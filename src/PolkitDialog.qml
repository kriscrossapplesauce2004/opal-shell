import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

// Opal polkit agent. An app asks for admin rights; this dialog collects the password.
Scope {
    id: root
    readonly property var flow: agent.flow
    PolkitAgent { id: agent }
    PanelWindow {
        id: window
        screen: Hub.chooseScreen()
        visible: agent.isActive && root.flow !== null
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-polkit"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: Theme.alpha("#000000", .4)
        
        MouseArea { anchors.fill: parent }
        PolkitCard {
            id: card
            anchors.centerIn: parent
            flow: root.flow
        }
    }
}
