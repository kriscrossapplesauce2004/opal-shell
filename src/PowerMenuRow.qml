import QtQuick
import QtQuick.Layouts

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
            Canvas {
                id:ringCanvas
                anchors.fill:parent;anchors.margins:-4;visible:r.ring>=0
                property real value:r.ring
                onValueChanged:requestPaint()
                onPaint:{
                    const c=getContext("2d");c.reset();if(value<0)return;
                    const lw=3.2, rad=Math.min(width,height)/2-lw/2-1;
                    c.lineWidth=lw;c.lineCap="round";c.strokeStyle=String(Theme.containerInk);
                    c.globalAlpha=.25;c.beginPath();c.arc(width/2,height/2,rad,0,2*Math.PI);c.stroke();
                    c.globalAlpha=1;c.beginPath();c.arc(width/2,height/2,rad,-Math.PI/2,-Math.PI/2+2*Math.PI*value);c.stroke();
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
