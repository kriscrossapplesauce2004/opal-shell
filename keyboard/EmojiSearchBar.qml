import QtQuick
import QtQuick.Layouts

// Search field that replaces the suggestion bar while emoji search is open.
Item {
    id: bar
    objectName: "emojiSearchBar"
    required property var keyboard
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 6
        Key { keyboard: bar.keyboard; round: true; icon: true; accent: true; label: "arrow_back"; value: "__searchdone"; description: "Close search"; Layout.preferredWidth: 48; Layout.fillHeight: true }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.topMargin: 3; Layout.bottomMargin: 3
            radius: height / 2; color: bar.keyboard.keyColor
            Row {
                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; spacing: 10
                Glyph { name: "search"; font.pixelSize: 20; color: bar.keyboard.secondaryText; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    objectName: "emojiQuery"
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.keyboard.emojiQuery !== "" ? bar.keyboard.emojiQuery : "Search emoji"
                    color: bar.keyboard.emojiQuery !== "" ? bar.keyboard.foreground : bar.keyboard.secondaryText
                    font.family: bar.keyboard.fontFamily; font.pixelSize: 16
                }
                Rectangle { width: 2; height: 20; radius: 1; color: bar.keyboard.primary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
