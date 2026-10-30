#include "layer_shell.h"
#include "surface_integration.h"

#include <QLoggingCategory>
#include <QtWaylandCompositor/QWaylandClient>
#include <QtWaylandCompositor/QWaylandCompositor>
#include <QtWaylandCompositor/QWaylandOutput>
#include <QtWaylandCompositor/QWaylandQuickShellIntegration>
#include <QtWaylandCompositor/QWaylandQuickShellSurfaceItem>
#include <QtWaylandCompositor/QWaylandResource>
#include <QtWaylandCompositor/QWaylandSurface>
#include <QtWaylandCompositor/private/qwaylandquickshellsurfaceitem_p.h>
#include <QtWaylandCompositor/private/qwaylandxdgshell_p.h>

#include <wayland-server-core.h>
#include <wayland-server-protocol.h>

Q_LOGGING_CATEGORY(lcLayer, "luna.layershell", QtWarningMsg)

QWaylandSurfaceRole LayerSurface::s_role("zwlr_layer_surface_v1");

namespace {

using Anchor = QtWaylandServer::zwlr_layer_surface_v1::anchor;
constexpr uint32_t AnchorTop = QtWaylandServer::zwlr_layer_surface_v1::anchor_top;
constexpr uint32_t AnchorBottom = QtWaylandServer::zwlr_layer_surface_v1::anchor_bottom;
constexpr uint32_t AnchorLeft = QtWaylandServer::zwlr_layer_surface_v1::anchor_left;
constexpr uint32_t AnchorRight = QtWaylandServer::zwlr_layer_surface_v1::anchor_right;
constexpr uint32_t BothHorizontal = AnchorLeft | AnchorRight;
constexpr uint32_t BothVertical = AnchorTop | AnchorBottom;

// The head of libwayland's struct wl_resource: object, then destroy. Stable since libwayland 1.0.
struct ResourceHead {
    const wl_interface *interface;
    const void *implementation;
    uint32_t id;
    wl_resource_destroy_func_t destroy;
};

QPointer<LayerShell> s_layerShell;

// Calls Qt's xdg_surface handler; a get_popup with a null parent gets a stand-in parent first.
int xdgSurfaceDispatcher(const void *implementation, void *target, uint32_t opcode, const wl_message *,
                         wl_argument *args)
{
    const auto *impl = static_cast<const struct xdg_surface_interface *>(implementation);
    auto *resource = static_cast<wl_resource *>(target);
    wl_client *client = wl_resource_get_client(resource);
    auto object = [](const wl_argument &a) { return reinterpret_cast<wl_resource *>(a.o); };
    switch (opcode) {
    case 0:
        impl->destroy(client, resource);
        break;
    case 1:
        impl->get_toplevel(client, resource, args[0].n);
        break;
    case 2: {
        wl_resource *parent = object(args[1]);
        if (!parent && s_layerShell) {
            QWaylandXdgSurface *standIn = s_layerShell->placeholderParent(client);
            wl_resource *standInResource =
                standIn ? QWaylandXdgSurfacePrivate::get(standIn)->resource()->handle : nullptr;
            impl->get_popup(client, resource, args[0].n, standInResource, object(args[2]));
            s_layerShell->addOrphanPopup(client, args[0].n);
        } else {
            impl->get_popup(client, resource, args[0].n, parent, object(args[2]));
        }
        break;
    }
    case 3:
        impl->set_window_geometry(client, resource, args[0].i, args[1].i, args[2].i, args[3].i);
        break;
    case 4:
        impl->ack_configure(client, resource, args[0].u);
        break;
    default:
        wl_resource_post_error(resource, WL_DISPLAY_ERROR_INVALID_METHOD, "unknown xdg_surface request %u", opcode);
        break;
    }
    return 0;
}

// Returns the edge that an exclusive zone pushes in from, or 0 if the anchors give none.
uint32_t exclusiveEdge(uint32_t anchors)
{
    switch (anchors) {
    case AnchorTop:
    case AnchorTop | BothHorizontal:
        return AnchorTop;
    case AnchorBottom:
    case AnchorBottom | BothHorizontal:
        return AnchorBottom;
    case AnchorLeft:
    case AnchorLeft | BothVertical:
        return AnchorLeft;
    case AnchorRight:
    case AnchorRight | BothVertical:
        return AnchorRight;
    default:
        return 0;
    }
}

// Same placement rules as wlroots' scene helper: anchors pick the side, margins push in, zero size stretches.
QRect layoutBox(const LayerSurface::State &s, const QRect &bounds)
{
    int x = 0;
    int y = 0;
    int w = s.size.width();
    int h = s.size.height();
    const uint32_t a = s.anchors;

    if (w == 0)
        x = bounds.x();
    else if ((a & BothHorizontal) == BothHorizontal)
        x = bounds.x() + (bounds.width() - w) / 2;
    else if (a & AnchorLeft)
        x = bounds.x();
    else if (a & AnchorRight)
        x = bounds.x() + bounds.width() - w;
    else
        x = bounds.x() + (bounds.width() - w) / 2;

    if (h == 0)
        y = bounds.y();
    else if ((a & BothVertical) == BothVertical)
        y = bounds.y() + (bounds.height() - h) / 2;
    else if (a & AnchorTop)
        y = bounds.y();
    else if (a & AnchorBottom)
        y = bounds.y() + bounds.height() - h;
    else
        y = bounds.y() + (bounds.height() - h) / 2;

    if (w == 0) {
        x += s.margins.left();
        w = bounds.width() - s.margins.left() - s.margins.right();
    } else if ((a & BothHorizontal) != BothHorizontal) {
        if (a & AnchorLeft)
            x += s.margins.left();
        else if (a & AnchorRight)
            x -= s.margins.right();
    }
    if (h == 0) {
        y += s.margins.top();
        h = bounds.height() - s.margins.top() - s.margins.bottom();
    } else if ((a & BothVertical) != BothVertical) {
        if (a & AnchorTop)
            y += s.margins.top();
        else if (a & AnchorBottom)
            y -= s.margins.bottom();
    }
    return QRect(x, y, std::max(1, w), std::max(1, h));
}

// Takes the exclusive zone of one surface out of the usable area.
void applyExclusive(QRect &usable, const LayerSurface::State &s)
{
    if (s.exclusiveZone <= 0)
        return;
    switch (exclusiveEdge(s.anchors)) {
    case AnchorTop: {
        const int d = s.exclusiveZone + s.margins.top();
        usable.setTop(usable.top() + d);
        break;
    }
    case AnchorBottom:
        usable.setBottom(usable.bottom() - (s.exclusiveZone + s.margins.bottom()));
        break;
    case AnchorLeft:
        usable.setLeft(usable.left() + s.exclusiveZone + s.margins.left());
        break;
    case AnchorRight:
        usable.setRight(usable.right() - (s.exclusiveZone + s.margins.right()));
        break;
    default:
        break;
    }
}

}

