#include "session_lock.h"
#include "surface_integration.h"

#include <QtWaylandCompositor/QWaylandCompositor>
#include <QtWaylandCompositor/QWaylandResource>

#include <wayland-server-core.h>
#include <wayland-server-protocol.h>

QWaylandSurfaceRole SessionLockSurface::s_role("ext_session_lock_surface_v1");

// ---------- SessionLockManager ----------

SessionLockManager::SessionLockManager() = default;

QWaylandCompositor *SessionLockManager::compositor() const
{
    return qobject_cast<QWaylandCompositor *>(extensionContainer());
}

void SessionLockManager::initialize()
{
    QWaylandCompositorExtensionTemplate::initialize();
    QWaylandCompositor *c = compositor();
    if (!c) {
        qWarning("SessionLockManager: no compositor; add it inside WaylandCompositor");
        return;
    }
    init(c->display(), 1);
}

void SessionLockManager::ext_session_lock_manager_v1_destroy(Resource *resource)
{
    wl_resource_destroy(resource->handle);
}

void SessionLockManager::ext_session_lock_manager_v1_lock(Resource *resource, uint32_t id)
{
    auto *lock = new SessionLock(this, resource->client(), id, resource->version());
    // A second lock while one is active, or while a dead client left the session locked, is refused.
    if (m_active || m_locked) {
        lock->sendFinished();
        return;
    }
    m_active = lock;
    m_locked = true;
    emit lockedChanged();
}

void SessionLockManager::confirmBlanked()
{
    if (m_active && !m_active->lockedSent())
        m_active->sendLocked();
}

void SessionLockManager::unlock(SessionLock *lock)
{
    if (lock != m_active)
        return;
    m_active = nullptr;
    m_locked = false;
    emit lockedChanged();
}

void SessionLockManager::lockGone(SessionLock *lock)
{
    // The session stays locked: only unlock_and_destroy unlocks it.
    if (lock == m_active)
        m_active = nullptr;
}

// ---------- SessionLock ----------

SessionLock::SessionLock(SessionLockManager *manager, wl_client *client, uint32_t id, int version)
    : m_manager(manager)
{
    init(client, id, version);
}

void SessionLock::sendLocked()
{
    if (m_lockedSent || m_finished)
        return;
    m_lockedSent = true;
    send_locked();
}

void SessionLock::sendFinished()
{
    if (m_finished)
        return;
    m_finished = true;
    send_finished();
}

void SessionLock::ext_session_lock_v1_destroy(Resource *resource)
{
    if (m_lockedSent && !m_finished) {
        wl_resource_post_error(resource->handle, error_invalid_destroy, "destroy while locked; use unlock_and_destroy");
        return;
    }
    wl_resource_destroy(resource->handle);
}

void SessionLock::ext_session_lock_v1_get_lock_surface(Resource *resource, uint32_t id, wl_resource *surfaceResource,
                                                       wl_resource *outputResource)
{
    QWaylandSurface *surface = QWaylandSurface::fromResource(surfaceResource);
    QWaylandOutput *output = QWaylandOutput::fromResource(outputResource);
    if (!surface || !output) {
        wl_resource_post_error(resource->handle, WL_DISPLAY_ERROR_INVALID_OBJECT, "bad surface or output");
        return;
    }
    if (surface->hasContent()) {
        wl_resource_post_error(resource->handle, error_already_constructed, "surface already has a buffer");
        return;
    }
    if (!surface->setRole(SessionLockSurface::role(), resource->handle, error_role))
        return;
    QWaylandResource res(wl_resource_create(resource->client(), &::ext_session_lock_surface_v1_interface,
                                            resource->version(), id));
    auto *lockSurface = new SessionLockSurface(m_manager, surface, output, res);
    if (m_manager && !m_finished)
        m_manager->addSurface(lockSurface);
}

void SessionLock::ext_session_lock_v1_unlock_and_destroy(Resource *resource)
{
    if (!m_lockedSent) {
        wl_resource_post_error(resource->handle, error_invalid_unlock, "unlock before locked");
        return;
    }
    if (m_manager)
        m_manager->unlock(this);
    wl_resource_destroy(resource->handle);
}

void SessionLock::ext_session_lock_v1_destroy_resource(Resource *)
{
    if (m_manager)
        m_manager->lockGone(this);
    deleteLater();
}

// ---------- SessionLockSurface ----------

SessionLockSurface::SessionLockSurface(SessionLockManager *manager, QWaylandSurface *surface, QWaylandOutput *output,
                                       const QWaylandResource &resource)
    : QWaylandShellSurfaceTemplate<SessionLockSurface>(surface)
    , m_manager(manager)
    , m_surface(surface)
    , m_output(output)
{
    init(resource.resource());
    connect(surface, &QWaylandSurface::redraw, this, &SessionLockSurface::handleCommit);
    connect(output, &QWaylandOutput::geometryChanged, this, &SessionLockSurface::sendSize);
    sendSize();
}

QWaylandQuickShellIntegration *SessionLockSurface::createIntegration(QWaylandQuickShellSurfaceItem *item)
{
    return new SurfaceOnlyIntegration(item, m_surface);
}

void SessionLockSurface::sendSize()
{
    if (!resource() || !m_output)
        return;
    QWaylandCompositor *c = m_manager ? m_manager->compositor() : nullptr;
    const uint32_t serial = c ? c->nextSerial() : 0;
    m_serials.append(serial);
    const QSize size = m_output->geometry().size();
    send_configure(serial, static_cast<uint32_t>(size.width()), static_cast<uint32_t>(size.height()));
}

void SessionLockSurface::handleCommit()
{
    if (!resource() || !m_surface)
        return;
    if (!m_acked) {
        wl_resource_post_error(resource()->handle, error_commit_before_first_ack, "commit before first ack");
        return;
    }
    if (!m_surface->hasContent())
        wl_resource_post_error(resource()->handle, error_null_buffer, "null buffer on a lock surface");
}

void SessionLockSurface::ext_session_lock_surface_v1_destroy(Resource *resource)
{
    wl_resource_destroy(resource->handle);
}

void SessionLockSurface::ext_session_lock_surface_v1_ack_configure(Resource *resource, uint32_t serial)
{
    const qsizetype index = m_serials.indexOf(serial);
    if (index < 0) {
        wl_resource_post_error(resource->handle, error_invalid_serial, "unknown serial %u", serial);
        return;
    }
    m_serials.remove(0, index + 1);
    m_acked = true;
}

void SessionLockSurface::ext_session_lock_surface_v1_destroy_resource(Resource *)
{
    deleteLater();
}
