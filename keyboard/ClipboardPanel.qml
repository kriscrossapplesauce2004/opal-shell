pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Clipboard panel: Opal clipboard history as cards, pinned first. Read-only.
Item {
    id: panel
    objectName: "clipboardPanel"
    required property var keyboard
    readonly property var items: keyboard.clipItems
    ColumnLayout {
        anchors.fill: parent; spacing: 4
        PanelTitle { keyboard: panel.keyboard; title: "Clipboard"; Layout.fillWidth: true; Layout.preferredHeight: 48 }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            GridView {
                id: grid
                objectName: "clipGrid"
                anchors.fill: parent
                cellWidth: width / 2; cellHeight: 88
                model: panel.items
                boundsBehavior: Flickable.StopAtBounds
                delegate: ClipCard {
                    required property var modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    keyboard: panel.keyboard; entry: modelData
                }
            }
            Column {
                objectName: "clipEmpty"
                visible: panel.items.length === 0
                anchors.centerIn: parent; spacing: 6; width: parent.width - 32
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: "content_paste_off"; font.pixelSize: 36; color: panel.keyboard.secondaryText }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: panel.keyboard.clipAvailable ? "Nothing copied yet" : "Clipboard history is unavailable"
                    color: panel.keyboard.foreground; font.family: panel.keyboard.fontFamily; font.pixelSize: 16; font.weight: Font.Medium
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: panel.keyboard.clipAvailable ? "Copied text and images from Opal appear here." : "It needs the Opal shell to be running."
                    color: panel.keyboard.secondaryText; font.family: panel.keyboard.fontFamily; font.pixelSize: 12
                }
            }
        }
    }
}