// ---------- LayerShell ----------

LayerShell::LayerShell() = default;

LayerShell::LayerShell(QWaylandCompositor *compositor)
    : QWaylandCompositorExtensionTemplate<LayerShell>(compositor)
{
}

QWaylandCompositor *LayerShell::compositor() const
{
    return qobject_cast<QWaylandCompositor *>(extensionContainer());
}

void LayerShell::initialize()
{
    QWaylandCompositorExtensionTemplate::initialize();
    QWaylandCompositor *c = compositor();
    if (!c) {
        qWarning("LayerShell: no compositor; add it inside WaylandCompositor");
        return;
    }
    init(c->display(), protocolVersion);
    s_layerShell = this;

    auto watchOutput = [this](QWaylandOutput *output) {
        connect(output, &QWaylandOutput::geometryChanged, this, [this, output] { arrange(output); });
    };
    for (QWaylandOutput *output : c->outputs())
        watchOutput(output);
    connect(c, &QWaylandCompositor::outputAdded, this, watchOutput);
    connect(c, &QWaylandCompositor::outputRemoved, this, [this](QWaylandOutput *output) {
        m_usable.remove(output);
        for (LayerSurface *s : std::as_const(m_surfaces)) {
            if (s->output() == output)
                s->close();
        }
    });
}

void LayerShell::setXdgShell(QWaylandXdgShell *shell)
{
    if (m_xdgShell == shell)
        return;
    if (m_xdgShell)
        disconnect(m_xdgShell, nullptr, this, nullptr);
    m_xdgShell = shell;
    if (shell)
        connect(shell, &QWaylandXdgShell::xdgSurfaceCreated, this, &LayerShell::hookXdgSurface);
    emit xdgShellChanged();
}

void LayerShell::hookXdgSurface(QWaylandXdgSurface *xdgSurface)
{
    auto *priv = QWaylandXdgSurfacePrivate::get(xdgSurface);
    if (!priv->resource() || !priv->resource()->handle)
        return;
    wl_resource *resource = priv->resource()->handle;
    // Qt's handlers check the implementation pointer, so it stays; only the dispatch goes through us.
    const auto *head = reinterpret_cast<const ResourceHead *>(resource);
    wl_resource_set_dispatcher(resource, xdgSurfaceDispatcher, head->implementation,
                               wl_resource_get_user_data(resource), head->destroy);
}

