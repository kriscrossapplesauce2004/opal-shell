import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the real shared search in each state with fixed data. No services.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 680; height: 640; visible: true; color: Opal.Theme.base
        property int step: 0
        property var cases: [
            {name: "search-idle", q: ""},
            {name: "search-dark", q: "dark"},
            {name: "search-convert", q: "5 km to mi"},
            {name: "search-claude", q: "how do i make window gaps smaller", answer: "Open **Settings › Wallpaper & style › Window gaps** and lower *Inner* and *Outer*. Opal writes the new values to its Hyprland include, so it applies at once."},
            {name: "search-files", q: "roadmap", files: [{path: "/home/u/opal/docs/ROADMAP-2026-10.md", name: "ROADMAP-2026-10.md", folder: "~/opal/docs", dir: false}]},
            {name: "search-touch", q: "set", touch: true, w: 412, h: 760}
        ]
        Rectangle { id: panel; x: 20; y: 20; width: win.width - 40; height: win.height - 40; radius: 32; color: Opal.Theme.level(1); clip: true
            Loader { id: loader; anchors.fill: parent }
        }
        Component { id: searchView; Opal.OpalSearch { touch: !!(win.cases[win.step] || {}).touch } }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            win.width = c.w || 680; win.height = c.h || 640;
            Opal.Activities.chipFixture = [{id: "code:1", kind: "code", label: "Copy code 482913", icon: "copy", arg: "482913"}, {id: "continue:x", kind: "continue", label: "Continue Hyprland Wiki", icon: "link", arg: "firefox"}];
            Opal.Hub.query = c.q;
            Opal.Hub.fileResults = {query: c.q, items: c.files || []};
            loader.sourceComponent = null; loader.sourceComponent = searchView;
            if (c.answer) { loader.item.sentQuery = c.q; Opal.Hub.claudeAnswer = c.answer; Opal.Hub.claudeBusy = false; } else Opal.Hub.claudeAnswer = "";
            grab.restart();
        }
        Timer { id: grab; interval: 1500; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
        Component.onCompleted: Qt.callLater(run)
    }
}
