import QtQuick
import Waylib.Server

// One layer-shell surface, placed by the Scene from its anchors and margins.
LayerSurfaceItem {
    id: item

    required property var layerSurface
    required property var shell

    // Place from Layers.arrange, in scene coordinates.
    property var place: ({ x: 0, y: 0, width: 0, height: 0 })

    shellSurface: layerSurface
    resizeMode: SurfaceItem.SizeFromSurface
    x: place.x
    y: place.y

    onPlaceChanged: shell.server.configureLayer(layerSurface, Qt.size(Math.round(place.width), Math.round(place.height)))

    function focusSurface() {
        shell.server.focusItem(item)
    }
}
