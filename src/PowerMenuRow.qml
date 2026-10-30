import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// One row of the power key menu. sel runs 0..1 so the ink can blend while the drum rolls.
Item {
    id:r
    property var entry:({})
    property real sel:0
    property real ring:-1
    property bool locked:false
    signal tapped()
    readonly property bool blocked:locked&&!!entry.secure
    readonly property color ink:Theme.mix(Theme.text,entry.danger ? Theme.error : Theme.containerInk,sel)
    MouseArea {anchors.fill:parent;onClicked:r.tapped()}
    RowLayout {
        anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:14;spacing:14
        Item {
            Layout.preferredWidth:38;Layout.preferredHeight:38
            Rectangle {anchors.fill:parent;radius:width/2;color:Theme.alpha(r.entry.danger ? Theme.error : Theme.primary,.16);opacity:r.sel}
            Image {
                id:avatar
                anchors.fill:parent;visible:!!r.entry.avatar&&status===Image.Ready
                source:r.entry.avatar||"";fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(76,76);asynchronous:true
            }
            Glyph {anchors.centerIn:parent;visible:!avatar.visible;name:r.entry.icon||"";font.pixelSize:22;color:r.entry.danger ? Theme.error : r.sel>.5 ? r.ink : Theme.primary;opacity:r.blocked ? .45 : 1}
            // Countdown to sleep around the icon.
            Shape {
                id:ringShape
                anchors.fill:parent;anchors.margins:-4;visible:r.ring>=0
                preferredRendererType:Shape.CurveRenderer
                readonly property real value:r.ring
                readonly property real arcR:Math.min(width,height)/2-1.6-1
                ShapePath {
                    strokeColor:Theme.alpha(Theme.containerInk,.25);strokeWidth:3.2;fillColor:"transparent";capStyle:ShapePath.RoundCap
                    PathAngleArc {centerX:ringShape.width/2;centerY:ringShape.height/2;radiusX:ringShape.arcR;radiusY:ringShape.arcR;startAngle:0;sweepAngle:360}
                }
                ShapePath {
                    strokeColor:ringShape.value>0 ? Theme.containerInk : "transparent";strokeWidth:3.2;fillColor:"transparent";capStyle:ShapePath.RoundCap
                    PathAngleArc {centerX:ringShape.width/2;centerY:ringShape.height/2;radiusX:ringShape.arcR;radiusY:ringShape.arcR;startAngle:-90;sweepAngle:360*Math.max(0,Math.min(1,ringShape.value))}
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth:true;spacing:0
            MText {Layout.fillWidth:true;visible:!!r.entry.group;text:String(r.entry.group||"").toUpperCase();role:"labelS";font.pixelSize:9;font.letterSpacing:1;color:Theme.alpha(r.ink,.65);elide:Text.ElideRight}
            MText {Layout.fillWidth:true;text:r.entry.label||"";role:"title";font.pixelSize:17;color:r.ink;opacity:r.blocked ? .5 : 1;elide:Text.ElideRight}
            MText {
                Layout.fillWidth:true;visible:text!==""&&!r.entry.group;role:"bodyS";color:Theme.alpha(r.ink,.72);elide:Text.ElideRight
                text:r.ring>=0 ? "Sleeping in "+Math.max(1,Math.ceil((1-r.ring)*PowerKey.countdownMs/1000))+" s" : r.blocked ? "Unlock to use" : (r.entry.detail||"")
            }
        }
        Glyph {
            visible:r.blocked||!!r.entry.sub||r.entry.on===true
            name:r.blocked ? "lock" : r.entry.on===true&&!r.entry.sub ? "check" : "chevron_right"
            font.pixelSize:20;color:Theme.alpha(r.ink,.8)
        }
    }
}
