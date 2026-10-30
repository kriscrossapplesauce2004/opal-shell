#pragma once

#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QtWaylandCompositor/QWaylandCompositorExtensionTemplate>
#include <QtWaylandCompositor/QWaylandOutput>
#include <QtWaylandCompositor/QWaylandSurface>
#include <QtWaylandCompositor/QWaylandXdgShell>

#include "qwayland-server-wlr-foreign-toplevel-management-unstable-v1.h"

class ForeignToplevel;

// Server for zwlr_foreign_toplevel_manager_v1: the task bar's list of windows.
class ForeignToplevelManager : public QWaylandCompositorExtensionTemplate<ForeignToplevelManager>,
                               public QtWaylandServer::zwlr_foreign_toplevel_manager_v1,
                   public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)

public:
    ForeignToplevelManager();
    void initialize() override;
    // QML creates the object without a container; initialize once the compositor parent is set.
    void classBegin() override {}
    void componentComplete() override
    {
        if (!isInitialized())
            initialize();
    }

    // Publishes one window to every bound client; the scene sets its state on the returned object.
    Q_INVOKABLE ForeignToplevel *add(QWaylandXdgToplevel *toplevel, QWaylandOutput *output);

    void forget(ForeignToplevel *toplevel);

protected:
    void zwlr_foreign_toplevel_manager_v1_bind_resource(Resource *resource) override;
    void zwlr_foreign_toplevel_manager_v1_stop(Resource *resource) override;

private:
    QList<ForeignToplevel *> m_toplevels;
};

// One window as seen by foreign clients: title, app id, states, and the requests they send.
class ForeignToplevel : public QObject, public QtWaylandServer::zwlr_foreign_toplevel_handle_v1
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by ForeignToplevelManager")
    Q_PROPERTY(bool activated READ activated WRITE setActivated NOTIFY stateChanged)
    Q_PROPERTY(bool minimized READ minimized WRITE setMinimized NOTIFY stateChanged)
    Q_PROPERTY(bool maximized READ maximized WRITE setMaximized NOTIFY stateChanged)
    Q_PROPERTY(bool fullscreen READ fullscreen WRITE setFullscreen NOTIFY stateChanged)

public:
    ForeignToplevel(ForeignToplevelManager *manager, QWaylandXdgToplevel *toplevel, QWaylandOutput *output);

    bool activated() const { return m_activated; }
    bool minimized() const { return m_minimized; }
    bool maximized() const { return m_maximized; }
    bool fullscreen() const { return m_fullscreen; }
    void setActivated(bool on);
    void setMinimized(bool on);
    void setMaximized(bool on);
    void setFullscreen(bool on);

    // Sends the handle and its full state to one manager resource.
    void announce(wl_resource *managerResource);

    // Tells every client that the window is gone.
    Q_INVOKABLE void remove();

signals:
    void stateChanged();
    void activateRequested();
    void closeRequested();
    void minimizeRequested(bool on);
    void maximizeRequested(bool on);
    void fullscreenRequested(bool on);

protected:
    void zwlr_foreign_toplevel_handle_v1_set_maximized(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_unset_maximized(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_set_minimized(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_unset_minimized(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_activate(Resource *resource, wl_resource *seat) override;
    void zwlr_foreign_toplevel_handle_v1_close(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_set_rectangle(Resource *resource, wl_resource *surface, int32_t x, int32_t y,
                                                       int32_t width, int32_t height) override;
    void zwlr_foreign_toplevel_handle_v1_destroy(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_set_fullscreen(Resource *resource, wl_resource *output) override;
    void zwlr_foreign_toplevel_handle_v1_unset_fullscreen(Resource *resource) override;
    void zwlr_foreign_toplevel_handle_v1_destroy_resource(Resource *resource) override;

private:
    QByteArray stateArray() const;
    void sendState();
    void sendDetails(Resource *resource);

    QPointer<ForeignToplevelManager> m_manager;
    QPointer<QWaylandXdgToplevel> m_toplevel;
    QPointer<QWaylandOutput> m_output;
    bool m_activated = false;
    bool m_minimized = false;
    bool m_maximized = false;
    bool m_fullscreen = false;
    bool m_removed = false;
};
