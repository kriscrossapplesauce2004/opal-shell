import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Interactive Capture Studio overlay: Region, Window, Full Screen, OCR and Screen Recording.
PanelWindow {
    id: cap
    screen: Hub.targetScreen || Hub.chooseScreen()
    visible: Hub.captureOpen
    property string scopeMode: "region" // "region", "window", "screen"
    property bool videoMode: false
    property bool recordAudio: true
    property bool ocrMode: false
    property real dragX0: 0
    property real dragY0: 0
    property real dragX1: 0
    property real dragY1: 0
    property bool dragging: false

    readonly property int rx: Math.round(Math.min(dragX0, dragX1))
    readonly property int ry: Math.round(Math.min(dragY0, dragY1))
    readonly property int rw: Math.round(Math.abs(dragX1 - dragX0))
    readonly property int rh: Math.round(Math.abs(dragY1 - dragY0))

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-capture"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: Theme.alpha("#000000", scopeMode === "region" ? .32 : .18)

    function triggerScreen() {
        const out = cap.screen ? cap.screen.name : "";
        Hub.captureOpen = false;
        if (cap.videoMode) Hub.command({action: "capture-record-start", output: out, audio: cap.recordAudio});
        else Hub.command({action: "capture-take", mode: "screen", output: out, ocr: cap.ocrMode});
    }
    function triggerWindow(addr) {
        Hub.captureOpen = false;
        Hub.command({action: "capture-take", mode: "window", address: addr || "", ocr: cap.ocrMode});
    }
    function triggerRegion() {
        if (cap.rw < 16 || cap.rh < 16) return;
        const mon = (Hub.monitors || []).find(m => cap.screen && m.name === cap.screen.name);
        const ox = mon ? Math.round(mon.x || 0) : 0;
        const oy = mon ? Math.round(mon.y || 0) : 0;
        const geom = (ox + cap.rx) + "," + (oy + cap.ry) + " " + cap.rw + "x" + cap.rh;
        Hub.captureOpen = false;
        if (cap.videoMode) Hub.command({action: "capture-record-start", geometry: geom, audio: cap.recordAudio});
        else Hub.command({action: "capture-take", mode: "region", geometry: geom, ocr: cap.ocrMode});
    }

    Shortcut { sequence: "Escape"; enabled: cap.visible; onActivated: Hub.captureOpen = false }
    Shortcut { sequence: "Return"; enabled: cap.visible && cap.scopeMode === "screen"; onActivated: cap.triggerScreen() }

    // Region drag canvas
    MouseArea {
        anchors.fill: parent
        cursorShape: cap.scopeMode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor
        onPressed: e => {
            if (cap.scopeMode === "screen") { cap.triggerScreen(); return; }
            if (cap.scopeMode === "window") { cap.triggerWindow(""); return; }
            cap.dragX0 = e.x; cap.dragY0 = e.y;
            cap.dragX1 = e.x; cap.dragY1 = e.y;
            cap.dragging = true;
        }
        onPositionChanged: e => {
            if (cap.dragging) { cap.dragX1 = e.x; cap.dragY1 = e.y; }
        }
        onReleased: {
            if (cap.dragging) {
                cap.dragging = false;
                cap.triggerRegion();
            }
        }
    }

    // Selected region frame
    Rectangle {
        visible: cap.scopeMode === "region" && (cap.dragging || (cap.rw >= 16 && cap.rh >= 16))
        x: cap.rx; y: cap.ry; width: cap.rw; height: cap.rh
        radius: 12
        color: Theme.alpha(Theme.primary, .14)
        border.width: 2; border.color: Theme.primary
        Rectangle {
            visible: cap.rw > 80 && cap.rh > 36
            anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 8
            width: sizeLabel.implicitWidth + 16; height: 24; radius: 12
            color: Theme.alpha(Theme.base, .88)
            MText { id: sizeLabel; anchors.centerIn: parent; text: cap.rw + " × " + cap.rh; role: "labelS" }
        }
    }

    // Top Floating Capture Bar
    Surface {
        id: bar
        anchors.top: parent.top; anchors.topMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        width: barRow.implicitWidth + 24; height: 56; radius: 28
        kind: "menus"
        translucency: Math.max(.82, Hub.prefs.glass + .18)
        border.color: Theme.outline

        RowLayout {
            id: barRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: [
                    {id: "region", icon: "crop_free", label: "Region"},
                    {id: "window", icon: "select_window", label: "Window"},
                    {id: "screen", icon: "fullscreen", label: "Screen"}
                ]
                MButton {
                    required property var modelData
                    icon: modelData.icon; text: modelData.label; compact: true
                    filled: cap.scopeMode === modelData.id
                    tonal: cap.scopeMode !== modelData.id
                    onClicked: {
                        cap.scopeMode = modelData.id;
                        if (modelData.id === "screen" && !cap.videoMode) cap.triggerScreen();
                        else if (modelData.id === "window" && !cap.videoMode) cap.triggerWindow("");
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 24; color: Theme.outline }

            MButton {
                icon: cap.videoMode ? "videocam" : "photo_camera"
                text: cap.videoMode ? "Video" : "Photo"
                compact: true; tonal: true
                tooltip: "Switch between screenshot and screen recording"
                onClicked: cap.videoMode = !cap.videoMode
            }

            MButton {
                visible: !cap.videoMode
                icon: "text_fields"; text: "OCR"
                compact: true; filled: cap.ocrMode; tonal: !cap.ocrMode
                tooltip: "Extract text from the captured area to the clipboard"
                onClicked: cap.ocrMode = !cap.ocrMode
            }

            MButton {
                visible: cap.videoMode
                icon: cap.recordAudio ? "volume_up" : "volume_off"
                text: cap.recordAudio ? "Audio on" : "Muted"
                compact: true; filled: cap.recordAudio; tonal: !cap.recordAudio
                onClicked: cap.recordAudio = !cap.recordAudio
            }

            MButton {
                visible: cap.videoMode && cap.scopeMode === "screen"
                icon: "fiber_manual_record"; text: "Start"
                compact: true; filled: true
                onClicked: cap.triggerScreen()
            }

            MButton {
                icon: "close"; compact: true; implicitWidth: 36; implicitHeight: 36
                tooltip: "Cancel · Escape"
                onClicked: Hub.captureOpen = false
            }
        }
    }
}
