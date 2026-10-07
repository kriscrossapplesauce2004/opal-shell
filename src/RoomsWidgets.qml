import QtQuick
import QtQuick.Layouts

// Rooms desktop widgets: a glance with live chips, a card to pick up where you left off, and the current room. The taskbar is not changed.
Column {
    id:widgets
    property Item backdrop:null
    // Full-size item that holds the sheets that chips grow into.
    property Item host:null
    property real available:10000
    spacing:14

    // Glance: date, clock and live chips.
    Item {
        width:parent.width;height:glance.implicitHeight+32
        Frost {anchors.fill:parent;radius:28;backdrop:widgets.backdrop}
        Column {
            id:glance;x:18;y:16;width:parent.width-36;spacing:6
            MText {text:Qt.formatDate(Hub.now,"dddd d MMMM");role:"titleS"}
            MText {text:Qt.formatTime(Hub.now,"hh:mm");font.pixelSize:56;font.weight:Font.Black;font.features:{"tnum":1}}
            Flow {
                width:parent.width;spacing:8;topPadding:4
                MorphChip {
                    visible:Hub.status.track!==""
                    icon:"music_note";text:Hub.status.track;selected:Hub.status.playing;host:widgets.host
                    sheetWidth:380;sheetHeight:184
                    sheet:Component {MediaCard {anchors.fill:parent;anchors.margins:4}}
                }
                MorphChip {
                    visible:Notifier.inbox.length>0
                    icon:"notifications";text:String(Notifier.inbox.length);host:widgets.host
                    sheetWidth:400;sheetHeight:420
                    sheet:Component {Flickable {anchors.fill:parent;anchors.margins:12;contentHeight:groups.implicitHeight;clip:true
                        NotificationGroups {id:groups;width:parent.width}}}
                }
                MorphChip {
                    visible:Hub.focusRunning||Hub.focusSeconds<25*60
                    icon:"timer";text:"Focus "+Math.floor(Hub.focusSeconds/60)+":"+String(Hub.focusSeconds%60).padStart(2,"0");selected:Hub.focusRunning;host:widgets.host
                    sheetWidth:360;sheetHeight:180
                    sheet:Component {FocusCard {anchors.fill:parent;anchors.margins:4}}
                }
                MorphChip {
                    visible:Hub.status.track===""&&Notifier.inbox.length===0&&!Hub.focusRunning
                    icon:"timer";text:"Focus";host:widgets.host
                    sheetWidth:360;sheetHeight:180
                    sheet:Component {FocusCard {anchors.fill:parent;anchors.margins:4}}
                }
            }
        }
    }

    // Pick up: finished things as chips, then the Ladder.
    Item {
        visible:(Rooms.earlier.length>0||Rooms.ladder.length>0)&&widgets.available>=420
        width:parent.width;height:visible ? pickup.implicitHeight+32 : 0
        Frost {anchors.fill:parent;radius:28;backdrop:widgets.backdrop}
        Column {
            id:pickup;x:18;y:16;width:parent.width-36;spacing:10
            MText {text:"PICK UP";role:"labelS";color:Theme.primary;font.letterSpacing:1.3}
            Flow {
                visible:Rooms.earlier.length>0;width:parent.width;spacing:8
                Repeater {model:Rooms.earlier.slice(0,4);MorphChip {required property var modelData;icon:modelData.glyph;text:modelData.title;onClicked:Rooms.open(modelData)}}
            }
            Repeater {
                model:Rooms.ladder
                Item {
                    id:rung
                    required property var modelData
                    required property int index
                    readonly property real step:Rooms.ladder.length>1 ? index/(Rooms.ladder.length-1) : 1
                    width:pickup.width;height:rungRow.implicitHeight
                    opacity:.62+.38*step
                    RowLayout {
                        id:rungRow;width:parent.width;spacing:10
                        Item {
                            Layout.preferredWidth:20+6*rung.step;Layout.preferredHeight:Layout.preferredWidth
                            AppIcon {anchors.fill:parent;visible:!!rung.modelData.app;app:rung.modelData.app||null;style:"raw"}
                            Glyph {anchors.centerIn:parent;visible:!rung.modelData.app;name:rung.modelData.glyph||"history";font.pixelSize:parent.width*.8}
                        }
                        ColumnLayout {
                            Layout.fillWidth:true;spacing:0
                            MText {Layout.fillWidth:true;text:rung.modelData.title;font.pixelSize:13+4*rung.step;font.weight:rung.step===1 ? Font.DemiBold : Font.Medium;elide:Text.ElideRight}
                            MText {Layout.fillWidth:true;visible:text!=="";text:rung.modelData.meta;role:"labelS";color:Theme.subtext;elide:Text.ElideRight}
                        }
                    }
                    HoverHandler {cursorShape:Qt.PointingHandCursor}
                    TapHandler {onTapped:Rooms.open(rung.modelData)}
                }
            }
        }
    }

    // Rooms: the current workspace as it is laid out, and every room as a chip.
    Item {
        visible:Rooms.live&&widgets.available>=640
        width:parent.width;height:visible ? 250+roomChips.height : 0
        Frost {anchors.fill:parent;radius:28;backdrop:widgets.backdrop}
        RoomCard {
            x:0;y:0;width:parent.width;height:236
            color:"transparent"
            room:Rooms.currentRoom;current:true;previews:false
        }
        Flow {
            id:roomChips
            x:14;y:236;width:parent.width-28;spacing:6
            Repeater {model:Rooms.list
                MorphChip {required property var modelData;icon:"space_dashboard";text:modelData.id+" · "+modelData.name;selected:modelData.id===Rooms.current;onClicked:Rooms.enter(modelData)}}
            MorphChip {icon:"add";onClicked:Rooms.newRoom()}
        }
    }
}
