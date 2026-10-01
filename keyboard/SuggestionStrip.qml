pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: strip
    required property var keyboard
    required property var engine
    implicitHeight: 40
    visible: keyboard.suggestionVisible
    Row {
        anchors.centerIn: parent
        height: parent.height
        spacing: 6
        property real candidateWidth: (strip.width - 16 - spacing * Math.max(0, strip.engine.suggestions.length - 1)) / Math.max(1, strip.engine.suggestions.length)
        width: Math.min(strip.width - 16, strip.engine.suggestions.length * candidateWidth + Math.max(0, strip.engine.suggestions.length - 1) * spacing)
        Repeater {
            model: strip.engine.suggestions
            Rectangle {
                id: chip
                required property string modelData
                required property int index
                width: parent.candidateWidth; height: parent.height - 6; anchors.verticalCenter: parent.verticalCenter
                radius: 17
                color: "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: modelData
                Accessible.onPressAction: strip.keyboard.acceptSuggestion(modelData)
                Rectangle { visible: chip.index > 0; width: 1; height: 18; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: strip.keyboard.outlineColor }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: chip.modelData
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    color: chip.index === 0 ? strip.keyboard.primary : strip.keyboard.foreground
                    font.family: strip.keyboard.fontFamily
                    font.pixelSize: 15
                    font.weight: chip.index === 0 ? Font.DemiBold : Font.Medium
                }
                Rectangle { anchors.fill: parent; radius: parent.radius; color: strip.keyboard.foreground; opacity: suggestionTap.pressed ? 0.10 : 0 }
                TapHandler { id: suggestionTap; onTapped: strip.keyboard.acceptSuggestion(chip.modelData) }
            }
        }
    }
}