QWaylandXdgSurface *LayerShell::placeholderParent(wl_client *client)
{
    if (auto existing = m_placeholders.value(client))
        return existing;
    QWaylandCompositor *c = compositor();
    if (!c || !m_xdgShell)
        return nullptr;
    QWaylandClient *qclient = QWaylandClient::fromWlClient(c, client);
    // Server-side objects with server ids; the client never sees them.
    auto *surface = new QWaylandSurface(c, qclient, 0, 4);
    wl_resource *res = wl_resource_create(client, &xdg_surface_interface, 1, 0);
    if (!res) {
        delete surface;
        return nullptr;
    }
    auto *standIn = new QWaylandXdgSurface(m_xdgShell, surface, QWaylandResource(res));
    m_placeholders.insert(client, standIn);
    return standIn;
}

void LayerShell::addOrphanPopup(wl_client *client, uint32_t id)
{
    m_orphans[client].append(id);
}

QWaylandXdgPopup *LayerShell::takeOrphanPopup(wl_resource *popupResource)
{
    wl_client *client = wl_resource_get_client(popupResource);
    const uint32_t id = wl_resource_get_id(popupResource);
    auto it = m_orphans.find(client);
    if (it == m_orphans.end() || !it->removeOne(id))
        return nullptr;
    auto *r = QtWaylandServer::xdg_popup::Resource::fromResource(popupResource);
    if (!r || !r->xdg_popup_object)
        return nullptr;
    auto *priv = static_cast<QWaylandXdgPopupPrivate *>(r->xdg_popup_object);
    return static_cast<QWaylandXdgPopup *>(priv->q_ptr);
}

QWaylandOutput *LayerShell::resolveOutput(QWaylandOutput *output) const
{
    if (output)
        return output;
    QWaylandCompositor *c = compositor();
    return c ? c->defaultOutput() : nullptr;
}

QRect LayerShell::usableArea() const
{
    QWaylandCompositor *c = compositor();
    return c ? usableAreaFor(c->defaultOutput()) : QRect();
}

QRect LayerShell::usableAreaFor(QWaylandOutput *output) const
{
    if (!output)
        return QRect();
    auto it = m_usable.constFind(output);
    if (it != m_usable.constEnd())
        return *it;
    return QRect(QPoint(0, 0), output->geometry().size());
}

void LayerShell::arrangeAll()
{
    QWaylandCompositor *c = compositor();
    if (!c)
        return;
    for (QWaylandOutput *output : c->outputs())
        arrange(output);
}

void LayerShell::arrange(QWaylandOutput *output)
{
    if (!output)
        return;
    // Output-local coordinates: the layer containers sit at the output origin.
    const QRect full(QPoint(0, 0), output->geometry().size());
    QRect usable = full;
    static constexpr int order[] = {Overlay, Top, Bottom, Background};

    for (bool exclusivePass : {true, false}) {
        for (int layer : order) {
            for (LayerSurface *s : std::as_const(m_surfaces)) {
                if (s->output() != output || !s->initialized() || s->layer() != layer)
                    continue;
                const auto &state = s->current();
                if ((state.exclusiveZone > 0) != exclusivePass)
                    continue;
                const QRect bounds = state.exclusiveZone == -1 ? full : usable;
                s->place(layoutBox(state, bounds));
                if (exclusivePass)
                    applyExclusive(usable, state);
            }
        }
    }

    const QRect old = usableAreaFor(output);
    m_usable.insert(output, usable);
    QWaylandCompositor *c = compositor();
    if (old != usable && c && output == c->defaultOutput())
        emit usableAreaChanged();
    updateExclusiveFocus();
}

void LayerShell::surfaceChanged(LayerSurface *surface)
{
    arrange(surface->output());
}

void LayerShell::surfaceGone(LayerSurface *surface)
{
    m_surfaces.removeAll(surface);
    if (surface->output())
        arrange(surface->output());
    else
        updateExclusiveFocus();
}

void LayerShell::updateExclusiveFocus()
{
    LayerSurface *best = nullptr;
    for (LayerSurface *s : std::as_const(m_surfaces)) {
        if (!s->mapped() || s->keyboardInteractivity() != LayerSurface::InteractivityExclusive || s->layer() < Top)
            continue;
        if (!best || s->layer() >= best->layer())
            best = s;
    }
    if (best != m_exclusiveFocus) {
        m_exclusiveFocus = best;
        emit exclusiveFocusChanged();
    }
}

