import QtQuick
import Quickshell
import Quickshell.Wayland

// Holds the power key menu above everything on one screen. The lock screen shows its own copy while locked.
PanelWindow {
    id:win
    screen:PowerKey.screen||Hub.internalScreen||Quickshell.screens[0]
    visible:menu.visible&&!Hub.locked
    anchors {top:true;bottom:true;left:true;right:true}
    exclusionMode:ExclusionMode.Ignore
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.namespace:"opal-power-menu"
    WlrLayershell.keyboardFocus:PowerKey.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color:"transparent"
    // The controller moves the drum like the volume keys.
    readonly property int priority:90
    onVisibleChanged:{if(visible&&PowerKey.open)ControllerNav.claim(win);else ControllerNav.release(win);}
    Connections {
        target:ControllerNav
        function onKey(name) {
            if(ControllerNav.top!==win)return;
            if(name==="up")PowerKey.move(-1);else if(name==="down")PowerKey.move(1);
            else if(name==="accept"||name==="right")PowerKey.pick();else if(name==="back"||name==="left")PowerKey.goBack();
        }
    }
    PowerMenu {
        id:menu
        anchors.fill:parent
        focus:true
        Keys.onPressed:event=>menu.handleKey(event)
    }
}
