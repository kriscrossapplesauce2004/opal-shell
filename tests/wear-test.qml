import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the Luna wear shell: each view on a 454 px round display, plus the face in another palette. No services.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property string art: "file://" + Quickshell.env("HOME") + "/Ocean.png"
    function note(app, icon, summary, body, ago) {
        return {notification: {appName: app, appIcon: icon, summary: summary, body: body, transient: false, actions: [], urgency: 1, id: Math.floor(Math.random() * 1e6), dismiss: () => {}, expire: () => {}},
                received: Date.now() - ago * 60000, read: false, popup: false};
    }
    Window {
        id: win
        width: 454; height: 454; visible: true; color: "#000000"
        property int step: 0
        property var cases: [
            {name: "wear-face", view: "face"},
            {name: "wear-notification", view: "notification"},
            {name: "wear-media", view: "media"},
            {name: "wear-live", view: "live"},
            {name: "wear-approve", view: "approve"},
            {name: "wear-tiles", view: "tiles"},
            {name: "wear-face-tide", view: "face", palette: 1},
            {name: "wear-face-small", view: "face", size: 396}
        ]
        Opal.WearShell { id: shell; width: win.width; height: win.height }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            width = c.size || 454; height = c.size || 454;
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: false, palette: c.palette || 0, dynamicColors: false, dnd: false});
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {battery: 73, charging: false, wifi: true});
            Opal.Activities.fixture = [
                {id: "x:cc", external: "cc", kind: "agent", icon: "auto_awesome", title: "Send a message to Sam?", short: "Needs you", subtitle: "Claude wants to reply in Messages", code: "Running ten minutes late, save me a seat?", progress: -1, priority: 88, since: 1, until: 0,
                    controls: [{id: "x:deny", action: "deny", label: "Deny"}, {id: "x:allow", action: "allow", label: "Allow", primary: true}]},
                {id: "focus", kind: "focus", icon: "timer", title: "Pasta timer", short: "4:12", subtitle: "Ends at 19:46", progress: .7, priority: 60, since: 2, until: 0, controls: []},
                {id: "n:9", nid: 9, kind: "transfer", icon: "download", title: "Saltmarsh S1E3", short: "62%", subtitle: "Downloading on phone", progress: .62, priority: 55, since: 1, until: 0, controls: []},
                {id: "media", kind: "media", icon: "music", art: root.art, title: "Tidal Lines", short: "Tidal Lines", subtitle: "Lumen", progress: -1, priority: 50, since: 3, until: 0, playing: true, controls: []}
            ];
            Opal.Notifier.entries = [root.note("Messages", "chat", "Sam", "Running ten minutes late, save me a seat?", 0), root.note("Calendar", "event", "Dinner at 20:00", "Tasca do Chico", 30)];
            shell.view = c.view;
            settle.restart();
        }
        Component.onCompleted: run()
        // Saved preferences can load after the first case starts, so apply the case again before the grab.
        Timer { id: settle; interval: 900; onTriggered: { const c = win.cases[win.step]; Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, palette: c.palette || 0, dynamicColors: false}); grab.restart(); } }
        Timer { id: grab; interval: 800; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
    }
}
