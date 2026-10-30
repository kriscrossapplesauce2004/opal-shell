import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Frame Lab v0: scripts open, hold, fling and close for hot surfaces and prints frame gaps. Run: python3 tools/frame-lab.py
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property int cycles: Math.max(1, Number(Quickshell.env("OPAL_FRAMELAB_CYCLES")) || 5)
    // Remove a surface from this list when it does not load offscreen.
    readonly property var scenarios: [
        {name: "quicksettings", surface: "qs", w: 412, h: 820, mode: "phone", list: false},
        {name: "start-menu", surface: "start", w: 600, h: 680, mode: "desktop", list: true},
        {name: "launcher", surface: "launcher", w: 1120, h: 760, mode: "desktop", list: true},
        {name: "notifications", surface: "notes", w: 420, h: 620, mode: "phone", list: false}
    ]
    readonly property var timing: ({open: 400, hold: 600, fling: 700, close: 300, idle: 100})
    readonly property string clock: typeof performance !== "undefined" && performance.now ? "performance.now" : "Date.now"
    property int scenario: 0
    property int cycle: 0
    property int stepIndex: 0
    property var steps: []
    property real stepEnd: 0
    property real flingStart: 0
    property var flick: null
    property bool sawFlick: false
    property real lastSwap: -1
    property var intervals: []
    property bool capturing: false

    function now() { return typeof performance !== "undefined" && performance.now ? performance.now() : Date.now(); }

    // Find the first scrollable child that holds more content than its view.
    function findFlick(item) {
        const queue = [item];
        for (let guard = 0; queue.length && guard < 5000; guard++) {
            const it = queue.shift();
            if (!it) continue;
            if (typeof it.contentY === "number" && typeof it.contentHeight === "number" && it.contentHeight > it.height + 1) return it;
            for (const child of (it.children || [])) queue.push(child);
        }
        return null;
    }

    function viewFor(surface) {
        if (surface === "qs") return qsView;
        if (surface === "start") return startView;
        if (surface === "launcher") return launcherView;
        return notesView;
    }

    function begin(index) {
        const s = scenarios[index];
        win.width = s.w; win.height = s.h;
        const favorites = Opal.Hub.apps.slice(0, 12).map(a => a.id);
        Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {mode: s.mode, palette: 1, light: false, pinsConfigured: true, favorites: favorites, recent: favorites.slice(0, 3)});
        if (s.surface === "launcher") Opal.Hub.page = "launcher";
        steps = ["open", "hold"].concat(s.list ? ["fling"] : []).concat(["close", "idle"]);
        cycle = 0; stepIndex = 0; sawFlick = false; intervals = []; lastSwap = -1;
        capturing = true; driver.running = true;
        enter();
    }

    function enter() {
        const kind = steps[stepIndex];
        stepEnd = now() + timing[kind];
        if (kind === "open") { loader.sourceComponent = null; loader.sourceComponent = viewFor(scenarios[scenario].surface); }
        if (kind === "close") loader.sourceComponent = null;
        if (kind === "fling") { flick = findFlick(loader.item); sawFlick = sawFlick || flick !== null; flingStart = now(); }
    }

    // Each frame: move the fling if one runs, then advance the script by time.
    function tick() {
        if (!capturing) return;
        const t = now();
        if (steps[stepIndex] === "fling" && flick) {
            const p = Math.min(1, (t - flingStart) / timing.fling);
            const span = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = span * (1 - Math.pow(1 - p, 3));
        }
        if (t < stepEnd) return;
        stepIndex++;
        if (stepIndex >= steps.length) {
            stepIndex = 0; cycle++;
            if (cycle >= cycles) { finish(); return; }
        }
        enter();
    }

    function finish() {
        capturing = false; driver.running = false;
        const s = scenarios[scenario];
        console.log("FRAMELAB " + JSON.stringify({scenario: s.name, surface: s.surface, cycles: cycles, clock: clock, flickable: sawFlick,
            intervals_ms: intervals.map(v => Math.round(v * 1000) / 1000)}));
        scenario++;
        if (scenario >= scenarios.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
        Qt.callLater(() => begin(scenario));
    }

    function start() {
        Opal.Notifier.entries = Array.from({length: 30}, (_, i) => ({notification: {appName: "Fixture", appIcon: "dialog-information", summary: "Fixture note " + i, body: "Generated body " + i, transient: false, actions: [], urgency: 1, id: i + 1, dismiss: () => {}, expire: () => {}},
            received: Date.now() - i * 60000, read: false, popup: false}));
        Opal.Hub.apps = Array.from({length: 60}, (_, i) => ({id: "fixture-" + i, name: "Fixture app " + i, genericName: "Fixture", icon: "application-x-executable", keywords: ["fixture"], categories: ["Utility"], execute: () => {}}));
        Opal.Hub.status = Object.assign({}, Opal.Hub.status, {battery: 73, charging: false, wifi: true, network: "Fixture WLAN", bluetooth: true, brightness: 58, volume: 32, hypr: true, workspace: 2, workspaces: [1, 2, 3], profile: "balanced"});
        begin(0);
    }

    // Frame gaps come from frameSwapped. A new scenario starts without a gap.
    Connections {
        target: win
        function onFrameSwapped() {
            const t = root.now();
            if (root.capturing && root.lastSwap >= 0) root.intervals.push(t - root.lastSwap);
            root.lastSwap = t;
        }
    }

    // Keeps a frame pending every tick, so idle time still shows as frames.
    FrameAnimation { id: driver; running: false; onTriggered: root.tick() }

    Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) root.start(); else restart(); } }

    Window {
        id: win
        width: 412; height: 820; visible: true; color: Opal.Theme.base
        Loader { id: loader; anchors.fill: parent }
    }

    Component { id: qsView; Rectangle { anchors.fill: parent; color: Opal.Theme.level(2); radius: 32; Opal.QuickSettings { anchors.fill: parent } } }
    Component { id: startView; Item { anchors.fill: parent
        Opal.Surface { x: 18; y: parent.height - height - 72; width: Math.min(760, parent.width - 36); height: Math.min(620, parent.height - 88); radius: 28
            Opal.StartMenu { anchors.fill: parent } } } }
    Component { id: launcherView; Opal.Launcher { anchors.fill: parent } }
    Component { id: notesView; Rectangle { anchors.fill: parent; color: Opal.Theme.level(2); radius: 32; Opal.NotificationSheet { anchors.fill: parent } } }
}
