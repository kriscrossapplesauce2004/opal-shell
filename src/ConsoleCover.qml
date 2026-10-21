import QtQuick
import Quickshell

// A console home cover. Portrait at rest; focused, it grows into a wide card with the game's header art. A group (Minecraft) shows its size.
Item {
    id: cover
    // {id, title, source, cover, hero, header, logo, icon, group?, count?}
    property var entry: null
    property bool running: false
    property string kicker: ""
    property real portraitWidth: 117
    property real wideWidth: 372
    // Set by ControllerFocus on the focused delegate.
    property bool controllerFocused: false
    // Only the controller grows a cover; growing under a hovering pointer would move the row under it.
    readonly property bool wide: controllerFocused && !!entry && !entry.group
    signal activated()
    signal alternate()
    function controllerActivate() { activated(); }
    function controllerAlternate() { alternate(); }
    readonly property int tint: entry ? Math.abs(entry.title.split("").reduce((h, c) => (h * 31 + c.charCodeAt(0)) | 0, 7)) % 3 : 0
    readonly property color genFill: [Theme.primaryContainer, Theme.secondaryContainer, Theme.tertiaryContainer][tint]
    readonly property color genInk: [Theme.onContainer, Theme.onSecondaryContainer, Theme.onTertiaryContainer][tint]
    readonly property string portraitArt: entry ? entry.cover || "" : ""
    readonly property string wideArt: entry ? entry.header || entry.hero || "" : ""
    implicitWidth: wide ? wideWidth : portraitWidth
    width: implicitWidth
    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }

    Rectangle { anchors.fill: parent; radius: Theme.shapeLg; color: portraitImage.ready || wideImage.ready ? Theme.level(3) : cover.genFill }
    RoundedImage {
        id: portraitImage
        anchors.fill: parent; radius: Theme.shapeLg
        source: cover.portraitArt; decodeSize: Qt.size(300, 450)
        opacity: cover.wide && wideImage.ready ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
    }
    RoundedImage {
        id: wideImage
        anchors.fill: parent; radius: Theme.shapeLg
        source: cover.wide ? cover.wideArt : ""; decodeSize: Qt.size(920, 430)
        opacity: cover.wide ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
    }
    Rectangle {
        anchors.fill: parent; radius: Theme.shapeLg; visible: cover.wide
        gradient: Gradient { GradientStop { position: .3; color: "transparent" } GradientStop { position: 1; color: Theme.alpha("#000000", .8) } }
    }
    Column {
        visible: cover.wide
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        spacing: 2
        MText { visible: cover.kicker !== ""; text: cover.kicker.toUpperCase(); role: "labelS"; font.letterSpacing: 1.4; font.weight: Font.Bold; color: Theme.primary }
        MText { width: parent.width; text: cover.entry ? cover.entry.title : ""; role: "title"; font.pixelSize: 20; color: "#ffffff" }
    }
    // Generated cover for art-less entries and groups.
    Item {
        anchors.fill: parent
        visible: !portraitImage.ready && !(cover.wide && wideImage.ready)
        Glyph { x: 16; y: 16; name: cover.entry && cover.entry.group ? "deployed_code" : "sports_esports"; font.pixelSize: Math.min(40, cover.width * .3); color: cover.genInk }
        Image {
            x: 16; y: 16; width: 40; height: 40; visible: status === Image.Ready && !(cover.entry && cover.entry.group)
            source: cover.entry && cover.entry.icon ? (cover.entry.icon.startsWith("file:") ? cover.entry.icon : Quickshell.iconPath(cover.entry.icon, true)) : ""
            sourceSize: Qt.size(80, 80); asynchronous: true
        }
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
            spacing: 4
            MText { width: parent.width; text: cover.entry ? cover.entry.title : ""; role: "title"; font.pixelSize: Math.max(15, Math.min(20, cover.width / 7)); fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 2; color: cover.genInk }
            MText { width: parent.width; text: cover.entry ? (cover.entry.group ? cover.entry.count + " instances" : cover.entry.source || "") : ""; role: "labelS"; color: Theme.alpha(cover.genInk, .75) }
        }
        Rectangle {
            visible: !!cover.entry && !!cover.entry.group
            anchors { right: parent.right; top: parent.top; margins: 10 }
            width: 28; height: 28; radius: 14; color: Theme.alpha(cover.genInk, .16)
            MText { anchors.centerIn: parent; text: cover.entry && cover.entry.count ? cover.entry.count : ""; role: "label"; font.weight: Font.Bold; color: cover.genInk }
        }
    }
    Rectangle {
        visible: cover.running
        anchors { top: parent.top; left: parent.left; margins: 10 }
        width: runningLabel.implicitWidth + 20; height: 24; radius: 12; color: Theme.primary
        MText { id: runningLabel; anchors.centerIn: parent; text: "Running"; role: "labelS"; font.weight: Font.Bold; color: Theme.onPrimary }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => { if (e && e.button === Qt.RightButton) cover.alternate(); else cover.activated(); }
    }
    Accessible.role: Accessible.Button
    Accessible.name: entry ? entry.title : ""
}
