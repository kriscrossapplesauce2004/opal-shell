import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import Luna.Compositor
import "Layout.js" as Layout

// One window, one scene: clients, layer surfaces and the shell are Items in this Window.
Window {
    id: root

    width: 1280
    height: 800
    visible: true
    title: "Luna compositor"
    color: "#0d1116"

    // The stand-in bar is for runs without a real shell (run-nested.sh).
    readonly property bool standInBar: typeof lunaStandInBar !== "undefined" && lunaStandInBar
    readonly property int barHeight: standInBar ? 36 : 0
    // Windows tile in the area that no layer-shell exclusive zone covers.
    readonly property rect usable: layerShell.usableArea.width > 0 ? layerShell.usableArea : Qt.rect(0, 0, width, height)
    readonly property var workArea: ({ x: usable.x, y: usable.y + barHeight, width: usable.width,
                                       height: Math.max(0, usable.height - barHeight) })
    readonly property var fullArea: ({ x: 0, y: 0, width: width, height: height })

    property var clients: []
    property var focused: null
    property int topZ: 1
    property var layerItems: []
    property var lockItem: null

    readonly property alias foreignToplevels: foreignToplevelManager
    readonly property alias output: mainOutput
    readonly property alias layers: layerShell

    onWidthChanged: relayout()
    onHeightChanged: relayout()
    onWorkAreaChanged: relayout()

    function addClient(toplevel, xdgSurface) {
        const c = clientComponent.createObject(clientLayer, {
            toplevel: toplevel,
            xdgSurface: xdgSurface,
            shell: root,
            slot: { x: workArea.x + 8, y: workArea.y + 8, width: workArea.width - 16, height: workArea.height - 16 },
            z: ++topZ
        })
        c.gone.connect(() => root.removeClient(c))
        clients = clients.concat([c])
        relayout()
        focusClient(c)
    }

    function removeClient(c) {
        clients = clients.filter(x => x !== c)
        relayout()
        if (focused === c) {
            const rest = clients.filter(x => !x.minimized)
            focusClient(rest.length > 0 ? rest[rest.length - 1] : null)
        }
    }

    // Tiles normal windows; maximized windows fill the work area, fullscreen windows the output.
    function relayout() {
        const tiled = clients.filter(c => !c.minimized && !c.maximized && !c.fullscreen && !c.closing)
        const rects = Layout.tile(tiled.length, workArea)
        tiled.forEach((c, i) => { c.slot = rects[i] })
        clients.forEach(c => {
            if (c.fullscreen)
                c.slot = fullArea
            else if (c.maximized)
                c.slot = workArea
        })
        clientLayer.z = clients.some(c => c.fullscreen && !c.minimized) ? 3.5 : 2
    }

    // Raises the client, marks it active and gives it keyboard focus, unless a layer surface holds focus.
    function focusClient(c) {
        focused = c
        clients.forEach(x => { x.focused = (x === c) })
        if (!c)
            return
        if (c.minimized)
            setMinimized(c, false)
        c.z = ++topZ
        if (!layerShell.exclusiveFocus)
            c.focusSurface()
    }

    function setMinimized(c, on) {
        if (c.minimized === on)
            return
        c.minimized = on
        relayout()
        if (on && focused === c) {
            const rest = clients.filter(x => !x.minimized)
            focusClient(rest.length > 0 ? rest[rest.length - 1] : null)
        }
    }

    function setMaximized(c, on) {
        c.maximized = on
        relayout()
    }

    function setFullscreen(c, on) {
        c.fullscreen = on
        relayout()
    }

    function layerContainer(layer) {
        return [backgroundLayer, bottomLayer, topLayer, overlayLayer][Math.max(0, Math.min(3, layer))]
    }

    function addLayerSurface(layerSurface) {
        const item = layerComponent.createObject(layerContainer(layerSurface.layer), {
            layerSurface: layerSurface,
            shell: root
        })
        layerItems = layerItems.concat([item])
    }

    function removeLayerItem(item) {
        layerItems = layerItems.filter(x => x !== item)
    }

    // A lock surface wins, then exclusive layer focus; without either, the active window gets the keys back.
    function applyFocus() {
        if (lockManager.locked) {
            if (lockItem)
                lockItem.focusSurface()
            return
        }
        const ex = layerShell.exclusiveFocus
        if (ex) {
            const item = layerItems.find(i => i.layerSurface === ex)
            if (item)
                item.focusSurface()
            return
        }
        if (focused)
            focused.focusSurface()
    }

    // Keeps the active window in step with keyboard focus that a click moved.
    function keyboardFocusMoved(surface) {
        const layerItem = layerItems.find(i => i.surface === surface)
        const c = surface ? clients.find(x => x.surfaceObject === surface) : null
        console.info("luna: keyboard focus ->", !surface ? "none" : c ? "window " + c.toplevel.title
                     : layerItem ? "layer " + layerItem.layerSurface.nameSpace
                     : lockItem && lockItem.surface === surface ? "lock surface" : "other surface")
        if (!surface)
            return
        if (c && c !== focused) {
            focused = c
            clients.forEach(x => { x.focused = (x === c) })
            c.z = ++topZ
        }
    }

    Component {
        id: clientComponent
        ClientWindow {}
    }

    Component {
        id: layerComponent
        LayerSurfaceItem {}
    }

    // Every scene Item is a child of the tracker, so pointer motion reaches the surfaces.
    WaylandMouseTracker {
        id: tracker
        anchors.fill: parent
        windowSystemCursorEnabled: true

        // Layer order: background < bottom < windows < top < overlay.
        // While locked, nothing but the lock layer is in the scene graph.
        Item { id: backgroundLayer; anchors.fill: parent; z: 0; visible: !lockManager.locked }
        Item { id: bottomLayer; anchors.fill: parent; z: 1; visible: !lockManager.locked }
        Item { id: clientLayer; anchors.fill: parent; z: 2; visible: !lockManager.locked }
        Item { id: topLayer; anchors.fill: parent; z: 3; visible: !lockManager.locked }
        Item { id: overlayLayer; anchors.fill: parent; z: 4; visible: !lockManager.locked }

        Bar {
            id: bar
            visible: root.standInBar && !lockManager.locked
            shell: root
            z: 5
        }

        // Blank until the lock client draws; stays blank if the lock client dies.
        Rectangle {
            id: lockLayer
            anchors.fill: parent
            z: 10
            visible: lockManager.locked
            color: "black"
        }
    }

    Component {
        id: lockComponent
        ShellSurfaceItem {
            id: lockItem
            property var lockSurface
            shellSurface: lockSurface
            x: 0
            y: 0
            focusOnClick: true
            function focusSurface() {
                takeFocus()
                forceActiveFocus()
            }
            onSurfaceDestroyed: destroy()
        }
    }

    // The lock client hears "locked" only after a frame without unlocked content is on screen.
    property bool lockConfirmed: false
    onFrameSwapped: {
        if (lockManager.locked && !lockConfirmed) {
            lockConfirmed = true
            lockManager.confirmBlanked()
        }
    }

    Connections {
        target: lockManager
        function onLockedChanged() {
            root.lockConfirmed = false
            root.applyFocus()
        }
        function onLockSurfaceCreated(lockSurface) {
            root.lockItem = lockComponent.createObject(lockLayer, { lockSurface: lockSurface })
            root.applyFocus()
        }
    }

    Connections {
        target: layerShell
        function onExclusiveFocusChanged() { root.applyFocus() }
    }

    Connections {
        target: compositor.defaultSeat
        function onKeyboardFocusChanged(newFocus, oldFocus) { root.keyboardFocusMoved(newFocus) }
    }

    WaylandCompositor {
        id: compositor
        socketName: lunaSocketName

        WaylandOutput {
            id: mainOutput
            compositor: compositor
            window: root
            sizeFollowsWindow: true
        }

        XdgShell {
            id: xdgShell
            onToplevelCreated: (toplevel, xdgSurface) => root.addClient(toplevel, xdgSurface)
        }

        LayerShell {
            id: layerShell
            xdgShell: xdgShell
            onLayerSurfaceCreated: layerSurface => root.addLayerSurface(layerSurface)
            onUsableAreaChanged: root.relayout()
        }

        ForeignToplevelManager {
            id: foreignToplevelManager
        }

        SessionLockManager {
            id: lockManager
        }

        // Server-side mode: clients draw no decorations, the shell draws the frame.
        XdgDecorationManagerV1 {
            preferredMode: XdgToplevel.ServerSideDecoration
        }

        TextInputManager {}
        TextInputManagerV3 {}
        IdleInhibitManagerV1 {}
    }
}
