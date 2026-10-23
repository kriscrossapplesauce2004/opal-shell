import QtQuick
// M3 Expressive split button: the main action and a separate menu half. The menu chevron turns while the menu is open.
Row {
    id: split
    property string icon: ""
    property string text: ""
    property bool tonal: false
    property bool open: false
    property real buttonHeight: 40
    signal clicked()
    signal menuRequested()
    spacing: 2
    readonly property color fillColor: tonal ? Theme.secondaryContainer : Theme.primary
    readonly property color ink: tonal ? Theme.onSecondaryContainer : Theme.onPrimary
    Rectangle {
        width: label.implicitWidth + (glyph.visible ? glyph.width + 8 : 0) + 32; height: split.buttonHeight
        topLeftRadius: height / 2; bottomLeftRadius: height / 2; topRightRadius: 4; bottomRightRadius: 4
        color: split.fillColor
        Rectangle { anchors.fill: parent; topLeftRadius: parent.topLeftRadius; bottomLeftRadius: parent.bottomLeftRadius; topRightRadius: 4; bottomRightRadius: 4; color: split.ink; opacity: mainMouse.pressed ? .12 : mainMouse.containsMouse ? .08 : 0 }
        Row {
            anchors.centerIn: parent; spacing: 8
            Glyph { id: glyph; visible: split.icon !== ""; name: split.icon; font.pixelSize: 20; color: split.ink; anchors.verticalCenter: parent.verticalCenter }
            MText { id: label; text: split.text; role: "label"; color: split.ink; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: mainMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: split.clicked() }
        Accessible.role: Accessible.Button; Accessible.name: split.text; Accessible.onPressAction: split.clicked()
    }
    Rectangle {
        width: split.buttonHeight; height: split.buttonHeight
        // The menu half rounds fully while its menu is open.
        topLeftRadius: split.open ? height / 2 : 4; bottomLeftRadius: topLeftRadius; topRightRadius: height / 2; bottomRightRadius: height / 2
        Behavior on topLeftRadius { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        color: split.fillColor
        Rectangle { anchors.fill: parent; radius: parent.topRightRadius; color: split.ink; opacity: menuMouse.pressed ? .12 : menuMouse.containsMouse ? .08 : 0 }
        Glyph { anchors.centerIn: parent; anchors.horizontalCenterOffset: split.open ? 0 : -1; name: "keyboard_arrow_down"; rotation: split.open ? 180 : 0; font.pixelSize: 20; color: split.ink
            Behavior on rotation { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } } }
        MouseArea { id: menuMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: split.menuRequested() }
        Accessible.role: Accessible.ButtonMenu; Accessible.name: split.text + " options"; Accessible.onPressAction: split.menuRequested()
    }
}
