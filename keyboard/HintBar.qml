import QtQuick

// Controller hint bar: button badges with what each one does.
Rectangle {
    id: bar
    objectName: "hintBar"
    required property var keyboard
    readonly property var hints: [{b: "A", t: "Type"}, {b: "B", t: "Delete"}, {b: "X", t: "Space"}, {b: "Y", t: "Shift"}, {b: "LT", t: "Symbols"}, {b: "RT", t: "Cursor"}, {b: "Start", t: "Done"}]
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 32
    radius: height / 2
    color: keyboard.specialColor
    Row {
        id: row
        anchors.centerIn: parent; spacing: 14
        Repeater {
            model: bar.hints
            Row {
                required property var modelData
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(20, badge.implicitWidth + 10); height: 20; radius: modelData.b.length > 1 ? 6 : 10
                    color: modelData.b.length > 1 ? bar.keyboard.keyColor : bar.keyboard.secondaryContainer
                    Text { id: badge; anchors.centerIn: parent; text: parent.parent.modelData.b; font.pixelSize: 11; font.weight: Font.Bold; color: bar.keyboard.foreground }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.t; font.family: bar.keyboard.fontFamily; font.pixelSize: 12; color: bar.keyboard.secondaryText }
            }
        }
    }
}
