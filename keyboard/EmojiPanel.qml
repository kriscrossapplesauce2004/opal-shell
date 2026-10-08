pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Emoji panel: search field, category tabs and a scrolling grid. The bundled table lives in EmojiData.js.
Item {
    id: panel
    required property var keyboard
    property var toneCell: null
    readonly property var emojiList: keyboard.emojiRows(keyboard.emojiPage)
    ColumnLayout {
        anchors.fill: parent; spacing: 4
        PanelTitle { keyboard: panel.keyboard; title: "Emoji"; Layout.fillWidth: true; Layout.preferredHeight: 48 }
        Rectangle {
            objectName: "emojiSearch"
            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 21
            color: panel.keyboard.keyColor
            Accessible.role: Accessible.Button
            Accessible.name: "Search emoji"
            Row {
                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; spacing: 14
                Glyph { name: "search"; font.pixelSize: 22; color: panel.keyboard.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Search emoji"; font.family: panel.keyboard.fontFamily; font.pixelSize: 15; color: panel.keyboard.secondaryText; anchors.verticalCenter: parent.verticalCenter }
            }
            TapHandler { onTapped: panel.keyboard.startEmojiSearch() }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 38; spacing: 0
            Repeater {
                model: panel.keyboard.emojiTabs
                Key {
                    required property var modelData
                    required property int index
                    keyboard: panel.keyboard; round: true; icon: true; label: modelData.icon; value: "__category" + index; description: modelData.label
                    toggled: panel.keyboard.emojiPage === index
                    Layout.fillWidth: true; Layout.fillHeight: true
                }
            }
        }
        Text {
            text: panel.keyboard.emojiTabs[panel.keyboard.emojiPage].label
            Layout.leftMargin: 8; color: panel.keyboard.primary; font.family: panel.keyboard.fontFamily; font.pixelSize: 12; font.weight: Font.Medium
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            GridView {
                id: grid
                anchors.fill: parent
                cellWidth: width / 8; cellHeight: 46
                model: panel.emojiList
                boundsBehavior: Flickable.StopAtBounds
                delegate: EmojiCell {
                    required property string modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    keyboard: panel.keyboard; emoji: modelData
                    onToneRequested: item => panel.toneCell = item
                }
            }
            Text {
                visible: panel.emojiList.length === 0
                anchors.centerIn: parent
                text: "Emoji you use appear here"
                color: panel.keyboard.secondaryText; font.family: panel.keyboard.fontFamily; font.pixelSize: 14
            }
            // Skin tone picker pill above the held emoji.
            Rectangle {
                id: tones
                visible: panel.toneCell !== null
                readonly property var spot: panel.toneCell ? panel.toneCell.mapToItem(tones.parent, 0, 0) : Qt.point(0, 0)
                height: 56; radius: 28; width: Math.min(parent.width - 8, 6 * 46 + 12)
                x: Math.max(4, Math.min(parent.width - width - 4, spot.x + (panel.toneCell ? panel.toneCell.width / 2 : 0) - width / 2))
                y: Math.max(0, spot.y - height + 4)
                color: panel.keyboard.specialColor; border.width: 1; border.color: panel.keyboard.alpha(panel.keyboard.foreground, 0.2)
                z: 10
                Row {
                    anchors.fill: parent; anchors.margins: 6
                    Repeater {
                        model: panel.toneCell ? panel.toneCell.alternatives : []
                        Item {
                            required property string modelData
                            width: (tones.width - 12) / 6; height: parent.height
                            Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 26; font.family: "Noto Color Emoji" }
                            TapHandler { onTapped: { panel.keyboard.dispatch(parent.modelData); panel.toneCell = null; } }
                        }
                    }
                }
            }
            TapHandler { enabled: panel.toneCell !== null; onTapped: panel.toneCell = null; gesturePolicy: TapHandler.ReleaseWithinBounds }
        }
    }
    Connections { target: panel.keyboard; function onPanelChanged() { panel.toneCell = null; } function onEmojiPageChanged() { panel.toneCell = null; } }
}
