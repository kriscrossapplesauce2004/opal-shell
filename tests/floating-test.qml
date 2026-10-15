import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Renders the snap layouts card with no services.
ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        id: win
        width: 480; height: 300; visible: true; color: Opal.Theme.base
        Opal.SnapLayoutsCard { anchors.centerIn: parent }
        Timer { interval: 1200; running: true; onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/snap-layouts.png"); console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); }) }
    }
}
