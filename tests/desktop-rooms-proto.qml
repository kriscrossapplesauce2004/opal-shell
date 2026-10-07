import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Desktop Rooms prototypes built from the real Rooms parts. Run: OPAL_ENTRY=desktop-rooms-proto.qml bash tests/render-offscreen.sh
ShellRoot {
    Component.onCompleted:Quickshell.watchFiles=false
    Window {
        id:fixture
        width:1600;height:900;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"desk-1-start",view:startView},
            {name:"desk-2-shelf-hover",view:restView,hover:true},
            {name:"desk-3-overview",view:overviewView},
            {name:"desk-4-rest",view:restView},
            {name:"desk-4-rest-light",view:restView,light:true},
            {name:"desk-widgets",view:widgetsView},
            {name:"desk-widgets-light",view:widgetsView,light:true},
            {name:"desk-widgets-chip",view:widgetsView,chip:true}
        ]
        property var c:cases[0]
        function seed() {
            const W=1600,H=900;
            const wins=[
                {title:"claude — ~/opal",className:"kitty",address:"0x1",workspace:1,monitor:"DP-1",at:[12,12],size:[W*.5-18,H-120],floating:false,fullscreen:0},
                {title:"Lua configuration – Hyprland Wiki",className:"google-chrome",address:"0x2",workspace:1,monitor:"DP-1",at:[W*.5+6,12],size:[W*.5-18,H*.55],floating:false,fullscreen:0},
                {title:"Wallpapers",className:"org.kde.dolphin",address:"0x3",workspace:1,monitor:"DP-1",at:[W*.5+6,H*.55+18],size:[W*.5-18,H*.45-138],floating:false,fullscreen:0},
                {title:"DELTARUNE",className:"steam_app_1671210",address:"0x4",workspace:2,monitor:"DP-1",at:[0,0],size:[W,H],floating:false,fullscreen:2},
                {title:"opal-dock — PCB Editor",className:"kicad",address:"0x5",workspace:3,monitor:"DP-1",at:[12,12],size:[W*.64,H-120],floating:false,fullscreen:0},
                {title:"JLCPCB – Order",className:"google-chrome",address:"0x6",workspace:3,monitor:"DP-1",at:[W*.64+24,12],size:[W*.36-36,H-120],floating:false,fullscreen:0},
                {title:"#opal-dev",className:"discord",address:"0x7",workspace:4,monitor:"DP-1",at:[W*.2,H*.1],size:[W*.6,H*.7],floating:true,fullscreen:0}
            ];
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:!!c.light,desktopStyle:"rooms",desktopWidgets:true,wallpaperPath:"file:///home/melissa/Pictures/Wallpapers/default.png"});
            Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=wins;
            Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,workspace:1,workspaces:[1,2,3,4],monitors:[{name:"DP-1",workspace:1,x:0,y:0,width:W,height:H,scale:1,transform:0}],activeAddress:"0x1",track:"snowfall",artist:"lofi girl",playing:true});
            Opal.PhoneState.activity={files:[{kind:"file",title:"ROADMAP-2026-10.md",path:"/tmp/none.md",when:"1 h ago"},{kind:"file",title:"board-notes.txt",path:"/tmp/x"}],games:[{kind:"game",id:"steam:9",title:"Kerbal Space Program"},{kind:"game",id:"steam:8",title:"Fabulously Optimized"}]};
        }
        Image {anchors.fill:parent;source:"file:///home/melissa/Pictures/Wallpapers/default.png";sourceSize:Qt.size(1920,1920);fillMode:Image.PreserveAspectCrop}
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            c=cases[step];seed();
            loader.sourceComponent=null;loader.sourceComponent=c.view;
            prep.restart();
        }
        Timer {id:prep;interval:500;onTriggered:{fixture.seed();if(fixture.c.chip){const ch=fixture.findChip(loader.item);if(ch)ch.expanded=true;}grab.restart();}}
        function findChip(item) {if(!item)return null;if(item.sheetWidth!==undefined&&item.text==="snowfall")return item;for(let i=0;i<item.children.length;i++){const f=fixture.findChip(item.children[i]);if(f)return f;}return null;}
        Timer {id:grab;interval:1200;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    // Shelf with room chips in place of a flat app strip. The current room shows its apps beside its chip.
    component Shelf:Item {
        id:shelf
        property int hoverRoom:-1
        anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12}
        height:52
        Row {
            spacing:8;anchors.verticalCenter:parent.verticalCenter
            Rectangle {width:52;height:52;radius:26;color:Opal.Theme.primaryContainer
                Opal.Glyph {anchors.centerIn:parent;name:"space_dashboard";font.pixelSize:24;color:Opal.Theme.containerInk}}
            Rectangle {width:220;height:52;radius:26;color:Opal.Theme.alpha(Opal.Theme.level(2),.92)
                Row {anchors.verticalCenter:parent.verticalCenter;x:18;spacing:10
                    Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
                    Opal.MText {text:"Search";role:"body";color:Opal.Theme.subtext}}}
            Rectangle {width:1;height:28;color:Opal.Theme.outline;anchors.verticalCenter:parent.verticalCenter}
            Rectangle {
                height:52;width:roomsRow.implicitWidth+16;radius:26;color:Opal.Theme.alpha(Opal.Theme.level(2),.92)
                Row {
                    id:roomsRow;anchors.verticalCenter:parent.verticalCenter;x:8;spacing:6
                    Repeater {model:Opal.Rooms.list
                        Rectangle {
                            required property var modelData
                            readonly property bool here:modelData.id===Opal.Rooms.current
                            height:40;width:chipRow.implicitWidth+20;radius:20
                            color:here ? Opal.Theme.secondaryContainer : shelf.hoverRoom===modelData.id ? Opal.Theme.alpha(Opal.Theme.text,.08) : "transparent"
                            Row {id:chipRow;anchors.centerIn:parent;spacing:6
                                Opal.MText {text:modelData.id;role:"label";color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
                                Opal.MText {visible:here;text:modelData.name;role:"label";anchors.verticalCenter:parent.verticalCenter}
                                Repeater {model:modelData.windows.slice(0,here ? 4 : 2)
                                    Opal.AppIcon {required property var modelData;width:24;height:24;app:Opal.Hub.appForWindow(modelData);style:"raw";anchors.verticalCenter:parent.verticalCenter}}
                            }
                        }
                    }
                    Rectangle {height:40;width:40;radius:20;color:"transparent";border.width:1;border.color:Opal.Theme.outline
                        Opal.Glyph {anchors.centerIn:parent;name:"add";font.pixelSize:18;color:Opal.Theme.subtext}}
                }
            }
        }
        Row {
            anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:8
            Rectangle {width:pill.implicitWidth+28;height:52;radius:26;color:Opal.Theme.secondaryContainer
                Row {id:pill;anchors.centerIn:parent;spacing:8
                    Opal.Glyph {name:"music_note";font.pixelSize:18;color:Opal.Theme.onSecondaryContainer}
                    Opal.MText {text:"snowfall · lofi girl";role:"label";color:Opal.Theme.onSecondaryContainer}}}
            Rectangle {width:150;height:52;radius:26;color:Opal.Theme.alpha(Opal.Theme.level(2),.92)
                Row {anchors.centerIn:parent;spacing:14
                    Repeater {model:["notifications","wifi","volume_up","battery_5_bar"];Opal.Glyph {required property string modelData;name:modelData;font.pixelSize:18}}}}
            Rectangle {width:132;height:52;radius:26;color:Opal.Theme.primaryContainer
                Opal.MText {anchors.centerIn:parent;text:"Tue 7  18:24";role:"titleS";color:Opal.Theme.containerInk}}
        }
    }

    // The glance, Earlier and Ladder column, shared by Start, the overview and the resting desktop.
    component Story:Column {
        spacing:12
        property bool big:true
        Opal.MText {text:"Wednesday 7 October";role:"titleS"}
        Opal.MText {text:"18:24";font.pixelSize:parent.big ? 72 : 52;font.weight:Font.Black}
        Flow {width:parent.width;spacing:8
            Opal.MorphChip {icon:"music_note";text:"snowfall";selected:true}
            Opal.MorphChip {icon:"notifications";text:"3"}
            Opal.MorphChip {icon:"timer";text:"Focus 18:20"}}
        Item {width:1;height:6}
        Opal.MText {text:"EARLIER";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.3}
        Flow {width:parent.width;spacing:8
            Repeater {model:Opal.Rooms.earlier;Opal.MorphChip {required property var modelData;icon:modelData.glyph;text:modelData.title}}}
        Item {width:1;height:4}
        Repeater {model:Opal.Rooms.ladder
            Row {required property var modelData;required property int index;spacing:12;opacity:.6+.16*index
                Opal.Glyph {name:modelData.glyph||"history";font.pixelSize:20+6*index;anchors.verticalCenter:parent.verticalCenter}
                Column {Opal.MText {text:modelData.title;font.pixelSize:15+5*index;font.weight:index===2 ? Font.DemiBold : Font.Medium}
                        Opal.MText {text:modelData.meta;role:"labelS";color:Opal.Theme.subtext}}}}
    }

    // Rooms desktop widgets on the real wallpaper, with the classic shelf look.
    Component {id:widgetsView
        Item {
            Opal.Wallpaper {anchors.fill:parent}
        }
    }

    // 1. Start as Rooms.
    Component {id:startView
        Item {
            Shelf {}
            Rectangle {
                x:12;anchors.bottom:parent.bottom;anchors.bottomMargin:76
                width:1060;height:640;radius:32;color:Opal.Theme.alpha(Opal.Theme.base,.96)
                Rectangle {x:24;y:22;width:parent.width-48;height:52;radius:26;color:Opal.Theme.level(3)
                    Row {anchors.verticalCenter:parent.verticalCenter;x:20;spacing:10
                        Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
                        Opal.MText {text:"Search apps, files, rooms, or ! to ask Claude";role:"body";color:Opal.Theme.subtext}}}
                Story {x:28;y:98;width:330;big:false}
                Grid {
                    x:384;y:98;columns:2;spacing:14
                    Repeater {model:Opal.Rooms.list
                        Opal.RoomCard {required property var modelData;room:modelData;current:modelData.id===Opal.Rooms.current;width:318;height:240;previews:false}}
                }
            }
        }
    }

    // 2 and 4. Resting desktop; with hover, a room chip grows into its card.
    Component {id:restView
        Item {
            Rectangle {anchors.fill:parent;gradient:Gradient {orientation:Gradient.Horizontal
                GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,.72)} GradientStop {position:.42;color:Opal.Theme.alpha(Opal.Theme.base,.0)}}}
            Story {x:48;y:48;width:420}
            Shelf {id:sh;hoverRoom:fixture.c.hover ? 3 : -1}
            Opal.RoomCard {
                visible:!!fixture.c.hover
                room:Opal.Rooms.list.find(r=>r.id===3)||null;previews:false
                x:380;y:parent.height-76-height;width:420;height:280
            }
        }
    }

    // 3. Overview: every room large, the story at the left, search at the bottom.
    Component {id:overviewView
        Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.82)}
            Story {x:48;y:48;width:380}
            Row {
                x:470;y:96;spacing:20
                Repeater {model:Opal.Rooms.list.slice(0,3)
                    Opal.RoomCard {required property var modelData;room:modelData;current:modelData.id===Opal.Rooms.current;previews:false
                        width:modelData.id===Opal.Rooms.current ? 520 : 260;height:modelData.id===Opal.Rooms.current ? 390 : 260
                        anchors.verticalCenter:undefined}}
            }
            Row {
                x:470;y:560;spacing:8
                Repeater {model:Opal.Rooms.list;Opal.MorphChip {required property var modelData;icon:"space_dashboard";text:modelData.id+" · "+modelData.name;selected:modelData.id===Opal.Rooms.current}}
                Opal.MorphChip {icon:"add";text:"Room"}
            }
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:40;width:620;height:56;radius:28;color:Opal.Theme.level(3)
                Row {anchors.verticalCenter:parent.verticalCenter;x:20;spacing:10
                    Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
                    Opal.MText {text:"Search apps, files, rooms…";role:"body";color:Opal.Theme.subtext}}}
        }
    }
}
