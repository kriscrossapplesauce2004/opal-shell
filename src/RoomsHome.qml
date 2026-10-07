import QtQuick
import QtQuick.Layouts
import Quickshell

// Rooms home: a glance, finished things as chips, a short Ladder of recent things, the current room with its real layout, room chips, pins and search.
Item {
    id:home
    property bool editing:false
    readonly property bool wide:width>=760
    readonly property var room:Rooms.currentRoom
    // On a tablet the navigation bar holds the apps and search, so Rooms leaves them out.
    readonly property bool navDock:wide&&Hub.prefs.tabletDock!==false
    // On an empty room the card area shows every room instead of an empty card.
    readonly property bool overview:!!room&&room.windows.length===0&&Rooms.list.some(r=>r.windows.length>0)
    Component.onCompleted:PhoneState.refreshActivity()
    // Docked: rooms live on the monitor. The card shrinks into its chip and the chip row moves to the top.
    property bool docked:Hub.docked
    property real dockT:docked ? 1 : 0
    // Tests set this to show one frame of the dock morph.
    property bool holdDock:false
    Behavior on dockT {enabled:!home.holdDock;NumberAnimation {duration:Theme.motion(560);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized}}
    readonly property string dockName:{const m=Hub.monitors.find(m=>m.name===Hub.dockOutput);return m&&m.description ? m.description.replace(/\s+\(?[A-Z]{2,4}-[A-Z0-9-]+\)?$/,"") : (Hub.dockOutput||"monitor");}
    signal dragProgress(real value)
    signal dragFinished(bool open)
    signal openDrawer(bool search)

    // Light scrim at the top for the glance, heavier where the room and bar sit.
    Rectangle {
        anchors.fill:parent
        gradient:Gradient {
            GradientStop {position:0;color:Theme.alpha(Theme.base,.08)}
            GradientStop {position:.38;color:Theme.alpha(Theme.base,.42)}
            GradientStop {position:1;color:Theme.alpha(Theme.base,.9)}
        }
    }

    // Up opens the drawer, down opens the shade.
    DragHandler {
        target:null;xAxis.enabled:false;yAxis.enabled:true
        grabPermissions:PointerHandler.CanTakeOverFromItems
        onTranslationChanged:if(active&&translation.y<0)home.dragProgress(Math.min(1,-translation.y/(home.height*.55)))
        onActiveChanged:{
            if(active)return;
            if(translation.y>70){home.dragProgress(0);Hub.page="controls";return;}
            home.dragFinished(-translation.y/(home.height*.55)>.28||centroid.velocity.y<-600);
        }
    }

    // ---- Left column (the whole width on a phone): glance, Earlier, Ladder.
    Column {
        id:story
        x:24;y:12;width:home.wide ? Math.min(440,home.width*.36) : home.width-48
        spacing:10
        MText {text:Qt.formatDate(Hub.now||new Date(),"dddd d MMMM");role:"titleS"}
        MText {
            text:Qt.formatTime(Hub.now||new Date(),"hh:mm")
            font.pixelSize:home.wide ? 64 : 54-10*home.dockT;font.weight:Font.Black;font.features:{"tnum":1}
        }
        // Live chips. Each one grows into its controls.
        Flow {
            id:glance;width:parent.width;spacing:8
            MorphChip {
                visible:Hub.status.track!==""
                icon:"music_note";text:Hub.status.track;selected:Hub.status.playing;host:home
                sheetWidth:380;sheetHeight:184
                sheet:Component {MediaCard {anchors.fill:parent;anchors.margins:4}}
            }
            MorphChip {
                visible:Notifier.inbox.length>0
                icon:"notifications";text:String(Notifier.inbox.length);host:home
                sheetWidth:400;sheetHeight:Math.min(420,home.height*.6)
                sheet:Component {
                    Flickable {anchors.fill:parent;anchors.margins:12;contentHeight:groups.implicitHeight;clip:true
                        NotificationGroups {id:groups;width:parent.width}}
                }
            }
            MorphChip {
                visible:Hub.focusRunning||Hub.focusSeconds<25*60
                icon:"timer";text:"Focus "+Math.floor(Hub.focusSeconds/60)+":"+String(Hub.focusSeconds%60).padStart(2,"0");selected:Hub.focusRunning;host:home
                sheetWidth:360;sheetHeight:180
                sheet:Component {FocusCard {anchors.fill:parent;anchors.margins:4}}
            }
            MorphChip {
                visible:home.docked
                icon:"desktop_windows";text:"Docked";tag:home.dockName;selected:true;host:home
                sheetWidth:440;sheetHeight:330
                sheet:Component {DockWelcome {anchors.fill:parent}}
            }
            MorphChip {
                visible:!Hub.focusRunning&&Hub.focusSeconds>=25*60
                icon:"timer";text:"Focus";host:home
                sheetWidth:360;sheetHeight:180
                sheet:Component {FocusCard {anchors.fill:parent;anchors.margins:4}}
            }
            MorphChip {
                icon:Hub.status.wifi ? "wifi" : "wifi_off";text:Hub.status.wifi ? (Hub.status.network||"Wi-Fi") : "Offline";host:home
                sheetWidth:380;sheetHeight:400
                sheet:Component {ConnectionPanel {anchors.fill:parent;anchors.margins:12;kind:"wifi";embedded:true}}
            }
            MorphChip {
                visible:Hub.status.battery>=0
                icon:Hub.status.charging ? "battery_charging_full" : Hub.status.battery<=20 ? "battery_alert" : "battery_5_bar"
                text:Hub.status.battery+"%";selected:Hub.status.battery<=20&&!Hub.status.charging
            }
        }
        Item {width:1;height:4}
        MText {visible:Rooms.earlier.length>0;text:"EARLIER";role:"labelS";color:Theme.primary;font.letterSpacing:1.3}
        Flow {
            visible:Rooms.earlier.length>0;width:parent.width;spacing:8
            Repeater {model:Rooms.earlier
                MorphChip {required property var modelData;icon:modelData.glyph;text:modelData.title;onClicked:Rooms.open(modelData)}}
        }
        Item {width:1;height:2}
        // Ladder: older things are smaller and fainter; the newest sits nearest the room.
        Repeater {
            model:home.wide ? Rooms.ladder : Rooms.ladder.slice(-2)
            Item {
                id:rung
                required property var modelData
                required property int index
                readonly property int count:home.wide ? Rooms.ladder.length : Math.min(2,Rooms.ladder.length)
                readonly property real step:count>1 ? index/(count-1) : 1
                width:story.width;height:rungRow.implicitHeight
                opacity:(.6+.32*step)*(1-home.dockT*.15)
                RowLayout {
                    id:rungRow;width:parent.width;spacing:12
                    Item {
                        Layout.preferredWidth:22+8*rung.step;Layout.preferredHeight:Layout.preferredWidth
                        AppIcon {anchors.fill:parent;visible:!!rung.modelData.app;app:rung.modelData.app||null;style:"raw"}
                        Glyph {anchors.centerIn:parent;visible:!rung.modelData.app;name:rung.modelData.glyph||"history";font.pixelSize:parent.width*.8}
                    }
                    ColumnLayout {
                        Layout.fillWidth:true;spacing:0
                        MText {Layout.fillWidth:true;text:rung.modelData.title;font.pixelSize:15+6*rung.step;font.weight:rung.step===1 ? Font.DemiBold : Font.Medium;elide:Text.ElideRight}
                        MText {Layout.fillWidth:true;text:rung.modelData.meta;role:"labelS";color:Theme.subtext;elide:Text.ElideRight}
                    }
                }
                TapHandler {onTapped:Rooms.open(rung.modelData)}
            }
        }
    }

    // ---- Rooms.
    readonly property real roomsX:home.wide ? story.x+story.width+32 : 0
    readonly property real roomsW:home.wide ? home.width-roomsX-24 : home.width
    // The room card at rest. It shrinks toward its chip while docking.
    Item {
        id:roomArea
        x:home.roomsX;width:home.roomsW
        anchors.bottom:undockedChips.top;anchors.bottomMargin:12
        height:home.wide ? undockedChips.y-36 : Math.max(180,Math.min(250,undockedChips.y-story.y-story.height-24))
        // Overview: every room with windows, drawn with its layout. Tap one to go there.
        Grid {
            visible:home.overview&&home.dockT===0
            x:24;width:parent.width-48;height:parent.height
            columns:home.wide ? 3 : 2;spacing:12
            readonly property var shown:Rooms.list.filter(r=>r.windows.length>0).slice(0,home.wide ? 6 : 4)
            readonly property int rowsUsed:Math.max(1,Math.ceil(shown.length/columns))
            Repeater {
                model:parent.shown
                RoomCard {
                    required property var modelData
                    room:modelData;previews:false;radius:24
                    width:(parent.width-parent.spacing*(parent.columns-1))/parent.columns
                    height:Math.min(home.wide ? 440 : 260,(parent.height-parent.spacing*(parent.rowsUsed-1))/parent.rowsUsed)
                    onEntered:Rooms.enter(modelData)
                }
            }
        }
    }
    RoomCard {
        id:card
        room:home.room;current:true
        readonly property var restRect:Qt.rect(roomArea.x+24,roomArea.y,roomArea.width-48,roomArea.height)
        readonly property var chipRect:{const c=dockedRepeater.itemAt(Math.max(0,Rooms.list.indexOf(home.room)));if(!c)return Qt.rect(restRect.x,story.y+story.height+40,120,36);const p=c.mapToItem(home,0,0);return Qt.rect(p.x,p.y,c.width,c.height);}
        x:restRect.x+(chipRect.x-restRect.x)*home.dockT
        y:restRect.y+(chipRect.y-restRect.y)*home.dockT
        width:restRect.width+(chipRect.width-restRect.width)*home.dockT
        height:restRect.height+(chipRect.height-restRect.height)*home.dockT
        radius:Math.min(height/2,30)
        opacity:home.dockT<.75 ? 1 : (1-home.dockT)*4
        visible:opacity>0&&home.room!==null&&!home.overview
        previews:home.dockT===0
        onEntered:{}
        // The card's own content fades early so the shrink reads as a surface, not a squashed picture.
        layer.enabled:home.dockT>0&&home.dockT<1
        Rectangle {anchors.fill:parent;radius:parent.radius;color:Theme.secondaryContainer;opacity:Math.max(0,(home.dockT-.35)/.4);visible:opacity>0}
    }
    // Neighbour room peeking at the right edge, a promise that rooms swipe.
    RoomCard {
        readonly property var next:Rooms.list[Rooms.list.indexOf(home.room)+1]||null
        visible:next!==null&&home.dockT===0&&!home.wide&&!home.overview
        room:next;previews:false
        x:home.width-18;y:roomArea.y+20;width:home.width-48;height:roomArea.height-40;opacity:.7
        onEntered:Rooms.enter(next)
    }
    // Swipe sideways on the card to change room.
    DragHandler {
        target:null;xAxis.enabled:true;yAxis.enabled:false
        enabled:home.dockT===0
        parent:card
        onActiveChanged:{
            if(active)return;
            const i=Rooms.list.indexOf(home.room);
            if(translation.x<-60&&i<Rooms.list.length-1)Rooms.enter(Rooms.list[i+1]);
            else if(translation.x>60&&i>0)Rooms.enter(Rooms.list[i-1]);
        }
    }

    // Room chips under the card when undocked.
    Flow {
        id:undockedChips
        x:home.roomsX+24;width:home.roomsW-48
        anchors.bottom:home.navDock ? parent.bottom : pins.top;anchors.bottomMargin:home.navDock ? 14 : home.wide ? 14 : 18
        spacing:8
        opacity:1-Math.min(1,home.dockT*2.5)
        visible:opacity>0
        Repeater {model:Rooms.list
            MorphChip {required property var modelData;icon:"space_dashboard";text:modelData.id+" · "+modelData.name;selected:modelData.id===Rooms.current;onClicked:Rooms.enter(modelData)}}
        MorphChip {icon:"add";text:"Room";onClicked:Rooms.newRoom()}
    }
    // Docked: the same chips at the top, tagged with the monitor they now live on.
    Column {
        id:dockedChips
        x:24;width:home.width-48
        y:story.y+story.height+18
        spacing:10
        opacity:Math.max(0,(home.dockT-.55)/.45)
        visible:home.dockT>0
        MText {text:"ON "+home.dockName.toUpperCase();role:"labelS";color:Theme.primary;font.letterSpacing:1.3}
        Flow {
            width:parent.width;spacing:8
            Repeater {id:dockedRepeater;model:Rooms.list
                MorphChip {required property var modelData;icon:"space_dashboard";text:modelData.id+" · "+modelData.name;selected:modelData.id===Rooms.current;onClicked:Rooms.enter(modelData)}}
            MorphChip {icon:"add";text:"Room";onClicked:Rooms.newRoom()}
        }
        // The phone can become the monitor's trackpad from here.
        Rectangle {
            width:parent.width;height:96;radius:28
            color:Theme.alpha(Theme.level(2),.9);border.width:1;border.color:Theme.outline
            RowLayout {anchors.fill:parent;anchors.margins:18;spacing:14
                Glyph {name:"touchpad_mouse";font.pixelSize:30;color:Theme.subtext}
                ColumnLayout {Layout.fillWidth:true;spacing:0
                    MText {text:"Use as trackpad";role:"titleS"}
                    MText {text:"Control "+home.dockName+" from the phone";role:"labelS";color:Theme.subtext;Layout.fillWidth:true;elide:Text.ElideRight}}
            }
            TapHandler {onTapped:Hub.setPhoneDockMode("trackpad")}
        }
    }

    // ---- Pins and search.
    Row {
        id:pins
        visible:!home.navDock
        x:home.wide ? home.roomsX+24 : (home.width-width)/2
        anchors.bottom:bar.top;anchors.bottomMargin:16
        spacing:home.wide ? 24 : Math.max(12,(home.width-48-5*46)/4)
        Repeater {model:Hub.favoriteApps.slice(0,5)
            AppIcon {required property var modelData;app:modelData;width:46;height:46
                TapHandler {onTapped:Hub.launch(parent.modelData)}}}
    }
    Rectangle {
        id:bar
        visible:!home.navDock
        anchors.bottom:parent.bottom;anchors.bottomMargin:12
        x:home.wide ? (home.width-width)/2 : 12;width:home.wide ? 560 : home.width-24
        height:56;radius:28;color:Theme.alpha(Theme.level(3),.94)
        RowLayout {anchors.fill:parent;anchors.leftMargin:20;anchors.rightMargin:8;spacing:10
            Glyph {name:"search";font.pixelSize:20;color:Theme.subtext}
            MText {Layout.fillWidth:true;text:"Search apps, files, rooms…";role:"body";color:Theme.subtext}
            Rectangle {width:40;height:40;radius:20;color:Theme.primaryContainer
                Glyph {anchors.centerIn:parent;name:"apps";font.pixelSize:20;color:Theme.containerInk}
                TapHandler {onTapped:home.openDrawer(false)}}
        }
        TapHandler {onTapped:home.openDrawer(true)}
        Accessible.role:Accessible.Button;Accessible.name:"Search"
    }
}
