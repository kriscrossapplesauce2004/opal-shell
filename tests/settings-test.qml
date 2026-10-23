import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the real Settings at desktop, small tablet, phone and console sizes, with the Look page, search and the Material look. No services.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 1120; height: 780; visible: true; color: "#000"
        property int step: 0
        property var cases: [
            {name: "set-01-desktop-home", w: 1120, h: 780, section: ""},
            {name: "set-02-desktop-style", w: 1120, h: 780, section: "style"},
            {name: "set-03-desktop-look", w: 1120, h: 780, section: "look"},
            {name: "set-04-desktop-search", w: 1120, h: 780, section: "accessibility", query: "motion", found: "Reduce motion"},
            {name: "set-05-desktop-material", w: 1120, h: 780, section: "power", look: "material"},
            {name: "set-06-desktop-apps", w: 1120, h: 780, section: "apps"},
            {name: "set-07-small-tablet", w: 800, h: 1100, section: "home", mode: "phone"},
            {name: "set-08-phone-list", w: 412, h: 915, section: "", mode: "phone"},
            {name: "set-09-phone-page", w: 412, h: 915, section: "sound", mode: "phone"},
            {name: "set-10-console", w: 1280, h: 800, section: "games", mode: "console"},
            {name: "set-11-desktop-light", w: 1120, h: 780, section: "look", light: true, look: "mixed"}
        ]
        Loader { id: loader; anchors.fill: parent }
        Component {
            id: view
            Item {
                property alias settingsItem: settings
                Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/Ocean.png"; fillMode: Image.PreserveAspectCrop }
                Opal.Surface { anchors.fill: parent; radius: win.width < 900 ? 0 : 36; translucency: Opal.Hub.prefs.glass
                    Opal.Settings { id: settings; anchors.fill: parent }
                }
            }
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            width = c.w; height = c.h;
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {mode: c.mode || "desktop", light: !!c.light, look: c.look || "glass", lookSurfaces: {}, glass: .72, palette: 1, dynamicColors: false, wallpaperPath: "file://" + Quickshell.env("HOME") + "/Ocean.png"});
            Opal.Hub.settingsSection = c.section;
            loader.sourceComponent = null; loader.sourceComponent = view;
            if (c.query) Qt.callLater(() => { loader.item.settingsItem.query = c.query; Opal.Hub.findSetting(c.section, c.found); });
            grab.restart();
        }
        Timer { id: grab; interval: 1600; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }) }
        Component.onCompleted: { const only = Quickshell.env("OPAL_CASE"); if (only) cases = cases.filter(c => c.name.indexOf(only) >= 0); Qt.callLater(run); }
    }
}
