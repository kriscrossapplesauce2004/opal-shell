import QtQuick

// A disk bar split into parts, [{v: bytes, c: colour}], with small gaps; only the outer ends are round.
Row {
    id: bar
    property var parts: []
    property real total: 0
    property real barHeight: 14
    spacing: 3
    readonly property real sum: Math.max(1, total || parts.reduce((s, p) => s + p.v, 0))
    Repeater {
        model: bar.parts
        Rectangle {
            required property var modelData
            required property int index
            width: Math.max(4, (bar.width - bar.spacing * (bar.parts.length - 1)) * modelData.v / bar.sum); height: bar.barHeight
            readonly property real end: bar.barHeight / 2
            topLeftRadius: index === 0 ? end : 3; bottomLeftRadius: index === 0 ? end : 3
            topRightRadius: index === bar.parts.length - 1 ? end : 3; bottomRightRadius: index === bar.parts.length - 1 ? end : 3
            color: modelData.c
        }
    }
}
