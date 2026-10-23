import QtQuick
import QtQuick.Layouts
// Android page: the app store and Android setup or management, one tab each.
Item {
    id: hub
    property bool phone: false
    readonly property bool ready: Hub.waydroid.installed && Hub.waydroid.initialized
    focus: true
    ColumnLayout {
        anchors.fill: parent; anchors.margins: hub.phone ? 16 : 24; spacing: 16
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Rectangle { Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 16; color: Theme.primaryContainer
                Glyph { anchors.centerIn: parent; name: "android"; color: Theme.onContainer; font.pixelSize: 26 } }
            MText { text: "Android"; role: "headline"; Layout.fillWidth: true }
            SegmentedButtons {
                Layout.preferredWidth: hub.phone ? 210 : 280; buttonHeight: 40
                options: [{value: "store", label: "Apps", icon: "storefront"}, {value: "setup", label: hub.ready ? "Manage" : "Set up", icon: hub.ready ? "tune" : "download"}]
                current: Hub.androidView
                onPicked: value => Hub.androidView = value
            }
            MButton { icon: "close"; tonal: true; onClicked: Hub.close() }
        }
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            sourceComponent: Hub.androidView === "setup" ? setupView : storeView
        }
    }
    Component { id: storeView; AndroidStore { onOpenSetup: Hub.androidView = "setup" } }
    Component { id: setupView; WaydroidSetup { onOpenStore: Hub.androidView = "store" } }
}
