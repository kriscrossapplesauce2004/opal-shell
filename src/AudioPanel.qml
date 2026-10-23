import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Sound and music: the player on top, then outputs and volume in their own sections. The player never names the output device.
Item {
    id: p
    readonly property var sinks: Pipewire.nodes.values.filter(n => n && n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => n && !n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n && n.isStream && n.type === PwNodeType.AudioOutStream && n.audio)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property var streamSinks: ({})
    implicitHeight: column.implicitHeight + 36
    PwObjectTracker { objects: p.sinks.concat(p.streams).concat(p.sources) }
    function cycleStreamSink(streamNode) {
        if (!streamNode || p.sinks.length < 2) return;
        const currentName = p.streamSinks[streamNode.id] || (p.sink ? p.sink.name : "");
        const idx = Math.max(0, p.sinks.findIndex(s => s.name === currentName));
        const nextSink = p.sinks[(idx + 1) % p.sinks.length];
        if (!nextSink) return;
        const map = Object.assign({}, p.streamSinks);
        map[streamNode.id] = nextSink.name;
        p.streamSinks = map;
        const props = nextSink.properties || {};
        const target = String(props["object.serial"] || nextSink.name || "");
        if (target && streamNode.id) Hub.command({action: "audio-route-stream", streamId: Number(streamNode.id), sinkTarget: target});
    }
    function friendly(node) {
        if (!node) return "";
        const props = node.properties || {};
        return node.nickname || props["device.product.name"] || props["alsa.card_name"] || node.description || node.name;
    }
    function detail(node) {
        const d = node ? (node.description || "") : "";
        const props = node ? node.properties || {} : {};
        const bus = /hdmi|displayport|\bdp\b/i.test(d) ? "HDMI" : props["device.bus"] === "bluetooth" || props["api.bluez5.address"] ? "Bluetooth" : props["device.bus"] === "usb" ? "USB" : "";
        const chip = (d.match(/^(\S+(?:\s\d+\S*)?)/) || ["", ""])[1].replace(/\/.*$/, "");
        return [bus, bus && chip && friendly(node) !== d ? chip : ""].filter(x => x).join(" · ");
    }
    function icon(node) {
        const d = ((node && node.description) || "") + " " + JSON.stringify(node ? node.properties || {} : {});
        return /headphone|headset|buds|bluez/i.test(d) ? "headphones" : /hdmi|displayport/i.test(d) ? "monitor" : "speaker";
    }
    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            MText { text: "Sound & music"; role: "title"; Layout.fillWidth: true; leftPadding: 4 }
            MButton { icon: "close"; implicitWidth: 38; implicitHeight: 38; tooltip: "Close sound & music"; onClicked: Hub.closeAudio() }
        }
        MediaPlayerCard { Layout.fillWidth: true; Layout.preferredHeight: implicitHeight }
        MText { visible: p.sinks.length > 1; text: "Output"; role: "labelS"; font.letterSpacing: 1; color: Theme.primary; leftPadding: 6 }
        Column {
            visible: p.sinks.length > 1
            Layout.fillWidth: true; spacing: 4
            Repeater {
                model: p.sinks
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool on: modelData === p.sink
                    width: parent.width; height: 56; radius: 20
                    color: on ? Theme.secondaryContainer : rowMouse.containsMouse ? Theme.alpha(Theme.text, .06) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                        Glyph { Layout.preferredWidth: 26; name: p.icon(row.modelData); font.pixelSize: 22; color: row.on ? Theme.onSecondaryContainer : Theme.text }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            MText { Layout.fillWidth: true; text: p.friendly(row.modelData); role: "titleS"; color: row.on ? Theme.onSecondaryContainer : Theme.text }
                            MText { Layout.fillWidth: true; visible: text !== ""; text: p.detail(row.modelData); role: "labelS"; color: Theme.subtext }
                        }
                        Glyph { visible: row.on; name: "check"; font.pixelSize: 20; color: Theme.onSecondaryContainer }
                    }
                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSink = row.modelData }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: p.friendly(row.modelData)
                    Accessible.checked: row.on
                }
            }
        }
        MText { text: "Volume"; role: "labelS"; font.letterSpacing: 1; color: Theme.primary; leftPadding: 6 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            ExpressiveSlider {
                Layout.fillWidth: true; implicitHeight: 52; compact: true; trackHeight: 44; wheelEnabled: false
                icon: Hub.status.muted ? "mute" : "volume"; iconAtHandle: true; value: Hub.status.volume
                activeColor: Hub.status.muted ? Theme.subtext : Theme.primary
                onMoved: Hub.volume(value)
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: Hub.command({action: "mute"}) }
                Accessible.name: "Volume"
            }
            MText { text: Hub.status.muted ? "Off" : Hub.status.volume + "%"; role: "label"; font.weight: Font.Bold; font.features: {"tnum": 1}; Layout.preferredWidth: 40 }
        }
        // Each app that plays sound gets its own slider, mute button and output sink selector.
        Repeater {
            model: p.streams
            RowLayout {
                id: app
                required property var modelData
                readonly property var props: modelData.properties || {}
                readonly property bool isMuted: !!(modelData.audio && modelData.audio.muted)
                Layout.fillWidth: true; spacing: 8
                AppIcon { Layout.preferredWidth: 26; Layout.preferredHeight: 26; Layout.leftMargin: 6; style: "raw"; name: app.props["application.icon-name"] || (app.props["application.process.binary"] || "").toLowerCase() }
                MText { Layout.preferredWidth: 78; text: app.props["application.name"] || app.modelData.description || "App"; role: "label"; color: Theme.subtext; elide: Text.ElideRight }
                MButton {
                    icon: app.isMuted ? "volume_off" : "volume_up"
                    compact: true; implicitWidth: 28; implicitHeight: 28
                    tonal: app.isMuted
                    tooltip: app.isMuted ? "Unmute app" : "Mute app"
                    onClicked: if (app.modelData.audio) app.modelData.audio.muted = !app.modelData.audio.muted
                }
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 24
                    readonly property real v: app.modelData.audio ? Math.min(1, app.modelData.audio.volume) : 0
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.level(3) }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * parent.v; height: 6; radius: 3; color: app.isMuted ? Theme.subtext : Theme.primary }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: parent.width * parent.v - 2; width: 4; height: 18; radius: 2; color: Theme.primary }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        function set(x) { if (app.modelData.audio) app.modelData.audio.volume = Math.max(0, Math.min(1, x / width)); }
                        onPressed: e => set(e.x)
                        onPositionChanged: e => { if (pressed) set(e.x); }
                    }
                    Accessible.role: Accessible.Slider
                    Accessible.name: (app.props["application.name"] || "App") + " volume"
                }
                MButton {
                    visible: p.sinks.length > 1
                    icon: "speaker"; compact: true; implicitWidth: 28; implicitHeight: 28
                    tooltip: "Switch output device for " + (app.props["application.name"] || "this app")
                    onClicked: p.cycleStreamSink(app.modelData)
                }
                MText { text: Math.round((app.modelData.audio ? app.modelData.audio.volume : 0) * 100) + "%"; role: "labelS"; color: Theme.subtext; Layout.preferredWidth: 34; font.features: {"tnum": 1} }
            }
        }
        MText { visible: p.sources.length > 0; text: "Microphone"; role: "labelS"; font.letterSpacing: 1; color: Theme.primary; leftPadding: 6 }
        RowLayout {
            visible: p.sources.length > 0
            Layout.fillWidth: true; spacing: 8
            MButton {
                icon: Hub.status.micMuted ? "mic_off" : "mic"
                text: Hub.status.micMuted ? "Microphone muted" : (p.source ? p.friendly(p.source) : "Microphone ready")
                tonal: true; compact: true; Layout.fillWidth: true
                onClicked: Hub.command({action: "mic"})
            }
            MButton {
                visible: p.sources.length > 1
                icon: "swap_horiz"; compact: true; implicitWidth: 34; implicitHeight: 34
                tooltip: "Cycle input microphone"
                onClicked: {
                    const idx = Math.max(0, p.sources.indexOf(p.source));
                    const next = p.sources[(idx + 1) % p.sources.length];
                    if (next) Pipewire.preferredDefaultAudioSource = next;
                }
            }
        }
    }
    WheelHandler {
        target: null
        onWheel: event => {
            const delta = event.angleDelta.y || event.pixelDelta.y;
            if (delta) { Hub.volume(Math.max(0, Math.min(100, Hub.status.volume + (delta > 0 ? 2 : -2)))); event.accepted = true; }
        }
    }
}
