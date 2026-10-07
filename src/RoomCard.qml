import QtQuick
import QtQuick.Layouts

// One room drawn as it is laid out: each window keeps its real place and size on the room's monitor.
Rectangle {
    id:card
    property var room:null
    property bool current:false
    property bool previews:true
    signal entered()
    radius:30
    color:Theme.alpha(Theme.level(3),.96)
    RowLayout {
        id:head;x:18;y:14;width:parent.width-36;spacing:8
        MText {text:card.room ? card.room.id : "";role:"titleS";color:Theme.primary}
        MText {text:card.room ? card.room.name : "";role:"titleS";Layout.fillWidth:true;elide:Text.ElideRight}
        MText {visible:card.current;text:"Here";role:"labelS";color:Theme.primary}
        MText {visible:!card.current&&!!card.room;text:card.room ? card.room.windows.length+(card.room.windows.length===1 ? " window" : " windows") : "";role:"labelS";color:Theme.subtext}
    }
    TapHandler {onTapped:card.entered()}
    // The miniature keeps the monitor's aspect and sits centred in the space left under the header.
    Item {
        id:area
        anchors {left:parent.left;right:parent.right;top:head.bottom;bottom:parent.bottom;margins:12;topMargin:10}
        readonly property real aspect:card.room&&card.room.aspect>0 ? card.room.aspect : 16/9
        readonly property real boxW:Math.min(width,Math.max(height*aspect*1.4,width*.8))
        Item {
            id:box
            anchors.centerIn:parent
            width:area.boxW;height:area.height
            Repeater {
                model:card.room ? card.room.tiles.slice().sort((a,b)=>(a.floating?1:0)-(b.floating?1:0)) : []
                Rectangle {
                    id:tile
                    required property var modelData
                    readonly property bool focused:Hub.active(modelData.window)
                    x:modelData.x*box.width+2;y:modelData.y*box.height+2
                    width:Math.max(24,modelData.w*box.width-4);height:Math.max(24,modelData.h*box.height-4)
                    radius:12;clip:true
                    color:Theme.level(1)
                    border.width:focused ? 2 : modelData.floating ? 1 : 0
                    border.color:focused ? Theme.primary : Theme.outline
                    // Live picture where the compositor can give one; the icon tile stays under it as the fallback.
                    Column {
                        anchors.centerIn:parent;spacing:4;width:parent.width-12
                        visible:!(preview.item&&preview.item.hasContent)
                        AppIcon {anchors.horizontalCenter:parent.horizontalCenter;width:Math.min(32,tile.height*.4);height:width;app:tile.modelData.app;name:tile.modelData.app ? tile.modelData.app.icon : (tile.modelData.window.className||"")}
                        MText {visible:tile.height>64;width:parent.width;horizontalAlignment:Text.AlignHCenter;text:tile.modelData.title;role:"labelS";color:Theme.subtext;elide:Text.ElideRight}
                    }
                    Loader {
                        id:preview
                        anchors.fill:parent;anchors.margins:tile.border.width
                        active:card.previews&&Rooms.live&&tile.modelData.address!==""&&card.visible
                        source:active ? "RoomPreview.qml" : ""
                        onLoaded:item.address=tile.modelData.address
                    }
                    TapHandler {onTapped:{Rooms.focus(tile.modelData);}}
                }
            }
            MText {
                anchors.centerIn:parent
                visible:!!card.room&&card.room.tiles.length===0
                text:"Empty room";role:"label";color:Theme.subtext
            }
        }
    }
    Accessible.role:Accessible.Button
    Accessible.name:card.room ? "Room "+card.room.id+", "+card.room.name : "Room"
}
