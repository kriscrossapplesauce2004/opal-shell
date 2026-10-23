import QtQuick
// M3 Expressive switch: the handle carries a check when on and a cross when off, and grows while pressed.
Rectangle {
    id: sw
    property bool checked: false
    // A row that owns the press sets these, so the whole row presses the switch.
    property bool interactive: true
    property bool held: false
    readonly property bool down: held || mouse.pressed
    signal toggled(bool checked)
    implicitWidth: 52; implicitHeight: 32
    radius: height / 2
    color: checked ? Theme.primary : Theme.level(4)
    border.width: checked ? 0 : 2; border.color: Theme.alpha(Theme.subtext, .7)
    opacity: enabled ? 1 : .4
    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
    Rectangle {
        readonly property real size: sw.down ? 28 : 24
        width: size; height: size; radius: size / 2
        x: sw.checked ? sw.width - width - (sw.down ? 2 : 4) : (sw.down ? 2 : 4)
        anchors.verticalCenter: parent.verticalCenter
        color: sw.checked ? Theme.onPrimary : Theme.subtext
        Behavior on x { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
        Behavior on height { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
        Glyph { anchors.centerIn: parent; name: sw.checked ? "check" : "close"; font.pixelSize: 16; color: sw.checked ? Theme.primary : Theme.level(4) }
    }
    MouseArea { id: mouse; anchors.fill: parent; enabled: sw.interactive; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.checked) }
    activeFocusOnTab: interactive
    Keys.onSpacePressed: toggled(!checked)
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.onPressAction: toggled(!checked)
}
