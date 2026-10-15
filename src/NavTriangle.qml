import QtQuick

// The back key: an outline triangle with the same stroke as the home circle and the recents square.
Canvas {
    id: tri
    property color ink: Theme.text
    property real stroke: 2.5
    implicitWidth: 18; implicitHeight: 18
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset();
        const s = stroke / 2 + 1;
        c.lineWidth = stroke; c.lineJoin = "round"; c.strokeStyle = String(ink);
        c.beginPath();
        c.moveTo(width - s - 1, s); c.lineTo(width - s - 1, height - s); c.lineTo(s + 1, height / 2); c.closePath();
        c.stroke();
    }
}
