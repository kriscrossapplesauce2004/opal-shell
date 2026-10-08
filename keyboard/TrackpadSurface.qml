import QtQuick

// Visual trackpad surface: dot grid, hint and the touch circle. It handles no input itself.
Rectangle {
    id: surface
    required property var keyboard
    property bool showTouch: false
    property point touch: Qt.point(width / 2, height / 2)
    property bool selecting: false
    radius: 26
    color: keyboard.alpha(keyboard.backgroundColor, 0.92)
    Grid {
        anchors.fill: parent; anchors.margins: 18; columns: 10
        columnSpacing: Math.max(2, (width - 10 * 6) / 9); rowSpacing: Math.max(2, (height - 4 * 6) / 3)
        Repeater { model: 40; Rectangle { width: 6; height: 6; radius: 3; color: surface.keyboard.alpha(surface.keyboard.secondaryText, 0.25) } }
    }
    Column {
        anchors.centerIn: parent; spacing: 6
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: "touchpad_mouse"; font.pixelSize: 40; color: surface.keyboard.primary }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Trackpad"; font.family: surface.keyboard.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; color: surface.keyboard.foreground }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: surface.selecting ? "Selecting text" : "Drag to move the cursor · two fingers or Shift to select"; font.family: surface.keyboard.fontFamily; font.pixelSize: 11; color: surface.keyboard.secondaryText }
    }
    Rectangle {
        visible: surface.showTouch
        x: surface.touch.x - 28; y: surface.touch.y - 28; width: 56; height: 56; radius: 28
        color: surface.keyboard.alpha(surface.keyboard.primary, 0.25); border.width: 2; border.color: surface.keyboard.primary
    }
}
