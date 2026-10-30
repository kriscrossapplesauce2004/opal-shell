import QtQuick
// Stand-in for Quickshell Region: stores a rectangle and has no effect in the host.
QtObject {
    property real x: 0
    property real y: 0
    property real width: 0
    property real height: 0
    property var item: null
    property int intersection: 0
}
