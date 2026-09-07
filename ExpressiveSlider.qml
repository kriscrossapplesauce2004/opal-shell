import QtQuick
import QtQuick.Controls
Slider {
    id:s
    property string icon: "volume"
    from:0; to:100
    implicitHeight:56
    background: Rectangle {
        x:s.leftPadding; y:(s.height-height)/2; width:s.availableWidth; height:46; radius:16
        color:Theme.surfaceHigh
        Rectangle { width:Math.max(46,parent.width*s.visualPosition); height:parent.height; radius:s.pressed ? 12 : 16; color:Theme.primary
            Behavior on radius { NumberAnimation { duration:180 } }
        }
        Glyph { x:15; anchors.verticalCenter:parent.verticalCenter; name:s.icon; color:s.visualPosition>0.16 ? Theme.onPrimary : Theme.subtext; font.pixelSize:21 }
    }
    handle: Rectangle {
        x:s.leftPadding+s.visualPosition*(s.availableWidth-width)
        y:(s.height-height)/2; width:4; height:s.pressed ? 38 : 30; radius:2
        color:s.visualPosition>0.16 ? Theme.onPrimary : Theme.subtext
        Behavior on height { NumberAnimation { duration:160 } }
    }
    Accessible.name:icon
}
