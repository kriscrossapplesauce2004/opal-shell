import QtQuick
// Stand-in for Quickshell PopupWindow: an Item that the host positions.
Item {
    id: root
    property var anchor: QtObject { property var window: null; property rect rect; property int edges: 0; property int gravity: 0 }
    property color color: "transparent"
}
