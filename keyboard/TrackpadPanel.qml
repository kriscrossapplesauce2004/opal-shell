import QtQuick
import QtQuick.Layouts

// Trackpad panel: drag moves the cursor with arrow events, two fingers or latched Shift select.
Item {
    id: panel
    objectName: "trackpadPanel"
    required property var keyboard
    property real lastX: 0
    property real lastY: 0
    ColumnLayout {
        anchors.fill: parent; spacing: 4
        PanelTitle { keyboard: panel.keyboard; title: "Trackpad"; Layout.fillWidth: true; Layout.preferredHeight: 48 }
        TrackpadSurface {
            id: pad
            objectName: "trackpadSurface"
            keyboard: panel.keyboard
            Layout.fillWidth: true; Layout.fillHeight: true
            selecting: panel.keyboard.selecting || panel.keyboard.shiftState > 0
            MultiPointTouchArea {
                anchors.fill: parent
                minimumTouchPoints: 1; maximumTouchPoints: 2; mouseEnabled: true
                touchPoints: [TouchPoint { id: first }, TouchPoint { id: second }]
                function sync() {
                    const down = first.pressed || second.pressed;
                    pad.showTouch = down;
                    if (down) pad.touch = Qt.point(first.pressed ? first.x : second.x, first.pressed ? first.y : second.y);
                }
                onPressed: {
                    panel.lastX = first.pressed ? first.x : second.x; panel.lastY = first.pressed ? first.y : second.y;
                    sync();
                }
                onUpdated: {
                    sync();
                    const x = first.pressed ? first.x : second.x, y = first.pressed ? first.y : second.y;
                    // A second finger holds Shift for the whole drag.
                    panel.keyboard.trackpadSelect = first.pressed && second.pressed;
                    while (Math.abs(x - panel.lastX) >= 12) { panel.keyboard.moveCursor(x > panel.lastX ? "Right" : "Left"); panel.lastX += x > panel.lastX ? 12 : -12; }
                    while (Math.abs(y - panel.lastY) >= 22) { panel.keyboard.moveCursor(y > panel.lastY ? "Down" : "Up"); panel.lastY += y > panel.lastY ? 22 : -22; }
                }
                onReleased: { sync(); if (!first.pressed && !second.pressed) panel.keyboard.trackpadSelect = false; }
                onCanceled: { pad.showTouch = false; panel.keyboard.trackpadSelect = false; }
            }
        }
    }
}
