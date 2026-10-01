pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: key
    required property var keyboard
    property string label: ""
    property string value: label
    property string hint: ""
    property string description: label
    property var alternatives: []
    property bool accent: false
    property bool special: false
    property bool toggled: false
    property bool repeating: false
    property bool spacebar: false
    property bool icon: false
    property bool dense: false
    property bool toolbar: false
    property bool down: false
    property bool choosing: false
    property bool scrubbing: false
    property int choice: 0
    property real startX: 0
    property real startY: 0
    property real lastX: 0
    property int pressGeneration: 0
    property bool valid: false
    readonly property bool focused: keyboard.focusedKey === key
    readonly property bool hovered: hover.hovered
    readonly property bool revealable: {
        let node = key;
        while (node) {
            if (!node.visible || node.width <= 0 || node.height <= 0) return false;
            node = node.parentItem;
        }
        return true;
    }
    objectName: "key-" + value
    readonly property real popupWidth: Math.min(keyboard.width - 12, Math.max(58, alternatives.length * 42))
    property point deckPosition: Qt.point(0, 0)
    readonly property real popupX: Math.max(-deckPosition.x + 6, Math.min(width / 2 - popupWidth / 2, keyboard.width - deckPosition.x - popupWidth - 6))
    z: down ? 20 : 0
    implicitHeight: 56
    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.onPressAction: keyboard.dispatch(value)

    function cancel() { hold.stop(); repeat.stop(); if (scrubbing) keyboard.gestureHint = ""; down = false; choosing = false; scrubbing = false; valid = false; }
    function begin(x, y) {
        cancel(); deckPosition = mapToItem(keyboard, 0, 0); down = true; valid = true; startX = x; startY = y; lastX = x;
        pressGeneration = keyboard.generation;
        if (repeating) { keyboard.dispatch(value); hold.restart(); }
        else if (alternatives.length > 0 && !keyboard.privateInput) hold.restart();
    }
    function update(x, y) {
        if (!valid) return;
        if (choosing) {
            if (y < -82 || y > height + 30 || x < popupX - 24 || x > popupX + popupWidth + 24) { cancel(); return; }
            choice = Math.max(0, Math.min(alternatives.length - 1, Math.floor((x - popupX) / (popupWidth / alternatives.length)))); return;
        }
        if (spacebar && (scrubbing || Math.abs(x - startX) > 14)) {
            if (y < -height || y > height * 2) { cancel(); return; }
            scrubbing = true; hold.stop();
            keyboard.gestureHint = keyboard.selecting || keyboard.shiftState ? "Selecting text" : "Moving cursor";
            while (Math.abs(x - lastX) >= 14) {
                keyboard.moveCursor(x > lastX ? "Right" : "Left");
                lastX += x > lastX ? 14 : -14;
            }
        } else if (x < -4 || x > width + 4 || y < -12 || y > height + 12) cancel();
    }
    function finish(x, y) {        if (valid && pressGeneration === keyboard.generation) {
            if (choosing) keyboard.dispatch(alternatives[choice]);
            else if (!repeating && !scrubbing && x >= 0 && x <= width && y >= 0 && y <= height) keyboard.dispatch(value);
        }
        cancel();
    }
    onVisibleChanged: if (!visible) cancel()
    onEnabledChanged: if (!enabled) cancel()
    Component.onDestruction: { cancel(); if (keyboard) keyboard.unregisterKey(key); }
    Component.onCompleted: keyboard.registerKey(key)
    function activate() { if (revealable) keyboard.dispatch(value); }
    Connections { target: key.keyboard; function onCancelInput() { key.cancel(); } }
    Timer {
        id: hold; interval: key.repeating ? 360 : 420
        onTriggered: {
            if (!key.valid) return;
            if (key.repeating) repeat.start();
            else { key.choosing = true; key.choice = 0; }
        }
    }
    Timer { id: repeat; interval: 55; repeat: true; onTriggered: { if (key.valid && key.pressGeneration === key.keyboard.generation) key.keyboard.dispatch(key.value); else key.cancel(); } }
    Rectangle {
        anchors.fill: parent; anchors.margins: key.toolbar ? 3 : 2.5
        objectName: "keySurface"
        radius: key.toolbar || key.accent || key.spacebar ? height / 2 : key.special ? 18 : key.dense ? 10 : 12
        color: key.toggled ? key.keyboard.primaryContainer : key.accent ? key.keyboard.primary : key.focused ? key.keyboard.tertiaryContainer : key.toolbar || key.dense ? "transparent" : key.spacebar ? key.keyboard.specialColor : key.special ? key.keyboard.secondaryContainer : key.keyboard.keyColor
        border.width: key.focused ? 2 : 0
        border.color: key.focused ? key.keyboard.primary : key.keyboard.outlineColor

        Rectangle {
            objectName: "stateLayer"
            anchors.fill: parent
            radius: parent.radius
            color: key.accent ? key.keyboard.primaryInk : key.keyboard.foreground
            opacity: key.down ? 0.12 : key.hovered ? 0.08 : 0
        }

        Text {
            anchors.centerIn: parent
            text: key.label
            color: key.accent ? key.keyboard.primaryInk : key.toggled ? key.keyboard.primaryContainerInk : key.focused ? key.keyboard.tertiaryContainerInk : key.special && !key.toolbar ? key.keyboard.secondaryContainerInk : key.keyboard.foreground
            font.family: key.icon ? "Material Symbols Rounded" : key.keyboard.fontFamily
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: key.icon ? (key.toolbar ? 19 : 21) : key.dense ? 16 : key.label.length > 3 ? 13 : key.special ? 17 : Math.min(22, parent.height * 0.46)
            font.weight: key.special || key.accent ? Font.Medium : Font.Normal
        }
        Text {
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: 6; anchors.topMargin: 3
            visible: key.hint !== "" && height < parent.height / 2
            text: key.hint; color: key.accent ? key.keyboard.primaryInk : key.keyboard.secondaryText
            font.pixelSize: 9
        }
        Rectangle { visible: key.spacebar && key.scrubbing; width: 36; height: 3; radius: 2; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter; color: key.keyboard.primary }
    }
    HoverHandler { id: hover }
    Rectangle {
        objectName: "keyPreview"
        parent: key.keyboard.previewLayer
        z: key.choosing ? 2 : 1
        visible: key.visible && !key.keyboard.privateInput && (key.choosing || (key.down && !key.special && !key.spacebar))
        x: key.deckPosition.x + (key.choosing ? key.popupX : Math.max(6 - key.deckPosition.x, Math.min((key.width - width) / 2, key.keyboard.width - key.deckPosition.x - width - 6)))
        y: Math.max(2, key.deckPosition.y - height + 3)
        width: key.choosing ? key.popupWidth : Math.max(52, key.width + 12)
        height: 57; radius: 17
        color: key.keyboard.primary; border.width: 2; border.color: key.keyboard.backgroundColor
        Row {
            id: choicesRow
            anchors.fill: parent; anchors.margins: 3
            Repeater {
                model: key.choosing ? key.alternatives : [key.label]
                Rectangle {
                    id: alternative
                    required property string modelData
                    required property int index
                    width: (choicesRow.width / (key.choosing ? key.alternatives.length : 1)); height: choicesRow.height; radius: 12
                    color: key.choosing && index === key.choice ? key.keyboard.primaryInk : "transparent"
                    Text { anchors.centerIn: parent; text: alternative.modelData; font.pixelSize: 26; color: key.choosing && alternative.index === key.choice ? key.keyboard.primary : key.keyboard.primaryInk }
                }
            }
        }
    }
    MultiPointTouchArea {
        anchors.fill: parent
        minimumTouchPoints: 1; maximumTouchPoints: 1; mouseEnabled: true
        onPressed: points => key.begin(points[0].x, points[0].y)
        onUpdated: points => key.update(points[0].x, points[0].y)
        onReleased: points => key.finish(points[0].x, points[0].y)
        onCanceled: key.cancel()
    }
}