void LayerShell::zwlr_layer_shell_v1_get_layer_surface(Resource *resource, uint32_t id, wl_resource *surfaceResource,
                                                       wl_resource *outputResource, uint32_t layer,
                                                       const QString &nameSpace)
{
    QWaylandSurface *surface = QWaylandSurface::fromResource(surfaceResource);
    if (!surface) {
        wl_resource_post_error(resource->handle, WL_DISPLAY_ERROR_INVALID_OBJECT, "no wl_surface");
        return;
    }
    if (layer > Overlay) {
        wl_resource_post_error(resource->handle, error_invalid_layer, "invalid layer %u", layer);
        return;
    }
    if (!surface->setRole(LayerSurface::role(), resource->handle, error_role))
        return;
    QWaylandOutput *output = outputResource ? QWaylandOutput::fromResource(outputResource) : nullptr;
    QWaylandResource res(wl_resource_create(resource->client(), &::zwlr_layer_surface_v1_interface,
                                            wl_resource_get_version(resource->handle), id));
    auto *layerSurface = new LayerSurface(this, surface, resolveOutput(output), static_cast<int>(layer), nameSpace, res);
    m_surfaces.append(layerSurface);
    qCInfo(lcLayer) << "layer surface" << nameSpace << "layer" << layer;
    emit layerSurfaceCreated(layerSurface);
}

void LayerShell::zwlr_layer_shell_v1_destroy(Resource *resource)
{
    wl_resource_destroy(resource->handle);
}

// ---------- LayerSurface ----------

LayerSurface::LayerSurface(LayerShell *shell, QWaylandSurface *surface, QWaylandOutput *output, int layer,
                           const QString &nameSpace, const QWaylandResource &resource)
    : QWaylandShellSurfaceTemplate<LayerSurface>(surface)
    , m_shell(shell)
    , m_surface(surface)
    , m_output(output)
    , m_nameSpace(nameSpace)
{
    m_pending.layer = layer;
    m_current.layer = layer;
    init(resource.resource());
    connect(surface, &QWaylandSurface::redraw, this, &LayerSurface::handleCommit);
    connect(surface, &QWaylandSurface::surfaceDestroyed, this, [this] {
        if (m_mapped) {
            m_mapped = false;
            emit mappedChanged();
        }
    });
}

LayerSurface::~LayerSurface()
{
    if (m_shell)
        m_shell->surfaceGone(this);
}

QWaylandQuickShellIntegration *LayerSurface::createIntegration(QWaylandQuickShellSurfaceItem *item)
{
    return new SurfaceOnlyIntegration(item, m_surface);
}

void LayerSurface::handleCommit()
{
    if (m_closed || !m_surface)
        return;
    const State &p = m_pending;
    if (p.size.width() == 0 && (p.anchors & BothHorizontal) != BothHorizontal) {
        wl_resource_post_error(resource()->handle, error_invalid_size, "width 0 needs left and right anchors");
        return;
    }
    if (p.size.height() == 0 && (p.anchors & BothVertical) != BothVertical) {
        wl_resource_post_error(resource()->handle, error_invalid_size, "height 0 needs top and bottom anchors");
        return;
    }

    const State old = m_current;
    m_current = m_pending;
    const bool hasBuffer = m_surface->hasContent();

    if (!m_initialized) {
        // Initial commit: lay out and send the first configure.
        m_initialized = true;
        m_shell->surfaceChanged(this);
    } else if (m_mapped && !hasBuffer) {
        // Null buffer: unmap; the client must commit again without a buffer to get a new configure.
        m_mapped = false;
        m_initialized = false;
        m_configured = false;
        m_configuredSize = QSize();
        emit mappedChanged();
        m_shell->surfaceChanged(this);
    } else {
        const bool layoutChanged = old.size != m_current.size || old.anchors != m_current.anchors
            || old.exclusiveZone != m_current.exclusiveZone || old.margins != m_current.margins
            || old.layer != m_current.layer;
        if (!m_mapped && hasBuffer && m_configured) {
            m_mapped = true;
            emit mappedChanged();
            m_shell->surfaceChanged(this);
        } else if (layoutChanged || old.keyboard != m_current.keyboard) {
            m_shell->surfaceChanged(this);
        }
    }

    if (old.layer != m_current.layer)
        emit layerChanged();
    if (old.keyboard != m_current.keyboard)
        emit keyboardInteractivityChanged();
    if (old.anchors != m_current.anchors || old.exclusiveZone != m_current.exclusiveZone)
        emit stateChanged();
}

