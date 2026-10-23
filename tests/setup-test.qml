import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the first-run setup steps, the Android installer phases, the store and the workspace switcher with fixture state.
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
            {name: "oobe-0-hello", view: "oobe", oobe: 0},
            {name: "oobe-1-network", view: "oobe", oobe: 1},
            {name: "oobe-2-look", view: "oobe", oobe: 2},
            {name: "oobe-3-device", view: "oobe", oobe: 3},
            {name: "oobe-4-apps", view: "oobe", oobe: 4},
            {name: "oobe-4-apps-android", view: "oobe", oobe: 4, android: true, phase: "ready"},
            {name: "oobe-5-claude", view: "oobe", oobe: 5},
            {name: "oobe-6-tips", view: "oobe", oobe: 6},
            {name: "oobe-7-ready", view: "oobe", oobe: 7},
            {name: "oobe-3-device-light", view: "oobe", oobe: 3, light: true},
            {name: "oobe-phone", view: "oobe", oobe: 2, w: 412, h: 915},
            {name: "android-intro", view: "android", phase: "ready", av: "setup"},
            {name: "android-running", view: "android", phase: "running", av: "setup"},
            {name: "android-failed", view: "android", phase: "failed", av: "setup"},
            {name: "android-done", view: "android", phase: "done", av: "setup"},
            {name: "android-manage", view: "android", phase: "installed", av: "setup", installed: true},
            {name: "android-store", view: "android", av: "store", installed: true},
            {name: "android-store-detail", view: "android", av: "store", installed: true, detail: true},
            {name: "android-store-light", view: "android", av: "store", installed: true, light: true},
            {name: "pill-collapsed", view: "pill", expand: false},
            {name: "pill-expanded", view: "pill", expand: true},
            {name: "pill-light", view: "pill", expand: false, light: true},
            {name: "shelf-pill", view: "shelf"},
            {name: "shelf-pill-light", view: "shelf", light: true}]
        function fixtures(late) {
            const c = cases[step];
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {hypr: true, workspace: 2, workspaces: [1, 2, 4], windows: fixtureWindows, activeAddress: "w1", urgent: ["w6"], network: "Home Wi-Fi",
                monitors: [{name: "HDMI-A-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0}]});
            Opal.Hub.compositorActive = true; Opal.Hub.compositorWindows = fixtureWindows;
            Opal.Hub.waydroid = Object.assign({}, Opal.Hub.waydroid, {installed: !!c.installed, initialized: !!c.installed, session: c.installed ? "running" : "stopped", appCount: 7, ip: "192.168.240.112"});
            Opal.Hub.waydroidSetup = {phase: c.phase || "ready", checks: Object.assign({}, checks, c.installed ? {installed: true, initialized: true} : {}), stages: c.phase === "failed" ? stages.map(s => s.state === "running" ? Object.assign({}, s, {state: "failed"}) : s) : stages,
                log: ["resolving dependencies...", "(1/3) installing lxc", "[Downloading] 412.00 MB/1100.00 MB    8.4 MB/s(approx.)"], error: c.phase === "failed" ? "Download Android failed: urlopen error [Errno -3] Temporary failure in name resolution" : "",
                androidId: c.phase === "done" ? "3958301749261038452" : "", image: "GAPPS", arm: true, busy: c.phase === "running"};
            if (late && (Opal.Hub.androidStore.items || []).length) return;
            // Backend replies to the page's own search carry an older request number, so they never replace the fixture.
            Opal.Hub.androidStoreRequest = 100000;
            Opal.Hub.androidStore = {loading: false, progress: -1, count: 4508, categories: [{name: "System", count: 649}, {name: "Internet", count: 603}, {name: "Multimedia", count: 468}, {name: "Navigation", count: 120}],
                items: storeItems, installed: ["org.videolan.vlc"], jobs: ({"org.schabi.newpipe": {state: "download", progress: .62}}), detail: null, error: "", query: "", category: ""};
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
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, onboarded: true, mode: "desktop", look: "mixed", barStyle: "islands"});
            Opal.Hub.androidView = c.av || "store";
            fixtures();
            loader.sourceComponent = null;
            loader.sourceComponent = c.view === "oobe" ? oobeView : c.view === "android" ? androidView : c.view === "shelf" ? shelfView : pillView;
            settle.restart();
        }
        Timer { id: settle; interval: 900; onTriggered: { win.fixtures(false); const c = win.cases[win.step]; if (c.view === "oobe" && loader.item) { loader.item.step = c.oobe; loader.item.androidOpen = !!c.android; }
            if (c.view === "pill" && loader.item) loader.item.pillExpand = !!c.expand;
            if (c.detail && loader.item) { const pane = win.find(loader.item, "androidStore"); if (pane) pane.selected = Object.assign({}, win.storeItems[3], {version: "0.27.2", license: "GPL-3.0-or-later", description: "NewPipe does not use any Google framework libraries, or the YouTube API. It only parses the website to gain the information it needs.", screenshots: []}); }
            grab.restart(); } }
        Timer { id: grab; interval: 1300; onTriggered: { win.fixtures(true); win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }); } }
        Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.run(); else restart(); } }
        Loader { id: loader; anchors.fill: parent }
        Component { id: oobeView; Opal.OobeContent {} }
        Component { id: androidView; Item {
            Opal.Surface { anchors.centerIn: parent; width: 1120; height: 780; radius: 36; kind: "panels"
                Opal.AndroidHub { anchors.fill: parent } } } }
        Component { id: shelfView; Item {
            Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/Ocean.png"; fillMode: Image.PreserveAspectCrop }
            Column { x: 60; y: 60; spacing: 24
                Opal.WorkspaceShelfPill { height: 44; output: null }
                Opal.WorkspaceShelfPill { height: 44; output: null; Component.onCompleted: { seen = 1; flashing = true; } }
                Opal.WorkspaceShelfPill { height: 44; output: null; color: Opal.Theme.primaryContainer }
                Opal.WorkspaceShelfPill { height: 40; output: null; framed: false } } } }
        Component { id: pillView; Item {
            property bool pillExpand: false
            Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/Ocean.png"; fillMode: Image.PreserveAspectCrop }
            Opal.WorkspacePill { anchors.horizontalCenter: parent.horizontalCenter; y: 20; shown: 2; out: true; expand: parent.pillExpand; screenObj: null } } }
    }
}
