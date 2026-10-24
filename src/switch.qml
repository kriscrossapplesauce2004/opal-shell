import QtQuick
import Quickshell
import Quickshell.Io
// The switch assistant window, for people on other desktops. Run with OPAL_POLKIT=1 (no session backend) by tools/switch/opal-switch --gui.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    // Fonts the assistant fetched before opening, for computers without Opal's fonts yet.
    readonly property string fontDir: Quickshell.env("OPAL_SWITCH_FONTS") || ""
    FontLoader { source: fontDir ? "file://" + fontDir + "/symbols.ttf" : "" }
    FontLoader { source: fontDir ? "file://" + fontDir + "/sans.ttf" : "" }
    FloatingWindow {
        id: win
        title: "Switch to Opal"
        implicitWidth: 1120; implicitHeight: 760
        minimumSize: Qt.size(400, 600)
        color: Theme.base
        visible: true
        onVisibleChanged: if (!visible) content.close()
        SwitchContent {
            id: content
            anchors.fill: parent
            onSend: cmd => { if (engine.running) engine.write(JSON.stringify(cmd) + "\n"); }
            onQuit: Qt.quit()
        }
    }
    Process {
        id: engine
        command: ["python3", "-I", Quickshell.env("OPAL_SWITCH_ENGINE"), "serve"]
        running: true
        stdinEnabled: true
        onStarted: write(JSON.stringify({action: "detect"}) + "\n")
        stdout: SplitParser { onRead: line => { try { content.handle(JSON.parse(line)); } catch (error) { console.warn("Switch engine:", line); } } }
        onExited: (code, status) => {
            if (!content.busy) return;
            content.handle({event: "error", text: "The switch engine stopped"});
            content.handle({event: "done", ok: false});
        }
    }
}
