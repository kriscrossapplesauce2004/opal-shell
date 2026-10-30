#include "server.h"

#include <QCoreApplication>

#include "output_capture.h"

#include <WServer>
#include <WOutput>
#include <WSurfaceItem>
#include <WBackend>
#include <wcursor.h>
#include <wscoplistener.h>
#include <wcursorshapemanagerv1.h>
#include <wextforeigntoplevellistv1.h>
#include <winputmethodhelper.h>
#include <winputpopupsurface.h>
#include <wlayershell.h>
#include <wlayersurface.h>
#include <woutputitem.h>
#include <woutputlayout.h>
#include <woutputmanagerv1.h>
#include <woutputrenderwindow.h>
#include <wpointerconstraintsv1.h>
#include <wrelativepointermanagerv1.h>
#include <wrenderhelper.h>
#include <wsecuritycontextmanager.h>
#include <wsessionlock.h>
#include <wsessionlockmanager.h>
#include <wsessionlocksurface.h>
#include <wsocket.h>
#include <wforeigntoplevelv1.h>
#include <wxdgdecorationmanager.h>
#include <wxdgdialogmanagerv1.h>
#include <wxdgoutput.h>
#include <wxdgpopupsurface.h>
#include <wxdgshell.h>
#include <wxdgtoplevelsurface.h>
#include <wxwayland.h>
#include <wxwaylandsurface.h>
#include <wxwaylandsurfaceitem.h>

#include "wlr_extra.h"

#include <QDir>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QSinglePointEvent>

#include <cstdio>

WAYLIB_SERVER_USE_NAMESPACE

namespace {

constexpr uint32_t kXdgShellVersion = 5;
constexpr uint32_t kCompositorVersion = 6;
constexpr uint32_t kPresentationVersion = 2;
constexpr uint32_t kFractionalScaleVersion = 1;
constexpr uint32_t kCursorShapeVersion = 1;

// Creates a QML component of module Luna.Server; returns null and prints errors on failure.
QObject *createFromModule(QQmlEngine *engine, const char *type, const QVariantMap &props)
{
    QQmlComponent component(engine, QStringLiteral("Luna.Server"), QString::fromLatin1(type));
    QObject *obj = component.createWithInitialProperties(props, engine->rootContext());
    if (!obj)
        std::fprintf(stderr, "luna-compositor: cannot create %s: %s\n", type, qPrintable(component.errorString()));
    return obj;
}

}

LunaServer::LunaServer(QQmlEngine *engine, const LunaOptions &options, QObject *parent)
    : WSeatEventFilter(parent)
    , WObject()
    , m_engine(engine)
    , m_options(options)
    , m_window(new WOutputRenderWindow(this))
    , m_server(new WServer(this))
{
    m_window->setColor(QColor(0x0d, 0x11, 0x16));
}

LunaServer::~LunaServer()
{
    // The scene goes first, so no binding runs against a half-destroyed server.
    delete m_scene;
    m_scene = nullptr;
    qDeleteAll(m_outputItems);
    m_outputItems.clear();
    teardown();
}

QString LunaServer::socketPath() const
{
    return m_socket ? m_socket->fullServerName() : QString();
}

QByteArray LunaServer::xwaylandDisplay() const
{
    return m_xwayland ? m_xwayland->displayName() : QByteArray();
}

QString LunaServer::backendName() const
{
    return QString::fromLocal8Bit(qgetenv("WLR_BACKENDS"));
}

