#pragma once

#include <QHash>
#include <QMargins>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QRect>
#include <QtWaylandCompositor/QWaylandCompositorExtensionTemplate>
#include <QtWaylandCompositor/QWaylandShellSurfaceTemplate>
#include <QtWaylandCompositor/QWaylandXdgShell>
#include <QtWaylandCompositor/QWaylandOutput>
#include <QtWaylandCompositor/QWaylandSurface>

#include "qwayland-server-wlr-layer-shell-unstable-v1.h"

class LayerSurface;

// Server for zwlr_layer_shell_v1: shell surfaces in layers around the windows, arranged per output.
class LayerShell : public QWaylandCompositorExtensionTemplate<LayerShell>, public QtWaylandServer::zwlr_layer_shell_v1,
                   public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QWaylandXdgShell *xdgShell READ xdgShell WRITE setXdgShell NOTIFY xdgShellChanged)
    Q_PROPERTY(QRect usableArea READ usableArea NOTIFY usableAreaChanged)
    Q_PROPERTY(LayerSurface *exclusiveFocus READ exclusiveFocus NOTIFY exclusiveFocusChanged)

public:
    enum Layer { Background = 0, Bottom = 1, Top = 2, Overlay = 3 };
    Q_ENUM(Layer)

    LayerShell();
    explicit LayerShell(QWaylandCompositor *compositor);

    void initialize() override;
    // QML creates the object without a container; initialize once the compositor parent is set.
    void classBegin() override {}
    void componentComplete() override
    {
        if (!isInitialized())
            initialize();
    }

    QWaylandXdgShell *xdgShell() const { return m_xdgShell; }
    void setXdgShell(QWaylandXdgShell *shell);

    // Area of the default output that no exclusive zone covers; windows tile here.
    QRect usableArea() const;
    Q_INVOKABLE QRect usableAreaFor(QWaylandOutput *output) const;

    // The topmost mapped surface in the top or overlay layer that asks for exclusive keyboard focus.
    LayerSurface *exclusiveFocus() const { return m_exclusiveFocus; }

    // Lays out every surface on the output again and sends new sizes.
    Q_INVOKABLE void arrange(QWaylandOutput *output);
    Q_INVOKABLE void arrangeAll();

    QWaylandCompositor *compositor() const;
    QWaylandOutput *resolveOutput(QWaylandOutput *output) const;
    void surfaceChanged(LayerSurface *surface);
    void surfaceGone(LayerSurface *surface);

    // A null-parent xdg_popup waits here until a layer surface claims it.
    QWaylandXdgPopup *takeOrphanPopup(wl_resource *popupResource);
    void addOrphanPopup(wl_client *client, uint32_t id);
    QWaylandXdgSurface *placeholderParent(wl_client *client);

    static constexpr int protocolVersion = 4;

signals:
    void xdgShellChanged();
    void usableAreaChanged();
    void exclusiveFocusChanged();
    void layerSurfaceCreated(LayerSurface *layerSurface);

protected:
    void zwlr_layer_shell_v1_get_layer_surface(Resource *resource, uint32_t id, wl_resource *surface,
                                               wl_resource *output, uint32_t layer, const QString &nameSpace) override;
    void zwlr_layer_shell_v1_destroy(Resource *resource) override;

private:
    void hookXdgSurface(QWaylandXdgSurface *xdgSurface);
    void updateExclusiveFocus();

    QPointer<QWaylandXdgShell> m_xdgShell;
    QList<LayerSurface *> m_surfaces;
    QHash<QWaylandOutput *, QRect> m_usable;
    QPointer<LayerSurface> m_exclusiveFocus;
    QHash<wl_client *, QPointer<QWaylandXdgSurface>> m_placeholders;
    QHash<wl_client *, QList<uint32_t>> m_orphans;
};

