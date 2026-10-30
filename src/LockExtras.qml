import QtQuick
import QtQuick.Layouts
import Quickshell

// Lock screen extras: one notification chip that grows into the list, the swipeable widget stack, two hold-to-fire corner shortcuts, Quick Settings while locked and the ambient clock.
Item {
    id: extras
    // The lock scene that hosts this item.
    property Item scene: null
    // The settings preview shows the lock without its live behaviour.
    property bool preview: false
    readonly property string privacy: Hub.prefs.lockNotifications || "title"
    readonly property bool idleReady: Hub.prefs.ambientClock !== false && !!scene && !scene.greeter && !preview
    readonly property bool notesAllowed: privacy !== "off" && privacy !== "count"
    readonly property bool phone: width < 600
    readonly property bool resting: !!scene && !scene.revealed && !scene.greeter
    property bool ambientOn: false
    property bool listOpen: false
    property bool quickOpen: false
    function wake() { ambientOn = false; idle.restart(); }
    function openQuick() { if (Hub.prefs.lockQuickSettings !== false) { quickOpen = true; wake(); } }
    function unlockThen(fn) { if (fn) Hub.whenUnlocked(fn); quickOpen = false; listOpen = false; if (scene) scene.reveal(); }
    onSceneChanged: idle.restart()
    Timer { id: idle; interval: 45000; running: extras.idleReady && !extras.ambientOn && !(extras.scene && extras.scene.revealed) && !extras.quickOpen && !extras.listOpen; onTriggered: extras.ambientOn = true }
    // A key press or revealing the auth column ends ambient mode and folds what was open.
    Connections { target: extras.scene; function onRevealedChanged() { if (extras.scene.revealed) { extras.wake(); extras.quickOpen = false; extras.listOpen = false; } } }

    // Tests set fixtureItems to show cards without a notification server.
    property var fixtureItems: null
    readonly property var items: fixtureItems !== null ? fixtureItems : realItems
    readonly property var realItems: {
        const revision = Notifier.revision;
        if (privacy === "off") return [];
        return Notifier.inbox.slice().sort((a, b) => b.received - a.received);
    }
    readonly property var apps: {
        const seen = {}, out = [];
        for (const e of items) {
            const n = e.notification, k = n ? (n.appName || n.appIcon || "") : "";
            if (!n || seen[k]) continue;
            seen[k] = true; out.push(n);
            if (out.length === 3) break;
        }
        return out;
    }

    // ---- Corner shortcuts ----
    readonly property var shortcuts: Object.assign(phone ? {left: PhoneState.torch.available ? "tile:torch" : "tile:dnd", right: "tile:awake"} : {left: "tile:dnd", right: "tile:theme"}, Hub.prefs.lockShortcuts || {})
    function shortcutIcon(sc) {
        const id = String(sc || "").slice(5);
        if (String(sc).startsWith("app:")) return "";
        return ({torch: PhoneState.torch.on ? "flashlight_on" : "flashlight_off", dnd: "do_not_disturb_on", awake: "coffee", theme: "dark_mode", mic: Hub.status.micMuted ? "mic_off" : "mic",
                 saver: "battery_saver", focus: "timer", wifi: Hub.status.wifi ? "wifi" : "wifi_off", bluetooth: "bluetooth"})[id] || "bolt";
    }
    function shortcutOn(sc) {
        const id = String(sc || "").slice(5);
        return ({torch: PhoneState.torch.on, dnd: Hub.dnd, awake: Hub.keepAwake, theme: !Theme.light, mic: !Hub.status.micMuted, saver: Hub.status.profile === "power-saver",
                 focus: Hub.focusRunning, wifi: !!Hub.status.wifi, bluetooth: !!Hub.status.bluetooth})[id] || false;
    }
    function fire(sc) {
        sc = String(sc || "");
        if (sc.startsWith("app:")) {
            const key = sc.slice(4).toLowerCase();
            unlockThen(() => { const app = Hub.apps.find(a => String(a.id).toLowerCase() === key); if (app) Hub.launchNew(app); });
            return;
        }
        switch (sc.slice(5)) {
        case "torch": PhoneState.setTorch(!PhoneState.torch.on); break;
        case "dnd": Hub.set("dnd", !Hub.dnd); break;
        case "awake": Hub.keepAwake = !Hub.keepAwake; break;
        case "theme": Hub.set("light", !Theme.light); break;
        case "mic": Hub.command({action: "mic"}); break;
        case "saver": if (Hub.status.profile) Hub.command({action: "profile", value: Hub.status.profile === "power-saver" ? "balanced" : "power-saver"}); break;
        case "focus": Hub.timerToggle(); break;
        case "wifi": Hub.connection("wifi", "power", {enabled: !Hub.status.wifi}); break;
        case "bluetooth": Hub.connection("bluetooth", "power", {enabled: !Hub.status.bluetooth}); break;
        }
    }
    component Corner: Item {
        id: corner
        property string sc: ""
        readonly property bool app: sc.startsWith("app:")
        readonly property var appEntry: app ? Hub.apps.find(a => String(a.id).toLowerCase() === sc.slice(4).toLowerCase()) || null : null
        readonly property bool on: extras.shortcutOn(sc)
        property real held: 0
        width: 64; height: 64
        visible: sc !== "" && extras.resting && !extras.listOpen
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: corner.on ? Theme.primaryContainer : Theme.alpha(Theme.level(3), .62)
            border.width: 1; border.color: Theme.alpha("#ffffff", .10)
            scale: 1 + corner.held * .12
        }
        // Holding fills a ring; a full ring fires the shortcut.
        Canvas {
            anchors.fill: parent; anchors.margins: -4; visible: corner.held > 0
            property real v: corner.held
            onVChanged: requestPaint()
            onPaint: { const c = getContext("2d"); c.reset(); c.lineWidth = 3; c.lineCap = "round"; c.strokeStyle = Theme.primary; c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * v); c.stroke(); }
        }
        Glyph { visible: !corner.app; anchors.centerIn: parent; name: extras.shortcutIcon(corner.sc); font.pixelSize: 26; color: corner.on ? Theme.onContainer : "#ffffff" }
        AppIcon { visible: corner.app; anchors.centerIn: parent; width: 30; height: 30; app: corner.appEntry }
        NumberAnimation { id: hold; target: corner; property: "held"; from: 0; to: 1; duration: 450; onFinished: { extras.fire(corner.sc); release.start(); } }
        NumberAnimation { id: release; target: corner; property: "held"; to: 0; duration: Theme.motion(160) }
        TapHandler {
            enabled: !extras.preview
            onPressedChanged: { if (pressed) { release.stop(); hold.start(); } else if (hold.running) { hold.stop(); release.start(); } }
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Hold to " + (corner.app ? "open " + (corner.appEntry ? corner.appEntry.name : "app") : "toggle " + corner.sc.slice(5))
        Accessible.onPressAction: extras.fire(corner.sc)
    }
    Corner { sc: extras.shortcuts.left || ""; x: extras.phone ? 28 : 48; anchors.bottom: parent.bottom; anchors.bottomMargin: extras.phone ? 48 : 60 }
    Corner { sc: extras.shortcuts.right || ""; anchors.right: parent.right; anchors.rightMargin: extras.phone ? 28 : 48; anchors.bottom: parent.bottom; anchors.bottomMargin: extras.phone ? 48 : 60 }

    // ---- Notifications and the widget stack, bottom centre ----
    Column {
        id: bottom
        visible: extras.resting
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: extras.phone ? 132 : 64
        width: Math.min(extras.phone ? extras.width - 32 : 460, extras.width - 48)
        spacing: 12
        // One chip: app icons and a count. It grows into the list.
        Rectangle {
            id: chip
            visible: extras.items.length > 0 && !extras.listOpen
            anchors.horizontalCenter: parent.horizontalCenter
            width: chipRow.implicitWidth + 28; height: 48; radius: 24
            color: chipTap.pressed ? Theme.alpha(Theme.level(4), .8) : Theme.alpha(Theme.level(3), .62)
            border.width: 1; border.color: Theme.alpha("#ffffff", .10)
            Row {
                id: chipRow; anchors.centerIn: parent; spacing: 10
                Row {
                    spacing: -8; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: extras.apps
                        Rectangle { required property var modelData; width: 28; height: 28; radius: 14; color: Theme.level(3)
                            AppIcon { anchors.centerIn: parent; width: 22; height: 22; name: parent.modelData.appIcon || parent.modelData.appName || "" } }
                    }
                }
                MText { text: extras.items.length + (extras.items.length === 1 ? " notification" : " notifications"); role: "label"; font.weight: Font.DemiBold; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                Glyph { visible: extras.notesAllowed; name: "expand_less"; font.pixelSize: 18; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
            TapHandler { id: chipTap; enabled: extras.notesAllowed && !extras.preview; onTapped: { extras.listOpen = true; extras.wake(); } }
            Accessible.role: Accessible.Button
            Accessible.name: extras.items.length + " notifications" + (extras.notesAllowed ? ". Show them" : "")
        }
        // The list, grouped newest first. Bodies follow the privacy setting; actions and replies wait for the unlock.
        Rectangle {
            id: list
            visible: extras.listOpen
            width: parent.width; height: Math.min(extras.height * .55, listColumn.implicitHeight + 28); radius: 28
            color: Theme.alpha(Theme.level(3), .72); border.width: 1; border.color: Theme.alpha("#ffffff", .10)
            Flickable {
                anchors.fill: parent; anchors.margins: 14; contentHeight: listColumn.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: listColumn
                    width: parent.width; spacing: 8
                    Item {
                        width: parent.width; height: 36
                        MText { x: 6; anchors.verticalCenter: parent.verticalCenter; text: extras.items.length + " notifications"; role: "titleS"; color: "#ffffff" }
                        MButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; icon: "expand_more"; compact: true; implicitWidth: 36; implicitHeight: 36; contained: true; tooltip: "Fold"; onClicked: extras.listOpen = false }
                    }
                    Repeater {
                        model: extras.listOpen ? extras.items.slice(0, 12) : []
                        Rectangle {
                            id: row
                            required property var modelData
                            readonly property var n: modelData.notification || ({})
                            readonly property var actions: (n.actions || []).filter(a => a.identifier !== "default").slice(0, 2)
                            readonly property bool canReply: Hub.prefs.lockReply !== false && (!!n.hasInlineReply)
                            property bool replying: false
                            width: listColumn.width; height: rowColumn.implicitHeight + 24; radius: 22; color: Theme.level(3)
                            Column {
                                id: rowColumn
                                x: 14; y: 12; width: parent.width - 28; spacing: 8
                                Row {
                                    spacing: 10; width: parent.width
                                    AppIcon { width: 32; height: 32; name: row.n.appIcon || row.n.appName || "" }
                                    Column {
                                        width: parent.width - 42
                                        MText { width: parent.width; text: (row.n.appName || "App") + " · " + Notifier.age(row.modelData.received); role: "labelS"; color: Theme.subtext; elide: Text.ElideRight }
                                        MText { width: parent.width; text: row.n.summary || "New notification"; role: "titleS"; elide: Text.ElideRight }
                                        MText {
                                            width: parent.width; role: "bodyS"; color: Theme.subtext; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight
                                            text: extras.privacy === "full" ? String(row.n.body || "").replace(/<[^>]*>/g, "") : "Unlock to see more"
                                        }
                                    }
                                }
                                Row {
                                    visible: row.actions.length > 0 || row.canReply; x: 42; spacing: 8
                                    MButton { visible: row.canReply; text: "Reply"; icon: "reply"; compact: true; implicitHeight: 32; contained: true; onClicked: { row.replying = true; replyField.forceActiveFocus(); } }
                                    Repeater {
                                        model: row.actions
                                        MButton { required property var modelData; text: modelData.text || "Action"; compact: true; implicitHeight: 32; contained: true
                                            onClicked: { const a = modelData; extras.unlockThen(() => a.invoke()); } }
                                    }
                                }
                                Row {
                                    visible: row.replying; x: 42; spacing: 8
                                    OpalField { id: replyField; width: rowColumn.width - 42 - 48; placeholderText: "Reply to " + (row.n.summary || row.n.appName || "them")
                                        onAccepted: sendButton.clicked() }
                                    MButton { id: sendButton; icon: "send"; compact: true; implicitWidth: 40; implicitHeight: 40; filled: true; tooltip: "Send after unlock"
                                        onClicked: { const msg = replyField.text.trim(), note = row.n; if (!msg) return; extras.unlockThen(() => { if (note && note.sendInlineReply) note.sendInlineReply(msg); }); } }
                                }
                            }
                        }
                    }
                    MText { x: 6; width: parent.width - 12; wrapMode: Text.Wrap; text: "Replies and actions run once you unlock."; role: "labelS"; color: Theme.alpha("#ffffff", .7) }
                }
            }
        }
        LockWidgets { visible: !extras.listOpen; width: parent.width; preview: extras.preview }
    }

    // ---- Quick Settings while locked ----
    MouseArea { anchors.fill: parent; visible: extras.quickOpen || extras.listOpen; z: 8; onClicked: { extras.quickOpen = false; extras.listOpen = false; } }
    // A pull from the top edge opens Quick Settings, like a phone.
    Item {
        anchors.left: parent.left; anchors.right: parent.right; height: 40; visible: extras.resting && !extras.preview && Hub.prefs.lockQuickSettings !== false
        DragHandler { target: null; xAxis.enabled: false; onActiveChanged: if (!active && translation.y > 50) extras.openQuick() }
    }
    Rectangle {
        id: quick
        visible: extras.quickOpen
        z: 9
        width: extras.phone ? extras.width - 16 : 412; height: quickColumn.implicitHeight + 32
        x: extras.phone ? 8 : extras.width - width - 24; y: extras.phone ? 8 : 64
        radius: 32; color: Theme.alpha(Theme.level(2), .97); border.width: 1; border.color: Theme.outline
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: quickColumn
            x: 16; y: 16; width: parent.width - 32; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                MText { text: "Quick Settings"; role: "title"; Layout.fillWidth: true; Layout.leftMargin: 4 }
                MButton { icon: "close"; compact: true; implicitWidth: 40; implicitHeight: 40; contained: true; tooltip: "Close"; onClicked: extras.quickOpen = false }
            }
            ExpressiveSlider { visible: Hub.status.brightness >= 0; Layout.fillWidth: true; implicitHeight: 48; compact: true; trackHeight: 40; icon: "sun"; iconAtHandle: true; value: Hub.status.brightness
                onMoved: Hub.command({action: "brightness", value: Math.round(value)}); Accessible.name: "Brightness" }
            ExpressiveSlider { Layout.fillWidth: true; implicitHeight: 48; compact: true; trackHeight: 40; icon: Hub.status.muted ? "mute" : "volume"; iconAtHandle: true; value: Hub.status.volume
                onMoved: Hub.volume(value); Accessible.name: "Volume" }
            QuickTileDeck { Layout.fillWidth: true; locked: true; onUnlockRequested: extras.unlockThen(null) }
            MText { Layout.fillWidth: true; Layout.leftMargin: 4; wrapMode: Text.Wrap; text: "Tiles with a lock ask you to unlock first."; role: "labelS"; color: Theme.subtext }
        }
    }

    Loader {
        anchors.fill: parent
        active: extras.ambientOn
        z: 10
        sourceComponent: AmbientClock { onWoken: extras.wake() }
    }
}
