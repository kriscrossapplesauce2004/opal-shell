import QtQuick
import QtQuick.Layouts

// One home widget by kind. The same widgets fill the phone pages, the tablet row and the desktop canvas.
Item {
    id: hw
    property string kind: "glance"
    // In edit mode an empty live widget keeps a placeholder so the user can see and move it.
    property bool editing: false
    readonly property var live: Activities.list.find(a => a.kind !== "media") || null
    readonly property bool empty: kind === "live" && live === null || kind === "photos" && !HomeData.photo
    Loader {
        anchors.fill: parent
        active: !hw.empty || hw.editing
        sourceComponent: hw.empty ? placeholder : hw.kind === "glance" ? glanceView : hw.kind === "media" ? mediaView : hw.kind === "photos" ? photoView
            : hw.kind === "devices" ? devicesView : hw.kind === "clock" ? clockView : hw.kind === "live" ? liveView : glanceView
    }
    Component { id: glanceView; Item { GlanceWidget { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; big: Math.max(20, Math.min(32, hw.height * .3)) } } }
    Component { id: mediaView; MediaPlayerCard { small: hw.height < 180 } }
    Component { id: liveView; ActivityCard { a: hw.live || ({}); onOpened: Activities.open(hw.live, null) } }
    Component {
        id: photoView
        Item {
            RoundedImage { anchors.fill: parent; radius: 28; source: HomeData.photo ? "file://" + HomeData.photo.path : ""; decodeSize: Qt.size(hw.width * 2, hw.height * 2) }
            Rectangle {
                anchors.fill: parent; radius: 28
                gradient: Gradient { GradientStop { position: .55; color: "transparent" } GradientStop { position: 1; color: Theme.alpha("#000000", .55) } }
            }
            Column {
                x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; spacing: 0
                MText { text: HomeData.photo ? HomeData.photo.caption : ""; role: "titleS"; color: "#ffffff" }
                MText { text: HomeData.photo ? HomeData.photo.detail : ""; role: "labelS"; color: Theme.alpha("#ffffff", .8) }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (HomeData.photo) Hub.command({action: "open-path", path: HomeData.photo.path}) }
            Accessible.role: Accessible.Button
            Accessible.name: "Photo memory, " + (HomeData.photo ? HomeData.photo.caption : "")
        }
    }
    Component {
        id: devicesView
        Rectangle {
            id: dw
            radius: 28; color: Theme.alpha(Theme.level(2), .94)
            readonly property var items: HomeData.devices.slice(0, 3).map(d => ({icon: d.icon, label: d.percent + "%", value: d.percent / 100, name: d.name}))
                .concat(HomeData.updates > 0 ? [{icon: "system_update", label: String(HomeData.updates), value: -1, name: HomeData.updates + " updates"}] : [])
                .concat(Hub.status.battery >= 0 && HomeData.devices.length < 3 ? [{icon: Hub.status.charging ? "battery_charging_full" : "battery_full", label: Hub.status.battery + "%", value: Hub.status.battery / 100, name: "This device"}] : [])
            Grid {
                anchors.centerIn: parent; columns: 2; rowSpacing: 12; columnSpacing: 20
                visible: dw.items.length > 0
                Repeater {
                    model: dw.items.slice(0, 4)
                    Column {
                        required property var modelData
                        spacing: 4; width: (dw.width - 60) / 2
                        Item {
                            width: Math.min(52, dw.height * .3); height: width; anchors.horizontalCenter: parent.horizontalCenter
                            ProgressRing { anchors.fill: parent; visible: modelData.value >= 0; value: Math.max(0, modelData.value); lineWidth: 4; ink: modelData.value >= 0 && modelData.value < .2 ? Theme.error : Theme.primary }
                            Rectangle { anchors.fill: parent; visible: modelData.value < 0; radius: width / 2; color: Theme.tertiaryContainer }
                            Glyph { anchors.centerIn: parent; name: modelData.icon; font.pixelSize: parent.width * .42; color: modelData.value < 0 ? Theme.onTertiaryContainer : Theme.text }
                        }
                        MText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; role: "label"; font.weight: Font.Bold }
                        Accessible.role: Accessible.StaticText
                        Accessible.name: modelData.name + " " + modelData.label
                    }
                }
            }
            MText { anchors.centerIn: parent; visible: dw.items.length === 0; text: "No devices"; role: "bodyS"; color: Theme.subtext }
        }
    }
    Component {
        id: clockView
        Rectangle {
            radius: 28; color: Theme.alpha(Theme.level(2), .94)
            Column {
                anchors.centerIn: parent; spacing: 2
                MText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(Hub.now, "HH:mm"); font.pixelSize: Math.min(hw.height * .34, hw.width * .26); font.weight: Font.Black; font.features: {"tnum": 1} }
                MText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(Hub.now, "dddd d MMMM"); role: "labelS"; color: Theme.subtext }
            }
        }
    }
    Component {
        id: placeholder
        Rectangle {
            radius: 28; color: Theme.alpha(Theme.level(2), .5); border.width: 1; border.color: Theme.outline
            MText { anchors.centerIn: parent; text: hw.kind === "live" ? "Live activity shows here" : "No photos yet"; role: "bodyS"; color: Theme.subtext }
        }
    }
}
