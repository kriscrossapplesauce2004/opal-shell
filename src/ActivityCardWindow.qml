import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The Shelf pill grows up into its card: the chosen activity in full, the others as chips. A click outside closes it.
Scope {
    id: scope
    property real reveal: 0
    property bool presenting: false
    readonly property var shown: Activities.byId[Activities.focusId] || Activities.primary
    readonly property var others: Activities.list.filter(a => !shown || a.id !== shown.id)
    Connections {
        target: Activities
        function onCardOpenChanged() {
            if (Activities.cardOpen) { scope.presenting = true; grow.to = 1; grow.restart(); }
            else { grow.to = 0; grow.restart(); }
        }
    }
    NumberAnimation {
        id: grow; target: scope; property: "reveal"; duration: Theme.motion(grow.to > 0 ? 360 : 200)
        easing.type: Easing.BezierSpline; easing.bezierCurve: grow.to > 0 ? Theme.emphasizedDecelerate : Theme.emphasizedAccelerate
        onFinished: if (!Activities.cardOpen) scope.presenting = false
    }
    // Input-only click-away surfaces on every output.
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData; visible: Activities.cardOpen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "opal-activity-dismiss"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            // Keep the Shelf clickable so its pill can close the card again.
            mask: Region {
                Region { x: 0; y: 0; width: modelData.width; height: modelData.height - 72 }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: Activities.cardOpen = false }
        }
    }
    PanelWindow {
        id: win
        screen: Activities.cardScreen || Quickshell.screens[0]
        visible: scope.presenting
        anchors { bottom: true; right: true }
        margins { bottom: 78; right: 12 }
        implicitWidth: 420
        implicitHeight: Math.min(column.implicitHeight + 8, (screen ? screen.height : 900) - 120)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "opal-activity"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        ColumnLayout {
            id: column
            width: parent.width - 8; x: 4
            anchors.bottom: parent.bottom
            spacing: 8
            opacity: scope.reveal
            transform: [
                Scale { origin.x: column.width; origin.y: column.height; xScale: .92 + .08 * scope.reveal; yScale: .85 + .15 * scope.reveal },
                Translate { y: 16 * (1 - scope.reveal) }
            ]
            Flow {
                visible: scope.others.length > 0 || Activities.freshChips.length > 0
                Layout.fillWidth: true; layoutDirection: Qt.RightToLeft; spacing: 8
                Repeater { model: scope.others; ActivityChip { required property var modelData; a: modelData; onClicked: Activities.focusId = modelData.id } }
                Repeater {
                    model: Activities.freshChips
                    ActivityChip { required property var modelData; a: ({kind: "neutral", icon: modelData.icon, short: modelData.label, title: modelData.label}); onClicked: Activities.runChip(modelData) }
                }
            }
            ActivityCard {
                visible: scope.shown !== null
                Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                a: scope.shown || ({})
                onOpened: { Activities.open(scope.shown, Activities.cardScreen); Activities.cardOpen = false; }
            }
        }
    }
}
