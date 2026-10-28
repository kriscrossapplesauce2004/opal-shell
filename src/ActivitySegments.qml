import QtQuick

// Segmented activity pill: one pill split into segments with small gaps, one per activity. The first, most urgent one leads and shows its label.
Row {
    id: segs
    // Activity maps from ActivityModel.js, most urgent first.
    property var items: Activities.list
    // Every segment shows its label, as on hover.
    property bool labels: false
    // Calm: icons and short values only, and at most two segments.
    property bool calm: Activities.calm
    property int maxSegments: calm ? 2 : 4
    property real size: 44
    property real maxLabel: 180
    property string selectedId: ""
    property color fill: Theme.level(3)
    signal picked(var a)
    // Past the limit, the last segment folds the rest into a count.
    readonly property bool overflow: items.length > maxSegments
    readonly property var shown: overflow ? items.slice(0, maxSegments - 1) : items
    readonly property int hidden: overflow ? items.length - shown.length : 0
    readonly property int count: shown.length + (overflow ? 1 : 0)
    spacing: 3
    Repeater {
        model: segs.shown
        Rectangle {
            id: seg
            required property var modelData
            required property int index
            readonly property var a: modelData
            readonly property string kind: a.kind || "neutral"
            readonly property bool lead: index === 0
            readonly property bool selected: segs.selectedId !== "" && a.id === segs.selectedId
            readonly property real progress: a.progress === undefined ? -1 : a.progress
            // The lead keeps the tint of its kind; the rest stay calm.
            readonly property bool tinted: lead && ActivityStyle.tone(kind) !== "neutral" && ActivityStyle.tone(kind) !== "media"
            readonly property color ink: selected ? Theme.onContainer : tinted ? ActivityStyle.ink(kind) : Theme.text
            readonly property string label: segs.calm ? (lead ? (a.short || "") : "") : (segs.labels || lead) ? (a.title || a.short || "") : (a.short || "")
            height: segs.size
            width: content.implicitWidth + (label !== "" ? 26 : 20)
            topLeftRadius: index === 0 ? height / 2 : 6; bottomLeftRadius: topLeftRadius
            topRightRadius: index === segs.count - 1 ? height / 2 : 6; bottomRightRadius: topRightRadius
            color: selected ? Theme.primaryContainer : tinted ? ActivityStyle.fill(kind) : segs.fill
            clip: true
            Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
            // Progress fills the segment from the left.
            Rectangle {
                visible: seg.progress >= 0
                width: parent.width * Math.max(0, Math.min(1, seg.progress)); height: parent.height
                topLeftRadius: parent.topLeftRadius; bottomLeftRadius: parent.bottomLeftRadius
                color: Theme.alpha(seg.selected ? Theme.onContainer : Theme.primary, .2)
                Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium) } }
            }
            Rectangle { anchors.fill: parent; radius: 6; topLeftRadius: parent.topLeftRadius; bottomLeftRadius: parent.bottomLeftRadius; topRightRadius: parent.topRightRadius; bottomRightRadius: parent.bottomRightRadius
                color: Theme.stateLayer; opacity: tap.pressed ? .12 : hover.hovered ? .06 : 0 }
            Row {
                id: content
                anchors.centerIn: parent; spacing: 7
                Rectangle { visible: seg.kind === "recording"; width: 9; height: 9; radius: 5; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                RoundedImage { visible: !!seg.a.art; source: seg.a.art || ""; radius: 6; width: segs.size * .5; height: width; decodeSize: Qt.size(64, 64); anchors.verticalCenter: parent.verticalCenter }
                Glyph {
                    visible: !seg.a.art && seg.kind !== "recording"; name: seg.a.icon || "spark"; font.pixelSize: segs.size * .42
                    color: seg.selected || ActivityStyle.tone(seg.kind) === "neutral" ? seg.ink : ActivityStyle.accent(seg.kind); anchors.verticalCenter: parent.verticalCenter
                }
                Glyph { visible: seg.kind === "media" && !!seg.a.playing; name: "graphic_eq"; font.pixelSize: segs.size * .4; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                MText {
                    visible: seg.label !== ""; text: seg.label; role: "label"; font.weight: Font.DemiBold; color: seg.ink
                    width: Math.min(implicitWidth, segs.maxLabel); elide: Text.ElideRight; font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter
                }
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: tap; onTapped: segs.picked(seg.a) }
            Accessible.role: Accessible.Button
            Accessible.name: (seg.a.title || "Activity") + (seg.a.subtitle ? ", " + seg.a.subtitle : "")
            Accessible.onPressAction: segs.picked(seg.a)
        }
    }
    // The folded rest.
    Rectangle {
        visible: segs.overflow
        height: segs.size; width: moreText.implicitWidth + 22
        topLeftRadius: 6; bottomLeftRadius: 6; topRightRadius: height / 2; bottomRightRadius: height / 2
        color: segs.fill
        MText { id: moreText; anchors.centerIn: parent; text: "+" + segs.hidden; role: "label"; font.weight: Font.Bold }
        TapHandler { onTapped: segs.picked(segs.items[segs.shown.length]) }
        Accessible.role: Accessible.Button
        Accessible.name: segs.hidden + " more activities"
    }
}