// One zwlr_layer_surface_v1: double-buffered state, the arranged rectangle and the configure sequence.
class LayerSurface : public QWaylandShellSurfaceTemplate<LayerSurface>, public QtWaylandServer::zwlr_layer_surface_v1
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by LayerShell")
    Q_PROPERTY(QWaylandSurface *surface READ surface CONSTANT)
    Q_PROPERTY(QWaylandOutput *output READ output CONSTANT)
    Q_PROPERTY(QString nameSpace READ nameSpace CONSTANT)
    Q_PROPERTY(int layer READ layer NOTIFY layerChanged)
    Q_PROPERTY(int keyboardInteractivity READ keyboardInteractivity NOTIFY keyboardInteractivityChanged)
    Q_PROPERTY(int exclusiveZone READ exclusiveZone NOTIFY stateChanged)
    Q_PROPERTY(int anchors READ anchors NOTIFY stateChanged)
    Q_PROPERTY(QRect geometry READ geometry NOTIFY geometryChanged)
    Q_PROPERTY(bool mapped READ mapped NOTIFY mappedChanged)

public:
    enum Interactivity { InteractivityNone = 0, InteractivityExclusive = 1, InteractivityOnDemand = 2 };
    Q_ENUM(Interactivity)

    struct State {
        QSize size;
        uint32_t anchors = 0;
        int exclusiveZone = 0;
        QMargins margins;
        int keyboard = 0;
        int layer = 0;
    };

    LayerSurface(LayerShell *shell, QWaylandSurface *surface, QWaylandOutput *output, int layer,
                 const QString &nameSpace, const QWaylandResource &resource);
    ~LayerSurface() override;

    QWaylandQuickShellIntegration *createIntegration(QWaylandQuickShellSurfaceItem *item) override;

    QWaylandSurface *surface() const { return m_surface; }
    QWaylandOutput *output() const { return m_output; }
    QString nameSpace() const { return m_nameSpace; }
    int layer() const { return m_current.layer; }
    int keyboardInteractivity() const { return m_current.keyboard; }
    int exclusiveZone() const { return m_current.exclusiveZone; }
    int anchors() const { return static_cast<int>(m_current.anchors); }
    QRect geometry() const { return m_geometry; }
    bool mapped() const { return m_mapped; }
    bool initialized() const { return m_initialized; }
    const State &current() const { return m_current; }

    // Sets the arranged rectangle; sends configure if the size changed.
    void place(const QRect &rect);

    // Tells the client the surface is gone, for example when its output goes away.
    Q_INVOKABLE void close();

    static QWaylandSurfaceRole *role() { return &s_role; }

signals:
    void layerChanged();
    void keyboardInteractivityChanged();
    void stateChanged();
    void geometryChanged();
    void mappedChanged();
    void popupCreated(QWaylandXdgPopup *popup, QWaylandXdgSurface *xdgSurface);

protected:
    void zwlr_layer_surface_v1_set_size(Resource *resource, uint32_t width, uint32_t height) override;
    void zwlr_layer_surface_v1_set_anchor(Resource *resource, uint32_t anchor) override;
    void zwlr_layer_surface_v1_set_exclusive_zone(Resource *resource, int32_t zone) override;
    void zwlr_layer_surface_v1_set_margin(Resource *resource, int32_t top, int32_t right, int32_t bottom,
                                          int32_t left) override;
    void zwlr_layer_surface_v1_set_keyboard_interactivity(Resource *resource, uint32_t interactivity) override;
    void zwlr_layer_surface_v1_get_popup(Resource *resource, wl_resource *popup) override;
    void zwlr_layer_surface_v1_ack_configure(Resource *resource, uint32_t serial) override;
    void zwlr_layer_surface_v1_destroy(Resource *resource) override;
    void zwlr_layer_surface_v1_set_layer(Resource *resource, uint32_t layer) override;
    void zwlr_layer_surface_v1_destroy_resource(Resource *resource) override;

private:
    void handleCommit();
    void sendConfigure(const QSize &size);

    QPointer<LayerShell> m_shell;
    QPointer<QWaylandSurface> m_surface;
    QPointer<QWaylandOutput> m_output;
    QString m_nameSpace;
    State m_pending;
    State m_current;
    QRect m_geometry;
    QSize m_configuredSize;
    QList<uint32_t> m_pendingSerials;
    bool m_initialized = false;
    bool m_configured = false;
    bool m_mapped = false;
    bool m_closed = false;

    static QWaylandSurfaceRole s_role;
};