bool LunaServer::start()
{
    m_engine->rootContext()->setContextProperty(QStringLiteral("luna"), this);
    m_engine->setContextForObject(m_window, m_engine->rootContext());
    m_engine->setContextForObject(m_window->contentItem(), m_engine->rootContext());

    // Seat, cursor and output layout.
    m_layout = new WOutputLayout(m_server);
    m_cursor = new WCursor(this);
    m_cursor->setEventWindow(m_window);
    m_cursor->setLayout(m_layout);
    m_seat = m_server->attach<WSeat>();
    m_seat->setEventFilter(this);
    m_seat->setCursor(m_cursor);
    m_seat->setKeyboardFocusWindow(m_window);

    connect(m_layout, &WOutputLayout::implicitWidthChanged, this, &LunaServer::updateOutputRect);
    connect(m_layout, &WOutputLayout::implicitHeightChanged, this, &LunaServer::updateOutputRect);

    m_backend = m_server->attach<WBackend>();
    connect(m_backend, &WBackend::inputAdded, this, [this](WInputDevice *device) {
        m_seat->attachInputDevice(device);
    });
    connect(m_backend, &WBackend::inputRemoved, this, [this](WInputDevice *device) {
        m_seat->detachInputDevice(device);
    });

    m_outputManager = m_server->attach<WOutputManagerV1>();
    // wlr-output-management: test or apply mode, scale, transform, VRR and enable state from tools like wlr-randr.
    connect(m_outputManager, &WOutputManagerV1::requestTestOrApply, this,
        [this](wlr_output_configuration_v1 *config, bool onlyTest) {
            const QList<WOutputState> states = m_outputManager->stateListPending(config);
            bool ok = true;
            for (const WOutputState &st : states) {
                wlr_output_state state;
                wlr_output_state_init(&state);
                wlr_output_state_set_enabled(&state, st.enabled);
                if (st.enabled) {
                    if (st.mode)
                        wlr_output_state_set_mode(&state, st.mode);
                    else
                        wlr_output_state_set_custom_mode(&state, st.customModeSize.width(),
                                                         st.customModeSize.height(), st.customModeRefresh);
                    wlr_output_state_set_adaptive_sync_enabled(&state, st.adaptiveSyncEnabled);
                    wlr_output_state_set_transform(&state, static_cast<wl_output_transform>(st.transform));
                    wlr_output_state_set_scale(&state, st.scale);
                }
                ok &= onlyTest ? wlr_output_test_state(st.output->handle(), &state)
                               : wlr_output_commit_state(st.output->handle(), &state);
                wlr_output_state_finish(&state);
            }
            m_outputManager->sendResult(config, ok);
        });
    connect(m_backend, &WBackend::outputAdded, this, &LunaServer::addOutput);
    connect(m_backend, &WBackend::outputRemoved, this, &LunaServer::removeOutput);

    // Shells.
    m_xdgShell = m_server->attach<WXdgShell>(kXdgShellVersion);
    m_foreignToplevel = m_server->attach<WForeignToplevel>(m_xdgShell);
    m_extForeignToplevel = m_server->attach<WExtForeignToplevelListV1>();
    m_layerShell = m_server->attach<WLayerShell>(m_xdgShell);
    auto *xdgOutput = m_server->attach<WXdgOutputManager>(m_layout);

    connect(m_xdgShell, &WXdgShell::toplevelSurfaceAdded, this, [this](WXdgToplevelSurface *s) {
        addToplevel(s, false);
    });
    connect(m_xdgShell, &WXdgShell::toplevelSurfaceRemoved, this, [this](WXdgToplevelSurface *s) {
        removeToplevel(s);
    });
    connect(m_xdgShell, &WXdgShell::popupSurfaceAdded, this, [this](WXdgPopupSurface *p) {
        enterOutputs(p->surface());
        Q_EMIT popupAdded(p, p->parentSurface());
    });
    connect(m_xdgShell, &WXdgShell::popupSurfaceRemoved, this, &LunaServer::popupRemoved);

    connect(m_layerShell, &WLayerShell::surfaceAdded, this, [this](WLayerSurface *s) {
        // Arrange again on property changes and on the initial commit, which needs a configure.
        connect(s, &WLayerSurface::layerPropertiesChanged, this, &LunaServer::layersChanged);
        connect(s->surface(), &WSurface::commit, this, [this, s] {
            if (s->handle()->initial_commit)
                Q_EMIT layersChanged();
        });
        enterOutputs(s->surface());
        Q_EMIT layerAdded(s);
    });
    connect(m_layerShell, &WLayerShell::surfaceRemoved, this, &LunaServer::layerRemoved);

    // Requests from task bars.
    connect(m_foreignToplevel, &WForeignToplevel::requestActivate, this, &LunaServer::activateRequested);
    connect(m_foreignToplevel, &WForeignToplevel::requestClose, this, &LunaServer::closeRequested);
    connect(m_foreignToplevel, &WForeignToplevel::requestMinimize, this, &LunaServer::minimizeRequested);
    connect(m_foreignToplevel, &WForeignToplevel::requestMaximize, this, &LunaServer::maximizeRequested);
    connect(m_foreignToplevel, &WForeignToplevel::requestFullscreen, this, &LunaServer::fullscreenRequested);

    // ext-session-lock: the lock stays until the client unlocks it.
    auto *lockManager = m_server->attach<WSessionLockManager>();
    connect(lockManager, &WSessionLockManager::lockCreated, this, [this](WSessionLock *lock) {
        if (m_lock) {
            lock->finish();
            return;
        }
        m_lock = lock;
        connect(lock, &WSessionLock::surfaceAdded, this, [this](WSessionLockSurface *s) {
            enterOutputs(s->surface());
            Q_EMIT lockSurfaceAdded(s);
        });
        connect(lock, &WSessionLock::surfaceRemoved, this, &LunaServer::lockSurfaceRemoved);
        auto release = [this] {
            m_lock = nullptr;
            Q_EMIT lockedChanged();
        };
        connect(lock, &WSessionLock::unlocked, this, release);
        connect(lock, &WSessionLock::canceled, this, release);
        // The protocol wants the session to stay locked when the lock client dies; the scene keeps it blank.
        lock->lock();
        Q_EMIT lockedChanged();
    });

    m_server->start();

    m_renderer = WRenderHelper::createRenderer(m_backend->handle());
    if (!m_renderer) {
        std::fprintf(stderr, "luna-compositor: cannot create a renderer\n");
        return false;
    }
    m_allocator = wlr_allocator_autocreate(m_backend->handle(), m_renderer);
    wlr_renderer_init_wl_display(m_renderer, m_server->handle());
    m_compositor = wlr_compositor_create(m_server->handle(), kCompositorVersion, m_renderer);
    wlr_subcompositor_create(m_server->handle());
    m_window->init(m_renderer, m_allocator);

    setupWlrootsProtocols();

    m_inputMethod = new WInputMethodHelper(m_server, m_seat);
    connect(m_inputMethod, &WInputMethodHelper::inputPopupSurfaceV2Added, this, [this](WInputPopupSurface *p) {
        enterOutputs(p->surface());
        Q_EMIT inputPopupAdded(p, p->parentSurface());
    });
    connect(m_inputMethod, &WInputMethodHelper::inputPopupSurfaceV2Removed, this, &LunaServer::inputPopupRemoved);

    // Opal draws its own window frames: ask clients for client-side decoration.
    m_decoration = m_server->attach<WXdgDecorationManager>();
    m_decoration->setPreferredMode(WXdgDecorationManager::Client);

    m_server->attach<WCursorShapeManagerV1>();
    // Pointer constraints: a lock or confine request is active while its surface has keyboard focus.
    auto *constraints = m_server->attach<WPointerConstraintsV1>();
    connect(constraints, &WPointerConstraintsV1::newConstraint, this, [this](wlr_pointer_constraint_v1 *c) {
        WSurface *focus = m_seat->keyboardFocusSurface();
        if (focus && focus->handle() == c->surface)
            wlr_pointer_constraint_v1_send_activated(c);
    });
    m_relativePointer = m_server->attach<WRelativePointerManagerV1>();
    connect(m_seat, &WSeat::relativePointerMotion, this, [this](uint32_t ts, QPointF d, QPointF u) {
        m_relativePointer->sendRelativeMotion(m_seat, ts, d, u);
    });
    m_server->attach<WSecurityContextManager>();
    m_server->attach<WXdgDialogManagerV1>();

    if (m_options.xwayland) {
        setupXWayland();
        xdgOutput->setFilter([this](WClient *client) {
            return !m_xwayland || client != m_xwayland->waylandClient();
        });
    }

    // The scene: layers, windows and the stand-in bar, as Items in the render window.
    m_scene = qobject_cast<QQuickItem *>(createFromModule(m_engine, "Scene", {}));
    if (!m_scene)
        return false;
    m_scene->setParentItem(m_window->contentItem());

    // The Wayland socket.
    m_socket = new WSocket(false, this);
    const QString runtime = QString::fromLocal8Bit(qgetenv("XDG_RUNTIME_DIR"));
    if (runtime.isEmpty() || !m_socket->create(QDir(runtime).filePath(m_options.socketName))) {
        std::fprintf(stderr, "luna-compositor: cannot create socket %s in %s\n",
                     qPrintable(m_options.socketName), qPrintable(runtime));
        return false;
    }
    m_server->addSocket(m_socket);
    if (m_xwayland)
        m_xwayland->setOwnsSocket(m_socket);

    if (!wlr_backend_start(m_backend->handle())) {
        std::fprintf(stderr, "luna-compositor: cannot start the backend\n");
        return false;
    }
    return true;
}

