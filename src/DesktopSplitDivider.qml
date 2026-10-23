import QtQuick
import Quickshell
import Quickshell.Wayland

// Coupled resize handle in the gap between snapped desktop windows in floating mode.
Scope {
    PanelWindow {
        id: divider
        readonly property var group: Hub.activeSnapGroup
        readonly property var target: group ? (Quickshell.screens.find(s => s.name === group.monitor) || Hub.chooseScreen()) : Hub.chooseScreen()
        screen: target || Quickshell.screens[0]
        visible: !!Hub.prefs.floatingMode && group !== null && Hub.page === "" && !Hub.locked
        readonly property real areaWidth: target ? target.width : 1920
        readonly property real areaHeight: target ? target.height - 72 : 1008
        readonly property real ratio: dragArea.pressed ? dragArea.liveRatio : (group ? group.ratio : .5)
        readonly property real handleWidth: 20
        anchors { top: true; bottom: true; left: true }
        margins.top: 8
        margins.bottom: 80
        margins.left: Math.round(8 + ratio * (areaWidth - 24) - handleWidth / 2)
        implicitWidth: handleWidth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "opal-snap-divider"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: dragArea.pressed ? 8 : (dragArea.containsMouse ? 6 : 4)
            height: dragArea.pressed ? 96 : (dragArea.containsMouse ? 76 : 48)
            radius: width / 2
            color: dragArea.pressed ? Theme.primary : Theme.alpha(Theme.text, dragArea.containsMouse ? .78 : .22)
            opacity: dragArea.pressed || dragArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion(150) } }
            Behavior on width { NumberAnimation { duration: Theme.motion(140); easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.motion(140); easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SplitHCursor
            property real startRatio: .5
            property real startGlobalX: 0
            property real liveRatio: .5
            onPressed: e => {
                startRatio = divider.group ? divider.group.ratio : .5;
                liveRatio = startRatio;
                startGlobalX = divider.margins.left + e.x;
            }
            onPositionChanged: e => {
                if (!pressed || !divider.group) return;
                const currentGlobalX = divider.margins.left + e.x;
                const next = Math.max(.25, Math.min(.75, startRatio + (currentGlobalX - startGlobalX) / Math.max(1, divider.areaWidth - 24)));
                if (Math.abs(next - liveRatio) >= .01) {
                    liveRatio = next;
                    Hub.resizeSnapGroup(divider.group.monitor, divider.group.workspace, next);
                }
            }
            onReleased: {
                if (divider.group) Hub.resizeSnapGroup(divider.group.monitor, divider.group.workspace, liveRatio);
            }
            onDoubleClicked: {
                if (divider.group) {
                    liveRatio = .5;
                    Hub.resizeSnapGroup(divider.group.monitor, divider.group.workspace, .5);
                }
            }
            Accessible.role: Accessible.Separator
            Accessible.name: "Snap group divider"
        }
    }
}
