import QtQuick

// One emoji in a grid. Tap to type, hold for skin tones when they exist.
Item {
    id: cell
    required property var keyboard
    property string emoji: ""
    property real fontSize: 28
    readonly property var alternatives: keyboard.alternatives(emoji)
    readonly property bool focused: keyboard.focusedKey === cell
    readonly property bool revealable: {
        let node = cell;
        while (node) {
            if (!node.visible || node.width <= 0 || node.height <= 0) return false;
            node = node.parentItem;
        }
        return true;
    }
    objectName: "key-" + emoji
    signal toneRequested(var item)
    function activate() { if (revealable) keyboard.dispatch(emoji); }
    Accessible.role: Accessible.Button
    Accessible.name: emoji
    Accessible.onPressAction: cell.activate()
    Component.onCompleted: keyboard.registerKey(cell)
    Component.onDestruction: { if (keyboard) keyboard.unregisterKey(cell); }
    Rectangle {
        anchors.fill: parent; anchors.margins: 2; radius: 14
        color: cell.focused ? cell.keyboard.primary : "transparent"
        scale: cell.focused ? 1.12 : 1
        Rectangle { anchors.fill: parent; radius: parent.radius; color: cell.keyboard.foreground; opacity: tap.pressed ? 0.12 : 0 }
    }
    Text { anchors.centerIn: parent; text: cell.emoji; font.pixelSize: cell.fontSize; font.family: "Noto Color Emoji" }
    TapHandler {
        id: tap
        longPressThreshold: 0.42
        onTapped: cell.keyboard.dispatch(cell.emoji)
        onLongPressed: { if (cell.alternatives.length > 1) cell.toneRequested(cell); else cell.keyboard.dispatch(cell.emoji); }
    }
}
