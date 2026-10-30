import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell

// One xdg toplevel as an Item in the shell scene.
Item {
    id: client

    required property var toplevel
    required property var xdgSurface
    required property var shell

    // Target rectangle from the tiling layout.
    property var slot: ({ x: 0, y: 0, width: 0, height: 0 })
    property bool focused: false
    property bool ready: false
    property bool closing: false
    property bool minimized: false
    property bool maximized: false
    property bool fullscreen: false
    // Task bar handle for foreign clients (zwlr_foreign_toplevel_handle_v1).
    property var handle: null
    readonly property var surfaceObject: surface.surface

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

    // Grow and shrink from the top edge, where the bar sits.
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

    // Sends the tiled size and the states to the client, only when they change.
    onSlotChanged: sendSize()
    onFocusedChanged: sendSize()
    onMaximizedChanged: sendSize()
    onFullscreenChanged: sendSize()

    function sendSize() {
        if (!ready || closing)
            return
        const states = []
        if (focused)
            states.push(XdgToplevel.ActivatedState)
        if (maximized)
            states.push(XdgToplevel.MaximizedState)
        if (fullscreen)
            states.push(XdgToplevel.FullscreenState)
        if (!maximized && !fullscreen)
            states.push(XdgToplevel.TiledLeftState, XdgToplevel.TiledRightState, XdgToplevel.TiledTopState,
                        XdgToplevel.TiledBottomState)
        toplevel.sendConfigure(Qt.size(Math.round(slot.width), Math.round(slot.height)), states)
    }

    function focusSurface() {
        surface.takeFocus()
        surface.forceActiveFocus()
    }

    function beginClose() {
        if (closing)
            return
        closing = true
        if (handle)
            handle.remove()
        handle = null
        closeAnim.start()
        shell.relayout()
    }

    Component.onCompleted: {
        ready = true
        handle = shell.foreignToplevels.add(toplevel, shell.output)
        sendSize()
        openAnim.start()
    }

    Binding { target: client.handle; property: "activated"; value: client.focused; when: client.handle !== null }
    Binding { target: client.handle; property: "minimized"; value: client.minimized; when: client.handle !== null }
    Binding { target: client.handle; property: "maximized"; value: client.maximized; when: client.handle !== null }
    Binding { target: client.handle; property: "fullscreen"; value: client.fullscreen; when: client.handle !== null }

    // Requests from the task bar.
    Connections {
        target: client.handle
        function onActivateRequested() { client.shell.focusClient(client) }
        function onCloseRequested() { client.toplevel.sendClose() }
        function onMinimizeRequested(on) { client.shell.setMinimized(client, on) }
        function onMaximizeRequested(on) { client.shell.setMaximized(client, on) }
        function onFullscreenRequested(on) { client.shell.setFullscreen(client, on) }
    }

    // Requests from the window itself.
    Connections {
        target: client.toplevel
        function onSetMaximized() { client.shell.setMaximized(client, true) }
        function onUnsetMaximized() { client.shell.setMaximized(client, false) }
        function onSetFullscreen(output) { client.shell.setFullscreen(client, true) }
        function onUnsetFullscreen() { client.shell.setFullscreen(client, false) }
        function onSetMinimized() { client.shell.setMinimized(client, true) }
    }

    // Keeps a copy of the last frame, so the close animation has content.
    ShaderEffectSource {
        id: snapshot
        x: 0
        y: 0
        width: surface.width
        height: surface.height
        sourceItem: surface
        live: false
        hideSource: false
    }

    Timer {
        interval: 500
        repeat: true
        running: !client.closing && client.visible
        onTriggered: snapshot.scheduleUpdate()
    }

    ShellSurfaceItem {
        id: surface
        x: 0
        y: 0
        shellSurface: client.xdgSurface
        autoCreatePopupItems: true
        // An exclusive layer surface (lock, launcher) keeps the keys; a click on a window does not take them.
        focusOnClick: !client.shell.layers.exclusiveFocus
        onSurfaceDestroyed: client.beginClose()
    }

    // Focus border, drawn by the shell because the server sets no decorations.
    Rectangle {
        anchors.fill: parent
        z: 10
        visible: !client.fullscreen
        color: "transparent"
        border.width: 2
        border.color: client.focused ? "#8ab4ff" : "#2a3038"
    }
}
