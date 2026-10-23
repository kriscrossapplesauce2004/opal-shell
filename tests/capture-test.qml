import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders Capture Studio over a fixture frame (empty, selected, window hover, video, colour) and the markup editor with marks.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 1600; height: 900; visible: true; color: "black"
        property int step: 0
        readonly property string frame: Quickshell.env("HOME") + "/Ocean.png"
        readonly property var fixtureWindows: [
            {title: "Opal — GitHub", className: "google-chrome", workspace: 1, address: "w1", at: [0, 0], size: [800, 900], focus: 1},
            {title: "~/opal", className: "kitty", workspace: 1, address: "w2", at: [800, 0], size: [800, 450], focus: 0},
            {title: "Steam", className: "steam", workspace: 1, address: "w3", at: [800, 450], size: [800, 450], focus: 2}]
        readonly property var cases: [
            {name: "studio-region", view: "studio", mx: 640, my: 360},
            {name: "studio-selected", view: "studio", sel: [420, 260, 640, 360]},
            {name: "studio-window", view: "studio", mode: "window", mx: 1100, my: 200},
            {name: "studio-video", view: "studio", video: true, sel: [200, 520, 520, 300], delay: 3},
            {name: "studio-color", view: "studio", mode: "color", mx: 900, my: 500},
            {name: "studio-light", view: "studio", sel: [420, 260, 640, 360], light: true},
            {name: "markup", view: "markup"},
            {name: "markup-light", view: "markup", light: true}]
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, look: "mixed"});
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {hypr: true, workspace: 1, windows: fixtureWindows, monitors: [{name: "", x: 0, y: 0, workspace: 1}]});
            Opal.Hub.compositorActive = true; Opal.Hub.compositorWindows = fixtureWindows;
            Opal.Hub.captureFrozen = frame;
            loader.sourceComponent = null;
            loader.sourceComponent = c.view === "studio" ? studioView : markupView;
            settle.restart();
        }
        Timer { id: settle; interval: 700; onTriggered: {
            const c = win.cases[win.step], it = loader.item;
            if (c.view === "studio") {
                if (c.mode) it.pickMode(c.mode);
                if (c.video) it.video = true;
                if (c.delay) it.delay = c.delay;
                if (c.sel) it.setSel(c.sel[0], c.sel[1], c.sel[2], c.sel[3]);
                it.mx = c.mx === undefined ? -1000 : c.mx; it.my = c.my === undefined ? -1000 : c.my;
            } else {
                it.shapes = [
                    {t: "box", color: "#FF4D4F", size: 6, x: 120, y: 90, w: 300, h: 160},
                    {t: "arrow", color: "#FFC53D", size: 6, x1: 520, y1: 330, x2: 420, y2: 240},
                    {t: "highlight", color: "#52C41A", size: 6, pts: [60, 300, 160, 302, 260, 304]},
                    {t: "pen", color: "#4096FF", size: 6, pts: [380, 60, 400, 40, 430, 70, 460, 40, 490, 70]},
                    {t: "text", color: "#FFFFFF", size: 32, x: 130, y: 100, text: "Look here"},
                    {t: "pix", x: 30, y: 30, w: 120, h: 50}];
                it.redo = [{t: "pen", pts: []}];
            }
            grab.restart();
        } }
        Timer { id: grab; interval: 900; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
        Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.run(); else restart(); } }
        Loader { id: loader; anchors.fill: parent }
        Component { id: studioView; Opal.CaptureStudio {} }
        Component { id: markupView; Opal.CaptureMarkup { path: win.frame } }
    }
}
