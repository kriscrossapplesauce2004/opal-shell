pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Top bar: tools button, suggestion chips (or terminal shortcuts), and the hide button.
Item {
    id: strip
    required property var keyboard
    required property var engine
    implicitHeight: 40
    readonly property var toolsButton: tools
    // Best candidate sits in the middle, as in the design.
    readonly property var candidates: {
        const list = strip.engine.suggestions;
        return list.length >= 3 ? [list[1], list[0], list[2]] : list;
    }
    readonly property var chips: keyboard.terminalMode ? [{label: "Paste", action: "__paste"}, {label: "Ctrl C", action: "__ctrlc"}, {label: "Tab", action: "Tab"}]
        : keyboard.suggestionVisible ? candidates.map(word => ({label: word, action: word})) : []
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 4
        Key { id: tools; keyboard: strip.keyboard; round: true; icon: true; label: "apps"; value: "__tools"; description: "Tools"; Layout.preferredWidth: 48; Layout.fillHeight: true; toggled: strip.keyboard.panel === "menu" }
        Row {
            id: chipRow
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 6
            readonly property real chipWidth: Math.max(60, (width - spacing * Math.max(0, strip.chips.length - 1)) / Math.max(1, strip.chips.length))
            Repeater {
                model: strip.chips
                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool primaryChip: strip.keyboard.terminalMode ? modelData.action === "__ctrlc" : strip.chips.length >= 3 ? index === 1 : index === 0
                    readonly property bool selected: strip.keyboard.suggestionFocus === index && strip.keyboard.controllerActive
                    objectName: "suggestion-" + index
                    width: chipRow.chipWidth; height: chipRow.height - 6; anchors.verticalCenter: parent.verticalCenter
                    radius: height / 2
                    color: selected ? strip.keyboard.primary : primaryChip ? strip.keyboard.secondaryContainer : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    Accessible.onPressAction: strip.keyboard.chipAction(modelData.action)
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Rectangle {
                            visible: strip.keyboard.controllerActive && (chip.index === 0 || chip.index === strip.chips.length - 1) && strip.chips.length > 1
                            width: 34; height: 22; radius: 7; anchors.verticalCenter: parent.verticalCenter
                            color: strip.keyboard.keyColor
                            Text { anchors.centerIn: parent; text: chip.index === 0 ? "LB" : "RB"; font.pixelSize: 11; font.weight: Font.Bold; color: strip.keyboard.foreground }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, chip.width - 24)
                            text: chip.modelData.label
                            elide: Text.ElideRight
                            color: chip.selected ? strip.keyboard.primaryInk : chip.primaryChip ? strip.keyboard.secondaryContainerInk : strip.keyboard.foreground
                            font.family: strip.keyboard.fontFamily
                            font.pixelSize: strip.keyboard.controllerActive ? 18 : 16
                            font.weight: chip.primaryChip ? Font.DemiBold : Font.Normal
                        }
                    }
                    Rectangle { anchors.fill: parent; radius: parent.radius; color: strip.keyboard.foreground; opacity: chipTap.pressed ? 0.10 : 0 }
                    TapHandler { id: chipTap; onTapped: strip.keyboard.chipAction(chip.modelData.action) }
                }
            }
        }
        Key { keyboard: strip.keyboard; round: true; icon: true; label: "keyboard_hide"; value: "__hide"; description: "Hide keyboard"; Layout.preferredWidth: 48; Layout.fillHeight: true }
    }
}
