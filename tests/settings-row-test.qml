import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Every toggle row of the given Settings pages, through the click analogue, asserting
// the row's OWN checked (what the user sees) before and after the bridge echo.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 980; height: 800; visible: true; color: "#000"
        property int failures: 0
        property var rows: []
        property var seen: ({})
        readonly property var sections: ["look", "home", "sound", "notifications", "apps", "accessibility"]
        property int sIdx: 0

        Item {
            anchors.fill: parent
            Opal.Surface {
                anchors.fill: parent
                Opal.Settings { id: settings; anchors.fill: parent }
            }
        }

        Timer { id: step; interval: 700; onTriggered: win.openNext() }
        Timer { id: click; interval: 300; onTriggered: win.judgeClick() }
        Timer { id: echo; interval: 1300; onTriggered: win.judgeEcho() }
        Timer { interval: 600; running: true; onTriggered: { if (Opal.Hub.preferencesLoaded) win.openNext(); else restart(); } }

        function openNext() {
            if (sIdx >= sections.length) { console.log("ROW_LENS_COMPLETE", JSON.stringify({failures: failures})); Qt.quit(); return; }
            Opal.Hub.openSettings(sections[sIdx]);
            rows = []; collect(settings, rows);
            console.log("PAGE", sections[sIdx], "rows:", rows.map(r => r.title).join(" § ") || "(none)");
            idx = 0;
            pace.restart();
        }

        Timer { id: pace; interval: 200; onTriggered: win.step() }

        property int idx: 0

        function collect(node, out) {
            if (!node) return;
            if (node.toggle === true) { if (!seen[node.title]) seen[node.title] = true; out.push(node); return; }
            // Walk visual children only once: child Items are in both children and data.
            const list = node.children;
            for (let i = 0; i < list.length; i++) collect(list[i], out);
        }

        property var rowAt: null
        property var lens: ({})

        function step() {
            if (idx >= rows.length) { sIdx++; step.restart(); return; }
            rowAt = rows[idx];
            lens[rowAt.title] = { before: !!rowAt.checked };
            rowAt.activated();
            click.restart();
        }

        function judgeClick() {
            const Lens = lens[rowAt.title];
            Lens.expected = !Lens.before;
            if (!!rowAt.checked !== Lens.expected) { failures++; console.log("LENS_REVERT_IMMEDIATE", win.sections[sIdx], rowAt.title); }
            else console.log("LENS_OK_CLICK", win.sections[sIdx], rowAt.title);
            echo.restart();
        }

        function judgeEcho() {
            const Lens = lens[rowAt.title];
            if (!!rowAt.checked !== Lens.expected) { failures++; console.log("LENS_REVERT_AFTER_ECHO", win.sections[sIdx], rowAt.title); }
            else {
                console.log("LENS_OK_ECHO", win.sections[sIdx], rowAt.title);
                Lens.after = true;
            }
            idx++;
            pace.restart();
        }
    }
}
