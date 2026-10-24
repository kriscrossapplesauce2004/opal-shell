import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the switch assistant's pages and phases with fixture checks from a GNOME and a KDE computer.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 1120; height: 760; visible: true; color: Opal.Theme.base
        property int step: 0
        readonly property string ocean: Quickshell.env("HOME") + "/Ocean.png"
        readonly property var gnome: ({
            distro: {id: "fedora", name: "Fedora Linux 41 (Workstation Edition)", like: []}, manager: "dnf", arch: "x86_64", desktop: "GNOME", session: "wayland", dm: "GDM",
            gpu: {nvidia: false, other: true, modeset: false}, have: {hyprland: false, quickshell: false, python: true, git: true, pkexec: true, curl: true, hyprlandLua: false},
            available: {hyprland: true, quickshell: "copr"}, missing: ["hyprland", "quickshell", "playerctl", "brightnessctl", "grim", "slurp", "wl-clipboard", "xdg-desktop-portal-hyprland", "cmake"],
            fonts: {"Material Symbols Rounded": false, "Google Sans Flex": false}, hyprVersion: "", hyprConfig: false, opalInstalled: false, sessionInstalled: false,
            terminal: "ptyxis", files: "nautilus", source: "/home/sam/.local/share/opal/source", free: 120 * 1073741824, problems: [], warnings: [],
            found: {light: false, wallpaper: ocean, palette: 1, accent: "teal", pins: ["firefox", "org.gnome.Nautilus", "kitty", "steam", "code", "org.gnome.Settings"], keyboard: "gb,us", naturalScroll: true, clock24: true}})
        readonly property var stages: [
            {id: "packages", title: "Install Hyprland, Quickshell and helpers", state: "done", progress: 1},
            {id: "session", title: "Add Opal to the login screen", state: "done", progress: 1},
            {id: "fonts", title: "Get the Opal fonts", state: "done", progress: 1},
            {id: "hyprland", title: "Write a Hyprland setup", state: "done", progress: 1},
            {id: "opal", title: "Install Opal", state: "running", progress: .6, detail: "Installed windowing plugin to /home/sam/.local/share/opal/plugins/opal-windowing.so"},
            {id: "settings", title: "Bring your desktop along", state: "waiting", progress: -1}]
        readonly property var cases: [
            {name: "switch-checking", phase: "checking"},
            {name: "switch-0-hello", page: 0},
            {name: "switch-0-blocked", page: 0, patch: {have: {hyprland: true, quickshell: false, python: true, git: true, pkexec: true, curl: true, hyprlandLua: true}, desktop: "KDE Plasma", dm: "SDDM",
                available: {quickshell: false}, missing: ["quickshell"], problems: ["Your distribution has no Quickshell package. Build it from quickshell.org, then run this again"],
                warnings: ["NVIDIA: Hyprland needs the proprietary driver with nvidia-drm.modeset=1 on the kernel command line"], gpu: {nvidia: true, other: false, modeset: false}}},
            {name: "switch-0-again", page: 0, patch: {sessionInstalled: true, opalInstalled: true, have: {hyprland: true, quickshell: true, python: true, git: true, pkexec: true, curl: true, hyprlandLua: true}, hyprVersion: "0.56.0", hyprConfig: true, missing: [], fonts: {"Material Symbols Rounded": true, "Google Sans Flex": true}}},
            {name: "switch-1-bring", page: 1},
            {name: "switch-1-bring-empty", page: 1, patch: {desktop: "Sway", found: {}}},
            {name: "switch-2-choose", page: 2},
            {name: "switch-2-choose-light", page: 2, light: true},
            {name: "switch-3-review", page: 3, phase: "ready"},
            {name: "switch-3-running", page: 3, phase: "running"},
            {name: "switch-3-done", page: 3, phase: "done"},
            {name: "switch-3-failed", page: 3, phase: "failed", log: true},
            {name: "switch-3-undone", page: 3, phase: "undone"},
            {name: "switch-narrow", page: 1, w: 420, h: 820}]
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            width = c.w || 1120; height = c.h || 760;
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, palette: 0, look: "mixed"});
            loader.sourceComponent = null;
            loader.sourceComponent = view;
            settle.restart();
        }
        Timer { id: settle; interval: 700; onTriggered: {
            const c = win.cases[win.step], s = loader.item;
            if (c.phase !== "checking") s.handle({event: "detect", data: Object.assign({}, win.gnome, c.patch || {})});
            if (c.light !== undefined) Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light});
            s.step = c.page || 0;
            if (c.phase === "running" || c.phase === "done" || c.phase === "failed") {
                s.phase = "running";
                s.handle({event: "plan", stages: win.stages});
                ["resolving dependencies…", "Installing hyprland-0.56.0-1.fc41.x86_64", "Building the Borealis keyboard...", "Installed windowing plugin"].forEach(t => s.handle({event: "log", text: t}));
            }
            if (c.phase === "done") s.handle({event: "done", ok: true});
            if (c.phase === "failed") { s.handle({event: "error", text: "Install Opal failed. Open the details for the log"}); s.handle({event: "done", ok: false}); s.showLog = !!c.log; }
            if (c.phase === "undone") { s.phase = "undoing"; s.handle({event: "done", ok: true}); }
            grab.restart();
        } }
        Timer { id: grab; interval: 1200; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
        Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.run(); else restart(); } }
        Loader { id: loader; anchors.fill: parent }
        Component { id: view; Opal.SwitchContent { onSend: cmd => console.log("SEND", JSON.stringify(cmd)) } }
    }
}
