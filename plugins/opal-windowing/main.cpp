// Opal windowing: reports window drags to the shell for snap zones, and restores a snapped window's size when it is dragged away.
// Events go to Hyprland's event socket (socket2) as "opalwindrag>>kind,…"; the Opal backend already reads that socket.
#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <hyprland/src/managers/KeybindManager.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp>

#include <format>
#include <string>
#include <unordered_map>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

inline HANDLE PHANDLE = nullptr;

namespace {
    // Edge zones are this many logical pixels deep; corners take this much of each edge.
    constexpr double EDGE   = 8.0;
    constexpr double CORNER = 120.0;

    struct SState {
        SP<Config::Values::CBoolValue>            zonesEnabled;
        std::string                               dragging; // Address of the window being moved, or empty.
        std::string                               zone;
        std::string                               zoneMonitor;
        std::unordered_map<std::string, Vector2D> restoreSize; // Snapped windows and the size they had before the snap.
        bool                                      restarting = false;
    };
    UP<SState> g_state;

    std::string addressOf(PHLWINDOW w) {
        return std::format("0x{:x}", (uintptr_t)w.get());
    }

    void post(const std::string& data) {
        if (g_pEventManager)
            g_pEventManager->postEvent(SHyprIPCEvent{"opalwindrag", data});
    }

    bool insideAnyMonitor(const Vector2D& p) {
        for (auto const& m : State::monitorState()->monitors()) {
            if (m && m->logicalBox().containsPoint(p))
                return true;
        }
        return false;
    }

    // The snap zone under the cursor. A shared edge between two monitors is not a zone, so the cursor can cross it.
    std::pair<std::string, std::string> zoneAt(const Vector2D& p) {
        for (auto const& m : State::monitorState()->monitors()) {
            if (!m)
                continue;
            const auto box = m->logicalBox();
            if (!box.containsPoint(p))
                continue;
            const double x = p.x - box.x, y = p.y - box.y;
            const bool   left   = x <= EDGE && !insideAnyMonitor({box.x - 2, p.y});
            const bool   right  = x >= box.w - EDGE && !insideAnyMonitor({box.x + box.w + 2, p.y});
            const bool   top    = y <= EDGE && !insideAnyMonitor({p.x, box.y - 2});
            const bool   bottom = y >= box.h - EDGE && !insideAnyMonitor({p.x, box.y + box.h + 2});
            const bool   nearTop = y < CORNER, nearBottom = y > box.h - CORNER, nearLeft = x < CORNER, nearRight = x > box.w - CORNER;
            std::string  zone;
            if ((top && nearLeft) || (left && nearTop))
                zone = "topleft";
            else if ((top && nearRight) || (right && nearTop))
                zone = "topright";
            else if ((bottom && nearLeft) || (left && nearBottom))
                zone = "bottomleft";
            else if ((bottom && nearRight) || (right && nearBottom))
                zone = "bottomright";
            else if (top)
                zone = "top";
            else if (left)
                zone = "left";
            else if (right)
                zone = "right";
            return {zone, m->m_name};
        }
        return {"", ""};
    }

    PHLWINDOW draggedWindow() {
        if (!g_layoutManager)
            return nullptr;
        const auto& drag = g_layoutManager->dragController();
        if (!drag || drag->mode() != MBIND_MOVE)
            return nullptr;
        const auto target = drag->target();
        if (!target || !target->floating())
            return nullptr;
        const auto w = target->window();
        return w && w->m_isMapped ? w : nullptr;
    }

    // A snapped window that starts moving goes back to its earlier size under the cursor, and the drag starts again from there.
    void unsnap(PHLWINDOW w, const Vector2D& size) {
        const auto target = w->layoutTarget();
        if (!target)
            return;
        const auto cursor = g_pInputManager->getMouseCoordsInternal();
        const auto box    = target->position();
        const double fx   = box.w > 0 ? std::clamp((cursor.x - box.x) / box.w, 0.0, 1.0) : 0.5;
        // The cursor may be on the titlebar above the body, so the offset can be negative.
        const double dy   = std::min(cursor.y - box.y, std::max(0.0, size.y - 1));
        g_state->restarting = true;
        g_layoutManager->endDragTarget();
        target->setPositionGlobal(CBox{Vector2D{cursor.x - fx * size.x, cursor.y - dy}.round(), size});
        target->warpPositionSize();
        g_layoutManager->beginDragTarget(target, MBIND_MOVE);
        g_state->restarting = false;
    }

