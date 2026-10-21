pragma Singleton
import QtQuick
import Quickshell

// The compositor under Opal and the game-session roles it carries out: the console home underneath, the app in front, the overlay above.
// Hyprland: the home is the empty Home workspace and apps open fullscreen on the Play workspace. Gamescope: base-layer app focus.
QtObject {
    id: comp
    readonly property bool gamescope: Quickshell.env("OPAL_COMPOSITOR") === "gamescope"
    readonly property string kind: gamescope ? "gamescope" : Hub.status.hypr ? "hyprland" : "wayland"
    // Console roles apply in the gamescope session and in console mode.
    readonly property bool consoleRoles: gamescope || Hub.prefs.mode === "console"
    readonly property var apps: Hub.windows.filter(w => !Hub.minimized(w))
    // The home is on screen when no app is in front of it.
    readonly property bool homeShown: {
        if (gamescope) return Hub.status.homeShown !== false;
        const monitors = Hub.status.monitors || [];
        const active = monitors.find(m => m.name === Hub.status.activeMonitor) || monitors[0];
        const shown = active ? Number(active.workspace) : Number(Hub.status.workspace);
        return !apps.some(w => Number(w.workspace) === shown);
    }
    function showHome() { Hub.close(); GameState.closeQuickAccess(); Hub.command({action: "console-home"}); }
    function focusApp(w) {
        if (!w) return;
        GameState.closeQuickAccess();
        if (gamescope) { Hub.close(); Hub.command({action: "console-focus", appid: w.appid}); }
        else Hub.focusWindow(w);
    }
    function closeApp(w) { if (!w) return; if (gamescope) Hub.command({action: "console-close", appid: w.appid}); else Hub.closeWindow(w); }
    // Gamescope routes keyboard and pointer input to the overlay only while it asks for it.
    function overlayInput(on) { if (gamescope) Hub.command({action: "console-overlay-input", on: on === true}); }
}
