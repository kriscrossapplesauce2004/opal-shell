import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders Luna on a foldable: the cover screen, the open book with one home page on each side of the hinge, and tabletop with the clock above the fold and controls below. No services.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property string art: "file://" + Quickshell.env("HOME") + "/Ocean.png"
    readonly property var activities: [
        {id: "focus", kind: "focus", icon: "timer", title: "Pasta timer", short: "4:12", subtitle: "Ends at 19:46", progress: .7, priority: 60, since: 2, until: 0, ring: true, ringText: "4:12", controls: []},
        {id: "n:9", nid: 9, kind: "transfer", icon: "download", title: "Saltmarsh S1E3", short: "62%", subtitle: "Downloading", progress: .62, priority: 55, since: 1, until: 0, controls: []}
    ]
    Window {
        id: win
        width: 412; height: 860; visible: true; color: "#000000"
        property int step: 0
        property var cases: [
            {name: "fold-cover", view: coverView, w: 412, h: 860},
            {name: "fold-book", view: openView, w: 1040, h: 1000, posture: "book"},
            {name: "fold-tabletop", view: openView, w: 1040, h: 1000, posture: "tabletop"},
            {name: "fold-book-light", view: openView, w: 1040, h: 1000, posture: "book", light: true}
        ]
        property var current: cases[0]
        readonly property real hinge: 28
        Loader { id: loader; anchors.fill: parent }
        // The cover screen is a phone: the usual phone home.
        Component {
            id: coverView
            Item {
                Opal.PhoneBackdrop { anchors.fill: parent; soft: 0 }
                Opal.PhoneStatus { anchors.left: parent.left; anchors.right: parent.right; height: 48 }
                Opal.PhoneHome { anchors.fill: parent; anchors.topMargin: 48; anchors.bottomMargin: 24 }
            }
        }
        // The inner screen. The posture decides how the two parts sit around the hinge.
        Component {
            id: openView
            Item {
                id: inner
                readonly property bool book: win.current.posture === "book"
                Opal.PhoneBackdrop { anchors.fill: parent; soft: inner.book ? 0 : .6 }
                Opal.PhoneStatus { anchors.left: parent.left; anchors.right: parent.right; height: 48 }
                Opal.PostureLayout {
                    anchors.fill: parent; anchors.topMargin: 48; anchors.bottomMargin: inner.book ? Opal.PhoneState.tabletNavHeight : 0
                    posture: win.current.posture; hinge: win.hinge
                    first: inner.book ? livePage : standClock
                    second: inner.book ? appsPage : standControls
                }
                Opal.TabletBar { visible: inner.book; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Opal.PhoneState.tabletNavHeight; screenObj: null }
                // The crease, as the screen shows it. It is part of the fixture, not of the shell.
                Rectangle {
                    x: inner.book ? parent.width / 2 - 1 : 0; y: inner.book ? 0 : 48 + (parent.height - 48) / 2 - 1
                    width: inner.book ? 2 : parent.width; height: inner.book ? parent.height : 2
                    color: Opal.Theme.alpha("#000000", .35)
                }
            }
        }
        // Book: the Live page on the left and the first home page on the right. The taskbar below carries the favourites, so neither half has a dock.
        Component { id: livePage; Opal.PhoneHome { startPage: 0; ownDock: false } }
        Component { id: appsPage; Opal.PhoneHome { startPage: 1; ownDock: false } }
        // Tabletop: a large clock and the glance above the fold, where the eyes are.
        Component {
            id: standClock
            Item {
                Column {
                    anchors.centerIn: parent; spacing: 18
                    Opal.LockClock { anchors.horizontalCenter: parent.horizontalCenter; kind: "stacked"; tone: "primary"; size: 150 }
                    Opal.LockGlance { anchors.horizontalCenter: parent.horizontalCenter; compact: true }
                }
            }
        }
        // Tabletop: the controls below the fold, where the fingers are.
        Component {
            id: standControls
            Rectangle {
                color: Opal.Theme.base
                Row {
                    anchors.fill: parent; anchors.margins: 24; spacing: 24
                    Opal.LockWidgets { width: (parent.width - 24) / 2; anchors.verticalCenter: parent.verticalCenter }
                    Opal.QuickTileDeck { width: (parent.width - 24) / 2; height: parent.height }
                }
            }
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            current = cases[step];
            const ids = Opal.Hub.apps.map(a => a.id);
            const homeLayout = {pages: [{widgets: [{kind: "glance", w: 4, h: 1}, {kind: "live", w: 4, h: 2}], items: ids.slice(0, 12)}, {widgets: [], items: ids.slice(12, 20)}]};
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!current.light, palette: 0, dynamicColors: false, phoneButtons: true, phoneHome: homeLayout, homeDesktopFiles: false, wallpaperPath: "file:///home/melissa/Pictures/Wallpapers/default.png"});
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {battery: 73, charging: false, wifi: true, bluetooth: true, hypr: false, workspaces: [1], workspace: 1});
            Opal.Hub.windows = [];
            Opal.Hub.focusRunning = true; Opal.Hub.focusSeconds = 4 * 60 + 12;
            Opal.Activities.fixture = root.activities;
            const now = Date.now();
            Opal.HomeData.weather = {place: "Lisbon", temp: 18, unit: "°", text: "Partly cloudy", icon: "partly_cloudy_day", high: 21, low: 14};
            Opal.HomeData.events = [{title: "Dinner with Sam", start: now + 90 * 60000, end: now + 180 * 60000, allDay: false, join: "", location: "Tasca do Chico"}];
            win.width = current.w; win.height = current.h;
            loader.sourceComponent = null; loader.sourceComponent = current.view;
            settle.restart();
        }
        Component.onCompleted: run()
        // Saved preferences can load after the first case starts, so apply the case again before the grab.
        Timer { id: settle; interval: 900; onTriggered: { Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!win.current.light, palette: 0, dynamicColors: false}); Opal.PhoneState.activity = {files: [], games: []}; grab.restart(); } }
        Timer { id: grab; interval: 1200; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
    }
}
