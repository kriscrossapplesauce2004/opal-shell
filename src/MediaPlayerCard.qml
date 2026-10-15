import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// Pixel Quick Settings style player: calm art, the source app, a squiggle that seeks, and a dot per player. It never shows the output device.
Item {
    id: pc
    property bool small: false
    // The chosen player. Empty means the first one that plays.
    property string chosen: ""
    readonly property var players: Mpris.players.values.filter(p => p.trackTitle !== "" || p.isPlaying)
    readonly property var player: {
        const list = players;
        const picked = list.find(p => p.dbusName === chosen);
        return picked || list.find(p => p.isPlaying) || list[0] || null;
    }
    readonly property bool playing: !!player && player.isPlaying
    readonly property real fraction: player && player.lengthSupported && player.length > 0 ? player.position / player.length : 0
    readonly property string appName: player ? (player.identity || "Media") : ""
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0)), h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, r = s % 60;
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }
    function step(delta) {
        if (players.length < 2) return;
        const i = Math.max(0, players.indexOf(player));
        chosen = players[(i + delta + players.length) % players.length].dbusName;
    }
    implicitWidth: 380
    implicitHeight: small ? 156 : 196
    // Position is not a notifying property. Ask the player to refresh it once a second while it plays.
    Timer { interval: 1000; repeat: true; running: pc.playing && pc.visible; onTriggered: if (pc.player) pc.player.positionChanged() }

    Rectangle { anchors.fill: parent; radius: 28; color: Theme.level(3) }
    RoundedImage {
        id: art
        anchors.fill: parent; radius: 28; visible: !!pc.player && pc.player.trackArtUrl !== ""
        source: pc.player ? pc.player.trackArtUrl : ""; decodeSize: Qt.size(720, 400)
    }
    Rectangle {
        anchors.fill: parent; radius: 28
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(Theme.base, art.visible ? (Theme.light ? .5 : .55) : 0) }
            GradientStop { position: 1; color: Theme.alpha(Theme.base, art.visible ? (Theme.light ? .82 : .88) : 0) }
        }
    }
    // Swipe sideways to change the player.
    DragHandler {
        target: null; xAxis.enabled: true; yAxis.enabled: false
        onActiveChanged: if (!active && Math.abs(centroid.position.x - centroid.pressPosition.x) > 48) pc.step(centroid.position.x < centroid.pressPosition.x ? 1 : -1)
    }

    RowLayout {
        x: 18; y: 16; width: pc.width - 36; spacing: 8
        AppIcon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; style: "raw"; name: pc.player ? (pc.player.desktopEntry || "") : ""; visible: !!pc.player && pc.player.desktopEntry !== "" }
        MText { Layout.fillWidth: true; text: pc.player ? pc.appName : "Nothing playing"; role: "label"; color: Theme.subtext }
        Row {
            spacing: 4; visible: pc.players.length > 1
            Repeater {
                model: pc.players
                Rectangle {
                    required property var modelData
                    width: modelData === pc.player ? 14 : 6; height: 6; radius: 3
                    color: modelData === pc.player ? Theme.text : Theme.alpha(Theme.text, .35)
                    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: pc.chosen = modelData.dbusName }
                }
            }
        }
    }
    ColumnLayout {
        x: 18; y: pc.small ? 46 : 56; width: pc.width - 36 - 80; spacing: 2
        MText { Layout.fillWidth: true; text: pc.player ? pc.player.trackTitle : "Start playback in any player"; role: pc.small ? "titleS" : "title" }
        MText { Layout.fillWidth: true; visible: text !== ""; text: pc.player ? pc.player.trackArtist : ""; role: "bodyS"; color: Theme.subtext }
    }
    Rectangle {
        id: playButton
        anchors.right: parent.right; anchors.rightMargin: 18; y: pc.small ? 42 : 50
        width: 62; height: 62; radius: pc.playing ? 22 : 31; color: Theme.primaryContainer
        opacity: pc.player && pc.player.canTogglePlaying ? 1 : .5
        Behavior on radius { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
        Glyph { anchors.centerIn: parent; name: pc.playing ? "pause" : "play"; font.pixelSize: 30; color: Theme.containerInk }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !!pc.player && pc.player.canTogglePlaying; onClicked: pc.player.togglePlaying() }
        Accessible.role: Accessible.Button
        Accessible.name: pc.playing ? "Pause" : "Play"
    }
    RowLayout {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12; x: 10; width: pc.width - 20; spacing: 6
        MButton { icon: "previous"; compact: true; implicitWidth: 34; implicitHeight: 34; enabled: !!pc.player && pc.player.canGoPrevious; tooltip: "Previous"; onClicked: pc.player.previous() }
        MText { visible: !!pc.player && pc.player.positionSupported; text: pc.clock(pc.player ? pc.player.position : 0); role: "labelS"; color: Theme.subtext; font.features: {"tnum": 1} }
        Squiggle {
            Layout.fillWidth: true; Layout.preferredHeight: 24; value: pc.fraction; playing: pc.playing
            seekable: !!pc.player && pc.player.canSeek && pc.player.lengthSupported
            onSeeked: f => { if (pc.player) pc.player.position = f * pc.player.length; }
        }
        MText { visible: !!pc.player && pc.player.lengthSupported; text: pc.clock(pc.player ? pc.player.length : 0); role: "labelS"; color: Theme.subtext; font.features: {"tnum": 1} }
        MButton { icon: "skip"; compact: true; implicitWidth: 34; implicitHeight: 34; enabled: !!pc.player && pc.player.canGoNext; tooltip: "Next"; onClicked: pc.player.next() }
    }
}
