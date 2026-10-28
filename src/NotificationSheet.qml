import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Desktop notification card from the Shelf's notification pill: grouped messages with replies, Do not disturb and Clear all.
Item {
    id: sheet
    readonly property real fitHeight: Math.min(720, col.implicitHeight + 32)
    Component.onCompleted: Notifier.centerOpen = true
    Component.onDestruction: Notifier.centerOpen = false
    ColumnLayout {
        id: col
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 4; spacing: 8
            MText { text: "Notifications"; role: "title"; Layout.fillWidth: true }
            MButton { icon: Hub.dnd ? "quiet" : "bell"; text: Hub.dnd ? "Do not disturb" : ""; compact: true; implicitHeight: 34; tonal: Hub.dnd
                tooltip: Hub.dnd ? "Turn off Do not disturb" : "Do not disturb"; onClicked: Hub.set("dnd", !Hub.dnd) }
            MButton { visible: Notifier.inbox.length > 0; text: "Clear all"; compact: true; implicitHeight: 34; ink: Theme.subtext; onClicked: Notifier.clear() }
        }
        SuggestionChips { Layout.fillWidth: true; Layout.leftMargin: 2 }
        Flickable {
            id: list
            visible: Notifier.inbox.length > 0
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredHeight: Math.min(560, groups.implicitHeight)
            contentHeight: groups.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            NotificationGroups { id: groups; width: list.width }
        }
        RowLayout {
            visible: Notifier.inbox.length === 0; Layout.fillWidth: true; Layout.leftMargin: 6; Layout.topMargin: 4; Layout.bottomMargin: 6; spacing: 12
            Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20; color: Theme.alpha(Theme.primary, .14)
                Glyph { anchors.centerIn: parent; name: Hub.dnd ? "do_not_disturb_on" : "done_all"; font.pixelSize: 20; color: Theme.primary } }
            ColumnLayout { spacing: 0; Layout.fillWidth: true
                MText { text: "All caught up"; role: "label"; font.weight: Font.DemiBold }
                MText { text: Hub.dnd ? "Do not disturb is on" : "New notifications show up here"; role: "labelS"; color: Theme.subtext } }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            MButton { text: "Notification settings"; compact: true; implicitHeight: 32; ink: Theme.primary; onClicked: Hub.openSettings("notifications") }
        }
    }
    ControllerFocus { anchors.fill: parent; root: sheet; priority: 5; onBack: Hub.close() }
}
