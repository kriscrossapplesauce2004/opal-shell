import QtQuick
import QtQuick.Shapes

// Pixel-style seek bar: a wave for the played part while playing, a flat track for the rest, and a drag handle.
Item {
    id: sq
    property real value: 0
    property color ink: Theme.text
    property bool playing: false
    property bool seekable: true
    property real phase: 0
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))
    property bool dragging: false
    property real dragValue: 0
    signal seeked(real fraction)
    implicitHeight: 24
    NumberAnimation on phase { running: sq.playing && sq.visible && !Theme.reduceMotion; from: 0; to: 1; duration: 1600; loops: Animation.Infinite }
    // Wave points for the played part, one per pixel; flat while paused.
    function wavePoints(p, v, on, w, h) {
        const mid = h / 2, px = Math.max(6, w * v), amp = on ? 3 : 0, pts = [];
        for (let x = 3; x <= px - 6; x += 1) pts.push(Qt.point(x, mid + Math.sin((x / 24 - p) * 2 * Math.PI) * amp));
        return pts;
    }
    // Track from the playhead to the right edge, as two points.
    function trackPoints(v, w, h) {
        const mid = h / 2, px = Math.max(6, w * v);
        return [Qt.point(px + 6, mid), Qt.point(w - 3, mid)];
    }
    Shape {
        id: wave
        anchors.fill: parent
        clip: true
        preferredRendererType: Shape.CurveRenderer; antialiasing: true
        ShapePath {
            strokeColor: sq.ink; strokeWidth: 3.5; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            PathPolyline { path: sq.wavePoints(sq.phase, sq.shown, sq.playing, sq.width, sq.height) }
        }
        ShapePath {
            strokeColor: Theme.alpha(sq.ink, .3); strokeWidth: 3.5; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            PathPolyline { path: sq.trackPoints(sq.shown, sq.width, sq.height) }
        }
    }
    // Drag handle at the playhead.
    Rectangle {
        x: Math.max(6, sq.width * sq.shown) - 2; y: sq.height / 2 - 8
        width: 4; height: 16; radius: 2; color: sq.ink
    }
    MouseArea {
        anchors.fill: parent; enabled: sq.seekable; cursorShape: Qt.PointingHandCursor
        function fraction(x) { return Math.max(0, Math.min(1, x / width)); }
        onPressed: e => { sq.dragging = true; sq.dragValue = fraction(e.x); }
        onPositionChanged: e => { if (pressed) sq.dragValue = fraction(e.x); }
        onReleased: e => { sq.dragging = false; sq.seeked(fraction(e.x)); }
        onCanceled: sq.dragging = false
    }
    Accessible.role: Accessible.Slider
    Accessible.name: "Seek"
}
