import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the real clipboard panel in each state with fixed data. No services.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 490; height: 650; visible: true; color: "#202024"
        property int step: 0
        readonly property var samples: [
            "A little thought worth keeping.",
            "https://m3.material.io/components/chips/overview",
            "const idea = {\n  color: 'expressive',\n  mood: 'quiet'\n};",
            "Meet at 16:30. Bring the good playlist.",
            "#7c5cff",
            "kriscross@example.com",
            "sudo pacman -Syu --needed quickshell-git",
            "/home/u/Pictures/Wallpapers/Shoreline.png",
            "The quick brown fox jumps over the lazy dog, and then keeps running for a very long time across the whole paragraph so it wraps several lines."
        ]
        property var cases: [
            {name: "clip-list"},
            {name: "clip-expand-code", expand: "fixture-2"},
            {name: "clip-expand-color", expand: "fixture-4"},
            {name: "clip-expand-image", expand: "fixture-img"},
            {name: "clip-chip-links", chip: "links"},
            {name: "clip-empty", empty: true},
            {name: "clip-filter", filter: "http"},
            {name: "clip-phone", phone: true, w: 412, h: 860},
            {name: "clip-widget", widget: true, w: 840, h: 320}
        ]
        Rectangle { id: panel; x: 0; y: 0; width: win.width; height: win.height; radius: 36; color: Opal.Theme.level(1); clip: true
            Loader { id: loader; anchors.fill: parent }
        }
        Component { id: panelView; Opal.ClipboardPanel { touchMode: !!(win.cases[win.step] || {}).phone } }
        Component { id: widgetView; Item { Opal.ClipboardCard { anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 } } } }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            win.width = c.w || 490; win.height = c.h || 650;
            const now = Date.now();
            Opal.Hub.clipboardAvailable = true;
            const kinds = ["Text", "Link", "Snippet", "Text", "Color", "Email", "Text", "Path", "Text"];
            const list = samples.map((t, i) => ({id: "fixture-" + i, text: t, chars: t.length, lines: t.split("\n").length, kind: kinds[i], host: i === 1 ? "m3.material.io" : undefined, captured: now - (i + 1) * 7 * 60000 - (i > 5 ? 86400000 : 0), pinned: i === 3, source: ["kitty", "firefox", "code", "", "org.gnome.Nautilus", "thunderbird", "kitty", "org.gnome.Nautilus", ""][i]}));
            list.splice(2, 0, {id: "fixture-img", text: "", chars: 0, lines: 0, kind: "Image", image: Quickshell.env("HOME") + "/Ocean.png", mime: "image/png", bytes: 412000, width: 640, height: 360, captured: now - 3 * 60000, pinned: false, source: "firefox"});
            Opal.Hub.clipboardItems = c.empty ? [] : list;
            loader.sourceComponent = null; loader.sourceComponent = c.widget ? widgetView : panelView;
            if (c.filter) loader.item.filter = c.filter;
            if (c.chip) loader.item.kindFilter = c.chip;
            if (c.expand !== undefined) { const i = loader.item.items.findIndex(x => x.id === c.expand); loader.item.select(i); loader.item.toggleExpand(c.expand); }
            // The sandbox backend publishes an empty history at start, so the fixture is set again before the grab.
            refix.list = c.empty ? [] : list; refix.restart();
            grab.restart();
        }
        Timer { id: refix; property var list: []; interval: 600; onTriggered: Opal.Hub.clipboardItems = list }
        Timer { id: grab; interval: 1500; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
        Component.onCompleted: Qt.callLater(run)
    }
}
