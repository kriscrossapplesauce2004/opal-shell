import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Frame-by-frame demo of the dock menu at 30 fps. Each frame is saved as a PNG for ffmpeg.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 1280; height: 720; visible: true; color: "black"
        property int frame: 0
        readonly property int total: 330
        Opal.DockScene {
            id: dock
            anchors.fill: parent
            autoplay: false
            output: "HDMI-A-1"
            description: "Living room TV"
            hasPhone: true
            apps: [{address: "0x1", title: "Mozilla Firefox", className: "firefox"}, {address: "0x2", title: "~ — kitty", className: "kitty"}, {address: "0x3", title: "Deltarune", className: "steam_app_1671210"}]
            modes: ["3840x2160@60.00Hz", "2560x1440@120.00Hz", "1920x1080@60.00Hz"]
        }
        Component.onCompleted: {
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {wallpaperPath: "file://" + Quickshell.env("HOME") + "/Ocean.png", wallpaperDim: 0, light: false});
            Opal.Hub.apps = [{id: "firefox", name: "Firefox", icon: "firefox", categories: [], keywords: [], execute: () => {}}, {id: "kitty", name: "Kitty", icon: "kitty", categories: [], keywords: [], execute: () => {}}];
            dock.pagerView.highlightRangeMode = ListView.NoHighlightRange;
            dock.pagerView.interactive = false;
            starter.start();
        }
        Timer { id: starter; interval: 1500; onTriggered: { Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {wallpaperPath: "file://" + Quickshell.env("HOME") + "/Ocean.png", wallpaperDim: 0, light: false}); win.step(); } }
        function ease(t) { return 1 - Math.pow(1 - Math.max(0, Math.min(1, t)), 3); }
        function easeIn(t) { t = Math.max(0, Math.min(1, t)); return t * t * t; }
        function between(a, b) { return (frame - a) / (b - a); }
        // Timeline, in frames.
        function apply() {
            const f = frame, w = dock.pagerView.width;
            if (f <= 40) dock.arrival = ease(f / 40);
            if (f === 70) dock.mode = "console";
            if (f === 95) dock.mode = "desktop";
            if (f >= 115 && f <= 133) dock.pagerView.contentX = w * ease(between(115, 133));
            if (f === 155) dock.toggleApp("0x3");
            if (f >= 180 && f <= 198) dock.pagerView.contentX = w * (1 + ease(between(180, 198)));
            if (f === 215) dock.phoneMode = "panel";
            if (f === 235) dock.phoneMode = "trackpad";
            if (f >= 250 && f <= 268) dock.pagerView.contentX = w * (2 + ease(between(250, 268)));
            if (f === 285) dock.scale = 1.25;
            if (f >= 305) dock.arrival = 1 - easeIn(between(305, 325));
            dock.page = Math.round(dock.pagerView.contentX / Math.max(1, w));
        }
        function step() {
            apply();
            // Let behaviours settle a little between frames, then save.
            settle.restart();
        }
        Timer {
            id: settle; interval: 60
            onTriggered: win.contentItem.grabToImage(result => {
                result.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/frame-" + String(win.frame).padStart(4, "0") + ".png");
                win.frame++;
                if (win.frame >= win.total) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); }
                else win.step();
            })
        }
    }
}
