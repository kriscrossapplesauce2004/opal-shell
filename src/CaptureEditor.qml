import QtQuick
import Quickshell
import Quickshell.Wayland

// Full-screen markup window for a fresh screenshot. Only an explicit Edit opens it, so it may take the keyboard.
PanelWindow {
    id: editorWin
    screen: Hub.captureScreen || Hub.chooseScreen()
    visible: Hub.captureEditPath !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-capture-editor"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    Loader { anchors.fill: parent; active: editorWin.visible; sourceComponent: Component { CaptureMarkup { path: Hub.captureEditPath; onDone: Hub.captureEditPath = "" } } }
}
