import QtQuick
import QtQuick.Shapes

// The back key: an outline triangle with the same stroke as the home circle and the recents square.
Item {
    id: tri
    property color ink: Theme.text
    property real stroke: 2.5
    readonly property real inset: stroke / 2 + 1
    implicitWidth: 18; implicitHeight: 18
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: tri.ink; strokeWidth: tri.stroke; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M " + (tri.width - tri.inset - 1) + " " + tri.inset + " L " + (tri.width - tri.inset - 1) + " " + (tri.height - tri.inset) + " L " + (tri.inset + 1) + " " + (tri.height / 2) + " Z"
            }
        }
    }
}
