import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Capture Studio: select on a frozen frame (region, window, screen or one pixel's colour), then copy, save, mark up, read text, ask Claude or record.
// The same scope holds the delay countdown and the frame around a region recording.
Scope {
    id: studio

    // ---------- the studio ----------
    PanelWindow {
        id: cap
        screen: Hub.captureScreen || Hub.chooseScreen()
        visible: Hub.captureOpen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-capture"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        Loader { anchors.fill: parent; active: cap.visible; sourceComponent: Component { CaptureStudio { screenObj: cap.screen; onDelayed: (seconds, request) => countdown.start(seconds, request) } } }
    }

    // ---------- delay countdown ----------
    QtObject {
        id: countdown
        property var pending: null
        function start(seconds, request) { pending = request; Hub.captureCountdown = seconds; tick.restart(); }
    }
    Timer {
        id: tick; interval: 1000; repeat: true
        onTriggered: {
            Hub.captureCountdown = Hub.captureCountdown - 1;
            if (Hub.captureCountdown > 0) return;
            stop();
            // The chip must be gone before the screen is read.
            fire.request = countdown.pending; countdown.pending = null;
            if (fire.request) fire.restart();
        }
    }
    Timer { id: fire; property var request: null; interval: 150; onTriggered: if (request) Hub.command(request) }
    PanelWindow {
        screen: Hub.captureScreen || Hub.chooseScreen()
        visible: Hub.captureCountdown > 0
        anchors { top: true }
        margins.top: 24
        implicitWidth: 120; implicitHeight: 120
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-capture-countdown"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        MorphShape {
            anchors.fill: parent; shape: Hub.captureCountdown % 2 ? 2 : 5; fill: Theme.primary; spinMs: 6000
            MText { anchors.centerIn: parent; text: Hub.captureCountdown; role: "displayM"; color: Theme.onPrimary }
        }
        // A click on the countdown cancels the shot.
        MouseArea { anchors.fill: parent; onClicked: { tick.stop(); countdown.pending = null; Hub.captureCountdown = 0; } }
    }

    // ---------- frame around a region recording ----------
    PanelWindow {
        id: recFrame
        readonly property var r: Hub.recordingRect
        screen: r && r.screen ? r.screen : Hub.chooseScreen()
        visible: Hub.recordingActive && !!r
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-capture-frame"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        // Only the stop pill takes input; the frame never blocks what is being recorded.
        mask: Region { item: stopPill }
        property int now: 0
        Timer { interval: 1000; repeat: true; running: recFrame.visible; triggeredOnStart: true; onTriggered: recFrame.now = Math.floor(Date.now() / 1000) }
        // The frame sits just outside the recorded area, so it is never in the video.
        Rectangle {
            visible: !!recFrame.r
            x: recFrame.r ? recFrame.r.x - 4 : 0; y: recFrame.r ? recFrame.r.y - 4 : 0
            width: recFrame.r ? recFrame.r.w + 8 : 0; height: recFrame.r ? recFrame.r.h + 8 : 0
            color: "transparent"; border.width: 2; border.color: Theme.error; radius: 4
        }
        Rectangle {
            id: stopPill
            readonly property int secs: Hub.recordingStarted > 0 ? Math.max(0, recFrame.now - Hub.recordingStarted) : 0
            x: recFrame.r ? Math.max(8, Math.min(recFrame.width - width - 8, recFrame.r.x + recFrame.r.w - width)) : 0
            y: recFrame.r ? (recFrame.r.y > 52 ? recFrame.r.y - 48 : Math.min(recFrame.height - height - 8, recFrame.r.y + recFrame.r.h + 10)) : 0
            width: stopRow.implicitWidth + 24; height: 38; radius: 19; color: Theme.error
            Row { id: stopRow; anchors.centerIn: parent; spacing: 8
                Rectangle { width: 10; height: 10; radius: 2; color: Theme.base; anchors.verticalCenter: parent.verticalCenter }
                MText { text: Math.floor(stopPill.secs / 60) + ":" + String(stopPill.secs % 60).padStart(2, "0") + " · Stop"; role: "label"; font.features: {"tnum": 1}; color: Theme.base; anchors.verticalCenter: parent.verticalCenter } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.command({action: "capture-record-stop"}) }
            Accessible.role: Accessible.Button; Accessible.name: "Stop recording"
        }
    }
}
