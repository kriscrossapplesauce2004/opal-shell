import QtQuick
import Quickshell
// Phone launcher icon: a round bubble with the app icon and an optional label. Long press opens the app menu.
Item {
    id:icon
    required property var app
    property bool label:true
    property real size:58
    property bool selected:false
    signal activated()
    // Drag out: a long press lifts the icon instead of opening the menu, and the finger then carries it. Points are in window coordinates.
    property bool dragOut:false
    signal lifted(real x, real y)
    signal dragged(real x, real y)
    signal dropped(real x, real y)
    implicitWidth:size+16
    implicitHeight:size+(label ? 30 : 8)
    // Pointer hover: a soft plate behind the icon and its label.
    Rectangle {anchors.fill:parent;radius:20;color:Theme.stateLayer;opacity:mouse.containsMouse&&!mouse.carrying ? .08 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(120)}}}
    Rectangle {
        id:bubble
        anchors.horizontalCenter:parent.horizontalCenter;y:4
        width:icon.size;height:width;radius:width*.3
        color:"transparent"
        border.width:icon.selected ? 3 : 0;border.color:Theme.primary
        opacity:mouse.carrying ? .35 : mouse.pressed ? .8 : 1
        scale:mouse.pressed&&!mouse.carrying ? .9 : 1
        Behavior on scale {NumberAnimation {duration:Theme.motion(120);easing.type:Easing.OutCubic}}
        AppIcon {anchors.fill:parent;anchors.margins:icon.selected ? 4 : 0;app:icon.app}
        // Running apps get a small dot under the bubble.
        Rectangle {
            visible:Hub.windows.some(w=>Hub.appForWindow(w)===icon.app)
            anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.bottom;anchors.topMargin:2
            width:5;height:5;radius:2.5;color:Theme.primary
        }
    }
    MText {
        visible:icon.label
        anchors.top:bubble.bottom;anchors.topMargin:7;anchors.horizontalCenter:parent.horizontalCenter
        width:icon.width-4;horizontalAlignment:Text.AlignHCenter
        text:icon.app.name;role:"label";color:Theme.text
    }
    OpalMenu {id:menu;title:icon.app.name;icon:"apps";entries:visible ? Hub.appMenu(icon.app) : []}
    MouseArea {
        id:mouse;anchors.fill:parent
        acceptedButtons:Qt.LeftButton|Qt.RightButton
        hoverEnabled:true;cursorShape:Qt.PointingHandCursor
        property bool carrying:false
        // A mouse carries the icon as soon as it moves; a finger needs the long press, so a swipe still scrolls the list.
        property bool mouseHold:false
        property point pressAt:Qt.point(0,0)
        preventStealing:carrying||mouseHold
        onPressed:e=>{mouseHold=icon.dragOut&&e.source===Qt.MouseEventNotSynthesized&&e.button===Qt.LeftButton;pressAt=Qt.point(e.x,e.y);}
        function scene(e) {return mouse.mapToItem(null,e.x,e.y);}
        onClicked:e=>{if(carrying)return;if(e.button===Qt.RightButton)menu.popup(e.x,e.y);else icon.activated();}
        onPressAndHold:e=>{if(icon.dragOut&&e.button===Qt.LeftButton){carrying=true;const p=scene(e);icon.lifted(p.x,p.y);}else menu.popup(e.x,e.y);}
        onPositionChanged:e=>{
            if(!carrying&&mouseHold&&Math.abs(e.x-pressAt.x)+Math.abs(e.y-pressAt.y)>10){carrying=true;const p=scene(e);icon.lifted(p.x,p.y);return;}
            if(carrying){const p=scene(e);icon.dragged(p.x,p.y);}
        }
        onReleased:e=>{mouseHold=false;if(carrying){carrying=false;const p=scene(e);icon.dropped(p.x,p.y);}}
        onCanceled:{mouseHold=false;if(carrying){carrying=false;icon.dropped(-1,-1);}}
    }
    Accessible.role:Accessible.Button
    Accessible.name:app.name
    Accessible.onPressAction:activated()
}
