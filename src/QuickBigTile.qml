import QtQuick

// A 2×2 or wide Quick Settings tile with a live control: now playing, the timer, or device batteries.
Rectangle {
    id: bt
    property string kind: "media"
    property bool wide: false
    readonly property var media: Activities.byId["media"] || null
    readonly property bool playing: !!media && !!media.playing
    radius: 22; color: Theme.alpha(Theme.tile, .82); clip: true
    function pad(n) { return (n < 10 ? "0" : "") + n; }

    // Now playing: cover, title and controls.
    Item {
        visible: bt.kind === "media"; anchors.fill: parent; anchors.margins: bt.wide ? 8 : 12
        Rectangle {
            id: cover
            width: bt.wide ? parent.height : 52; height: width; radius: bt.wide ? 14 : 14; color: Theme.secondaryContainer; clip: true
            RoundedImage { anchors.fill: parent; radius: parent.radius; visible: !!bt.media && !!bt.media.art; source: bt.media ? bt.media.art || "" : ""; decodeSize: Qt.size(128, 128) }
            Glyph { anchors.centerIn: parent; visible: !bt.media || !bt.media.art; name: "music_note"; font.pixelSize: 24; color: Theme.onSecondaryContainer }
        }
        Column {
            x: cover.width + 10; y: bt.wide ? (parent.height - height) / 2 : 4; width: parent.width - x - (bt.wide ? 44 : 0); spacing: 2
            MText { width: parent.width; text: bt.media ? bt.media.title : "Nothing playing"; role: "titleS"; elide: Text.ElideRight }
            MText { width: parent.width; text: bt.media ? bt.media.subtitle || "" : ""; role: "labelS"; color: Theme.subtext; elide: Text.ElideRight; visible: text !== "" }
        }
        MButton {
            visible: bt.wide; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            icon: bt.playing ? "pause" : "play"; compact: true; implicitWidth: 40; implicitHeight: 40; tonal: true; tooltip: bt.playing ? "Pause" : "Play"; onClicked: Hub.media("play-pause")
        }
        Row {
            visible: !bt.wide; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
            MButton { icon: "previous"; compact: true; implicitWidth: 34; implicitHeight: 34; tooltip: "Previous"; onClicked: Hub.media("previous") }
            MButton { icon: bt.playing ? "pause" : "play"; compact: true; implicitWidth: 52; implicitHeight: 34; filled: true; tooltip: bt.playing ? "Pause" : "Play"; onClicked: Hub.media("play-pause") }
            MButton { icon: "skip"; compact: true; implicitWidth: 34; implicitHeight: 34; tooltip: "Next"; onClicked: Hub.media("next") }
        }
    }
    // Timer: a ring and quick controls.
    Item {
        visible: bt.kind === "focus"; anchors.fill: parent; anchors.margins: 12
        Canvas {
            id: ring
            width: bt.wide ? parent.height : 64; height: width; anchors.verticalCenter: parent.verticalCenter
            property real value: Hub.focusRunning ? 1 - Hub.focusSeconds / Math.max(1, Hub.focusTotal || 1500) : 0
            property color ink: Theme.tertiary
            onValueChanged: requestPaint(); onInkChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"), r = width / 2 - 4; c.reset(); c.lineWidth = bt.wide ? 4 : 6; c.lineCap = "round";
                c.strokeStyle = Theme.alpha(ink, .25); c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke();
                if (value > 0) { c.strokeStyle = ink; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, value)); c.stroke(); }
            }
            Glyph { visible: bt.wide; anchors.centerIn: parent; name: "timer"; font.pixelSize: 18 }
            MText { visible: !bt.wide; anchors.centerIn: parent; text: Math.floor(Hub.focusSeconds / 60) + ":" + bt.pad(Hub.focusSeconds % 60); role: "label"; font.weight: Font.Bold; font.features: {"tnum": 1} }
        }
        Column {
            x: ring.width + 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x; spacing: bt.wide ? 0 : 8
            MText { text: bt.wide ? Math.floor(Hub.focusSeconds / 60) + ":" + bt.pad(Hub.focusSeconds % 60) : "Timer"; role: "titleS"; font.features: {"tnum": 1} }
            MText { visible: bt.wide; text: Hub.focusRunning ? "Running" : "Paused"; role: "labelS"; color: Theme.subtext }
            Row {
                visible: !bt.wide; spacing: 6
                MButton { text: "+1"; compact: true; implicitWidth: 44; implicitHeight: 32; contained: true; tooltip: "Add a minute"; onClicked: Hub.focusSeconds += 60 }
                MButton { icon: Hub.focusRunning ? "pause" : "play"; compact: true; implicitWidth: 32; implicitHeight: 32; tonal: true; tooltip: Hub.focusRunning ? "Pause" : "Start"; onClicked: Hub.timerToggle() }
            }
        }
        MButton { visible: bt.wide; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; icon: Hub.focusRunning ? "pause" : "play"; compact: true; implicitWidth: 40; implicitHeight: 40; tonal: true
            tooltip: Hub.focusRunning ? "Pause" : "Start"; onClicked: Hub.timerToggle() }
    }
    // Devices: batteries of connected devices.
    Column {
        visible: bt.kind === "devices"; anchors.fill: parent; anchors.margins: 14; spacing: bt.wide ? 6 : 10
        MText { visible: !bt.wide; text: "Devices"; role: "titleS" }
        Repeater {
            model: HomeData.devices.slice(0, bt.wide ? 2 : 3)
            Row {
                required property var modelData
                spacing: 8
                Glyph { name: modelData.icon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: bt.width - 100; height: 6; radius: 3; color: Theme.alpha(Theme.text, .15); anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: parent.width * modelData.percent / 100; height: 6; radius: 3; color: modelData.percent < 20 ? Theme.error : Theme.primary }
                }
                MText { text: modelData.percent + "%"; role: "labelS"; font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        MText { visible: HomeData.devices.length === 0; text: "No devices with a battery"; role: "labelS"; color: Theme.subtext }
    }
}