void LunaServer::setupWlrootsProtocols()
{
    wl_display *d = m_server->handle();

    // Capture: wlr-screencopy for grim and today's tools, ext-image-copy-capture for portals.
    wlr_screencopy_manager_v1_create(d);
    wlr_ext_image_copy_capture_manager_v1_create(d, 1);
    wlr_ext_output_image_capture_source_manager_v1_create(d, 1);

    // Pacing and buffers.
    wlr_presentation_create(d, m_backend->handle(), kPresentationVersion);
    wlr_viewporter_create(d);
    wlr_fractional_scale_manager_v1_create(d, kFractionalScaleVersion);
    wlr_single_pixel_buffer_manager_v1_create(d);
    wlr_alpha_modifier_v1_create(d);
    // A hint only: the compositor does not yet tear on request.
    wlr_tearing_control_manager_v1_create(d, 1);
    wlr_content_type_manager_v1_create(d, 1);

    // Clipboard managers and data control.
    wlr_data_control_manager_v1_create(d);
    wlr_ext_data_control_manager_v1_create(d, 1);

    // Output and seat helpers.
    wlr_gamma_control_manager_v1_create(d);
    wlr_output_power_manager_v1_create(d);
    wlr_virtual_pointer_manager_v1_create(d);
    wlr_keyboard_shortcuts_inhibit_v1_create(d);
    wlr_xdg_system_bell_v1_create(d, 1);
    wlr_xdg_toplevel_tag_manager_v1_create(d, 1);
    // Icons are accepted; the shell does not show them yet.
    if (auto *icons = wlr_xdg_toplevel_icon_manager_v1_create(d, 1)) {
        int iconSizes[] = {16, 24, 32, 48, 64, 128, 256};
        wlr_xdg_toplevel_icon_manager_v1_set_sizes(icons, iconSizes, std::size(iconSizes));
    }

    // xdg-foreign: a client can parent a dialog to another client's window.
    auto *registry = wlr_xdg_foreign_registry_create(d);
    wlr_xdg_foreign_v1_create(d, registry);
    wlr_xdg_foreign_v2_create(d, registry);

    // Idle: inhibitors stop the idle timer that ext-idle-notify reports.
    m_idleNotifier = wlr_idle_notifier_v1_create(d);
    m_idleInhibit = wlr_idle_inhibit_v1_create(d);
    listeners()->add(&m_idleInhibit->events.new_inhibitor, this, [this](wlr_idle_inhibitor_v1 *inhibitor) {
        wlr_idle_notifier_v1_set_inhibited(m_idleNotifier, true);
        // When the last inhibitor goes, idle notification starts again; the listener removes itself.
        struct Gone { wl_listener listener; LunaServer *server; };
        auto *gone = new Gone{{}, this};
        gone->listener.notify = [](wl_listener *l, void *) {
            Gone *g = wl_container_of(l, g, listener);
            wl_list_remove(&g->listener.link);
            LunaServer *server = g->server;
            delete g;
            QMetaObject::invokeMethod(server, [server] {
                wlr_idle_notifier_v1_set_inhibited(server->m_idleNotifier,
                                                   !wl_list_empty(&server->m_idleInhibit->inhibitors));
            }, Qt::QueuedConnection);
        };
        wl_signal_add(&inhibitor->events.destroy, &gone->listener);
    });

    // xdg-activation: a valid token raises and focuses the window.
    m_activation = wlr_xdg_activation_v1_create(d);
    listeners()->add(&m_activation->events.request_activate, this,
        [this](wlr_xdg_activation_v1_request_activate_event *event) {
            WSurface *surface = WSurface::fromHandle(event->surface);
            if (!surface)
                return;
            WToplevelSurface *toplevel = WXdgToplevelSurface::fromSurface(surface);
            if (!toplevel)
                toplevel = WXWaylandSurface::fromSurface(surface);
            if (toplevel)
                Q_EMIT activateRequested(toplevel);
        });
}

