import QtQuick
import QtQuick.Layouts
// M3 Expressive connected button group. Selection changes colour only; a pressed segment squishes wider for a moment.
RowLayout {
    id:group
    property var options:[]
    property var current:null
    property bool enabledAll:true
    property real buttonHeight:48
    signal picked(var value)
    spacing:2
    Repeater {
        model:group.options
        Rectangle {
            id:segment
            required property var modelData
            required property int index
            readonly property bool selected:modelData.value===group.current
            readonly property bool first:index===0
            readonly property bool last:index===group.options.length-1
            property real squish:press.pressed ? 1 : 0
            Behavior on squish {NumberAnimation {duration:Theme.motion(press.pressed ? 90 : 260);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}}
            Layout.fillWidth:true;Layout.preferredHeight:group.buttonHeight
            Layout.horizontalStretchFactor:Math.round(100+squish*22)
            topLeftRadius:first ? height/2 : 8;bottomLeftRadius:topLeftRadius
            topRightRadius:last ? height/2 : 8;bottomRightRadius:topRightRadius
            color:selected ? Theme.primary : Theme.alpha(Theme.light ? "#ffffff" : Theme.glassRaised,Theme.light ? .8 : .6)
            opacity:group.enabledAll ? 1 : .45
            Behavior on color {ColorAnimation {duration:Theme.motion(180)}}
            Rectangle {anchors.fill:parent;topLeftRadius:parent.topLeftRadius;topRightRadius:parent.topRightRadius;bottomLeftRadius:parent.bottomLeftRadius;bottomRightRadius:parent.bottomRightRadius;color:segment.selected ? Theme.onPrimary : Theme.stateLayer;opacity:press.pressed ? .12 : press.containsMouse ? .06 : 0}
            Row {
                anchors.centerIn:parent;spacing:6
                Glyph {visible:!!segment.modelData.icon||segment.selected;name:segment.selected&&!segment.modelData.icon ? "check" : segment.modelData.icon||"";font.pixelSize:18;color:segment.selected ? Theme.onPrimary : Theme.text;anchors.verticalCenter:parent.verticalCenter}
                MText {text:segment.modelData.label;font.pixelSize:13;font.weight:Font.Medium;color:segment.selected ? Theme.onPrimary : Theme.text;anchors.verticalCenter:parent.verticalCenter}
            }
            MouseArea {id:press;anchors.fill:parent;enabled:group.enabledAll;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:group.picked(segment.modelData.value)}
            Accessible.role:Accessible.RadioButton;Accessible.name:modelData.label;Accessible.checked:selected
        }
    }
}
