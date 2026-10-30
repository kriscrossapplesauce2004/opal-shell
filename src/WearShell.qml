import QtQuick

// Luna wear: the round watch shell. It shows one view: face, notification, media, live, approve or tiles. The layout is for a 454 px display and scales to the item size.
Item {
    id: wear
    property string view: "face"
    property var health: ({heart: 72, steps: 6412, goal: 10000, move: .68})
    property int watchBattery: 82
    property real mediaProgress: .38
    property real volume: .6
    property int phoneBattery: Hub.status.battery === undefined ? -1 : Hub.status.battery
    readonly property var note: Notifier.entries.length ? Notifier.entries[0] : null
    readonly property var media: Activities.byId["media"] || null
    readonly property var live: Activities.list.filter(a => a.kind !== "media")
    readonly property var agent: Activities.list.find(a => a.kind === "agent") || null
    readonly property var pill: live.find(a => a.kind !== "agent") || null
    function ago(t) { const m = Math.round((Hub.now.getTime() - t) / 60000); return m < 1 ? "now" : m < 60 ? m + " min" : Math.round(m / 60) + " h"; }
    implicitWidth: 454; implicitHeight: 454

    Item {
        id: face
        width: 454; height: 454
        scale: Math.min(wear.width, wear.height) / 454; transformOrigin: Item.TopLeft
        Rectangle { anchors.fill: parent; radius: width / 2; color: "#000000" }

        // Face: activity rings, the stacked clock, two complications and the top live activity.
        Item {
            anchors.fill: parent; visible: wear.view === "face"
            ProgressRing { anchors.fill: parent; anchors.margins: 8; lineWidth: 12; ink: Theme.primary; value: wear.health.move }
            ProgressRing { anchors.fill: parent; anchors.margins: 24; lineWidth: 12; ink: Theme.secondary; value: wear.health.steps / wear.health.goal }
            MText { anchors.horizontalCenter: parent.horizontalCenter; y: 76; text: Qt.formatDateTime(Hub.now, "ddd d").toUpperCase(); role: "label"; font.pixelSize: 16; font.letterSpacing: 2; color: Theme.tertiary }
            LockClock { anchors.centerIn: parent; anchors.verticalCenterOffset: -4; kind: "stacked"; tone: "primary"; size: 112 }
            Repeater {
                model: [{x: 52, icon: "favorite", value: wear.health.heart, part: wear.health.heart / 180, ink: Theme.tertiary},
                        wear.phoneBattery >= 0 ? {x: 454 - 52 - 84, icon: "smartphone", value: wear.phoneBattery + "%", part: wear.phoneBattery / 100, ink: Theme.secondary} : {x: 454 - 52 - 84, icon: "footprint", value: (wear.health.steps / 1000).toFixed(1) + "k", part: wear.health.steps / wear.health.goal, ink: Theme.secondary}]
                Item {
                    required property var modelData
                    x: modelData.x; y: 227 - 42; width: 84; height: 84
                    ProgressRing { anchors.fill: parent; lineWidth: 6; ink: parent.modelData.ink; value: parent.modelData.part }
                    Column {
                        anchors.centerIn: parent; spacing: -2
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: parent.parent.modelData.icon; font.pixelSize: 20; color: parent.parent.modelData.ink }
                        MText { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.value; role: "titleS"; font.features: {"tnum": 1} }
                    }
                }
            }
            Rectangle {
                visible: wear.pill !== null
                anchors.horizontalCenter: parent.horizontalCenter; y: 354; height: 40; radius: 20; width: pillRow.implicitWidth + 28
                color: Theme.tertiaryContainer
                Row {
                    id: pillRow; anchors.centerIn: parent; spacing: 6
                    Glyph { name: wear.pill ? wear.pill.icon : ""; font.pixelSize: 20; color: Theme.tertiaryInk; anchors.verticalCenter: parent.verticalCenter }
                    MText { text: wear.pill ? wear.pill.short : ""; role: "titleS"; font.features: {"tnum": 1}; color: Theme.tertiaryInk; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // Notification: the newest entry from the phone, with suggested replies and voice.
        Column {
            visible: wear.view === "notification" && wear.note !== null
            anchors.centerIn: parent; width: 330; spacing: 10
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Rectangle { width: 36; height: 36; radius: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                    Glyph { anchors.centerIn: parent; name: "chat"; font.pixelSize: 20; color: Theme.primaryInk } }
                MText { text: wear.note ? wear.note.notification.appName + " · " + wear.ago(wear.note.received) : ""; role: "label"; font.pixelSize: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            }
            MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: wear.note ? wear.note.notification.summary : ""; role: "headline" }
            MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: wear.note ? wear.note.notification.body : ""; role: "title"; font.weight: Font.Normal; wrapMode: Text.Wrap; maximumLineCount: 3 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8; topPadding: 6
                Repeater {
                    model: ["On my way", "Sure"]
                    Rectangle { required property string modelData; width: replyText.implicitWidth + 32; height: 48; radius: 24; color: Theme.secondaryContainer
                        MText { id: replyText; anchors.centerIn: parent; text: parent.modelData; role: "titleS"; color: Theme.secondaryInk } }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                MButton { icon: "keyboard"; implicitWidth: 52; implicitHeight: 52; tonal: true; tooltip: "Type a reply" }
                MButton { icon: "mic"; implicitWidth: 72; implicitHeight: 52; filled: true; tooltip: "Reply by voice" }
            }
        }

        // Media: the art fills the face, progress runs on the rim, and the crown arc shows the volume.
        Item {
            anchors.fill: parent; visible: wear.view === "media" && wear.media !== null
            RoundedImage { anchors.fill: parent; radius: width / 2; source: wear.media ? wear.media.art || "" : ""; decodeSize: Qt.size(454, 454) }
            Rectangle { anchors.fill: parent; radius: width / 2; gradient: Gradient { GradientStop { position: 0; color: Theme.alpha("#000000", .25) } GradientStop { position: .55; color: Theme.alpha("#000000", .7) } GradientStop { position: 1; color: Theme.alpha("#000000", .85) } } }
            ProgressRing { anchors.fill: parent; anchors.margins: 6; lineWidth: 8; ink: Theme.primary; value: wear.mediaProgress }
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const c = getContext("2d"), r = width / 2 - 30, a = Math.PI / 7; c.reset(); c.lineWidth = 8; c.lineCap = "round";
                    c.strokeStyle = Theme.alpha("#ffffff", .25); c.beginPath(); c.arc(width / 2, height / 2, r, -a, a); c.stroke();
                    c.strokeStyle = String(Theme.secondary); c.beginPath(); c.arc(width / 2, height / 2, r, a, a - 2 * a * wear.volume, true); c.stroke();
                }
            }
            Column {
                anchors.centerIn: parent; anchors.verticalCenterOffset: 34; width: 300; spacing: 4
                MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: wear.media ? wear.media.title : ""; role: "headline"; color: "#ffffff" }
                MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: wear.media ? wear.media.subtitle : ""; role: "title"; font.weight: Font.Normal; color: Theme.alpha("#ffffff", .75) }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 14; topPadding: 14
                    MButton { icon: "previous"; implicitWidth: 56; implicitHeight: 56; tonal: true; tooltip: "Previous"; anchors.verticalCenter: parent.verticalCenter }
                    MButton { icon: wear.media && wear.media.playing ? "pause" : "play"; implicitWidth: 84; implicitHeight: 72; filled: true; tooltip: "Play or pause"; anchors.verticalCenter: parent.verticalCenter }
                    MButton { icon: "skip"; implicitWidth: 56; implicitHeight: 56; tonal: true; tooltip: "Next"; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 6; topPadding: 10
                    Glyph { name: "smartphone"; font.pixelSize: 16; color: Theme.alpha("#ffffff", .75) }
                    MText { text: "Playing on phone"; role: "label"; font.pixelSize: 15; color: Theme.alpha("#ffffff", .75) }
                }
            }
        }

        // Live: the phone's live activities, one row each.
        Column {
            visible: wear.view === "live"
            anchors.centerIn: parent; width: 340; spacing: 10
            MText { anchors.horizontalCenter: parent.horizontalCenter; text: "Live · " + wear.live.length; role: "label"; font.pixelSize: 16; color: Theme.subtext; bottomPadding: 4 }
            Repeater {
                model: wear.live.slice(0, 3)
                Rectangle {
                    required property var modelData
                    width: 340; height: 84; radius: 32; color: Theme.level(2)
                    Rectangle { id: liveIcon; x: 14; anchors.verticalCenter: parent.verticalCenter; width: 56; height: 56; radius: 28; color: parent.modelData.kind === "agent" ? Theme.primaryContainer : Theme.tertiaryContainer
                        Glyph { anchors.centerIn: parent; name: parent.parent.modelData.icon; font.pixelSize: 26; color: parent.parent.modelData.kind === "agent" ? Theme.containerInk : Theme.tertiaryInk } }
                    Column {
                        x: liveIcon.x + liveIcon.width + 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - 20; spacing: 2
                        MText { width: parent.width; text: parent.parent.modelData.title; role: "titleS"; font.pixelSize: 19 }
                        MText { width: parent.width; text: parent.parent.modelData.subtitle || ""; role: "label"; font.pixelSize: 15; color: Theme.subtext }
                        Rectangle { visible: parent.parent.modelData.progress >= 0; width: parent.width; height: 6; radius: 3; color: Theme.level(4)
                            Rectangle { width: parent.width * Math.max(0, parent.parent.parent.modelData.progress); height: 6; radius: 3; color: Theme.tertiary } }
                    }
                }
            }
        }

        // Approve: an agent waits for a yes before it acts. The watch shows what it will do.
        Column {
            visible: wear.view === "approve" && wear.agent !== null
            anchors.centerIn: parent; width: 320; spacing: 10
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; radius: 28; color: Theme.primaryContainer
                Glyph { anchors.centerIn: parent; name: wear.agent ? wear.agent.icon : ""; font.pixelSize: 28; color: Theme.containerInk } }
            MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: wear.agent ? wear.agent.title : ""; role: "title" }
            MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: wear.agent ? wear.agent.subtitle || "" : ""; role: "label"; font.pixelSize: 16; color: Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 2 }
            Rectangle {
                visible: !!(wear.agent && wear.agent.code); width: parent.width; height: codeText.implicitHeight + 24; radius: 20; color: Theme.level(2)
                MText { id: codeText; anchors.centerIn: parent; width: parent.width - 28; text: wear.agent ? "“" + (wear.agent.code || "") + "”" : ""; role: "body"; font.pixelSize: 17; color: Theme.text; wrapMode: Text.Wrap; maximumLineCount: 3; horizontalAlignment: Text.AlignHCenter }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 10; topPadding: 6
                MButton { text: "Deny"; implicitHeight: 56; implicitWidth: 120; tonal: true }
                MButton { text: "Allow"; implicitHeight: 56; implicitWidth: 120; filled: true }
            }
        }

        // Tiles: both batteries and six round toggles.
        Column {
            visible: wear.view === "tiles"
            anchors.centerIn: parent; spacing: 16
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 18
                Repeater {
                    model: [{icon: "watch", value: wear.watchBattery}, {icon: "smartphone", value: Hub.status.battery || 0}]
                    Row { required property var modelData; spacing: 4
                        Glyph { name: parent.modelData.icon; font.pixelSize: 20; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: parent.modelData.value + "%"; role: "title"; font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter } }
                }
            }
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter; columns: 3; spacing: 14
                Repeater {
                    model: [{icon: "wifi", on: !!Hub.status.wifi}, {icon: "do_not_disturb_on", on: !!Hub.prefs.dnd}, {icon: "phonelink_ring", on: false},
                            {icon: "flashlight_on", on: false}, {icon: "battery_saver", on: false}, {icon: "bedtime", on: true}]
                    Rectangle {
                        required property var modelData
                        width: 96; height: 96; radius: modelData.on ? 32 : 48; color: modelData.on ? Theme.primary : Theme.level(3)
                        Glyph { anchors.centerIn: parent; name: parent.modelData.icon; font.pixelSize: 34; color: parent.modelData.on ? Theme.primaryInk : Theme.text }
                    }
                }
            }
            MText { anchors.horizontalCenter: parent.horizontalCenter; text: "Bedtime until 07:00"; role: "label"; font.pixelSize: 16; color: Theme.subtext }
        }

        // The display is round: paint black outside the circle so square images do not show past the edge.
        Canvas {
            anchors.fill: parent
            onPaint: { const c = getContext("2d"); c.reset(); c.fillStyle = "#000000"; c.fillRule = Qt.OddEvenFill; c.beginPath(); c.rect(0, 0, width, height); c.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI); c.fill(); }
        }
    }
}
