import QtQuick
// Large M3 Expressive shape for hero art: set shape to morph to another polar shape, and it turns slowly while spin is on.
Item {
    id: ms
    // Lobes and depth: circle, soft burst, cookie 9, pentagon, pill, sunny, cookie 4, clover, cookie 12.
    readonly property var shapes: [[0, 0], [10, .10], [9, .16], [5, .14], [2, .22], [8, .12], [4, .2], [4, .32], [12, .08]]
    property int shape: 0
    property color fill: Theme.primaryContainer
    property color fill2: fill
    property bool spin: true
    property real spinMs: 26000
    property real squash: 1
    property int from: 0
    property int to: 0
    property real k: 1
    property real turn: 0
    onShapeChanged: { from = k < .5 ? from : to; to = shape; morph.restart(); }
    Component.onCompleted: { from = shape; to = shape; }
    NumberAnimation { id: morph; target: ms; property: "k"; from: 0; to: 1; duration: Theme.motion(720); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized }
    NumberAnimation on turn { running: ms.spin && ms.visible && !Theme.reduceMotion; from: 0; to: 360; duration: ms.spinMs; loops: Animation.Infinite }
    onKChanged: canvas.requestPaint()
    onTurnChanged: canvas.requestPaint()
    onFillChanged: canvas.requestPaint()
    onFill2Changed: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d"); c.reset();
            const a = ms.shapes[ms.from] || ms.shapes[0], b = ms.shapes[ms.to] || ms.shapes[0];
            const cx = width / 2, cy = height / 2, base = Math.min(width, height) * .5 / 1.34, off = ms.turn * Math.PI / 180;
            c.beginPath();
            for (let s = 0; s <= 240; s++) {
                const ang = s / 240 * Math.PI * 2;
                const ra = 1 + a[1] * Math.cos(a[0] * (ang - off)), rb = 1 + b[1] * Math.cos(b[0] * (ang - off));
                const r = base * (ra + (rb - ra) * ms.k);
                const x = cx + Math.cos(ang) * r, y = cy + Math.sin(ang) * r * ms.squash;
                if (s === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.closePath();
            const g = c.createLinearGradient(0, 0, width, height);
            g.addColorStop(0, ms.fill); g.addColorStop(1, ms.fill2);
            c.fillStyle = g; c.fill();
        }
    }
}
