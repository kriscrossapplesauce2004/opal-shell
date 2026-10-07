import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Launcher round 3: one design that mixes Ladder, Rooms, Desk and Shelf, shown in several states. Static data only.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string wall:"file:///home/melissa/Pictures/Wallpapers/default.png"
    readonly property string hero:"file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_hero.jpg"
    readonly property string pap:"/usr/share/icons/Papirus/64x64/apps/"
    function icon(n) {
        const fixed={kitty:"/usr/share/pixmaps/kitty.png",steam:"/usr/share/pixmaps/steam.png",chrome:pap+"google-chrome.svg",dolphin:pap+"org.kde.dolphin.svg",prism:pap+"org.prismlauncher.PrismLauncher.svg",obs:pap+"com.obsproject.Studio.svg",files:pap+"org.gnome.Nautilus.svg",calc:pap+"org.gnome.Calculator.svg",kate:pap+"org.kde.kate.svg",writer:pap+"libreoffice-writer.svg",signal:pap+"signal-desktop.svg"};
        return "file://"+(fixed[n]||pap+n+".svg");
    }
    // Shared fixture data.
    readonly property var rooms:[
        {n:1,name:"opal",tiles:[{icon:"kitty",t:"claude",x:0,y:0,w:.55,h:1,focus:true,term:true},{icon:"chrome",t:"Hyprland Wiki",x:.55,y:0,w:.45,h:.6},{icon:"dolphin",t:"Wallpapers",x:.55,y:.6,w:.45,h:.4}]},
        {n:2,name:"Play",tiles:[{icon:"steam",t:"DELTARUNE",x:0,y:0,w:1,h:1,art:true}]},
        {n:3,name:"Board",tiles:[{icon:"kicad",t:"opal-dock PCB",x:0,y:0,w:.64,h:1},{icon:"chrome",t:"JLCPCB",x:.64,y:0,w:.36,h:1}]}
    ]
    readonly property var ladder:[
        {t:"ROADMAP-2026-10.md",m:"Kate · 1 h ago",i:"kate",s:15,o:.62},
        {t:"Hyprland Wiki",m:"Chrome · open on Desktop",i:"chrome",s:18,o:.78,d:true},
        {t:"snowfall",m:"lofi girl · paused",i:"spotify",s:21,o:.92,media:true}
    ]
    readonly property var earlier:[{i:"steam",t:"DELTARUNE"},{i:"prism",t:"Prism"},{i:"kicad",t:"PCB"},{i:"discord",t:"#opal-dev"}]

    Window {
        id:fixture
        width:412;height:915;visible:true;color:"#000"
        property int step:0
        property var cases:[
            {name:"r3-1-home",view:homeView},
            {name:"r3-2-room-morph",view:homeView,morph:.5},
            {name:"r3-3-drawer",view:drawerView},
            {name:"r3-4-docked",view:homeView,docked:true},
            {name:"r3-5-tablet",view:homeView,w:1280,h:800},
            {name:"r3-6-home-light",view:homeView,light:true}
        ]
        property var current:cases[0]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            current=cases[step];
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:!!current.light});
            fixture.width=current.w||412;fixture.height=current.h||915;
            loader.sourceComponent=null;loader.sourceComponent=current.view;
            grab.restart();
        }
        Timer {id:grab;interval:1600;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    component Ico:Image {property string n:"";source:n ? root.icon(n) : "";sourceSize:Qt.size(96,96);smooth:true;fillMode:Image.PreserveAspectFit}
    component Wall:Item {
        Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1600,1600);fillMode:Image.PreserveAspectCrop}
        // Scrim: light at the top for the glance, heavier where content sits.
        Rectangle {anchors.fill:parent;gradient:Gradient {
            GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,.10)}
            GradientStop {position:.35;color:Opal.Theme.alpha(Opal.Theme.base,.45)}
            GradientStop {position:1;color:Opal.Theme.alpha(Opal.Theme.base,.92)}}}
    }
    component Status:RowLayout {
        height:32
        Opal.MText {text:"12:41";role:"label";Layout.leftMargin:22}
        Item {Layout.fillWidth:true}
        Opal.Glyph {name:"wifi";font.pixelSize:15}
        Opal.Glyph {name:"battery_5_bar";font.pixelSize:15}
        Opal.MText {text:"76%";role:"labelS";Layout.rightMargin:22}
    }
    // Assist chip with an app icon or a symbol. Tonal when selected.
    component AppChip:Rectangle {
        property string i:""
        property string g:""
        property string t:""
        property string tag:""
        property bool on:false
        implicitWidth:cr.implicitWidth+(t ? 22 : 14);implicitHeight:36;radius:18
        color:on ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.level(2),.86)
        border.width:on ? 0 : 1;border.color:Opal.Theme.outline
        Row {id:cr;anchors.centerIn:parent;spacing:7
            Ico {visible:parent.parent.i!=="";width:20;height:20;n:parent.parent.i;anchors.verticalCenter:parent.verticalCenter}
            Opal.Glyph {visible:parent.parent.g!=="";name:parent.parent.g;font.pixelSize:18;anchors.verticalCenter:parent.verticalCenter;color:parent.parent.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
            Opal.MText {visible:parent.parent.t!=="";text:parent.parent.t;role:"label";anchors.verticalCenter:parent.verticalCenter;color:parent.parent.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
            Rectangle {visible:parent.parent.tag!=="";width:tg.implicitWidth+12;height:20;radius:10;color:Opal.Theme.alpha(Opal.Theme.tertiary,.2);anchors.verticalCenter:parent.verticalCenter
                Opal.MText {id:tg;anchors.centerIn:parent;text:parent.parent.parent.tag;role:"labelS";color:Opal.Theme.tertiary}}
        }
    }
    component Term:Rectangle {
        radius:14;color:"#0d0f12";clip:true
        Column {x:10;y:8;spacing:2
            Repeater {model:["~/opal $ claude","✻ Round 3 prototypes…","  6 states rendered","> chips and morphing"]
                Text {required property string modelData;text:modelData;color:modelData.startsWith(">") ? "#c7cc79" : "#cfd2d6";font.family:"CaskaydiaCove Nerd Font";font.pixelSize:11}}}
    }
    component RoomMini:Item {
        property var tiles:[]
        Repeater {model:parent.tiles
            Rectangle {
                required property var modelData
                x:modelData.x*parent.width+2;y:modelData.y*parent.height+2;width:modelData.w*parent.width-4;height:modelData.h*parent.height-4
                radius:12;clip:true;color:Opal.Theme.level(1)
                border.width:modelData.focus ? 2 : 0;border.color:Opal.Theme.primary
                Image {anchors.fill:parent;visible:modelData.art===true;source:root.hero;sourceSize:Qt.size(700,350);fillMode:Image.PreserveAspectCrop}
                Term {anchors.fill:parent;anchors.margins:5;visible:modelData.term===true}
                Column {visible:!modelData.term&&!modelData.art;anchors.centerIn:parent;spacing:4;width:parent.width-12
                    Ico {anchors.horizontalCenter:parent.horizontalCenter;width:26;height:26;n:modelData.icon}
                    Opal.MText {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:modelData.t;role:"labelS";color:Opal.Theme.subtext;elide:Text.ElideRight}}
            }
        }
    }
    component RoomCard:Rectangle {
        property var room:null
        property bool current:false
        radius:30;color:Opal.Theme.alpha(Opal.Theme.level(3),.96)
        RowLayout {id:rh;x:18;y:14;width:parent.width-36;spacing:8
            Opal.MText {text:parent.parent.room ? parent.parent.room.n : "";role:"titleS";color:Opal.Theme.primary}
            Opal.MText {text:parent.parent.room ? parent.parent.room.name : "";role:"titleS";Layout.fillWidth:true}
            Opal.MText {visible:parent.parent.current;text:"Here";role:"labelS";color:Opal.Theme.primary}
        }
        RoomMini {anchors {left:parent.left;right:parent.right;top:rh.bottom;bottom:parent.bottom;margins:12;topMargin:10} tiles:parent.room ? parent.room.tiles : []}
    }
    component Bar:Rectangle {
        property string hint:"Search apps, files, rooms…"
        height:56;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(3),.94)
        RowLayout {anchors.fill:parent;anchors.leftMargin:20;anchors.rightMargin:8;spacing:10
            Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
            Opal.MText {Layout.fillWidth:true;text:parent.parent.hint;role:"body";color:Opal.Theme.subtext}
            Rectangle {width:40;height:40;radius:20;color:Opal.Theme.primaryContainer
                Opal.Glyph {anchors.centerIn:parent;name:"apps";font.pixelSize:20;color:Opal.Theme.containerInk}}
        }
    }
    component Pins:Row {
        spacing:20
        Repeater {model:["kitty","chrome","dolphin","steam","discord"];Ico {required property string modelData;width:46;height:46;n:modelData}}
    }

    // Home. The same parts arrange themselves for phone, tablet and docked.
    Component {id:homeView
        Item {
            id:home
            readonly property bool wide:width>700
            readonly property bool docked:!!fixture.current.docked
            readonly property real morph:fixture.current.morph||0
            Wall {anchors.fill:parent}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6}

            // Glance: date, clock and live chips.
            Column {id:glance;x:24;y:56;spacing:4;width:home.wide ? 420 : parent.width-48
                Opal.MText {text:"Tuesday 7 October";role:"titleS"}
                Opal.MText {text:"12:41";font.pixelSize:home.docked ? 44 : home.wide ? 64 : 54;font.weight:Font.Black}
                Flow {width:parent.width;spacing:8;topPadding:4
                    AppChip {g:"music_note";t:"snowfall";on:true}
                    AppChip {i:"discord";t:"3"}
                    AppChip {g:"timer";t:"Focus 18:20"}
                    AppChip {visible:home.docked;g:"desktop_windows";t:"Docked";tag:"Dell U2720Q";on:true}
                }
            }

            // Earlier: finished things shrink to chips. Ladder: recent things step up in size toward the room.
            Column {
                id:story
                x:24;width:home.wide ? 420 : parent.width-48
                anchors.top:glance.bottom;anchors.topMargin:home.docked ? 18 : home.wide ? 26 : 16
                spacing:12
                Opal.MText {text:"EARLIER";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.3}
                Flow {width:parent.width;spacing:8
                    Repeater {model:root.earlier;AppChip {required property var modelData;i:modelData.i;t:modelData.t}}}
                Item {width:1;height:4}
                Repeater {model:home.docked ? [] : home.wide ? root.ladder : root.ladder.slice(1)
                    Row {required property var modelData;spacing:12;opacity:modelData.o
                        Ico {width:modelData.s+8;height:width;n:modelData.i;anchors.verticalCenter:parent.verticalCenter}
                        Column {
                            Row {spacing:8
                                Opal.MText {text:modelData.t;font.pixelSize:modelData.s;font.weight:modelData.media ? Font.DemiBold : Font.Medium}
                                Rectangle {visible:!!modelData.d;width:7;height:7;radius:4;color:Opal.Theme.tertiary;anchors.verticalCenter:parent.verticalCenter}}
                            Opal.MText {text:modelData.m;role:"labelS";color:Opal.Theme.subtext}}
                    }
                }
            }

            // Docked: rooms live on the monitor, so here they are chips; the rest of the phone is a trackpad.
            Column {
                visible:home.docked
                anchors {left:parent.left;right:parent.right;top:story.bottom;bottom:bar.top;margins:16;topMargin:22;bottomMargin:16}
                spacing:12
                Opal.MText {text:"ON DELL U2720Q";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.3;leftPadding:8}
                Flow {width:parent.width;spacing:8
                    Repeater {model:root.rooms;AppChip {required property var modelData;g:"space_dashboard";t:modelData.n+" · "+modelData.name;on:modelData.n===1}}
                    AppChip {g:"add";t:"Room"}}
                Rectangle {width:parent.width;height:parent.height-90;radius:30;color:Opal.Theme.alpha(Opal.Theme.level(2),.9);border.width:1;border.color:Opal.Theme.outline
                    Column {anchors.centerIn:parent;spacing:6
                        Opal.Glyph {anchors.horizontalCenter:parent.horizontalCenter;name:"touchpad_mouse";font.pixelSize:34;color:Opal.Theme.subtext}
                        Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:"Trackpad";role:"titleS"}
                        Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:"Two fingers to scroll · tap to click";role:"labelS";color:Opal.Theme.subtext}}}
            }

            // Rooms: the current room as a card; the others as chips under it. A swipe morphs card to chip and chip to card.
            Item {
                id:roomArea
                visible:!home.docked
                x:home.wide ? 470 : 0;width:home.wide ? parent.width-470-24 : parent.width
                anchors.bottom:roomChips.top;anchors.bottomMargin:12
                height:home.wide ? parent.height-st.height-roomChips.height-bar.height-110 : 232
                // Neighbour peeking from the right.
                RoomCard {room:root.rooms[1];x:roomArea.width-26+(-roomArea.width*.62*home.morph);y:18+(-18*home.morph);width:roomArea.width-48;height:parent.height-36+(36*home.morph);opacity:.75+.25*home.morph}
                RoomCard {room:root.rooms[0];current:home.morph===0
                    x:24-(home.morph*roomArea.width*.55);y:home.morph*60;width:(roomArea.width-48)*(1-.55*home.morph);height:parent.height*(1-.6*home.morph);opacity:1-.5*home.morph}
            }
            Flow {
                id:roomChips;visible:!home.docked
                x:roomArea.x+24;width:roomArea.width-48
                anchors.bottom:pins.top;anchors.bottomMargin:home.wide ? 14 : 18
                spacing:8
                Repeater {model:root.rooms;AppChip {required property var modelData;g:"space_dashboard";t:modelData.n+" · "+modelData.name;on:home.morph>.4 ? modelData.n===2 : modelData.n===1}}
                AppChip {g:"add";t:"Room"}
            }
            Pins {id:pins;visible:!home.docked;anchors.horizontalCenter:home.wide ? undefined : parent.horizontalCenter;x:home.wide ? roomArea.x+24 : 0;anchors.bottom:bar.top;anchors.bottomMargin:16}
            Bar {id:bar;anchors.bottom:parent.bottom;anchors.bottomMargin:26
                x:home.wide ? (parent.width-width)/2 : 12;width:home.wide ? 560 : parent.width-24}
        }
    }

    // Drawer: the Shelf sheet comes up with filter chips, then running and recent, then a plain A–Z grid.
    Component {id:drawerView
        Item {
            Wall {anchors.fill:parent}
            Status {id:st;width:parent.width;anchors.top:parent.top;anchors.topMargin:6}
            Opal.MText {x:24;y:56;text:"12:41";font.pixelSize:40;font.weight:Font.Black;opacity:.7}
            Rectangle {
                anchors {left:parent.left;right:parent.right;bottom:parent.bottom}
                height:parent.height*.86;radius:34;color:Opal.Theme.base
                Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:10;width:36;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.3)}
                Column {
                    anchors {left:parent.left;right:parent.right;top:parent.top;margins:16;topMargin:26}
                    spacing:14
                    Bar {width:parent.width;hint:"Search apps, files, rooms…"}
                    Flow {width:parent.width;spacing:8
                        AppChip {g:"apps";t:"All";on:true}
                        AppChip {g:"play_circle";t:"Running"}
                        AppChip {g:"sports_esports";t:"Games"}
                        AppChip {g:"folder";t:"Files"}
                        AppChip {g:"code";t:"Dev"}}
                    // Running and Continue, as two short columns.
                    Row {width:parent.width;spacing:12
                        Repeater {model:[{h:"Running",rows:[{t:"kitty",m:"claude — ~/opal",i:"kitty"},{t:"Chrome",m:"Hyprland Wiki",i:"chrome"}]},{h:"Continue",rows:[{t:"DELTARUNE",m:"2 h ago",i:"steam"},{t:"ROADMAP.md",m:"1 h ago",i:"kate"}]}]
                            Rectangle {required property var modelData;width:(parent.width-12)/2;height:130;radius:24;color:Opal.Theme.level(2)
                                Column {x:14;y:12;width:parent.width-28;spacing:10
                                    Opal.MText {text:modelData.h.toUpperCase();role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2}
                                    Repeater {model:modelData.rows
                                        Row {required property var modelData;spacing:10
                                            Ico {width:28;height:28;n:modelData.i;anchors.verticalCenter:parent.verticalCenter}
                                            Column {Opal.MText {text:modelData.t;role:"label";font.weight:Font.DemiBold} Opal.MText {text:modelData.m;role:"labelS";color:Opal.Theme.subtext}}}}}}}
                    }
                    Opal.MText {text:"ALL APPS";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2;leftPadding:4}
                    Grid {width:parent.width;columns:4;rowSpacing:18
                        Repeater {model:[{i:"blender",t:"Blender"},{i:"calc",t:"Calculator"},{i:"chrome",t:"Chrome"},{i:"code",t:"Code"},{i:"discord",t:"Discord"},{i:"dolphin",t:"Dolphin"},{i:"files",t:"Files"},{i:"firefox",t:"Firefox"},{i:"freecad",t:"FreeCAD"},{i:"gimp",t:"GIMP"},{i:"inkscape",t:"Inkscape"},{i:"kicad",t:"KiCad"},{i:"kitty",t:"kitty"},{i:"krita",t:"Krita"},{i:"obs",t:"OBS"},{i:"obsidian",t:"Obsidian"}]
                            Column {required property var modelData;width:parent.width/4;spacing:6
                                Ico {width:52;height:52;n:modelData.i;anchors.horizontalCenter:parent.horizontalCenter}
                                Opal.MText {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:modelData.t;role:"labelS";elide:Text.ElideRight}}}
                    }
                }
            }
        }
    }
}
