import QtQuick

// M3 Expressive linear progress: the active track, a gap, the inactive track and a stop dot. A negative value shows an indeterminate sweep.
Item {
    id: bar
    property real value: 0
    property color ink: Theme.primary
    readonly property bool indeterminate: value < 0
    readonly property real shown: indeterminate ? .3 : Math.max(0, Math.min(1, value))
    property real sweep: 0
    implicitHeight: 8
    clip: indeterminate
    NumberAnimation on sweep { running: bar.indeterminate && bar.visible && !Theme.reduceMotion; from: -.3; to: 1; duration: 1400; loops: Animation.Infinite }
    Rectangle {
        x: bar.indeterminate ? bar.sweep * bar.width : 0
        width: Math.max(bar.height, (bar.width - 6) * bar.shown); height: bar.height; radius: bar.height / 2; color: bar.ink
        Behavior on width { enabled: !bar.indeterminate; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
    }
    Rectangle {
        visible: !bar.indeterminate
        x: (bar.width - 6) * bar.shown + 6; width: Math.max(0, bar.width - x); height: bar.height; radius: bar.height / 2
        color: Theme.alpha(bar.ink, .2)
    }
    Rectangle { visible: bar.indeterminate; anchors.fill: parent; radius: bar.height / 2; color: Theme.alpha(bar.ink, .2); z: -1 }
    Rectangle { visible: !bar.indeterminate; x: bar.width - bar.height / 2 - 2; y: (bar.height - 4) / 2; width: 4; height: 4; radius: 2; color: bar.ink }
}
