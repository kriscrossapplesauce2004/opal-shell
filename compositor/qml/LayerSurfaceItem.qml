import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import Luna.Compositor

// One layer-shell surface as an Item in its layer container, at the place the LayerShell arranged.
ShellSurfaceItem {
    id: item

    required property var layerSurface
    required property var shell

    shellSurface: layerSurface
    x: layerSurface.geometry.x
    y: layerSurface.geometry.y
    visible: layerSurface.mapped
    autoCreatePopupItems: false
    // "none" never takes keys; "on_demand" and "exclusive" take them on a press.
    focusOnClick: layerSurface.keyboardInteractivity !== LayerSurface.InteractivityNone

    function focusSurface() {
        takeFocus()
        forceActiveFocus()
    }

    onSurfaceDestroyed: {
        shell.removeLayerItem(item)
        item.destroy()
    }

    Component.onDestruction: shell.removeLayerItem(item)

    Connections {
        target: item.layerSurface
        function onLayerChanged() { item.parent = item.shell.layerContainer(item.layerSurface.layer) }
        function onPopupCreated(popup, xdgSurface) {
            const p = popupComponent.createObject(item, { shellSurface: xdgSurface })
            console.info("luna: popup for layer", item.layerSurface.nameSpace, p)
        }
    }

    // Qt's popup glue places the popup relative to this item from the positioner.
    Component {
        id: popupComponent
        ShellSurfaceItem {
            z: 10
            autoCreatePopupItems: true
            onSurfaceDestroyed: destroy()
            Timer { running: true; interval: 1500; onTriggered: console.info("luna: popup item", parent.x, parent.y, parent.width, parent.height, parent.visible, parent.surface) }
        }
    }
}
