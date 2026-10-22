import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// App switcher render round 1 (2026-10-23): two options per mode for desktop tiling, desktop floating, tablet, phone and console. Static data; windows are drawn mock apps.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    // Icon files for the offscreen render, which has no icon theme.
    readonly property var icons:({"firefox":"/usr/share/icons/Papirus/64x64/apps/firefox.svg","code-oss":"/usr/share/icons/Papirus/64x64/apps/code-oss.svg","org.gnome.Nautilus":"/usr/share/icons/Papirus/64x64/apps/org.gnome.Nautilus.svg","spotify":"/usr/share/icons/Papirus/64x64/apps/spotify.svg","steam":"/usr/share/icons/Papirus/64x64/apps/steam.svg","kitty":"/usr/share/icons/Papirus/64x64/apps/kitty.svg"})
    readonly property string wallpaper:"file:///home/melissa/Pictures/Wallpapers/dr5-keyart-YzI66DkClTeJ5jBQ.png"
    readonly property string shotDr:"file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260820011409_1.jpg"
    readonly property string shotStel:"file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260825231150_1.jpg"
    readonly property string heroDr:"file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_hero.jpg"
    readonly property string logoDr:"file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/logo.png"
    // Most recent first. Geometry is the tiled position on a 1280x800 desktop.
    readonly property var wins:[
        {k:"firefox",app:"Firefox",icon:"firefox",t:"Material 3 Expressive — m3.material.io",ws:1,x:8,y:8,w:628,h:740},
        {k:"kitty",app:"kitty",icon:"kitty",t:"~/.local/state/opal/staging — fish",ws:1,x:644,y:8,w:628,h:740},
        {k:"code",app:"Code - OSS",icon:"code-oss",t:"WindowSwitcher.qml — staging",ws:2,x:8,y:8,w:836,h:740},
        {k:"game",app:"DELTARUNE",icon:"steam",t:"DELTARUNE",ws:4,x:0,y:0,w:1280,h:800,img:shotDr},
        {k:"files",app:"Files",icon:"org.gnome.Nautilus",t:"Downloads",ws:2,x:852,y:8,w:420,h:740},
        {k:"spotify",app:"Spotify",icon:"spotify",t:"Toby Fox — ASGORE",ws:3,x:8,y:8,w:628,h:740},
        {k:"btop",app:"kitty",icon:"kitty",t:"btop",ws:3,x:644,y:8,w:628,h:740}
    ]
    // Floating mode: free positions on workspace 1; the last two are minimized.
    readonly property var floats:[
        {k:"firefox",app:"Firefox",icon:"firefox",t:"Material 3 Expressive — m3.material.io",x:110,y:52,w:780,h:520},
        {k:"kitty",app:"kitty",icon:"kitty",t:"~/.local/state/opal/staging — fish",x:600,y:290,w:600,h:380},
        {k:"code",app:"Code - OSS",icon:"code-oss",t:"WindowSwitcher.qml — staging",x:40,y:330,w:560,h:360},
        {k:"spotify",app:"Spotify",icon:"spotify",t:"Toby Fox — ASGORE",min:true,w:780,h:520},
        {k:"files",app:"Files",icon:"org.gnome.Nautilus",t:"Downloads",min:true,w:640,h:440}
    ]
    readonly property var phoneWins:[
        {k:"firefox",app:"Firefox",icon:"firefox",t:"m3.material.io"},
        {k:"spotify",app:"Spotify",icon:"spotify",t:"ASGORE"},
        {k:"kitty",app:"kitty",icon:"kitty",t:"fish"},
        {k:"files",app:"Files",icon:"org.gnome.Nautilus",t:"Downloads"},
        {k:"code",app:"Code - OSS",icon:"code-oss",t:"Settings.qml"}
    ]
    readonly property var games:[
        {k:"game",app:"DELTARUNE",icon:"steam",t:"DELTARUNE",img:shotDr,sub:"Playing · 1 h 12 min"},
        {k:"game",app:"Stellaris",icon:"steam",t:"Stellaris",img:shotStel,sub:"Paused · 3 h 40 min"},
        {k:"firefox",app:"Firefox",icon:"firefox",t:"Firefox",sub:"Desktop app"},
        {k:"spotify",app:"Spotify",icon:"spotify",t:"Spotify",sub:"Playing ASGORE"}
    ]

    Window {
        id:fixture
        width:1280;height:800;visible:true;color:"black"
        property int step:0
        property var cases:[
            {name:"sw-d1-strip",view:d1,w:1280,h:800},
            {name:"sw-d2-chip-morph",view:d2,w:1280,h:800},
            {name:"sw-d3-overview-rows",view:d3,w:1280,h:800},
            {name:"sw-d4-overview-maps",view:d4,w:1280,h:800},
            {name:"sw-f1-strip-minimized",view:f1,w:1280,h:800},
            {name:"sw-f2-expose",view:f2,w:1280,h:800},
            {name:"sw-t1-tablet-row",view:t1,w:1280,h:800},
            {name:"sw-t2-tablet-grid",view:t2,w:1280,h:800},
            {name:"sw-p1-phone-carousel",view:p1,w:412,h:915},
            {name:"sw-p2-phone-grid",view:p2,w:412,h:915},
            {name:"sw-c1-console-hero",view:c1,w:1280,h:800},
            {name:"sw-c2-console-sheet",view:c2,w:1280,h:800}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            width=cases[step].w;height=cases[step].h;
            loader.sourceComponent=null;loader.sourceComponent=cases[step].view;
            grab.restart();
        }
        Timer {id:grab;interval:2600;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        // OPAL_CASE=<name part> renders matching cases only.
        Component.onCompleted:{const only=Quickshell.env("OPAL_CASE");if(only)cases=cases.filter(c=>c.name.indexOf(only)>=0);Qt.callLater(run);}
    }

    // ---------- Shared pieces ----------

    // Rounded, cropped art. Canvas clipping works on the software renderer used for offscreen renders.
    component Art:Item {
        id:art
        property url source
        property real radius:0
        Image {id:probe;source:art.source;visible:false;onStatusChanged:cnv.requestPaint()}
        Canvas {
            id:cnv;anchors.fill:parent
            readonly property string src:String(art.source)
            onSrcChanged:if(src!=="")loadImage(src)
            Component.onCompleted:if(src!=="")loadImage(src)
            onImageLoaded:requestPaint()
            property int tries:0
            Timer {interval:400;repeat:true;running:cnv.tries<5;onTriggered:{cnv.tries++;cnv.requestPaint();}}
            onWidthChanged:requestPaint()
            onHeightChanged:requestPaint()
            onPaint:{
                const ctx=getContext("2d");ctx.reset();
                if(src===""||!isImageLoaded(src)||probe.implicitWidth<=0)return;
                const iw=probe.implicitWidth,ih=probe.implicitHeight,w=width,h=height,r=Math.min(art.radius,w/2,h/2);
                ctx.beginPath();ctx.roundedRect(0,0,w,h,r,r);ctx.closePath();ctx.clip();
                const s=Math.max(w/iw,h/ih),sw=w/s,sh=h/s;
                ctx.drawImage(src,(iw-sw)/2,(ih-sh)/2,sw,sh,0,0,w,h);
            }
        }
    }

    // App icon with a glyph fallback.
    component AppIco:Item {
        id:ai
        property string icon:""
        implicitWidth:24;implicitHeight:24
        Image {id:img;anchors.fill:parent;sourceSize:Qt.size(ai.width*2,ai.height*2);source:root.icons[ai.icon] ? "file://"+root.icons[ai.icon] : Quickshell.iconPath(ai.icon,true);smooth:true}
        Opal.Glyph {anchors.centerIn:parent;visible:img.status!==Image.Ready;name:"apps";font.pixelSize:ai.width*.8;color:Opal.Theme.primary}
    }

    // A drawn stand-in for a real app window. Every child that touches an edge uses that corner's radius.
    component Win:Rectangle {
        id:win
        property var d:({k:"kitty"})
        property real r:12
        property bool bar:false
        readonly property real u:Math.max(3,Math.min(width,height*1.2)/60)
        readonly property real barH:bar ? Math.max(14,u*2.6) : 0
        radius:r
        color:d.k==="firefox" ? "#1c1b22" : d.k==="code" ? "#1e1e1e" : d.k==="files" ? "#242424" : d.k==="spotify" ? "#121212" : d.k==="game" ? "#000000" : "#14121b"
        // Floating mode title bar.
        Rectangle {
            visible:win.bar;width:parent.width;height:win.barH;topLeftRadius:win.r;topRightRadius:win.r;color:"#2a2733"
            Opal.MText {anchors.left:parent.left;anchors.leftMargin:win.u*1.5;anchors.verticalCenter:parent.verticalCenter;width:parent.width*.6;text:win.d.t||"";font.pixelSize:Math.max(6,win.barH*.42);color:"#d8d3e4"}
            Row {anchors.right:parent.right;anchors.rightMargin:win.u*1.2;anchors.verticalCenter:parent.verticalCenter;spacing:win.u*.8
                Repeater {model:["#f2b8b5","#e6c87a","#9fd49a"];Rectangle {required property string modelData;width:win.barH*.42;height:width;radius:width/2;color:modelData}}
            }
        }
        Item {
            id:body;anchors.fill:parent;anchors.topMargin:win.barH;clip:true
            // Firefox: tab strip, address bar and a Material page.
            Item {visible:win.d.k==="firefox";anchors.fill:parent
                Rectangle {width:parent.width;height:Math.max(win.u*2.6,win.bar ? 0 : win.r*1.1);topLeftRadius:win.bar ? 0 : win.r;topRightRadius:topLeftRadius;color:"#2b2a33"
                    Rectangle {x:win.u*1.2;y:win.u*.5;width:Math.min(parent.width*.4,win.u*16);height:parent.height-win.u*.5;topLeftRadius:win.u*.6;topRightRadius:win.u*.6;color:"#42414d"}
                }
                Rectangle {x:win.u*1.2;y:win.u*3.1;width:parent.width-win.u*2.4;height:win.u*1.8;radius:height/2;color:"#2b2a33"}
                Rectangle {x:win.u*2;y:win.u*6;width:parent.width-win.u*4;height:parent.height*.32;radius:win.u*1.6;color:Opal.Theme.primaryContainer
                    Opal.MText {x:win.u*1.6;y:win.u*1.4;width:parent.width-win.u*3;text:"Material 3 Expressive";font.pixelSize:Math.max(5,win.u*2.1);font.weight:Font.Bold;color:Opal.Theme.onContainer;wrapMode:Text.Wrap;maximumLineCount:2}
                    Rectangle {x:win.u*1.6;anchors.bottom:parent.bottom;anchors.bottomMargin:win.u*1.4;width:win.u*9;height:win.u*2.2;radius:height/2;color:Opal.Theme.primary}
                }
                Grid {x:win.u*2;y:win.u*7+parent.height*.32;columns:parent.width>parent.height ? 3 : 2;spacing:win.u
                    Repeater {model:6;Rectangle {width:(win.width-win.u*4-win.u*((win.width>win.height ? 3 : 2)-1))/(win.width>win.height ? 3 : 2);height:win.u*7;radius:win.u;color:"#2b2a33"
                        Rectangle {x:win.u;y:win.u;width:parent.width*.5;height:win.u*.8;radius:height/2;color:"#5b5a66"}
                        Rectangle {x:win.u;y:win.u*2.4;width:parent.width*.75;height:win.u*.6;radius:height/2;color:"#3f3e49"}
                    }}
                }
            }
            // Terminal: fish prompt with git output, or btop graphs.
            Column {visible:win.d.k==="kitty";x:win.u*1.4;y:win.u*1.4;width:parent.width-win.u*2.8;spacing:win.u*.35;clip:true;height:parent.height-win.u*2.8
                Repeater {model:[["#a6e3a1","melissa@opal ~/.l/s/o/staging (overhaul-2026-10)> git status"],["#cdd6f4","On branch overhaul-2026-10"],["#cdd6f4","Changes not staged for commit:"],["#f38ba8","        modified:   src/WindowSwitcher.qml"],["#f38ba8","        modified:   src/Settings.qml"],["#f38ba8","        modified:   src/Theme.qml"],["#cdd6f4",""],["#89b4fa","Untracked files:"],["#f38ba8","        tests/switcher-proto.qml"],["#cdd6f4",""],["#a6e3a1","melissa@opal ~/.l/s/o/staging> bash tests/render-offscreen.sh"],["#cdd6f4","Isolated render directory: /tmp/opal-render.Xb21"],["#cdd6f4","OFFSCREEN_TESTS_COMPLETE"],["#a6e3a1","melissa@opal ~/.l/s/o/staging> ▋"]]
                    Text {required property var modelData;width:parent.width;text:modelData[1];color:modelData[0];font.family:"monospace";font.pixelSize:Math.max(4,win.u*1.05);elide:Text.ElideRight}
                }
            }
            Item {visible:win.d.k==="btop";anchors.fill:parent;anchors.margins:win.u
                Repeater {model:3
                    Rectangle {required property int index;x:0;y:index*(parent.height/3);width:parent.width;height:parent.height/3-win.u*.6;radius:win.u*.8;color:"transparent";border.width:1;border.color:["#89b4fa","#a6e3a1","#f9e2af"][index]
                        Row {anchors.bottom:parent.bottom;anchors.bottomMargin:win.u*.6;x:win.u*.6;spacing:Math.max(1,win.u*.25)
                            Repeater {model:28;Rectangle {required property int index;width:Math.max(1,(win.width-win.u*4)/28-win.u*.25);height:(win.height/3-win.u*3)*(.2+.7*Math.abs(Math.sin(index*.7+parent.parent.index)));color:["#89b4fa","#a6e3a1","#f9e2af"][parent.parent.index];anchors.bottom:parent.bottom;opacity:.8}}
                        }
                    }
                }
            }
            // Code editor: activity bar, file tree, tokens.
            Item {visible:win.d.k==="code";anchors.fill:parent
                Rectangle {width:win.u*2.4;height:parent.height;topLeftRadius:win.bar ? 0 : win.r;bottomLeftRadius:win.r;color:"#2c2c2c"}
                Rectangle {x:win.u*2.4;width:parent.width*.22;height:parent.height;color:"#252526"
                    Column {x:win.u;y:win.u;spacing:win.u*.7
                        Repeater {model:[.7,.5,.6,.8,.4,.55,.65,.5];Rectangle {required property real modelData;width:(win.width*.22-win.u*2)*modelData;height:win.u*.6;radius:height/2;color:"#5a5a5a"}}
                    }
                }
                Column {x:win.u*3.4+parent.width*.22;y:win.u*1.2;spacing:win.u*.7
                    Repeater {model:[[.1,"#c586c0",.3,"#9cdcfe"],[.05,"#569cd6",.4,"#ce9178"],[.15,"#9cdcfe",.2,"#dcdcaa"],[.15,"#4ec9b0",.35,"#d4d4d4"],[.1,"#6a9955",.5,"#6a9955"],[.15,"#9cdcfe",.25,"#b5cea8"],[.05,"#c586c0",.15,"#d4d4d4"],[.2,"#dcdcaa",.3,"#ce9178"],[.1,"#9cdcfe",.45,"#d4d4d4"],[.15,"#569cd6",.2,"#4ec9b0"],[.05,"#d4d4d4",.1,"#d4d4d4"]]
                        Row {required property var modelData;spacing:win.u*.6
                            Rectangle {width:win.width*.6*modelData[0];height:win.u*.65;radius:height/2;color:modelData[1]}
                            Rectangle {width:win.width*.6*modelData[2];height:win.u*.65;radius:height/2;color:modelData[3]}
                        }
                    }
                }
            }
            // Files: sidebar and a folder grid.
            Item {visible:win.d.k==="files";anchors.fill:parent
                Rectangle {width:Math.min(parent.width*.3,win.u*12);height:parent.height;topLeftRadius:win.bar ? 0 : win.r;bottomLeftRadius:win.r;color:"#303030"
                    Column {x:win.u;y:win.u*1.4;spacing:win.u*.9
                        Repeater {model:6;Rectangle {width:parent.parent.width-win.u*2;height:win.u*1.6;radius:height/2;color:index===2 ? "#3d4a5c" : "transparent";required property int index
                            Rectangle {x:win.u*.5;anchors.verticalCenter:parent.verticalCenter;width:parent.width*.6;height:win.u*.55;radius:height/2;color:"#8a8a8a"}}}
                    }
                }
                Grid {x:Math.min(win.width*.3,win.u*12)+win.u*1.4;y:win.u*1.6;columns:Math.max(2,Math.floor((win.width-Math.min(win.width*.3,win.u*12)-win.u*2)/(win.u*6.4)));spacing:win.u*1.2
                    Repeater {model:12;Column {spacing:win.u*.3
                        Opal.Glyph {name:"folder";font.pixelSize:win.u*5;color:"#62a0ea";width:win.u*5.2}
                        Rectangle {width:win.u*4;height:win.u*.5;radius:height/2;color:"#8a8a8a";anchors.horizontalCenter:parent.horizontalCenter}
                    }}
                }
            }
            // Spotify: rail, cover and a play button.
            Item {visible:win.d.k==="spotify";anchors.fill:parent
                Rectangle {anchors.centerIn:parent;anchors.verticalCenterOffset:-parent.height*.08;width:Math.min(parent.width,parent.height)*.55;height:width;radius:win.u
                    gradient:Gradient {GradientStop {position:0;color:"#3a2a6a"} GradientStop {position:1;color:"#d14b6b"}}
                    Opal.Glyph {anchors.centerIn:parent;name:"music_note";font.pixelSize:parent.width*.4;color:"#ffffffaa"}
                }
                Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;y:parent.height*.72;text:"ASGORE";font.pixelSize:Math.max(5,win.u*1.8);font.weight:Font.Bold;color:"white"}
                Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:parent.height*.81;width:win.u*4.4;height:width;radius:width/2;color:"#1ed760"
                    Opal.Glyph {anchors.centerIn:parent;name:"play_arrow";font.pixelSize:parent.width*.6;color:"black"}}
            }
            Art {visible:win.d.k==="game";anchors.fill:parent;source:win.d.img||"";radius:win.r}
        }
    }

    // Wallpaper. Blurred is a tiny decode scaled up, which reads as blur on the software renderer.
    component Wall:Image {
        property bool blurred:false
        anchors.fill:parent;source:root.wallpaper;fillMode:Image.PreserveAspectCrop
        sourceSize:blurred ? Qt.size(48,30) : Qt.size(1280,800);smooth:true
    }

    // The live "edge" shelf (the user's bar style), drawn simply.
    component EdgeShelf:Rectangle {
        anchors.bottom:parent.bottom;width:parent.width;height:44;color:Opal.Theme.alpha(Opal.Theme.glassIsland,.82)
        Row {anchors.centerIn:parent;spacing:10
            Repeater {model:["firefox","kitty","code-oss","org.gnome.Nautilus","spotify","steam"];AppIco {required property string modelData;icon:modelData;width:26;height:26}}
        }
        Opal.MText {anchors.right:parent.right;anchors.rightMargin:18;anchors.verticalCenter:parent.verticalCenter;text:"14:32";role:"titleS"}
    }

    // The tiled desktop on workspace 1, behind the switchers.
    component Desk:Item {
        anchors.fill:parent
        Wall {}
        Repeater {model:root.wins.filter(w=>w.ws===1);Win {required property var modelData;d:modelData;x:modelData.x;y:modelData.y;width:modelData.w;height:modelData.h;r:14}}
        EdgeShelf {}
    }

    component FloatDesk:Item {
        anchors.fill:parent
        Wall {}
        Repeater {model:root.floats.filter(w=>!w.min).slice().reverse();Win {required property var modelData;d:modelData;bar:true;x:modelData.x;y:modelData.y;width:modelData.w;height:modelData.h;r:14}}
        EdgeShelf {}
    }

    // Keyboard hint keycap.
    component Key:Rectangle {
        property string t:""
        implicitWidth:Math.max(26,kt.implicitWidth+14);implicitHeight:24;radius:7
        color:Opal.Theme.alpha(Opal.Theme.text,.10);border.width:1;border.color:Opal.Theme.alpha(Opal.Theme.text,.18)
        Opal.MText {id:kt;anchors.centerIn:parent;text:parent.t;role:"labelS";color:Opal.Theme.text}
    }
    component Hint:Row {
        property string k:""
        property string t:""
        spacing:6
        Key {t:parent.k;anchors.verticalCenter:parent.verticalCenter}
        Opal.MText {text:parent.t;role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
    }

    // M3E floating toolbar: a pill of icon and label buttons that floats over content.
    component Toolbar:Rectangle {
        id:tb
        property var items:[]
        property bool vibrant:false
        implicitWidth:tbRow.implicitWidth+16;implicitHeight:64;radius:32
        color:vibrant ? Opal.Theme.primaryContainer : Opal.Theme.alpha(Opal.Theme.level(3),.96)
        Row {id:tbRow;anchors.centerIn:parent;spacing:4
            Repeater {model:tb.items
                Rectangle {
                    required property var modelData
                    readonly property bool hot:!!modelData.hot
                    width:modelData.split ? splitRow.implicitWidth : modelData.t ? lab.implicitWidth+ico.width+36 : 48;height:48;radius:24
                    color:modelData.split ? "transparent" : hot ? Opal.Theme.primary : "transparent"
                    Opal.Glyph {id:ico;visible:!modelData.split;x:modelData.t ? 14 : 13;anchors.verticalCenter:parent.verticalCenter;name:modelData.g||"";font.pixelSize:22;color:parent.hot ? Opal.Theme.onPrimary : tb.vibrant ? Opal.Theme.onContainer : Opal.Theme.text}
                    Opal.MText {id:lab;visible:!modelData.split&&!!modelData.t;x:ico.x+ico.width+8;anchors.verticalCenter:parent.verticalCenter;text:modelData.t||"";role:"label";color:parent.hot ? Opal.Theme.onPrimary : tb.vibrant ? Opal.Theme.onContainer : Opal.Theme.text}
                    // Split button: the main action and a separate menu half.
                    Row {id:splitRow;visible:!!modelData.split;anchors.verticalCenter:parent.verticalCenter;spacing:2
                        Rectangle {width:sl.implicitWidth+sg.width+34;height:48;topLeftRadius:24;bottomLeftRadius:24;topRightRadius:6;bottomRightRadius:6;color:Opal.Theme.secondaryContainer
                            Opal.Glyph {id:sg;x:14;anchors.verticalCenter:parent.verticalCenter;name:modelData.g||"";font.pixelSize:22;color:Opal.Theme.onSecondaryContainer}
                            Opal.MText {id:sl;x:sg.x+sg.width+8;anchors.verticalCenter:parent.verticalCenter;text:modelData.t||"";role:"label";color:Opal.Theme.onSecondaryContainer}
                        }
                        Rectangle {width:40;height:48;topLeftRadius:6;bottomLeftRadius:6;topRightRadius:24;bottomRightRadius:24;color:Opal.Theme.secondaryContainer
                            Opal.Glyph {anchors.centerIn:parent;anchors.horizontalCenterOffset:-2;name:"keyboard_arrow_down";font.pixelSize:22;color:Opal.Theme.onSecondaryContainer}}
                    }
                }
            }
        }
    }

    // Selection ring drawn outside the item, so the item itself never changes shape.
    component Ring:Rectangle {
        property real r:16
        anchors.fill:parent;anchors.margins:-5;radius:r+5;color:"transparent";border.width:3;border.color:Opal.Theme.primary
    }

    // Workspace tag: compact chip with the number.
    component WsChip:Rectangle {
        property int n:1
        property bool current:false
        property string extra:""
        implicitWidth:wsr.implicitWidth+20;implicitHeight:28;radius:14
        color:current ? Opal.Theme.primary : Opal.Theme.alpha(Opal.Theme.level(4),.9)
        Row {id:wsr;anchors.centerIn:parent;spacing:6
            Opal.MText {text:"Workspace "+parent.parent.n;role:"label";color:parent.parent.current ? Opal.Theme.onPrimary : Opal.Theme.text}
            Opal.MText {visible:parent.parent.extra!=="";text:parent.parent.extra;role:"label";color:parent.parent.current ? Opal.Theme.alpha(Opal.Theme.onPrimary,.75) : Opal.Theme.subtext}
        }
    }

    // M3E search bar.
    component SearchBar:Rectangle {
        property string hint:"Search"
        property string trail:""
        implicitHeight:56;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(3),.96)
        Opal.Glyph {x:18;anchors.verticalCenter:parent.verticalCenter;name:"search";font.pixelSize:24;color:Opal.Theme.text}
        Opal.MText {x:54;anchors.verticalCenter:parent.verticalCenter;text:parent.hint;role:"body";color:Opal.Theme.subtext}
        Rectangle {visible:parent.trail!=="";anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;width:trl.implicitWidth+40;height:40;radius:20;color:Opal.Theme.secondaryContainer
            Opal.Glyph {x:12;anchors.verticalCenter:parent.verticalCenter;name:"filter_list";font.pixelSize:18;color:Opal.Theme.onSecondaryContainer}
            Opal.MText {id:trl;x:34;anchors.verticalCenter:parent.verticalCenter;text:parent.parent.trail;role:"label";color:Opal.Theme.onSecondaryContainer}
        }
    }

    // App chip above a touch card: icon, name and a menu chevron.
    component AppChip:Rectangle {
        property var d:({})
        implicitWidth:acr.implicitWidth+24;implicitHeight:36;radius:18;color:Opal.Theme.alpha(Opal.Theme.level(3),.94)
        Row {id:acr;anchors.centerIn:parent;spacing:8
            AppIco {icon:parent.parent.d.icon||"";width:22;height:22;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:parent.parent.d.app||"";role:"label";anchors.verticalCenter:parent.verticalCenter}
            Opal.Glyph {name:"keyboard_arrow_down";font.pixelSize:18;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
        }
    }

    // ---------- Desktop tiling ----------

    // D1: Alt+Tab strip. Live previews at their real proportions, most recent first; the previous window is chosen.
    Component {id:d1;Item {
        Desk {}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.28)}
        Rectangle {
            id:strip1;anchors.centerIn:parent;anchors.verticalCenterOffset:-20
            width:row1.implicitWidth+48;height:row1.implicitHeight+48;radius:36
            color:Opal.Theme.alpha(Opal.Theme.glassIsland,.88);border.width:1;border.color:Opal.Theme.glassEdge
            Row {id:row1;anchors.centerIn:parent;spacing:18
                Repeater {model:root.wins
                    Column {
                        required property var modelData
                        required property int index
                        readonly property bool sel:index===1
                        spacing:10
                        Item {width:Math.max(96,Math.min(250,150*modelData.w/modelData.h));height:150
                            Win {anchors.fill:parent;d:modelData;r:16}
                            Ring {visible:parent.parent.sel;r:16}
                            Rectangle {visible:modelData.ws!==1;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:6;width:22;height:22;radius:11;color:Opal.Theme.alpha(Opal.Theme.level(4),.95)
                                Opal.MText {anchors.centerIn:parent;text:modelData.ws;role:"labelS"}}
                        }
                        AppIco {icon:modelData.icon;width:28;height:28;anchors.horizontalCenter:parent.horizontalCenter;opacity:parent.sel ? 1 : .8}
                    }
                }
            }
        }
        // The chosen window's title sits under the strip, so the tiles stay clean.
        Rectangle {
            anchors.horizontalCenter:parent.horizontalCenter;anchors.top:strip1.bottom;anchors.topMargin:14
            width:tr1.implicitWidth+32;height:44;radius:22;color:Opal.Theme.alpha(Opal.Theme.level(3),.95)
            Row {id:tr1;anchors.centerIn:parent;spacing:10
                Opal.MText {text:"kitty";role:"titleS";anchors.verticalCenter:parent.verticalCenter}
                Opal.MText {text:"~/.local/state/opal/staging — fish";role:"body";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
            }
        }
        Row {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:64;spacing:22
            Hint {k:"Tab";t:"Next"} Hint {k:"⇧ Tab";t:"Back"} Hint {k:"Q";t:"Close window"} Hint {k:"Alt ↑";t:"Release to switch"}
        }
    }}

    // D2: chip morph. A pill of app icons; the chosen one has grown in place into a preview card.
    Component {id:d2;Item {
        Desk {}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.22)}
        Rectangle {
            anchors.centerIn:parent
            width:row2.implicitWidth+28;height:row2.implicitHeight+28;radius:40
            color:Opal.Theme.alpha(Opal.Theme.glassIsland,.9);border.width:1;border.color:Opal.Theme.glassEdge
            Row {id:row2;anchors.centerIn:parent;spacing:10
                Repeater {model:root.wins
                    Item {
                        required property var modelData
                        required property int index
                        readonly property bool sel:index===1
                        width:sel ? 360 : 64;height:sel ? 292 : 64;anchors.verticalCenter:parent.verticalCenter
                        // Chip state.
                        Rectangle {visible:!parent.sel;anchors.fill:parent;radius:32;color:Opal.Theme.alpha(Opal.Theme.level(4),.85)
                            AppIco {anchors.centerIn:parent;icon:modelData.icon;width:36;height:36}
                            Rectangle {visible:modelData.ws!==1;anchors.right:parent.right;anchors.bottom:parent.bottom;width:20;height:20;radius:10;color:Opal.Theme.secondaryContainer
                                Opal.MText {anchors.centerIn:parent;text:modelData.ws;role:"labelS";color:Opal.Theme.onSecondaryContainer}}
                        }
                        // Card state: the same surface, grown.
                        Rectangle {visible:parent.sel;anchors.fill:parent;radius:32;color:Opal.Theme.primaryContainer
                            Win {x:12;y:12;width:parent.width-24;height:206;d:modelData;r:22}
                            Row {x:18;y:230;spacing:10
                                AppIco {icon:modelData.icon;width:30;height:30;anchors.verticalCenter:parent.verticalCenter}
                                Column {anchors.verticalCenter:parent.verticalCenter
                                    Opal.MText {text:modelData.app;role:"titleS";color:Opal.Theme.onContainer}
                                    Opal.MText {text:modelData.t;width:290;role:"labelS";color:Opal.Theme.alpha(Opal.Theme.onContainer,.8)}
                                }
                            }
                        }
                    }
                }
            }
        }
        Row {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:64;spacing:22
            Hint {k:"Tab";t:"Next"} Hint {k:"⇧ Tab";t:"Back"} Hint {k:"Q";t:"Close window"} Hint {k:"Alt ↑";t:"Release to switch"}
        }
    }}

    // D3: overview in rows, one per workspace. Search on top, floating toolbar at the bottom.
    Component {id:d3;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.55)}
        RowLayout {x:48;y:28;width:parent.width-96;spacing:12
            SearchBar {Layout.preferredWidth:520;hint:"Search 7 windows";trail:"All workspaces"}
            Item {Layout.fillWidth:true}
            Opal.MText {text:"Super+Tab";role:"label";color:Opal.Theme.subtext}
        }
        Column {x:48;y:110;width:parent.width-96;spacing:14
            Repeater {model:[1,2,3,4]
                Row {
                    required property int modelData
                    readonly property var ws:root.wins.filter(w=>w.ws===modelData)
                    spacing:14
                    Column {width:120;spacing:6;anchors.verticalCenter:parent.verticalCenter
                        Opal.MText {text:"Workspace";role:"labelS";color:Opal.Theme.subtext}
                        Opal.MText {text:modelData;font.pixelSize:34;font.weight:Font.Bold;color:modelData===1 ? Opal.Theme.primary : Opal.Theme.text}
                        Opal.MText {text:parent.parent.ws.length+(parent.parent.ws.length===1 ? " window" : " windows");role:"labelS";color:Opal.Theme.subtext}
                    }
                    Repeater {model:parent.ws
                        Item {
                            required property var modelData
                            readonly property bool sel:modelData.k==="kitty"
                            width:Math.max(110,Math.min(240,128*modelData.w/modelData.h));height:146
                            Win {width:parent.width;height:120;d:modelData;r:16}
                            Ring {visible:parent.sel;r:16;anchors.bottomMargin:21}
                            Row {y:126;spacing:6;width:parent.width
                                AppIco {icon:modelData.icon;width:18;height:18}
                                Opal.MText {text:modelData.t;role:"labelS";width:parent.width-24;color:parent.parent.sel ? Opal.Theme.text : Opal.Theme.subtext}
                            }
                        }
                    }
                }
            }
        }
        Toolbar {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:24
            items:[{g:"open_in_new",t:"Switch",hot:true},{g:"add",t:"New window"},{split:true,g:"move_item",t:"Move to"},{g:"close",t:"Close"}]}
    }}

    // D4: overview as workspace maps. Each workspace card shows its real tiling; the current one is large.
    Component {id:d4;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.5)}
        SearchBar {x:(parent.width-width)/2;y:24;width:560;hint:"Search windows";trail:"All workspaces"}
        // Current workspace, large.
        Rectangle {
            id:cur4;x:48;y:100;width:760;height:520;radius:32;color:Opal.Theme.alpha(Opal.Theme.level(2),.9);border.width:2;border.color:Opal.Theme.primary
            WsChip {x:18;y:14;n:1;current:true;extra:"2 windows"}
            Item {x:18;y:52;width:parent.width-36;height:parent.height-70
                readonly property real s:Math.min(width/1280,height/800)
                readonly property real ox:(width-1280*s)/2
                Repeater {model:root.wins.filter(w=>w.ws===1)
                    Item {required property var modelData;readonly property real s:parent.s;x:parent.ox+modelData.x*s;y:modelData.y*s;width:modelData.w*s;height:modelData.h*s
                        Win {anchors.fill:parent;d:modelData;r:16}
                        Ring {visible:modelData.k==="kitty";r:16}
                        Rectangle {anchors.left:parent.left;anchors.bottom:parent.bottom;anchors.margins:10;width:lt.implicitWidth+44;height:32;radius:16;color:Opal.Theme.alpha(Opal.Theme.level(4),.95)
                            AppIco {x:8;anchors.verticalCenter:parent.verticalCenter;icon:modelData.icon;width:20;height:20}
                            Opal.MText {id:lt;x:34;anchors.verticalCenter:parent.verticalCenter;text:modelData.app;role:"label"}}
                    }
                }
            }
        }
        // Other workspaces, smaller cards.
        Column {x:828;y:100;spacing:14
            Repeater {model:[2,3,4]
                Rectangle {
                    required property int modelData
                    width:404;height:164;radius:26;color:Opal.Theme.alpha(Opal.Theme.level(2),.82)
                    WsChip {x:12;y:10;n:modelData;extra:root.wins.filter(w=>w.ws===modelData).length+""}
                    Item {x:12;y:44;width:parent.width-24;height:parent.height-54
                        readonly property real s:Math.min(width/1280,height/800)
                        readonly property real ox:(width-1280*s)/2
                        Repeater {model:root.wins.filter(w=>w.ws===modelData)
                            Win {required property var modelData;readonly property real s:parent.s;x:parent.ox+modelData.x*s;y:modelData.y*s;width:modelData.w*s;height:modelData.h*s;d:modelData;r:10}
                        }
                    }
                }
            }
        }
        Toolbar {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:24
            items:[{g:"open_in_new",t:"Switch",hot:true},{g:"add",t:"New workspace"},{split:true,g:"move_item",t:"Move to"},{g:"close",t:"Close"}]}
    }}

    // ---------- Desktop floating ----------

    // F1: Alt+Tab strip with title bars; minimized windows come last behind a divider.
    Component {id:f1;Item {
        FloatDesk {}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.28)}
        Rectangle {
            id:strip3;anchors.centerIn:parent;anchors.verticalCenterOffset:-20
            width:row3.implicitWidth+48;height:row3.implicitHeight+48;radius:36
            color:Opal.Theme.alpha(Opal.Theme.glassIsland,.88);border.width:1;border.color:Opal.Theme.glassEdge
            Row {id:row3;anchors.centerIn:parent;spacing:18
                Repeater {model:root.floats
                    Row {
                        required property var modelData
                        required property int index
                        spacing:18
                        Rectangle {visible:parent.index===3;width:2;height:120;radius:1;color:Opal.Theme.alpha(Opal.Theme.text,.18)}
                        Column {
                            readonly property bool sel:parent.index===1
                            spacing:10
                            Item {width:Math.min(200,120*modelData.w/modelData.h);height:120
                                Win {anchors.fill:parent;d:modelData;r:14;bar:true;opacity:modelData.min ? .45 : 1}
                                Ring {visible:parent.parent.sel;r:14}
                                Rectangle {visible:!!modelData.min;anchors.centerIn:parent;width:mr.implicitWidth+20;height:30;radius:15;color:Opal.Theme.alpha(Opal.Theme.level(4),.95)
                                    Row {id:mr;anchors.centerIn:parent;spacing:4
                                        Opal.Glyph {name:"minimize";font.pixelSize:16;anchors.verticalCenter:parent.verticalCenter}
                                        Opal.MText {text:"Minimized";role:"labelS";anchors.verticalCenter:parent.verticalCenter}}}
                            }
                            AppIco {icon:modelData.icon;width:28;height:28;anchors.horizontalCenter:parent.horizontalCenter}
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.horizontalCenter:parent.horizontalCenter;anchors.top:strip3.bottom;anchors.topMargin:14
            width:tr3.implicitWidth+32;height:44;radius:22;color:Opal.Theme.alpha(Opal.Theme.level(3),.95)
            Row {id:tr3;anchors.centerIn:parent;spacing:10
                Opal.MText {text:"kitty";role:"titleS";anchors.verticalCenter:parent.verticalCenter}
                Opal.MText {text:"~/.local/state/opal/staging — fish";role:"body";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
            }
        }
        Row {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:64;spacing:22
            Hint {k:"Tab";t:"Next"} Hint {k:"M";t:"Minimize / restore"} Hint {k:"Q";t:"Close window"} Hint {k:"Alt ↑";t:"Release to switch"}
        }
    }}

    // F2: exposé. Windows spread out without overlap, keeping their relative places; minimized ones wait in a chip that has opened into a tray.
    Component {id:f2;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.5)}
        SearchBar {x:(parent.width-width)/2;y:24;width:520;hint:"Search windows";trail:"Workspace 1"}
        Repeater {model:[{i:0,x:96,y:110,w:560,h:373},{i:1,x:700,y:150,w:500,h:317},{i:2,x:150,y:470,w:330,h:212}]
            Item {
                required property var modelData
                readonly property var d:root.floats[modelData.i]
                x:modelData.x;y:modelData.y;width:modelData.w;height:modelData.h
                Win {anchors.fill:parent;d:parent.d;bar:true;r:16}
                Ring {visible:parent.modelData.i===1;r:16}
                Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.bottom;anchors.topMargin:-18;width:ft.implicitWidth+46;height:34;radius:17;color:Opal.Theme.alpha(Opal.Theme.level(4),.96)
                    AppIco {x:9;anchors.verticalCenter:parent.verticalCenter;icon:parent.parent.d.icon;width:20;height:20}
                    Opal.MText {id:ft;x:36;anchors.verticalCenter:parent.verticalCenter;text:parent.parent.d.app;role:"label"}}
            }
        }
        // Minimized tray: the "2 minimized" chip has grown into a card.
        Rectangle {
            x:700;y:520;width:500;height:180;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(2),.92)
            Row {x:18;y:14;spacing:8
                Opal.Glyph {name:"minimize";font.pixelSize:20}
                Opal.MText {text:"2 minimized";role:"titleS"}
            }
            Row {x:18;y:52;spacing:14
                Repeater {model:root.floats.filter(w=>w.min)
                    Column {required property var modelData;spacing:6
                        Win {width:200;height:96;d:modelData;bar:true;r:12}
                        Row {spacing:6;AppIco {icon:modelData.icon;width:16;height:16} Opal.MText {text:modelData.app;role:"labelS";color:Opal.Theme.subtext}}
                    }
                }
            }
        }
        Toolbar {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:24
            items:[{g:"open_in_new",t:"Switch",hot:true},{g:"dashboard",t:"Snap layouts"},{g:"desktop_windows",t:"Show desktop"},{split:true,g:"move_item",t:"Move to"},{g:"close",t:""}]}
    }}

    // ---------- Tablet ----------

    component TabletBars:Item {
        anchors.fill:parent
        Rectangle {width:parent.width;height:34;color:"transparent"
            Opal.MText {x:22;anchors.verticalCenter:parent.verticalCenter;text:"14:32";role:"label"}
            Row {anchors.right:parent.right;anchors.rightMargin:22;anchors.verticalCenter:parent.verticalCenter;spacing:6
                Opal.Glyph {name:"wifi";font.pixelSize:16} Opal.Glyph {name:"battery_5_bar";font.pixelSize:16} Opal.MText {text:"82%";role:"labelS"}}
        }
        // Centred floating dock, as on the tablet home.
        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:12;width:dkr.implicitWidth+28;height:68;radius:34;color:Opal.Theme.alpha(Opal.Theme.glassIsland,.85);border.width:1;border.color:Opal.Theme.glassEdge
            Row {id:dkr;anchors.centerIn:parent;spacing:14
                Repeater {model:["firefox","kitty","org.gnome.Nautilus","spotify","steam","code-oss"];AppIco {required property string modelData;icon:modelData;width:42;height:42}}}
        }
    }

    // T1: Android-tablet recents. A row of big cards with an app chip above each; the dock stays put.
    Component {id:t1;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.35)}
        Repeater {model:[{i:2,x:-470},{i:0,x:270},{i:1,x:1030}]
            Item {
                required property var modelData
                readonly property var d:root.phoneWins[modelData.i]
                x:modelData.x;y:110;width:740;height:462
                AppChip {d:parent.d;anchors.horizontalCenter:parent.horizontalCenter;y:-50}
                Win {anchors.fill:parent;d:parent.d;r:28}
            }
        }
        Row {anchors.horizontalCenter:parent.horizontalCenter;y:600;spacing:12
            Toolbar {items:[{g:"screenshot_monitor",t:"Screenshot"},{g:"select",t:"Select"},{g:"splitscreen_left",t:"Split screen",hot:true}]}
            Rectangle {width:clr.implicitWidth+32;height:64;radius:32;color:Opal.Theme.alpha(Opal.Theme.level(3),.96);anchors.verticalCenter:parent.verticalCenter
                Opal.MText {id:clr;anchors.centerIn:parent;text:"Clear all";role:"label"}}
        }
        TabletBars {}
    }}

    // T2: Android 12L grid. The latest app is large; older ones stack in two rows beside it.
    Component {id:t2;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.35)}
        Item {x:640;y:96;width:600;height:390
            AppChip {d:root.phoneWins[0];y:-46}
            Win {anchors.fill:parent;d:root.phoneWins[0];r:28}
        }
        Grid {x:40;y:96;columns:2;columnSpacing:20;rowSpacing:58
            Repeater {model:[1,2,3,4]
                Item {required property int modelData;width:270;height:166
                    AppChip {d:root.phoneWins[modelData];y:-44;scale:.9;transformOrigin:Item.Left}
                    Win {anchors.fill:parent;d:root.phoneWins[modelData];r:20}
                }
            }
        }
        // Split screen: drag a card onto the big one, or pick two.
        Rectangle {x:640;y:506;width:600;height:66;radius:33;color:Opal.Theme.alpha(Opal.Theme.primaryContainer,.9)
            Row {anchors.centerIn:parent;spacing:10
                Opal.Glyph {name:"splitscreen_left";font.pixelSize:22;color:Opal.Theme.onContainer}
                Opal.MText {text:"Drag a card here to split screen with Firefox";role:"label";color:Opal.Theme.onContainer}}
        }
        Row {anchors.horizontalCenter:parent.horizontalCenter;y:606;spacing:12
            Toolbar {items:[{g:"screenshot_monitor",t:"Screenshot"},{g:"select",t:"Select"},{g:"delete_sweep",t:"Clear all"}]}
        }
        TabletBars {}
    }}

    // ---------- Phone ----------

    component PhoneBars:Item {
        anchors.fill:parent
        Item {width:parent.width;height:36
            Opal.MText {x:22;anchors.verticalCenter:parent.verticalCenter;text:"14:32";role:"label"}
            Row {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;spacing:5
                Opal.Glyph {name:"wifi";font.pixelSize:16} Opal.Glyph {name:"battery_5_bar";font.pixelSize:16}}
        }
        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:10;width:120;height:5;radius:3;color:Opal.Theme.text;opacity:.8}
    }

    // P1: Android recents carousel. One big card, neighbours peeking, a floating toolbar under it.
    Component {id:p1;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.4)}
        Repeater {model:[{i:2,x:-262,s:.9},{i:0,x:56,s:1},{i:1,x:374,s:.9}]
            Item {
                required property var modelData
                readonly property var d:root.phoneWins[modelData.i]
                x:modelData.x;y:130;width:300;height:610;scale:modelData.s
                AppChip {visible:parent.modelData.s===1;d:parent.d;anchors.horizontalCenter:parent.horizontalCenter;y:-50}
                Win {anchors.fill:parent;d:parent.d;r:32}
            }
        }
        Toolbar {anchors.horizontalCenter:parent.horizontalCenter;y:772;items:[{g:"screenshot_monitor",t:"Screenshot"},{g:"select",t:"Select"},{g:"splitscreen",t:"Split"}]}
        PhoneBars {}
    }}

    // P2: two-column grid with search; long-press a card for its menu.
    Component {id:p2;Item {
        Wall {blurred:true}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.45)}
        SearchBar {x:16;y:48;width:parent.width-32;hint:"Search recent apps"}
        Grid {x:16;y:150;columns:2;columnSpacing:12;rowSpacing:44
            Repeater {model:root.phoneWins.slice(0,4)
                Item {required property var modelData;required property int index;width:184;height:300
                    Row {y:-32;spacing:6
                        AppIco {icon:modelData.icon;width:22;height:22}
                        Opal.MText {text:modelData.app;role:"label";anchors.verticalCenter:parent.verticalCenter}
                    }
                    Win {anchors.fill:parent;d:modelData;r:24}
                    Ring {visible:index===0;r:24}
                }
            }
        }
        Toolbar {anchors.horizontalCenter:parent.horizontalCenter;y:810;items:[{g:"screenshot_monitor",t:""},{g:"select",t:""},{g:"splitscreen",t:""},{g:"delete_sweep",t:"Clear all"}]}
        PhoneBars {}
    }}

    // ---------- Console ----------

    component PadHint:Row {
        property string b:"A"
        property color c:"#6fcf6a"
        property string t:""
        spacing:8
        Rectangle {width:30;height:30;radius:15;color:parent.c;anchors.verticalCenter:parent.verticalCenter
            Opal.MText {anchors.centerIn:parent;text:parent.parent.b;role:"label";color:"black";font.weight:Font.Bold}}
        Opal.MText {text:parent.t;role:"titleS";anchors.verticalCenter:parent.verticalCenter}
    }

    // C1: hero carousel. The focused app is large; neighbours shrink to the sides.
    Component {id:c1;Item {
        Art {anchors.fill:parent;source:root.heroDr}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.72)}
        Opal.MText {x:64;y:44;text:"Running";role:"headline"}
        Opal.MText {x:64;y:84;text:"4 apps · Guide opens this anywhere";role:"body";color:Opal.Theme.subtext}
        Repeater {model:[{i:3,x:-250,y:258,w:300,h:188},{i:1,x:76,y:258,w:300,h:188},{i:0,x:400,y:180,w:640,h:360},{i:2,x:1064,y:258,w:300,h:188}]
            Item {
                required property var modelData
                readonly property var d:root.games[modelData.i]
                readonly property bool hero:modelData.i===0
                x:modelData.x+(hero ? 0 : modelData.x>600 ? 0 : 0);y:modelData.y;width:modelData.w;height:modelData.h;z:hero ? 2 : 1
                visible:!(modelData.i===1&&false)
                Win {anchors.fill:parent;d:parent.d;r:parent.hero ? 32 : 24;opacity:parent.hero ? 1 : .6}
                Ring {visible:parent.hero;r:32}
            }
        }
        Column {x:400;y:566;spacing:6
            Image {source:root.logoDr;height:56;fillMode:Image.PreserveAspectFit;sourceSize.height:112}
            Opal.MText {text:"Playing · 1 h 12 min · 60 fps profile";role:"body";color:Opal.Theme.subtext}
        }
        Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:64;color:Opal.Theme.alpha(Opal.Theme.level(1),.92)
            Row {anchors.right:parent.right;anchors.rightMargin:40;anchors.verticalCenter:parent.verticalCenter;spacing:30
                PadHint {b:"A";c:"#6fcf6a";t:"Switch"} PadHint {b:"X";c:"#5aa7ff";t:"Close"} PadHint {b:"Y";c:"#f2c94c";t:"Profile"} PadHint {b:"B";c:"#eb5757";t:"Back"}}
        }
    }}

    // C2: Quick Access sheet. Running apps as rows; the focused row has grown into a card.
    Component {id:c2;Item {
        Art {anchors.fill:parent;source:root.shotDr}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.35)}
        Rectangle {
            anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:parent.bottom;anchors.margins:16;width:420;radius:32
            color:Opal.Theme.alpha(Opal.Theme.level(2),.95)
            Opal.MText {x:24;y:22;text:"Running";role:"headline"}
            Column {x:16;y:76;width:parent.width-32;spacing:8
                // Focused: a card with the live preview and actions.
                Rectangle {width:parent.width;height:330;radius:26;color:Opal.Theme.primaryContainer
                    Win {x:12;y:12;width:parent.width-24;height:204;d:root.games[0];r:18}
                    Opal.MText {x:18;y:228;text:"DELTARUNE";role:"title";color:Opal.Theme.onContainer}
                    Opal.MText {x:18;y:252;text:"Playing · 1 h 12 min";role:"labelS";color:Opal.Theme.alpha(Opal.Theme.onContainer,.8)}
                    Row {x:14;y:278;spacing:8
                        Rectangle {width:104;height:40;radius:20;color:Opal.Theme.primary;Opal.MText {anchors.centerIn:parent;text:"Switch";role:"label";color:Opal.Theme.onPrimary}}
                        Rectangle {width:104;height:40;radius:20;color:Opal.Theme.alpha(Opal.Theme.onContainer,.12);Opal.MText {anchors.centerIn:parent;text:"Profile";role:"label";color:Opal.Theme.onContainer}}
                        Rectangle {width:90;height:40;radius:20;color:Opal.Theme.alpha(Opal.Theme.onContainer,.12);Opal.MText {anchors.centerIn:parent;text:"Close";role:"label";color:Opal.Theme.onContainer}}
                    }
                }
                Repeater {model:root.games.slice(1)
                    Rectangle {required property var modelData;width:parent.width;height:76;radius:20;color:Opal.Theme.alpha(Opal.Theme.level(3),.9)
                        Win {x:10;y:10;width:96;height:56;d:modelData;r:10}
                        Column {x:120;anchors.verticalCenter:parent.verticalCenter;spacing:2
                            Opal.MText {text:modelData.t;role:"titleS"}
                            Opal.MText {text:modelData.sub;role:"labelS";color:Opal.Theme.subtext}}
                    }
                }
            }
            Row {anchors.bottom:parent.bottom;anchors.bottomMargin:20;x:24;spacing:22
                PadHint {b:"A";c:"#6fcf6a";t:"Switch"} PadHint {b:"X";c:"#5aa7ff";t:"Close"} PadHint {b:"B";c:"#eb5757";t:"Back"}}
        }
    }}
}
