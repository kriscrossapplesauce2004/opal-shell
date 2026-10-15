import QtQuick

// Compact pill for one activity: lead art or glyph, a short label, a progress ring and a count of the activities behind it.
Rectangle {
    id: chip
    // The activity map from ActivityModel.js.
    property var a: ({})
    property int more: 0
    property bool selected: false
    readonly property string kind: a.kind || "neutral"
    readonly property color ink: ActivityStyle.ink(kind)
    readonly property real progress: a.progress === undefined ? -1 : a.progress
    readonly property string label: a.short !== undefined ? a.short : (a.title || "")
    signal clicked()
    implicitHeight: 30
    implicitWidth: row.implicitWidth + (label !== "" ? 22 : 16)
    radius: height / 2
    color: ActivityStyle.fill(kind)
    border.width: selected ? 2 : 0
    border.color: ActivityStyle.tone(kind) === "neutral" ? Theme.primary : ActivityStyle.accent(kind)
    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
    Row {
        id: row
        anchors.centerIn: parent; spacing: 6
        Rectangle { visible: chip.kind === "recording"; width: 8; height: 8; radius: 4; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
        RoundedImage { visible: !!chip.a.art; source: chip.a.art || ""; radius: 6; width: 20; height: 20; decodeSize: Qt.size(64, 64); anchors.verticalCenter: parent.verticalCenter }
        Glyph {
            visible: !chip.a.art && chip.kind !== "recording"; name: chip.a.icon || "spark"; font.pixelSize: 17
            color: ActivityStyle.tone(chip.kind) === "neutral" ? chip.ink : ActivityStyle.accent(chip.kind); anchors.verticalCenter: parent.verticalCenter
        }
        MText {
            visible: chip.label !== ""; text: chip.label; role: "label"; font.weight: Font.DemiBold; color: chip.ink
            width: Math.min(implicitWidth, 150); font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter
        }
        Glyph { visible: chip.kind === "media" && !!chip.a.playing; name: "graphic_eq"; font.pixelSize: 17; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        ProgressRing { visible: chip.progress >= 0; value: chip.progress; ink: chip.ink; lineWidth: 2.6; width: 17; height: 17; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            visible: chip.more > 0; width: 26; height: 20; radius: 10; color: Theme.alpha(chip.ink, .16); anchors.verticalCenter: parent.verticalCenter
            MText { anchors.centerIn: parent; text: "+" + chip.more; role: "labelS"; font.weight: Font.Bold; color: chip.ink }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    Accessible.role: Accessible.Button
    Accessible.name: (a.title || "Activity") + (more > 0 ? ", plus " + more + " more" : "")
}
