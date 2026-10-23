import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
// First-run setup: a full-screen walk through Wi-Fi, look, device, apps, Claude and shortcuts. Every choice applies right away.
PanelWindow {
    id: oobe
    screen: Hub.chooseScreen()
    visible: Hub.oobeOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-setup"
    // A first-run open never grabs the keyboard; a click gives it focus. Only an explicit open takes it at once.
    WlrLayershell.keyboardFocus: Hub.oobeExplicit ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    color: Theme.base
    Loader { anchors.fill: parent; active: oobe.visible; sourceComponent: Component { OobeContent {} } }
}