void LayerSurface::place(const QRect &rect)
{
    if (rect != m_geometry) {
        m_geometry = rect;
        emit geometryChanged();
    }
    if (!m_configured || rect.size() != m_configuredSize)
        sendConfigure(rect.size());
}

void LayerSurface::sendConfigure(const QSize &size)
{
    if (m_closed || !resource())
        return;
    QWaylandCompositor *c = m_shell ? m_shell->compositor() : nullptr;
    const uint32_t serial = c ? c->nextSerial() : 0;
    m_pendingSerials.append(serial);
    m_configured = true;
    m_configuredSize = size;
    send_configure(serial, static_cast<uint32_t>(size.width()), static_cast<uint32_t>(size.height()));
}

void LayerSurface::close()
{
    if (m_closed || !resource())
        return;
    m_closed = true;
    send_closed();
}

void LayerSurface::zwlr_layer_surface_v1_set_size(Resource *, uint32_t width, uint32_t height)
{
    m_pending.size = QSize(static_cast<int>(width), static_cast<int>(height));
}

void LayerSurface::zwlr_layer_surface_v1_set_anchor(Resource *resource, uint32_t anchor)
{
    if (anchor > (BothHorizontal | BothVertical)) {
        wl_resource_post_error(resource->handle, error_invalid_anchor, "invalid anchor %u", anchor);
        return;
    }
    m_pending.anchors = anchor;
}

void LayerSurface::zwlr_layer_surface_v1_set_exclusive_zone(Resource *, int32_t zone)
{
    m_pending.exclusiveZone = zone;
}

void LayerSurface::zwlr_layer_surface_v1_set_margin(Resource *, int32_t top, int32_t right, int32_t bottom, int32_t left)
{
    m_pending.margins = QMargins(left, top, right, bottom);
}

void LayerSurface::zwlr_layer_surface_v1_set_keyboard_interactivity(Resource *resource, uint32_t interactivity)
{
    if (interactivity > keyboard_interactivity_on_demand) {
        wl_resource_post_error(resource->handle, error_invalid_keyboard_interactivity,
                               "invalid keyboard interactivity %u", interactivity);
        return;
    }
    m_pending.keyboard = static_cast<int>(interactivity);
}

void LayerSurface::zwlr_layer_surface_v1_get_popup(Resource *, wl_resource *popupResource)
{
    QWaylandXdgPopup *popup = m_shell ? m_shell->takeOrphanPopup(popupResource) : nullptr;
    if (!popup) {
        qCWarning(lcLayer) << "get_popup: popup was not created with a null parent";
        return;
    }
    // A press outside the client's surfaces dismisses the popup, as with Qt's own popup items.
    if (m_surface && m_surface->client()) {
        QPointer<QWaylandXdgPopup> guard(popup);
        QWaylandQuickShellEventFilter::startFilter(m_surface->client(), [guard] {
            if (guard)
                guard->sendPopupDone();
        });
    }
    emit popupCreated(popup, popup->xdgSurface());
}

void LayerSurface::zwlr_layer_surface_v1_ack_configure(Resource *resource, uint32_t serial)
{
    const qsizetype index = m_pendingSerials.indexOf(serial);
    if (index < 0) {
        wl_resource_post_error(resource->handle, error_invalid_surface_state, "wrong configure serial %u", serial);
        return;
    }
    m_pendingSerials.remove(0, index + 1);
}

void LayerSurface::zwlr_layer_surface_v1_destroy(Resource *resource)
{
    wl_resource_destroy(resource->handle);
}

void LayerSurface::zwlr_layer_surface_v1_set_layer(Resource *resource, uint32_t layer)
{
    if (layer > LayerShell::Overlay) {
        wl_resource_post_error(resource->handle, QtWaylandServer::zwlr_layer_shell_v1::error_invalid_layer,
                               "invalid layer %u", layer);
        return;
    }
    m_pending.layer = static_cast<int>(layer);
}

void LayerSurface::zwlr_layer_surface_v1_destroy_resource(Resource *)
{
    m_closed = true;
    m_initialized = false;
    if (m_mapped) {
        m_mapped = false;
        emit mappedChanged();
    }
    if (m_shell) {
        m_shell->surfaceGone(this);
        m_shell = nullptr;
    }
    deleteLater();
}
