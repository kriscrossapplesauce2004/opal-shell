import QtQuick
import QtQuick.Controls
Slider {
    id:s
    property string icon:"volume"
    from:0;to:100
    stepSize:5
    wheelEnabled:true
    implicitHeight:60
    leftPadding:0;rightPadding:0
    readonly property real thumbX:leftPadding+visualPosition*(availableWidth-4)
    background:Item {
        x:s.leftPadding;y:(s.height-height)/2;width:s.availableWidth;height:44
        // Clip the rounded outer ends to leave flat inner edges beside the handle.
        Item {
            width:Math.max(0,s.thumbX-s.leftPadding-6);height:parent.height;clip:true
            Rectangle {width:parent.width+16;height:parent.height;radius:14;color:Theme.primary}
        }
        Item {
            x:s.thumbX-s.leftPadding+10;width:Math.max(0,parent.width-x);height:parent.height;clip:true
            Rectangle {x:-16;width:parent.width+16;height:parent.height;radius:14;color:Theme.surfaceHigh}
        }
        Glyph {
            x:12;anchors.verticalCenter:parent.verticalCenter;name:s.icon;font.pixelSize:22
            color:Theme.subtext
            visible:s.availableWidth>64
        }
        Item {
            width:Math.max(0,s.thumbX-s.leftPadding-6);height:parent.height;clip:true
            Glyph {x:12;anchors.verticalCenter:parent.verticalCenter;name:s.icon;font.pixelSize:22;color:Theme.primaryText;visible:s.availableWidth>64}
        }
    }
    handle:Rectangle {
        x:s.thumbX;y:(s.height-height)/2;width:4;height:s.pressed ? 58 : 54;radius:2
        color:Theme.primary
        Behavior on height {NumberAnimation {duration:Theme.motion(160)}}
    }
    Accessible.name:icon
}
