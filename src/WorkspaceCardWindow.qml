import QtQuick
import Quickshell
import Quickshell.Wayland

// The workspace card window: it sits just above the tablet bar or the desktop Shelf and grows up out of the workspace chip. A tap outside closes it.
Scope {
    id: scope
    property real reveal: 0
    property bool presenting: false
    Connections {
        target: PhoneState
        function onSpacesOpenChanged() {
            if (PhoneState.spacesOpen) { scope.presenting = true; grow.to = 1; grow.restart(); }
            else { grow.to = 0; grow.restart(); }
        }
    }
    NumberAnimation {
        id: grow; target: scope; property: "reveal"; duration: Theme.motion(grow.to > 0 ? 380 : 180)
        easing.type: Easing.BezierSpline; easing.bezierCurve: grow.to > 0 ? Theme.emphasizedDecelerate : Theme.emphasizedAccelerate
        onFinished: if (!PhoneState.spacesOpen) scope.presenting = false
    }
    // Leaving the tablet posture closes a card that a tablet chip opened.
    Connections { target: Hub; function onStatusChanged() { if (PhoneState.spacesOpen && PhoneState.spacesBottom < 0 && !PhoneState.isTablet(PhoneState.spacesScreen)) PhoneState.spacesOpen = false; } }
    PanelWindow {
        id: dismiss
        screen: PhoneState.spacesScreen || Quickshell.screens[0]
        visible: PhoneState.spacesOpen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-workspaces-dismiss"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        // It covers the whole screen, the bar too: a click anywhere outside the card closes it, a click on the chip as well.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: PhoneState.spacesOpen = false }
    }
    PanelWindow {
        id: win
        screen: PhoneState.spacesScreen || Quickshell.screens[0]
        visible: scope.presenting
        anchors { bottom: true; left: true }
        margins { bottom: PhoneState.spacesBottom >= 0 ? PhoneState.spacesBottom : PhoneState.tabletNavHeight - 6; left: Math.max(8, Math.min(PhoneState.spacesX - 10, (win.screen ? win.screen.width : 1920) - implicitWidth - 8)) }
        implicitWidth: card.implicitWidth + 16
        implicitHeight: card.implicitHeight + 16
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-workspaces"
        WlrLayershell.keyboardFocus: PhoneState.spacesOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        WorkspaceCard {
            id: card
            x: 8; y: 8; width: implicitWidth; height: implicitHeight
            screenObj: win.screen
            focus: true
            Keys.onEscapePressed: PhoneState.spacesOpen = false
            // Picking a workspace from inside the launcher also closes the launcher.
            onPicked: { PhoneState.spacesOpen = false; if (Hub.page === "launcher") Hub.close(); }
            // Grows up out of the chip at the bottom-left corner.
            opacity: Math.min(1, scope.reveal * 1.5)
            transformOrigin: Item.BottomLeft
            scale: .55 + .45 * scope.reveal
            transform: Translate { y: 10 * (1 - scope.reveal) }
        }
    }
}
