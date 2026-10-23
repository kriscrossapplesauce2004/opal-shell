import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the AI-free mode: the setup AI step both ways, the hello chip, tips and ready without AI, and Settings › AI & assistant.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 1600; height: 960; visible: true; color: Opal.Theme.base
        property int step: 0
        readonly property var cases: [
            {name: "ai-oobe-hello", view: "oobe", oobe: 0, ai: true},
            {name: "ai-oobe-hello-off", view: "oobe", oobe: 0, ai: false},
            {name: "ai-oobe-step-on", view: "oobe", oobe: 5, ai: true},
            {name: "ai-oobe-step-off", view: "oobe", oobe: 5, ai: false},
            {name: "ai-oobe-step-off-phone", view: "oobe", oobe: 5, ai: false, w: 412, h: 915},
            {name: "ai-oobe-tips-off", view: "oobe", oobe: 6, ai: false},
            {name: "ai-oobe-ready-off", view: "oobe", oobe: 7, ai: false},
            {name: "ai-settings-on", view: "settings", ai: true},
            {name: "ai-settings-off", view: "settings", ai: false},
            {name: "ai-settings-off-light", view: "settings", ai: false, light: true}]
        function fixtures() {
            const c = cases[step];
            Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: !!c.light, onboarded: true, mode: "desktop", look: "mixed", aiFeatures: c.ai});
            Opal.Hub.aiStatus = {claude: true, mcp: c.ai, hooks: false, enabled: c.ai};
            Opal.Hub.status = Object.assign({}, Opal.Hub.status, {network: "Home Wi-Fi"});
        }
        function run() {
            if (step >= cases.length) { console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
            const c = cases[step];
            width = c.w || 1600; height = c.h || 960;
            fixtures();
            loader.sourceComponent = null;
            loader.sourceComponent = c.view === "oobe" ? oobeView : settingsView;
            settle.restart();
        }
        Timer { id: settle; interval: 900; onTriggered: { win.fixtures(); const c = win.cases[win.step]; if (c.view === "oobe" && loader.item) loader.item.step = c.oobe; grab.restart(); } }
        Timer { id: grab; interval: 1300; onTriggered: { win.fixtures(); win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/" + win.cases[win.step].name + ".png"); win.step++; win.run(); }); } }
        Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.run(); else restart(); } }
        Loader { id: loader; anchors.fill: parent }
        Component { id: oobeView; Opal.OobeContent {} }
        Component { id: settingsView; Item {
            Opal.Surface { anchors.centerIn: parent; width: 760; height: 860; radius: 36; kind: "panels"
                Opal.SettingsAI { anchors.fill: parent; anchors.margins: 24 } } } }
    }
}
