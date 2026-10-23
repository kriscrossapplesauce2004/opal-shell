import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Post-capture preview card with 1-tap Copy, Ask Claude, Open and Delete actions.
PanelWindow {
    id: previewWin
    screen: Hub.chooseScreen()
    readonly property var item: Hub.lastCapture
    visible: item !== null && Hub.page === "" && !Hub.captureOpen
    anchors { bottom: true; right: true }
    margins { bottom: 84; right: 18 }
    implicitWidth: 348
    implicitHeight: cardBody.implicitHeight + 28
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-capture-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    Surface {
        anchors.fill: parent
        radius: 28
        kind: "menus"
        translucency: Math.max(.82, Hub.prefs.glass + .16)
        border.color: Theme.outline

        ColumnLayout {
            id: cardBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 76; Layout.preferredHeight: 52; radius: 12
                    color: Theme.level(4); clip: true
                    Image {
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        source: previewWin.item && previewWin.item.path ? "file://" + previewWin.item.path : ""
                        asynchronous: true; cache: false
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    MText {
                        Layout.fillWidth: true
                        text: previewWin.item && previewWin.item.ocr ? "Text extracted & copied" : "Screenshot saved"
                        role: "titleS"
                    }
                    MText {
                        Layout.fillWidth: true
                        text: previewWin.item && previewWin.item.ocr ? previewWin.item.ocr : "Copied to clipboard · Pictures/Screenshots"
                        role: "labelS"; color: Theme.subtext; maximumLineCount: 2; elide: Text.ElideRight
                    }
                }
                MButton {
                    icon: "close"; compact: true; implicitWidth: 30; implicitHeight: 30
                    onClicked: Hub.lastCapture = null
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                MButton {
                    icon: "spark"; text: "Ask Claude"; compact: true; filled: true
                    onClicked: {
                        const path = previewWin.item ? previewWin.item.path : "";
                        Hub.lastCapture = null;
                        Hub.openAssistant("");
                        if (path) { AssistantState.ctxScreenshot = path; AssistantState.useScreenshot = true; }
                    }
                }
                MButton {
                    icon: "open_in_new"; text: "Open"; compact: true; tonal: true
                    onClicked: {
                        const path = previewWin.item ? previewWin.item.path : "";
                        Hub.lastCapture = null;
                        if (path) Hub.command({action: "open-path", path: path});
                    }
                }
                Item { Layout.fillWidth: true }
                MButton {
                    icon: "delete"; compact: true; implicitWidth: 34; implicitHeight: 34
                    tooltip: "Delete screenshot"
                    onClicked: {
                        const path = previewWin.item ? previewWin.item.path : "";
                        Hub.lastCapture = null;
                        if (path) Hub.command({action: "capture-delete", path: path});
                    }
                }
            }
        }
    }
}
