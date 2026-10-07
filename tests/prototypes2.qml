import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "src" as Opal

// Launcher concept prototypes, round 2. Static data only.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string wall:"file:///home/melissa/Pictures/Wallpapers/default.png"
    readonly property string hero:"file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_hero.jpg"
    readonly property var icons:({kitty:"/usr/share/pixmaps/kitty.png",chrome:"/usr/share/icons/Papirus/64x64/apps/google-chrome.svg",dolphin:"/usr/share/icons/Papirus/64x64/apps/org.kde.dolphin.svg",steam:"/usr/share/pixmaps/steam.png",kicad:"/usr/share/icons/Papirus/64x64/apps/kicad.svg",prism:"/usr/share/icons/Papirus/64x64/apps/org.prismlauncher.PrismLauncher.svg",discord:"/usr/share/icons/Papirus/64x64/apps/discord.svg",spotify:"/usr/share/icons/Papirus/64x64/apps/spotify.svg"})
    Window {
        id:fixture
        width:412;height:915;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"r2-1-ladder",view:ladderView},
            {name:"r2-2-rooms-river",view:riverView},
            {name:"r2-3-desk",view:deskView},
            {name:"r2-4-shelf",view:shelfView},
            {name:"r2-5-content-cards",view:cardsView},
            {name:"r2-2-rooms-river-tablet",view:riverView,w:1280,h:800}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const c=cases[step];
            fixture.width=c.w||412;fixture.height=c.h||915;
            loader.sourceComponent=null;loader.sourceComponent=c.view;
            grab.restart();
        }
        Timer {id:grab;interval:1600;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    component Ico:Image {property string n:"";source:root.icons[n] ? "file://"+root.icons[n] : "";sourceSize:Qt.size(96,96);smooth:true;fillMode:Image.PreserveAspectFit}
    component Wall:Item {
        property real dim:.35
        Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1400,1400);fillMode:Image.PreserveAspectCrop}
        Rectangle {anchors.fill:parent;color:"#000000";opacity:parent.dim}
    }
    component Status:RowLayout {
        property color ink:"#ffffff"
        height:32
        Opal.MText {text:"12:41";role:"label";color:parent.ink;Layout.leftMargin:22}
        Item {Layout.fillWidth:true}
        Opal.Glyph {name:"wifi";font.pixelSize:15;color:parent.ink}
        Opal.Glyph {name:"battery_5_bar";font.pixelSize:15;color:parent.ink}
        Opal.MText {text:"76%";role:"labelS";color:parent.ink;Layout.rightMargin:22}
    }
    component Bar:Rectangle {
        property string hint:"Open, find or run…"
        height:56;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(3),.92)
        RowLayout {anchors.fill:parent;anchors.leftMargin:20;anchors.rightMargin:8;spacing:10
            Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
            Opal.MText {Layout.fillWidth:true;text:parent.parent.hint;role:"body";color:Opal.Theme.subtext}
            Rectangle {width:40;height:40;radius:20;color:Opal.Theme.primaryContainer
                Opal.Glyph {anchors.centerIn:parent;name:"grid_view";font.pixelSize:20;color:Opal.Theme.containerInk}}
        }
    }
    component Tag:Rectangle {
        property string label:""
        visible:label!=="";implicitWidth:tl.implicitWidth+14;implicitHeight:20;radius:10;color:Opal.Theme.alpha(Opal.Theme.tertiary,.18)
        Opal.MText {id:tl;anchors.centerIn:parent;text:parent.label;role:"labelS";color:Opal.Theme.tertiary}
    }
    component Term:Rectangle {
        property var lines:["~/opal $ claude","✻ Merging workstream A…","  190 tests OK","> make the dock welcome better"]
        radius:16;color:"#0d0f12"
        Column {x:12;y:10;spacing:2
            Repeater {model:parent.parent.lines
                Text {required property string modelData;required property int index;text:modelData;color:modelData.startsWith(">") ? "#c7cc79" : "#cfd2d6";font.family:"CaskaydiaCove Nerd Font";font.pixelSize:11}}}
    }
    // A room miniature drawn from its real tiling.
    component Room:Item {
        property var tiles:[]
        property bool live:false
        Repeater {model:parent.tiles
            Rectangle {
                required property var modelData
                x:modelData.x*parent.width+2;y:modelData.y*parent.height+2;width:modelData.w*parent.width-4;height:modelData.h*parent.height-4
                radius:12;clip:true;color:Opal.Theme.level(1)
                border.width:modelData.focus ? 2 : 0;border.color:Opal.Theme.primary
                Image {anchors.fill:parent;visible:modelData.art===true;source:root.hero;sourceSize:Qt.size(600,300);fillMode:Image.PreserveAspectCrop}
                Term {anchors.fill:parent;anchors.margins:6;visible:modelData.term===true}
                Column {visible:!modelData.term&&!modelData.art;anchors.centerIn:parent;spacing:4;width:parent.width-12
                    Ico {anchors.horizontalCenter:parent.horizontalCenter;width:26;height:26;n:modelData.icon}
                    Opal.MText {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:modelData.t;role:"labelS";color:Opal.Theme.subtext;elide:Text.ElideRight}
                }
            }
        }
    }

    // 1. Ladder: type size is recency. The thing you are doing is huge; older things step down.
    Component {id:ladderView
        Item {
            Wall {anchors.fill:parent;dim:.62}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6}
            Column {
                anchors {left:parent.left;right:parent.right;bottom:bar.top;leftMargin:26;rightMargin:22;bottomMargin:26}
                spacing:16
                Repeater {model:[
                    {t:"opal-dock.kicad_pcb",m:"KiCad · yesterday",s:15,o:.45,i:"kicad",d:"Desktop"},
                    {t:"Fabulously Optimized",m:"Prism · 1 h 05 m",s:17,o:.55,i:"prism"},
                    {t:"DELTARUNE",m:"Chapter 4 · 2 h ago",s:20,o:.68,i:"steam"},
                    {t:"Hyprland Wiki",m:"Chrome · 3 tabs · on Desktop",s:23,o:.8,i:"chrome",live:true,d:"Desktop"},
                    {t:"snowfall",m:"lofi girl · paused",s:25,o:.88,i:"spotify",live:true}]
                    Row {required property var modelData;spacing:12;opacity:modelData.o
                        Ico {width:modelData.s+6;height:width;n:modelData.i;anchors.verticalCenter:parent.verticalCenter}
                        Column {
                            Row {spacing:8
                                Opal.MText {text:modelData.t;font.pixelSize:modelData.s;font.weight:modelData.live ? Font.DemiBold : Font.Normal;color:"#ffffff"}
                                Tag {label:modelData.d||"";anchors.verticalCenter:parent.verticalCenter}
                            }
                            Opal.MText {text:modelData.m;role:"labelS";color:"#d8d2e0"}
                        }
                    }
                }
                // Now: the largest step, with its live window.
                Column {width:parent.width;spacing:10;topPadding:6
                    Opal.MText {text:"NOW";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.4}
                    Row {spacing:12
                        Ico {width:40;height:40;n:"kitty";anchors.verticalCenter:parent.verticalCenter}
                        Opal.MText {text:"claude — ~/opal";font.pixelSize:34;font.weight:Font.Bold;color:"#ffffff"}
                    }
                    Term {width:parent.width;height:96}
                }
            }
            Bar {id:bar;anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26}}
        }
    }

    // 2. Rooms river: rooms are the unit; the current room sits at the thumb with its real layout; ended things fold into chips.
    Component {id:riverView
        Item {
            id:rv
            readonly property bool wide:width>700
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6;ink:Opal.Theme.text}
            GridLayout {
                anchors {top:st.bottom;left:parent.left;right:parent.right;bottom:bar.top;margins:12;topMargin:6;bottomMargin:12}
                columns:rv.wide ? 2 : 1;columnSpacing:12;rowSpacing:10
                ColumnLayout {Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredWidth:rv.wide ? 380 : -1;spacing:10
                    Item {Layout.fillHeight:true}
                    Opal.MText {text:"Earlier";role:"labelS";color:Opal.Theme.subtext;Layout.leftMargin:8}
                    Flow {Layout.fillWidth:true;spacing:8
                        Repeater {model:[{i:"kicad",t:"opal-dock PCB"},{i:"prism",t:"Fabulously Optimized"},{i:"steam",t:"DELTARUNE"},{i:"discord",t:"#opal-dev"}]
                            Rectangle {required property var modelData;implicitWidth:cr.implicitWidth+20;height:36;radius:18;color:"transparent";border.width:1;border.color:Opal.Theme.outline
                                Row {id:cr;anchors.centerIn:parent;spacing:6
                                    Ico {width:18;height:18;n:modelData.i;anchors.verticalCenter:parent.verticalCenter}
                                    Opal.MText {text:modelData.t;role:"label";anchors.verticalCenter:parent.verticalCenter}}}}
                    }
                    Opal.MText {text:"Rooms";role:"labelS";color:Opal.Theme.subtext;Layout.leftMargin:8;Layout.topMargin:6}
                    Repeater {model:[{n:3,name:"Board",icons:["kicad","chrome"],d:"Desktop",m:"2 windows"},{n:2,name:"Play",icons:["steam"],m:"DELTARUNE · paused"}]
                        Rectangle {required property var modelData;Layout.fillWidth:true;Layout.preferredHeight:64;radius:22;color:Opal.Theme.level(2)
                            RowLayout {anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:14;spacing:12
                                Opal.MText {text:modelData.n;role:"titleS";color:Opal.Theme.primary}
                                ColumnLayout {Layout.fillWidth:true;spacing:0
                                    Opal.MText {text:modelData.name;role:"titleS"}
                                    Opal.MText {text:modelData.m;role:"bodyS";color:Opal.Theme.subtext}}
                                Tag {label:modelData.d||""}
                                Row {spacing:-6;Repeater {model:modelData.icons;Ico {required property string modelData;width:28;height:28;n:modelData}}}
                            }}
                    }
                }
                // The current room, drawn as it is laid out.
                Rectangle {Layout.fillWidth:true;Layout.fillHeight:rv.wide;Layout.preferredHeight:rv.wide ? -1 : 300;radius:30;color:Opal.Theme.level(3)
                    RowLayout {id:rh;x:18;y:14;width:parent.width-36
                        Opal.MText {text:"1";role:"title";color:Opal.Theme.primary}
                        Opal.MText {text:"opal";role:"title";Layout.fillWidth:true}
                        Row {spacing:8
                            Rectangle {width:snowRow.implicitWidth+18;height:30;radius:15;color:Opal.Theme.tertiaryContainer
                                Row {id:snowRow;anchors.centerIn:parent;spacing:6
                                    Opal.Glyph {name:"play_arrow";font.pixelSize:16;color:Opal.Theme.tertiaryInk}
                                    Opal.MText {text:"snowfall";role:"label";color:Opal.Theme.tertiaryInk}}}
                        }
                    }
                    Room {anchors {left:parent.left;right:parent.right;top:rh.bottom;bottom:parent.bottom;margins:12;topMargin:10}
                        tiles:[{icon:"kitty",t:"claude",x:0,y:0,w:.55,h:1,focus:true,term:true},{icon:"chrome",t:"Hyprland Wiki",x:.55,y:0,w:.45,h:.6},{icon:"dolphin",t:"Wallpapers",x:.55,y:.6,w:.45,h:.4}]}
                }
            }
            Bar {id:bar;hint:"Open in this room, or start a new one…";anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26;leftMargin:rv.wide ? parent.width*.25 : 12;rightMargin:rv.wide ? parent.width*.25 : 12}}
        }
    }

    // 3. Desk: a glance on the wallpaper, rooms in a carousel at the thumb, five pins, one bar.
    Component {id:deskView
        Item {
            Wall {anchors.fill:parent;dim:.28}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6}
            Column {x:26;y:96;spacing:2
                Opal.MText {text:"Tuesday 7";font.pixelSize:18;color:"#ffffff";font.weight:Font.Medium}
                Opal.MText {text:"12:41";font.pixelSize:76;font.weight:Font.Black;color:"#ffffff"}
                Row {spacing:8;topPadding:6
                    Rectangle {width:ms.implicitWidth+22;height:34;radius:17;color:Opal.Theme.alpha("#000000",.35)
                        Row {id:ms;anchors.centerIn:parent;spacing:8
                            Opal.Glyph {name:"music_note";font.pixelSize:16;color:"#ffffff"}
                            Opal.MText {text:"snowfall · lofi girl";role:"label";color:"#ffffff"}}}
                    Rectangle {width:ns.implicitWidth+22;height:34;radius:17;color:Opal.Theme.alpha("#000000",.35)
                        Row {id:ns;anchors.centerIn:parent;spacing:8
                            Ico {width:16;height:16;n:"discord"}
                            Opal.MText {text:"3";role:"label";color:"#ffffff"}}}
                }
            }
            // Carousel: the current room is centred, its neighbours peek.
            Item {
                id:car;anchors {left:parent.left;right:parent.right;bottom:pins.top;bottomMargin:18}
                height:300
                Repeater {model:[{x:-286,name:"Board",tiles:[{icon:"kicad",t:"PCB",x:0,y:0,w:.66,h:1},{icon:"chrome",t:"JLCPCB",x:.66,y:0,w:.34,h:1}]},
                                 {x:46,name:"opal",cur:true,tiles:[{icon:"kitty",t:"claude",x:0,y:0,w:.55,h:1,focus:true,term:true},{icon:"chrome",t:"Wiki",x:.55,y:0,w:.45,h:.6},{icon:"dolphin",t:"Wallpapers",x:.55,y:.6,w:.45,h:.4}]},
                                 {x:378,name:"Play",tiles:[{icon:"steam",t:"DELTARUNE",x:0,y:0,w:1,h:1,art:true}]}]
                    Rectangle {required property var modelData;x:modelData.x;y:modelData.cur ? 0 : 22;width:320;height:modelData.cur ? 300 : 256;radius:30;color:Opal.Theme.alpha(Opal.Theme.level(3),.94)
                        Opal.MText {id:rn;x:18;y:14;text:modelData.name;role:"title"}
                        Room {anchors {left:parent.left;right:parent.right;top:rn.bottom;bottom:parent.bottom;margins:12;topMargin:10} tiles:modelData.tiles}
                    }
                }
            }
            Row {id:pins;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:bar.top;anchors.bottomMargin:16;spacing:22
                Repeater {model:["kitty","chrome","dolphin","steam","discord"];Ico {required property string modelData;width:44;height:44;n:modelData}}}
            Bar {id:bar;anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26}}
        }
    }

    // 4. Shelf: the wallpaper stays visible; a half sheet holds a typographic index in two columns.
    Component {id:shelfView
        Item {
            Wall {anchors.fill:parent;dim:.12}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6}
            Opal.MText {x:26;y:120;text:"12:41";font.pixelSize:64;font.weight:Font.Bold;color:"#ffffff"}
            Rectangle {
                anchors {left:parent.left;right:parent.right;bottom:parent.bottom}
                height:parent.height*.6;radius:36;color:Opal.Theme.base
                Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:10;width:36;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.3)}
                RowLayout {
                    anchors {left:parent.left;right:parent.right;top:parent.top;margins:24;topMargin:34}
                    spacing:20
                    Repeater {model:[{h:"Running",rows:[{t:"kitty",m:"claude — ~/opal",i:"kitty",l:true},{t:"Chrome",m:"Hyprland Wiki",i:"chrome",l:true,d:true},{t:"Dolphin",m:"Wallpapers",i:"dolphin",l:true},{t:"Spotify",m:"snowfall · paused",i:"spotify",l:true}]},
                                     {h:"Continue",rows:[{t:"ROADMAP",m:"md · 1 h ago",g:"description"},{t:"DELTARUNE",m:"2 h ago",i:"steam"},{t:"opal-dock",m:"PCB · yesterday",i:"kicad",d:true},{t:"Wallpapers",m:"folder",g:"folder"}]}]
                        ColumnLayout {required property var modelData;Layout.fillWidth:true;Layout.alignment:Qt.AlignTop;spacing:14
                            Opal.MText {text:modelData.h.toUpperCase();role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2}
                            Repeater {model:modelData.rows
                                RowLayout {required property var modelData;spacing:10;Layout.fillWidth:true
                                    Item {Layout.preferredWidth:28;Layout.preferredHeight:28
                                        Ico {anchors.fill:parent;n:modelData.i||""}
                                        Opal.Glyph {anchors.centerIn:parent;visible:!!modelData.g;name:modelData.g||"";font.pixelSize:22;color:Opal.Theme.subtext}}
                                    ColumnLayout {spacing:0;Layout.fillWidth:true
                                        Row {spacing:6
                                            Opal.MText {text:modelData.t;font.pixelSize:17;font.weight:modelData.l ? Font.DemiBold : Font.Normal}
                                            Rectangle {visible:!!modelData.d;width:6;height:6;radius:3;color:Opal.Theme.tertiary;anchors.verticalCenter:parent.verticalCenter}}
                                        Opal.MText {text:modelData.m;role:"labelS";color:Opal.Theme.subtext;elide:Text.ElideRight;Layout.fillWidth:true}
                                    }
                                }
                            }
                        }
                    }
                }
                Bar {anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26}}
            }
        }
    }

    // 5. Content cards: each item shows its content, not an app label.
    Component {id:cardsView
        Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6;ink:Opal.Theme.text}
            Column {
                anchors {left:parent.left;right:parent.right;bottom:bar.top;margins:12;bottomMargin:12}
                spacing:10
                Row {width:parent.width;spacing:10
                    // A game shows its art.
                    Rectangle {width:(parent.width-10)*.58;height:150;radius:26;clip:true;color:"#000"
                        Image {anchors.fill:parent;source:root.hero;sourceSize:Qt.size(800,400);fillMode:Image.PreserveAspectCrop}
                        Rectangle {anchors.fill:parent;gradient:Gradient {GradientStop {position:.45;color:"transparent"} GradientStop {position:1;color:"#cc000000"}}}
                        Column {x:16;anchors.bottom:parent.bottom;anchors.bottomMargin:14
                            Opal.MText {text:"DELTARUNE";role:"titleS";color:"#fff"}
                            Opal.MText {text:"Chapter 4 · 2 h ago";role:"labelS";color:"#ddd"}}
                        Rectangle {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:12;width:40;height:40;radius:20;color:"#ffffff"
                            Opal.Glyph {anchors.centerIn:parent;name:"play_arrow";color:"#000";font.pixelSize:22}}
                    }
                    // A document shows its first lines.
                    Rectangle {width:(parent.width-10)*.42;height:150;radius:26;color:Opal.Theme.level(2)
                        Column {x:14;y:14;width:parent.width-28;spacing:4
                            Opal.MText {text:"ROADMAP-2026-10.md";role:"labelS";color:Opal.Theme.primary;elide:Text.ElideRight;width:parent.width}
                            Opal.MText {text:"Opal overhaul — October 2026";role:"label";font.weight:Font.Bold;wrapMode:Text.Wrap;width:parent.width}
                            Opal.MText {text:"Tablet is part of phone mode. Wide outputs become a tablet layout…";role:"labelS";color:Opal.Theme.subtext;wrapMode:Text.Wrap;width:parent.width;maximumLineCount:4;elide:Text.ElideRight}}
                    }
                }
                Row {width:parent.width;spacing:10
                    // A web page shows its title and site, and where it is open.
                    Rectangle {width:(parent.width-10)*.5;height:120;radius:26;color:Opal.Theme.level(2)
                        Column {x:14;y:14;width:parent.width-28;spacing:6
                            Row {spacing:6;Ico {width:16;height:16;n:"chrome"} Opal.MText {text:"wiki.hypr.land";role:"labelS";color:Opal.Theme.subtext}}
                            Opal.MText {text:"Lua configuration";role:"titleS";wrapMode:Text.Wrap;width:parent.width}
                            Tag {label:"Open on Desktop"}}
                    }
                    // Music shows the track with controls.
                    Rectangle {width:(parent.width-10)*.5;height:120;radius:26;color:Opal.Theme.tertiaryContainer
                        Column {x:14;y:14;spacing:2
                            Opal.MText {text:"snowfall";role:"titleS";color:Opal.Theme.tertiaryInk}
                            Opal.MText {text:"lofi girl";role:"labelS";color:Opal.Theme.tertiaryInk;opacity:.8}}
                        Row {x:10;anchors.bottom:parent.bottom;anchors.bottomMargin:10;spacing:2
                            Repeater {model:["skip_previous","play_arrow","skip_next"];Rectangle {required property string modelData;width:40;height:40;radius:20;color:modelData==="play_arrow" ? Opal.Theme.alpha("#000000",.15) : "transparent"
                                Opal.Glyph {anchors.centerIn:parent;name:parent.modelData;color:Opal.Theme.tertiaryInk;font.pixelSize:22}}}}
                    }
                }
                // Now: the live window, largest, at the thumb.
                Rectangle {width:parent.width;height:250;radius:30;color:Opal.Theme.level(3)
                    RowLayout {id:nh;x:16;y:14;width:parent.width-32;spacing:10
                        Ico {width:26;height:26;n:"kitty"}
                        Opal.MText {text:"claude — ~/opal";role:"titleS";Layout.fillWidth:true}
                        Opal.MText {text:"+2 windows";role:"labelS";color:Opal.Theme.subtext}}
                    Term {anchors {left:parent.left;right:parent.right;top:nh.bottom;bottom:parent.bottom;margins:12;topMargin:10}
                        lines:["~/opal $ claude","✻ Merging workstream A…","  190 tests OK","  render: phone, tablet, gestures","  pills + assistant agents started","> more, better designs are needed"]}
                }
            }
            Bar {id:bar;anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:12;bottomMargin:26}}
        }
    }
}
