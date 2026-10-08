pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Slim pill bar shown when a physical keyboard is attached: suggestions, emoji, clipboard, show keyboard.
Rectangle {
    id: bar
    objectName: "dockedBar"
    required property var keyboard
    required property var engine
    radius: height / 2
    color: keyboard.specialColor
    border.width: 1; border.color: keyboard.outlineColor
    readonly property var candidates: {
        const list = engine.suggestions;
        return list.length >= 3 ? [list[1], list[0], list[2]] : list;
    }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 6; spacing: 2
        Row {
            id: chipRow
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
            readonly property real chipWidth: Math.max(60, (width - spacing * Math.max(0, bar.candidates.length - 1)) / Math.max(1, bar.candidates.length))
            Text {
                visible: bar.candidates.length === 0 || bar.keyboard.privateInput
                anchors.verticalCenter: parent.verticalCenter
                text: bar.keyboard.privateInput ? "Private input" : "Borealis"
                color: bar.keyboard.secondaryText; font.family: bar.keyboard.fontFamily; font.pixelSize: 14
            }
            Repeater {
                model: bar.keyboard.privateInput ? [] : bar.candidates
                Rectangle {
                    id: chip
                    required property string modelData
                    required property int index
                    readonly property bool best: bar.candidates.length >= 3 ? index === 1 : index === 0
                    width: chipRow.chipWidth; height: chipRow.height - 14; anchors.verticalCenter: parent.verticalCenter
                    radius: height / 2
                    color: best ? bar.keyboard.secondaryContainer : "transparent"
                    Text { anchors.centerIn: parent; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: chip.modelData; color: chip.best ? bar.keyboard.secondaryContainerInk : bar.keyboard.foreground; font.family: bar.keyboard.fontFamily; font.pixelSize: 15; font.weight: chip.best ? Font.DemiBold : Font.Normal }
                    TapHandler { onTapped: bar.keyboard.acceptSuggestion(chip.modelData) }
                }
            }
        }
        Key { keyboard: bar.keyboard; round: true; toolbar: true; icon: true; label: "mood"; value: "__dock-emoji"; description: "Emoji"; Layout.preferredWidth: 48; Layout.fillHeight: true }
        Key { keyboard: bar.keyboard; round: true; toolbar: true; icon: true; label: "content_paste"; value: "__dock-clipboard"; description: "Clipboard"; visible: !bar.keyboard.privateInput; Layout.preferredWidth: visible ? 48 : 0; Layout.fillHeight: true }
        Key { keyboard: bar.keyboard; round: true; icon: true; label: "keyboard"; value: "__dock-show"; description: "Show keyboard"; Layout.preferredWidth: 48; Layout.fillHeight: true; Layout.rightMargin: 2 }
    }
}
