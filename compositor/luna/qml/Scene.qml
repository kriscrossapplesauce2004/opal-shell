import QtQuick
import Waylib.Server
import "qml/Layout.js" as Layout
import "Layers.js" as Layers

// The one scene: layer surfaces, windows, popups, the lock and the stand-in bar, as Items over the output.
Item {
    id: root

    readonly property var server: luna
    readonly property rect outputRect: server.outputRect

    x: outputRect.x
    y: outputRect.y
    width: outputRect.width
    height: outputRect.height

    readonly property int barHeight: server.standInBar ? 36 : 0
    // Windows tile in the area that no layer-shell exclusive zone covers.
    property var usable: ({ x: 0, y: 0, width: width, height: height })
    readonly property var workArea: ({ x: usable.x, y: usable.y + barHeight, width: usable.width,
                                       height: Math.max(0, usable.height - barHeight) })
    readonly property var fullArea: ({ x: 0, y: 0, width: width, height: height })

    property var clients: []
    property var focused: null
    property int topZ: 1
    property var layerItems: []
    property var unmanaged: []
    property var lockItems: []
    readonly property bool locked: server.locked

    onWidthChanged: arrangeLayers()
    onHeightChanged: arrangeLayers()
    onWorkAreaChanged: {
        relayout()
        server.setWorkArea(Qt.rect(workArea.x, workArea.y, workArea.width, workArea.height))
    }

    function clientFor(shellSurface) {
        return clients.find(c => c.shellSurface === shellSurface) || null
    }

    // Finds the item that shows a WSurface: a window, a layer surface or a popup.
    function itemForSurface(surface) {
        const c = clients.find(x => x.surface === surface)
        if (c)
            return c.surfaceItem
        const l = layerItems.find(x => x.surface === surface)
        if (l)
            return l
        return popupItems.find(p => p.surface === surface) || null
    }
    property var popupItems: []

    function addClient(shellSurface, x11) {
        const parentSurface = shellSurface.parentSurface
        const c = clientComponent.createObject(clientLayer, {
            shellSurface: shellSurface,
            x11: x11,
            shell: root,
            slot: { x: workArea.x + 8, y: workArea.y + 8, width: workArea.width - 16, height: workArea.height - 16 },
            z: ++topZ
        })
        c.gone.connect(() => root.forgetClient(c))
        clients = clients.concat([c])
        relayout()
        focusClient(c)
    }

    function removeClient(shellSurface) {
        const c = clientFor(shellSurface)
        if (!c)
            return
        c.beginClose()
        if (focused === c) {
            const rest = clients.filter(x => !x.minimized && !x.closing)
            focusClient(rest.length > 0 ? rest[rest.length - 1] : null)
        }
    }

    function forgetClient(c) {
        clients = clients.filter(x => x !== c)
        relayout()
    }

    // Tiles normal windows; maximized windows fill the work area, fullscreen windows the output.
    function relayout() {
        const tiled = clients.filter(c => !c.minimized && !c.maximized && !c.fullscreen && !c.closing)
        const rects = Layout.tile(tiled.length, workArea)
        tiled.forEach((c, i) => { c.slot = rects[i] })
        clients.forEach(c => {
            if (c.closing)
                return
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
        if (!exclusiveLayer())
            c.focusSurface()
    }

    function setMinimized(c, on) {
        if (!c || c.minimized === on)
            return
        c.minimized = on
        relayout()
        if (on && focused === c) {
            const rest = clients.filter(x => !x.minimized && !x.closing)
            focusClient(rest.length > 0 ? rest[rest.length - 1] : null)
        }
    }

    function setMaximized(c, on) {
        if (!c)
            return
        c.maximized = on
        relayout()
    }

    function setFullscreen(c, on) {
        if (!c)
            return
        c.fullscreen = on
        relayout()
    }

    // --- Layer shell ---

    function layerContainer(layer) {
        return [backgroundLayer, bottomLayer, topLayer, overlayLayer][Math.max(0, Math.min(3, layer))]
    }

    function addLayer(layerSurface) {
        const item = layerComponent.createObject(layerContainer(layerSurface.layer), {
            layerSurface: layerSurface,
            shell: root
        })
        layerItems = layerItems.concat([item])
        arrangeLayers()
    }

    function removeLayer(layerSurface) {
        const item = layerItems.find(i => i.layerSurface === layerSurface)
        layerItems = layerItems.filter(i => i !== item)
        if (item)
            item.destroy()
        arrangeLayers()
        applyFocus()
    }

    // Places all layer surfaces and sets the work area from their exclusive zones.
    function arrangeLayers() {
        const entries = layerItems.map(i => ({
            exclusiveZone: i.layerSurface.exclusiveZone,
            anchor: i.layerSurface.ancher,
            leftMargin: i.layerSurface.leftMargin,
            rightMargin: i.layerSurface.rightMargin,
            topMargin: i.layerSurface.topMargin,
            bottomMargin: i.layerSurface.bottomMargin,
            desiredWidth: i.layerSurface.desiredSize.width,
            desiredHeight: i.layerSurface.desiredSize.height
        }))
        const result = Layers.arrange(entries, { x: 0, y: 0, width: root.width, height: root.height })
        layerItems.forEach((item, i) => {
            const container = layerContainer(item.layerSurface.layer)
            if (item.parent !== container)
                item.parent = container
            item.place = result.places[i]
        })
        if (JSON.stringify(result.usable) !== JSON.stringify(usable))
            usable = result.usable
        applyFocus()
    }

    // The topmost layer surface that wants the keys: exclusive interactivity in the top or overlay layer.
    function exclusiveLayer() {
        const ex = layerItems.filter(i => i.layerSurface.keyboardInteractivity === 1 /* exclusive */
                                     && i.layerSurface.layer >= 2 /* top */)
        return ex.length > 0 ? ex[ex.length - 1] : null
    }

    // A lock surface wins, then exclusive layer focus; without either, the active window gets the keys back.
    function applyFocus() {
        if (locked) {
            if (lockItems.length > 0)
                server.focusItem(lockItems[0])
            return
        }
        const ex = exclusiveLayer()
        if (ex) {
            ex.focusSurface()
            return
        }
        if (focused)
            focused.focusSurface()
    }

    // A press gives focus to what it landed on: a window, or a layer surface that takes keys.
    function pressed(surface) {
        if (locked)
            return
        const c = clients.find(x => x.surface === surface && !x.closing)
        if (c) {
            if (c !== focused)
                focusClient(c)
            return
        }
        const l = layerItems.find(x => x.surface === surface)
        if (l && l.layerSurface.keyboardInteractivity !== 0 /* none */)
            l.focusSurface()
    }

    // --- Popups ---

    function addPopup(popup, parentSurface) {
        const parentItem = itemForSurface(parentSurface)
        if (!parentItem) {
            console.warn("luna: popup without a parent item")
            return
        }
        const p = popupComponent.createObject(parentItem, { shellSurface: popup })
        popupItems = popupItems.concat([p])
    }

    function removePopup(popup) {
        const p = popupItems.find(x => x.shellSurface === popup)
        popupItems = popupItems.filter(x => x !== p)
        if (p)
            p.destroy()
    }

    function addInputPopup(popup, parentSurface) {
        const parentItem = itemForSurface(parentSurface)
        if (!parentItem)
            return
        const p = inputPopupComponent.createObject(parentItem, { shellSurface: popup })
        popupItems = popupItems.concat([p])
    }

    // --- X11 windows the window manager must not move (menus, tooltips, transients) ---

    function addUnmanaged(surface) {
        const u = unmanagedComponent.createObject(unmanagedLayer, { shellSurface: surface })
        unmanaged = unmanaged.concat([u])
    }

    function removeUnmanaged(surface) {
        const u = unmanaged.find(x => x.shellSurface === surface)
        unmanaged = unmanaged.filter(x => x !== u)
        if (u)
            u.destroy()
    }

    // --- Session lock ---

    function addLockSurface(lockSurface) {
        const item = lockComponent.createObject(lockLayer, { shellSurface: lockSurface })
        lockItems = lockItems.concat([item])
        server.resizeLockSurface(item, Qt.size(width, height))
        applyFocus()
    }

    function removeLockSurface(lockSurface) {
        const item = lockItems.find(x => x.shellSurface === lockSurface)
        lockItems = lockItems.filter(x => x !== item)
        if (item)
            item.destroy()
    }

    onLockedChanged: applyFocus()

    Connections {
        target: root.server
        function onToplevelAdded(surface, x11) { root.addClient(surface, x11) }
        function onToplevelRemoved(surface) { root.removeClient(surface) }
        function onLayerAdded(surface) { root.addLayer(surface) }
        function onLayerRemoved(surface) { root.removeLayer(surface) }
        function onLayersChanged() { root.arrangeLayers() }
        function onPopupAdded(popup, parent) { root.addPopup(popup, parent) }
        function onPopupRemoved(popup) { root.removePopup(popup) }
        function onInputPopupAdded(popup, parent) { root.addInputPopup(popup, parent) }
        function onInputPopupRemoved(popup) { root.removePopup(popup) }
        function onUnmanagedAdded(surface) { root.addUnmanaged(surface) }
        function onUnmanagedRemoved(surface) { root.removeUnmanaged(surface) }
        function onLockSurfaceAdded(surface) { root.addLockSurface(surface) }
        function onLockSurfaceRemoved(surface) { root.removeLockSurface(surface) }
        function onSurfacePressed(surface) { root.pressed(surface) }
        function onActivateRequested(surface) { root.focusClient(root.clientFor(surface)) }
        function onCloseRequested(surface) { surface.close() }
        function onMinimizeRequested(surface, on) { root.setMinimized(root.clientFor(surface), on) }
        function onMaximizeRequested(surface, on) { root.setMaximized(root.clientFor(surface), on) }
        function onFullscreenRequested(surface, on) { root.setFullscreen(root.clientFor(surface), on) }
    }

    Component {
        id: clientComponent
        ClientWindow {}
    }

    Component {
        id: layerComponent
        LayerItem {}
    }

    // Popups sit at the place the positioner gave, relative to the parent surface.
    Component {
        id: popupComponent
        XdgPopupSurfaceItem {
            z: 100
            resizeMode: SurfaceItem.SizeFromSurface
            x: implicitPosition.x
            y: implicitPosition.y
        }
    }

    Component {
        id: inputPopupComponent
        InputPopupSurfaceItem {
            z: 100
            resizeMode: SurfaceItem.SizeFromSurface
            x: 0
            y: 0
        }
    }

    Component {
        id: unmanagedComponent
        XWaylandSurfaceItem {
            resizeMode: SurfaceItem.SizeFromSurface
            // The X client places menus and tooltips itself, in global coordinates.
            x: shellSurface ? shellSurface.geometry.x - root.x : 0
            y: shellSurface ? shellSurface.geometry.y - root.y : 0
        }
    }

    Component {
        id: lockComponent
        SurfaceItem {
            x: 0
            y: 0
            resizeMode: SurfaceItem.SizeFromSurface
        }
    }

    // Layer order: background, bottom, windows, top, overlay, X11 menus, lock; while locked, only the lock shows.
    Item { id: backgroundLayer; anchors.fill: parent; z: 0; visible: !root.locked }
    Item { id: bottomLayer; anchors.fill: parent; z: 1; visible: !root.locked }
    Item { id: clientLayer; anchors.fill: parent; z: 2; visible: !root.locked }
    Item { id: topLayer; anchors.fill: parent; z: 3; visible: !root.locked }
    Item { id: overlayLayer; anchors.fill: parent; z: 4; visible: !root.locked }
    Item { id: unmanagedLayer; anchors.fill: parent; z: 5; visible: !root.locked }

    Bar {
        id: bar
        visible: root.server.standInBar && !root.locked
        shell: root
        z: 6
    }

    // Blank until the lock client draws; stays blank if the lock client dies.
    Rectangle {
        id: lockLayer
        anchors.fill: parent
        z: 10
        visible: root.locked
        color: "black"
    }
}
