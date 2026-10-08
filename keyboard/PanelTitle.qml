import QtQuick
import QtQuick.Layouts

// Title bar of a panel: keyboard button returns to the keys, title, settings.
Item {
    id: bar
    required property var keyboard
    property string title: ""
    property bool settingsButton: true
    implicitHeight: 48
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 2; anchors.rightMargin: 2; spacing: 10
        Key { keyboard: bar.keyboard; round: true; icon: true; label: "keyboard"; value: "__keys"; description: "Back to keys"; Layout.preferredWidth: 48; Layout.fillHeight: true; accent: true }
        Text { text: bar.title; Layout.fillWidth: true; color: bar.keyboard.foreground; font.family: bar.keyboard.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight }
        Key { visible: bar.settingsButton; keyboard: bar.keyboard; round: true; toolbar: true; icon: true; label: "tune"; value: "__settings"; description: "Keyboard settings"; Layout.preferredWidth: 48; Layout.fillHeight: true }
    }
}
