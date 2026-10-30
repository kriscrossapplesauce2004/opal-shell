#include "foreign_toplevel.h"

#include <QtWaylandCompositor/QWaylandClient>
#include <QtWaylandCompositor/QWaylandCompositor>
#include <QtWaylandCompositor/QWaylandOutput>
#include <QtWaylandCompositor/QWaylandXdgShell>

#include <wayland-server-core.h>

namespace {
constexpr int ManagerVersion = 3;
}

// ---------- ForeignToplevelManager ----------

ForeignToplevelManager::ForeignToplevelManager() = default;

void ForeignToplevelManager::initialize()
{
    QWaylandCompositorExtensionTemplate::initialize();
    auto *c = qobject_cast<QWaylandCompositor *>(extensionContainer());
    if (!c) {
        qWarning("ForeignToplevelManager: no compositor; add it inside WaylandCompositor");
        return;
    }
    init(c->display(), ManagerVersion);
}

ForeignToplevel *ForeignToplevelManager::add(QWaylandXdgToplevel *toplevel, QWaylandOutput *output)
{
    if (!toplevel)
        return nullptr;
    auto *handle = new ForeignToplevel(this, toplevel, output);
    QQmlEngine::setObjectOwnership(handle, QQmlEngine::CppOwnership);
    m_toplevels.append(handle);
    const auto resources = resourceMap();
    for (Resource *r : resources)
        handle->announce(r->handle);
    return handle;
}

void ForeignToplevelManager::forget(ForeignToplevel *toplevel)
{
    m_toplevels.removeAll(toplevel);
}

void ForeignToplevelManager::zwlr_foreign_toplevel_manager_v1_bind_resource(Resource *resource)
{
    for (ForeignToplevel *t : std::as_const(m_toplevels))
        t->announce(resource->handle);
}

void ForeignToplevelManager::zwlr_foreign_toplevel_manager_v1_stop(Resource *resource)
{
    send_finished(resource->handle);
    wl_resource_destroy(resource->handle);
}

// ---------- ForeignToplevel ----------

ForeignToplevel::ForeignToplevel(ForeignToplevelManager *manager, QWaylandXdgToplevel *toplevel,
                                 QWaylandOutput *output)
    : m_manager(manager)
    , m_toplevel(toplevel)
    , m_output(output)
{
    connect(toplevel, &QWaylandXdgToplevel::titleChanged, this, [this] {
        const auto resources = resourceMap();
        for (Resource *r : resources) {
            send_title(r->handle, m_toplevel ? m_toplevel->title() : QString());
            send_done(r->handle);
        }
    });
    connect(toplevel, &QWaylandXdgToplevel::appIdChanged, this, [this] {
        const auto resources = resourceMap();
        for (Resource *r : resources) {
            send_app_id(r->handle, m_toplevel ? m_toplevel->appId() : QString());
            send_done(r->handle);
        }
    });
}

void ForeignToplevel::announce(wl_resource *managerResource)
{
    if (m_removed)
        return;
    wl_client *client = wl_resource_get_client(managerResource);
    Resource *r = add(client, 0, wl_resource_get_version(managerResource));
    if (!r)
        return;
    m_manager->send_toplevel(managerResource, r->handle);
    sendDetails(r);
}

void ForeignToplevel::sendDetails(Resource *r)
{
    if (m_toplevel) {
        send_title(r->handle, m_toplevel->title());
        send_app_id(r->handle, m_toplevel->appId());
    }
    if (m_output) {
        auto *c = m_output->compositor();
        QWaylandClient *client = c ? QWaylandClient::fromWlClient(c, r->client()) : nullptr;
        if (wl_resource *out = client ? m_output->resourceForClient(client) : nullptr)
            send_output_enter(r->handle, out);
    }
    send_state(r->handle, stateArray());
    send_done(r->handle);
}

QByteArray ForeignToplevel::stateArray() const
{
    QList<uint32_t> states;
    if (m_maximized)
        states.append(state_maximized);
    if (m_minimized)
        states.append(state_minimized);
    if (m_activated)
        states.append(state_activated);
    if (m_fullscreen)
        states.append(state_fullscreen);
    return QByteArray(reinterpret_cast<const char *>(states.constData()),
                      static_cast<qsizetype>(states.size() * sizeof(uint32_t)));
}

void ForeignToplevel::sendState()
{
    if (m_removed)
        return;
    const QByteArray array = stateArray();
    const auto resources = resourceMap();
    for (Resource *r : resources) {
        send_state(r->handle, array);
        send_done(r->handle);
    }
    emit stateChanged();
}

void ForeignToplevel::setActivated(bool on)
{
    if (m_activated == on)
        return;
    m_activated = on;
    sendState();
}

void ForeignToplevel::setMinimized(bool on)
{
    if (m_minimized == on)
        return;
    m_minimized = on;
    sendState();
}

void ForeignToplevel::setMaximized(bool on)
{
    if (m_maximized == on)
        return;
    m_maximized = on;
    sendState();
}

void ForeignToplevel::setFullscreen(bool on)
{
    if (m_fullscreen == on)
        return;
    m_fullscreen = on;
    sendState();
}

void ForeignToplevel::remove()
{
    if (m_removed)
        return;
    m_removed = true;
    if (m_manager)
        m_manager->forget(this);
    const auto resources = resourceMap();
    for (Resource *r : resources)
        send_closed(r->handle);
    // The object lives until every client destroys its handle.
    if (resources.isEmpty())
        deleteLater();
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_set_maximized(Resource *)
{
    emit maximizeRequested(true);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_unset_maximized(Resource *)
{
    emit maximizeRequested(false);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_set_minimized(Resource *)
{
    emit minimizeRequested(true);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_unset_minimized(Resource *)
{
    emit minimizeRequested(false);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_activate(Resource *, wl_resource *)
{
    emit activateRequested();
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_close(Resource *)
{
    emit closeRequested();
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_set_rectangle(Resource *, wl_resource *, int32_t, int32_t,
                                                                    int32_t, int32_t)
{
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_destroy(Resource *resource)
{
    wl_resource_destroy(resource->handle);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_set_fullscreen(Resource *, wl_resource *)
{
    emit fullscreenRequested(true);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_unset_fullscreen(Resource *)
{
    emit fullscreenRequested(false);
}

void ForeignToplevel::zwlr_foreign_toplevel_handle_v1_destroy_resource(Resource *)
{
    // The generated code takes the resource out of the map before this call.
    if (m_removed && resourceMap().isEmpty())
        deleteLater();
}
