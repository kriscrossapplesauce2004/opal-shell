import QtQuick
import QtQuick.Effects
// Tonal container. Level sets the tone; translucency only lets a little compositor blur through. The Look makes it solid per surface kind.
Rectangle {
    id: surface
    property real translucency: 1
    property bool elevated: false
    property int level: elevated ? 3 : 2
    property bool outlined: false
    // Look surface kind: panels, menus, bars, widgets, shade or lock.
    property string kind: "panels"
    property bool shadow: true
    radius: Theme.shapeXl
    color: Theme.alpha(Theme.level(level), Theme.panelAlpha(translucency, kind))
    border.width: outlined ? 1 : 0
    border.color: Theme.outline
    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
    // Elevation shadow behind the surface, when the Look asks for shadows.
    RectangularShadow {
        z: -1
        visible: surface.shadow && Theme.shadows && surface.color.a > 0
        anchors.fill: parent
        radius: surface.radius
        offset.y: surface.elevated ? 8 : 4
        blur: surface.elevated ? 28 : 18
        color: Theme.alpha("#000000", Theme.light ? .18 : .42)
    }
}
