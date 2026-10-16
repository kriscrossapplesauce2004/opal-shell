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
            {name: "home-tablet-full", view: tabletView, w: 1280, h: 800, full: true},
            {name: "home-tablet-1080", view: tabletView, w: 1920, h: 1080, full: true},
            {name: "home-tablet-1080-sparse", view: tabletView, w: 1920, h: 1080, sparse: true, bright: true},
            {name: "tablet-workspaces", view: tabletView, w: 1280, h: 800, full: true, spaces: true},
            {name: "tablet-launcher-over-app", view: tabletView, w: 1920, h: 1080, sparse: true, drawer: true, appOpen: true},
            {name: "tablet-launcher-over-app-opening", view: tabletView, w: 1920, h: 1080, sparse: true, drawer: true, appOpen: true, arrival: .55},
            {name: "tablet-launcher", view: tabletView, w: 1280, h: 800, full: true, drawer: true},
            {name: "tablet-launcher-1080", view: tabletView, w: 1920, h: 1080, sparse: true, bright: true, drawer: true},
            {name: "tablet-launcher-1080-opening", view: tabletView, w: 1920, h: 1080, sparse: true, bright: true, drawer: true, arrival: .5},
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
        // The whole tablet screen: backdrop, status bar, home and the dock bar.
        Component {
            id: tabletView
            Item {
                id: tv
                property alias home: th
                Opal.PhoneBackdrop { anchors.fill: parent; soft: 0 }
                Opal.PhoneStatus { anchors.left: parent.left; anchors.right: parent.right; height: 48 }
                Opal.PhoneHome { id: th; anchors.fill: parent; anchors.topMargin: 48; anchors.bottomMargin: Opal.PhoneState.tabletNavHeight }
                property alias bar: tbar
                Opal.TabletBar { id: tbar; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Opal.PhoneState.tabletNavHeight; screenObj: null }
                // A stand-in app window, for the launcher that opens over an app.
                Rectangle {
                    visible: !!win.current.appOpen
                    anchors.fill: parent; anchors.topMargin: 48; anchors.bottomMargin: Opal.PhoneState.tabletNavHeight
                    color: "#f4f1ec"
                    Rectangle { width: parent.width; height: 44; color: "#e2ddd5"; Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "kitty — ~/opal"; font.pixelSize: 15; color: "#333" } }
                    Text { x: 24; y: 70; text: "$ git status\nOn branch overhaul-2026-10\nnothing to commit, working tree clean"; font.family: "monospace"; font.pixelSize: 18; color: "#222" }
                }
                // The workspace card where the live window puts it: just above the bar, from the chip's left edge.
                Opal.WorkspaceCard {
                    visible: !!win.current.spaces
                    width: implicitWidth; height: implicitHeight
                    x: Math.max(8, tbar.workspaces.mapToItem(tv, 0, 0).x - 2); y: tv.height - Opal.PhoneState.tabletNavHeight + 6 - height
                }
                Opal.TabletLauncher { anchors.fill: parent; visible: !!win.current.drawer; arrival: win.current.arrival === undefined ? 1 : win.current.arrival }
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
                Opal.DesktopHome { id: dh; anchors.fill: parent; anchors.bottomMargin: 72; screenName: "TEST-1" }
            }
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            current = cases[step];
            const ids = Opal.Hub.apps.map(a => a.id);
            const homeLayout = current.full ? {pages: [{widgets: [{kind: "glance", w: 4, h: 1}, {kind: "media", w: 4, h: 2}, {kind: "photos", w: 2, h: 2}, {kind: "devices", w: 2, h: 2}, {kind: "live", w: 4, h: 2}], items: ids.slice(0, 14)}, {widgets: [], items: ids.slice(14, 20)}]}
                : current.sparse ? {pages: [{widgets: [{kind: "glance", w: 4, h: 1}, {kind: "media", w: 4, h: 2}, {kind: "live", w: 4, h: 2}], items: [ids[0], null, ids[1], null, null, ids[2]]}]} : undefined;
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!current.light, desktopCanvas: undefined, phoneButtons: true, phoneHome: homeLayout, homeDesktopFiles: !!current.sparse,
                wallpaperPath: current.bright ? "file:///home/melissa/Pictures/dr5-keyart-YzI66DkClTeJ5jBQ.png" : current.view === tabletView ? "file:///home/melissa/Pictures/Wallpapers/default.png" : undefined});
            Opal.Activities.fixture = current.sparse ? [] : root.activities;
            Opal.HomeData.weather = {place: "Lisbon", temp: 18, unit: "°", text: "Partly cloudy", icon: "partly_cloudy_day", high: 21, low: 14};
            Opal.HomeData.photo = {path: "/home/melissa/Pictures/Wallpapers/3kg8qd.jpeg", caption: "1 year ago", detail: "Memories"};
            Opal.HomeData.updates = 42;
            Opal.HomeData.desktopFolder = "/x";
            Opal.HomeData.desktopItems = [
                {path: "/x/ROADMAP.md", name: "ROADMAP-2026-10.md", dir: false, glyph: "description", icon: "text-markdown"},
                {path: "/x/Prints", name: "Prints", dir: true, glyph: "folder", icon: "folder"},
                {path: "/x/AU1388.pdf", name: "AU1388.pdf", dir: false, glyph: "picture_as_pdf", icon: "application-pdf"}
            ];
            Opal.HomeData.editingScreen = current.edit && current.view === desktopView ? "TEST-1" : "";
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {monitors: [{name: "TEST-1", workspace: current.empty ? 3 : 1}], hypr: current.view === tabletView, workspaces: [1, 2, 3], workspace: 3});
            Opal.PhoneState.activity = {files: [{title: "ROADMAP-2026-10.md", path: "/x/ROADMAP.md", ago: "1 h ago"}], games: [{id: "steam:1671210", title: "DELTARUNE", ago: "2 h ago"}]};
            if (current.appOpen) Opal.Hub.windows = [{className: "kitty", workspace: 3, address: "k", at: [0, 48], size: [1920, 944]}];
            else if (!current.spaces) Opal.Hub.windows = [];
            win.width = current.w || 412; win.height = current.h || 915;
            loader.sourceComponent = null; loader.sourceComponent = current.view;
            const h = loader.item.home;
            if (current.view === phoneView) {
                if (current.page !== undefined) Qt.callLater(() => h.pager.positionViewAtIndex(current.page, 0));
                if (current.edit) h.editing = true;
                if (current.picker) { h.editing = true; h.pickerOpen = true; }
                if (current.menu) Qt.callLater(() => { h.menuFor = {page: 0, index: 0, app: Opal.Hub.apps[0] || null, folder: false, x: 20, y: 520, w: h.cellWidth, h: h.cellHeight}; });
            }
            if (current.spaces) {
                Opal.Hub.windows = [{className: ids[2], workspace: 1, address: "a", at: [0, 0], size: [640, 800]}, {className: ids[5], workspace: 1, address: "b", at: [640, 0], size: [640, 400]},
                    {className: ids[7], workspace: 1, address: "d", at: [640, 400], size: [640, 400]}, {className: ids[9], workspace: 2, address: "c", at: [0, 0], size: [1280, 800]}];
                Opal.Hub.status = Object.assign({}, Opal.Hub.status, {monitors: [{name: "", x: 0, y: 0, width: 1280, height: 800, scale: 1, transform: 0}]});
                Opal.PhoneState.spacesOpen = true;
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
