import QtQuick
// Stand-in for Quickshell PanelWindow: a plain Item in the host scene.
Item {
    id: root
    property var screen: null
    property color color: "transparent"
    property int exclusiveZone: 0
    property var mask: null
    property var margins: ({ top: 0, bottom: 0, left: 0, right: 0 })
}
