import QtQuick
import QtQuick.Layouts

// The power key menu on screen: a drum picker in a sheet beside the power key, with hints at the volume keys.
// It fills its parent. The parent forwards keys to handleKey().
Item {
    id:menu
    property bool locked:false
    readonly property bool shown:PowerKey.open&&reveal>0
    property real reveal:PowerKey.open ? 1 : 0
    Behavior on reveal {NumberAnimation {duration:Theme.motion(PowerKey.open ? 260 : 180);easing.type:PowerKey.open ? Easing.OutCubic : Easing.InCubic}}
    visible:reveal>0
    readonly property var place:PowerKey.keyPlace(PowerKey.device.power)
    readonly property var volumePlace:PowerKey.keyPlace(PowerKey.device.volume)
    readonly property bool vertical:place.edge==="left"||place.edge==="right"
    // Without a hardware key beside it (a desktop shortcut or the controller) the sheet sits in the middle.
    readonly property bool centred:PowerKey.source!=="key"&&!PowerKey.device.handset
    readonly property real rowH:58
    readonly property int visibleRows:Math.min(5,Math.max(3,Math.floor((height-120)/rowH)))
    // The drum position follows the selection, and a finger drag moves it directly.
    property real pos:PowerKey.index
    property bool dragging:false
    Behavior on pos {enabled:!menu.dragging;NumberAnimation {duration:Theme.motion(200);easing.type:Easing.OutCubic}}
    Connections {target:PowerKey;function onIndexChanged() {if(!menu.dragging)menu.pos=PowerKey.index;}function onStackChanged() {menu.dragging=false;menu.pos=PowerKey.index;}}

    function handleKey(event) {
        if(!PowerKey.open)return false;
        const k=event.key;
        if(k===Qt.Key_VolumeUp||k===Qt.Key_Up||k===Qt.Key_Backtab){PowerKey.move(-1);}
        else if(k===Qt.Key_VolumeDown||k===Qt.Key_Down||k===Qt.Key_Tab){PowerKey.move(1);}
        else if(k===Qt.Key_PowerOff||k===Qt.Key_PowerDown||k===Qt.Key_Sleep||k===Qt.Key_Return||k===Qt.Key_Enter||k===Qt.Key_Space||k===Qt.Key_Right){if(!event.isAutoRepeat)PowerKey.pick();}
        else if(k===Qt.Key_Escape||k===Qt.Key_Back||k===Qt.Key_Left||k===Qt.Key_Backspace){PowerKey.goBack();}
        else if(k===Qt.Key_Home){PowerKey.select(0);}
        else if(k===Qt.Key_End){PowerKey.select(PowerKey.rows.length-1);}
        else return false;
        event.accepted=true;
        return true;
    }

    // Scrim: tap outside the sheet to close.
    Rectangle {anchors.fill:parent;color:"#000000";opacity:.4*menu.reveal}
    MouseArea {anchors.fill:parent;enabled:PowerKey.open;onClicked:PowerKey.close()}

    // Hints sit at the physical keys: arrows at the volume rocker, a dot at the power key when it is not beside the sheet.
    component KeyHint:Rectangle {
        property string glyph:""
        width:34;height:34;radius:17
        color:Theme.alpha(Theme.level(3),.94)
        border.width:1;border.color:Theme.outline
        Glyph {anchors.centerIn:parent;name:parent.glyph;font.pixelSize:20}
    }
    Item {
        id:volumeHints
        visible:PowerKey.source==="key"
        opacity:menu.reveal
        readonly property bool side:menu.volumePlace.edge==="left"||menu.volumePlace.edge==="right"
        readonly property real along:(side ? menu.height : menu.width)*menu.volumePlace.at
        x:menu.volumePlace.edge==="left" ? 8 : menu.volumePlace.edge==="right" ? menu.width-width-8 : along-width/2
        y:menu.volumePlace.edge==="top" ? 8 : menu.volumePlace.edge==="bottom" ? menu.height-height-8 : along-height/2
        width:side ? 34 : 76;height:side ? 76 : 34
        // Hidden where the sheet would cover it.
        KeyHint {glyph:"keyboard_arrow_up";x:0;y:0}
        KeyHint {glyph:"keyboard_arrow_down";x:volumeHints.side ? 0 : 42;y:volumeHints.side ? 42 : 0}
        z:sheet.overlapsVolume ? -1 : 1
    }

    Rectangle {
        id:sheet
        readonly property real along:(menu.vertical ? menu.height : menu.width)*menu.place.at
        readonly property real slide:(1-menu.reveal)*(width+24)
        readonly property bool overlapsVolume:menu.volumePlace.edge===menu.place.edge
        width:Math.min(menu.width-(overlapsVolume ? 64 : 24),300)
        height:drum.height+header.height+16
        radius:30
        color:Theme.level(3)
        border.width:1;border.color:Theme.outline
        x:menu.centred ? (menu.width-width)/2 : menu.place.edge==="right" ? menu.width-width-(overlapsVolume&&menu.volumePlace.edge==="right" ? 52 : 12)+slide
          : menu.place.edge==="left" ? 12-slide+(overlapsVolume&&menu.volumePlace.edge==="left" ? 40 : 0)
          : Math.max(12,Math.min(menu.width-width-12,along-width/2))
        y:menu.centred ? (menu.height-height)/2+(1-menu.reveal)*24 : menu.vertical ? Math.max(56,Math.min(menu.height-height-56,along-height*.45))
          : menu.place.edge==="top" ? 56-(1-menu.reveal)*(height+60) : menu.height-height-56+(1-menu.reveal)*(height+60)
        opacity:Math.min(1,menu.reveal*1.6)
        // Swallow taps so the scrim behind does not close the menu.
        MouseArea {anchors.fill:parent}

        MText {
            id:header
            x:20;y:12;width:parent.width-40
            height:PowerKey.stack.length ? 24 : 0;visible:height>0
            text:PowerKey.stack.length ? PowerKey.nodeLabel(PowerKey.stack[PowerKey.stack.length-1]).toUpperCase() : ""
            role:"labelS";color:Theme.subtext;font.letterSpacing:1.2;elide:Text.ElideRight
        }
        Item {
            id:drum
            x:8;y:8+header.height;width:parent.width-16
            height:menu.visibleRows*menu.rowH
            clip:true
            readonly property real centreY:height/2-menu.rowH/2
            // The highlight stays in the centre; rows roll past it.
            Rectangle {
                y:drum.centreY;width:parent.width;height:menu.rowH;radius:height/2
                color:PowerKey.current&&PowerKey.current.danger ? Theme.alpha(Theme.error,.24) : Theme.primaryContainer
                Behavior on color {ColorAnimation {duration:Theme.motion(140)}}
            }
            Repeater {
                model:PowerKey.rows
                PowerMenuRow {
                    required property var modelData
                    required property int index
                    readonly property real dist:Math.abs(index-menu.pos)
                    readonly property real slot:drum.centreY+(index-menu.pos)*menu.rowH
                    width:drum.width;height:menu.rowH;y:slot
                    entry:modelData;sel:Math.max(0,1-dist);locked:menu.locked
                    ring:dist<.5&&modelData.id==="sleep" ? PowerKey.countdown : -1
                    opacity:Math.max(0,1-Math.max(0,dist-.6)*.4)
                    visible:slot>-menu.rowH&&slot<drum.height
                    onTapped:{if(index===PowerKey.index)PowerKey.pick();else{PowerKey.select(index);PowerKey.pick();}}
                }
            }
            // A finger flicks the drum; it settles on the nearest row.
            DragHandler {
                id:drag
                target:null;yAxis.enabled:true;xAxis.enabled:false
                property real startPos:0
                onActiveChanged:{
                    if(active){PowerKey.stopCountdown();startPos=menu.pos;menu.dragging=true;}
                    else {const i=Math.max(0,Math.min(PowerKey.rows.length-1,Math.round(menu.pos)));menu.dragging=false;PowerKey.select(i);menu.pos=i;}
                }
                onTranslationChanged:if(active)menu.pos=Math.max(-.4,Math.min(PowerKey.rows.length-.6,startPos-translation.y/menu.rowH))
            }
            WheelHandler {onWheel:e=>PowerKey.move(e.angleDelta.y>0 ? -1 : 1)}
        }
    }
}
