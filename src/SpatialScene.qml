import QtQuick

// Luna spatial: the XR view. Panels float in front of the environment, and a heads-up layer keeps the time, the battery and the top live activity in view.
Item {
    id: scene
    property url environment
    property int headsetBattery: 78
    default property alias panels: space.data
    readonly property var pill: Activities.list.find(a => a.kind !== "media") || null

    Image { anchors.fill: parent; source: scene.environment; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(1920, 1080); asynchronous: true }
    // The environment stays visible, but darker, so the glass panels keep contrast.
    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: Theme.alpha("#000000", .45) } GradientStop { position: .6; color: Theme.alpha("#000000", .2) } GradientStop { position: 1; color: Theme.alpha("#000000", .55) } } }
    Item { id: space; anchors.fill: parent }

    // Heads-up layer: it follows the head, so it stays small and at the top corners.
    Rectangle {
        x: 48; y: 40; height: 44; radius: 22; width: hudRow.implicitWidth + 32
        color: Theme.alpha(Theme.glassRaised, .8); border.width: 1; border.color: Theme.glassEdge
        Row {
            id: hudRow; anchors.centerIn: parent; spacing: 10
            MText { text: Qt.formatDateTime(Hub.now, "HH:mm"); role: "title"; font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 1; height: 18; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            Glyph { name: "battery_5_bar"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
            MText { text: scene.headsetBattery + "%"; role: "titleS"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Rectangle {
        visible: scene.pill !== null
        anchors.right: parent.right; anchors.rightMargin: 48; y: 40; height: 44; radius: 22; width: pillRow.implicitWidth + 32
        color: Theme.tertiaryContainer
        Row {
            id: pillRow; anchors.centerIn: parent; spacing: 8
            Glyph { name: scene.pill ? scene.pill.icon : ""; font.pixelSize: 20; color: Theme.tertiaryInk; anchors.verticalCenter: parent.verticalCenter }
            MText { text: scene.pill ? scene.pill.title + " · " + scene.pill.short : ""; role: "titleS"; color: Theme.tertiaryInk; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
