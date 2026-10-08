pragma ComponentBehavior: Bound
import QtQuick

// One scrolling row of search results, shown in place of the number row.
Item {
    id: strip
    objectName: "emojiResults"
    required property var keyboard
    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal; clip: true; boundsBehavior: Flickable.StopAtBounds
        model: strip.keyboard.emojiResults
        delegate: EmojiCell {
            required property string modelData
            width: Math.max(44, list.height); height: list.height
            keyboard: strip.keyboard; emoji: modelData; fontSize: 24
        }
    }
    Text {
        visible: strip.keyboard.emojiResults.length === 0
        anchors.centerIn: parent
        text: strip.keyboard.emojiQuery === "" ? "Type a word, like smile or fire" : "No emoji found"
        color: strip.keyboard.secondaryText; font.family: strip.keyboard.fontFamily; font.pixelSize: 14
    }
}
