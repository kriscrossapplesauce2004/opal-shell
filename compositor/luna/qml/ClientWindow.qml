import QtQuick
import Waylib.Server

// One toplevel (xdg or X11) as an Item in the scene: spring geometry, open and close motion.
Item {
    id: client

    required property var shellSurface
    required property bool x11
    required property var shell

    // Target rectangle from the tiling layout.
    property var slot: ({ x: 0, y: 0, width: 0, height: 0 })
    property bool focused: false
    property bool ready: false
    property bool closing: false
    property bool minimized: false
    property bool maximized: false
    property bool fullscreen: false
    property var surfaceItem: null
    readonly property var surface: surfaceItem ? surfaceItem.surface : null
    readonly property string title: shellSurface ? (shellSurface.title || shellSurface.appId || "window") : "window"

    signal gone()

    x: slot.x
    y: slot.y
    width: slot.width
    height: slot.height
    visible: !minimized || closing

    // Animate only after creation, so a new window does not fly in from the corner.
    Behavior on x {
        enabled: client.ready
        SpringAnimation { spring: 3.2; damping: 0.42; epsilon: 0.25 }
    }
    Behavior on y {
        enabled: client.ready
        SpringAnimation { spring: 3.2; damping: 0.42; epsilon: 0.25 }
    }
    Behavior on width {
        enabled: client.ready
        SpringAnimation { spring: 3.2; damping: 0.42; epsilon: 0.25 }
    }
    Behavior on height {
        enabled: client.ready
        SpringAnimation { spring: 3.2; damping: 0.42; epsilon: 0.25 }
    }

    // Grow and shrink from the top edge.
    transformOrigin: Item.Top
    scale: 0.6
    opacity: 0

    ParallelAnimation {
        id: openAnim
        SpringAnimation { target: client; property: "scale"; to: 1; spring: 4.0; damping: 0.45; epsilon: 0.005 }
        NumberAnimation { target: client; property: "opacity"; to: 1; duration: 180 }
    }

    ParallelAnimation {
        id: closeAnim
        SpringAnimation { target: client; property: "scale"; to: 0.6; spring: 4.0; damping: 0.6; epsilon: 0.005 }
        NumberAnimation { target: client; property: "opacity"; to: 0; duration: 160 }
        onFinished: {
            client.gone()
            client.destroy()
        }
    }

    // Sends the tiled size and states to the client, only when they change.
    onSlotChanged: sendSize()
    onFocusedChanged: sendStates()
    onMaximizedChanged: sendStates()
    onFullscreenChanged: sendStates()

    function sendSize() {
        if (!ready || closing)
            return
        shell.server.configureToplevel(shellSurface, Qt.size(Math.round(slot.width), Math.round(slot.height)))
        if (x11 && surfaceItem)
            shell.server.moveX11(surfaceItem, Qt.point(Math.round(slot.x), Math.round(slot.y)))
    }

    function sendStates() {
        if (!ready || closing)
            return
        shellSurface.setActivate(focused)
        shellSurface.setMaximize(maximized)
        shellSurface.setFullScreen(fullscreen)
    }

    function focusSurface() {
        if (surfaceItem && !closing)
            shell.server.focusItem(surfaceItem)
    }

    // The surface is gone; its item keeps the last buffer for the close motion.
    function beginClose() {
        if (closing)
            return
        closing = true
        closeAnim.start()
        shell.relayout()
    }

    Component {
        id: xdgItem
        XdgToplevelSurfaceItem {
            resizeMode: SurfaceItem.SizeFromSurface
        }
    }

    Component {
        id: x11Item
        XWaylandSurfaceItem {
            resizeMode: SurfaceItem.SizeFromSurface
        }
    }

    Component.onCompleted: {
        surfaceItem = (x11 ? x11Item : xdgItem).createObject(client, { shellSurface: client.shellSurface })
        ready = true
        sendSize()
        sendStates()
        openAnim.start()
    }

    // Focus border, drawn by the shell; clients draw their own frames.
    Rectangle {
        anchors.fill: parent
        z: 10
        visible: !client.fullscreen
        color: "transparent"
        border.width: 2
        border.color: client.focused ? "#8ab4ff" : "#2a3038"
    }
}
