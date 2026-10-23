import QtQuick
import Quickshell
import Quickshell.Wayland
// Workspace switcher: slides down from the top edge on a workspace switch. Hover keeps it open and grows it into tiles; click or scroll switches.
PanelWindow {
    id: osd
    // The target is computed once; reading the window screen back would make a binding loop with visible.
    readonly property var target: Hub.chooseScreen()
    screen: target
    property int shown: 0
    property int baseline: -1
    property bool out: false
    // An IPC open stays longer and starts as tiles.
    property bool pinned: false
    anchors { top: true; left: true; right: true }
    implicitHeight: 360
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-workspaces"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    // Desktop bars show the workspace in the clock pill instead.
    readonly property bool inBar: !!target && Hub.layoutFor(target.width, target.height, target.name) === "desktop" && (Hub.status.fullscreenMonitors || []).indexOf(target.name) < 0
    visible: (out || closing.running) && (!inBar || pinned)
    // Only the pill takes input, so the rest of the strip never blocks the apps under it.
    mask: Region { item: osd.out ? pill.hitItem : null }
    function show(sticky) {
        osd.shown = Hub.status.workspace || osd.shown || 1;
        osd.out = true;
        pinned = !!sticky;
        if (sticky) pill.expand = true;
        hide.restart();
    }
    // The first value after startup is only a baseline, so login and reload stay quiet.
    Connections {
        target: Hub
        function onStatusChanged() {
            const w = Hub.status.workspace || 0;
            if (!Hub.status.hypr || w <= 0) return;
            if (osd.baseline < 0) { osd.baseline = w; osd.shown = w; return; }
            if (w === osd.shown && osd.out) { hide.restart(); return; }
            if (w === osd.shown) return;
            osd.shown = w;
            osd.out = true;
            hide.restart();
        }
        function onWorkspaceOverviewRequest() { osd.show(true); }
    }
    Timer { id: hide; interval: osd.pinned ? 4000 : 1400; onTriggered: if (!pill.hovered) { osd.out = false; osd.pinned = false; pill.expand = false; } }
    Timer { id: dwell; interval: 320; onTriggered: if (pill.hovered) pill.expand = true }
    // A short pause after the pointer leaves, so crossing a gap does not close the tiles.
    Connections { target: pill; function onHoveredChanged() { if (pill.hovered) { hide.stop(); leave.stop(); dwell.restart(); } else { dwell.stop(); pill.expand = false; hide.stop(); leave.restart(); } } }
    Timer { id: leave; interval: 900; onTriggered: if (!pill.hovered) { osd.out = false; osd.pinned = false; } }
    Timer { id: closing; interval: 260; running: !osd.out }
    WorkspacePill { id: pill; anchors.horizontalCenter: parent.horizontalCenter; shown: osd.shown; out: osd.out; screenObj: osd.target }
}
