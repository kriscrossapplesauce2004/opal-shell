pragma Singleton
import QtQuick

// Quick Access state: the overlay, the running game and the performance report from game_perf.py.
QtObject {
    id: state
    property bool quickAccess: false
    // glance: the small pill over the game. sheet: the full Quick Access.
    property string stage: "sheet"
    // True when the overlay was opened by keyboard or IPC, so it may take keyboard focus.
    property bool keyboardOpened: false
    property var perf: ({})
    property var detail: ({})
    // Console home widgets from game_widgets.py: Steam updates, storage, captures and Prism instances.
    property var widgets: ({updates: [], storage: {}, captures: {total: 0, perGame: {}, items: []}, instances: []})
    // The profile the backend applied to the game in front, {id, profile}.
    property var applied: ({})
    readonly property var presets: ({saver: {power: "power-saver", fpsLimit: 40, name: "Saver", icon: "eco"}, balanced: {power: "balanced", fpsLimit: 60, name: "Balanced", icon: "balance"}, max: {power: "performance", fpsLimit: 0, name: "Max", icon: "rocket_launch"}})
    function ownProfile(id) { const all = Hub.prefs.gameProfiles || {}; return id && all[id] ? all[id] : null; }
    // Its own profile, else the next-game preset. Mirrors game_profiles.resolve.
    function profileFor(id) {
        const own = ownProfile(id);
        if (own && presets[own.preset]) return Object.assign({}, presets[own.preset], {preset: own.preset, own: true});
        if (own && own.preset === "custom") return Object.assign({power: "balanced", fpsLimit: 0, name: "Custom", icon: "tune"}, own, {own: true, name: "Custom", icon: "tune"});
        const next = presets[Hub.prefs.gameProfileNext] ? Hub.prefs.gameProfileNext : "balanced";
        return Object.assign({}, presets[next], {preset: next, own: false});
    }
    function profileLabel(id) { const p = profileFor(id); return p.name + " · " + (p.fpsLimit ? p.fpsLimit + " FPS" : "no limit"); }
    function setOwnProfile(id, profile) {
        const all = Object.assign({}, Hub.prefs.gameProfiles || {});
        if (profile) all[id] = profile; else delete all[id];
        Hub.set("gameProfiles", all);
        if (id && id === activeGameId) { Hub.command({action: "game-profile-end"}); Hub.command({action: "game-profile-start", id: id}); }
    }
    function loadWidgets() { Hub.command({action: "game-widgets"}); }
    // A game in front gets its profile: always in console mode, on the desktop only when it has its own.
    readonly property string activeGameId: runningGame ? runningGame.id : ""
    onActiveGameIdChanged: {
        if (activeGameId && (Compositor.consoleRoles || ownProfile(activeGameId))) Hub.command({action: "game-profile-start", id: activeGameId});
        else if (!activeGameId) Hub.command({action: "game-profile-end"});
    }
    readonly property bool perfReady: perf.event === "gamePerf"
    // A library game with a window, else the fullscreen window title.
    readonly property var runningGame: Hub.games.find(g => Hub.gameRunning(g)) || null
    // Under gamescope any app in front of the home is fullscreen.
    readonly property bool fullscreen: Compositor.gamescope ? !Compositor.homeShown : (Hub.status.fullscreenMonitors || []).length > 0
    readonly property bool gameActive: runningGame !== null || fullscreen
    readonly property string gameTitle: runningGame ? runningGame.title : fullscreen ? (Hub.status.title || "Current app") : ""
    readonly property var gameWindows: runningGame ? Hub.gameWindows(runningGame) : []
    // Time since Opal first saw this game running.
    property string seenId: ""
    property date seenAt: new Date()
    readonly property int sessionMinutes: gameActive ? Math.max(0, Math.floor((Hub.now - seenAt) / 60000)) : 0
    onGameTitleChanged: { if (gameTitle !== "" && gameTitle !== seenId) seenAt = new Date(); seenId = gameTitle; }

    function receive(e) {
        if (e.event === "gamePerf") perf = e;
        else if (e.event === "gameDetail") detail = e;
        else if (e.event === "gameWidgets") widgets = e;
        else if (e.event === "gameProfile") applied = e;
    }
    function refresh() { Hub.command({action: "perf-get"}); }
    function set(key, value) { Hub.command({action: "perf-set", key: key, value: value}); }
    function loadDetail(id) { detail = {id: id}; Hub.command({action: "game-detail", id: id}); }
    function openQuickAccess(keyboard) {
        Hub.close();
        Hub.targetScreen = Hub.chooseScreen();
        keyboardOpened = keyboard === true;
        // Over a game, Guide first shows the glance; a keyboard or IPC open goes straight to the sheet.
        stage = gameActive && keyboard !== true ? "glance" : "sheet";
        quickAccess = true;
        refresh();
    }
    function closeQuickAccess() { quickAccess = false; }
    function toggleQuickAccess() { if (quickAccess) closeQuickAccess(); else openQuickAccess(true); }
    function quitGame() { gameWindows.forEach(w => Hub.closeWindow(w)); }
}
