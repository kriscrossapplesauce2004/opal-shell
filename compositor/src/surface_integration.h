#pragma once

#include <QtWaylandCompositor/QWaylandQuickShellIntegration>
#include <QtWaylandCompositor/QWaylandQuickShellSurfaceItem>
#include <QtWaylandCompositor/QWaylandSurface>

// Item glue for our own shell surfaces: the item shows the wl_surface and does nothing else.
class SurfaceOnlyIntegration : public QWaylandQuickShellIntegration
{
public:
    SurfaceOnlyIntegration(QWaylandQuickShellSurfaceItem *item, QWaylandSurface *surface)
        : QWaylandQuickShellIntegration(item)
    {
        item->setSurface(surface);
    }
};
