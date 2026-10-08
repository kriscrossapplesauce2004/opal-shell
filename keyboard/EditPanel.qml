import QtQuick
import QtQuick.Layouts

// Text editing: arrow pad around a Select toggle, line and word jumps, and edit actions.
Item {
    id: panel
    required property var keyboard
    ColumnLayout {
        anchors.fill: parent; spacing: 4
        PanelTitle { keyboard: panel.keyboard; title: "Text editing"; Layout.fillWidth: true; Layout.preferredHeight: 48 }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 3
                radius: 28; color: panel.keyboard.specialColor
                GridLayout {
                    anchors.fill: parent; anchors.margins: 6; columns: 3; rowSpacing: 0; columnSpacing: 0
                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                    Key { keyboard: panel.keyboard; big: true; icon: true; label: "keyboard_arrow_up"; description: "Up"; value: "Up"; repeating: true; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                    Key { keyboard: panel.keyboard; big: true; icon: true; label: "keyboard_arrow_left"; description: "Left"; value: "Left"; repeating: true; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
                    Key { keyboard: panel.keyboard; round: true; glyph: "select"; stacked: true; label: "Select"; description: "Select"; value: "__select"; toggled: panel.keyboard.selecting; latch: true; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1; Layout.margins: 6 }
                    Key { keyboard: panel.keyboard; big: true; icon: true; label: "keyboard_arrow_right"; description: "Right"; value: "Right"; repeating: true; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                    Key { keyboard: panel.keyboard; big: true; icon: true; label: "keyboard_arrow_down"; description: "Down"; value: "Down"; repeating: true; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1.25; Layout.maximumWidth: 150; spacing: 2
                Repeater {
                    model: [{g: "first_page", t: "Line start", v: "Home"}, {g: "last_page", t: "Line end", v: "End"}, {g: "keyboard_double_arrow_left", t: "Word ←", v: "WordLeft"}, {g: "keyboard_double_arrow_right", t: "Word →", v: "WordRight"}, {g: "select_all", t: "Select all", v: "Select all"}]
                    Key {
                        required property var modelData
                        keyboard: panel.keyboard; special: true; glyph: modelData.g; label: modelData.t; value: modelData.v; description: modelData.t
                        Layout.fillWidth: true; Layout.fillHeight: true
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 52; spacing: 0
            Repeater {
                model: [{g: "content_cut", t: "Cut"}, {g: "content_copy", t: "Copy"}, {g: "content_paste", t: "Paste"}, {g: "undo", t: "Undo"}, {g: "redo", t: "Redo"}]
                Key {
                    required property var modelData
                    keyboard: panel.keyboard; round: true; stacked: true; glyph: modelData.g; label: modelData.t; value: modelData.t; description: modelData.t
                    Layout.fillWidth: true; Layout.fillHeight: true
                }
            }
        }
    }
}
