pragma Singleton
import QtQuick
// Stand-in for the Quickshell singleton: screens come from the host, the rest is inert.
QtObject {
    id: qs
    readonly property var screens: Qt.application.screens
    property string shellDir: ""
    property string cacheDir: ""
    property var watchFiles: false
    function iconPath(name, fallback) { return "" }
    function env(name) { return "" }
    function execDetached(command) { console.warn("Luna shim: execDetached is inert", JSON.stringify(command)) }
}
