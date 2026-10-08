pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A titled list of choice rows, used by Languages and Settings.
Item {
    id: panel
    required property var keyboard
    property string title: ""
    // Each row is {label, hint, value, on}. The value goes to keyboard.dispatch.
    property var rows: []
    ColumnLayout {
        anchors.fill: parent; spacing: 4
        PanelTitle { keyboard: panel.keyboard; title: panel.title; settingsButton: false; Layout.fillWidth: true; Layout.preferredHeight: 48 }
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            columns: panel.rows.length > 4 ? 2 : 1; rowSpacing: 4; columnSpacing: 4
            Repeater {
                model: panel.rows
                Key {
                    required property var modelData
                    keyboard: panel.keyboard; special: !modelData.on; toggled: !!modelData.on; latch: !!modelData.on
                    glyph: modelData.on ? "check" : ""; label: modelData.label; value: modelData.value; description: modelData.label
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1
                }
            }
        }
    }
}
