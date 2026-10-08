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
    // A latched modifier is drawn filled with the primary colour.
    property bool latch: false
    property bool repeating: false
    property bool spacebar: false
    property bool icon: false
    property bool dense: false
    property bool toolbar: false
    // A circular icon button, as used in the suggestion bar and panel titles.
    property bool round: false
    // A tool tile: tonal glyph container above a small label.
    property bool tile: false
    property string badge: ""
    property bool mono: false
    // A glyph shown next to (or, when stacked, above) the label.
    property string glyph: ""
    property bool stacked: false
    // A large pad key, as in the arrow pad.
    property bool big: false
    property bool down: false
    property bool choosing: false
    property bool scrubbing: false
    property bool tracking: false
    property int choice: 0
    property real startX: 0
    property real startY: 0
    property real lastX: 0
    property real lastY: 0
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
    readonly property real popupWidth: Math.min(keyboard.width - 12, Math.max(58, alternatives.length * 44 + 12))
    property point deckPosition: Qt.point(0, 0)
    readonly property real popupX: Math.max(-deckPosition.x + 6, Math.min(width / 2 - popupWidth / 2, keyboard.width - deckPosition.x - popupWidth - 6))
    readonly property bool tonalStyle: keyboard.keyStyle === "tonal"
    readonly property bool filled: toggled && latch || accent
    readonly property real restingRadius: round || toolbar ? height / 2 : tile ? 20 : big ? 22 : dense ? 12 : 14
    z: down ? 20 : focused ? 30 : 0
    implicitHeight: 56
    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.onPressAction: keyboard.dispatch(value)

    function cancel() {
        hold.stop(); repeat.stop(); track.stop();
        if (scrubbing) keyboard.gestureHint = "";
        if (tracking) keyboard.endTrackpad();
        down = false; choosing = false; scrubbing = false; tracking = false; valid = false;
    }
    function begin(x, y) {
        cancel(); deckPosition = mapToItem(keyboard, 0, 0); down = true; valid = true; startX = x; startY = y; lastX = x; lastY = y;
        pressGeneration = keyboard.generation;
        if (repeating) { keyboard.dispatch(value); hold.restart(); }
        else if (alternatives.length > 0 && !keyboard.privateInput) hold.restart();
        if (spacebar && !keyboard.privateInput) track.restart();
    }
    function update(x, y) {
        if (!valid) return;
        if (choosing) {
            if (y < -82 || y > height + 30 || x < popupX - 24 || x > popupX + popupWidth + 24) { cancel(); return; }
            choice = Math.max(0, Math.min(alternatives.length - 1, Math.floor((x - popupX - 6) / ((popupWidth - 12) / alternatives.length)))); return;
        }
        if (tracking) {
            // Two dimensional cursor steps while the trackpad surface is up.
            while (Math.abs(x - lastX) >= 12) { keyboard.moveCursor(x > lastX ? "Right" : "Left"); lastX += x > lastX ? 12 : -12; }
            while (Math.abs(y - lastY) >= 22) { keyboard.moveCursor(y > lastY ? "Down" : "Up"); lastY += y > lastY ? 22 : -22; }
            return;
        }
        if (spacebar && (scrubbing || Math.abs(x - startX) > 14)) {
            if (y < -height || y > height * 2) { cancel(); return; }
            scrubbing = true; hold.stop(); track.stop();
            keyboard.gestureHint = keyboard.selecting || keyboard.shiftState ? "Selecting text" : "Moving cursor";
            while (Math.abs(x - lastX) >= 14) {
                keyboard.moveCursor(x > lastX ? "Right" : "Left");
                lastX += x > lastX ? 14 : -14;
            }
        } else if (x < -4 || x > width + 4 || y < -12 || y > height + 12) cancel();
    }
    function finish(x, y) {
        if (valid && pressGeneration === keyboard.generation) {
            if (choosing) keyboard.dispatch(alternatives[choice]);
            else if (!repeating && !scrubbing && !tracking && x >= 0 && x <= width && y >= 0 && y <= height) keyboard.dispatch(value);
        }
        cancel();
    }
    onVisibleChanged: if (!visible) cancel()
    onEnabledChanged: if (!enabled) cancel()
    Component.onDestruction: { cancel(); if (keyboard) keyboard.unregisterKey(key); }
    Component.onCompleted: keyboard.registerKey(key)
    function activate() { if (revealable && enabled) keyboard.dispatch(value); }
    Connections { target: key.keyboard; function onCancelInput() { key.cancel(); } }
    Timer {
        id: hold; interval: key.repeating ? 360 : 420
        onTriggered: {
            if (!key.valid) return;
            if (key.repeating) repeat.start();
            else { key.choosing = true; key.choice = 0; }
        }
    }
    // A long, still hold on the space bar raises the trackpad surface.
    Timer {
        id: track; interval: 650
        onTriggered: if (key.valid && !key.scrubbing && !key.choosing) { key.tracking = true; key.keyboard.beginTrackpad(); }
    }
    Timer { id: repeat; interval: 55; repeat: true; onTriggered: { if (key.valid && key.pressGeneration === key.keyboard.generation) key.keyboard.dispatch(key.value); else key.cancel(); } }
    Rectangle {
        id: surface
        anchors.fill: parent; anchors.margins: key.toolbar || key.round ? 3 : key.tile ? 3 : 2.5
        objectName: "keySurface"
        // The pressed key morphs into a pill.
        radius: key.down && !key.tile && !key.round && !key.toolbar ? height / 2 : key.focused && !key.tile ? Math.min(height / 2, 20) : key.restingRadius
        scale: key.focused && key.keyboard.controllerActive ? 1.12 : 1
        Behavior on radius { NumberAnimation { duration: key.keyboard.reduceMotion ? 0 : 110; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: key.keyboard.reduceMotion ? 0 : 140; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: key.keyboard.reduceMotion ? 0 : 90 } }
        color: key.focused ? key.keyboard.primary
             : key.filled ? key.keyboard.primary
             : key.down && !key.tile ? key.keyboard.primaryContainer
             : key.toggled ? key.keyboard.secondaryContainer
             : key.toolbar || key.dense && !key.tonalStyle ? "transparent"
             : key.round ? key.keyboard.specialColor
             : key.tile || key.big ? key.keyboard.keyColor
             : key.special ? (key.tonalStyle ? key.keyboard.secondaryContainer : key.keyboard.alpha(key.keyboard.secondaryContainer, 0.7))
             : key.spacebar ? key.keyboard.keyColor
             : key.tonalStyle ? key.keyboard.keyColor : "transparent"
        border.width: key.focused ? 3 : 0
        border.color: key.keyboard.alpha(key.keyboard.primaryInk, 0.5)
        readonly property color ink: key.focused || key.filled ? key.keyboard.primaryInk
            : key.down && !key.tile ? key.keyboard.primaryContainerInk
            : key.toggled ? key.keyboard.secondaryContainerInk
            : key.special && !key.toolbar && !key.round && !key.tile ? key.keyboard.secondaryContainerInk : key.keyboard.foreground

        Rectangle {
            objectName: "stateLayer"
            anchors.fill: parent
            radius: parent.radius
            color: key.accent ? key.keyboard.primaryInk : key.keyboard.foreground
            opacity: key.down ? 0.12 : key.hovered ? 0.08 : 0
        }
        readonly property real tileBox: Math.max(28, Math.min(44, height - 28))
        // Tool tile content: a glyph in a tonal container with a count badge.
        Column {
            visible: key.tile
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: surface.tileBox; height: surface.tileBox; radius: 16
                color: key.keyboard.alpha(key.keyboard.primary, 0.16)
                Glyph { anchors.centerIn: parent; name: key.tile ? key.label : ""; fill: key.toggled ? 1 : 0; font.pixelSize: 24; color: key.keyboard.primary }
                Rectangle {
                    visible: key.badge !== ""
                    anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -5; anchors.topMargin: -5
                    width: Math.max(18, badgeText.implicitWidth + 8); height: 18; radius: 9
                    color: key.keyboard.tertiary
                    Text { id: badgeText; anchors.centerIn: parent; text: key.badge; font.pixelSize: 10; font.weight: Font.Bold; color: key.keyboard.backgroundColor }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: key.description; font.family: key.keyboard.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
                color: surface.ink
            }
        }
        Grid {
            visible: key.glyph !== "" && !key.tile
            anchors.centerIn: parent
            columns: key.stacked ? 1 : 2
            spacing: key.stacked ? 1 : 6
            horizontalItemAlignment: Grid.AlignHCenter; verticalItemAlignment: Grid.AlignVCenter
            Glyph { name: key.glyph; fill: key.toggled || key.filled ? 1 : 0; font.pixelSize: key.stacked ? 19 : 18; color: surface.ink }
            Text { text: key.label; font.family: key.keyboard.fontFamily; font.pixelSize: key.stacked ? 10 : 12; font.weight: Font.Medium; color: surface.ink }
        }
        Glyph {
            visible: key.icon && !key.tile && key.glyph === ""
            anchors.centerIn: parent
            name: key.icon ? key.label : ""
            fill: key.toggled || key.filled ? 1 : 0
            font.pixelSize: key.big ? 32 : key.toolbar || key.round ? 20 : 22
            color: surface.ink
        }
        Text {
            visible: !key.icon && !key.tile && key.glyph === ""
            anchors.centerIn: parent
            text: key.label
            color: surface.ink
            font.family: key.mono ? "CaskaydiaCove Nerd Font Mono" : key.keyboard.fontFamily
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: key.dense ? 16 : key.label.length > 3 ? 14 : key.special ? 16 : Math.min(24, parent.height * 0.46)
            font.weight: key.special || key.accent || key.label.length > 1 ? Font.DemiBold : Font.Normal
        }
        Text {
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: 6; anchors.topMargin: 2
            visible: key.hint !== "" && !key.tile
            text: key.hint; color: surface.ink; opacity: 0.6
            font.pixelSize: 10; font.family: key.keyboard.fontFamily
        }
        Rectangle { visible: key.spacebar && (key.scrubbing || key.tracking); width: 36; height: 3; radius: 2; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter; color: key.keyboard.primary }
    }
    HoverHandler { id: hover }
    // Press balloon above the key, or the accent picker pill that grows out of the held key.
    Rectangle {
        id: balloon
        objectName: "keyPreview"
        parent: key.keyboard.previewLayer
        z: key.choosing ? 2 : 1
        visible: key.visible && !key.keyboard.privateInput && (key.choosing || (key.down && !key.special && !key.spacebar && !key.tile && !key.round && !key.toolbar && !key.dense) || (key.down && key.dense && key.label.length === 1))
        x: key.deckPosition.x + (key.choosing ? key.popupX : Math.max(6 - key.deckPosition.x, Math.min((key.width - width) / 2, key.keyboard.width - key.deckPosition.x - width - 6)))
        y: Math.max(2, key.deckPosition.y - height + (key.choosing ? 0 : 3))
        width: key.choosing ? key.popupWidth : Math.max(54, key.width + 10)
        height: key.choosing ? 60 : 72
        radius: key.choosing ? 30 : 22
        color: key.choosing ? key.keyboard.specialColor : key.keyboard.primaryContainer
        border.width: key.choosing ? 1 : 0
        border.color: key.keyboard.alpha(key.keyboard.foreground, 0.2)
        transformOrigin: Item.Bottom
        scale: key.choosing && !key.keyboard.reduceMotion ? grow : 1
        property real grow: key.choosing ? 1 : 0.4
        Behavior on grow { NumberAnimation { duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        Row {
            id: choicesRow
            anchors.fill: parent; anchors.margins: key.choosing ? 6 : 3
            Repeater {
                model: key.choosing ? key.alternatives : [key.label]
                Rectangle {
                    id: alternative
                    required property string modelData
                    required property int index
                    width: (choicesRow.width / (key.choosing ? key.alternatives.length : 1)); height: choicesRow.height; radius: height / 2
                    color: key.choosing && index === key.choice ? key.keyboard.primary : "transparent"
                    Text { anchors.centerIn: parent; text: alternative.modelData; font.pixelSize: key.choosing ? 24 : 32; font.family: key.keyboard.fontFamily; color: key.choosing ? (alternative.index === key.choice ? key.keyboard.primaryInk : key.keyboard.foreground) : key.keyboard.primaryContainerInk }
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
