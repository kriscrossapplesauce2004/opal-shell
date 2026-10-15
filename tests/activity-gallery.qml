import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the real activity chips, cards and player with fixed activities. No services.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property var fixture: [
        {id: "x:claude", kind: "agent", icon: "terminal", title: "Claude Code needs you", short: "Needs you", subtitle: "~/opal · Bash", meta: "now", code: "$ git push origin overhaul-2026-10", progress: -1,
            controls: [{id: "open", icon: "open_in_new"}, {id: "deny", label: "Deny"}, {id: "allow", label: "Allow", primary: true}]},
        {id: "x:pacman", kind: "system", icon: "system_update", title: "Updating 42 packages", short: "42", subtitle: "pacman · mesa, qt6-base, linux-cachyos", progress: .61, progressText: "26 of 42 · about a minute left", controls: []},
        {id: "focus", kind: "focus", icon: "timer", title: "Focus", short: "18:20", subtitle: "Ends at 18:42", progress: .7, ring: true, ringText: "18:20", controls: [{id: "focus-add", label: "+5 min"}, {id: "focus-toggle", label: "Pause", primary: true}]},
        {id: "rec", kind: "recording", icon: "radio_button_checked", title: "Recording screen", short: "0:42", subtitle: "OBS Studio · 0:42", progress: -1, controls: [{id: "stop", icon: "stop", label: "Stop", primary: true}]},
        {id: "dl", kind: "transfer", icon: "download", appIcon: "firefox", title: "kicad-9.0.2.tar.zst", short: "66%", subtitle: "Firefox · Downloads", progress: .66, progressText: "340 of 512 MB", controls: [{id: "cancel", label: "Cancel"}]},
        {id: "bt", kind: "device", icon: "headphones", title: "Pixel Buds Pro", short: "80%", subtitle: "Connected", progress: -1, controls: []},
        {id: "op", kind: "system", icon: "content_copy", title: "Copying 3 files", short: "", subtitle: "Files · to ~/Backup", progress: -2, progressText: "Working…", controls: []}
    ]
    Window {
        id: win
        width: 900; height: 900; visible: true; color: Opal.Theme.base
        Column {
            x: 24; y: 24; spacing: 10
            Repeater { model: fixture; Opal.ActivityChip { required property var modelData; required property int index; a: modelData; more: index === 0 ? 2 : 0; selected: index === 1 } }
        }
        Column {
            x: 260; y: 24; width: 380; spacing: 12
            Repeater { model: fixture.slice(0, 4); Opal.ActivityCard { required property var modelData; width: 380; a: modelData } }
        }
        Column {
            x: 660; y: 24; width: 220; spacing: 12
            Repeater { model: fixture.slice(4); Opal.ActivityCard { required property var modelData; width: 220; a: modelData } }
        }
        Opal.MediaPlayerCard { x: 260; y: 660; width: 380 }
        Timer { interval: 2500; running: true; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/activity-gallery.png"); console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); }) }
    }
}