void LunaServer::setupXWayland()
{
    auto *xwaylandOutput = m_server->attach<WXdgOutputManager>(m_layout);
    xwaylandOutput->setScaleOverride(1.0);
    m_xwayland = m_server->attach<WXWayland>(m_compositor, true);
    m_xwayland->setSeat(m_seat);
    connect(m_xwayland, &WXWayland::ready, this, [this] {
        m_xwaylandReady = true;
        if (!m_workArea.isEmpty())
            m_xwayland->setWorkareas({m_workArea});
    });
    xwaylandOutput->setFilter([this](WClient *client) {
        return client == m_xwayland->waylandClient();
    });

    connect(m_xwayland, &WXWayland::surfaceAdded, this, [this](WXWaylandSurface *surface) {
        connect(surface, &WXWaylandSurface::associated, this, [this, surface] {
            enterOutputs(surface->surface());
            if (surface->isBypassManager() || surface->parentXWaylandSurface())
                Q_EMIT unmanagedAdded(surface);
            else
                addToplevel(surface, true);
        });
        connect(surface, &WXWaylandSurface::aboutToDissociate, this, [this, surface] {
            if (surface->isBypassManager() || surface->parentXWaylandSurface())
                Q_EMIT unmanagedRemoved(surface);
            else
                removeToplevel(surface);
        });
    });
}