    void onMove() {
        if (g_state->restarting)
            return;
        const auto w = draggedWindow();
        if (!w) {
            // The drag ended without a button release that we saw, for example when the window closed.
            if (!g_state->dragging.empty()) {
                post("end," + g_state->dragging + ",,");
                g_state->dragging.clear();
                g_state->zone.clear();
            }
            return;
        }
        const auto address = addressOf(w);
        if (g_state->dragging != address) {
            g_state->dragging = address;
            g_state->zone.clear();
            post("begin," + address);
            if (const auto it = g_state->restoreSize.find(address); it != g_state->restoreSize.end()) {
                const auto size = it->second;
                g_state->restoreSize.erase(it);
                unsnap(w, size);
                post("unsnap," + address);
            }
        }
        if (!g_state->zonesEnabled || !g_state->zonesEnabled->value())
            return;
        const auto [zone, monitor] = zoneAt(g_pInputManager->getMouseCoordsInternal());
        if (zone != g_state->zone || monitor != g_state->zoneMonitor) {
            g_state->zone        = zone;
            g_state->zoneMonitor = monitor;
            post("zone," + zone + "," + monitor);
        }
    }

    void onButton(const IPointer::SButtonEvent& e) {
        if (e.state != WL_POINTER_BUTTON_STATE_RELEASED || g_state->dragging.empty())
            return;
        // hyprbars ends its titlebar drag on release only while the window has focus. When it does not, the window would keep
        // following the pointer and the next press would only end the drag, so a drag still held after this release ends here.
        const auto released = g_state->dragging;
        if (g_pEventLoopManager)
            g_pEventLoopManager->doLater([released] {
                const auto w = draggedWindow();
                if (w && addressOf(w) == released)
                    CKeybindManager::changeMouseBindMode(MBIND_INVALID);
            });
        const bool zones = g_state->zonesEnabled && g_state->zonesEnabled->value();
        post("end," + g_state->dragging + "," + (zones ? g_state->zone : "") + "," + (zones ? g_state->zoneMonitor : ""));
        g_state->dragging.clear();
        g_state->zone.clear();
        g_state->zoneMonitor.clear();
    }

    // hl.plugin.opal_windowing.set_restore("0xADDRESS", width, height): a later drag restores this size. Width 0 forgets the window.
    int luaSetRestore(lua_State* L) {
        const char* address = luaL_checkstring(L, 1);
        const auto  width   = luaL_checknumber(L, 2);
        const auto  height  = luaL_checknumber(L, 3);
        if (width < 1 || height < 1)
            g_state->restoreSize.erase(address);
        else
            g_state->restoreSize[address] = Vector2D{width, height};
        return 0;
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();
    if (HASH != CLIENT_HASH)
        throw std::runtime_error("[opal-windowing] Version mismatch");

    g_state               = makeUnique<SState>();
    g_state->zonesEnabled = makeShared<Config::Values::CBoolValue>("plugin:opal_windowing:snap_zones", "Report snap zones while a window is dragged", false);
    HyprlandAPI::addConfigValueV2(PHANDLE, g_state->zonesEnabled);
    HyprlandAPI::addLuaFunction(PHANDLE, "opal_windowing", "set_restore", luaSetRestore);

    static auto P1 = Event::bus()->m_events.input.mouse.move.listen([](Vector2D, Event::SCallbackInfo&) { onMove(); });
    static auto P2 = Event::bus()->m_events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo&) { onButton(e); });
    static auto P3 = Event::bus()->m_events.window.close.listen([](PHLWINDOW w) {
        if (g_state && w)
            g_state->restoreSize.erase(addressOf(w));
    });

    return {"opal-windowing", "Snap zones and drag-to-restore for Opal's floating window mode.", "Opal", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_state.reset();
}
