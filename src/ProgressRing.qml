import QtQuick
import QtQuick.Shapes

// Circular progress: a faint full track and an arc for the value from 0 to 1.
// The arc starts at 12 o'clock and runs clockwise.
Item {
    id: ring
    property real value: 0
    property color ink: Theme.primary
    property real lineWidth: 3
    readonly property real arcR: Math.min(width, height) / 2 - lineWidth / 2 - 1
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.alpha(ring.ink, .22); strokeWidth: ring.lineWidth; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.arcR; radiusY: ring.arcR; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: ring.value > 0 ? ring.ink : "transparent"; strokeWidth: ring.lineWidth; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.arcR; radiusY: ring.arcR; startAngle: -90; sweepAngle: 360 * Math.min(1, ring.value) }
        }
    }
}
