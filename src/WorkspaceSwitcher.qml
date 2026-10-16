import QtQuick

// Workspace chip for the tablet bar: the current number and one dot per workspace. A tap pops the workspace card up out of it.
Item {
    id: chip
    property var screenObj: null
    readonly property var spaces: (Hub.status.workspaces || []).slice().sort((a, b) => a - b)
    readonly property int current: Number(Hub.status.workspace)
    readonly property bool open: PhoneState.spacesOpen && PhoneState.spacesScreen === screenObj
    function toggle() {
        if (open) { PhoneState.spacesOpen = false; return; }
        PhoneState.spacesScreen = screenObj;
        PhoneState.spacesX = chip.mapToItem(null, 0, 0).x;
        PhoneState.spacesOpen = true;
    }
    implicitWidth: pill.width; implicitHeight: 52
    width: implicitWidth; height: implicitHeight

    Rectangle {
        id: pill
        width: pillRow.implicitWidth + 16; height: 52; radius: 26
        color: chip.open ? Theme.primaryContainer : Theme.alpha(Theme.text, .07)
        Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: tap.pressed ? .14 : hover.hovered ? .08 : 0 }
        Row {
            id: pillRow
            anchors.centerIn: parent; spacing: 10
            Rectangle {
                width: 36; height: 36; radius: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                MText { anchors.centerIn: parent; text: String(chip.current || "–"); role: "label"; font.weight: Font.Bold; color: Theme.onPrimary }
            }
            // One dot per workspace; the current one is a short bar. The row ends with a small gap, not an arrow.
            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: 4; rightPadding: 6
                Repeater {
                    model: chip.spaces
                    Rectangle {
                        required property var modelData
                        readonly property bool on: Number(modelData) === chip.current
                        anchors.verticalCenter: parent.verticalCenter
                        width: on ? 14 : 6; height: 6; radius: 3
                        color: on ? (chip.open ? Theme.containerInk : Theme.primary) : Theme.alpha(chip.open ? Theme.containerInk : Theme.text, Hub.windows.some(w => Number(w.workspace) === Number(modelData)) ? .6 : .28)
                        Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: chip.toggle() }
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + chip.current + " of " + chip.spaces.length + ". Show workspaces"
    }
}
