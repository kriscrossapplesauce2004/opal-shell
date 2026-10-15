import QtQuick
import Quickshell
import Quickshell.Wayland

// Snap layouts: a small card of layouts at the top of the screen. Pick a cell and the focused window fills that part of the screen.
Scope {
    id: snap
    property bool open: false
    property real reveal: 0
    property var screen: null
    function show() { screen = Hub.chooseScreen(); open = true; grow.to = 1; grow.restart(); }
    function hide() { open = false; grow.to = 0; grow.restart(); }
    function pick(cell) { Hub.command({action: "window-snap", cell: cell}); hide(); }
    NumberAnimation { id: grow; target: snap; property: "reveal"; duration: Theme.motion(grow.to > 0 ? 300 : 160); easing.type: Easing.BezierSpline; easing.bezierCurve: grow.to > 0 ? Theme.emphasizedDecelerate : Theme.emphasizedAccelerate }
    PanelWindow {
        id: win
        screen: snap.screen || Quickshell.screens[0]
        visible: snap.open || snap.reveal > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-snap"
        WlrLayershell.keyboardFocus: snap.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        MouseArea { anchors.fill: parent; onPressed: snap.hide() }
        Item {
            anchors.fill: parent
            focus: snap.open
            Keys.onEscapePressed: snap.hide()
            SnapLayoutsCard {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24 - 16 * (1 - snap.reveal)
                opacity: snap.reveal; scale: .94 + .06 * snap.reveal
                onPicked: cell => snap.pick(cell)
            }
        }
    }
}
