import QtQuick

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
    Canvas {
        id: wave
        anchors.fill: parent
        property real p: sq.phase
        property real v: sq.shown
        property bool on: sq.playing
        onPChanged: requestPaint()
        onVChanged: requestPaint()
        onOnChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const mid = height / 2, px = Math.max(6, width * v), amp = on ? 3 : 0;
            c.lineWidth = 3.5; c.lineCap = "round"; c.strokeStyle = String(sq.ink);
            c.beginPath();
            for (let x = 3; x <= px - 6; x += 1) {
                const y = mid + Math.sin((x / 24 - p) * 2 * Math.PI) * amp;
                if (x === 3) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.stroke();
            c.globalAlpha = .3; c.beginPath(); c.moveTo(px + 6, mid); c.lineTo(width - 3, mid); c.stroke();
            c.globalAlpha = 1; c.fillStyle = String(sq.ink); c.beginPath(); c.roundedRect(px - 2, mid - 8, 4, 16, 2, 2); c.fill();
        }
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
