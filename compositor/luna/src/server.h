#pragma once

#include <wglobal.h>
#include <wseat.h>

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QSize>

QT_BEGIN_NAMESPACE
class QQmlEngine;
class QQuickItem;
QT_END_NAMESPACE

WAYLIB_SERVER_BEGIN_NAMESPACE
class WServer;
class WBackend;
class WOutput;
class WOutputItem;
class WOutputLayout;
class WOutputRenderWindow;
class WCursor;
class WSocket;
class WSurface;
class WSurfaceItem;
class WToplevelSurface;
class WXdgShell;
class WLayerShell;
class WLayerSurface;
class WXWayland;
class WXWaylandSurface;
class WXWaylandSurfaceItem;
class WXdgPopupSurface;
class WForeignToplevel;
class WExtForeignToplevelListV1;
class WXdgDecorationManager;
class WInputMethodHelper;
class WInputPopupSurface;
class WSessionLock;
class WSessionLockSurface;
class WRelativePointerManagerV1;
class WOutputManagerV1;
WAYLIB_SERVER_END_NAMESPACE

struct wlr_renderer;
struct wlr_allocator;
struct wlr_compositor;
struct wlr_xdg_activation_v1;
struct wlr_idle_inhibit_manager_v1;
struct wlr_idle_notifier_v1;

class OutputCapture;

// Options that main() reads from the command line.
struct LunaOptions
{
    QString socketName = QStringLiteral("luna-0");
    QSize headlessSize = QSize(1280, 800);
    bool xwayland = true;
    bool standInBar = false;
};

// The Wayland side of luna-compositor: protocols, outputs, input, and signals to the QML scene.
class LunaServer : public WAYLIB_SERVER_NAMESPACE::WSeatEventFilter, public WAYLIB_SERVER_NAMESPACE::WObject
{
    Q_OBJECT
    Q_PROPERTY(QRectF outputRect READ outputRect NOTIFY outputRectChanged FINAL)
    Q_PROPERTY(bool standInBar READ standInBar CONSTANT FINAL)
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged FINAL)

public:
    LunaServer(QQmlEngine *engine, const LunaOptions &options, QObject *parent = nullptr);
    ~LunaServer() override;

    // Creates the backend, the protocols and the scene, then starts the backend.
    bool start();

    WAYLIB_SERVER_NAMESPACE::WOutputRenderWindow *window() const { return m_window; }
    wlr_renderer *renderer() const;
    // Watches every output now and later; the server does not own the capture.
    void setCapture(OutputCapture *capture);
    QString socketPath() const;
    QByteArray xwaylandDisplay() const;
    QString backendName() const;

    QRectF outputRect() const { return m_outputRect; }
    bool standInBar() const { return m_options.standInBar; }
    bool locked() const { return m_lock != nullptr; }

    // Gives keyboard focus to the surface of item; null clears focus.
    Q_INVOKABLE void focusItem(WAYLIB_SERVER_NAMESPACE::WSurfaceItem *item);
    // Asks a toplevel for a new size; waits for the initial commit if needed.
    Q_INVOKABLE void configureToplevel(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface, const QSizeF &size);
    // Sends a layer surface its size; the call has no effect before the initial commit.
    Q_INVOKABLE void configureLayer(WAYLIB_SERVER_NAMESPACE::WLayerSurface *surface, const QSizeF &size);
    Q_INVOKABLE bool isInitialized(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface) const;
    // Tells the X server where an X11 window is.
    Q_INVOKABLE void moveX11(WAYLIB_SERVER_NAMESPACE::WXWaylandSurfaceItem *item, const QPointF &scenePos);
    Q_INVOKABLE void resizeLockSurface(WAYLIB_SERVER_NAMESPACE::WSurfaceItem *item, const QSizeF &size);
    // Sends the X11 work area, so X clients keep clear of the shell.
    Q_INVOKABLE void setWorkArea(const QRectF &area);

