import QtQuick
// Stand-in for Quickshell Variants: one delegate per model entry, parented to this Item.
Item {
    id: root
    property var model: []
    property Component delegate: null
    Instantiator {
        model: root.model
        delegate: root.delegate
        onObjectAdded: (index, object) => { object.parent = root }
    }
}
