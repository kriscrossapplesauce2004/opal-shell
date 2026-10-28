import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Render round 1 (2026-10-28): Quick Settings without notifications on the desktop, resizable tiles, edit mode and detail sheets; the segmented activity pill; the notification and clock pills; named spaces; the customisable lock screen. Static data.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string papirus:"/usr/share/icons/Papirus/64x64/apps/"
    readonly property string wallpaper:"file:///home/melissa/Pictures/Wallpapers/dr5-keyart-YzI66DkClTeJ5jBQ.png"
    readonly property var notes:[
        {icon:"discord",app:"Discord",title:"Sam",body:"are you on tonight?",count:2,time:"now"},
        {icon:"steam",app:"Steam",title:"DELTARUNE update ready",body:"Chapter 5 · 1.2 GB",count:1,time:"6 min"},
        {icon:"thunderbird",app:"Thunderbird",title:"Your order has shipped",body:"Arrives Friday",count:1,time:"22 min"}
    ]
    // Activities, most important first. w is the share of the pill.
    readonly property var acts:[
        {k:"timer",g:"timer",t:"4:12",long:"Pasta timer · 4:12",tint:"tertiary"},
        {k:"download",app:"firefox",t:"62%",long:"DELTARUNE_OST.zip · 62%",prog:.62},
        {k:"music",app:"spotify",t:"",long:"ASGORE · Toby Fox",wave:true}
    ]

    Window {
        id:fixture
        width:1280;height:800;visible:true;color:"black"
        property int step:0
        property var cases:[
            {name:"01-shelf-pill-states",view:shelfStates,w:1280,h:800},
            {name:"02-notification-card",view:notifCard,w:1280,h:800},
            {name:"03-qs-a-compact",view:qsA,w:1280,h:800},
            {name:"04-qs-b-wide",view:qsB,w:1280,h:800},
            {name:"05-qs-edit-mode",view:qsEdit,w:1280,h:800},
            {name:"06-qs-detail-wifi",view:qsWifi,w:1280,h:800},
            {name:"07-qs-detail-displays",view:qsDisplays,w:1280,h:800},
            {name:"08-qs-phone-shade",view:qsPhone,w:412,h:915},
            {name:"09-activity-segments",view:segStates,w:1280,h:800},
            {name:"10-activity-card",view:segCard,w:1280,h:800},
            {name:"11-activity-everywhere",view:segEverywhere,w:1280,h:800},
            {name:"12-clock-calendar-card",view:clockCard,w:1280,h:800},
            {name:"13-spaces-card",view:spacesCard,w:1280,h:800},
            {name:"14-spaces-edit",view:spacesEdit,w:1280,h:800},
            {name:"15-lock-a-stacked",view:lockA,w:1280,h:800},
            {name:"16-lock-b-shapes",view:lockB,w:1280,h:800},
            {name:"17-lock-notifications",view:lockNotes,w:1280,h:800},
            {name:"18-lock-quick-settings",view:lockQs,w:1280,h:800},
            {name:"19-lock-phone",view:lockPhone,w:412,h:915},
            {name:"20-lock-settings-editor",view:lockSettings,w:1280,h:800}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            width=cases[step].w;height=cases[step].h;
            loader.sourceComponent=null;loader.sourceComponent=cases[step].view;
            grab.restart();
        }
        Timer {id:grab;interval:2200;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        // OPAL_CASE=<name part> renders matching cases only.
        Component.onCompleted:{const only=Quickshell.env("OPAL_CASE");if(only)cases=cases.filter(c=>c.name.indexOf(only)>=0);Qt.callLater(run);}
    }

    // ---------- Shared pieces ----------

    component Wall:Image {
        property bool blurred:false
        anchors.fill:parent;source:root.wallpaper;fillMode:Image.PreserveAspectCrop
        sourceSize:blurred ? Qt.size(48,30) : Qt.size(1280,800);smooth:true
    }
    component AppIco:Item {
        id:ai
        property string icon:""
        implicitWidth:24;implicitHeight:24
        Image {id:img;anchors.fill:parent;sourceSize:Qt.size(ai.width*2,ai.height*2);source:ai.icon!=="" ? "file://"+root.papirus+ai.icon+".svg" : "";smooth:true}
        Opal.Glyph {anchors.centerIn:parent;visible:img.status!==Image.Ready;name:"apps";font.pixelSize:ai.width*.8;color:Opal.Theme.primary}
    }
    component G:Opal.Glyph {}
    component Txt:Opal.MText {}
    // Round icon button.
    component IconBtn:Rectangle {
        property string g:""
        property bool filled:false
        property bool tonal:false
        property real size:40
        width:size;height:size;radius:size/2
        color:filled ? Opal.Theme.primary : tonal ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.text,.08)
        G {anchors.centerIn:parent;name:parent.g;font.pixelSize:parent.size*.5;color:parent.filled ? Opal.Theme.onPrimary : parent.tonal ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
    }
    // Pill button: filled, tonal or text.
    component PillBtn:Rectangle {
        property string g:""
        property string t:""
        property string kind:"tonal"
        property real h:40
        implicitWidth:pbr.implicitWidth+(t!=="" ? 32 : 20);implicitHeight:h;radius:h/2
        color:kind==="filled" ? Opal.Theme.primary : kind==="tonal" ? Opal.Theme.secondaryContainer : kind==="outline" ? "transparent" : "transparent"
        border.width:kind==="outline" ? 1 : 0;border.color:Opal.Theme.alpha(Opal.Theme.text,.24)
        readonly property color ink:kind==="filled" ? Opal.Theme.onPrimary : kind==="tonal" ? Opal.Theme.onSecondaryContainer : Opal.Theme.primary
        Row {id:pbr;anchors.centerIn:parent;spacing:8
            G {visible:parent.parent.g!=="";name:parent.parent.g;font.pixelSize:18;color:parent.parent.ink;anchors.verticalCenter:parent.verticalCenter}
            Txt {visible:parent.parent.t!=="";text:parent.parent.t;role:"label";color:parent.parent.ink;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    component Chip:Rectangle {
        property string g:""
        property string t:""
        property bool on:false
        implicitWidth:chr.implicitWidth+24;implicitHeight:32;radius:16
        color:on ? Opal.Theme.secondaryContainer : "transparent"
        border.width:on ? 0 : 1;border.color:Opal.Theme.alpha(Opal.Theme.text,.2)
        Row {id:chr;anchors.centerIn:parent;spacing:6
            G {visible:parent.parent.g!=="";name:parent.parent.g;font.pixelSize:16;color:parent.parent.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}
            Txt {text:parent.parent.t;role:"label";color:parent.parent.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // Popup card above the Shelf.
    component Card:Rectangle {
        radius:28;color:Opal.Theme.alpha(Opal.Theme.level(2),.98)
        border.width:1;border.color:Opal.Theme.outline
    }
    // Lock-screen glass.
    component GlassBox:Rectangle {
        color:Opal.Theme.alpha(Opal.Theme.level(3),.62);border.width:1;border.color:Opal.Theme.alpha("#ffffff",.10)
    }
    component Caption:Txt {role:"labelS";color:Opal.Theme.subtext}
    component Heading:Txt {role:"titleS";color:"#ffffff"}
    component Switch:Rectangle {
        property bool on:true
        width:52;height:32;radius:16;color:on ? Opal.Theme.primary : Opal.Theme.alpha(Opal.Theme.text,.12)
        border.width:on ? 0 : 2;border.color:Opal.Theme.alpha(Opal.Theme.text,.4)
        Rectangle {width:parent.on ? 24 : 16;height:width;radius:width/2;anchors.verticalCenter:parent.verticalCenter;x:parent.on ? parent.width-width-4 : 8
            color:parent.on ? Opal.Theme.onPrimary : Opal.Theme.alpha(Opal.Theme.text,.6)
            G {visible:parent.parent.on;anchors.centerIn:parent;name:"check";font.pixelSize:16;color:Opal.Theme.primary}}
    }
    component Slider:Rectangle {
        property real v:.6
        property string g:"light_mode"
        property real h:40
        height:h;radius:h*.3;color:Opal.Theme.alpha(Opal.Theme.tile,.9)
        Rectangle {width:Math.max(parent.h,parent.width*parent.v)-4;height:parent.height;radius:parent.radius;color:Opal.Theme.primary}
        Rectangle {x:parent.width*parent.v;width:4;height:parent.height+8;y:-4;radius:2;color:Opal.Theme.primary}
        G {x:12;anchors.verticalCenter:parent.verticalCenter;name:parent.g;font.pixelSize:20;color:Opal.Theme.onPrimary}
    }

    // Mock app windows.
    component Win:Rectangle {
        id:win
        property string k:"kitty"
        radius:14
        color:k==="firefox" ? "#1c1b22" : k==="code" ? "#1e1e1e" : "#14121b"
        clip:true
        Item {visible:win.k==="firefox";anchors.fill:parent
            Rectangle {width:parent.width;height:34;color:"#2b2a33";topLeftRadius:14;topRightRadius:14
                Rectangle {x:12;y:6;width:180;height:28;topLeftRadius:8;topRightRadius:8;color:"#42414d"}}
            Rectangle {x:12;y:42;width:parent.width-24;height:24;radius:12;color:"#2b2a33"}
            Rectangle {x:24;y:84;width:parent.width-48;height:parent.height*.32;radius:20;color:Opal.Theme.primaryContainer
                Txt {x:22;y:20;text:"Material 3 Expressive";role:"headline";color:Opal.Theme.onContainer}
                Rectangle {x:22;anchors.bottom:parent.bottom;anchors.bottomMargin:20;width:120;height:36;radius:18;color:Opal.Theme.primary}}
            Grid {x:24;y:100+parent.height*.32;columns:2;spacing:12
                Repeater {model:4;Rectangle {width:(win.width-60)/2;height:90;radius:14;color:"#2b2a33"}}}
        }
        Column {visible:win.k==="kitty";x:16;y:16;spacing:4;width:parent.width-32
            Repeater {model:[["#a6e3a1","melissa@opal ~/.l/s/o/staging> git status"],["#cdd6f4","On branch main"],["#cdd6f4","Changes not staged for commit:"],["#f38ba8","        modified:   src/QuickSettings.qml"],["#f38ba8","        modified:   src/LockScene.qml"],["#cdd6f4",""],["#89b4fa","Untracked files:"],["#f38ba8","        tests/qspl-proto.qml"],["#cdd6f4",""],["#a6e3a1","melissa@opal ~/.l/s/o/staging> cargo build"],["#cdd6f4","   Compiling luna-compositor v0.1.0"],["#cdd6f4","   Building [=======>      ] 214/380"],["#a6e3a1","melissa@opal ~/.l/s/o/staging> ▋"]]
                Text {required property var modelData;width:parent.width;text:modelData[1];color:modelData[0];font.family:"monospace";font.pixelSize:13;elide:Text.ElideRight}}
        }
    }
    component Desk:Item {
        anchors.fill:parent
        Wall {}
        Win {k:"firefox";x:10;y:10;width:626;height:716}
        Win {k:"kitty";x:644;y:10;width:626;height:716}
    }

    // ---------- Shelf pills ----------

    component Island:Rectangle {height:44;radius:22;color:Opal.Theme.level(3)}

    // Notification pill: hidden, new (grows to the latest one), rest (icons + count) or open.
    component NotifPill:Rectangle {
        id:np
        property string st:"rest"
        visible:st!=="none"
        height:44;radius:22
        color:st==="open" ? Opal.Theme.primaryContainer : st==="new" ? Opal.Theme.secondaryContainer : Opal.Theme.level(3)
        width:st==="new" ? newRow.implicitWidth+28 : restRow.implicitWidth+24
        clip:true
        Row {id:newRow;visible:np.st==="new";anchors.verticalCenter:parent.verticalCenter;x:9;spacing:10
            AppIco {icon:"discord";width:26;height:26;anchors.verticalCenter:parent.verticalCenter}
            Txt {text:"Sam";role:"label";font.weight:Font.Bold;color:Opal.Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter}
            Txt {text:"are you on tonight?";role:"label";color:Opal.Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter}
        }
        // The dwell bar: how long until it shrinks back.
        Rectangle {visible:np.st==="new";anchors.bottom:parent.bottom;anchors.bottomMargin:4;x:22;width:(parent.width-44)*.55;height:3;radius:2;color:Opal.Theme.alpha(Opal.Theme.onSecondaryContainer,.5)}
        Row {id:restRow;visible:np.st!=="new";anchors.verticalCenter:parent.verticalCenter;x:10;spacing:8
            Row {spacing:-8;anchors.verticalCenter:parent.verticalCenter
                Repeater {model:["discord","steam","thunderbird"]
                    Rectangle {required property string modelData;width:28;height:28;radius:14;color:np.color
                        AppIco {anchors.centerIn:parent;icon:parent.modelData;width:24;height:24}}}
            }
            Txt {text:"4";role:"label";font.weight:Font.Bold;color:np.st==="open" ? Opal.Theme.onContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // Clock pill: plain, event soon, event now, or open.
    component ClockPill:Row {
        id:cp
        property string st:"normal"
        spacing:3
        Rectangle {
            height:44;width:clk.implicitWidth+28
            topLeftRadius:22;bottomLeftRadius:22;topRightRadius:cp.st==="normal"||cp.st==="open" ? 22 : 6;bottomRightRadius:topRightRadius
            color:cp.st==="open" ? Opal.Theme.primaryContainer : Opal.Theme.primary
            Row {id:clk;anchors.centerIn:parent;spacing:8
                Txt {text:"14:52";role:"titleS";color:cp.st==="open" ? Opal.Theme.onContainer : Opal.Theme.onPrimary;anchors.verticalCenter:parent.verticalCenter}
                Txt {visible:cp.st==="normal"||cp.st==="open";text:"Wed 28";role:"label";color:Opal.Theme.alpha(cp.st==="open" ? Opal.Theme.onContainer : Opal.Theme.onPrimary,.8);anchors.verticalCenter:parent.verticalCenter}
            }
        }
        // The event segment only appears while the event needs attention.
        Rectangle {
            visible:cp.st==="soon"||cp.st==="now"
            height:44;width:evr.implicitWidth+26;topLeftRadius:6;bottomLeftRadius:6;topRightRadius:22;bottomRightRadius:22
            color:Opal.Theme.tertiaryContainer
            Row {id:evr;anchors.centerIn:parent;spacing:8
                G {name:cp.st==="now" ? "videocam" : "event";font.pixelSize:18;color:Opal.Theme.onTertiaryContainer;anchors.verticalCenter:parent.verticalCenter}
                Txt {text:cp.st==="now" ? "Standup now" : "Standup in 8 min";role:"label";font.weight:Font.DemiBold;color:Opal.Theme.onTertiaryContainer;anchors.verticalCenter:parent.verticalCenter}
                Rectangle {visible:cp.st==="now";width:jt.implicitWidth+20;height:28;radius:14;color:Opal.Theme.tertiary;anchors.verticalCenter:parent.verticalCenter
                    Txt {id:jt;anchors.centerIn:parent;text:"Join";role:"label";color:Opal.Theme.base}}
            }
        }
    }
    component StatusPill:Island {
        width:sr.implicitWidth+24
        Row {id:sr;anchors.centerIn:parent;spacing:10
            G {name:"wifi";font.pixelSize:19;anchors.verticalCenter:parent.verticalCenter}
            G {name:"volume_up";font.pixelSize:19;anchors.verticalCenter:parent.verticalCenter}
            G {name:"battery_5_bar";font.pixelSize:19;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // Workspace pill: number, or the named space's icon in its colour.
    component WsPill:Island {
        id:wp
        property string icon:""
        property color tint:Opal.Theme.primary
        property string name:""
        property bool flash:false
        property bool open:false
        color:open ? Opal.Theme.primaryContainer : Opal.Theme.level(3)
        width:wr.implicitWidth+16
        Row {id:wr;anchors.verticalCenter:parent.verticalCenter;x:7;spacing:8
            Rectangle {width:wp.flash&&wp.name!=="" ? wn.implicitWidth+wg.width+26 : 30;height:30;radius:15;color:wp.tint;anchors.verticalCenter:parent.verticalCenter
                G {id:wg;visible:wp.icon!=="";x:wp.flash&&wp.name!=="" ? 8 : (parent.width-width)/2;anchors.verticalCenter:parent.verticalCenter;name:wp.icon;font.pixelSize:18;color:Opal.Theme.base}
                Txt {visible:wp.icon==="";anchors.centerIn:parent;text:"2";role:"label";font.weight:Font.Bold;color:Opal.Theme.onPrimary}
                Txt {id:wn;visible:wp.flash&&wp.name!=="";x:wg.x+wg.width+6;anchors.verticalCenter:parent.verticalCenter;text:wp.name;role:"label";font.weight:Font.Bold;color:Opal.Theme.base}
            }
            Row {visible:wp.flash;spacing:4;anchors.verticalCenter:parent.verticalCenter
                Repeater {model:["code-oss","kitty"];AppIco {required property string modelData;icon:modelData;width:22;height:22}}}
            Row {spacing:4;rightPadding:4;anchors.verticalCenter:parent.verticalCenter
                Repeater {model:4;Rectangle {required property int index;width:index===1 ? 14 : 6;height:6;radius:3;anchors.verticalCenter:parent.verticalCenter
                    color:index===1 ? (wp.open ? Opal.Theme.onContainer : wp.tint) : Opal.Theme.alpha(Opal.Theme.text,index<3 ? .6 : .28)}}
            }
        }
    }
    // Segmented activity pill: one pill split into segments with small gaps; the first, most important one is widest.
    component SegPill:Row {
        id:sp
        property var items:root.acts
        property bool labels:false
        property int selected:-1
        property real h:44
        property bool compact:false
        spacing:3
        Repeater {
            model:sp.items
            Rectangle {
                id:seg
                required property var modelData
                required property int index
                readonly property bool first:index===0
                readonly property bool last:index===sp.items.length-1
                readonly property bool sel:index===sp.selected
                readonly property bool wide:first||sp.labels
                height:sp.h
                width:segRow.implicitWidth+(sp.compact ? 18 : 24)
                topLeftRadius:first ? height/2 : 6;bottomLeftRadius:topLeftRadius
                topRightRadius:last ? height/2 : 6;bottomRightRadius:topRightRadius
                color:sel ? Opal.Theme.primaryContainer : modelData.tint==="tertiary"&&first ? Opal.Theme.tertiaryContainer : Opal.Theme.level(3)
                clip:true
                // Progress fills the segment from the left.
                Rectangle {visible:!!seg.modelData.prog;width:parent.width*(seg.modelData.prog||0);height:parent.height;color:Opal.Theme.alpha(Opal.Theme.primary,.22)
                    topLeftRadius:parent.topLeftRadius;bottomLeftRadius:parent.bottomLeftRadius}
                Row {
                    id:segRow;anchors.centerIn:parent;spacing:7
                    readonly property color ink:seg.sel ? Opal.Theme.onContainer : seg.modelData.tint==="tertiary"&&seg.first ? Opal.Theme.onTertiaryContainer : Opal.Theme.text
                    G {visible:!!seg.modelData.g;name:seg.modelData.g||"";font.pixelSize:sp.compact ? 16 : 19;color:segRow.ink;anchors.verticalCenter:parent.verticalCenter}
                    AppIco {visible:!!seg.modelData.app;icon:seg.modelData.app||"";width:sp.compact ? 18 : 22;height:width;anchors.verticalCenter:parent.verticalCenter}
                    // Music: a small live waveform.
                    Row {visible:!!seg.modelData.wave;spacing:2;anchors.verticalCenter:parent.verticalCenter
                        Repeater {model:[.4,.9,.6,1,.5];Rectangle {required property real modelData;width:3;height:(sp.compact ? 12 : 16)*modelData;radius:1.5;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}}}
                    Txt {visible:text!=="";text:seg.wide ? (seg.modelData.long||seg.modelData.t) : seg.modelData.t;role:"label";font.weight:Font.DemiBold;font.features:{"tnum":1};color:segRow.ink;anchors.verticalCenter:parent.verticalCenter}
                }
            }
        }
    }
    // The islands Shelf with every right-side pill.
    component Shelf:Item {
        id:sh
        property string notif:"rest"
        property string clock:"normal"
        property var acts:root.acts
        property int actSel:-1
        property bool actLabels:false
        property bool statusOpen:false
        property bool wsOpen:false
        property string wsIcon:""
        property color wsTint:Opal.Theme.primary
        property alias rightGroup:rg
        anchors.bottom:parent.bottom;width:parent.width;height:64
        Island {id:left;x:18;anchors.verticalCenter:parent.verticalCenter;height:52;radius:26;width:lr.implicitWidth+12
            Row {id:lr;anchors.centerIn:parent;spacing:6
                Rectangle {width:44;height:44;radius:22;color:Opal.Theme.primaryContainer;G {anchors.centerIn:parent;name:"apps";color:Opal.Theme.onContainer}}
                Rectangle {width:150;height:44;radius:22;color:Opal.Theme.level(1)
                    Row {x:14;anchors.verticalCenter:parent.verticalCenter;spacing:8;G {name:"search";font.pixelSize:19;color:Opal.Theme.subtext}Txt {text:"Search";role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                Repeater {model:["firefox","kitty","code-oss","org.gnome.Nautilus","spotify","discord"]
                    Item {required property string modelData;required property int index;width:44;height:44
                        Rectangle {anchors.fill:parent;radius:14;color:index<2 ? Opal.Theme.alpha(Opal.Theme.text,.08) : "transparent"}
                        AppIco {anchors.centerIn:parent;icon:parent.modelData;width:28;height:28}
                        Rectangle {visible:index<3||index===4;anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:index<2 ? 14 : 6;height:3;radius:2;color:Opal.Theme.primary}}}
            }
        }
        Row {
            id:rg;anchors.right:parent.right;anchors.rightMargin:22;anchors.verticalCenter:parent.verticalCenter;spacing:8
            WsPill {icon:sh.wsIcon;tint:sh.wsTint;open:sh.wsOpen}
            SegPill {visible:sh.acts.length>0;items:sh.acts;selected:sh.actSel;labels:sh.actLabels}
            NotifPill {st:sh.notif}
            StatusPill {color:sh.statusOpen ? Opal.Theme.primaryContainer : Opal.Theme.level(3)}
            ClockPill {st:sh.clock}
        }
    }

    // ---------- Quick Settings tiles ----------

    // Tile grid in units: wide 2x1, round 1x1 and big 2x2 tiles.
    component TileGrid:Item {
        id:tg
        property var tiles:[]
        property real unitW:88
        property real unitH:64
        property real gap:8
        property bool edit:false
        property bool locked:false
        property int dragging:-1
        readonly property int rows:tiles.reduce((m,t)=>Math.max(m,t.r+(t.h||1)),0)
        width:4*unitW+3*gap;height:rows*unitH+(rows-1)*gap
        Repeater {
            model:tg.tiles
            Item {
                id:cell
                required property var modelData
                required property int index
                readonly property var d:modelData
                readonly property int sw:d.s==="big"||d.s==="wide" ? 2 : 1
                readonly property int shh:d.s==="big" ? 2 : 1
                readonly property bool lifted:index===tg.dragging
                x:d.c*(tg.unitW+tg.gap)+(lifted ? 26 : 0);y:d.r*(tg.unitH+tg.gap)+(lifted ? -18 : 0)
                width:sw*tg.unitW+(sw-1)*tg.gap;height:shh*tg.unitH+(shh-1)*tg.gap
                z:lifted ? 5 : 0
                scale:lifted ? 1.05 : 1
                // A lifted tile casts a soft shadow.
                Rectangle {visible:cell.lifted;anchors.fill:parent;anchors.margins:-2;anchors.topMargin:8;anchors.bottomMargin:-10;radius:24;color:"#000000";opacity:.35}
                Opal.ShadeTile {visible:cell.d.s==="wide";anchors.fill:parent;dense:true;icon:cell.d.g||"";title:cell.d.t||"";subtitle:cell.d.sub||"";active:!!cell.d.on}
                Opal.ShadeTile {visible:cell.d.s==="round";anchors.fill:parent;dense:true;iconOnly:true;icon:cell.d.g||"";title:cell.d.t||"";active:!!cell.d.on}
                BigTile {visible:cell.d.s==="big";anchors.fill:parent;d:cell.d}
                // Locked: tiles that would show private data ask for an unlock.
                Rectangle {visible:tg.locked&&!!cell.d.priv;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:6;width:22;height:22;radius:11;color:Opal.Theme.level(4)
                    G {anchors.centerIn:parent;name:"lock";font.pixelSize:13;color:Opal.Theme.subtext}}
                // Edit mode: a remove badge, a resize handle and an outline.
                Rectangle {visible:tg.edit;anchors.fill:parent;anchors.margins:-3;radius:cell.d.s==="round" ? height/2+3 : 22;color:"transparent";border.width:2;border.color:Opal.Theme.alpha(Opal.Theme.primary,cell.lifted ? 1 : .45)}
                Rectangle {visible:tg.edit;x:-8;y:-8;width:24;height:24;radius:12;color:Opal.Theme.level(5);border.width:1;border.color:Opal.Theme.outline
                    G {anchors.centerIn:parent;name:"remove";font.pixelSize:16}}
                Rectangle {visible:tg.edit;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:-7;width:26;height:26;radius:13;color:cell.lifted ? Opal.Theme.primary : Opal.Theme.secondaryContainer
                    G {anchors.centerIn:parent;name:"open_in_full";font.pixelSize:14;rotation:90;color:cell.lifted ? Opal.Theme.onPrimary : Opal.Theme.onSecondaryContainer}}
            }
        }
    }
    // Big tiles carry a live control.
    component BigTile:Rectangle {
        id:bt
        property var d:({})
        radius:24;color:Opal.Theme.alpha(Opal.Theme.tile,.82);clip:true
        // Now playing: cover, title and controls.
        Item {visible:bt.d.k==="media";anchors.fill:parent;anchors.margins:12
            Rectangle {width:52;height:52;radius:14
                gradient:Gradient {GradientStop {position:0;color:"#3a2a6a"} GradientStop {position:1;color:"#d14b6b"}}
                G {anchors.centerIn:parent;name:"music_note";font.pixelSize:24;color:"#ffffffcc"}}
            Column {x:62;y:4;width:parent.width-62;spacing:2
                Txt {width:parent.width;text:"ASGORE";role:"titleS";elide:Text.ElideRight}
                Txt {width:parent.width;text:"Toby Fox";role:"labelS";color:Opal.Theme.subtext;elide:Text.ElideRight}}
            Rectangle {y:64;width:parent.width;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.15)
                Rectangle {width:parent.width*.38;height:4;radius:2;color:Opal.Theme.primary}}
            Row {anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;spacing:10
                IconBtn {g:"skip_previous";size:34;color:"transparent"}
                Rectangle {width:52;height:34;radius:12;color:Opal.Theme.primary;G {anchors.centerIn:parent;name:"pause";font.pixelSize:20;color:Opal.Theme.onPrimary}}
                IconBtn {g:"skip_next";size:34;color:"transparent"}}
        }
        // Timer: a ring and quick controls.
        Item {visible:bt.d.k==="timer";anchors.fill:parent;anchors.margins:12
            Canvas {width:64;height:64;anchors.verticalCenter:parent.verticalCenter
                readonly property color track:Opal.Theme.alpha(Opal.Theme.tertiary,.25)
                readonly property color ink:Opal.Theme.tertiary
                onPaint:{const c=getContext("2d");c.reset();c.lineWidth=7;c.lineCap="round";
                    c.strokeStyle=track;c.beginPath();c.arc(32,32,27,0,Math.PI*2);c.stroke();
                    c.strokeStyle=ink;c.beginPath();c.arc(32,32,27,-Math.PI/2,-Math.PI/2+Math.PI*2*.7);c.stroke();}
                Txt {anchors.centerIn:parent;text:"4:12";role:"label";font.weight:Font.Bold}}
            Column {x:76;anchors.verticalCenter:parent.verticalCenter;spacing:8;width:parent.width-76
                Txt {text:"Pasta timer";role:"titleS";width:parent.width;elide:Text.ElideRight}
                Row {spacing:6;PillBtn {t:"+1 min";h:32}IconBtn {g:"pause";size:32;tonal:true}}}
        }
        // Devices: batteries of connected devices.
        Column {visible:bt.d.k==="devices";anchors.fill:parent;anchors.margins:14;spacing:10
            Txt {text:"Devices";role:"titleS"}
            Repeater {model:[["headphones","WH-1000XM5",.8],["sports_esports","DualSense",.45],["smartphone","OnePlus 7",.62]]
                Row {required property var modelData;spacing:8
                    G {name:modelData[0];font.pixelSize:18;anchors.verticalCenter:parent.verticalCenter}
                    Rectangle {width:bt.width-110;height:6;radius:3;color:Opal.Theme.alpha(Opal.Theme.text,.15);anchors.verticalCenter:parent.verticalCenter
                        Rectangle {width:parent.width*modelData[2];height:6;radius:3;color:modelData[2]<.5 ? Opal.Theme.tertiary : Opal.Theme.primary}}
                    Txt {text:Math.round(modelData[2]*100)+"%";role:"labelS";anchors.verticalCenter:parent.verticalCenter}}}
        }
    }
    readonly property var qsTiles:[
        {s:"wide",c:0,r:0,g:"wifi",t:"Wi-Fi",sub:"Hyperoptic 5G",on:true,priv:true},
        {s:"wide",c:2,r:0,g:"bluetooth",t:"Bluetooth",sub:"WH-1000XM5",on:true,priv:true},
        {s:"big",c:0,r:1,k:"media"},
        {s:"round",c:2,r:1,g:"do_not_disturb_on",t:"Do not disturb"},
        {s:"round",c:3,r:1,g:"nightlight",t:"Night light",on:true},
        {s:"round",c:2,r:2,g:"mic",t:"Microphone",on:true},
        {s:"round",c:3,r:2,g:"videocam_off",t:"Camera"},
        {s:"wide",c:0,r:3,g:"bolt",t:"Power mode",sub:"Balanced"},
        {s:"wide",c:2,r:3,g:"dark_mode",t:"Dark theme",on:true},
        {s:"big",c:0,r:4,k:"timer"},
        {s:"wide",c:2,r:4,g:"screen_record",t:"Screen record",sub:"Off"},
        {s:"wide",c:2,r:5,g:"android",t:"Android",sub:"Stopped"}
    ]
    // QS header without the clock: battery, then lock, power and settings.
    component QsHeader:Item {
        width:parent ? parent.width : 0;height:44
        Row {anchors.verticalCenter:parent.verticalCenter;spacing:10
            Rectangle {width:bh.implicitWidth+28;height:40;radius:20;color:Opal.Theme.alpha(Opal.Theme.text,.08)
                Row {id:bh;anchors.centerIn:parent;spacing:6;G {name:"battery_5_bar";font.pixelSize:18}Txt {text:"85% · 3 h 20 min";role:"label";anchors.verticalCenter:parent.verticalCenter}}}
        }
        Row {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:8
            IconBtn {g:"edit"}IconBtn {g:"lock"}IconBtn {g:"power_settings_new"}IconBtn {g:"settings"}}
    }

    // ---------- 01: shelf pill states ----------
    component StateRow:Column {
        property string label:""
        spacing:10
        Txt {text:parent.label;role:"title";color:"#ffffff"}
    }
    component StateCell:Column {
        property string cap:""
        default property alias content:holder.data
        spacing:8
        Item {id:holder;width:childrenRect.width;height:44}
        Caption {text:parent.cap}
    }
    Component {id:shelfStates
        Item {
            Wall {blurred:true}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.72)}
            Column {x:56;y:44;spacing:34
                Txt {text:"Shelf pills · round 1";role:"displayS";color:"#ffffff"}
                StateRow {label:"Notification pill (desktop only)"
                    Row {spacing:28
                        StateCell {cap:"No notifications: hidden";Rectangle {width:120;height:44;radius:22;color:"transparent";border.width:1;border.color:Opal.Theme.alpha("#ffffff",.18);Caption {anchors.centerIn:parent;text:"(nothing)"}}}
                        StateCell {cap:"New: grows to the latest one";NotifPill {st:"new"}}
                        StateCell {cap:"After 4 s: icons + count";NotifPill {st:"rest"}}
                        StateCell {cap:"Open";NotifPill {st:"open"}}
                    }
                }
                StateRow {label:"Clock pill: the next event joins only when it needs attention"
                    Row {spacing:28
                        StateCell {cap:"Normal";ClockPill {st:"normal"}}
                        StateCell {cap:"10 min before";ClockPill {st:"soon"}}
                        StateCell {cap:"Starting: Join";ClockPill {st:"now"}}
                        StateCell {cap:"Open: clock + calendar card";ClockPill {st:"open"}}
                    }
                }
                StateRow {label:"Workspace pill with named spaces"
                    Row {spacing:28
                        StateCell {cap:"Unnamed space: number";WsPill {}}
                        StateCell {cap:"Named space: its icon and colour";WsPill {icon:"terminal";tint:"#8bd5a0"}}
                        StateCell {cap:"On switch: name + apps for a moment";WsPill {icon:"terminal";tint:"#8bd5a0";name:"Opal";flash:true}}
                    }
                }
                StateRow {label:"Together, right side of the Shelf"
                    Row {spacing:8
                        WsPill {icon:"terminal";tint:"#8bd5a0"}
                        SegPill {}
                        NotifPill {st:"rest"}
                        StatusPill {}
                        ClockPill {st:"soon"}
                    }
                }
            }
        }
    }

    // ---------- 02: notification card ----------
    component NoteGroup:Rectangle {
        id:ng
        property var n:({})
        property bool expanded:false
        property bool reply:false
        width:parent ? parent.width : 0;radius:22;color:Opal.Theme.level(3)
        height:ngc.implicitHeight+24
        Column {id:ngc;x:14;y:12;width:parent.width-28;spacing:10
            Row {spacing:10;width:parent.width
                AppIco {icon:ng.n.icon;width:32;height:32}
                Column {width:parent.width-90
                    Row {spacing:6;Txt {text:ng.n.app;role:"labelS";color:Opal.Theme.subtext}Caption {text:"· "+ng.n.time}}
                    Txt {width:parent.width;text:ng.n.title;role:"titleS";elide:Text.ElideRight}
                    Txt {width:parent.width;text:ng.n.body;role:"bodyS";color:Opal.Theme.subtext;elide:Text.ElideRight}
                }
                Rectangle {visible:ng.n.count>1;width:34;height:24;radius:12;color:Opal.Theme.alpha(Opal.Theme.text,.1)
                    Row {anchors.centerIn:parent;Txt {text:ng.n.count;role:"labelS"}G {name:"expand_more";font.pixelSize:14}}}
            }
            Column {visible:ng.expanded;x:42;width:parent.width-42;spacing:8
                Txt {text:"Sam · 2 min";role:"labelS";color:Opal.Theme.subtext}
                Txt {text:"we're doing the chapter 5 race at 9";role:"bodyS"}
            }
            Row {visible:ng.reply;x:42;spacing:8
                Rectangle {width:ngc.width-42-56;height:40;radius:20;color:Opal.Theme.level(1)
                    Txt {x:16;anchors.verticalCenter:parent.verticalCenter;text:"Reply to Sam";role:"body";color:Opal.Theme.subtext}}
                IconBtn {g:"send";filled:true}
            }
            Row {visible:ng.reply;x:42;spacing:8;PillBtn {t:"Mark as read";kind:"outline";h:32}PillBtn {t:"Mute 1 h";kind:"outline";h:32}}
        }
    }
    Component {id:notifCard
        Item {
            Desk {}
            Shelf {id:s;notif:"open"}
            Card {
                width:420;height:ncc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:150
                Column {id:ncc;x:16;y:16;width:parent.width-32;spacing:8
                    Item {width:parent.width;height:44
                        Txt {anchors.verticalCenter:parent.verticalCenter;text:"Notifications";role:"title"}
                        Row {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:8
                            Chip {g:"do_not_disturb_on";t:"Do not disturb"}PillBtn {t:"Clear all";kind:"text";h:32}}}
                    NoteGroup {n:root.notes[0];expanded:true;reply:true}
                    NoteGroup {n:root.notes[1]}
                    NoteGroup {n:root.notes[2]}
                    Caption {text:"Silent";topPadding:6}
                    Rectangle {width:parent.width;height:44;radius:22;color:Opal.Theme.level(3)
                        Row {x:14;anchors.verticalCenter:parent.verticalCenter;spacing:10;AppIco {icon:"org.gnome.Nautilus";width:22;height:22}Txt {text:"Files · 3 copies finished";role:"label";anchors.verticalCenter:parent.verticalCenter}}}
                    Item {width:parent.width;height:36;PillBtn {anchors.right:parent.right;t:"Notification settings";kind:"text";h:36}}
                }
            }
        }
    }

    // ---------- 03/04: desktop Quick Settings ----------
    component QsCardA:Card {
        id:qa
        property bool edit:false
        property bool locked:false
        width:412;height:qac.implicitHeight+32
        Column {id:qac;x:16;y:16;width:parent.width-32;spacing:14
            QsHeader {visible:!qa.edit&&!qa.locked}
            Item {visible:qa.locked;width:parent.width;height:40
                Txt {anchors.verticalCenter:parent.verticalCenter;text:"Quick Settings";role:"title"}
                IconBtn {anchors.right:parent.right;g:"power_settings_new"}}
            Item {visible:qa.edit;width:parent.width;height:40
                Txt {anchors.verticalCenter:parent.verticalCenter;text:"Edit tiles";role:"title"}
                Row {anchors.right:parent.right;spacing:8;PillBtn {t:"Reset";kind:"text"}PillBtn {t:"Done";kind:"filled"}}}
            Slider {visible:!qa.edit;width:parent.width;v:.72;g:"light_mode"}
            Slider {visible:!qa.edit;width:parent.width;v:.48;g:"volume_up"}
            TileGrid {unitW:(qac.width-24)/4;tiles:root.qsTiles;edit:qa.edit;locked:qa.locked;dragging:qa.edit ? 7 : -1}
        }
    }
    Component {id:qsA
        Item {
            Desk {}
            Shelf {id:s;statusOpen:true}
            QsCardA {anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:22}
            Column {x:40;y:40;spacing:6
                Rectangle {width:420;height:96;radius:24;color:Opal.Theme.alpha(Opal.Theme.base,.86)
                    Column {x:20;y:16;width:380;spacing:6
                        Txt {text:"A · Compact card";role:"title"}
                        Txt {width:parent.width;wrapMode:Text.Wrap;role:"bodyS";color:Opal.Theme.subtext;text:"No notifications or clock any more: sliders, then the tile grid with wide, round and big 2×2 tiles. Opens from the status pill."}}}
            }
        }
    }
    Component {id:qsB
        Item {
            Desk {}
            Shelf {id:s;statusOpen:true}
            Card {
                width:780;height:qbc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:22
                Column {id:qbc;x:16;y:16;width:parent.width-32;spacing:14
                    QsHeader {}
                    Row {spacing:16
                        TileGrid {id:bgrid;unitW:100;tiles:root.qsTiles}
                        Column {width:qbc.width-bgrid.width-16;spacing:12
                            Rectangle {width:parent.width;height:dc.implicitHeight+28;radius:24;color:Opal.Theme.alpha(Opal.Theme.tile,.82)
                                Column {id:dc;x:14;y:14;width:parent.width-28;spacing:10
                                    Row {spacing:8;G {name:"desktop_windows";font.pixelSize:18}Txt {text:"Displays";role:"titleS";anchors.verticalCenter:parent.verticalCenter}}
                                    Caption {text:"DELL U2723QE"}
                                    Slider {width:parent.width;v:.72;g:"light_mode";h:36}
                                    Caption {text:"LG TV · HDMI-A-1"}
                                    Slider {width:parent.width;v:.4;g:"light_mode";h:36}}}
                            Rectangle {width:parent.width;height:vc.implicitHeight+28;radius:24;color:Opal.Theme.alpha(Opal.Theme.tile,.82)
                                Column {id:vc;x:14;y:14;width:parent.width-28;spacing:10
                                    Row {spacing:8;G {name:"volume_up";font.pixelSize:18}Txt {text:"Sound";role:"titleS";anchors.verticalCenter:parent.verticalCenter}}
                                    Slider {width:parent.width;v:.48;g:"volume_up";h:36}
                                    Slider {width:parent.width;v:.8;g:"mic";h:36}}}
                            BigTile {width:parent.width;height:136;d:({k:"devices"})}
                        }
                    }
                }
            }
            Rectangle {x:40;y:40;width:420;height:96;radius:24;color:Opal.Theme.alpha(Opal.Theme.base,.86)
                Column {x:20;y:16;width:380;spacing:6
                    Txt {text:"B · Wide desktop card";role:"title"}
                    Txt {width:parent.width;wrapMode:Text.Wrap;role:"bodyS";color:Opal.Theme.subtext;text:"Laid out for a wide screen: tiles on the left, per-monitor brightness, sound and device batteries on the right."}}}
        }
    }

    // ---------- 05: edit mode ----------
    Component {id:qsEdit
        Item {
            Desk {}
            Shelf {id:s;statusOpen:true}
            QsCardA {id:qe;edit:true;anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:22}
            // Size chooser for the tile being resized.
            Rectangle {x:qe.x-232;y:qe.y+330;width:220;height:sc.implicitHeight+24;radius:22;color:Opal.Theme.level(4);border.width:1;border.color:Opal.Theme.outline
                Column {id:sc;x:12;y:12;width:parent.width-24;spacing:10
                    Txt {text:"Power mode · size";role:"label"}
                    Row {spacing:3
                        Repeater {model:[["1×1",false],["2×1",true],["2×2",false]]
                            Rectangle {required property var modelData;required property int index;width:62;height:36
                                topLeftRadius:index===0 ? 18 : 6;bottomLeftRadius:topLeftRadius;topRightRadius:index===2 ? 18 : 6;bottomRightRadius:topRightRadius
                                color:modelData[1] ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.text,.08)
                                Txt {anchors.centerIn:parent;text:parent.modelData[0];role:"label";color:parent.modelData[1] ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}}}}
                    Caption {width:parent.width;wrapMode:Text.Wrap;text:"2×2 adds the profile switcher right in the tile."}
                }
            }
            // Spare tiles tray.
            Card {x:qe.x-470;y:40;width:450;height:tc.implicitHeight+32
                Column {id:tc;x:16;y:16;width:parent.width-32;spacing:12
                    Txt {text:"Spare tiles";role:"title"}
                    Caption {text:"Drag one into the grid. Any tile can be 1×1, 2×1 or 2×2."}
                    Grid {columns:2;spacing:8
                        Repeater {model:[["wifi_tethering","Hotspot"],["screen_rotation","Rotation"],["colorize","Colour picker"],["screenshot_region","Screenshot"],["coffee","Keep awake"],["vpn_key","VPN"],["keyboard","Keyboard layout"],["sports_esports","Game mode"],["qr_code_scanner","Scan QR"],["devices","Link phone"]]
                            Opal.ShadeTile {required property var modelData;width:(tc.width-8)/2;height:56;dense:true;icon:modelData[0];title:modelData[1]}}
                    }
                }
            }
        }
    }

    // ---------- 06/07: detail sheets ----------
    component SheetHead:Item {
        property string t:""
        property bool sw:true
        width:parent ? parent.width : 0;height:48
        Row {anchors.verticalCenter:parent.verticalCenter;spacing:8;IconBtn {g:"arrow_back"}Txt {text:parent.parent.t;role:"title";anchors.verticalCenter:parent.verticalCenter}}
        Switch {visible:parent.sw;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter}
    }
    component ListRow:Rectangle {
        property string g:""
        property string t:""
        property string sub:""
        property string trail:""
        property bool first:false
        property bool last:false
        width:parent ? parent.width : 0;height:56
        topLeftRadius:first ? 20 : 6;topRightRadius:topLeftRadius;bottomLeftRadius:last ? 20 : 6;bottomRightRadius:bottomLeftRadius
        color:Opal.Theme.level(3)
        G {x:16;anchors.verticalCenter:parent.verticalCenter;name:parent.g;font.pixelSize:20}
        Column {x:50;anchors.verticalCenter:parent.verticalCenter;width:parent.width-110
            Txt {text:parent.parent.t;role:"body"}
            Caption {visible:text!=="";text:parent.parent.sub}}
        G {visible:parent.trail!=="";anchors.right:parent.right;anchors.rightMargin:16;anchors.verticalCenter:parent.verticalCenter;name:parent.trail;font.pixelSize:18;color:Opal.Theme.subtext}
    }
    Component {id:qsWifi
        Item {
            Desk {}
            Shelf {id:s;statusOpen:true}
            Card {
                width:412;height:wc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:22
                Column {id:wc;x:16;y:16;width:parent.width-32;spacing:12
                    SheetHead {t:"Wi-Fi"}
                    Rectangle {width:parent.width;height:76;radius:24;color:Opal.Theme.primaryContainer
                        Rectangle {x:12;anchors.verticalCenter:parent.verticalCenter;width:48;height:48;radius:16;color:Opal.Theme.primary;G {anchors.centerIn:parent;name:"wifi";color:Opal.Theme.onPrimary}}
                        Column {x:72;anchors.verticalCenter:parent.verticalCenter
                            Txt {text:"Hyperoptic 5G";role:"titleS";color:Opal.Theme.onContainer}
                            Txt {text:"Connected · 5 GHz · Excellent";role:"labelS";color:Opal.Theme.alpha(Opal.Theme.onContainer,.8)}}
                        IconBtn {anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;g:"settings";color:Opal.Theme.alpha(Opal.Theme.onContainer,.12)}
                    }
                    Caption {text:"Available"}
                    Column {width:parent.width;spacing:2
                        ListRow {first:true;g:"network_wifi_3_bar";t:"Hyperoptic 2.4G";sub:"Saved";trail:"lock"}
                        ListRow {g:"network_wifi_3_bar";t:"BT-HUB7-K2";trail:"lock"}
                        ListRow {g:"network_wifi_2_bar";t:"Opal-phone";sub:"Hotspot · OnePlus 7";trail:"lock"}
                        ListRow {last:true;g:"network_wifi_1_bar";t:"Cafe Nero Free";sub:"Open · sign-in page"}
                    }
                    Row {spacing:8;Chip {g:"add";t:"Add network"}Chip {g:"visibility_off";t:"Hidden network"}Chip {g:"badge";t:"Enterprise"}}
                    Item {width:parent.width;height:36;PillBtn {anchors.right:parent.right;t:"Wi-Fi settings";kind:"text";h:36}}
                }
            }
            Rectangle {x:40;y:40;width:440;height:96;radius:24;color:Opal.Theme.alpha(Opal.Theme.base,.86)
                Column {x:20;y:16;width:400;spacing:6
                    Txt {text:"Long-press a tile: it grows into its sheet";role:"title"}
                    Txt {width:parent.width;wrapMode:Text.Wrap;role:"bodyS";color:Opal.Theme.subtext;text:"Wi-Fi gets hidden and enterprise networks in the shell. Back shrinks the sheet into the tile again."}}}
        }
    }
    Component {id:qsDisplays
        Item {
            Desk {}
            Shelf {id:s;statusOpen:true}
            Card {
                width:412;height:dsc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:22
                Column {id:dsc;x:16;y:16;width:parent.width-32;spacing:12
                    SheetHead {t:"Displays";sw:false}
                    Repeater {model:[["DELL U2723QE","DP-1 · 3840×2160 · 1.5×",.72,true],["LG TV","HDMI-A-1 · 1920×1080 · 1×",.4,false]]
                        Rectangle {required property var modelData;width:dsc.width;height:mc.implicitHeight+28;radius:24;color:Opal.Theme.level(3)
                            Column {id:mc;x:14;y:14;width:parent.width-28;spacing:10
                                Item {width:parent.width;height:36
                                    Column {Txt {text:modelData[0];role:"titleS"}Caption {text:modelData[1]}}
                                    Row {anchors.right:parent.right;spacing:6;Chip {t:"HDR";on:modelData[3]}Chip {t:"VRR";on:modelData[3]}}}
                                Slider {width:parent.width;v:modelData[2];g:"light_mode";h:36}
                            }}}
                    Column {width:parent.width;spacing:2
                        ListRow {first:true;g:"nightlight";t:"Night light";sub:"Sunset to sunrise";trail:"chevron_right"}
                        ListRow {g:"contrast";t:"Dark theme";sub:"On";trail:"chevron_right"}
                        ListRow {last:true;g:"screen_share";t:"Arrange displays";trail:"chevron_right"}}
                    Caption {width:parent.width;wrapMode:Text.Wrap;text:"External monitors use DDC/CI, so their brightness changes here too."}
                }
            }
        }
    }

    // ---------- 08: phone shade ----------
    Component {id:qsPhone
        Item {
            Wall {blurred:true}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.78)}
            Column {x:14;y:14;width:parent.width-28;spacing:12
                Item {width:parent.width;height:64
                    Column {Txt {text:"14:52";role:"displayM";color:"#ffffff"}Caption {text:"Wednesday 28 October"}}
                    Row {anchors.right:parent.right;anchors.top:parent.top;anchors.topMargin:14;spacing:6;IconBtn {g:"edit";size:36}IconBtn {g:"power_settings_new";size:36}IconBtn {g:"settings";size:36}}}
                Slider {width:parent.width;v:.72;g:"light_mode"}
                TileGrid {unitW:(parent.width-24)/4;unitH:60;tiles:root.qsTiles.filter(t=>t.r<4)}
                SegPill {items:root.acts.slice(0,2);labels:true;h:40}
                Caption {text:"Notifications";topPadding:4}
                Repeater {model:root.notes.slice(0,2);NoteGroup {required property var modelData;n:modelData}}
            }
        }
    }

    // ---------- 09: segmented pill ----------
    Component {id:segStates
        Item {
            Wall {blurred:true}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.74)}
            Column {x:56;y:44;spacing:30
                Txt {text:"Segmented activity pill";role:"displayS";color:"#ffffff"}
                StateRow {label:"Stacking: one pill, one segment per activity; the most urgent leads and shows its label"
                    Column {spacing:16
                        StateCell {cap:"One activity";SegPill {items:root.acts.slice(0,1)}}
                        StateCell {cap:"Two";SegPill {items:root.acts.slice(0,2)}}
                        StateCell {cap:"Three: timer ends soonest, so it leads; the download shows progress inside its segment";SegPill {}}
                        StateCell {cap:"Five: the last segment folds the rest into a count";SegPill {items:root.acts.concat([{k:"more",t:"+2"}])}}
                        StateCell {cap:"Hover: every segment shows its label";SegPill {labels:true}}
                    }
                }
                StateRow {label:"New sources"
                    Grid {columns:4;spacing:10
                        Repeater {model:[
                            [{g:"download",t:"",long:"Firefox · 3 downloads · 41%",prog:.41}],
                            [{app:"org.gnome.Nautilus",t:"",long:"Copying 12 files · 1 min",prog:.3}],
                            [{g:"construction",t:"",long:"cargo build · 214/380",prog:.56}],
                            [{g:"radio_button_checked",t:"",long:"Recording · 00:42",tint:"tertiary"}],
                            [{app:"steam",t:"",long:"DELTARUNE · 1 h 12 min"}],
                            [{g:"android",t:"",long:"Android · 2 apps open"}],
                            [{g:"screen_share",t:"",long:"Sharing screen · Discord",tint:"tertiary"}],
                            [{g:"system_update",t:"",long:"Updating 34 packages",prog:.7}]]
                            SegPill {required property var modelData;items:modelData}}
                    }
                }
            }
        }
    }
    // ---------- 10: expanded activity ----------
    Component {id:segCard
        Item {
            Desk {}
            Shelf {id:s;actSel:1;notif:"rest"}
            Card {
                width:430;height:acc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;x:s.rightGroup.x+70
                Column {id:acc;x:16;y:16;width:parent.width-32;spacing:14
                    // The other activities wait as segments on top.
                    Row {spacing:3
                        Repeater {model:[["timer","Pasta 4:12",false],["download","Download",true],["music_note","ASGORE",false]]
                            Rectangle {required property var modelData;required property int index;width:sr2.implicitWidth+26;height:36
                                topLeftRadius:index===0 ? 18 : 6;bottomLeftRadius:topLeftRadius;topRightRadius:index===2 ? 18 : 6;bottomRightRadius:topRightRadius
                                color:modelData[2] ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.text,.08)
                                Row {id:sr2;anchors.centerIn:parent;spacing:6;G {name:parent.parent.modelData[0];font.pixelSize:16;color:parent.parent.modelData[2] ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
                                    Txt {text:parent.parent.modelData[1];role:"label";color:parent.parent.modelData[2] ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}}}}
                    }
                    Row {spacing:14
                        Rectangle {width:56;height:56;radius:18;color:Opal.Theme.level(3);AppIco {anchors.centerIn:parent;icon:"firefox";width:34;height:34}}
                        Column {anchors.verticalCenter:parent.verticalCenter
                            Txt {text:"DELTARUNE_OST.zip";role:"title"}
                            Caption {text:"Firefox · from tobyfox.bandcamp.com"}}
                    }
                    // Wavy progress, as in the M3E spec.
                    Item {width:parent.width;height:14
                        Row {spacing:0;anchors.verticalCenter:parent.verticalCenter
                            Repeater {model:30;Rectangle {required property int index;width:(acc.width*.62)/30;height:4;radius:2;y:Math.sin(index*.9)*3;color:Opal.Theme.primary}}}
                        Rectangle {x:acc.width*.62+6;width:acc.width*.38-6;height:4;radius:2;anchors.verticalCenter:parent.verticalCenter;color:Opal.Theme.alpha(Opal.Theme.primary,.25)}
                    }
                    Item {width:parent.width;height:20
                        Txt {text:"18.4 of 29.6 MB · 2.1 MB/s";role:"label"}
                        Txt {anchors.right:parent.right;text:"6 s left";role:"label";color:Opal.Theme.subtext}}
                    Row {spacing:8;PillBtn {g:"pause";t:"Pause";kind:"filled"}PillBtn {g:"close";t:"Cancel"}PillBtn {g:"folder_open";t:"Show in folder";kind:"text"}}
                }
            }
            Rectangle {x:40;y:40;width:440;height:96;radius:24;color:Opal.Theme.alpha(Opal.Theme.base,.86)
                Column {x:20;y:16;width:400;spacing:6
                    Txt {text:"Click a segment: it grows into its card";role:"title"}
                    Txt {width:parent.width;wrapMode:Text.Wrap;role:"bodyS";color:Opal.Theme.subtext;text:"Each kind has its own controls. The other activities stay as segments on top, so switching is one click."}}}
        }
    }
    // ---------- 11: same pill everywhere ----------
    component Frame:Rectangle {
        property string label:""
        default property alias content:inner.data
        radius:24;color:Opal.Theme.level(1);clip:true;border.width:1;border.color:Opal.Theme.outline
        Item {id:inner;anchors.fill:parent}
        Rectangle {x:14;y:14;width:fl.implicitWidth+20;height:28;radius:14;color:Opal.Theme.alpha(Opal.Theme.base,.85);Txt {id:fl;anchors.centerIn:parent;text:parent.parent.label;role:"label"}}
    }
    Component {id:segEverywhere
        Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Grid {x:24;y:24;columns:2;spacing:20
                Frame {label:"Phone status bar";width:606;height:366
                    Wall {blurred:true}
                    Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:60;width:300;height:560;radius:36;color:Opal.Theme.alpha(Opal.Theme.base,.9)
                        Item {width:parent.width;height:40;y:6
                            Txt {x:22;anchors.verticalCenter:parent.verticalCenter;text:"14:52";role:"label";font.weight:Font.Bold}
                            SegPill {x:72;anchors.verticalCenter:parent.verticalCenter;compact:true;h:28;items:root.acts.slice(0,2).map(a=>Object.assign({},a,{long:""}))}
                            Row {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;spacing:4;G {name:"wifi";font.pixelSize:15}G {name:"battery_5_bar";font.pixelSize:15}}}
                        Caption {anchors.horizontalCenter:parent.horizontalCenter;y:60;text:"Tap: opens the shade with that activity on top"}
                    }
                }
                Frame {label:"Tablet bar";width:606;height:366
                    Wall {blurred:true}
                    Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:16;anchors.horizontalCenter:parent.horizontalCenter;width:560;height:52;radius:26;color:Opal.Theme.level(3)
                        Row {x:8;anchors.verticalCenter:parent.verticalCenter;spacing:4;IconBtn {g:"arrow_back";color:"transparent"}IconBtn {g:"circle";color:"transparent"}}
                        SegPill {anchors.centerIn:parent;h:38;items:root.acts.slice(0,2)}
                        Row {anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;spacing:8;G {name:"wifi";font.pixelSize:18}Txt {text:"14:52";role:"label"}}}
                }
                Frame {label:"Lock screen";width:606;height:366
                    Wall {}
                    Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.25)}
                    Txt {anchors.horizontalCenter:parent.horizontalCenter;y:60;text:"14:52";font.pixelSize:96;font.weight:Font.Black;font.variableAxes:{"wdth":125,"ROND":100};color:Opal.Theme.primary}
                    SegPill {anchors.horizontalCenter:parent.horizontalCenter;y:200}
                    Caption {anchors.horizontalCenter:parent.horizontalCenter;y:256;text:"Same pill; lock privacy hides notification-based ones"}
                }
                Frame {label:"Console Quick Access";width:606;height:366
                    Rectangle {anchors.fill:parent;color:"#0d0b12"}
                    Rectangle {anchors.right:parent.right;width:300;height:parent.height;color:Opal.Theme.level(2)
                        Column {x:16;y:58;width:parent.width-32;spacing:12
                            Txt {text:"Quick Access";role:"title"}
                            SegPill {h:40;items:[{app:"steam",t:"",long:"DELTARUNE · 1 h 12"},{g:"download",t:"41%",prog:.41}]}
                            Opal.ShadeTile {width:parent.width;height:56;dense:true;icon:"sports_esports";title:"Performance";subtitle:"60 FPS cap"}
                            Opal.ShadeTile {width:parent.width;height:56;dense:true;icon:"wifi";title:"Wi-Fi";subtitle:"Hyperoptic 5G";active:true}}}
                }
            }
        }
    }

    // ---------- 12: clock + calendar card ----------
    Component {id:clockCard
        Item {
            Desk {}
            Shelf {id:s;clock:"soon"}
            Card {
                width:400;height:ccc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;anchors.right:parent.right;anchors.rightMargin:22
                Column {id:ccc;x:18;y:16;width:parent.width-36;spacing:12
                    Row {spacing:6
                        Txt {text:"14:52";font.pixelSize:64;font.weight:Font.Black;font.variableAxes:{"wdth":125,"ROND":100};color:Opal.Theme.primary}
                        Txt {text:"08";role:"title";color:Opal.Theme.subtext;anchors.bottom:parent.bottom;anchors.bottomMargin:12}}
                    Txt {text:"Wednesday 28 October";role:"titleS";color:Opal.Theme.subtext;topPadding:-10}
                    Row {spacing:8;Chip {g:"public";t:"Tokyo 23:52"}Chip {g:"public";t:"New York 10:52"}Chip {g:"add";t:""}}
                    Row {spacing:8
                        Rectangle {width:(ccc.width-8)/2;height:64;radius:20;color:Opal.Theme.level(3)
                            Column {x:14;anchors.verticalCenter:parent.verticalCenter;Caption {text:"Alarm · Thu"}Txt {text:"07:30";role:"title"}}
                            Switch {anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter}}
                        Rectangle {width:(ccc.width-8)/2;height:64;radius:20;color:Opal.Theme.tertiaryContainer
                            Column {x:14;anchors.verticalCenter:parent.verticalCenter;Txt {text:"Pasta timer";role:"labelS";color:Opal.Theme.onTertiaryContainer}Txt {text:"4:12";role:"title";color:Opal.Theme.onTertiaryContainer}}
                            IconBtn {anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;g:"pause";color:Opal.Theme.alpha(Opal.Theme.onTertiaryContainer,.14)}}
                    }
                    Item {width:parent.width;height:32
                        Txt {anchors.verticalCenter:parent.verticalCenter;text:"October 2026";role:"titleS"}
                        Row {anchors.right:parent.right;IconBtn {g:"chevron_left";size:32;color:"transparent"}IconBtn {g:"chevron_right";size:32;color:"transparent"}}}
                    Grid {columns:7;spacing:0
                        Repeater {model:["M","T","W","T","F","S","S"];Caption {required property string modelData;width:ccc.width/7;horizontalAlignment:Text.AlignHCenter;text:modelData}}
                        Repeater {model:35
                            Item {required property int index;readonly property int day:index-2;width:ccc.width/7;height:34
                                Rectangle {anchors.centerIn:parent;width:32;height:32;radius:16;visible:parent.day===28;color:Opal.Theme.primary}
                                Txt {anchors.centerIn:parent;text:parent.day>0&&parent.day<=31 ? parent.day : "";role:"label";color:parent.day===28 ? Opal.Theme.onPrimary : Opal.Theme.text}
                                Rectangle {visible:[3,9,14,28,30].indexOf(parent.day)>=0;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;width:4;height:4;radius:2;color:parent.day===28 ? Opal.Theme.primary : Opal.Theme.tertiary;anchors.bottomMargin:-1}}}
                    }
                    Caption {text:"Today"}
                    Column {width:parent.width;spacing:2
                        Rectangle {width:parent.width;height:56;topLeftRadius:20;topRightRadius:20;bottomLeftRadius:6;bottomRightRadius:6;color:Opal.Theme.tertiaryContainer
                            Rectangle {x:12;anchors.verticalCenter:parent.verticalCenter;width:4;height:32;radius:2;color:Opal.Theme.tertiary}
                            Column {x:26;anchors.verticalCenter:parent.verticalCenter;Txt {text:"Standup";role:"titleS";color:Opal.Theme.onTertiaryContainer}Txt {text:"15:00 – 15:15 · in 8 min";role:"labelS";color:Opal.Theme.onTertiaryContainer}}
                            PillBtn {anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;g:"videocam";t:"Join";kind:"filled";h:36}}
                        Rectangle {width:parent.width;height:56;topLeftRadius:6;topRightRadius:6;bottomLeftRadius:20;bottomRightRadius:20;color:Opal.Theme.level(3)
                            Rectangle {x:12;anchors.verticalCenter:parent.verticalCenter;width:4;height:32;radius:2;color:Opal.Theme.primary}
                            Column {x:26;anchors.verticalCenter:parent.verticalCenter;Txt {text:"Pick up prints";role:"titleS"}Caption {text:"17:30 · Ender-3 queue"}}}
                    }
                }
            }
        }
    }

    // ---------- 13/14: named spaces ----------
    readonly property var spaces:[
        {n:1,name:"Opal",icon:"palette",tint:"#c7a7ff",apps:["code-oss","kitty"],named:true},
        {n:2,name:"Firefox",icon:"",tint:"",apps:["firefox","kitty"],named:false,cur:true},
        {n:3,name:"Games",icon:"sports_esports",tint:"#8bd5a0",apps:["steam","discord"],named:true},
        {n:4,name:"Music",icon:"",tint:"",apps:["spotify"],named:false}
    ]
    component SpaceTile:Column {
        id:st
        property var d:({})
        spacing:8
        Rectangle {
            width:138;height:88;radius:16;color:Opal.Theme.level(1);clip:true
            border.width:st.d.cur ? 3 : 0;border.color:Opal.Theme.primary
            Image {anchors.fill:parent;source:root.wallpaper;fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(140,90);opacity:.7}
            Row {anchors.fill:parent;anchors.margins:6;spacing:4
                Repeater {model:st.d.apps
                    Rectangle {required property string modelData;width:(126-(st.d.apps.length-1)*4)/st.d.apps.length;height:76;radius:8;color:"#1c1b22"
                        AppIco {anchors.centerIn:parent;icon:parent.modelData;width:24;height:24}}}}
        }
        Row {spacing:8
            Rectangle {width:26;height:26;radius:13;color:st.d.named ? st.d.tint : Opal.Theme.alpha(Opal.Theme.text,.12)
                G {visible:st.d.named;anchors.centerIn:parent;name:st.d.icon;font.pixelSize:16;color:Opal.Theme.base}
                Txt {visible:!st.d.named;anchors.centerIn:parent;text:st.d.n;role:"labelS";font.weight:Font.Bold}}
            Column {anchors.verticalCenter:parent.verticalCenter
                Txt {text:st.d.name;role:"label";font.weight:Font.DemiBold}
                Caption {visible:!st.d.named;text:"auto-named"}}
        }
    }
    Component {id:spacesCard
        Item {
            Desk {}
            Shelf {id:s;wsOpen:true}
            Card {id:wcard
                width:660;height:spc.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;x:s.rightGroup.x-200
                Column {id:spc;x:18;y:16;width:parent.width-36;spacing:14
                    Item {width:parent.width;height:40
                        Txt {anchors.verticalCenter:parent.verticalCenter;text:"Spaces";role:"title"}
                        PillBtn {anchors.right:parent.right;g:"add";t:"New space"}}
                    Row {spacing:16;Repeater {model:root.spaces;SpaceTile {required property var modelData;d:modelData}}}
                    Caption {text:"Saved";topPadding:4}
                    Row {spacing:10
                        Repeater {model:[["science","Quantlab","#ffb38a",["code-oss","kitty","firefox"]],["sports_esports","DELTATALE mod","#8bd5a0",["steam","org.gnome.Nautilus"]],["print","Printing","#9ecbff",["firefox"]]]
                            Rectangle {required property var modelData;width:svr.implicitWidth+20;height:48;radius:24;color:Opal.Theme.level(3)
                                Row {id:svr;anchors.centerIn:parent;spacing:8
                                    Rectangle {width:30;height:30;radius:15;color:modelData[2];G {anchors.centerIn:parent;name:modelData[0];font.pixelSize:17;color:Opal.Theme.base}}
                                    Txt {text:modelData[1];role:"label";font.weight:Font.DemiBold;anchors.verticalCenter:parent.verticalCenter}
                                    Row {spacing:-6;anchors.verticalCenter:parent.verticalCenter;Repeater {model:modelData[3];AppIco {required property string modelData;icon:modelData;width:20;height:20}}}
                                    G {name:"open_in_new";font.pixelSize:16;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}}
                    }
                }
            }
            // Space menu on the current (auto-named) space.
            Rectangle {x:wcard.x+18+154+70;y:wcard.y+40;width:230;height:smc.implicitHeight+16;radius:20;color:Opal.Theme.level(4);border.width:1;border.color:Opal.Theme.outline
                Column {id:smc;x:8;y:8;width:parent.width-16
                    Repeater {model:[["edit","Rename"],["palette","Icon and colour"],["bookmark_add","Save space"],["drive_file_move","Move windows to…"],["close","Close space"]]
                        Rectangle {required property var modelData;required property int index;width:smc.width;height:44;radius:14;color:index===2 ? Opal.Theme.secondaryContainer : "transparent"
                            Row {x:12;anchors.verticalCenter:parent.verticalCenter;spacing:12;G {name:modelData[0];font.pixelSize:19;color:index===4 ? Opal.Theme.error : Opal.Theme.text}
                                Txt {text:modelData[1];role:"body";color:index===4 ? Opal.Theme.error : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}}}}
                }
            }
        }
    }
    Component {id:spacesEdit
        Item {
            Desk {}
            Shelf {id:s;wsOpen:true}
            Card {
                width:420;height:sec.implicitHeight+32;anchors.bottom:s.top;anchors.bottomMargin:6;x:s.rightGroup.x-60
                Column {id:sec;x:18;y:16;width:parent.width-36;spacing:14
                    Row {spacing:8;IconBtn {g:"arrow_back"}Txt {text:"Space 2";role:"title";anchors.verticalCenter:parent.verticalCenter}}
                    Row {spacing:12
                        Rectangle {width:56;height:56;radius:28;color:"#ffb38a";G {anchors.centerIn:parent;name:"science";font.pixelSize:28;color:Opal.Theme.base}}
                        Rectangle {width:sec.width-68;height:56;radius:16;color:"transparent";border.width:2;border.color:Opal.Theme.primary
                            Caption {x:14;y:6;text:"Name";color:Opal.Theme.primary}
                            Txt {x:14;y:24;text:"Quantlab▏";role:"body"}}
                    }
                    Rectangle {width:parent.width;height:44;radius:22;color:Opal.Theme.level(3)
                        Row {x:14;anchors.verticalCenter:parent.verticalCenter;spacing:8;G {name:"search";font.pixelSize:18;color:Opal.Theme.subtext}Txt {text:"Search symbols";role:"body";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                    Grid {columns:8;spacing:6
                        Repeater {model:["science","code","terminal","sports_esports","brush","music_note","movie","school","work","print","rocket_launch","palette","home","travel_explore","bolt","favorite"]
                            Rectangle {required property string modelData;width:(sec.width-42)/8;height:width;radius:index===0 ? 14 : width/2;color:index===0 ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.text,.06)
                                required property int index
                                G {anchors.centerIn:parent;name:parent.modelData;font.pixelSize:20;color:parent.index===0 ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}}}}
                    Caption {text:"Colour"}
                    Row {spacing:10
                        Repeater {model:["#ffb38a","#c7a7ff","#8bd5a0","#9ecbff","#f2b8b5","#e6c87a","#a6e3e9","#d0c4b4"]
                            Rectangle {required property string modelData;required property int index;width:34;height:34;radius:17;color:modelData
                                border.width:index===0 ? 3 : 0;border.color:Opal.Theme.text
                                G {visible:parent.index===0;anchors.centerIn:parent;name:"check";font.pixelSize:18;color:Opal.Theme.base}}}}
                    Rectangle {width:parent.width;height:svc.implicitHeight+24;radius:20;color:Opal.Theme.level(3)
                        Column {id:svc;x:14;y:12;width:parent.width-90;spacing:2
                            Txt {text:"Save space";role:"body"}
                            Caption {width:parent.width;wrapMode:Text.Wrap;text:"Keeps its apps, layout, icon and colour. Reopen it from Spaces or search."}}
                        Switch {anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter}}
                    Item {width:parent.width;height:40;PillBtn {anchors.right:parent.right;t:"Done";kind:"filled"}}
                }
            }
        }
    }

    // ---------- 15–20: lock screen ----------
    // Face A: hours over minutes, huge and rounded.
    component FaceStacked:Column {
        property real size:150
        spacing:-size*.5
        Txt {anchors.horizontalCenter:parent.horizontalCenter;text:"14";font.pixelSize:parent.size;font.weight:Font.Black;font.variableAxes:{"wdth":125,"ROND":100};color:Opal.Theme.primary}
        Txt {anchors.horizontalCenter:parent.horizontalCenter;text:"52";font.pixelSize:parent.size;font.weight:Font.Black;font.variableAxes:{"wdth":125,"ROND":100};color:Opal.Theme.mix(Opal.Theme.primary,"#ffffff",.55)}
    }
    // Face B: each half in an M3 Expressive shape.
    component FaceShapes:Item {
        property real size:170
        width:size*1.75;height:size*1.25
        Opal.Flower {x:0;y:0;width:parent.size;height:parent.size;lobes:9;depth:.16;fill:Opal.Theme.primaryContainer}
        Opal.Flower {x:parent.size*.75;y:parent.size*.25;width:parent.size;height:parent.size;lobes:4;depth:.2;fill:Opal.Theme.tertiaryContainer;phase:45}
        Txt {x:0;y:0;width:parent.size;height:parent.size;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;text:"14";font.pixelSize:parent.size*.5;font.weight:Font.Black;font.variableAxes:{"wdth":110,"ROND":100};color:Opal.Theme.onContainer}
        Txt {x:parent.size*.75;y:parent.size*.25;width:parent.size;height:parent.size;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;text:"52";font.pixelSize:parent.size*.5;font.weight:Font.Black;font.variableAxes:{"wdth":110,"ROND":100};color:Opal.Theme.onTertiaryContainer}
    }
    // At a glance: date, weather, the next event.
    component Glance:Row {
        spacing:14
        Txt {text:"Wednesday 28 October";role:"titleS";color:"#ffffff"}
        Row {spacing:6;G {name:"partly_cloudy_day";font.pixelSize:20;color:"#ffffff"}Txt {text:"12°";role:"titleS";color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}}
        Row {spacing:6;G {name:"event";font.pixelSize:19;color:"#ffffff"}Txt {text:"Standup 15:00";role:"titleS";color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}}
    }
    component NotifChip:GlassBox {
        property bool open:false
        width:ncr.implicitWidth+28;height:48;radius:24
        Row {id:ncr;anchors.centerIn:parent;spacing:10
            Row {spacing:-8;anchors.verticalCenter:parent.verticalCenter
                Repeater {model:["discord","steam","thunderbird"];Rectangle {required property string modelData;width:28;height:28;radius:14;color:Opal.Theme.level(3);AppIco {anchors.centerIn:parent;icon:parent.modelData;width:22;height:22}}}}
            Txt {text:"4 notifications";role:"label";font.weight:Font.DemiBold;color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}
            G {name:parent.parent.open ? "expand_more" : "expand_less";font.pixelSize:18;color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // Swipeable widget stack: the top card, the next one peeking behind, dots for the rest.
    component WidgetStack:Item {
        property real w:440
        width:w;height:140
        GlassBox {x:20;y:0;width:parent.w-40;height:120;radius:28;opacity:.6}
        GlassBox {y:12;width:parent.w;height:128;radius:28
            Rectangle {x:16;anchors.verticalCenter:parent.verticalCenter;width:88;height:88;radius:20
                gradient:Gradient {GradientStop {position:0;color:"#3a2a6a"} GradientStop {position:1;color:"#d14b6b"}}
                G {anchors.centerIn:parent;name:"music_note";font.pixelSize:36;color:"#ffffffcc"}}
            Column {x:120;y:20;width:parent.width-160;spacing:2
                Txt {text:"ASGORE";role:"title";color:"#ffffff"}
                Txt {text:"Toby Fox · DELTARUNE Chapter 3+4";role:"labelS";color:Opal.Theme.subtext}}
            Row {x:120;anchors.bottom:parent.bottom;anchors.bottomMargin:16;spacing:10
                IconBtn {g:"skip_previous";size:36;color:"transparent"}
                Rectangle {width:60;height:36;radius:14;color:Opal.Theme.primary;G {anchors.centerIn:parent;name:"pause";font.pixelSize:20;color:Opal.Theme.onPrimary}}
                IconBtn {g:"skip_next";size:36;color:"transparent"}}
            Column {anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;spacing:5
                Repeater {model:4;Rectangle {required property int index;width:6;height:index===0 ? 16 : 6;radius:3;color:Opal.Theme.alpha("#ffffff",index===0 ? .9 : .35)}}}
        }
    }
    component Corner:Column {
        property string g:""
        property string t:""
        spacing:6
        GlassBox {width:64;height:64;radius:32;anchors.horizontalCenter:parent.horizontalCenter;G {anchors.centerIn:parent;name:parent.parent.g;font.pixelSize:26;color:"#ffffff"}}
        Caption {anchors.horizontalCenter:parent.horizontalCenter;text:parent.t;color:Opal.Theme.alpha("#ffffff",.7)}
    }
    component LockBase:Item {
        property bool dim:false
        anchors.fill:parent
        Wall {blurred:parent.dim}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",parent.dim ? .45 : .22)}
        Row {anchors.right:parent.right;anchors.rightMargin:24;y:18;spacing:12
            G {name:"wifi";font.pixelSize:20;color:"#ffffff"}G {name:"battery_5_bar";font.pixelSize:20;color:"#ffffff"}Txt {text:"85%";role:"label";color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}}
    }
    component DeskLock:Item {
        id:dl
        property bool shapes:false
        anchors.fill:parent
        LockBase {}
        Column {visible:!dl.shapes;anchors.horizontalCenter:parent.horizontalCenter;y:28;spacing:14
            FaceStacked {anchors.horizontalCenter:parent.horizontalCenter;size:150}
            Glance {anchors.horizontalCenter:parent.horizontalCenter}
            SegPill {anchors.horizontalCenter:parent.horizontalCenter;items:root.acts.slice(0,2)}}
        FaceShapes {visible:dl.shapes;x:96;y:70;size:190}
        Glance {visible:dl.shapes;x:110;y:340}
        SegPill {visible:dl.shapes;x:110;y:384;items:root.acts.slice(0,2)}
        NotifChip {anchors.horizontalCenter:parent.horizontalCenter;y:520}
        WidgetStack {anchors.horizontalCenter:parent.horizontalCenter;y:590}
        Corner {x:48;y:676;g:"do_not_disturb_on";t:"Hold"}
        Corner {anchors.right:parent.right;anchors.rightMargin:48;y:676;g:"calculate";t:"Hold"}
        Caption {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:14;text:"Type or touch the sensor to unlock";color:Opal.Theme.alpha("#ffffff",.7)}
    }
    Component {id:lockA
        DeskLock {}
    }
    Component {id:lockB
        DeskLock {shapes:true}
    }
    Component {id:lockNotes
        Item {
            LockBase {dim:true}
            FaceStacked {anchors.horizontalCenter:parent.horizontalCenter;y:24;size:96}
            Glance {anchors.horizontalCenter:parent.horizontalCenter;y:232}
            GlassBox {
                anchors.horizontalCenter:parent.horizontalCenter;y:276;width:460;height:lnc.implicitHeight+28;radius:28
                Column {id:lnc;x:14;y:14;width:parent.width-28;spacing:8
                    Item {width:parent.width;height:36
                        Txt {x:6;anchors.verticalCenter:parent.verticalCenter;text:"4 notifications";role:"titleS";color:"#ffffff"}
                        IconBtn {anchors.right:parent.right;g:"expand_more";size:36}}
                    NoteGroup {n:root.notes[0];reply:true}
                    NoteGroup {n:({icon:"steam",app:"Steam",title:"DELTARUNE update ready",body:"Unlock to see more",count:1,time:"6 min"})}
                    NoteGroup {n:({icon:"thunderbird",app:"Thunderbird",title:"Your order has shipped",body:"Unlock to see more",count:2,time:"22 min"})}
                    Caption {x:6;text:"Replies send once you unlock. Message text shows by your lock privacy setting.";color:Opal.Theme.alpha("#ffffff",.7)}
                }
            }
        }
    }
    Component {id:lockQs
        Item {
            DeskLock {}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.35)}
            QsCardA {locked:true;anchors.right:parent.right;anchors.rightMargin:24;y:52}
            Rectangle {x:40;y:40;width:440;height:96;radius:24;color:Opal.Theme.alpha(Opal.Theme.base,.86)
                Column {x:20;y:16;width:400;spacing:6
                    Txt {text:"Quick Settings while locked";role:"title"}
                    Txt {width:parent.width;wrapMode:Text.Wrap;role:"bodyS";color:Opal.Theme.subtext;text:"Click the status corner or pull down. Toggles work; tiles with a lock badge ask you to unlock before their sheet opens."}}}
        }
    }
    Component {id:lockPhone
        Item {
            LockBase {}
            FaceStacked {anchors.horizontalCenter:parent.horizontalCenter;y:56;size:130}
            Column {anchors.horizontalCenter:parent.horizontalCenter;y:336;spacing:6
                Txt {anchors.horizontalCenter:parent.horizontalCenter;text:"Wed 28 Oct  ·  12°  ·  Standup 15:00";role:"titleS";color:"#ffffff"}}
            SegPill {anchors.horizontalCenter:parent.horizontalCenter;y:376;h:40;items:root.acts.slice(0,2)}
            NotifChip {anchors.horizontalCenter:parent.horizontalCenter;y:560}
            WidgetStack {anchors.horizontalCenter:parent.horizontalCenter;y:620;w:380}
            Corner {x:28;y:800;g:"flashlight_on";t:""}
            Corner {anchors.right:parent.right;anchors.rightMargin:28;y:800;g:"photo_camera";t:""}
            G {anchors.horizontalCenter:parent.horizontalCenter;y:814;name:"fingerprint";font.pixelSize:40;color:Opal.Theme.alpha("#ffffff",.8)}
        }
    }
    // Settings → Lock screen with a live preview.
    component FaceThumb:Rectangle {
        property string label:""
        property bool sel:false
        default property alias content:ft.data
        width:118;height:150;radius:20;color:Opal.Theme.level(3);clip:true
        border.width:sel ? 3 : 0;border.color:Opal.Theme.primary
        Item {id:ft;anchors.fill:parent;anchors.bottomMargin:28}
        Txt {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:8;text:parent.label;role:"labelS"}
    }
    component SetRow:Rectangle {
        property string t:""
        property string sub:""
        property bool sw:false
        property bool on:true
        property string trail:""
        property bool first:false
        property bool last:false
        width:parent ? parent.width : 0;height:sub!=="" ? 68 : 56
        topLeftRadius:first ? 20 : 6;topRightRadius:topLeftRadius;bottomLeftRadius:last ? 20 : 6;bottomRightRadius:bottomLeftRadius
        color:Opal.Theme.level(2)
        Column {x:18;anchors.verticalCenter:parent.verticalCenter;Txt {text:parent.parent.t;role:"body"}Caption {visible:text!=="";text:parent.parent.sub}}
        Switch {visible:parent.sw;on:parent.on;anchors.right:parent.right;anchors.rightMargin:16;anchors.verticalCenter:parent.verticalCenter}
        Row {visible:parent.trail!=="";anchors.right:parent.right;anchors.rightMargin:16;anchors.verticalCenter:parent.verticalCenter;spacing:6
            Txt {text:parent.parent.trail;role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}G {name:"chevron_right";font.pixelSize:18;color:Opal.Theme.subtext}}
    }
    Component {id:lockSettings
        Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            // Navigation list.
            Column {x:20;y:24;width:250;spacing:2
                Txt {text:"Settings";role:"headline";bottomPadding:14;leftPadding:12}
                Repeater {model:[["wifi","Network"],["bluetooth","Connected devices"],["palette","Wallpaper & style"],["lock","Lock screen"],["notifications","Notifications"],["volume_up","Sound"],["desktop_windows","Displays"],["battery_5_bar","Battery"]]
                    Rectangle {required property var modelData;required property int index;width:250;height:48;radius:24;color:index===3 ? Opal.Theme.secondaryContainer : "transparent"
                        Row {x:16;anchors.verticalCenter:parent.verticalCenter;spacing:14;G {name:modelData[0];font.pixelSize:20;color:index===3 ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
                            Txt {text:modelData[1];role:"body";color:index===3 ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}}}}
            }
            // Live preview.
            Column {x:300;y:24;spacing:12
                Txt {text:"Lock screen";role:"headline"}
                Rectangle {width:440;height:275;radius:24;clip:true;color:"black"
                    Item {width:1280;height:800;scale:440/1280;transformOrigin:Item.TopLeft;DeskLock {}}}
                Row {spacing:3;anchors.horizontalCenter:parent.horizontalCenter
                    Repeater {model:[["Desktop",true],["Phone",false]]
                        Rectangle {required property var modelData;required property int index;width:100;height:36;topLeftRadius:index===0 ? 18 : 6;bottomLeftRadius:topLeftRadius;topRightRadius:index===1 ? 18 : 6;bottomRightRadius:topRightRadius
                            color:modelData[1] ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.text,.08)
                            Txt {anchors.centerIn:parent;text:parent.modelData[0];role:"label";color:parent.modelData[1] ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}}}}
                Caption {width:440;wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;text:"Click a part of the preview to jump to its setting."}
            }
            // Options.
            Column {x:770;y:70;width:490;spacing:8
                Caption {text:"Clock face"}
                Row {spacing:8
                    FaceThumb {label:"Stacked";sel:true;FaceStacked {anchors.centerIn:parent;size:44}}
                    FaceThumb {label:"Shapes";FaceShapes {anchors.centerIn:parent;size:52}}
                    FaceThumb {label:"Thin";Txt {anchors.centerIn:parent;text:"14:52";font.pixelSize:34;font.weight:Font.Light;color:"#ffffff"}}
                    FaceThumb {label:"Analog";Rectangle {anchors.centerIn:parent;width:80;height:80;radius:40;color:Opal.Theme.primaryContainer
                        Rectangle {x:39;y:14;width:3;height:28;radius:1.5;color:Opal.Theme.onContainer}Rectangle {x:40;y:38;width:26;height:3;radius:1.5;color:Opal.Theme.onContainer;rotation:20;transformOrigin:Item.Left}}}
                }
                Row {spacing:10;topPadding:4
                    Caption {text:"Colour";anchors.verticalCenter:parent.verticalCenter}
                    Repeater {model:[Opal.Theme.primary,Opal.Theme.tertiary,"#ffffff","#f2b8b5","#8bd5a0"];Rectangle {required property var modelData;required property int index;width:28;height:28;radius:14;color:modelData;border.width:index===0 ? 3 : 0;border.color:Opal.Theme.text}}}
                Caption {text:"Under the clock";topPadding:6}
                Column {width:parent.width;spacing:2
                    SetRow {first:true;t:"At a glance";sub:"Date, weather, next event, alarms";sw:true}
                    SetRow {t:"Live activities";sw:true}
                    SetRow {last:true;t:"Widget stack";sub:"Now playing, Timers, Calendar, Devices";trail:"4 widgets"}}
                Caption {text:"Shortcuts";topPadding:6}
                Column {width:parent.width;spacing:2
                    SetRow {first:true;t:"Left corner";trail:"Do not disturb"}
                    SetRow {last:true;t:"Right corner";trail:"Calculator"}}
            }
            Column {x:300;y:470;width:440;spacing:8
                Caption {text:"While locked"}
                Column {width:parent.width;spacing:2
                    SetRow {first:true;t:"Notifications";trail:"Titles only"}
                    SetRow {t:"Quick Settings";sub:"Private tiles still ask you to unlock";sw:true}
                    SetRow {last:true;t:"Reply from the lock screen";sw:true}}
            }
        }
    }
}
