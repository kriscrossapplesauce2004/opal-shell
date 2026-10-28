import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Displays detail sheet: brightness per external monitor over DDC/CI, then links to the display settings.
ColumnLayout {
    id: p
    property var backAction: () => { Hub.controlDetail = ""; }
    spacing: 12
    Component.onCompleted: Hub.command({action: "ddc", verb: "refresh"})
    RowLayout {
        Layout.fillWidth: true; spacing: 4
        MButton { icon: "back"; compact: true; implicitWidth: 40; implicitHeight: 40; tooltip: "Back"; onClicked: p.backAction() }
        MText { text: "Displays"; role: "headline"; Layout.fillWidth: true; Layout.leftMargin: 4 }
        MButton { icon: "refresh"; compact: true; implicitWidth: 40; implicitHeight: 40; ink: Theme.subtext; tooltip: "Look for displays again"; onClicked: Hub.command({action: "ddc", verb: "scan"}) }
    }
    MText {
        visible: !Hub.ddc.available; Layout.fillWidth: true; Layout.leftMargin: 6; wrapMode: Text.Wrap; role: "bodyS"; color: Theme.subtext
        text: "Install ddcutil to change the brightness of external monitors here."
    }
    Repeater {
        model: Hub.ddc.items
        Rectangle {
            required property var modelData
            Layout.fillWidth: true; implicitHeight: monitor.implicitHeight + 28; radius: 24; color: Theme.level(3)
            ColumnLayout {
                id: monitor
                x: 14; y: 14; width: parent.width - 28; spacing: 10
                ColumnLayout { spacing: 0
                    MText { text: modelData.model || "Display"; role: "titleS" }
                    MText { text: modelData.connector; role: "labelS"; color: Theme.subtext } }
                ExpressiveSlider {
                    visible: modelData.value >= 0; Layout.fillWidth: true; implicitHeight: 44; compact: true; trackHeight: 36; icon: "sun"; iconAtHandle: true
                    from: 0; to: modelData.max > 0 ? modelData.max : 100; value: Math.max(0, modelData.value)
                    // DDC is slow, so the monitor only hears the value when the drag ends.
                    onPressedChanged: if (!pressed) Hub.command({action: "ddc", verb: "set", bus: modelData.bus, value: Math.round(value * 100 / to)})
                    Accessible.name: "Brightness of " + (modelData.model || "display")
                }
                MText {
                    visible: modelData.value < 0; Layout.fillWidth: true; wrapMode: Text.Wrap; role: "bodyS"; color: Theme.subtext
                    text: "This display does not take brightness commands. Use its own buttons or remote."
                }
            }
        }
    }
    MText { visible: Hub.ddc.available && !Hub.ddc.items.length; Layout.fillWidth: true; Layout.leftMargin: 6; text: "Looking for displays…"; role: "bodyS"; color: Theme.subtext }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 2
        SettingRow { icon: "moon"; title: "Dark theme"; toggle: true; checked: !Theme.light; last: false; onActivated: Hub.set("light", !Theme.light) }
        SettingRow { icon: "screen_share"; title: "Arrange displays"; chevron: true; first: false; onActivated: Hub.openSettings("displays") }
    }
    Item { Layout.fillHeight: true }
}
