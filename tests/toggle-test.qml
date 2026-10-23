import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Toggle stickiness: flip rows the way the row click does (SettingRow.activated()),
// then confirm (1) the QML binding survives, (2) the bridge echo does not revert it.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 900; height: 700; visible: true; color: "#000"
        property var plan: [
            {key: "taskbarAutoHide"},
            {key: "light"},
            {key: "dnd"},
            {key: "desktopWidgets"}
        ]
        property int step: 0
        property int phase: 0 // 0 = click, 1 = waiting for the echo
        property var flips: ({})
        property bool orig: false

        Column {
            x: 20; y: 20; width: 560
            Repeater {
                id: rows
                model: win.plan
                Opal.SettingToggle {
                    required property var modelData
                    required property int index
                    title: modelData.key
                    checked: !!Opal.Hub.prefs[modelData.key]
                    onToggled: Opal.Hub.set(modelData.key, !checked)
                }
            }
        }

        Timer { id: echoWait; interval: 1200; onTriggered: win.judge() }

        function run() {
            if (step >= plan.length) { console.log("TOGGLE_TESTS_COMPLETE", JSON.stringify({flips: flips, prefs: Opal.Hub.prefs})); Qt.quit(); return; }
            phase = 0;
            // The row's MouseArea calls activated(); stand-in for a real click.
            const row = rows.itemAt(step); const before = !!Opal.Hub.prefs[plan[step].key];
            win.orig = before;
            row.activated();
            echoWait.restart();
        }

        function judge() {
            const key = plan[step].key;
            const now = !!Opal.Hub.prefs[key];
            if (phase === 0) {
                flips[key] = (now !== orig);
                phase = 1; echoWait.restart(); return;
            }
            // After the bridge echo the flip must stay.
            if (now === orig) console.log("TOGGLE_REVERTED", key);
            else console.log("TOGGLE_OK", key);
            step++; run();
        }
        Timer { interval: 400; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.run(); else restart(); } }
    }
}
