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
    // Recent files and games feed Pick up; the phone home is not the only reader.
    Component.onCompleted:PhoneState.refreshActivity()
    Timer {interval:300000;repeat:true;running:true;onTriggered:PhoneState.refreshActivity()}

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
                    visible:!Hub.focusRunning&&Hub.focusSeconds>=25*60
                    icon:"timer";text:"Focus";host:widgets.host
                    sheetWidth:360;sheetHeight:180
                    sheet:Component {FocusCard {anchors.fill:parent;anchors.margins:4}}
                }
                MorphChip {
                    icon:Hub.status.wifi ? "wifi" : "wifi_off";text:Hub.status.wifi ? (Hub.status.network||"Wi-Fi") : "Offline";host:widgets.host
                    sheetWidth:380;sheetHeight:400
                    sheet:Component {ConnectionPanel {anchors.fill:parent;anchors.margins:12;kind:"wifi";embedded:true}}
                }
                MorphChip {
                    visible:Hub.status.battery>=0
                    icon:Hub.status.charging ? "battery_charging_full" : Hub.status.battery<=20 ? "battery_alert" : "battery_5_bar"
                    text:Hub.status.battery+"%";selected:Hub.status.battery<=20&&!Hub.status.charging
                }
                MorphChip {
                    icon:Hub.prefs.dnd ? "do_not_disturb_on" : "notifications_active";text:Hub.prefs.dnd ? "Quiet" : "Alerts on";selected:!!Hub.prefs.dnd
                    onClicked:Hub.set("dnd",!Hub.prefs.dnd)
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

    // Rooms: every workspace with its real layout. The one you are on is marked; an empty one is a small "+" tile.
    Item {
        id:roomsCard
        readonly property var shown:Rooms.list.filter(r=>r.windows.length>0||r.id===Rooms.current).slice(0,6)
        visible:Rooms.live&&widgets.available>=560&&shown.length>0
        width:parent.width;height:visible ? roomsColumn.implicitHeight+28 : 0
        Frost {anchors.fill:parent;radius:28;backdrop:widgets.backdrop}
        Column {
            id:roomsColumn;x:14;y:14;width:parent.width-28;spacing:10
            RowLayout {
                width:parent.width
                MText {text:"ROOMS";role:"labelS";color:Theme.primary;font.letterSpacing:1.3;Layout.fillWidth:true;leftPadding:4}
                MText {text:Rooms.list.filter(r=>r.windows.length).length+" in use";role:"labelS";color:Theme.subtext}
            }
            Grid {
                id:roomGrid
                columns:2;spacing:8;width:parent.width
                readonly property real cell:(width-spacing)/2
                Repeater {
                    model:roomsCard.shown
                    Item {
                        id:roomTile
                        required property var modelData
                        readonly property bool here:modelData.id===Rooms.current
                        width:roomGrid.cell;height:modelData.windows.length ? 128 : 56
                        RoomCard {
                            anchors.fill:parent;visible:roomTile.modelData.windows.length>0
                            room:roomTile.modelData;current:roomTile.here;previews:false;radius:18
                            color:roomTile.here ? Theme.alpha(Theme.secondaryContainer,.9) : Theme.alpha(Theme.level(2),.8)
                            border.width:roomTile.here ? 2 : 0;border.color:Theme.primary
                            onEntered:Rooms.enter(roomTile.modelData)
                        }
                        Rectangle {
                            anchors.fill:parent;visible:roomTile.modelData.windows.length===0;radius:18
                            color:"transparent";border.width:roomTile.here ? 2 : 1;border.color:roomTile.here ? Theme.primary : Theme.outline
                            Row {anchors.centerIn:parent;spacing:6
                                MText {text:roomTile.modelData.id;role:"label";color:Theme.primary}
                                MText {text:roomTile.here ? "You are here" : "Empty";role:"labelS";color:Theme.subtext}}
                        }
                    }
                }
            }
            Flow {
                width:parent.width;spacing:6
                MorphChip {icon:"add";text:"New room";onClicked:Rooms.newRoom()}
                MorphChip {icon:"grid_view";text:"All apps";onClicked:Hub.openStart(false)}
            }
        }
    }
}