Q_SIGNALS:
    void outputRectChanged();
    void lockedChanged();
    void toplevelAdded(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface, bool x11);
    void toplevelRemoved(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface);
    // An X11 menu, tooltip or other window that the window manager must not move.
    void unmanagedAdded(WAYLIB_SERVER_NAMESPACE::WXWaylandSurface *surface);
    void unmanagedRemoved(WAYLIB_SERVER_NAMESPACE::WXWaylandSurface *surface);
    void popupAdded(WAYLIB_SERVER_NAMESPACE::WXdgPopupSurface *popup, WAYLIB_SERVER_NAMESPACE::WSurface *parent);
    void popupRemoved(WAYLIB_SERVER_NAMESPACE::WXdgPopupSurface *popup);
    void inputPopupAdded(WAYLIB_SERVER_NAMESPACE::WInputPopupSurface *popup, WAYLIB_SERVER_NAMESPACE::WSurface *parent);
    void inputPopupRemoved(WAYLIB_SERVER_NAMESPACE::WInputPopupSurface *popup);
    void layerAdded(WAYLIB_SERVER_NAMESPACE::WLayerSurface *surface);
    void layerRemoved(WAYLIB_SERVER_NAMESPACE::WLayerSurface *surface);
    void layersChanged();
    void lockSurfaceAdded(WAYLIB_SERVER_NAMESPACE::WSessionLockSurface *surface);
    void lockSurfaceRemoved(WAYLIB_SERVER_NAMESPACE::WSessionLockSurface *surface);
    // A pointer or touch press landed on this surface.
    void surfacePressed(WAYLIB_SERVER_NAMESPACE::WSurface *surface);
    // A press landed on no surface.
    void emptyPressed();
    // Requests from the task bar (foreign toplevel) or from xdg-activation.
    void activateRequested(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface);
    void closeRequested(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface);
    void minimizeRequested(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface, bool on);
    void maximizeRequested(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface, bool on);
    void fullscreenRequested(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface, bool on);

private:
    bool afterHandleEvent(WAYLIB_SERVER_NAMESPACE::WSeat *seat, WAYLIB_SERVER_NAMESPACE::WSurface *watched,
                          QObject *surfaceItem, QObject *, QInputEvent *event) override;
    bool unacceptedEvent(WAYLIB_SERVER_NAMESPACE::WSeat *, QWindow *, QInputEvent *event) override;

    void addOutput(WAYLIB_SERVER_NAMESPACE::WOutput *output);
    void removeOutput(WAYLIB_SERVER_NAMESPACE::WOutput *output);
    void enableOutput(WAYLIB_SERVER_NAMESPACE::WOutput *output);
    void setupXWayland();
    void setupWlrootsProtocols();
    void updateOutputRect();
    void enterOutputs(WAYLIB_SERVER_NAMESPACE::WSurface *surface);
    void addToplevel(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface, bool x11);
    void removeToplevel(WAYLIB_SERVER_NAMESPACE::WToplevelSurface *surface);

    QQmlEngine *m_engine;
    LunaOptions m_options;

    WAYLIB_SERVER_NAMESPACE::WOutputRenderWindow *m_window = nullptr;
    QQuickItem *m_scene = nullptr;
    WAYLIB_SERVER_NAMESPACE::WServer *m_server = nullptr;
    WAYLIB_SERVER_NAMESPACE::WBackend *m_backend = nullptr;
    WAYLIB_SERVER_NAMESPACE::WSeat *m_seat = nullptr;
    WAYLIB_SERVER_NAMESPACE::WCursor *m_cursor = nullptr;
    WAYLIB_SERVER_NAMESPACE::WOutputLayout *m_layout = nullptr;
    WAYLIB_SERVER_NAMESPACE::WSocket *m_socket = nullptr;
    WAYLIB_SERVER_NAMESPACE::WXdgShell *m_xdgShell = nullptr;
    WAYLIB_SERVER_NAMESPACE::WLayerShell *m_layerShell = nullptr;
    WAYLIB_SERVER_NAMESPACE::WXWayland *m_xwayland = nullptr;
    WAYLIB_SERVER_NAMESPACE::WForeignToplevel *m_foreignToplevel = nullptr;
    WAYLIB_SERVER_NAMESPACE::WExtForeignToplevelListV1 *m_extForeignToplevel = nullptr;
    WAYLIB_SERVER_NAMESPACE::WXdgDecorationManager *m_decoration = nullptr;
    WAYLIB_SERVER_NAMESPACE::WInputMethodHelper *m_inputMethod = nullptr;
    WAYLIB_SERVER_NAMESPACE::WRelativePointerManagerV1 *m_relativePointer = nullptr;
    WAYLIB_SERVER_NAMESPACE::WOutputManagerV1 *m_outputManager = nullptr;
    QPointer<WAYLIB_SERVER_NAMESPACE::WSessionLock> m_lock;

    wlr_renderer *m_renderer = nullptr;
    wlr_allocator *m_allocator = nullptr;
    wlr_compositor *m_compositor = nullptr;
    wlr_xdg_activation_v1 *m_activation = nullptr;
    wlr_idle_inhibit_manager_v1 *m_idleInhibit = nullptr;
    wlr_idle_notifier_v1 *m_idleNotifier = nullptr;

    QList<WAYLIB_SERVER_NAMESPACE::WOutputItem *> m_outputItems;
    QHash<WAYLIB_SERVER_NAMESPACE::WToplevelSurface *, QSize> m_pendingSize;
    OutputCapture *m_capture = nullptr;
    QRectF m_outputRect;
    QRect m_workArea;
    bool m_xwaylandReady = false;
};
