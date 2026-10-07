import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Launcher concept prototypes. Static data only; they render the idea, not a working shell.
ShellRoot {
    Component.onCompleted:Quickshell.watchFiles=false
    Window {
        id:fixture
        width:412;height:915;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"proto-now",view:nowView},
            {name:"proto-now-search",view:nowView,query:"ki"},
            {name:"proto-rooms",view:roomsView},
            {name:"proto-index",view:indexView},
            {name:"proto-now-light",view:nowView,light:true}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const c=cases[step];
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:!!c.light});
            loader.sourceComponent=c.view;
            if(loader.item&&c.query!==undefined)loader.item.query=c.query;
            grab.restart();
        }
        Timer {id:grab;interval:900;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    // Shared bits.
    component Status:RowLayout {
        width:parent ? parent.width : 0;height:32
        Opal.MText {text:"12:41";role:"label";Layout.leftMargin:22}
        Item {Layout.fillWidth:true}
        Opal.Glyph {name:"wifi";font.pixelSize:15}
        Opal.Glyph {name:"battery_5_bar";font.pixelSize:15}
        Opal.MText {text:"76%";role:"labelS";Layout.rightMargin:22}
    }
    component CommandBar:Rectangle {
        property string query:""
        property string hint:"Open, find or run…"
        height:56;radius:28;color:Opal.Theme.level(3)
        RowLayout {anchors.fill:parent;anchors.leftMargin:20;anchors.rightMargin:8;spacing:10
            Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
            Opal.MText {Layout.fillWidth:true;text:parent.parent.query!=="" ? parent.parent.query : parent.parent.hint;role:"body";color:parent.parent.query!=="" ? Opal.Theme.text : Opal.Theme.subtext}
            Rectangle {width:40;height:40;radius:20;color:Opal.Theme.primaryContainer
                Opal.Glyph {anchors.centerIn:parent;name:"grid_view";font.pixelSize:20;color:Opal.Theme.containerInk}}
        }
    }
    component Device:Rectangle {
        property string label:""
        visible:label!=="";implicitWidth:dl.implicitWidth+14;implicitHeight:20;radius:10;color:Opal.Theme.alpha(Opal.Theme.tertiary,.16)
        Opal.MText {id:dl;anchors.centerIn:parent;text:parent.label;role:"labelS";color:Opal.Theme.tertiary}
    }

    // Concept 1: Now. One river of everything you did, newest at the thumb. Typing filters the same river.
    Component {id:nowView
        Item {
            id:now
            property string query:""
            readonly property var river:[
                {day:"Yesterday"},
                {icon:"kicad",title:"opal-dock.kicad_pcb",meta:"KiCad · closed 21:40",device:"Desktop",action:"Open"},
                {icon:"org.prismlauncher.PrismLauncher",title:"Fabulously Optimized",meta:"Prism Launcher · 1h 05m",action:"Play"},
                {day:"Today"},
                {icon:"steam",title:"DELTARUNE",meta:"Chapter 4 · played 2h 14m · ended 10:20",action:"Play",art:true},
                {icon:"google-chrome",title:"Lua configuration – Hyprland Wiki",meta:"Chrome · 3 tabs",device:"Desktop",live:true,action:"Bring here"},
                {icon:"org.kde.dolphin",title:"Wallpapers",meta:"Dolphin · ~/Pictures",live:true},
                {media:true,title:"snowfall",meta:"lofi girl · paused"},
                {icon:"kitty",title:"claude — ~/opal",meta:"kitty · 3 windows",live:true,current:true}
            ]
            readonly property var results:[
                {section:"Running"},
                {icon:"kitty",title:"kitty",meta:"3 windows · claude — ~/opal",live:true},
                {section:"Apps"},
                {icon:"kicad",title:"KiCad",meta:"opened yesterday"},
                {section:"Files"},
                {icon:"folder",glyph:true,title:"~/kicad/opal-dock",meta:"folder · 14 files"},
                {icon:"description",glyph:true,title:"keyboard-build.log",meta:"~/.local/state/opal"},
                {section:"Run"},
                {icon:"terminal",glyph:true,title:"kill …",meta:"pick a process to stop"},
                {icon:"terminal",glyph:true,title:"ki in kitty",meta:"run as a shell command"}
            ]
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Status {id:status;anchors.top:parent.top;anchors.topMargin:6}
            ListView {
                id:list
                anchors {top:status.bottom;left:parent.left;right:parent.right;bottom:bar.top;bottomMargin:12;leftMargin:12;rightMargin:12}
                verticalLayoutDirection:ListView.BottomToTop
                spacing:6;clip:true;interactive:false
                model:(now.query!=="" ? now.results : now.river).slice().reverse()
                delegate:Item {
                    required property var modelData
                    width:list.width
                    height:modelData.day||modelData.section ? 34 : modelData.current ? 196 : modelData.media ? 76 : 68
                    Opal.MText {visible:!!(modelData.day||modelData.section);anchors.bottom:parent.bottom;anchors.bottomMargin:6;x:12;text:modelData.day||modelData.section||"";role:"labelS";color:Opal.Theme.subtext;font.letterSpacing:.6}
                    Rectangle {
                        visible:!(modelData.day||modelData.section)
                        anchors.fill:parent;radius:modelData.current ? 28 : 22
                        color:modelData.current ? Opal.Theme.level(3) : modelData.live ? Opal.Theme.level(2) : "transparent"
                        border.width:modelData.live||modelData.current||modelData.media ? 0 : 1;border.color:Opal.Theme.outline
                        // The current task shows a live window preview.
                        Rectangle {
                            visible:!!modelData.current
                            anchors {left:parent.left;right:parent.right;top:parent.top;margins:10}
                            height:118;radius:18;color:"#0d0f12"
                            Column {x:14;y:12;spacing:3
                                Repeater {model:["~/opal $ claude","✻ Merging workstream F…","  168 tests OK","  render: 4 dock scenes","> make the dock welcome better"]
                                    Text {required property string modelData;text:modelData;color:index===4 ? "#c7cc79" : "#cfd2d6";font.family:"CaskaydiaCove Nerd Font";font.pixelSize:11;required property int index}}
                            }
                            Row {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:8;spacing:4
                                Repeater {model:3;Rectangle {required property int index;width:index===0 ? 18 : 6;height:6;radius:3;color:index===0 ? "#c7cc79" : "#5a5d61"}}}
                        }
                        RowLayout {
                            anchors {left:parent.left;right:parent.right;bottom:parent.bottom;leftMargin:14;rightMargin:10;bottomMargin:modelData.current ? 14 : 0}
                            height:modelData.media ? 76 : 68;spacing:12
                            Item {Layout.preferredWidth:40;Layout.preferredHeight:40
                                Rectangle {anchors.fill:parent;radius:12;visible:!!modelData.media||!!modelData.glyph;color:modelData.media ? Opal.Theme.tertiaryContainer : Opal.Theme.level(3)
                                    Opal.Glyph {anchors.centerIn:parent;name:modelData.media ? "music_note" : modelData.icon||"";font.pixelSize:20;color:modelData.media ? Opal.Theme.tertiaryInk : Opal.Theme.subtext}}
                                Opal.AppIcon {anchors.fill:parent;visible:!modelData.media&&!modelData.glyph;name:modelData.icon||"";style:"raw"}
                            }
                            ColumnLayout {Layout.fillWidth:true;spacing:1
                                RowLayout {spacing:6;Layout.fillWidth:true
                                    Rectangle {visible:!!modelData.live;width:7;height:7;radius:4;color:Opal.Theme.primary}
                                    Opal.MText {text:modelData.title||"";role:"titleS";elide:Text.ElideRight;Layout.fillWidth:true}
                                }
                                RowLayout {spacing:6
                                    Opal.MText {text:modelData.meta||"";role:"bodyS";color:Opal.Theme.subtext;elide:Text.ElideRight}
                                    Device {label:modelData.device||""}
                                }
                            }
                            Row {visible:!!modelData.media;spacing:2
                                Repeater {model:["skip_previous","play_arrow","skip_next"];Rectangle {required property string modelData;width:36;height:36;radius:18;color:modelData==="play_arrow" ? Opal.Theme.tertiaryContainer : "transparent"
                                    Opal.Glyph {anchors.centerIn:parent;name:parent.modelData;font.pixelSize:20;color:Opal.Theme.text}}}
                            }
                            Rectangle {visible:!!modelData.action;implicitWidth:al.implicitWidth+22;height:32;radius:16;color:modelData.live ? Opal.Theme.secondaryContainer : Opal.Theme.level(2)
                                Opal.MText {id:al;anchors.centerIn:parent;text:modelData.action||"";role:"label"}}
                            Opal.MText {visible:!!modelData.current;text:"Now";role:"label";color:Opal.Theme.primary}
                        }
                    }
                }
            }
            CommandBar {id:bar;query:now.query;anchors {left:parent.left;right:parent.right;bottom:handle.top;margins:12;bottomMargin:10}}
            Rectangle {id:handle;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:10;width:120;height:5;radius:3;color:Opal.Theme.alpha(Opal.Theme.text,.5)}
        }
    }

    // Concept 2: Rooms. Workspaces are home. Each room keeps its real window layout, which the monitor shows as-is when docked.
    Component {id:roomsView
        Item {
            property string query:""
            readonly property var rooms:[
                {n:1,name:"opal",device:"",tiles:[{icon:"kitty",t:"claude — ~/opal",x:0,y:0,w:.5,h:1,focus:true},{icon:"google-chrome",t:"Hyprland Wiki",x:.5,y:0,w:.5,h:.6},{icon:"org.kde.dolphin",t:"Wallpapers",x:.5,y:.6,w:.5,h:.4}]},
                {n:2,name:"Play",device:"",tiles:[{icon:"steam",t:"DELTARUNE",x:0,y:0,w:1,h:1,full:true}]},
                {n:3,name:"Board",device:"Desktop",tiles:[{icon:"kicad",t:"opal-dock — PCB",x:0,y:0,w:.66,h:1},{icon:"google-chrome",t:"JLCPCB",x:.66,y:0,w:.34,h:1}]}
            ]
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Status {id:status;anchors.top:parent.top;anchors.topMargin:6}
            ColumnLayout {
                anchors {top:status.bottom;left:parent.left;right:parent.right;bottom:bar.top;margins:12;topMargin:8}
                spacing:12
                Repeater {model:parent.parent.rooms
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth:true;Layout.preferredHeight:modelData.n===1 ? 236 : 176
                        radius:28;color:modelData.n===1 ? Opal.Theme.level(3) : Opal.Theme.level(2)
                        RowLayout {id:head;x:18;y:12;width:parent.width-36;spacing:8
                            Opal.MText {text:modelData.n;role:"titleS";color:Opal.Theme.primary}
                            Opal.MText {text:modelData.name;role:"titleS";Layout.fillWidth:true}
                            Device {label:modelData.device}
                            Opal.MText {visible:modelData.n===1;text:"Here now";role:"labelS";color:Opal.Theme.primary}
                        }
                        // The miniature uses the room's real tiling, at the docked monitor's aspect.
                        Item {
                            anchors {left:parent.left;right:parent.right;top:head.bottom;bottom:parent.bottom;margins:12;topMargin:10}
                            Repeater {model:modelData.tiles
                                Rectangle {
                                    required property var modelData
                                    x:modelData.x*parent.width+3;y:modelData.y*parent.height+3;width:modelData.w*parent.width-6;height:modelData.h*parent.height-6
                                    radius:14;color:modelData.full ? "#1b1420" : Opal.Theme.level(1)
                                    border.width:modelData.focus ? 2 : 0;border.color:Opal.Theme.primary
                                    Column {anchors.centerIn:parent;spacing:6;width:parent.width-16
                                        Opal.AppIcon {anchors.horizontalCenter:parent.horizontalCenter;width:30;height:30;name:modelData.icon;style:"raw"}
                                        Opal.MText {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:modelData.t;role:"labelS";color:modelData.full ? "#e8dff0" : Opal.Theme.subtext;elide:Text.ElideRight}
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {Layout.fillWidth:true;Layout.preferredHeight:64;radius:24;color:"transparent";border.width:1;border.color:Opal.Theme.outline
                    RowLayout {anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:12;spacing:10
                        Opal.Glyph {name:"add";font.pixelSize:20;color:Opal.Theme.subtext}
                        Opal.MText {text:"New room";role:"titleS";Layout.fillWidth:true}
                        Opal.MText {text:"from an app, a folder or a project";role:"labelS";color:Opal.Theme.subtext}
                    }}
                Item {Layout.fillHeight:true}
            }
            CommandBar {id:bar;hint:"Open in this room, or type a new one…";anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26}}
        }
    }

    // Concept 3: Index. Text first, no icon wall. Everything is a line you can read at a glance or reach with the letter rail.
    Component {id:indexView
        Item {
            property string query:""
            readonly property var sections:[
                {h:"Running",rows:[{t:"kitty",m:"claude — ~/opal  ·  +2",live:true},{t:"Chrome",m:"Lua configuration – Hyprland Wiki",live:true,d:"Desktop"},{t:"Dolphin",m:"~/Pictures/Wallpapers",live:true}]},
                {h:"Continue",rows:[{t:"ROADMAP-2026-10.md",m:"edited 1 h ago"},{t:"DELTARUNE",m:"Chapter 4 · 2 h ago"},{t:"opal-dock.kicad_pcb",m:"yesterday",d:"Desktop"}]},
                {h:"Listening",rows:[{t:"snowfall",m:"lofi girl · paused"}]}
            ]
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Status {id:status;anchors.top:parent.top;anchors.topMargin:6}
            Column {
                anchors {top:status.bottom;left:parent.left;right:rail.left;topMargin:20;leftMargin:24}
                spacing:22
                Repeater {model:parent.parent.sections
                    Column {required property var modelData;width:parent.width;spacing:10
                        Opal.MText {text:modelData.h.toUpperCase();role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2}
                        Repeater {model:modelData.rows
                            Column {required property var modelData;width:parent.width;spacing:0
                                Row {spacing:8
                                    Opal.MText {text:modelData.t;font.pixelSize:24;font.weight:modelData.live ? Font.DemiBold : Font.Normal;color:modelData.live ? Opal.Theme.text : Opal.Theme.subtext}
                                    Rectangle {visible:!!modelData.live;width:7;height:7;radius:4;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
                                    Device {label:modelData.d||"";anchors.verticalCenter:parent.verticalCenter}
                                }
                                Opal.MText {text:modelData.m;role:"bodyS";color:Opal.Theme.muted}
                            }
                        }
                    }
                }
                Column {width:parent.width;spacing:8
                    Opal.MText {text:"PINNED";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2}
                    Flow {width:parent.width;spacing:14
                        Repeater {model:["kitty","Chrome","Dolphin","Steam","Prism","KiCad","Discord"]
                            Opal.MText {required property string modelData;text:modelData;font.pixelSize:19;color:Opal.Theme.text}}}
                }
            }
            Column {id:rail;anchors {right:parent.right;rightMargin:8;verticalCenter:parent.verticalCenter}
                spacing:1
                Repeater {model:"ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split("")
                    Opal.MText {required property string modelData;width:20;horizontalAlignment:Text.AlignHCenter;text:modelData;role:"labelS";color:Opal.Theme.muted}}
            }
            CommandBar {hint:"Type anything";anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26}}
        }
    }
}
