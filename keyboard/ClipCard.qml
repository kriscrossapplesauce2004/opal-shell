import QtQuick

// One clipboard history card. Tap commits its text through the input method.
Item {
    id: card
    required property var keyboard
    required property var entry
    readonly property string kind: entry.kind || "text"
    readonly property bool focused: keyboard.focusedKey === card
    readonly property bool revealable: {
        let node = card;
        while (node) {
            if (!node.visible || node.width <= 0 || node.height <= 0) return false;
            node = node.parentItem;
        }
        return true;
    }
    objectName: "clip-" + (entry.id || "")
    function activate() { if (revealable) keyboard.pasteClip(entry); }
    Accessible.role: Accessible.Button
    Accessible.name: kind === "image" ? "Image" : entry.text
    Accessible.onPressAction: card.activate()
    Component.onCompleted: keyboard.registerKey(card)
    Component.onDestruction: { if (keyboard) keyboard.unregisterKey(card); }
    Rectangle {
        anchors.fill: parent; anchors.margins: 3
        radius: 20; clip: false
        color: card.focused ? card.keyboard.primaryContainer : card.keyboard.keyColor
        border.width: card.focused ? 3 : 0; border.color: card.keyboard.primary
        opacity: card.entry.tooLong ? 0.5 : 1
        Image {
            visible: card.kind === "image"
            anchors.fill: parent; anchors.margins: 0
            source: card.kind === "image" ? card.entry.image : ""
            sourceSize: Qt.size(400, 200); fillMode: Image.PreserveAspectCrop; asynchronous: true
        }
        Text {
            visible: card.kind !== "image"
            anchors.fill: parent; anchors.margins: 12; anchors.rightMargin: card.kind === "colour" ? 46 : 12
            text: card.entry.text
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            font.pixelSize: 13
            font.family: card.kind === "code" ? "CaskaydiaCove Nerd Font Mono" : card.keyboard.fontFamily
            color: card.kind === "link" ? card.keyboard.primary : card.keyboard.foreground
        }
        Rectangle {
            visible: card.kind === "colour"
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
            width: 28; height: 28; radius: 14
            color: card.entry.colour || "transparent"
            border.width: 1; border.color: card.keyboard.alpha(card.keyboard.foreground, 0.3)
        }
        Glyph { visible: !!card.entry.pinned; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; name: "keep"; fill: 1; font.pixelSize: 16; color: card.keyboard.primary }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: card.keyboard.foreground; opacity: tap.pressed ? 0.1 : 0 }
    }
    TapHandler { id: tap; onTapped: card.keyboard.pasteClip(card.entry) }
}
