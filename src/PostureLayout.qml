import QtQuick

// Hinge-aware layout for foldables. Book puts the two parts on each side of the hinge, tabletop puts them above and below it, and flat gives the first part the full screen.
Item {
    id: fold
    property string posture: "flat"
    // The hinge band that content must not cross, in pixels, and where its centre is, as a fraction of the width or the height.
    property real hinge: 0
    property real at: .5
    property Component first
    property Component second
    readonly property bool book: posture === "book"
    readonly property bool tabletop: posture === "tabletop"
    readonly property bool split: book || tabletop
    readonly property real cut: (book ? width : height) * at
    readonly property alias firstItem: one.item
    readonly property alias secondItem: two.item

    Loader {
        id: one
        sourceComponent: fold.first
        x: 0; y: 0
        width: fold.book ? fold.cut - fold.hinge / 2 : fold.width
        height: fold.tabletop ? fold.cut - fold.hinge / 2 : fold.height
    }
    Loader {
        id: two
        active: fold.split
        sourceComponent: fold.second
        x: fold.book ? fold.cut + fold.hinge / 2 : 0
        y: fold.tabletop ? fold.cut + fold.hinge / 2 : 0
        width: fold.book ? fold.width - x : fold.width
        height: fold.tabletop ? fold.height - y : fold.height
    }
}
