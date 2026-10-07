#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/LayerSurface.hpp>
#include <hyprland/src/helpers/Monitor.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/SessionLockManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <any>
#include <set>
#include <stdexcept>
#include <string>

// Keep dock controls separate from the desktop pointer.
static PHLLSREF target;
static PHLMONITORREF monitor;
static WP<CWLSurfaceResource> surface;
static WP<ITouch> device;
static Vector2D origin;
static std::set<int32_t> fingers;
static SP<HOOK_CALLBACK_FN> downHook, moveHook, upHook, cancelHook;

static bool validTarget() {
    return !g_pSessionLockManager->isSessionLocked() && target && target->m_mapped && monitor && surface;
}

static void consume(SCallbackInfo& info) {
    info.cancelled = true;
    g_pInputManager->m_lastInputTouch = false;
}

static void down(void*, SCallbackInfo& info, std::any data) {
    const auto e = std::any_cast<ITouch::SDownEvent>(data);
    if (info.cancelled || g_pSessionLockManager->isSessionLocked()) return;
    if (fingers.empty()) {
        if (e.device->m_boundOutput.empty()) return;
        auto output = g_pCompositor->getMonitorFromName(e.device->m_boundOutput);
        if (!output) return;
        const auto position = output->m_position + e.pos * output->m_size;
        Vector2D local;
        PHLLS layer;
        auto hit = g_pCompositor->vectorToLayerPopupSurface(position, output, &local, &layer);
        if (hit) return;
        hit = g_pCompositor->vectorToLayerSurface(position, &output->m_layerSurfaceLayers[3], &local, &layer);
        if (!hit || !layer || layer->m_namespace != "opal-phone-dock") return;
        target = layer;
        surface = hit;
        monitor = output;
        device = e.device;
        origin = position - local;
    } else if (device.lock() != e.device || !validTarget()) return;
    if (!fingers.insert(e.touchID).second) return;
    consume(info);
    g_pSeatManager->sendTouchDown(surface.lock(), e.timeMs, e.touchID, monitor->m_position + e.pos * monitor->m_size - origin);
    g_pSeatManager->sendTouchFrame();
}

static void move(void*, SCallbackInfo& info, std::any data) {
    const auto e = std::any_cast<ITouch::SMotionEvent>(data);
    if (!fingers.contains(e.touchID)) return;
    consume(info);
    if (validTarget()) {
        g_pSeatManager->sendTouchMotion(e.timeMs, e.touchID, monitor->m_position + e.pos * monitor->m_size - origin);
        g_pSeatManager->sendTouchFrame();
    }
}

static void up(void*, SCallbackInfo& info, std::any data) {
    const auto e = std::any_cast<ITouch::SUpEvent>(data);
    if (!fingers.erase(e.touchID)) return;
    consume(info);
    if (surface && g_pSeatManager->m_state.touchFocus == surface.lock()) {
        g_pSeatManager->sendTouchUp(e.timeMs, e.touchID);
        g_pSeatManager->sendTouchFrame();
    }
    if (fingers.empty()) { target.reset(); surface.reset(); monitor.reset(); device.reset(); }
}

static void cancel(void*, SCallbackInfo& info, std::any data) {
    const auto e = std::any_cast<ITouch::SCancelEvent>(data);
    if (!fingers.erase(e.touchID)) return;
    consume(info);
    if (surface && g_pSeatManager->m_state.touchFocus == surface.lock()) g_pSeatManager->sendTouchCancel();
    if (fingers.empty()) { target.reset(); surface.reset(); monitor.reset(); device.reset(); }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
        throw std::runtime_error("opal-touch: compositor version does not match");
    downHook = HyprlandAPI::registerCallbackDynamic(handle, "touchDown", down);
    moveHook = HyprlandAPI::registerCallbackDynamic(handle, "touchMove", move);
    upHook = HyprlandAPI::registerCallbackDynamic(handle, "touchUp", up);
    cancelHook = HyprlandAPI::registerCallbackDynamic(handle, "touchCancel", cancel);
    return {"opal-touch", "Independent touch routing for Opal dock controls", "Opal", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (!fingers.empty() && surface && g_pSeatManager->m_state.touchFocus == surface.lock()) {
        g_pSeatManager->sendTouchCancel();
        for (const auto id : fingers) g_pSeatManager->sendTouchUp(0, id);
        g_pSeatManager->sendTouchFrame();
    }
    fingers.clear();
    downHook.reset(); moveHook.reset(); upHook.reset(); cancelHook.reset();
}
