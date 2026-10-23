import QtQuick
import QtQuick.Effects
// M3 Expressive floating toolbar: a pill of actions that floats over content. Items are {id, icon, text?, primary?, enabled?}.
Rectangle {
    id: bar
    property var items: []
    property bool vibrant: false
    property string kind: "panels"
    signal triggered(string id)
    implicitWidth: row.implicitWidth + 16; implicitHeight: 64
    radius: height / 2
    color: vibrant ? Theme.primaryContainer : Theme.fill(Theme.level(3), .96, kind)
    readonly property color ink: vibrant ? Theme.onContainer : Theme.text
    RectangularShadow { z: -1; visible: Theme.shadows; anchors.fill: parent; radius: bar.radius; offset.y: 6; blur: 22; color: Theme.alpha("#000000", Theme.light ? .16 : .4) }
    Row {
        id: row; anchors.centerIn: parent; spacing: 4
        Repeater {
            model: bar.items
            Rectangle {
                id: item
                required property var modelData
                readonly property bool hot: !!modelData.primary
                readonly property bool on: modelData.enabled !== false
                width: modelData.text ? label.implicitWidth + glyph.width + 36 : 48; height: 48
                // A primary action is a squarer filled button, the M3E toolbar FAB.
                radius: hot && !modelData.text ? 16 : 24
                color: hot ? Theme.primary : "transparent"
                opacity: on ? 1 : .38
                Rectangle { anchors.fill: parent; radius: parent.radius; color: item.hot ? Theme.onPrimary : bar.ink; opacity: press.pressed ? .12 : press.containsMouse ? .08 : 0 }
                Glyph { id: glyph; x: item.modelData.text ? 14 : (parent.width - width) / 2; anchors.verticalCenter: parent.verticalCenter; name: item.modelData.icon || ""; font.pixelSize: 22; color: item.hot ? Theme.onPrimary : bar.ink }
                MText { id: label; visible: !!item.modelData.text; x: glyph.x + glyph.width + 8; anchors.verticalCenter: parent.verticalCenter; text: item.modelData.text || ""; role: "label"; color: item.hot ? Theme.onPrimary : bar.ink }
                MouseArea { id: press; anchors.fill: parent; enabled: item.on; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.triggered(item.modelData.id) }
                Accessible.role: Accessible.Button; Accessible.name: item.modelData.text || item.modelData.id; Accessible.onPressAction: bar.triggered(item.modelData.id)
            }
        }
    }
}
