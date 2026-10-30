import QtQuick

// One window in Luna spatial. Yaw turns it toward the viewer and depth pushes it back. The title chip and the move handle sit outside the glass.
Item {
    id: panel
    property string title: ""
    property string icon: "apps"
    property real yaw: 0
    property real depth: 0
    property bool gazed: false
    default property alias content: body.data
    implicitWidth: 640; implicitHeight: 480
    scale: 1 / (1 + depth)
    transform: Rotation { origin.x: panel.width / 2; origin.y: panel.height / 2; axis { x: 0; y: 1; z: 0 } angle: panel.yaw }

    Rectangle {
        id: chip
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: glass.top; anchors.bottomMargin: 14
        width: chipRow.implicitWidth + 24; height: 40; radius: 20
        color: Theme.alpha(Theme.glassRaised, .82); border.width: 1; border.color: Theme.glassEdge
        Row {
            id: chipRow; anchors.centerIn: parent; spacing: 8
            Rectangle { width: 28; height: 28; radius: 14; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                Glyph { anchors.centerIn: parent; name: panel.icon; font.pixelSize: 17; color: Theme.primaryInk } }
            MText { text: panel.title; role: "titleS"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Rectangle {
        id: glass
        anchors.fill: parent
        radius: Theme.shapeXl; color: Theme.alpha(Theme.glassTint, .9); border.width: 1; border.color: Theme.glassEdge
        Rectangle { anchors.fill: parent; anchors.margins: 1; radius: parent.radius - 1; color: "transparent"; border.width: panel.gazed ? 3 : 0; border.color: Theme.alpha("#ffffff", .7) }
        Item { id: body; anchors.fill: parent; anchors.margins: 1; clip: true }
    }
    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: glass.bottom; anchors.topMargin: 16; width: 120; height: 8; radius: 4; color: Theme.alpha("#ffffff", .5) }
}
