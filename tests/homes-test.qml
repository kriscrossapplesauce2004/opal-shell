import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the real phone, tablet and desktop homes with fixed data. No services.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property var activities: [
        {id: "x:cc", external: "cc", kind: "agent", icon: "terminal", title: "Claude Code needs you", short: "Needs you", subtitle: "~/opal · wants to use Bash", code: "$ git push origin overhaul-2026-10", progress: -1, priority: 88, since: 1, until: 0,
            controls: [{id: "x:open", action: "open", icon: "open_in_new"}, {id: "x:deny", action: "deny", label: "Deny"}, {id: "x:allow", action: "allow", label: "Allow", primary: true}]},
        {id: "pacman", kind: "system", icon: "system_update", title: "Updating packages", short: "12", subtitle: "pacman · mesa", progress: -2, progressText: "12 done", priority: 65, since: 1, until: 0, controls: []}
    ]
    Window {
        id: win
        width: 412; height: 915; visible: true; color: "#000"
        property int step: 0
        property var cases: [
            {name: "home-phone", view: phoneView},
            {name: "home-phone-minus", view: phoneView, page: 0},
            {name: "home-phone-menu", view: phoneView, menu: true},
            {name: "home-phone-edit", view: phoneView, edit: true},
            {name: "home-phone-picker", view: phoneView, picker: true},
            {name: "home-tablet", view: phoneView, w: 1280, h: 800},
            {name: "home-desktop-empty", view: desktopView, w: 1600, h: 900, empty: true},
            {name: "home-desktop-edit", view: desktopView, w: 1600, h: 900, edit: true},
            {name: "home-desktop-bright", view: desktopView, w: 1600, h: 900, empty: true, bright: true},
            {name: "home-phone-light", view: phoneView, light: true}
        ]
        property var current: cases[0]
        Loader { id: loader; anchors.fill: parent }
        Component {
            id: phoneView
            Item {
                property alias home: ph
                Image { anchors.fill: parent; source: "file:///home/melissa/Pictures/Wallpapers/default.png"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(1400, 1400) }
                Opal.PhoneHome { id: ph; anchors.fill: parent; anchors.topMargin: 48; anchors.bottomMargin: 24 }
            }
        }
        Component {
            id: desktopView
            Item {
                id: dv
                property alias home: dh
                readonly property string wall: win.current.bright ? "file:///home/melissa/Pictures/dr5-keyart-YzI66DkClTeJ5jBQ.png" : "file:///home/melissa/Pictures/Wallpapers/default.png"
                Image { anchors.fill: parent; source: dv.wall; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(1920, 1080) }
                Rectangle { anchors.fill: parent; color: "#000000"; opacity: .11 }
                Opal.WallpaperTone { id: tone; source: dv.wall; dim: .11; areaWidth: dv.width; areaHeight: dv.height }
                Opal.DesktopHome { id: dh; anchors.fill: parent; anchors.bottomMargin: 72; screenName: "TEST-1"; tone: tone }
            }
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            current = cases[step];
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!current.light, desktopCanvas: undefined});
            Opal.Activities.fixture = root.activities;
            Opal.HomeData.weather = {place: "Lisbon", temp: 18, unit: "°", text: "Partly cloudy", icon: "partly_cloudy_day", high: 21, low: 14};
            Opal.HomeData.photo = {path: "/home/melissa/Pictures/Wallpapers/3kg8qd.jpeg", caption: "1 year ago", detail: "Memories"};
            Opal.HomeData.updates = 42;
            Opal.HomeData.desktopItems = [
                {path: "/x/ROADMAP.md", name: "ROADMAP-2026-10.md", dir: false, glyph: "description", icon: "text-markdown"},
                {path: "/x/Prints", name: "Prints", dir: true, glyph: "folder", icon: "folder"},
                {path: "/x/AU1388.pdf", name: "AU1388.pdf", dir: false, glyph: "picture_as_pdf", icon: "application-pdf"}
            ];
            Opal.HomeData.editingScreen = current.edit && current.view === desktopView ? "TEST-1" : "";
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {monitors: [{name: "TEST-1", workspace: current.empty ? 3 : 1}]});
            Opal.PhoneState.activity = {files: [{title: "ROADMAP-2026-10.md", path: "/x/ROADMAP.md", ago: "1 h ago"}], games: [{id: "steam:1671210", title: "DELTARUNE", ago: "2 h ago"}]};
            win.width = current.w || 412; win.height = current.h || 915;
            loader.sourceComponent = null; loader.sourceComponent = current.view;
            const h = loader.item.home;
            if (current.view === phoneView) {
                if (current.page !== undefined) Qt.callLater(() => h.pager.positionViewAtIndex(current.page, 0));
                if (current.edit) h.editing = true;
                if (current.picker) { h.editing = true; h.pickerOpen = true; }
                if (current.menu) Qt.callLater(() => { h.menuFor = {page: 0, index: 0, app: Opal.Hub.apps[0] || null, folder: false, x: 20, y: 520, w: h.cellWidth, h: h.cellHeight}; });
            }
            refill.restart();
            grab.restart();
        }
        // The sandboxed backend answers the recent files request with nothing, so the fixture goes back in after it.
        Timer { id: refill; interval: 900; onTriggered: Opal.PhoneState.activity = {files: [{title: "ROADMAP-2026-10.md", path: "/x/ROADMAP.md", ago: "1 h ago"}], games: [{id: "steam:1671210", title: "DELTARUNE", ago: "2 h ago"}]} }
        Timer { id: grab; interval: 1800; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
        Component.onCompleted: Qt.callLater(run)
    }
}
