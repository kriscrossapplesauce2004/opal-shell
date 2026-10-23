import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// After a capture: the shot, what happened to it, and one-tap Mark up, Ask Claude, Open and Delete. Hover keeps it open.
PanelWindow {
    id: previewWin
    screen: Hub.captureScreen || Hub.chooseScreen()
    readonly property var item: Hub.lastCapture
    readonly property bool textShot: !!item && item.intent === "ocr"
    visible: item !== null && Hub.page === "" && !Hub.captureOpen && Hub.captureEditPath === ""
    anchors { bottom: true; right: true }
    margins { bottom: 84; right: 18 }
    implicitWidth: 380
    implicitHeight: card.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-capture-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    property real arrival: 0
    onItemChanged: if (item) { arrival = 0; arrive.restart(); }
    NumberAnimation { id: arrive; target: previewWin; property: "arrival"; to: 1; duration: Theme.motion(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate }
    function path() { return previewWin.item ? previewWin.item.path : ""; }

    Surface {
        id: card
        width: parent.width; implicitHeight: body.implicitHeight + 28
        radius: 28; kind: "menus"; level: 3; elevated: true
        translucency: Math.max(.9, Hub.prefs.glass)
        border.width: Theme.edges && !Theme.solid("menus") ? 1 : 0; border.color: Theme.glassEdge
        opacity: previewWin.arrival
        transform: Translate { x: 24 * (1 - previewWin.arrival) }
        HoverHandler { onHoveredChanged: Hub.captureToastHeld = hovered }
        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12
            // The shot itself, large, with a click to open it.
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: previewWin.textShot ? 0 : 190; visible: !previewWin.textShot
                radius: 18; color: Theme.level(4); clip: true
                RoundedImage { anchors.fill: parent; radius: 18; source: previewWin.path() ? "file://" + previewWin.path() : ""; decodeSize: Qt.size(720, 380) }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10; height: 26; width: savedRow.implicitWidth + 18; radius: 13; color: Theme.alpha("#000000", .55)
                    Row { id: savedRow; anchors.centerIn: parent; spacing: 5
                        Glyph { name: previewWin.item && previewWin.item.copied ? "content_copy" : "download_done"; font.pixelSize: 15; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: previewWin.item && previewWin.item.copied ? "Copied" : "Saved"; role: "labelS"; color: "white"; anchors.verticalCenter: parent.verticalCenter } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const p = previewWin.path(); Hub.lastCapture = null; if (p) Hub.command({action: "open-path", path: p}); } }
            }
            // Text that OCR read, when that was the action.
            Rectangle {
                visible: previewWin.textShot; Layout.fillWidth: true; implicitHeight: ocrText.implicitHeight + 24; radius: 18; color: Theme.level(2)
                MText { id: ocrText; anchors.fill: parent; anchors.margins: 12; text: previewWin.item && previewWin.item.ocr ? previewWin.item.ocr : "No text found in that area"; role: "body"; wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight; textFormat: Text.PlainText }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                    MText { text: previewWin.textShot ? (previewWin.item && previewWin.item.ocr ? "Text copied" : "No text found") : "Screenshot"; role: "titleS" }
                    MText { Layout.fillWidth: true; text: "Pictures/Screenshots"; role: "labelS"; color: Theme.subtext } }
                MButton { icon: "close"; compact: true; implicitWidth: 32; implicitHeight: 32; tooltip: "Dismiss"; onClicked: Hub.lastCapture = null }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                MButton { icon: "edit"; text: "Mark up"; compact: true; filled: true
                    onClicked: { const p = previewWin.path(); Hub.lastCapture = null; if (p) Hub.captureEditPath = p; } }
                MButton { visible: Hub.aiEnabled !== false; icon: "auto_awesome"; text: "Ask Claude"; compact: true; tonal: true
                    onClicked: { const p = previewWin.path(); Hub.lastCapture = null; Hub.openAssistant(""); if (p) { AssistantState.ctxScreenshot = p; AssistantState.useScreenshot = true; } } }
                Item { Layout.fillWidth: true }
                MButton { icon: "content_copy"; compact: true; implicitWidth: 36; implicitHeight: 36; tooltip: "Copy image"
                    onClicked: { const p = previewWin.path(); if (p) Hub.command({action: "capture-copy", path: p}); } }
                MButton { icon: "delete"; compact: true; implicitWidth: 36; implicitHeight: 36; tooltip: "Delete"; ink: Theme.error
                    onClicked: { const p = previewWin.path(); Hub.lastCapture = null; if (p) Hub.command({action: "capture-delete", path: p}); } }
            }
        }
        // Time left before the card goes, as a thin bar along the bottom edge.
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.leftMargin: 28; anchors.bottomMargin: 4
            height: 3; radius: 1.5; color: Theme.alpha(Theme.primary, .5)
            width: (parent.width - 56) * life.p
            QtObject { id: life; property real p: 1 }
            NumberAnimation { running: previewWin.visible && !Hub.captureToastHeld; target: life; property: "p"; from: 1; to: 0; duration: 8000 }
        }
    }
}
