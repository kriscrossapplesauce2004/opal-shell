import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

// Quick Access: three sizes of one thing over the game. Guide shows the glance pill, Guide again opens the sheet, and a tile grows into its own sheet.
// The sheet's Home button hands the screen back to the console home through the compositor; Resume brings the game back.
Item {
    id: qa
    // 0 the main sheet, 1 the performance sheet grown from its tile, 2 notifications.
    property int tabIndex: 0
    property real reveal: GameState.quickAccess && GameState.stage === "sheet" ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.motion(320); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
    property real glanceReveal: GameState.quickAccess && GameState.stage === "glance" ? 1 : 0
    Behavior on glanceReveal { NumberAnimation { duration: Theme.motion(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
    readonly property bool shown: GameState.quickAccess || reveal > .001 || glanceReveal > .001
    readonly property bool sheetOpen: GameState.quickAccess && GameState.stage === "sheet"
    readonly property var perf: GameState.perf
    readonly property var game: GameState.runningGame
    readonly property real sheetWidth: Math.min(Math.max(440, Math.min(560, width * .3)), width - 24)
    readonly property var fpsChoices: [0, 30, 40, 45, 60, 72, 90, 120, 144]
    property bool confirmQuit: false
    readonly property string gameId: game ? game.id : ""
    readonly property var profile: GameState.profileFor(gameId)
    readonly property var own: GameState.ownProfile(gameId)

    function step(delta) {
        tabIndex = (tabIndex + delta + 3) % 3;
        if (ControllerNav.usingController) padFocus.selectSoon();
    }
    function open(view) { tabIndex = view; if (ControllerNav.usingController) padFocus.selectSoon(); }
    function minutesText(m) { return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60) + " min"; }
    function leave() { GameState.closeQuickAccess(); }
    function resume() { const w = GameState.gameWindows[0]; leave(); if (w) Compositor.focusApp(w); }
    // Presets apply to the game in front, or to the next game when nothing runs.
    function pickPreset(id) {
        if (id === "custom") { if (gameId && !(own && own.preset === "custom")) GameState.setOwnProfile(gameId, {preset: "custom", power: Hub.status.profile || "balanced", fpsLimit: perf.fpsLimit || 0}); open(1); return; }
        if (gameId) GameState.setOwnProfile(gameId, {preset: id});
        else Hub.set("gameProfileNext", id);
    }
    // Custom changes save to the game's own profile; without a game they apply only now.
    function setCustom(key, value) {
        if (gameId && own && own.preset === "custom") { const next = Object.assign({}, own); next[key] = value; GameState.setOwnProfile(gameId, next); }
        else if (key === "power") Hub.command({action: "profile", value: value});
        else GameState.set(key, value);
    }
    onShownChanged: { if (shown) { tabIndex = 0; confirmQuit = false; GameState.loadWidgets(); } }
    onSheetOpenChanged: { Compositor.overlayInput(sheetOpen); if (sheetOpen && ControllerNav.usingController) padFocus.selectSoon(); }

    focus: GameState.quickAccess
    Keys.onPressed: e => { if (ControllerNav.fromKeyboard(e)) e.accepted = true; }
    Timer { interval: 5000; repeat: true; running: GameState.quickAccess; onTriggered: GameState.refresh() }
    Timer { id: quitReset; interval: 4000; onTriggered: qa.confirmQuit = false }
    Timer { id: tdpDelay; property int watts: 0; interval: 220; onTriggered: qa.setCustom("tdp", watts) }

    // Glance: the smallest state. The game stays in view; Guide again opens the sheet.
    Rectangle {
        id: glance
        visible: qa.glanceReveal > .001
        opacity: qa.glanceReveal
        anchors.horizontalCenter: parent.horizontalCenter
        y: 20 - 16 * (1 - qa.glanceReveal)
        width: glanceRow.implicitWidth + 16; height: 60; radius: 30
        color: Theme.alpha(Theme.level(2), .96); border.width: 1; border.color: Theme.outline
        Row {
            id: glanceRow
            x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Rectangle {
                height: 44; width: gameChip.implicitWidth + 16; radius: 22; color: Theme.level(4)
                Row {
                    id: gameChip; x: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    RoundedImage { width: 36; height: 36; radius: 18; visible: !!qa.game; source: qa.game ? qa.game.cover || qa.game.hero || "" : ""; decodeSize: Qt.size(72, 108) }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; leftPadding: qa.game ? 0 : 10
                        MText { text: GameState.gameTitle || "Quick Access"; role: "titleS" }
                        MText { text: GameState.gameActive ? qa.minutesText(GameState.sessionMinutes) : ""; visible: GameState.gameActive; role: "labelS"; color: Theme.subtext }
                    }
                }
            }
            Repeater {
                model: {
                    const list = [];
                    if (qa.perf.fpsLimit) list.push({g: "speed", t: qa.perf.fpsLimit + " FPS"});
                    (qa.perf.controllers || []).slice(0, 2).forEach(c => list.push({g: "stadia_controller", t: c.percent + "%", low: c.percent <= 15 && !c.charging}));
                    if (Hub.status.battery >= 0) list.push({g: Hub.status.charging ? "battery_charging_full" : "battery_5_bar", t: Hub.status.battery + "%"});
                    if (Hub.unread > 0) list.push({g: "notifications", t: String(Hub.unread), tonal: true});
                    return list;
                }
                Rectangle {
                    required property var modelData
                    height: 44; width: pillRow.implicitWidth + 28; radius: 22
                    color: modelData.tonal ? Theme.secondaryContainer : modelData.low ? Theme.alpha(Theme.error, .18) : Theme.alpha(Theme.level(4), .86)
                    Row { id: pillRow; anchors.centerIn: parent; spacing: 6
                        Glyph { name: modelData.g; font.pixelSize: 18; color: modelData.tonal ? Theme.onSecondaryContainer : modelData.low ? Theme.error : Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: modelData.t; role: "label"; font.weight: Font.DemiBold; font.features: {"tnum": 1}; color: modelData.tonal ? Theme.onSecondaryContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                }
            }
            Rectangle {
                height: 44; width: clock.implicitWidth + 28; radius: 22; color: Theme.primaryContainer
                MText { id: clock; anchors.centerIn: parent; text: Qt.formatDateTime(Hub.now, "HH:mm"); role: "title"; font.features: {"tnum": 1}; color: Theme.onContainer }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: GameState.stage = "sheet" }
    }
    ControllerHints {
        visible: glance.visible
        opacity: qa.glanceReveal
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: glance.bottom; anchors.topMargin: 12
        items: [{b: "Guide", t: "Quick Access"}, ...(Hub.aiEnabled ? [{b: "Hold", t: "Claude"}] : []), {b: ControllerNav.acceptLabel, t: "Screenshot"}, {b: ControllerNav.backLabel, t: "Hide"}]
    }
    // The glance takes only A and B; everything else stays with the game.
    QtObject { id: glanceClaim; property int priority: 10 }
    readonly property bool glanceActive: GameState.quickAccess && GameState.stage === "glance"
    onGlanceActiveChanged: { if (glanceActive) ControllerNav.claim(glanceClaim); else ControllerNav.release(glanceClaim); }
    Component.onDestruction: ControllerNav.release(glanceClaim)
    Connections {
        target: ControllerNav
        function onKey(name) {
            if (ControllerNav.top !== glanceClaim) return;
            if (name === "accept") { qa.leave(); Hub.command({action: "screenshot"}); }
            else if (name === "back") qa.leave();
            else if (name === "menu") GameState.stage = "sheet";
        }
    }

    // The sheet.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", .5 * qa.reveal)
        visible: qa.reveal > .001
        MouseArea { anchors.fill: parent; enabled: qa.sheetOpen; onClicked: qa.leave() }
    }
    Rectangle {
        id: sheet
        visible: qa.reveal > .001
        width: qa.sheetWidth
        y: 12; height: qa.height - 24
        x: qa.width - width - 12 + (width + 24) * (1 - qa.reveal)
        radius: Theme.shapeXl
        color: Theme.alpha(Theme.level(2), .985)
        border.width: 1; border.color: Theme.outline
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors { fill: parent; margins: 16; topMargin: 16 }
            spacing: 12
            Item {
                id: contentArea
                Layout.fillWidth: true; Layout.fillHeight: true
                Flickable {
                    id: flick
                    anchors.fill: parent
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width; contentHeight: pageLoader.height
                    ScrollBar.vertical: ScrollBar {}
                    Loader {
                        id: pageLoader
                        width: flick.width
                        active: qa.shown
                        sourceComponent: qa.tabIndex === 1 ? performancePage : qa.tabIndex === 2 ? alertsPage : mainPage
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 18; visible: flick.contentHeight > flick.height + 1
                    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Theme.alpha(Theme.level(2), .985) } }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ControllerHints {
                    items: {
                        const list = [{b: ControllerNav.acceptLabel, t: "Select"}, {b: ControllerNav.backLabel, t: qa.tabIndex === 0 ? "Close" : "Back"}, {b: "LB RB", t: "Sheets"}];
                        if (qa.tabIndex === 2) list.push({b: ControllerNav.altLabel, t: "Dismiss"});
                        else if (qa.tabIndex === 0 && padFocus.current && padFocus.current.runningTile === true) list.push({b: ControllerNav.altLabel, t: "Close app"});
                        return list;
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    ControllerFocus {
        id: padFocus
        anchors.fill: parent
        root: contentArea
        priority: 10
        active: qa.sheetOpen
        closeOnBack: false
        showHints: false
        onBack: { if (qa.tabIndex !== 0) qa.open(0); else qa.leave(); }
        onTab: delta => qa.step(delta)
    }

    // Now playing: art, session time, and the three ways out of the sheet.
    component NowPlaying: Rectangle {
        id: now
        height: 132; radius: Theme.shapeLg
        color: qa.game ? Theme.primaryContainer : Theme.level(3)
        RoundedImage { anchors.fill: parent; radius: now.radius; visible: !!qa.game; source: qa.game ? qa.game.header || qa.game.hero || qa.game.cover || "" : ""; decodeSize: Qt.size(920, 264) }
        Rectangle {
            anchors.fill: parent; radius: now.radius; visible: !!qa.game
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.alpha("#000000", .82) } GradientStop { position: 1; color: Theme.alpha("#000000", .25) } }
        }
        Image {
            id: nowLogo
            x: 16; y: 14; width: 180; height: 50; visible: status === Image.Ready
            source: qa.game ? qa.game.logo || "" : ""
            fillMode: Image.PreserveAspectFit; horizontalAlignment: Image.AlignLeft; verticalAlignment: Image.AlignVCenter
            sourceSize.width: 360; asynchronous: true; smooth: true; mipmap: true
        }
        MText {
            visible: !nowLogo.visible; x: 16; y: 16; width: parent.width - 32; maximumLineCount: 2; wrapMode: Text.Wrap
            text: GameState.gameActive ? GameState.gameTitle : "No game is running"; role: "title"; font.pixelSize: 22; color: qa.game ? "#ffffff" : Theme.text
        }
        Column {
            x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; spacing: 1
            MText { text: GameState.gameActive ? "Playing for " + qa.minutesText(GameState.sessionMinutes) : "Pick one from the console home"; role: "titleS"; color: qa.game ? "#ffffff" : Theme.text }
            MText { text: qa.game ? qa.game.source : ""; visible: !!qa.game; role: "labelS"; color: Theme.alpha("#ffffff", .75) }
        }
    }

    Component {
        id: mainPage
        ColumnLayout {
            spacing: 10
            NowPlaying { Layout.fillWidth: true }
            // The ways out: back to the game, to the home under it, or quit.
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                MButton { visible: GameState.gameActive; Layout.fillWidth: true; text: "Resume"; icon: "play_arrow"; filled: true; onClicked: qa.resume() }
                MButton { Layout.fillWidth: true; text: "Home"; icon: "home"; tonal: true; onClicked: Compositor.showHome() }
                MButton {
                    visible: GameState.gameWindows.length > 0; Layout.fillWidth: true
                    text: qa.confirmQuit ? "Press again" : "Quit"; icon: "close"; tonal: true
                    onClicked: {
                        if (!qa.confirmQuit) { qa.confirmQuit = true; quitReset.restart(); return; }
                        qa.confirmQuit = false; GameState.gameWindows.forEach(w => Compositor.closeApp(w)); qa.leave();
                    }
                }
            }
            // Live readouts.
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: {
                        const list = [];
                        (qa.perf.controllers || []).slice(0, 2).forEach(c => list.push({g: c.charging ? "charging" : "stadia_controller", t: c.percent + "%", low: c.percent <= 15 && !c.charging}));
                        if (Hub.status.battery >= 0) list.push({g: Hub.status.charging ? "battery_charging_full" : "battery_5_bar", t: Hub.status.battery + "%"});
                        if (Hub.health.hottest > 0) list.push({g: "thermostat", t: Math.round(Hub.health.hottest) + "°"});
                        if (qa.perf.tdp) list.push({g: "bolt", t: qa.perf.tdp.watts + " W"});
                        list.push({g: "schedule", t: Qt.formatDateTime(Hub.now, "HH:mm")});
                        return list;
                    }
                    Rectangle {
                        required property var modelData
                        height: 30; width: readoutRow.implicitWidth + 22; radius: 15
                        color: modelData.low ? Theme.alpha(Theme.error, .18) : Theme.alpha(Theme.level(4), .86)
                        Row { id: readoutRow; anchors.centerIn: parent; spacing: 5
                            Glyph { name: modelData.g; font.pixelSize: 16; color: modelData.low ? Theme.error : Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            MText { text: modelData.t; role: "label"; font.weight: Font.DemiBold; font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter } }
                    }
                }
            }
            // Other running apps as rows. The game itself is the card above, so it is left out here.
            // A (or a click) switches; X, a middle click or the row's × closes the window.
            MText { visible: runList.windows.length > 0; text: "Running"; role: "title"; Layout.topMargin: 4 }
            Repeater {
                id: runList
                readonly property var windows: {
                    const game = GameState.gameWindows.map(w => w.address);
                    return Hub.recentWindows.filter(w => !Hub.minimized(w) && game.indexOf(w.address) < 0).slice(0, 6);
                }
                readonly property bool previews: Hub.prefs.switcherPreviews !== false
                model: windows
                Rectangle {
                    id: runRow
                    required property var modelData
                    readonly property var app: Hub.appForWindow(modelData)
                    readonly property string name: app ? app.name : String(modelData.className || modelData.title || "App")
                    readonly property bool controllerFocusable: true
                    readonly property bool controllerLeaf: true
                    readonly property bool runningTile: true
                    property bool controllerFocused: false
                    function controllerActivate() { qa.leave(); Hub.focusWindow(modelData); }
                    function controllerAlternate() { Hub.closeWindow(modelData); }
                    readonly property bool hot: controllerFocused || hover.containsMouse
                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: 20
                    color: hot ? Theme.alpha(Theme.level(5), .95) : Theme.alpha(Theme.level(4), .86)
                    Behavior on color { ColorAnimation { duration: Theme.motion(120) } }
                    Item {
                        id: thumb
                        x: 12; y: 12; width: 88; height: 48
                        Rectangle { anchors.fill: parent; radius: 10; color: Theme.level(5) }
                        Item {
                            anchors.fill: parent
                            visible: runList.previews
                            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: thumbMask; maskThresholdMin: .5; maskSpreadAtMin: 1 }
                            Loader {
                                anchors.fill: parent
                                active: runList.previews && qa.sheetOpen
                                source: Hub.status.hypr ? "HyprWindowPreview.qml" : "WindowPreview.qml"
                                onLoaded: { if (Hub.status.hypr) item.address = Qt.binding(() => runRow.modelData.address || ""); else item.handle = Qt.binding(() => runRow.modelData.handle || null); }
                            }
                        }
                        Rectangle { id: thumbMask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
                        Image {
                            visible: !runList.previews; anchors.centerIn: parent
                            width: parent.height * .6; height: width; sourceSize: Qt.size(96, 96)
                            source: Quickshell.iconPath(runRow.app ? runRow.app.icon : "application-x-executable", true)
                        }
                    }
                    Column {
                        x: thumb.x + thumb.width + 14
                        y: (runRow.height - height) / 2
                        width: runRow.width - x - (hover.containsMouse ? 48 : 14)
                        spacing: 2
                        MText { width: parent.width; text: runRow.name; role: "titleS"; color: Theme.text }
                        MText { width: parent.width; text: runRow.modelData.title || ""; role: "labelS"; color: Theme.alpha(Theme.text, .75) }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: e => { if (e && e.button === Qt.MiddleButton) runRow.controllerAlternate(); else runRow.controllerActivate(); }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 30; height: 30; radius: 15
                            visible: hover.containsMouse
                            color: closeArea.containsMouse ? Theme.error : Theme.alpha(Theme.level(5), .9)
                            Glyph { anchors.centerIn: parent; name: "close"; font.pixelSize: 16; color: closeArea.containsMouse ? Theme.base : Theme.text }
                            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: runRow.controllerAlternate() }
                        }
                    }
                    Accessible.role: Accessible.Button; Accessible.name: name + " " + (modelData.title || "")
                    Accessible.onPressAction: controllerActivate()
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 4
                MText { text: "Performance"; role: "title" }
                MText { Layout.fillWidth: true; text: qa.gameId ? (qa.own ? "Saved for this game" : "Next-game setting") : "For the next game"; role: "label"; color: Theme.subtext }
            }
            SegmentGroup {
                Layout.fillWidth: true; segmentHeight: 46
                options: [{id: "saver", name: "Saver", icon: "eco"}, {id: "balanced", name: "Balanced", icon: "balance"}, {id: "max", name: "Max", icon: "rocket_launch"}, {id: "custom", name: "Custom", icon: "tune"}]
                current: qa.gameId ? qa.profile.preset : (Hub.prefs.gameProfileNext || "balanced")
                onPicked: id => qa.pickPreset(id)
            }
            GridLayout {
                Layout.fillWidth: true; Layout.topMargin: 2; columns: 2; columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: [
                        {id: "fps", icon: "speed", title: "Frame limit", sub: qa.perf.fpsLimit ? qa.perf.fpsLimit + " FPS" : "Off", on: !!qa.perf.fpsLimit},
                        {id: "overlay", icon: "monitoring", title: "Overlay", sub: (qa.perf.overlay || "off") === "fps" ? "FPS only" : (qa.perf.overlay || "off").charAt(0).toUpperCase() + (qa.perf.overlay || "off").slice(1), on: (qa.perf.overlay || "off") !== "off"},
                        {id: "dnd", icon: "do_not_disturb_on", title: "Do not disturb", sub: Hub.dnd ? "On" : "Off", on: Hub.dnd},
                        {id: "quiet", icon: "timer", title: "Quiet session", sub: Hub.gameSession ? Hub.gameMinutes + " min" : "No popups, no sleep", on: Hub.gameSession},
                        {id: "wifi", icon: "wifi", title: "Wi-Fi", sub: Hub.status.wifi ? Hub.status.network || "On" : "Off", on: !!Hub.status.wifi},
                        {id: "bluetooth", icon: "bluetooth", title: "Bluetooth", sub: Hub.status.bluetooth ? "On" : "Off", on: !!Hub.status.bluetooth},
                        {id: "screenshot", icon: "screenshot_monitor", title: "Screenshot", sub: "Saved to Pictures", on: false},
                        {id: "apps", icon: "select_window", title: "Switch app", sub: Compositor.apps.length + (Compositor.apps.length === 1 ? " app" : " apps"), on: false}
                    ]
                    ShadeTile {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 60; dense: true
                        icon: modelData.icon; title: modelData.title; subtitle: modelData.sub; active: modelData.on
                        onClicked: toggled()
                        onToggled: {
                            const id = modelData.id;
                            if (id === "fps") qa.open(1);
                            else if (id === "overlay") { const list = ["off", "fps", "compact", "full"]; qa.setCustom("overlay", list[(Math.max(0, list.indexOf(qa.perf.overlay || "off")) + 1) % list.length]); }
                            else if (id === "dnd") Hub.set("dnd", !Hub.dnd);
                            else if (id === "quiet") Hub.toggleGameSession();
                            else if (id === "wifi") Hub.connection("wifi", "power", {enabled: !(Hub.connectivity.wifi.powered || Hub.status.wifi)});
                            else if (id === "bluetooth") Hub.connection("bluetooth", "power", {enabled: !(Hub.connectivity.bluetooth.powered || Hub.status.bluetooth)});
                            else if (id === "screenshot") { qa.leave(); Hub.command({action: "screenshot"}); }
                            else if (id === "apps") { qa.leave(); Hub.targetScreen = Hub.chooseScreen(); Hub.page = "windows"; }
                        }
                    }
                }
            }
            QaRow {
                visible: Hub.status.brightness >= 0; Layout.fillWidth: true
                kind: "slider"; icon: "sun"; title: "Brightness"; value: Hub.status.brightness
                onSliderMoved: v => Hub.command({action: "brightness", value: Math.round(v)})
            }
            QaRow {
                Layout.fillWidth: true
                kind: "slider"; icon: Hub.status.muted ? "mute" : "volume"; title: "Volume"; value: Hub.status.muted ? 0 : Hub.status.volume
                onSliderMoved: v => Hub.volume(v)
                onAlternate: Hub.command({action: "mute"})
            }
            QaRow {
                Layout.fillWidth: true
                icon: "notifications"; title: Notifier.inbox.length ? Notifier.inbox.length + (Notifier.inbox.length === 1 ? " notification" : " notifications") : "No notifications"
                detail: Notifier.inbox.slice(0, 3).map(n => n.notification ? n.notification.appName || n.notification.summary : "").filter(t => t).join(", ")
                onActivated: qa.open(2)
            }
            // Recently played, when nothing runs.
            Repeater {
                model: GameState.gameActive ? [] : Hub.games.filter(g => g.lastPlayed > 0).slice(0, 4)
                QaRow {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: "play_arrow"; title: modelData.title; detail: modelData.source + "  ·  " + Qt.formatDate(new Date(modelData.lastPlayed * 1000), "d MMM")
                    onActivated: { qa.leave(); Hub.launchGame(modelData); }
                }
            }
            QaRow {
                Layout.fillWidth: true
                kind: "toggle"; icon: "gamepad"; title: "Guide button opens this"; detail: "Tap: glance. Twice: this sheet." + (Hub.aiEnabled ? " Hold: Claude." : "") + " Turn off if Steam uses Guide"; checked: Hub.prefs.quickAccessGuide !== false
                onActivated: Hub.set("quickAccessGuide", Hub.prefs.quickAccessGuide === false)
            }
            QaRow {
                visible: Hub.prefs.mode === "console" && !Compositor.gamescope; Layout.fillWidth: true
                icon: "desktop_windows"; title: "Switch to desktop"; detail: "Super+Ctrl+D. Apps go back to workspace 1"
                onActivated: { qa.leave(); Hub.mode("desktop"); }
            }
            QaRow {
                Layout.fillWidth: true
                icon: "settings"; title: "Opal settings"
                onActivated: { qa.leave(); Hub.targetScreen = Hub.chooseScreen(); Hub.openSettings(); }
            }
        }
    }

    // The performance sheet, grown from the Custom segment and the frame-limit tile.
    Component {
        id: performancePage
        ColumnLayout {
            spacing: 12
            // Now playing has shrunk to a row.
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 28; color: Theme.level(3)
                RoundedImage { x: 8; y: 8; width: 40; height: 40; radius: 20; visible: !!qa.game; source: qa.game ? qa.game.cover || qa.game.hero || "" : ""; decodeSize: Qt.size(80, 120) }
                Column {
                    x: qa.game ? 60 : 18; anchors.verticalCenter: parent.verticalCenter
                    MText { text: GameState.gameTitle || "Next game"; role: "titleS" }
                    MText { text: GameState.gameActive ? qa.minutesText(GameState.sessionMinutes) : "Applies when a game starts"; role: "labelS"; color: Theme.subtext }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: perfColumn.implicitHeight + 36; radius: 28; color: Theme.level(3)
                ColumnLayout {
                    id: perfColumn
                    x: 18; y: 18; width: parent.width - 36; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        MButton { icon: "arrow_back"; tooltip: "Back"; compact: true; onClicked: qa.open(0) }
                        MText { Layout.fillWidth: true; text: qa.gameId && qa.own && qa.own.preset === "custom" ? "Custom profile" : "Performance"; role: "headline"; font.pixelSize: 22 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Glyph { name: "speed"; font.pixelSize: 20; color: Theme.primary }
                        MText { Layout.fillWidth: true; text: "Frame limit"; role: "titleS" }
                        MText { text: qa.perf.fpsLimit ? String(qa.perf.fpsLimit) : "Off"; role: "title"; font.features: {"tnum": 1}; color: Theme.primary }
                    }
                    FpsSteps {
                        Layout.fillWidth: true
                        stops: qa.fpsChoices
                        current: qa.perf.fpsLimit || 0
                        onPicked: v => qa.setCustom("fpsLimit", v)
                    }
                    MText { Layout.fillWidth: true; text: Compositor.gamescope ? "gamescope limits the frame rate itself." : qa.perf.mangohud ? "MangoHud limits games it runs in. Steam games need the launch option below." : "MangoHud is not installed, so the limit has no effect yet."; role: "labelS"; color: Theme.subtext; wrapMode: Text.Wrap }
                    RowLayout {
                        Layout.fillWidth: true
                        Glyph { name: "bolt"; font.pixelSize: 20; color: Theme.primary }
                        MText { Layout.fillWidth: true; text: "Power profile"; role: "titleS" }
                    }
                    SegmentGroup {
                        Layout.fillWidth: true
                        visible: !!qa.perf.profiles && qa.perf.profiles.available
                        options: [{id: "power-saver", name: "Saver"}, {id: "balanced", name: "Balanced"}, {id: "performance", name: "Performance"}]
                        current: Hub.status.profile || "balanced"
                        onPicked: id => qa.setCustom("power", id)
                    }
                    QaRow {
                        visible: !!qa.perf.tdp; Layout.fillWidth: true
                        kind: "slider"; icon: "bolt"; title: "Power limit"; unit: " W"; pressSteps: 1
                        from: qa.perf.tdp ? qa.perf.tdp.min : 0; to: qa.perf.tdp ? qa.perf.tdp.max : 100; value: qa.perf.tdp ? qa.perf.tdp.watts : 0
                        onSliderMoved: v => { tdpDelay.watts = Math.round(v); tdpDelay.restart(); }
                    }
                    RowLayout {
                        visible: !!qa.perf.gpu; Layout.fillWidth: true
                        Glyph { name: "memory"; font.pixelSize: 20; color: Theme.primary }
                        MText { Layout.fillWidth: true; text: "GPU clock"; role: "titleS" }
                    }
                    SegmentGroup {
                        visible: !!qa.perf.gpu; Layout.fillWidth: true
                        options: [{id: "auto", name: "Auto"}, {id: "low", name: "Low"}, {id: "high", name: "High"}]
                        current: qa.perf.gpu ? qa.perf.gpu.level : "auto"
                        onPicked: id => GameState.set("gpuLevel", id)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Glyph { name: "monitoring"; font.pixelSize: 20; color: Theme.primary }
                        MText { Layout.fillWidth: true; text: "Overlay"; role: "titleS" }
                    }
                    SegmentGroup {
                        Layout.fillWidth: true
                        options: [{id: "off", name: "Off"}, {id: "fps", name: "FPS"}, {id: "compact", name: "Compact"}, {id: "full", name: "Full"}]
                        current: qa.perf.overlay || "compact"
                        onPicked: id => qa.setCustom("overlay", id)
                    }
                }
            }
            QaRow {
                visible: !!qa.gameId; Layout.fillWidth: true
                kind: "toggle"; icon: "sports_esports"; title: "Only for " + (qa.game ? qa.game.title : "this game"); detail: "Back to the next-game setting when you quit"
                checked: !!qa.own && qa.own.preset === "custom"
                onActivated: {
                    if (qa.own && qa.own.preset === "custom") GameState.setOwnProfile(qa.gameId, null);
                    else GameState.setOwnProfile(qa.gameId, {preset: "custom", power: Hub.status.profile || "balanced", fpsLimit: qa.perf.fpsLimit || 0});
                }
            }
            QaRow {
                visible: GameState.perfReady; Layout.fillWidth: true
                kind: "info"; icon: "sports_esports"; title: "GameMode"
                detail: qa.perf.gamemode && qa.perf.gamemode.active ? qa.perf.gamemode.clients + (qa.perf.gamemode.clients === 1 ? " game" : " games") + " tuned" : ""
                choice: !qa.perf.gamemode || !qa.perf.gamemode.available ? "Not installed" : qa.perf.gamemode.active ? "Active" : "Idle"
            }
            QaRow {
                visible: GameState.perfReady && !Compositor.gamescope; Layout.fillWidth: true
                icon: "content_copy"; title: "Copy Steam launch option"; detail: "Steam games read the frame limit through it"
                onActivated: Hub.command({action: "perf-copy"})
            }
        }
    }

    // Notifications from the shell inbox.
    Component {
        id: alertsPage
        ColumnLayout {
            spacing: 8
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                MButton { icon: "arrow_back"; tooltip: "Back"; compact: true; onClicked: qa.open(0) }
                MText { Layout.fillWidth: true; text: "Notifications"; role: "headline"; font.pixelSize: 22 }
            }
            QaRow {
                visible: Notifier.inbox.length > 0; Layout.fillWidth: true
                icon: "clear_all"; title: "Clear all"; detail: Notifier.inbox.length + (Notifier.inbox.length === 1 ? " notification" : " notifications")
                onActivated: Notifier.clear()
            }
            Repeater {
                model: Notifier.inbox.slice(0, 20)
                QaRow {
                    required property var modelData
                    readonly property var notice: modelData.notification
                    Layout.fillWidth: true
                    icon: "notifications"
                    title: notice ? notice.summary || notice.appName : ""
                    detail: notice ? (notice.appName ? notice.appName + "  ·  " : "") + (notice.body || "").replace(/\s+/g, " ").slice(0, 70) + "  ·  " + Notifier.age(modelData.received) : ""
                    onActivated: {
                        const action = notice ? notice.actions.find(a => a.identifier === "default") : null;
                        if (action) { action.invoke(); qa.leave(); }
                        else Notifier.dismiss(modelData);
                    }
                    onAlternate: Notifier.dismiss(modelData)
                }
            }
            Column {
                visible: Notifier.inbox.length === 0
                Layout.fillWidth: true; Layout.topMargin: 40; spacing: 10
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: Hub.dnd ? "do_not_disturb_on" : "notifications"; font.pixelSize: 44; color: Theme.muted }
                MText { anchors.horizontalCenter: parent.horizontalCenter; text: Hub.dnd ? "Nothing new. Do not disturb is on." : "Nothing new"; role: "title"; color: Theme.subtext }
            }
        }
    }
}