void LunaServer::enterOutputs(WSurface *surface)
{
    // One output for now: every surface is on every output, so frame callbacks follow its refresh.
    if (!surface)
        return;
    for (WOutputItem *item : std::as_const(m_outputItems))
        surface->enterOutput(item->output());
}

void LunaServer::addToplevel(WToplevelSurface *surface, bool x11)
{
    enterOutputs(surface->surface());
    m_foreignToplevel->addSurface(surface);
    m_extForeignToplevel->addSurface(surface);
    connect(surface->surface(), &WSurface::commit, this, [this, surface] {
        const auto it = m_pendingSize.find(surface);
        if (it == m_pendingSize.end() || !surface->isInitialized())
            return;
        // Queued: the surface item answers the initial commit with a 0x0 configure first, this size wins.
        QMetaObject::invokeMethod(this, [this, surface] {
            const auto pending = m_pendingSize.find(surface);
            if (pending == m_pendingSize.end())
                return;
            const QSize size = pending.value();
            m_pendingSize.erase(pending);
            surface->resize(size);
        }, Qt::QueuedConnection);
    });
    Q_EMIT toplevelAdded(surface, x11);
}

void LunaServer::removeToplevel(WToplevelSurface *surface)
{
    m_pendingSize.remove(surface);
    m_foreignToplevel->removeSurface(surface);
    m_extForeignToplevel->removeSurface(surface);
    Q_EMIT toplevelRemoved(surface);
}

void LunaServer::addOutput(WOutput *output)
{
    // Headless and nested outputs accept any mode the backend asks for.
    output->listeners(this)->add(&output->handle()->events.request_state, this,
        [output](wlr_output_event_request_state *event) {
            if (event->state->committed & WLR_OUTPUT_STATE_MODE)
                wlr_output_commit_state(output->handle(), event->state);
        });

    auto *item = qobject_cast<WOutputItem *>(createFromModule(m_engine, "OutputDelegate", {}));
    if (!item)
        return;
    QQmlEngine::setObjectOwnership(item, QQmlEngine::CppOwnership);
    item->setOutput(output);
    item->setParentItem(m_window->contentItem());
    connect(item, &QQuickItem::widthChanged, this, &LunaServer::updateOutputRect);
    connect(item, &QQuickItem::heightChanged, this, &LunaServer::updateOutputRect);
    connect(item, &QQuickItem::xChanged, this, &LunaServer::updateOutputRect);
    connect(item, &QQuickItem::yChanged, this, &LunaServer::updateOutputRect);
    if (m_scene)
        item->stackBefore(m_scene);
    m_outputItems.append(item);

    enableOutput(output);
    m_layout->autoAdd(output);
    m_outputManager->newOutput(output);
    if (m_capture)
        m_capture->watch(output->handle());
    updateOutputRect();
}

void LunaServer::removeOutput(WOutput *output)
{
    output->removeListeners(this);
    if (m_capture)
        m_capture->unwatch(output->handle());
    m_outputManager->removeOutput(output);
    m_layout->remove(output);
    for (int i = 0; i < m_outputItems.size(); ++i) {
        if (m_outputItems.at(i)->output() == output) {
            delete m_outputItems.takeAt(i);
            break;
        }
    }
    updateOutputRect();
    // Nested: closing the last host window ends the compositor, so no process stays behind.
    if (m_outputItems.isEmpty() && backendName() == QStringLiteral("wayland"))
        QMetaObject::invokeMethod(QCoreApplication::instance(), &QCoreApplication::quit, Qt::QueuedConnection);
}

