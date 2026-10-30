import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// One activity: lead icon or ring, text and optional controls. Used inside ActivityPill.
Item {
    id: seg
    // The activity map from ActivityModel.js.
    property var a: ({})
    property color ink: Theme.onSecondaryContainer
    property bool detailed: false
    property real maxWidth: 200
    property real reserve: 0
    property var output: null
    readonly property real progress: a.progress === undefined ? -1 : a.progress
    readonly property bool hasArt: a.kind === "media" && !!a.art
    readonly property real textMax: Math.max(48, maxWidth - 28 - 10 - reserve - (detailed ? ctl.implicitWidth + 8 : 0))
    implicitWidth: 28 + 10 + Math.min(textBlock.implicitWidth, textMax) + (detailed && ctl.visible ? ctl.implicitWidth + 8 : 0)
    implicitHeight: 32

    Item {
        id: lead
        width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            visible: seg.hasArt; anchors.fill: parent; radius: 14; color: Theme.secondary; clip: true
            Image { anchors.fill: parent; source: seg.a.art || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(64, 64) }
        }
        Rectangle {
            visible: !seg.hasArt && seg.progress < 0; anchors.fill: parent; radius: 14
            color: seg.a.kind === "recording" ? Theme.alpha(Theme.error, .22) : Theme.alpha(seg.ink, .14)
        }
        Shape {
            id: ring
            anchors.fill: parent; visible: seg.progress >= 0
            preferredRendererType: Shape.CurveRenderer
            property real value: seg.progress
            property color stroke: seg.ink
            ShapePath {
                strokeColor: Theme.alpha(ring.stroke, .25); strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 14; centerY: 14; radiusX: 11.5; radiusY: 11.5; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: ring.value > 0 ? ring.stroke : "transparent"; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 14; centerY: 14; radiusX: 11.5; radiusY: 11.5; startAngle: -90; sweepAngle: 360 * Math.min(1, ring.value) }
            }
        }
        Glyph {
            anchors.centerIn: parent; visible: !seg.hasArt; name: seg.a.icon || "spark"
            font.pixelSize: seg.progress >= 0 ? 13 : 16
            color: seg.a.kind === "recording" ? Theme.error : seg.ink
        }
    }
    Column {
        id: textBlock
        anchors.left: lead.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
        MText {
            width: Math.min(implicitWidth, seg.textMax); elide: Text.ElideRight; text: seg.a.title || ""; role: "label"; font.weight: Font.DemiBold; color: seg.ink
            font.features: seg.a.kind === "focus" ? {"tnum": 1} : {}
        }
        MText {
            width: Math.min(implicitWidth, seg.textMax); visible: seg.detailed && text !== ""; elide: Text.ElideRight
            text: seg.a.subtitle || ""; role: "labelS"; color: Theme.alpha(seg.ink, .75)
        }
    }
    Row {
        id: ctl
        visible: seg.detailed && !!seg.a.controls && seg.a.controls.length > 0
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 0
        Repeater {
            model: seg.a.controls || []
            MButton {
                required property var modelData
                icon: modelData.icon || ""; text: modelData.label || ""; compact: true; contained: !modelData.icon
                implicitWidth: modelData.icon ? 32 : 76; implicitHeight: 32
                ink: seg.ink; tooltip: modelData.label || modelData.id
                onClicked: Activities.control(seg.a, modelData)
            }
        }
    }
}
