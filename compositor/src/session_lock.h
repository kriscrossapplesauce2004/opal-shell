#pragma once

#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QtWaylandCompositor/QWaylandCompositorExtensionTemplate>
#include <QtWaylandCompositor/QWaylandOutput>
#include <QtWaylandCompositor/QWaylandResource>
#include <QtWaylandCompositor/QWaylandShellSurfaceTemplate>
#include <QtWaylandCompositor/QWaylandSurface>

#include "qwayland-server-ext-session-lock-v1.h"

class SessionLock;
class SessionLockSurface;

// Server for ext_session_lock_manager_v1. While locked, the scene shows lock surfaces only.
class SessionLockManager : public QWaylandCompositorExtensionTemplate<SessionLockManager>,
                           public QtWaylandServer::ext_session_lock_manager_v1,
                           public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)

public:
    SessionLockManager();
    void initialize() override;
    void classBegin() override {}
    void componentComplete() override
    {
        if (!isInitialized())
            initialize();
    }

    // True from the lock request until a valid unlock; a lock client that dies leaves it true.
    bool locked() const { return m_locked; }

    // The scene calls this after it presented a frame with no unlocked content.
    Q_INVOKABLE void confirmBlanked();

    QWaylandCompositor *compositor() const;
    void unlock(SessionLock *lock);
    void lockGone(SessionLock *lock);
    void addSurface(SessionLockSurface *surface) { emit lockSurfaceCreated(surface); }

signals:
    void lockedChanged();
    void lockSurfaceCreated(SessionLockSurface *lockSurface);

protected:
    void ext_session_lock_manager_v1_destroy(Resource *resource) override;
    void ext_session_lock_manager_v1_lock(Resource *resource, uint32_t id) override;

private:
    QPointer<SessionLock> m_active;
    bool m_locked = false;
};

// One ext_session_lock_v1 object from the lock client.
class SessionLock : public QObject, public QtWaylandServer::ext_session_lock_v1
{
    Q_OBJECT

public:
    SessionLock(SessionLockManager *manager, wl_client *client, uint32_t id, int version);

    void sendLocked();
    void sendFinished();
    bool lockedSent() const { return m_lockedSent; }

protected:
    void ext_session_lock_v1_destroy(Resource *resource) override;
    void ext_session_lock_v1_get_lock_surface(Resource *resource, uint32_t id, wl_resource *surface,
                                              wl_resource *output) override;
    void ext_session_lock_v1_unlock_and_destroy(Resource *resource) override;
    void ext_session_lock_v1_destroy_resource(Resource *resource) override;

private:
    QPointer<SessionLockManager> m_manager;
    bool m_lockedSent = false;
    bool m_finished = false;
};

// One lock surface per output, always the full output size.
class SessionLockSurface : public QWaylandShellSurfaceTemplate<SessionLockSurface>,
                           public QtWaylandServer::ext_session_lock_surface_v1
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by SessionLockManager")
    Q_PROPERTY(QWaylandSurface *surface READ surface CONSTANT)
    Q_PROPERTY(QWaylandOutput *output READ output CONSTANT)

public:
    SessionLockSurface(SessionLockManager *manager, QWaylandSurface *surface, QWaylandOutput *output,
                       const QWaylandResource &resource);

    QWaylandQuickShellIntegration *createIntegration(QWaylandQuickShellSurfaceItem *item) override;
    QWaylandSurface *surface() const { return m_surface; }
    QWaylandOutput *output() const { return m_output; }

    static QWaylandSurfaceRole *role() { return &s_role; }

protected:
    void ext_session_lock_surface_v1_destroy(Resource *resource) override;
    void ext_session_lock_surface_v1_ack_configure(Resource *resource, uint32_t serial) override;
    void ext_session_lock_surface_v1_destroy_resource(Resource *resource) override;

private:
    void sendSize();
    void handleCommit();

    QPointer<SessionLockManager> m_manager;
    QPointer<QWaylandSurface> m_surface;
    QPointer<QWaylandOutput> m_output;
    QList<uint32_t> m_serials;
    bool m_acked = false;

    static QWaylandSurfaceRole s_role;
};
