import QtQuick
import Quickshell
import Quickshell.Wayland

// Snap layouts: a card of layouts that opens under the window's titlebar buttons. Pick a cell and the window fills that part of the screen,
// then Snap Assist offers the other windows for the rest of the layout.
Scope {
    id: snap
    property bool open: false
    property real reveal: 0
    property var screen: null
    // The window to place, taken when the card opens. Once the card has keyboard focus, Hyprland reports no active window.
    property string address: ""
    // The window's place on its screen, for anchoring the card at its top right corner.
    property var anchor: null
    function show() {
        address = Hub.status.activeAddress || "";
        const w = Hub.windows.find(x => x.address === address);
        screen = (w && Quickshell.screens.find(s => s.name === w.monitor)) || Hub.chooseScreen();
        const m = screen ? (Hub.status.monitors || []).find(x => x.name === screen.name) : null;
        anchor = w && m && w.at && w.size ? {right: w.at[0] + w.size[0] - m.x, top: w.at[1] - m.y} : null;
        open = true; grow.to = 1; grow.restart();
    }
    function hide() { open = false; grow.to = 0; grow.restart(); }
    function pick(cell) { Hub.command({action: "window-snap", cell: cell, address: address, assist: true}); hide(); }
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
        // The whole screen takes input, transparent parts included, so a press anywhere else ends it.
        mask: Region { x: 0; y: 0; width: win.screen ? win.screen.width : 0; height: win.screen ? win.screen.height : 0 }
        MouseArea { anchors.fill: parent; onPressed: snap.hide() }
        Item {
            id: area
            anchors.fill: parent
            focus: snap.open
            Keys.onEscapePressed: snap.hide()
            SnapLayoutsCard {
                id: card
                // Under the titlebar buttons when the window is known, else at the top of the screen; always fully on screen.
                x: snap.anchor ? Math.max(16, Math.min(area.width - width - 16, snap.anchor.right - width - 8)) : (area.width - width) / 2
                y: (snap.anchor ? Math.max(16, Math.min(area.height - height - 16, snap.anchor.top + 6)) : 24) - 12 * (1 - snap.reveal)
                transformOrigin: snap.anchor ? Item.TopRight : Item.Top
                opacity: snap.reveal; scale: .92 + .08 * snap.reveal
                onPicked: cell => snap.pick(cell)
            }
        }
    }
}
