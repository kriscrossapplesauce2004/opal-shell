import QtQuick

// A stepped slider: one stop per value, the chosen one marked by the M3 handle. Left and right on a controller move one stop.
Item {
    id: steps
    property var stops: []
    property var current: 0
    property bool controllerFocused: false
    signal picked(var value)
    readonly property int index: Math.max(0, stops.indexOf(current))
    readonly property real gap: stops.length > 1 ? (width - 24) / (stops.length - 1) : 0
    function controllerAdjust(delta) { const i = Math.max(0, Math.min(stops.length - 1, index + delta)); if (i !== index) picked(stops[i]); return true; }
    function controllerActivate() { controllerAdjust(1); }
    implicitHeight: 58
    Rectangle { x: 12; y: 12; width: steps.width - 24; height: 14; radius: 7; color: Theme.alpha(Theme.tile, .95) }
    Rectangle { x: 12; y: 12; width: Math.max(0, steps.gap * steps.index - 6); height: 14; radius: 7; color: Theme.primary; visible: steps.index > 0
        Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durShort); easing.type: Easing.OutCubic } } }
    Repeater {
        model: steps.stops
        Item {
            required property var modelData
            required property int index
            x: 12 + index * steps.gap; y: 0
            Rectangle { visible: index !== steps.index; x: -2.5; y: 16.5; width: 5; height: 5; radius: 2.5; color: index < steps.index ? Theme.onPrimary : Theme.subtext }
            MText { x: -width / 2; y: 36; text: modelData ? String(modelData) : "Off"; role: "label"; font.features: {"tnum": 1}
                font.weight: index === steps.index ? Font.Bold : Font.Medium; color: index === steps.index ? Theme.primary : Theme.subtext }
            MouseArea { x: -steps.gap / 2; width: Math.max(24, steps.gap); y: 0; height: steps.height; cursorShape: Qt.PointingHandCursor; onClicked: steps.picked(modelData); property bool controllerSkip: true }
        }
    }
    Rectangle { x: 12 + steps.gap * steps.index - 2; y: 2; width: 4; height: 34; radius: 2; color: Theme.primary
        Behavior on x { NumberAnimation { duration: Theme.motion(Theme.durShort); easing.type: Easing.OutCubic } } }
    // One controller target for the whole control.
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.NoButton | Qt.LeftButton; enabled: true; onClicked: {} }
    Accessible.role: Accessible.Slider
    Accessible.name: "Frame limit"
}
