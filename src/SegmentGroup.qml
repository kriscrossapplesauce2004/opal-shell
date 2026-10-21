import QtQuick
import QtQuick.Layouts

// One pill split into segments with small gaps. Selection changes colour only, never shape. Options are {id, name, icon?}.
RowLayout {
    id: group
    property var options: []
    property var current: null
    property real segmentHeight: 40
    signal picked(var id)
    spacing: 3
    Repeater {
        model: group.options
        Rectangle {
            id: segment
            required property var modelData
            required property int index
            readonly property bool chosen: modelData.id === group.current
            readonly property real outer: height / 2
            // Equal shares of the width; the check mark drops out when a segment is too narrow for it.
            Layout.fillWidth: true; Layout.preferredHeight: group.segmentHeight; Layout.preferredWidth: 1
            readonly property bool roomy: width >= name.implicitWidth + 23 + 20
            topLeftRadius: index === 0 ? outer : 6; bottomLeftRadius: topLeftRadius
            topRightRadius: index === group.options.length - 1 ? outer : 6; bottomRightRadius: topRightRadius
            color: chosen ? Theme.secondaryContainer : Theme.alpha(Theme.level(4), .88)
            Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
            Row {
                id: label
                anchors.centerIn: parent; spacing: 6
                Glyph { visible: (segment.chosen || !!segment.modelData.icon) && segment.roomy; name: segment.chosen ? "check" : segment.modelData.icon || ""; font.pixelSize: 17; color: segment.chosen ? Theme.onSecondaryContainer : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                MText { id: name; text: segment.modelData.name; role: "label"; font.weight: segment.chosen ? Font.Bold : Font.Medium; color: segment.chosen ? Theme.onSecondaryContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: group.picked(segment.modelData.id) }
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.name
            Accessible.checked: chosen
        }
    }
}
