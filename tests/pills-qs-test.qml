import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the contextual pills, the desktop Quick Settings, the notification and clock cards and the displays sheet with fixed data.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property string art: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/Fixture-1.png"
    function note(app, icon, summary, body, ago) {
        return {notification: {appName: app, appIcon: icon, summary: summary, body: body, transient: false, actions: [], urgency: 1, id: Math.floor(Math.random() * 1e6), dismiss: () => {}, expire: () => {}},
                received: Date.now() - ago * 60000, read: false, popup: false};
    }
    Window {
        id: fixture
        width: 1440; height: 300; visible: true; color: Opal.Theme.base
        property int step: 0
        property var cases: [
            {name: "pills-shelf", view: shelf, w: 1440, h: 160},
            {name: "pills-shelf-new", view: shelf, w: 1440, h: 160, fresh: true},
            {name: "pills-shelf-folded", view: shelf, w: 1440, h: 160, prefs: {pillsCollapsed: true}},
            {name: "pills-shelf-calm", view: shelf, w: 1440, h: 160, prefs: {pillLevel: "calm"}},
            {name: "pills-shelf-now", view: shelf, w: 1440, h: 160, now: true},
            {name: "qs-desktop", view: qs, w: 412, h: 720},
            {name: "qs-desktop-edit", view: qs, w: 412, h: 900, edit: true},
            {name: "qs-desktop-sizes", view: qs, w: 412, h: 720, prefs: {quickTiles: ["wifi", "bluetooth", "media", "dnd", "theme", "focus", "mic", "keyboard", "devices"], quickTileSizes: {focus: "big"}}},
            {name: "notification-card", view: notes, w: 420, h: 620},
            {name: "clock-card", view: clock, w: 400, h: 820},
            {name: "displays-sheet", view: displays, w: 412, h: 620},
            {name: "spaces-card", view: spaces, w: 1040, h: 420, spaces: true},
            {name: "spaces-edit", view: spaces, w: 460, h: 640, spaces: true, edit: 2},
            {name: "spaces-shelf", view: shelf, w: 1440, h: 160, spaces: true},
            {name: "lock-desktop", view: lock, w: 1280, h: 800},
            {name: "lock-thin", view: lock, w: 1280, h: 800, prefs: {lockFace: "thin", lockColor: "white"}},
            {name: "lock-notifications", view: lock, w: 1280, h: 800, lockList: true, prefs: {lockNotifications: "full"}},
            {name: "lock-quick", view: lock, w: 1280, h: 800, lockQuick: true},
            {name: "lock-phone", view: lock, w: 412, h: 915},
            {name: "settings-lock", view: settings, w: 1100, h: 900}
        ]
        Loader { id: loader; anchors.fill: parent }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            width = c.w; height = c.h;
            const now = Date.now();
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {palette: 1, barStyle: "islands", pillLevel: "full", pillsCollapsed: false, quickTiles: ["wifi", "bluetooth", "dnd", "awake", "theme", "saver", "mic", "keyboard"], quickTileSizes: {}, lockFace: "stacked", lockColor: "primary", lockNotifications: "title"}, c.prefs || {});
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {battery: 73, charging: false, wifi: true, network: "Oasis WLAN", bluetooth: true, brightness: 58, volume: 32, hypr: true, workspace: 2, workspaces: [1, 2, 3], profile: "balanced"});
            Opal.Activities.fixture = [
                {id: "focus", kind: "focus", icon: "timer", title: "Pasta timer", short: "4:12", subtitle: "Ends at 15:04", progress: .7, priority: 60, since: 2, until: 0, controls: []},
                {id: "n:9", nid: 9, kind: "transfer", icon: "download", title: "DELTARUNE_OST.zip", short: "62%", subtitle: "Firefox", progress: .62, priority: 55, since: 1, until: 0, controls: []},
                {id: "media", kind: "media", icon: "music", art: root.art, title: "ASGORE", short: "ASGORE", subtitle: "Toby Fox", progress: -1, priority: 50, since: 3, until: 0, playing: true, controls: []}
            ];
            Opal.Notifier.entries = [root.note("Discord", "discord", "Sam", "are you on tonight?", 1), root.note("Steam", "steam", "DELTARUNE update ready", "Chapter 5 · 1.2 GB", 6), root.note("Thunderbird", "thunderbird", "Your order has shipped", "Arrives Friday", 22)];
            Opal.HomeData.events = [
                {title: "Standup", start: c.now ? now - 60000 : now + 8 * 60000, end: now + 23 * 60000, allDay: false, join: "https://meet.google.com/abc", location: ""},
                {title: "Pick up prints", start: now + 3 * 3600000, end: now + 3.5 * 3600000, allDay: false, join: "", location: "Ender-3 queue"}
            ];
            Opal.HomeData.clocks = [{zone: "Asia/Tokyo", label: "Tokyo", offset: 540}, {zone: "America/New_York", label: "New York", offset: -240}];
            Opal.Hub.ddc = {available: true, items: [{bus: 4, connector: "DP-1", model: "DELL U2723QE", ddc: true, value: 72, max: 100}, {bus: 5, connector: "HDMI-A-1", model: "SAMSUNG", ddc: false, value: -1, max: 100}]};
            Opal.Hub.focusRunning = true; Opal.Hub.focusSeconds = 4 * 60 + 12;
            if (c.spaces) {
                Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {spaces: {"1": {name: "Opal", icon: "palette", color: "#c7a7ff"}, "3": {name: "Games", icon: "sports_esports", color: "#8bd5a0"}},
                    savedSpaces: [{id: "quantlab", name: "Quantlab", icon: "science", color: "#ffb38a", apps: [{app: "code", cls: "code"}, {app: "firefox", cls: "firefox"}]}, {id: "printing", name: "Printing", icon: "print", color: "#9ecbff", apps: [{app: "firefox", cls: "firefox"}]}]});
                Opal.Hub.apps = [{id: "firefox", name: "Firefox", icon: "firefox", keywords: [], categories: [], execute: () => {}}, {id: "code", name: "Code", icon: "code", keywords: [], categories: [], execute: () => {}}, {id: "steam", name: "Steam", icon: "steam", keywords: [], categories: [], execute: () => {}}];
                Opal.Hub.compositorActive = true;
                Opal.Hub.compositorWindows = [{title: "Opal", className: "code", address: "a1", workspace: 1, at: [0, 0], size: [960, 1080]}, {title: "Docs", className: "firefox", address: "a2", workspace: 1, at: [960, 0], size: [960, 1080]},
                    {title: "Mozilla Firefox", className: "firefox", address: "a3", workspace: 2, at: [0, 0], size: [1920, 1080]}, {title: "Steam", className: "steam", address: "a4", workspace: 3, at: [0, 0], size: [1920, 1080]}];
                Opal.Hub.status = Object.assign({}, Opal.Hub.status, {workspace: c.name === "spaces-shelf" ? 1 : 2, workspaces: [1, 2, 3]});
            }
            loader.sourceComponent = null; loader.sourceComponent = c.view;
            if (c.fresh) Qt.callLater(() => { Opal.Notifier.announced = Opal.Notifier.entries[0]; Opal.Notifier.announcedAt = Date.now(); });
            grab.restart();
        }
        Timer { id: grab; interval: 1600; onTriggered: fixture.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + fixture.cases[fixture.step].name + ".png"); fixture.step++; fixture.run(); }) }
        Component.onCompleted: Qt.callLater(run)
    }
    Component { id: shelf; Item { Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/Ocean.png"; fillMode: Image.PreserveAspectCrop }
        Opal.DesktopShelf { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 64 } } }
    component Card: Rectangle { anchors.fill: parent; color: Opal.Theme.level(2); radius: 32 }
    Component { id: qs; Card { Opal.QuickSettings { id: sheet; anchors.fill: parent; Component.onCompleted: sheet.editing = !!fixture.cases[fixture.step].edit } } }
    Component { id: notes; Card { Opal.NotificationSheet { anchors.fill: parent } } }
    Component { id: clock; Card { Opal.ClockCard { anchors.fill: parent } } }
    Component { id: spaces; Item { Opal.WorkspaceCard { id: wcard; x: 10; y: 10; width: implicitWidth; height: implicitHeight; Component.onCompleted: if (fixture.cases[fixture.step].edit) wcard.editing = fixture.cases[fixture.step].edit } } }
    Component { id: lock; Opal.LockScene { id: scene; mode: "lock"; userName: "Melissa"
        Component.onCompleted: { Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {wallpaperPath: "file://" + Quickshell.env("HOME") + "/Ocean.png", wallpaperDim: 0});
            const c = fixture.cases[fixture.step]; if (c.lockList) Qt.callLater(scene.openNotifications); if (c.lockQuick) Qt.callLater(scene.openQuick); } } }
    Component { id: settings; Rectangle { color: Opal.Theme.base; Opal.Settings { anchors.fill: parent; Component.onCompleted: Opal.Hub.settingsSection = "lock" } } }
    Component { id: displays; Card { Opal.DisplaysPanel { anchors.fill: parent; anchors.margins: 16 } } }
}