void LunaServer::enableOutput(WOutput *output)
{
    wlr_output *handle = output->handle();
    wlr_output_state state;
    wlr_output_state_init(&state);
    wlr_output_state_set_enabled(&state, true);
    if (wlr_output_is_headless(handle)) {
        // Headless outputs take the size from --size.
        wlr_output_state_set_custom_mode(&state, m_options.headlessSize.width(),
                                         m_options.headlessSize.height(), 60000);
    } else if (!handle->current_mode) {
        if (wlr_output_mode *mode = wlr_output_preferred_mode(handle))
            wlr_output_state_set_mode(&state, mode);
    }
    if (!wlr_output_commit_state(handle, &state))
        std::fprintf(stderr, "luna-compositor: cannot enable output %s\n", handle->name);
    wlr_output_state_finish(&state);
}

void LunaServer::updateOutputRect()
{
    // One output for now: the scene covers the first output.
    QRectF rect;
    if (!m_outputItems.isEmpty()) {
        WOutputItem *item = m_outputItems.first();
        rect = QRectF(item->position(), item->size());
    }
    if (rect.isEmpty())
        rect = QRectF(0, 0, m_layout->implicitWidth(), m_layout->implicitHeight());
    m_window->setWidth(m_layout->implicitWidth());
    m_window->setHeight(m_layout->implicitHeight());
    if (rect != m_outputRect) {
        m_outputRect = rect;
        Q_EMIT outputRectChanged();
    }
}

void LunaServer::setCapture(OutputCapture *capture)
{
    m_capture = capture;
    for (WOutputItem *item : std::as_const(m_outputItems))
        m_capture->watch(item->output()->handle());
}

wlr_renderer *LunaServer::renderer() const
{
    return m_renderer;
}

void LunaServer::focusItem(WSurfaceItem *item)
{
    if (!item || !item->surface()) {
        m_seat->setKeyboardFocusSurface(nullptr);
        return;
    }
    item->forceActiveFocus();
    m_seat->setKeyboardFocusSurface(item->surface());
}

void LunaServer::configureToplevel(WToplevelSurface *surface, const QSizeF &size)
{
    if (!surface)
        return;
    const QSize s = size.toSize();
    if (s.width() <= 0 || s.height() <= 0)
        return;
    if (surface->isInitialized()) {
        m_pendingSize.remove(surface);
        surface->resize(s);
    } else {
        m_pendingSize.insert(surface, s);
    }
}

void LunaServer::configureLayer(WLayerSurface *surface, const QSizeF &size)
{
    if (!surface || !surface->isInitialized())
        return;
    surface->configureSize(size.toSize());
}

bool LunaServer::isInitialized(WToplevelSurface *surface) const
{
    return surface && surface->isInitialized();
}

void LunaServer::moveX11(WXWaylandSurfaceItem *item, const QPointF &scenePos)
{
    if (item)
        item->moveTo(scenePos, true);
}

void LunaServer::resizeLockSurface(WSurfaceItem *item, const QSizeF &size)
{
    if (item)
        item->resizeSurface(size);
}

void LunaServer::setWorkArea(const QRectF &area)
{
    m_workArea = area.toRect();
    // wlroots needs a running X window manager here; a lazy Xwayland gets the area when it is ready.
    if (m_xwayland && m_xwaylandReady)
        m_xwayland->setWorkareas({m_workArea});
}

bool LunaServer::afterHandleEvent(WSeat *, WSurface *watched, QObject *, QObject *, QInputEvent *event)
{
    if (event->isSinglePointEvent() && static_cast<QSinglePointEvent *>(event)->isBeginEvent())
        Q_EMIT surfacePressed(watched);
    // Any input counts as activity for ext-idle-notify.
    if (m_idleNotifier)
        wlr_idle_notifier_v1_notify_activity(m_idleNotifier, m_seat->handle());
    return false;
}

bool LunaServer::unacceptedEvent(WSeat *, QWindow *, QInputEvent *event)
{
    if (event->isSinglePointEvent() && static_cast<QSinglePointEvent *>(event)->isBeginEvent())
        Q_EMIT emptyPressed();
    return false;
}
