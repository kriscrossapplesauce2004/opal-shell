import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the Waydroid additions: NVIDIA and adb checks, store updates and the Android quick tile.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 1600; height: 960; visible: true; color: Opal.Theme.base
        property int step: 0
        readonly property var fixtureWindows: [
            {title: "Opal — GitHub", className: "google-chrome", workspace: 2, address: "w1", at: [0, 0], size: [960, 1080]},
            {title: "~/opal", className: "kitty", workspace: 2, address: "w2", at: [960, 0], size: [960, 540]},
            {title: "Steam", className: "steam", workspace: 2, address: "w3", at: [960, 540], size: [960, 540]},
            {title: "Friends", className: "steam", workspace: 2, address: "w4", at: [1200, 600], size: [400, 400]},
            {title: "Dolphin", className: "org.kde.dolphin", workspace: 1, address: "w5", at: [0, 0], size: [1920, 1080]},
            {title: "Music", className: "dev.opal.Media", workspace: 4, address: "w6", at: [100, 80], size: [1200, 800]}]
        readonly property var stages: [
            {id: "package", title: "Install Waydroid", state: "done", progress: 1},
            {id: "binder", title: "Turn on Android support in the kernel", state: "done", progress: 1},
            {id: "init", title: "Download Android", state: "running", progress: .37, done: 412 * 1048576, total: 1100 * 1048576, speed: "8.4 MB/s", part: "system"},
            {id: "service", title: "Start the Android container", state: "waiting", progress: -1},
            {id: "arm", title: "Add ARM app support", state: "waiting", progress: -1},
            {id: "boot", title: "Start Android for the first time", state: "waiting", progress: -1},
            {id: "configure", title: "Fit Android to Opal", state: "waiting", progress: -1}]
        readonly property var checks: ({arch: "x86_64", cpu: "amd", wayland: true, binder: "ready", firewall: "", manager: "pacman", installed: false, available: true, initialized: false, serviceActive: false, free: 214 * 1073741824, need: 4 * 1073741824, pkexec: true, problems: []})
        readonly property var storeItems: [
            {package: "com.aurora.store", name: "Aurora Store", summary: "An unofficial FOSS client to Google Play", icon: "", size: 9 * 1048576, categories: ["App Store & Updater"]},
            {package: "org.fdroid.fdroid", name: "F-Droid", summary: "The app store that respects freedom and privacy", icon: "", size: 12 * 1048576, categories: ["App Store & Updater"]},
            {package: "org.mozilla.fennec_fdroid", name: "Fennec F-Droid Browser", summary: "Privacy-focused web browser", icon: "", size: 86 * 1048576, categories: ["Internet"]},
            {package: "org.schabi.newpipe", name: "NewPipe", summary: "Lightweight YouTube frontend", icon: "", size: 11 * 1048576, categories: ["Multimedia"]},
            {package: "app.organicmaps", name: "Organic Maps", summary: "Offline maps for travellers, hikers and cyclists", icon: "", size: 120 * 1048576, categories: ["Navigation"]},
            {package: "org.videolan.vlc", name: "VLC", summary: "Video and audio player that supports most formats", icon: "", size: 40 * 1048576, categories: ["Multimedia"]},
            {package: "im.vector.app", name: "Element", summary: "Secure decentralised chat and calls", icon: "", size: 60 * 1048576, categories: ["Internet"]},
            {package: "de.danoeh.antennapod", name: "AntennaPod", summary: "Easy-to-use, flexible podcast manager", icon: "", size: 8 * 1048576, categories: ["Multimedia"]},
            {package: "com.termux", name: "Termux", summary: "Terminal emulator with packages", icon: "", size: 100 * 1048576, categories: ["Development"]}]
        readonly property var cases: [
            {name: "android-intro-nvidia", view: "android", phase: "ready", av: "setup", gpu: "nvidia"},
            {name: "android-store-updates", view: "android", av: "store", installed: true, updates: true},
            {name: "android-store-updates-page", view: "android", av: "store", installed: true, updates: true, category: "Updates"},
            {name: "android-store-updates-light", view: "android", av: "store", installed: true, updates: true, light: true},
            {name: "android-tiles", view: "tiles", installed: true},
            {name: "android-tiles-setup", view: "tiles", installed: false}]
        function fixtures(late) {
            const c = cases[step];
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {hypr: true, workspace: 2, workspaces: [1, 2, 4], windows: fixtureWindows, activeAddress: "w1", urgent: ["w6"], network: "Home Wi-Fi",
                monitors: [{name: "HDMI-A-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0}]});
            Opal.Hub.compositorActive = true; Opal.Hub.compositorWindows = fixtureWindows;
            Opal.Hub.waydroid = Object.assign({}, Opal.Hub.waydroid, {installed: !!c.installed, initialized: !!c.installed, session: c.installed ? "running" : "stopped", appCount: 7, ip: "192.168.240.112"});
            Opal.Hub.waydroidSetup = {phase: c.phase || "ready", checks: Object.assign({}, checks, {adb: false, gpu: c.gpu || "ok"}, c.installed ? {installed: true, initialized: true} : {}), stages: c.phase === "failed" ? stages.map(s => s.state === "running" ? Object.assign({}, s, {state: "failed"}) : s) : stages,
                log: ["resolving dependencies...", "(1/3) installing lxc", "[Downloading] 412.00 MB/1100.00 MB    8.4 MB/s(approx.)"], error: c.phase === "failed" ? "Download Android failed: urlopen error [Errno -3] Temporary failure in name resolution" : "",
                androidId: c.phase === "done" ? "3958301749261038452" : "", image: "GAPPS", arm: true, busy: c.phase === "running"};
            if (late && (Opal.Hub.androidStore.items || []).length) return;
            // Backend replies to the page's own search carry an older request number, so they never replace the fixture.
            Opal.Hub.androidStoreRequest = 100000;
            Opal.Hub.androidStore = {loading: false, progress: -1, count: 4508, categories: [{name: "System", count: 649}, {name: "Internet", count: 603}, {name: "Multimedia", count: 468}, {name: "Navigation", count: 120}],
                items: storeItems, installed: ["org.videolan.vlc", "de.danoeh.antennapod", "com.termux"], jobs: ({"org.schabi.newpipe": {state: "download", progress: .62}}), detail: null, error: "", query: "", category: "",
                updates: c.updates ? [Object.assign({}, storeItems[5], {version: "3.6.2", installedCode: 13050407}), Object.assign({}, storeItems[7], {version: "3.7.0", installedCode: 3060000}), Object.assign({}, storeItems[8], {version: "0.119.0", installedCode: 1000})] : []};
        }
        function find(node, name) {
            if (!node) return null;
            if (node.objectName === name) return node;
            for (let i = 0; i < node.children.length; i++) { const hit = find(node.children[i], name); if (hit) return hit; }
            return null;
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            width = c.w || 1600; height = c.h || 960;
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, onboarded: true, mode: "desktop", look: "mixed", barStyle: "islands", quickTiles: ["android", "wifi", "bluetooth", "dnd", "theme", "saver"]});
            Opal.Hub.androidView = c.av || "store";
            fixtures();
            loader.sourceComponent = null;
            loader.sourceComponent = c.view === "android" ? androidView : tilesView;
            settle.restart();
        }
        Timer { id: settle; interval: 900; onTriggered: { win.fixtures(false); const c = win.cases[win.step];
            if (c.category && loader.item) { const pane = win.find(loader.item, "androidStore"); if (pane) pane.category = c.category; }
            grab.restart(); } }
        Timer { id: grab; interval: 1300; onTriggered: { win.fixtures(true); win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }); } }
        Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.run(); else restart(); } }
        Loader { id: loader; anchors.fill: parent }
        Component { id: androidView; Item {
            Opal.Surface { anchors.centerIn: parent; width: 1120; height: 780; radius: 36; kind: "panels"
                Opal.AndroidHub { anchors.fill: parent } } } }
        Component { id: tilesView; Item {
            Opal.Surface { anchors.centerIn: parent; width: 440; height: 300; radius: 28; kind: "panels"
                Opal.QuickTileDeck { anchors.fill: parent; anchors.margins: 16 } } } }
    }
}
