pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Container transform: the apps button surface grows into this sheet of tools.
Rectangle {
    id: sheet
    objectName: "toolsSheet"
    required property var keyboard
    // Morph progress from 0 (the button) to 1 (the full sheet).
    property real progress: 0
    // Button rectangle and full rectangle, both in deck coordinates.
    property rect origin: Qt.rect(0, 0, 48, 48)
    property rect target: Qt.rect(0, 0, 100, 100)
    readonly property real content: Math.max(0, Math.min(1, (progress - 0.4) / 0.6))
    visible: progress > 0.001
    x: origin.x + (target.x - origin.x) * progress
    y: origin.y + (target.y - origin.y) * progress
    width: origin.width + (target.width - origin.width) * progress
    height: origin.height + (target.height - origin.height) * progress
    radius: (origin.height / 2) + (28 - origin.height / 2) * progress
    color: keyboard.specialColor
    clip: true
    readonly property var tools: [
        {glyph: "content_paste", label: "Clipboard", value: "__tool-clipboard", badge: keyboard.clipCount > 0 ? String(keyboard.clipCount) : "", off: keyboard.privateInput},
        {glyph: "mood", label: "Emoji", value: "__tool-emoji"},
        {glyph: "text_select_move_forward_character", label: "Text editing", value: "__tool-edit"},
        {glyph: "touchpad_mouse", label: "Trackpad", value: "__tool-trackpad"},
        {glyph: "terminal", label: "Terminal keys", value: "__tool-terminal", on: keyboard.terminalMode},
        {glyph: "back_hand", label: "One-handed", value: "__tool-hand", on: keyboard.handed === 1 || keyboard.handed === 2},
        {glyph: "picture_in_picture", label: "Floating", value: "__tool-float", on: keyboard.floating, off: !keyboard.canFloat},
        {glyph: "height", label: "Resize", value: "__tool-resize"},
        {glyph: "language", label: "Languages", value: "__tool-languages"},
        {glyph: "special_character", label: "Symbols", value: "__tool-symbols", on: keyboard.mode === "symbols"},
        {glyph: "palette", label: "Theme", value: "__tool-theme", on: keyboard.keyStyle === "borderless"},
        {glyph: "settings", label: "Settings", value: "__tool-settings"}
    ]
    Item {
        width: sheet.target.width; height: sheet.target.height
        opacity: sheet.content
        visible: opacity > 0.01
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 4
            PanelTitle { keyboard: sheet.keyboard; title: "Tools"; Layout.fillWidth: true; Layout.preferredHeight: 48 }
            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                columns: 4; rowSpacing: 4; columnSpacing: 4
                Repeater {
                    model: sheet.tools
                    Key {
                        required property var modelData
                        keyboard: sheet.keyboard; tile: true; icon: true
                        label: modelData.glyph; description: modelData.label; value: modelData.value
                        badge: modelData.badge || ""
                        toggled: !!modelData.on
                        enabled: !modelData.off
                        opacity: enabled ? 1 : 0.38
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
                    }
                }
            }
        }
    }
}
