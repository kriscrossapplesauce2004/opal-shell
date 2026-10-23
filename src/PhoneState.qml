pragma Singleton
import QtQuick
import Quickshell

// Shared phone and tablet state: gestures, split view, pen, torch, battery and task-aware data.
Scope {
    id: s
    // Backend data.
    property var activity: ({files: [], games: []})
    property var torch: ({available: false, on: false})
    property var battery: ({available: false})
    property var batteryHistory: []
    // A wide phone output is a tablet when its shorter side is at least 600 logical pixels.
    function isTablet(screen) { return !!screen && Math.min(screen.width, screen.height) >= 600 && Hub.layoutFor(screen.width, screen.height, screen.name) === "phone"; }
    function phoneScreens() { return Quickshell.screens.filter(sc => Hub.layoutFor(sc.width, sc.height, sc.name) === "phone"); }
    // Icon grid metrics shared by home, drawer and folders, so every icon grid has the same rhythm.
    function columnsFor(width, wide) {
        const forced = Hub.prefs.phoneRows;
        if (forced) return Math.max(4, Math.min(forced, Math.floor((width - 8) / 64)));
        return wide ? 6 : width >= 400 ? 5 : 4;
    }
    function iconSize(cellWidth) { return Math.round(Math.max(48, Math.min(64, cellWidth - 22))); }
    function cellHeight(cellWidth) { return iconSize(cellWidth) + 38; }
    // A slim phone bar: three keys in 48 px, or a 28 px gesture strip.
    readonly property int navHeight: Hub.prefs.phoneButtons ? 48 : 28
    // The tablet workspace card: open state, its screen, and the left edge of the chip it grows from.
    property bool spacesOpen: false
    property var spacesScreen: null
    property real spacesX: 12
    // An app carried from the tablet launcher onto the home: {app, x, y} in screen coordinates, or null.
    property var homeDrag: null
    signal homeDrop(string appId, real x, real y)
    readonly property int barHeight: 48
    // A tablet gets a slimmer status bar than a phone.
    function statusFor(screen) { return isTablet(screen) ? 34 : barHeight; }

    // Pen awareness: after a stylus touch, targets grow and nothing depends on hover.
    property bool pen: false
    readonly property int hit: pen ? 56 : 48
    function penSeen() { pen = true; penReset.restart(); }
    function touchSeen() { if (pen) penReset.restart(); }
    Timer { id: penReset; interval: 120000; onTriggered: s.pen = false }

    // Recent windows, newest first, so back and app switching follow what the user did.
    property var mru: []
    readonly property string activeAddress: (Hub.status && Hub.status.activeAddress) || ""
    onActiveAddressChanged: if (activeAddress !== "") mru = [activeAddress].concat(mru.filter(a => a !== activeAddress)).slice(0, 12)
    function windowByAddress(address) { return Hub.windows.find(w => w.address === address) || null; }
    function activeWindow() { return Hub.windows.find(w => Hub.active(w)) || null; }
    function previousWindow() {
        for (let i = 0; i < mru.length; i += 1) {
            const w = windowByAddress(mru[i]);
            if (w && !Hub.active(w)) return w;
        }
        return Hub.windows.find(w => !Hub.active(w)) || null;
    }
    function neighbour(step) {
        const list = Hub.windows;
        if (list.length < 2) return null;
        const index = Math.max(0, list.findIndex(w => Hub.active(w)));
        return list[(index + step + list.length) % list.length];
    }
    readonly property bool appInFront: Hub.windows.some(w => Hub.active(w))
    readonly property bool atHome: Hub.page === "launcher" ? Hub.mobileTab === "home" : Hub.page === "" && !(Hub.status.hypr && appInFront)

    // Finger-tracking gestures. The navigation pill and the edge zones drive these.
    property string phase: ""
    property string outcome: ""
    property real progress: 0
    property real dx: 0
    property real dy: 0
    property int edge: 0
    property var gestureScreen: null
    property real velocityX: 0
    property real velocityY: 0
    signal drawerReleased(bool open)
    function begin(screen) { holdTimer.stop(); outcome = ""; phase = ""; progress = 0; dx = 0; dy = 0; edge = 0; gestureScreen = screen; }
    function height_() { return gestureScreen ? gestureScreen.height : 800; }
    function width_() { return gestureScreen ? gestureScreen.width : 400; }
    // Called while the finger moves. Offsets are from the touch-down point; velocities are in pixels per second.
    function move(offsetX, offsetY, vx, vy) {
        dx = offsetX; dy = offsetY; velocityX = vx; velocityY = vy;
        if (phase === "" && (Math.abs(offsetX) > 12 || Math.abs(offsetY) > 12)) {
            if (Math.abs(offsetY) >= Math.abs(offsetX)) {
                if (offsetY < 0) phase = atHome ? "drawer" : "home";
            } else if (!atHome && Hub.windows.length > 1) phase = "switch";
        }
        if (phase === "drawer") progress = Math.min(1, Math.max(0, -offsetY / (height_() * .55)));
        else if (phase === "home" || phase === "recents") {
            progress = Math.min(1, Math.max(0, -offsetY / (height_() * .5)));
            // Slow and high: hold to reach recents. Moving again returns to the home gesture.
            if (phase === "home" && progress > .2 && Math.abs(vy) < 160) holdTimer.start();
            else if (phase === "home" || Math.abs(vy) > 320) { holdTimer.stop(); if (phase === "recents") phase = "home"; }
        }
    }
    Timer { id: holdTimer; interval: 340; onTriggered: if (s.phase === "home") s.phase = "recents" }
    // Recents carousel. It lives in the gesture surface, so a swipe-up hands its moving card to the carousel in the same frame.
    property bool recentsOpen: false
    property var recentsScreen: null
    // The pose the centre card starts from: {k: scale, x, y: centre offsets, backdrop: opacity}, or null to fade in.
    property var recentsFrom: null
    function recentsInsets(screen) { return {top: statusFor(screen), bottom: isTablet(screen) ? navFor(screen) + 8 : navHeight}; }
    // The centre card slot: a screen-shaped card, an app chip above it and a toolbar below it.
    function recentsSlot(screen) {
        const w = screen ? screen.width : width_(), h = screen ? screen.height : height_(), inset = recentsInsets(screen);
        const tablet = isTablet(screen);
        const room = h - inset.top - inset.bottom - (tablet ? 168 : 176);
        const k = Math.max(.3, Math.min(tablet ? .6 : .7, room / h));
        const top = inset.top + (tablet ? 66 : 70);
        return {k: k, w: w * k, h: h * k, cx: w / 2, cy: top + h * k / 2, gap: tablet ? 36 : 22, offset: top + h * k / 2 - h / 2};
    }
    // The moving card's pose for the home and recents swipe. It depends only on the finger, so it never jumps when the phase changes.
    // The card's bottom edge stays under the finger while it shrinks towards the recents slot, then a little past it.
    function cardPose() {
        const h = height_(), slot = recentsSlot(gestureScreen), p = progress;
        const t = Math.min(1, p / .6), eased = 1 - (1 - t) * (1 - t);
        let k = 1 - (1 - slot.k) * eased;
        if (p > .6) k *= 1 - .3 * Math.min(1, (p - .6) / .4);
        return {k: k, x: dx * .35, y: h * (1 - k) / 2 + dy * .95, backdrop: Math.min(1, .35 + p * 1.2)};
    }
    function showRecents(screen, from) {
        recentsScreen = screen || gestureScreen || Hub.targetScreen || phoneScreens()[0] || null;
        recentsFrom = from || null;
        if (Hub.page !== "") Hub.close();
        recentsOpen = true;
    }
    function closeRecents() { recentsOpen = false; recentsFrom = null; }
    // Called when the finger lifts. Returns after it starts the action; the overlay then plays the settle.
    function end() {
        holdTimer.stop();
        const flingUp = velocityY < -700;
        if (phase === "drawer") {
            const open = progress > .28 || velocityY < -600;
            drawerReleased(open);
            phase = ""; progress = 0;
            return;
        }
        // Recents take the card where it is; the gesture ends in the same frame.
        if (phase === "recents") { const pose = cardPose(); showRecents(gestureScreen, pose); finish(); return; }
        else if (phase === "home") {
            if (progress > .28 || flingUp) { outcome = "home"; goHome(); } else outcome = "cancel";
        } else if (phase === "switch") {
            const w = width_();
            if (Math.abs(dx) > w * .3 || Math.abs(velocityX) > 650) { outcome = "switch"; switchApp(dx > 0 ? -1 : 1); } else outcome = "cancel";
        } else { phase = ""; return; }
        if (Theme.motion(1) === 0) finish();
    }
    function finish() { phase = ""; outcome = ""; progress = 0; dx = 0; dy = 0; edge = 0; }
    function cancel() { holdTimer.stop(); if (phase === "drawer") drawerReleased(false); outcome = "cancel"; if (Theme.motion(1) === 0 || phase === "") finish(); }

    // Edge back swipe from the left or right edge.
    // Edge gestures. Each edge has an upper and a lower half, and each half has a swipe and a swipe-and-hold, all assignable in Settings.
    readonly property var gestureActions: [
        {id: "back", label: "Back", icon: "arrow_back"}, {id: "home", label: "Home", icon: "home"}, {id: "recents", label: "Recent apps", icon: "view_carousel"},
        {id: "previous", label: "Last app", icon: "swap_horiz"}, {id: "drawer", label: "App drawer", icon: "apps"}, {id: "search", label: "Search", icon: "search"},
        {id: "notifications", label: "Notifications", icon: "notifications"}, {id: "controls", label: "Quick settings", icon: "tune"},
        {id: "assistant", label: "Assistant", icon: "auto_awesome"}, {id: "screenshot", label: "Screenshot", icon: "screenshot_monitor"},
        {id: "torch", label: "Flashlight", icon: "flashlight_on"}, {id: "keyboard", label: "Keyboard", icon: "keyboard"},
        {id: "lock", label: "Lock", icon: "lock"}, {id: "none", label: "Nothing", icon: "block"}]
    readonly property var edgeZones: ["leftUpper", "rightUpper", "leftLower", "rightLower"]
    function gestureAction(zone, hold) {
        const g = Hub.prefs.phoneGestures || {};
        const value = g[zone + (hold ? "Hold" : "")];
        return gestureActions.some(a => a.id === value) ? value : hold ? "none" : "back";
    }
    function actionInfo(id) { return gestureActions.find(a => a.id === id) || gestureActions[0]; }
    property real edgeY: .5
    property bool edgeHeld: false
    readonly property string edgeZone: (edge < 0 ? "left" : "right") + (edgeY < .5 ? "Upper" : "Lower")
    // What letting go would do right now.
    readonly property string pendingAction: phase !== "back" ? "" : edgeHeld && gestureAction(edgeZone, true) !== "none" ? gestureAction(edgeZone, true) : gestureAction(edgeZone, false)
    Timer { id: edgeHoldTimer; interval: 420; onTriggered: if (s.phase === "back" && s.progress >= 1) s.edgeHeld = true }
    function beginEdge(screen, side, y) { begin(screen); phase = "back"; edge = side; edgeHeld = false; edgeY = y === undefined ? .5 : y; dy = edgeY * height_(); }
    function moveEdge(offset, y) {
        dx = offset; progress = Math.min(1, Math.max(0, Math.abs(offset) / 96));
        if (y !== undefined) dy = y;
        if (progress < 1) { edgeHoldTimer.stop(); edgeHeld = false; }
        else if (!edgeHeld && !edgeHoldTimer.running && gestureAction(edgeZone, true) !== "none") edgeHoldTimer.start();
    }
    function endEdge() {
        edgeHoldTimer.stop();
        if (progress >= 1) { const action = pendingAction; outcome = "back"; runGesture(action); } else outcome = "cancel";
        edgeHeld = false;
        if (Theme.motion(1) === 0) finish();
    }
    function runGesture(id) {
        if (gestureScreen) Hub.targetScreen = gestureScreen;
        if (id === "back") back();
        else if (id === "home") goHome();
        else if (id === "recents") openRecents();
        else if (id === "previous") { const w = previousWindow(); if (w) Hub.focusWindow(w); }
        else if (id === "drawer") { Hub.mobileTab = "apps"; Hub.page = "launcher"; }
        else if (id === "search") Hub.openSearch();
        else if (id === "notifications") Hub.page = "notifications";
        else if (id === "controls") Hub.page = "controls";
        else if (id === "assistant") Hub.openAssistant("");
        else if (id === "screenshot") Hub.screenShot();
        else if (id === "torch") setTorch(!torch.on);
        else if (id === "keyboard") Hub.systemOsk("toggle");
        else if (id === "lock") Hub.lock();
    }

    // Actions. They only change shell state or ask the compositor adapter. They never send keys to apps.
    function goHome() {
        closeRecents();
        Hub.query = ""; Hub.mobileTab = "home"; Hub.close();
        if (Hub.status.hypr) Hub.command({action: "phone-home"});
    }
    function openRecents() { showRecents(gestureScreen, null); }
    function switchApp(step) {
        const w = step < 0 ? previousWindow() : neighbour(step);
        if (w) Hub.focusWindow(w);
    }
    // Back closes one shell layer first, then delegates to Smart Back (Waydroid KEYCODE_BACK -> transient Escape -> browser Alt+Left -> MRU app).
    function back() {
        if (Hub.captureOpen) Hub.captureOpen = false;
        else if (recentsOpen) closeRecents();
        else if (spacesOpen) spacesOpen = false;
        else if (Hub.audioOpen) Hub.closeAudio();
        else if (Hub.systemOskVisible) Hub.systemOsk("hide");
        else if (Hub.page === "settings" && Hub.settingsSection !== "") Hub.settingsSection = "";
        else if (Hub.controlDetail !== "" && (Hub.page === "controls" || Hub.page === "notifications")) Hub.controlDetail = "";
        else if (Hub.page === "launcher" && Hub.mobileTab !== "home") { Hub.mobileTab = "home"; }
        else if (Hub.page !== "") Hub.close();
        else if (Hub.status.hypr && appInFront) Hub.command({action: "phone-back"});
        else { const w = previousWindow(); if (w) Hub.focusWindow(w); }
    }

    // Split view and slide-over on tablets through the optional compositor adapter.
    property bool splitActive: false
    property string splitLeft: ""
    property string splitRight: ""
    property real splitRatio: Hub.prefs.phoneSplitRatio || .5
    property var splitScreen: null
    property string slideAddress: ""
    function outputName(screen) { return screen ? screen.name : ""; }
    function keyboardInset(screen) { return Hub.systemOskVisible && screen ? Math.round(screen.height * .38) : 0; }
    function applySplit() {
        if (!splitActive || !splitScreen) return;
        // Workspace 0 tells the backend not to move either window; split only pairs windows that share a workspace.
        Hub.command({action: "phone-split", output: splitScreen.name, left: splitLeft, right: splitRight, ratio: splitRatio, top: barHeight, bottom: navFor(splitScreen), keyboard: keyboardInset(splitScreen), workspace: 0});
    }
    // The tablet dock is inside the navigation bar now, so there is no extra dock height.
    function dockHeight(screen) { return 0; }
    // The tablet bar holds the floating dock; with gestures the gesture strip sits under it.
    readonly property int tabletNavHeight: Hub.prefs.phoneButtons ? 88 : 100
    function navFor(screen) { return isTablet(screen) && Hub.prefs.tabletDock !== false ? tabletNavHeight : navHeight; }
    function startSplit(screen, left, right) {
        if (!left || !right || left === right || !Hub.status.hypr || isTablet(screen)) return false;
        const a = Hub.windows.find(w => w.address === left), b = Hub.windows.find(w => w.address === right);
        if (!a || !b || a.workspace !== b.workspace) return false;
        splitScreen = screen; splitLeft = left; splitRight = right; splitActive = true;
        applySplit();
        splitCheck.restart();
        return true;
    }
    function splitWithPrevious(screen) {
        const a = activeWindow(), b = previousWindow();
        // A tablet tiles, and split view never moves windows between workspaces.
        if (isTablet(screen)) return false;
        if (a && b && a.workspace !== b.workspace) return false;
        return a && b ? startSplit(screen, a.address, b.address) : false;
    }
    function setRatio(value, commit) {
        splitRatio = Math.max(.25, Math.min(.75, value));
        if (commit) { Hub.set("phoneSplitRatio", splitRatio); applySplit(); } else splitThrottle.start();
    }
    Timer { id: splitThrottle; interval: 70; onTriggered: s.applySplit() }
    // A split that did not take hold (windows not floating side by side) ends, so no divider is left over an app.
    Timer {
        id: splitCheck; interval: 1500
        onTriggered: {
            if (!s.splitActive) return;
            const ws = Hub.compositorWindows.filter(w => w.address === s.splitLeft || w.address === s.splitRight);
            const placed = ws.length === 2 && ws.every(w => w.floating) && ws[0].workspace === ws[1].workspace;
            if (!placed) { s.endSplit(); Hub.message("Split view could not place both windows"); }
        }
    }
    function endSplit() {
        if (!splitActive) return;
        Hub.command({action: "phone-unsplit", addresses: [splitLeft, splitRight], outputs: phoneScreens().map(sc => sc.name)});
        splitActive = false; splitLeft = ""; splitRight = "";
    }
    function swapSplit() {
        if (!splitActive) return;
        const left = splitLeft;
        splitLeft = splitRight;
        splitRight = left;
        splitRatio = Math.max(.25, Math.min(.75, 1 - splitRatio));
        applySplit();
    }
    function saveSplitPair() {
        if (!splitActive) return;
        const a = Hub.windows.find(w => w.address === splitLeft), b = Hub.windows.find(w => w.address === splitRight);
        const appA = a ? Hub.appForWindow(a) : null, appB = b ? Hub.appForWindow(b) : null;
        if (appA && appB) Hub.addAppPairToHome(appA, appB, splitRatio);
        else Hub.message("Could not identify both apps to save pair");
    }
    property var pendingPair: null
    function launchAppPair(screen, leftId, rightId, ratio) {
        const sc = screen || homeScreen();
        const appA = Hub.apps.find(a => a.id === leftId), appB = Hub.apps.find(a => a.id === rightId);
        if (!appA || !appB) return;
        const winA = Hub.windows.find(w => Hub.appForWindow(w) === appA), winB = Hub.windows.find(w => Hub.appForWindow(w) === appB);
        if (winA && winB && sc) {
            splitRatio = ratio || .5;
            startSplit(sc, winA.address, winB.address);
            Hub.close();
            return;
        }
        pendingPair = {screen: sc, leftId: leftId, rightId: rightId, ratio: ratio || .5, until: Date.now() + 15000};
        if (!winA) Hub.launchNew(appA);
        if (!winB) Hub.launchNew(appB);
    }
    function slideOver(screen, address) {
        if (!address || !Hub.status.hypr || !screen) return;
        slideAddress = address;
        Hub.command({action: "phone-slideover", output: screen.name, address: address, fraction: .38, top: statusFor(screen), bottom: navFor(screen)});
    }
    // The phone or tablet screen that a home menu acts on.
    function homeScreen() { return isTablet(Hub.targetScreen) || phoneScreens().indexOf(Hub.targetScreen) >= 0 ? Hub.targetScreen : phoneScreens()[0] || null; }
    // An app opened "in slide over": its first new window slides over when it appears.
    property var pendingSlide: null
    function openSlideOver(screen, app) {
        if (!app || !screen) return;
        pendingSlide = {id: app.id, screen: screen, known: Hub.windows.map(w => w.address), until: Date.now() + 15000};
        Hub.launch(app);
    }
    function catchSlide() {
        const pair = pendingPair;
        if (pair) {
            if (Date.now() > pair.until) pendingPair = null;
            else {
                const winA = Hub.windows.find(x => Hub.appForWindow(x) && Hub.appForWindow(x).id === pair.leftId);
                const winB = Hub.windows.find(x => Hub.appForWindow(x) && Hub.appForWindow(x).id === pair.rightId);
                if (winA && winB) {
                    pendingPair = null;
                    splitRatio = pair.ratio || .5;
                    startSplit(pair.screen || homeScreen(), winA.address, winB.address);
                }
            }
        }
        const p = pendingSlide;
        if (!p) return;
        if (Date.now() > p.until) { pendingSlide = null; return; }
        const w = Hub.windows.find(x => p.known.indexOf(x.address) < 0 && Hub.appForWindow(x) && Hub.appForWindow(x).id === p.id);
        if (w) { pendingSlide = null; slideOver(p.screen, w.address); }
    }
    // Window actions for one app, shared by the dock menu and the home menu.
    function windowExtras(screen, app) {
        if (!app || !Hub.status.hypr || !screen) return [];
        const w = Hub.windows.find(x => Hub.appForWindow(x) === app);
        if (!w) return [{text: "Open in slide over", icon: "picture_in_picture", run: () => openSlideOver(screen, app)}];
        const out = [];
        const active = activeWindow();
        // A tablet already tiles windows side by side, so only a phone offers to pair two apps.
        if (!isTablet(screen) && active && active.address !== w.address) out.push({text: "Open beside current app", icon: "splitscreen_vertical_add", run: () => startSplit(screen, active.address, w.address)});
        if (w.floating) out.push({text: "Back to tiling", icon: "dashboard", run: () => { Hub.command({action: "window-tile", address: w.address}); if (slideAddress === w.address) slideAddress = ""; }});
        else out.push({text: "Slide over", icon: "picture_in_picture", run: () => slideOver(screen, w.address)});
        return out;
    }
    // A split ends when one of its windows closes.
    readonly property var windowAddresses: Hub.windows.map(w => w.address)
    onWindowAddressesChanged: { catchSlide(); if (splitActive && (windowAddresses.indexOf(splitLeft) < 0 || windowAddresses.indexOf(splitRight) < 0)) { splitActive = false; splitLeft = ""; splitRight = ""; } }

    // Fit apps to phone outputs. A window that opens, or an output that changes, triggers one debounced call.
    function fit() {
        // While a split is shown the fitter waits; maximizing would break the split.
        if (!Hub.status.hypr || Hub.prefs.phoneFitApps === false || splitActive) return;
        const names = fitNames;
        if (names.length) Hub.command({action: "phone-fit", outputs: names, modes: Hub.prefs.phoneAppModes || ({})});
    }
    // Only phone-sized outputs fit apps one at a time. Tablets keep desktop tiling.
    readonly property var fitNames: phoneScreens().filter(sc => !isTablet(sc)).map(sc => sc.name)
    readonly property var tabletNames: phoneScreens().filter(sc => isTablet(sc)).map(sc => sc.name)
    onTabletNamesChanged: tileTimer.restart()
    // A tablet output re-tiles once when it appears and after a reload, so windows from an earlier phone fit do not stay floating.
    Timer { id: tileTimer; interval: 600; running: true; onTriggered: if (Hub.status.hypr && s.tabletNames.length) Hub.command({action: "tablet-tile", outputs: s.tabletNames}) }
    Timer { id: fitTimer; interval: 350; onTriggered: s.fit() }
    // When an output stops being a phone, windows that phone mode floated or maximized get their own state back.
    property var lastFitNames: []
    onFitNamesChanged: {
        const left = lastFitNames.filter(n => fitNames.indexOf(n) < 0);
        lastFitNames = fitNames.slice();
        if (left.length && Hub.status.hypr) { if (splitActive) endSplit(); Hub.command({action: "phone-release", outputs: []}); }
    }
    Connections { target: Hub; function onCompositorWindowsChanged() { fitTimer.restart(); } }
    // The on-screen keyboard lifts floating windows. Tiled windows resize by the compositor.
    Connections {
        target: Hub
        function onSystemOskVisibleChanged() { liftTimer.restart(); }
    }
    Timer {
        id: liftTimer; interval: 200
        onTriggered: s.phoneScreens().forEach(sc => Hub.command({action: "phone-lift", output: sc.name, keyboard: s.keyboardInset(sc)}))
    }

    // Backend events.
    function ingest(e) {
        if (e.event === "recentActivity") activity = {files: e.files || [], games: e.games || []};
        else if (e.event === "torch") torch = {available: !!e.available, on: !!e.on, name: e.name || ""};
        else if (e.event === "batteryStats") {
            battery = e;
            if (e.available && e.percent !== null) batteryHistory = batteryHistory.concat([{t: Date.now(), percent: e.percent, watts: e.watts || 0}]).slice(-120);
        }
    }
    function refreshActivity() { Hub.command({action: "recent-activity"}); }
    function refreshTorch() { Hub.command({action: "torch-status"}); }
    function setTorch(on) { Hub.command({action: "torch", on: on}); }
    function refreshBattery() { Hub.command({action: "battery-stats"}); }
    Component.onCompleted: refreshTorch()
}
