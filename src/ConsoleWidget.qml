import QtQuick
import QtQuick.Layouts

// One console home widget. Each does its job in place (A) and opens its sheet (X).
// Kinds: updates, devices, music, storage, captures, next, minecraft, toggles, claude.
Rectangle {
    id: w
    property string kind: "updates"
    property bool glass: false
    property bool editing: false
    property bool controllerFocused: false
    signal openSheet(string kind)
    readonly property var wd: GameState.widgets
    readonly property var updates: wd.updates || []
    readonly property var storage: wd.storage || ({})
    readonly property var shots: (wd.captures || {}).items || []
    readonly property var instances: wd.instances || []
    readonly property var meta: ({
        updates: {g: "download", t: "Updates"}, devices: {g: "devices", t: "Devices"}, music: {g: "music_note", t: "Music"},
        storage: {g: "hard_drive", t: "Storage"}, captures: {g: "photo_library", t: "Captures"}, next: {g: "tune", t: "Next game"},
        minecraft: {g: "deployed_code", t: "Minecraft"}, toggles: {g: "toggle_on", t: "Toggles"}, claude: {g: "auto_awesome", t: "Ask Claude"}})
    function bytesText(b) { return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : b >= 1048576 ? Math.round(b / 1048576) + " MB" : b >= 1024 ? Math.round(b / 1024) + " KB" : b > 0 ? b + " B" : ""; }
    function gameFor(id) { return Hub.games.find(g => g.id === id) || null; }
    function titleFor(id) { const g = gameFor(id); return g ? g.title : ""; }
    // A runs the widget's main job.
    function controllerActivate() {
        if (kind === "updates") Hub.command({action: "steam-downloads"});
        else if (kind === "devices") Hub.settings("bluetooth");
        else if (kind === "music") Hub.media("play-pause");
        else if (kind === "captures") { if (shots.length) Hub.command({action: "open-path", path: shots[0].path}); }
        else if (kind === "next") Hub.set("gameProfileNext", ({saver: "balanced", balanced: "max", max: "saver"})[Hub.prefs.gameProfileNext || "balanced"]);
        else if (kind === "claude") Hub.openAssistant();
        else openSheet(kind);
    }
    function controllerAlternate() { openSheet(kind); }
    radius: 28
    color: kind === "music" || kind === "captures" ? Theme.level(3) : glass ? Theme.alpha(Theme.level(2), .86) : Theme.level(2)
    border.width: editing ? 2 : 0; border.color: Theme.alpha(Theme.primary, .4)
    clip: false

    // Header for card widgets.
    Row {
        visible: w.kind !== "music" && w.kind !== "captures"
        x: 18; y: 16; spacing: 8
        Glyph { name: w.meta[w.kind] ? w.meta[w.kind].g : "widgets"; font.pixelSize: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        MText { text: w.meta[w.kind] ? w.meta[w.kind].t : ""; role: "label"; font.weight: Font.Bold; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
    }
    // Most widgets are one controller target and their small buttons are for the pointer.
    // Next game, Minecraft and Toggles are rows of choices, so the controller reaches each choice instead.
    readonly property bool choices: kind === "next" || kind === "minecraft" || kind === "toggles"
    MouseArea {
        anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
        property bool controllerSkip: w.choices
        onClicked: e => { if (e && e.button === Qt.RightButton) w.controllerAlternate(); else w.controllerActivate(); }
    }

    Loader {
        property bool controllerSkip: !w.choices
        anchors.fill: parent
        sourceComponent: ({updates: updatesView, devices: devicesView, music: musicView, storage: storageView, captures: capturesView,
                           next: nextView, minecraft: minecraftView, toggles: togglesView, claude: claudeView})[w.kind] || null
    }

    Component {
        id: updatesView
        Item {
            MButton {
                anchors.right: parent.right; anchors.rightMargin: 12; y: 10
                visible: w.updates.length > 0; text: "Update all"; icon: "download"; tonal: true; compact: true
                onClicked: Hub.command({action: "steam-downloads"})
            }
            Column {
                x: 16; y: 54; width: parent.width - 32; spacing: 6
                Repeater {
                    model: w.updates.slice(0, Math.max(1, Math.floor((w.height - 60) / 36)))
                    Row {
                        required property var modelData
                        width: parent.width; spacing: 10
                        RoundedImage { width: 30; height: 30; radius: 9; source: w.gameFor(modelData.id) ? w.gameFor(modelData.id).cover || "" : ""; decodeSize: Qt.size(60, 90) }
                        MText { text: modelData.title; role: "label"; font.weight: Font.DemiBold; width: parent.width - 120; anchors.verticalCenter: parent.verticalCenter }
                        MText {
                            width: 70; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.state === "paused" ? "Paused" : modelData.state === "downloading" ? "Downloading" : w.bytesText(modelData.bytes) || "Queued"
                            role: "labelS"; color: Theme.subtext; font.features: {"tnum": 1}
                        }
                    }
                }
                MText { visible: w.updates.length === 0; text: "Every game is up to date"; role: "body"; color: Theme.subtext }
            }
        }
    }
    Component {
        id: devicesView
        Item {
            readonly property var items: {
                const list = (GameState.perf.controllers || []).map(c => ({g: "stadia_controller", v: c.percent, t: c.percent + "%", name: c.name}));
                HomeData.devices.forEach(d => { if (!list.some(x => x.name === d.name)) list.push({g: d.icon, v: d.percent, t: d.percent + "%", name: d.name}); });
                if (Hub.status.battery >= 0) list.push({g: Hub.status.charging ? "battery_charging_full" : "battery_5_bar", v: Hub.status.battery, t: Hub.status.battery + "%", name: "This device"});
                const capped = list.slice(0, w.width > 340 ? 3 : 2);
                capped.push({g: "add", v: -1, t: "Pair", name: "Pair a controller"});
                return capped;
            }
            Flow {
                x: 18; y: 48; width: parent.width - 36; spacing: 22
                Repeater {
                    model: parent.parent.items
                    Column {
                        required property var modelData
                        spacing: 3
                        Item {
                            width: 44; height: 44; anchors.horizontalCenter: parent.horizontalCenter
                            ProgressRing { anchors.fill: parent; visible: modelData.v >= 0; value: Math.max(0, modelData.v) / 100; lineWidth: 4; ink: modelData.v >= 0 && modelData.v < 20 ? Theme.error : Theme.primary }
                            Rectangle { anchors.fill: parent; visible: modelData.v < 0; radius: 22; color: Theme.tertiaryContainer }
                            Glyph { anchors.centerIn: parent; name: modelData.g; font.pixelSize: 20; color: modelData.v < 0 ? Theme.onTertiaryContainer : Theme.text }
                        }
                        MText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; role: "labelS"; font.weight: Font.Bold; font.features: {"tnum": 1} }
                    }
                }
            }
        }
    }
    Component { id: musicView; MediaPlayerCard { small: true } }
    Component {
        id: storageView
        Item {
            id: sv
            readonly property real total: w.storage.total || 0
            readonly property real free: w.storage.free || 0
            readonly property real games: w.storage.games || 0
            readonly property real other: Math.max(0, total - free - games)
            Column {
                x: 18; y: 46; width: parent.width - 36; spacing: 10
                Row {
                    spacing: 6
                    MText { text: sv.total ? w.bytesText(sv.free) : "—"; role: "headline"; font.features: {"tnum": 1} }
                    MText { text: sv.total ? "free of " + Math.round(sv.total / 1073741824) : ""; role: "label"; color: Theme.subtext; topPadding: 12 }
                }
                StorageBar { width: parent.width; total: sv.total; parts: [{v: sv.games, c: Theme.primary}, {v: sv.other, c: Theme.alpha(Theme.text, .35)}, {v: sv.free, c: Theme.level(4)}] }
                Row {
                    spacing: 12
                    Repeater {
                        model: [{c: Theme.primary, t: "Games " + Math.round(sv.games / 1073741824)}, {c: Theme.alpha(Theme.text, .35), t: "Other " + Math.round(sv.other / 1073741824)}]
                        Row { required property var modelData; spacing: 5
                            Rectangle { width: 9; height: 9; radius: 4.5; color: modelData.c; anchors.verticalCenter: parent.verticalCenter }
                            MText { text: modelData.t; role: "labelS"; color: Theme.subtext } }
                    }
                }
                MText {
                    width: parent.width
                    text: (w.storage.largest || []).length ? "Biggest: " + w.storage.largest[0].title + " · " + w.bytesText(w.storage.largest[0].bytes) : ""
                    role: "labelS"
                }
            }
        }
    }
    Component {
        id: capturesView
        Item {
            RoundedImage { anchors.fill: parent; radius: 28; source: w.shots.length ? "file://" + w.shots[0].path : ""; decodeSize: Qt.size(560, 400) }
            Rectangle { anchors.fill: parent; radius: 28; gradient: Gradient { GradientStop { position: .3; color: "transparent" } GradientStop { position: 1; color: Theme.alpha("#000000", .8) } } }
            Column {
                x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; spacing: 1
                MText { text: "CAPTURES"; role: "labelS"; font.letterSpacing: 1.4; font.weight: Font.Bold; color: Theme.primary }
                MText { text: w.shots.length ? (w.titleFor(w.shots[0].id) || "Screenshot") + " · " + (w.wd.captures.perGame[w.shots[0].id] || 1) : "No screenshots yet"; role: "titleS"; color: "#ffffff" }
            }
            MButton {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12
                visible: w.shots.length > 0; icon: "content_copy"; tooltip: "Copy"; compact: true
                onClicked: Hub.command({action: "capture-copy", path: w.shots[0].path})
            }
        }
    }
    Component {
        id: nextView
        Item {
            Column {
                x: 16; y: 48; width: parent.width - 32; spacing: 10
                SegmentGroup {
                    width: parent.width
                    options: [{id: "saver", name: "Saver"}, {id: "balanced", name: "Balanced"}, {id: "max", name: "Max"}]
                    current: Hub.prefs.gameProfileNext || "balanced"
                    onPicked: id => Hub.set("gameProfileNext", id)
                }
                MText { width: parent.width; text: "Games with their own profile keep it"; role: "labelS"; color: Theme.subtext; wrapMode: Text.WordWrap }
            }
        }
    }
    Component {
        id: minecraftView
        Item {
            Flow {
                x: 16; y: 50; width: parent.width - 32; spacing: 6
                Repeater {
                    model: w.instances.slice(0, 4)
                    Chip { required property var modelData; text: modelData.title; icon: "play_arrow"; onClicked: Hub.launchGame({id: modelData.id}) }
                }
            }
        }
    }
    Component {
        id: togglesView
        Item {
            Grid {
                x: 12; y: 46; columns: 2; spacing: 8
                Repeater {
                    model: [{id: "dnd", g: "do_not_disturb_on", t: "Do not disturb", on: Hub.dnd}, {id: "awake", g: "coffee", t: "Keep awake", on: Hub.keepAwake},
                            {id: "wifi", g: "wifi", t: "Wi-Fi", on: !!Hub.status.wifi}, {id: "bt", g: "bluetooth", t: "Bluetooth", on: !!Hub.status.bluetooth}]
                    ShadeTile {
                        required property var modelData
                        width: (w.width - 32) / 2; implicitHeight: 52; dense: true
                        icon: modelData.g; title: modelData.t; active: modelData.on
                        onClicked: toggled()
                        onToggled: {
                            if (modelData.id === "dnd") Hub.set("dnd", !Hub.dnd);
                            else if (modelData.id === "awake") Hub.keepAwake = !Hub.keepAwake;
                            else if (modelData.id === "wifi") Hub.connection("wifi", "power", {enabled: !Hub.status.wifi});
                            else Hub.connection("bluetooth", "power", {enabled: !Hub.status.bluetooth});
                        }
                    }
                }
            }
        }
    }
    Component {
        id: claudeView
        Item {
            MText { x: 18; y: 50; width: parent.width - 36; text: "Ask about a game, a setting or what to play next. Hold Guide to talk."; role: "body"; color: Theme.subtext; wrapMode: Text.WordWrap }
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: meta[kind] ? meta[kind].t : kind
}
