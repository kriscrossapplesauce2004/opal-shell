import QtQuick
import Quickshell
import Quickshell.Wayland
// Draggable divider between the two windows of a split view. Side by side on a wide screen, one above the other on a phone. The handle is large enough for a pen or a finger.
Scope {
    PanelWindow {
        id: divider
        readonly property var target: PhoneState.splitScreen
        screen: target || Quickshell.screens[0]
        visible: PhoneState.splitActive && target !== null
        readonly property real areaWidth: target ? target.width : 0
        readonly property real areaHeight: target ? target.height - PhoneState.barHeight - PhoneState.navFor(target) : 0
        // A tall area splits top and bottom, the same rule as phone_windows.split_rects.
        readonly property bool tall: areaHeight > areaWidth
        readonly property real span: tall ? areaHeight : areaWidth
        readonly property real handleSize: PhoneState.pen ? 40 : 32
        anchors { top: true; bottom: !tall; left: true; right: tall }
        // The window sits over the gap and follows the ratio while dragging.
        property real frozen: -1
        readonly property real offset: frozen >= 0 ? frozen : Math.round((span - 8) * PhoneState.splitRatio + 4 - handleSize / 2)
        margins.top: tall ? PhoneState.barHeight + offset : PhoneState.barHeight
        margins.bottom: tall ? 0 : PhoneState.navFor(target)
        margins.left: tall ? 0 : offset
        implicitWidth: tall ? 0 : handleSize
        implicitHeight: tall ? handleSize : 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "opal-split"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        // The gap between the two windows, along the whole divider, with the grip on it.
        Rectangle {
            anchors.centerIn: parent
            width: divider.tall ? parent.width : 8; height: divider.tall ? 8 : parent.height; color: Theme.base
        }
        Rectangle {
            id: grip
            readonly property real moved: area.pressed ? (PhoneState.splitRatio - area.startRatio) * (divider.span - 8) : 0
            x: divider.tall ? (parent.width - width) / 2 : (parent.width - width) / 2 + moved
            y: divider.tall ? (parent.height - height) / 2 + moved : (parent.height - height) / 2
            readonly property real thick: area.pressed ? 10 : 6
            readonly property real long: area.pressed ? 96 : 72
            width: divider.tall ? long : thick; height: divider.tall ? thick : long; radius: Math.min(width, height) / 2
            color: area.pressed ? Theme.primary : Theme.alpha(Theme.text, .7)
            Behavior on width { NumberAnimation { duration: Theme.motion(140); easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.motion(140); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.motion(120) } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            preventStealing: true
            cursorShape: divider.tall ? Qt.SizeVerCursor : Qt.SizeHorCursor
            property real startRatio: .5
            property real start: 0
            function along(e) { return divider.tall ? e.y : e.x; }
            // The window stays still during a drag so pointer positions stay stable.
            onPressed: e => { startRatio = PhoneState.splitRatio; start = along(e); divider.frozen = divider.offset; }
            onPositionChanged: e => { if (pressed) PhoneState.setRatio(startRatio + (along(e) - start) / Math.max(1, divider.span - 8), false); }
            onReleased: { PhoneState.setRatio(PhoneState.splitRatio, true); divider.frozen = -1; }
            onCanceled: divider.frozen = -1
            onDoubleClicked: PhoneState.setRatio(.5, true)
            Accessible.role: Accessible.Separator
            Accessible.name: "Split view divider"
        }
    }
}
