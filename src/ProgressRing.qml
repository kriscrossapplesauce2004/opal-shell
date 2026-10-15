import QtQuick

// Circular progress: a faint full track and an arc for the value from 0 to 1.
Canvas {
    id: ring
    property real value: 0
    property color ink: Theme.primary
    property real lineWidth: 3
    onValueChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset();
        const r = Math.min(width, height) / 2 - lineWidth / 2 - 1;
        c.lineWidth = lineWidth; c.lineCap = "round"; c.strokeStyle = String(ink);
        c.globalAlpha = .22; c.beginPath(); c.arc(width / 2, height / 2, r, 0, 2 * Math.PI); c.stroke();
        if (value <= 0) return;
        c.globalAlpha = 1; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, value)); c.stroke();
    }
}
