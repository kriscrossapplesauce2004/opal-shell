import QtQuick
import Waylib.Server

// One output: its viewport renders the scene region under it, and its cursor.
OutputItem {
    id: outputItem

    readonly property OutputViewport screenViewport: viewport

    devicePixelRatio: output?.scale ?? devicePixelRatio

    cursorDelegate: Cursor {
        required property QtObject outputCursor
        readonly property point position: parent.mapFromGlobal(cursor.position.x, cursor.position.y)

        cursor: outputCursor.cursor
        output: outputCursor.output.output
        x: position.x - hotSpot.x
        y: position.y - hotSpot.y
        visible: valid && outputCursor.visible
        OutputLayer.enabled: true
        OutputLayer.keepLayer: true
        OutputLayer.outputs: [viewport]
        OutputLayer.flags: OutputLayer.Cursor
        OutputLayer.cursorHotSpot: hotSpot
    }

    OutputViewport {
        id: viewport
        output: outputItem.output
        devicePixelRatio: outputItem.devicePixelRatio
        anchors.centerIn: parent
    }
}
