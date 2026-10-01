import QtQuick
import Quickshell
import Quickshell.Wayland

// The dock menu, full screen on the newly connected display. It takes the keyboard only when clicked.
PanelWindow {
    id: window
    screen: Hub.dockScreen || Quickshell.screens[0]
    visible: Hub.dockNotice && Hub.dockScreen !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-dock"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    Loader {
        anchors.fill: parent
        active: window.visible
        sourceComponent: DockScene {
            output: Hub.dockScreen ? Hub.dockScreen.name : ""
            description: { const m = Hub.monitors.find(m => Hub.dockScreen && m.name === Hub.dockScreen.name); return m && m.description ? m.description : output; }
            hasPhone: Hub.phoneScreen !== null
            apps: Hub.windows.filter(w => w.address && (!Hub.dockScreen || w.monitor !== Hub.dockScreen.name))
            modes: { const m = Hub.monitors.find(m => Hub.dockScreen && m.name === Hub.dockScreen.name); return m ? m.modes : []; }
            remembered: Hub.dockScreen ? (Hub.prefs.dockChoices || {})[Hub.dockScreen.name] || null : null
            onStarted: choice => Hub.applyDock(choice)
            onDismissed: Hub.dockNotice = false
        }
    }
}
