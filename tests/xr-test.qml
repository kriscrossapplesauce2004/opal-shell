import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders Luna spatial: real Opal surfaces as panels in space over the wallpaper, with the heads-up layer and the shelf as the dock. No services.
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
        width: 1920; height: 1080; visible: true; color: "#000000"
        property int step: 0
        property var cases: [
            {name: "xr-scene"},
            {name: "xr-scene-light", light: true},
            {name: "xr-scene-peach", palette: 2}
        ]
        Opal.SpatialScene {
            anchors.fill: parent
            environment: "file:///home/melissa/Pictures/Wallpapers/default.png"
            Opal.SpatialPanel {
                x: 130; y: 300; width: 440; height: 330; yaw: 26; depth: .06
                title: "Quick Settings"; icon: "tune"
                Opal.QuickTileDeck { anchors.fill: parent; anchors.margins: 20 }
            }
            Opal.SpatialPanel {
                x: 600; y: 200; width: 720; height: 620
                title: "Settings"; icon: "settings"
                Opal.Settings { anchors.fill: parent }
            }
            Opal.SpatialPanel {
                x: 1350; y: 300; width: 440; height: 330; yaw: -26; depth: .06
                title: "Live"; icon: "bolt"
                Column {
                    anchors.fill: parent; anchors.margins: 16; spacing: 12
                    // The player card reads MPRIS, which the fixture cannot fake, so only the other activities show.
                    Repeater { model: Opal.Activities.list.filter(a => a.kind !== "media"); Opal.ActivityCard { required property var modelData; width: 406; a: modelData } }
                }
            }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40; width: 1100; height: 64
                Opal.DesktopShelf { anchors.fill: parent }
            }
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, palette: c.palette || 0, dynamicColors: false, barStyle: "dock"});
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {battery: 73, charging: false, wifi: true, bluetooth: true, track: "Tidal Lines", artist: "Lumen", art: root.art, playing: true});
            Opal.Activities.fixture = [
                {id: "x:cc", external: "cc", kind: "agent", icon: "auto_awesome", title: "Send a message to Sam?", short: "Needs you", subtitle: "Claude wants to reply in Messages", code: "Running ten minutes late, save me a seat?", progress: -1, priority: 88, since: 1, until: 0,
                    controls: [{id: "x:deny", action: "deny", label: "Deny"}, {id: "x:allow", action: "allow", label: "Allow", primary: true}]},
                {id: "focus", kind: "focus", icon: "timer", title: "Pasta timer", short: "4:12", subtitle: "Ends at 19:46", progress: .7, priority: 60, since: 2, until: 0, controls: []},
                {id: "media", kind: "media", icon: "music", art: root.art, title: "Tidal Lines", short: "Tidal Lines", subtitle: "Lumen", progress: -1, priority: 50, since: 3, until: 0, playing: true,
                    controls: [{id: "media-previous", icon: "previous"}, {id: "media-pause", icon: "pause"}, {id: "media-next", icon: "skip"}]}
            ];
            Opal.Notifier.entries = [root.note("Messages", "chat", "Sam", "Running ten minutes late, save me a seat?", 0)];
            settle.restart();
        }
        Component.onCompleted: run()
        // Saved preferences can load after the first case starts, so apply the case again before the grab.
        Timer { id: settle; interval: 900; onTriggered: { const c = win.cases[win.step]; Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, palette: c.palette || 0, dynamicColors: false}); grab.restart(); } }
        Timer { id: grab; interval: 1000; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
    }
}
