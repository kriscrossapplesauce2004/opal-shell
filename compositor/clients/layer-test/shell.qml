import QtQuick
import Quickshell
import Quickshell.Wayland

// Layer-shell test shell: a top bar with an exclusive zone, a right dock, an overlay with on-demand keys, and a popup.
ShellRoot {
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 40
        exclusiveZone: 40
        WlrLayershell.namespace: "test-bar"
        color: "#3a5a8c"
        Text { anchors.centerIn: parent; text: "test bar (top, exclusive 40)"; color: "white" }

        PopupWindow {
            anchor.window: bar
            anchor.rect.x: 20
            anchor.rect.y: bar.height
            implicitWidth: 220
            implicitHeight: 120
            visible: true
            color: "#c0504d"
            Text { anchors.centerIn: parent; text: "popup of the bar"; color: "white" }
        }
    }

    PanelWindow {
        anchors { right: true; top: true; bottom: true }
        margins { top: 10; bottom: 10; right: 6 }
        implicitWidth: 60
        exclusiveZone: 66
        WlrLayershell.namespace: "test-dock"
        WlrLayershell.layer: WlrLayer.Bottom
        color: "#4f7d3a"
    }

    PanelWindow {
        anchors { bottom: true }
        margins { bottom: 30 }
        implicitWidth: 300
        implicitHeight: 80
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "test-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "#8a4fb0"
        Text { anchors.centerIn: parent; text: "overlay, exclusive keys"; color: "white" }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "test-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        color: "#202830"
    }
}
