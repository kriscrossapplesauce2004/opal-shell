import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Settings, Look and M3E components render round 1 (2026-10-23): Android 16 style Settings on desktop and phone, the Glass/Mixed/Material page, deep search, and the new components.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string wallpaper:"file:///home/melissa/Pictures/Wallpapers/dr5-keyart-YzI66DkClTeJ5jBQ.png"
    readonly property var th:Opal.Theme
    // Proposed tree. Each group is one card of connected rows.
    readonly property var groups:[
        [{g:"wifi",t:"Network & internet",d:"Wi-Fi · Opal-5G"},{g:"bluetooth",t:"Connected devices",d:"Bluetooth, Opal Link, controllers"}],
        [{g:"apps",t:"Apps & windows",d:"Tiling, app switcher, file dialogs"},{g:"notifications",t:"Notifications",d:"Do not disturb, inbox"},{g:"battery_5_bar",t:"Battery & power",d:"82% · Balanced"},{g:"volume_up",t:"Sound",d:"Volume 64% · Speakers"}],
        [{g:"monitor",t:"Displays",d:"Arrangement, night light"},{g:"palette",t:"Wallpaper & style",d:"Colours, themes, Look"},{g:"dock_to_bottom",t:"Home & shelf",d:"Layout, shelf, widgets"},{g:"swipe",t:"Phone & gestures",d:"Navigation, edges, keyboard"},{g:"sports_esports",t:"Games & controller",d:"Button order, Quick Access"}],
        [{g:"routine",t:"Modes & routines",d:"Schedules, profiles"},{g:"accessibility_new",t:"Accessibility",d:"Motion, contrast"},{g:"system_update",t:"System",d:"Updates, storage, app themes"},{g:"info",t:"About this device",d:"Opal · up 3 h"}]
    ]

    Window {
        id:fixture
        width:1280;height:800;visible:true;color:"black"
        property int step:0
        property var cases:[
            {name:"st-01-desktop-glass",view:s1,w:1280,h:800},
            {name:"st-02-desktop-material",view:s2,w:1280,h:800},
            {name:"st-03-deep-search",view:s3,w:1280,h:800},
            {name:"st-04-look-page",view:s4,w:1280,h:800},
            {name:"st-05-phone-home",view:s5,w:412,h:915},
            {name:"st-06-phone-subpage",view:s6,w:412,h:915},
            {name:"st-07-components",view:s7,w:1280,h:800},
            {name:"st-08-presets-compared",view:s8,w:1280,h:800}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            width=cases[step].w;height=cases[step].h;
            loader.sourceComponent=null;loader.sourceComponent=cases[step].view;
            grab.restart();
        }
        Timer {id:grab;interval:2400;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:{const only=Quickshell.env("OPAL_CASE");if(only)cases=cases.filter(c=>c.name.indexOf(only)>=0);Qt.callLater(run);}
    }

    // ---------- Look model ----------

    // A look decides each surface's fill. Solid surfaces are opaque M3 tonal containers; glass ones let the wallpaper through.
    component Look:QtObject {
        property bool solidSheets:false
        property bool solidBars:false
        property bool edges:true
        property bool shadows:false
        function sheet(c,a) {return solidSheets ? root.th.mix(c,c,0) : root.th.alpha(c,a*.8);}
        function bar(c,a) {return solidBars ? root.th.mix(c,c,0) : root.th.alpha(c,a);}
    }

    // ---------- Components ----------

    component Wall:Image {
        property bool blurred:false
        anchors.fill:parent;source:root.wallpaper;fillMode:Image.PreserveAspectCrop
        sourceSize:blurred ? Qt.size(48,30) : Qt.size(1280,800);smooth:true
    }

    // Rounded, cropped art on the software renderer.
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

    // M3E switch: the handle carries a check when on and a cross when off.
    component Sw:Rectangle {
        property bool on:false
        property bool pressed:false
        width:52;height:32;radius:16
        color:on ? root.th.primary : root.th.level(4)
        border.width:on ? 0 : 2;border.color:root.th.alpha(root.th.subtext,.7)
        Rectangle {
            readonly property real s:parent.pressed ? 28 : 24
            width:s;height:s;radius:s/2;anchors.verticalCenter:parent.verticalCenter
            x:parent.on ? parent.width-width-4 : 4
            color:parent.on ? root.th.onPrimary : root.th.subtext
            Opal.Glyph {anchors.centerIn:parent;name:parent.parent.on ? "check" : "close";font.pixelSize:16;color:parent.parent.on ? root.th.primary : root.th.level(4)}
        }
    }

    // Segmented list row: one card of a connected group. Ends round to 24, the middle keeps 4.
    component Row2:Rectangle {
        id:rw
        property string g:""
        property string t:""
        property string d:""
        property string value:""
        property bool first:true
        property bool last:true
        property bool current:false
        property bool found:false
        property int sw:-1
        property bool chevron:false
        property int tint:0
        property var look:null
        property bool badge:true
        implicitHeight:d ? 72 : 60
        Layout.fillWidth:true
        topLeftRadius:first ? 24 : 4;topRightRadius:topLeftRadius
        bottomLeftRadius:last ? 24 : 4;bottomRightRadius:bottomLeftRadius
        color:current ? root.th.secondaryContainer : found ? root.th.primaryContainer : look ? look.sheet(root.th.level(3),.55) : root.th.alpha(root.th.level(3),.55)
        border.width:found ? 2 : 0;border.color:root.th.primary
        RowLayout {anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:16;spacing:16
            Rectangle {visible:rw.g!=="";Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20
                color:!rw.badge ? "transparent" : [root.th.primaryContainer,root.th.secondaryContainer,root.th.tertiaryContainer,root.th.level(5)][rw.tint%4]
                Opal.Glyph {anchors.centerIn:parent;name:rw.g;font.pixelSize:22;color:!rw.badge ? root.th.subtext : [root.th.onContainer,root.th.onSecondaryContainer,root.th.onTertiaryContainer,root.th.text][rw.tint%4]}
            }
            ColumnLayout {Layout.fillWidth:true;spacing:2
                Opal.MText {Layout.fillWidth:true;text:rw.t;role:"titleS";color:rw.current ? root.th.onSecondaryContainer : rw.found ? root.th.onContainer : root.th.text}
                Opal.MText {visible:rw.d!=="";Layout.fillWidth:true;text:rw.d;role:"bodyS";color:rw.current ? root.th.alpha(root.th.onSecondaryContainer,.75) : rw.found ? root.th.alpha(root.th.onContainer,.8) : root.th.subtext;wrapMode:Text.Wrap;maximumLineCount:2}
            }
            Opal.MText {visible:rw.value!=="";text:rw.value;role:"label";color:root.th.subtext}
            Sw {visible:rw.sw>=0;on:rw.sw===1}
            Opal.Glyph {visible:rw.chevron;name:"chevron_right";font.pixelSize:22;color:root.th.subtext}
        }
    }

    // Group label above a card group.
    component Label2:Opal.MText {role:"label";color:root.th.primary;Layout.leftMargin:16;Layout.topMargin:14;Layout.bottomMargin:2}

    // M3E search bar.
    component Search:Rectangle {
        property string hint:"Search settings"
        property string typed:""
        property var look:null
        Layout.fillWidth:true;implicitHeight:56;radius:28
        color:look ? look.sheet(root.th.level(4),.8) : root.th.alpha(root.th.level(4),.8)
        Opal.Glyph {x:18;anchors.verticalCenter:parent.verticalCenter;name:parent.typed ? "arrow_back" : "search";font.pixelSize:24}
        Opal.MText {x:56;anchors.verticalCenter:parent.verticalCenter;text:parent.typed||parent.hint;role:"body";color:parent.typed ? root.th.text : root.th.subtext}
        Rectangle {visible:parent.typed!=="";x:57+tm.implicitWidth;anchors.verticalCenter:parent.verticalCenter;width:2;height:22;color:root.th.primary
            Opal.MText {id:tm;visible:false;text:parent.parent.typed;role:"body"}}
        Opal.Glyph {visible:parent.typed!=="";anchors.right:parent.right;anchors.rightMargin:18;anchors.verticalCenter:parent.verticalCenter;name:"close";font.pixelSize:22;color:root.th.subtext}
    }

    // Connected button group. Selection changes colour only; a pressed segment squishes wider.
    component Group2:RowLayout {
        id:bg
        property var items:[]
        property int sel:0
        property int pressedAt:-1
        property real h:48
        spacing:2
        Repeater {model:bg.items
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool on:index===bg.sel
                Layout.fillWidth:true;Layout.preferredWidth:index===bg.pressedAt ? 1.25 : 1;Layout.preferredHeight:bg.h
                topLeftRadius:index===0 ? bg.h/2 : 8;bottomLeftRadius:topLeftRadius
                topRightRadius:index===bg.items.length-1 ? bg.h/2 : 8;bottomRightRadius:topRightRadius
                color:on ? root.th.primary : root.th.alpha(root.th.level(4),.9)
                Row {anchors.centerIn:parent;spacing:6
                    Opal.Glyph {visible:!!parent.parent.modelData.g;name:parent.parent.modelData.g||"";font.pixelSize:18;color:parent.parent.on ? root.th.onPrimary : root.th.text;anchors.verticalCenter:parent.verticalCenter}
                    Opal.MText {text:parent.parent.modelData.t;role:"label";color:parent.parent.on ? root.th.onPrimary : root.th.text;anchors.verticalCenter:parent.verticalCenter}
                }
            }
        }
    }

    // Split button: main action and a menu half, same size and style.
    component Split2:Row {
        property string g:"add"
        property string t:"Action"
        property bool tonal:false
        property real h:40
        spacing:2
        Rectangle {width:sl.implicitWidth+sg.width+34;height:parent.h;topLeftRadius:parent.h/2;bottomLeftRadius:parent.h/2;topRightRadius:4;bottomRightRadius:4;color:parent.tonal ? root.th.secondaryContainer : root.th.primary
            Opal.Glyph {id:sg;x:14;anchors.verticalCenter:parent.verticalCenter;name:parent.parent.g;font.pixelSize:20;color:parent.parent.tonal ? root.th.onSecondaryContainer : root.th.onPrimary}
            Opal.MText {id:sl;x:sg.x+sg.width+8;anchors.verticalCenter:parent.verticalCenter;text:parent.parent.t;role:"label";color:parent.parent.tonal ? root.th.onSecondaryContainer : root.th.onPrimary}}
        Rectangle {width:parent.h;height:parent.h;topLeftRadius:4;bottomLeftRadius:4;topRightRadius:parent.h/2;bottomRightRadius:parent.h/2;color:parent.tonal ? root.th.secondaryContainer : root.th.primary
            Opal.Glyph {anchors.centerIn:parent;anchors.horizontalCenterOffset:-2;name:"keyboard_arrow_down";font.pixelSize:20;color:parent.parent.tonal ? root.th.onSecondaryContainer : root.th.onPrimary}}
    }

    // M3E loading indicator: a shape that morphs through the expressive set inside a container.
    component Loading:Item {
        property int lobes:7
        property real depth:.16
        property real phase:0
        property bool contained:true
        width:48;height:48
        Rectangle {visible:parent.contained;anchors.fill:parent;radius:width/2;color:root.th.primaryContainer}
        Opal.Flower {anchors.centerIn:parent;width:parent.width*.7;height:width;lobes:parent.lobes;depth:parent.depth;phase:parent.phase;fill:parent.contained ? root.th.onContainer : root.th.primary}
    }

    // Large flexible top app bar: back, a big title, and a subtitle.
    component TopBar2:ColumnLayout {
        property string t:""
        property string d:""
        property bool collapsed:false
        Layout.fillWidth:true;spacing:collapsed ? 0 : 6
        RowLayout {Layout.fillWidth:true;spacing:8
            Rectangle {Layout.preferredWidth:44;Layout.preferredHeight:44;radius:22;color:root.th.alpha(root.th.level(4),.8)
                Opal.Glyph {anchors.centerIn:parent;name:"arrow_back"}}
            Opal.MText {visible:parent.parent.collapsed;Layout.fillWidth:true;text:parent.parent.t;role:"title"}
            Item {visible:!parent.parent.collapsed;Layout.fillWidth:true}
            Rectangle {Layout.preferredWidth:44;Layout.preferredHeight:44;radius:22;color:"transparent"
                Opal.Glyph {anchors.centerIn:parent;name:"search";color:root.th.subtext}}
        }
        Opal.MText {visible:!parent.collapsed;Layout.fillWidth:true;Layout.topMargin:18;text:parent.t;font.pixelSize:40;font.weight:Font.Medium;font.variableAxes:({"wdth":110,"ROND":60})}
        Opal.MText {visible:!parent.collapsed&&parent.d!=="";Layout.fillWidth:true;text:parent.d;role:"body";color:root.th.subtext;Layout.bottomMargin:6}
    }

    // Navigation pane: title, search and the connected groups.
    component Nav:ColumnLayout {
        id:nav
        property var look:null
        property int current:-1
        property bool compactRows:false
        spacing:4
        Opal.MText {text:"Settings";font.pixelSize:36;font.weight:Font.Medium;font.variableAxes:({"wdth":110,"ROND":60});Layout.leftMargin:8;Layout.bottomMargin:10}
        Search {look:nav.look}
        Item {Layout.preferredHeight:8}
        Repeater {model:root.groups
            ColumnLayout {
                id:grp
                required property var modelData
                required property int index
                Layout.fillWidth:true;Layout.bottomMargin:12;spacing:2
                Repeater {model:grp.modelData
                    Row2 {
                        required property var modelData
                        required property int index
                        look:nav.look;g:modelData.g;t:modelData.t;d:nav.compactRows ? "" : modelData.d;tint:grp.index
                        first:index===0;last:index===grp.modelData.length-1
                        current:root.groups.slice(0,grp.index).reduce((n,x)=>n+x.length,0)+index===nav.current
                        implicitHeight:nav.compactRows ? 52 : 64
                    }
                }
            }
        }
    }

    // A desktop with the settings window over it.
    component Stage:Item {
        id:stage
        property var look:null
        default property alias content:win.data
        anchors.fill:parent
        Wall {}
        Rectangle {anchors.fill:parent;color:root.th.alpha("#000000",.18)}
        Rectangle {
            id:shadow;visible:!!stage.look&&stage.look.shadows;x:win.x;y:win.y+10;width:win.width;height:win.height;radius:36;color:root.th.alpha("#000000",.35)
        }
        Rectangle {
            id:win;x:(parent.width-width)/2;y:(parent.height-height)/2;width:1120;height:740;radius:36
            color:stage.look ? stage.look.sheet(root.th.level(1),.9) : root.th.alpha(root.th.level(1),.9)
            border.width:stage.look&&!stage.look.edges ? 0 : 1;border.color:root.th.glassEdge
        }
    }

    // ---------- Scenes ----------

    // S1: desktop, Glass. Two panes; the page has a large title over segmented rows.
    Component {id:s1;Item {
        Look {id:lk1}
        Stage {look:lk1
            Flickable {x:16;y:24;width:372;height:parent.height-24;clip:true;contentHeight:nav1.implicitHeight;interactive:false
                Nav {id:nav1;width:parent.width;look:lk1;current:7}}
            ColumnLayout {x:412;y:24;width:parent.width-440;spacing:2
                TopBar2 {t:"Wallpaper & style";d:"Colours, themes and the Look of Opal"}
                Item {Layout.preferredHeight:10}
                Item {Layout.fillWidth:true;Layout.preferredHeight:200
                    Art {anchors.fill:parent;source:root.wallpaper;radius:28}
                    Split2 {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:14;g:"wallpaper";t:"Change wallpaper";h:44}
                }
                Label2 {text:"Colour"}
                Rectangle {Layout.fillWidth:true;implicitHeight:92;topLeftRadius:24;topRightRadius:24;bottomLeftRadius:4;bottomRightRadius:4;color:lk1.sheet(root.th.level(3),.55)
                    Row {anchors.verticalCenter:parent.verticalCenter;x:18;spacing:14
                        Repeater {model:[[root.th.primary,root.th.tertiary,true],["#a5efff","#dfd6bb",false],["#ffc09e","#c8dba5",false],["#b3ccff","#a6dfc2",false],["#cfbdff","#efb8c8",false]]
                            Item {required property var modelData;width:60;height:60
                                Rectangle {anchors.fill:parent;radius:30;color:"transparent";border.width:modelData[2] ? 3 : 0;border.color:root.th.primary}
                                Rectangle {anchors.centerIn:parent;width:48;height:48;radius:24;color:modelData[0];clip:true
                                    Rectangle {x:24;y:24;width:24;height:24;color:modelData[1];bottomRightRadius:24}}
                                Opal.Glyph {visible:modelData[2];anchors.centerIn:parent;name:"check";color:root.th.onPrimary;font.pixelSize:20}
                            }
                        }
                    }
                    Opal.MText {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;text:"From wallpaper";role:"label";color:root.th.subtext}
                }
                Row2 {look:lk1;first:false;last:false;g:"dark_mode";badge:false;t:"Dark theme";sw:1}
                Row2 {look:lk1;first:false;last:true;g:"layers";badge:false;t:"Look";d:"Glass · see-through surfaces with blur";chevron:true}
                Label2 {text:"App icons"}
                Group2 {Layout.fillWidth:true;items:[{g:"apps",t:"Original"},{g:"rounded_corner",t:"Backplate"},{g:"palette",t:"Themed"}];sel:1}
            }
        }
    }}

    // S2: desktop, Material. The same window, opaque; Battery & power with a hero card.
    Component {id:s2;Item {
        Look {id:lk2;solidSheets:true;solidBars:true;edges:false;shadows:true}
        Stage {look:lk2
            Flickable {x:16;y:24;width:372;height:parent.height-24;clip:true;contentHeight:nav2.implicitHeight;interactive:false
                Nav {id:nav2;width:parent.width;look:lk2;current:4}}
            ColumnLayout {x:412;y:24;width:parent.width-440;spacing:2
                TopBar2 {t:"Battery & power";d:"82% · about 4 h 10 min left"}
                Item {Layout.preferredHeight:10}
                Rectangle {Layout.fillWidth:true;Layout.preferredHeight:128;radius:28;color:root.th.primaryContainer
                    Row {x:22;anchors.verticalCenter:parent.verticalCenter;spacing:18
                        Rectangle {width:40;height:76;radius:14;color:root.th.alpha(root.th.onContainer,.14)
                            Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:parent.height*.82;radius:14;color:root.th.onContainer}}
                        Column {anchors.verticalCenter:parent.verticalCenter;spacing:2
                            Opal.MText {text:"82%";font.pixelSize:40;font.weight:Font.Medium;color:root.th.onContainer}
                            Opal.MText {text:"On battery · Balanced";role:"body";color:root.th.alpha(root.th.onContainer,.8)}}
                    }
                }
                Label2 {text:"Power profile"}
                Group2 {Layout.fillWidth:true;items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"speed",t:"Performance"}];sel:1}
                Item {Layout.preferredHeight:10}
                Row2 {look:lk2;first:true;last:false;g:"coffee";badge:false;t:"Keep awake";d:"The screen does not sleep while this is on";sw:0}
                Row2 {look:lk2;first:false;last:false;g:"battery_saver";badge:false;t:"Saver at 20%";sw:1}
                Row2 {look:lk2;first:false;last:true;g:"power_settings_new";badge:false;t:"Power key";d:"Tap for the drum menu";chevron:true}
                Label2 {text:"Session"}
                Group2 {Layout.fillWidth:true;items:[{g:"lock",t:"Lock"},{g:"bedtime",t:"Sleep"},{g:"restart_alt",t:"Restart"},{g:"power_settings_new",t:"Shut down"}];sel:-1;h:56}
            }
        }
    }}

    // S3: deep search. Results show the path to each setting; the chosen hit opened its page and is highlighted.
    Component {id:s3;Item {
        Look {id:lk3}
        Stage {look:lk3
            ColumnLayout {x:16;y:24;width:372;spacing:4
                Opal.MText {text:"Settings";font.pixelSize:36;font.weight:Font.Medium;font.variableAxes:({"wdth":110,"ROND":60});Layout.leftMargin:8;Layout.bottomMargin:10}
                Search {look:lk3;typed:"motion"}
                Opal.MText {text:"4 results";role:"label";color:root.th.subtext;Layout.leftMargin:16;Layout.topMargin:12;Layout.bottomMargin:4}
                Row2 {look:lk3;first:true;last:false;current:true;g:"animation";tint:3;t:"Reduce motion";d:"Accessibility"}
                Row2 {look:lk3;first:false;last:false;g:"animation";tint:3;t:"Motion speed";d:"Accessibility"}
                Row2 {look:lk3;first:false;last:false;g:"palette";tint:2;t:"Theme ripple";d:"Wallpaper & style › Look"}
                Row2 {look:lk3;first:false;last:true;g:"swipe";tint:2;t:"Gesture animations";d:"Phone & gestures"}
                Opal.MText {text:"Sections";role:"label";color:root.th.subtext;Layout.leftMargin:16;Layout.topMargin:14;Layout.bottomMargin:4}
                Row2 {look:lk3;g:"accessibility_new";tint:3;t:"Accessibility";d:"Motion, contrast"}
            }
            ColumnLayout {x:412;y:24;width:parent.width-440;spacing:2
                TopBar2 {t:"Accessibility";d:"Motion and readable surfaces"}
                Label2 {text:"Motion"}
                Row2 {look:lk3;first:true;last:false;found:true;g:"animation";badge:false;t:"Reduce motion";d:"Remove transitions and decorative animation";sw:0}
                Row2 {look:lk3;first:false;last:true;g:"speed";badge:false;t:"Motion speed";value:"Normal";chevron:true}
                Label2 {text:"Readability"}
                Row2 {look:lk3;first:true;last:false;g:"contrast";badge:false;t:"High contrast text";sw:0}
                Row2 {look:lk3;first:false;last:false;g:"layers";badge:false;t:"Solid surfaces";d:"Same as the Material look";sw:0}
                Row2 {look:lk3;first:false;last:true;g:"format_size";badge:false;t:"Text size";value:"100%";chevron:true}
            }
            // The highlight fades after a moment; a small chip names why the page opened.
            Rectangle {x:412+(parent.width-440)-width;y:188;width:fnd.implicitWidth+28;height:30;radius:15;color:root.th.primary
                Opal.MText {id:fnd;anchors.centerIn:parent;text:"Found “motion”";role:"labelS";color:root.th.onPrimary}}
        }
    }}

    // S4: the Look page. Presets as preview cards, surfaces as rows, effects as switches.
    Component {id:s4;Item {
        Look {id:lk4;solidSheets:true}
        Stage {look:lk4
            Flickable {x:16;y:24;width:372;height:parent.height-24;clip:true;contentHeight:nav4.implicitHeight;interactive:false
                Nav {id:nav4;width:parent.width;look:lk4;current:7;compactRows:true}}
            ColumnLayout {x:412;y:20;width:parent.width-440;spacing:2
                TopBar2 {t:"Look";collapsed:true}
                Item {Layout.preferredHeight:6}
                RowLayout {Layout.fillWidth:true;spacing:12
                    Repeater {model:[{t:"Glass",d:"See-through, blurred",a:.62,b:.55,on:false},{t:"Mixed",d:"Solid sheets, glass bars",a:1,b:.55,on:true},{t:"Material",d:"Everything solid",a:1,b:1,on:false}]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth:true;Layout.preferredHeight:164;radius:28
                            color:modelData.on ? root.th.secondaryContainer : root.th.level(3)
                            border.width:modelData.on ? 2 : 0;border.color:root.th.primary
                            Item {x:12;y:12;width:parent.width-24;height:96
                                Art {anchors.fill:parent;source:root.wallpaper;radius:18}
                                // A sheet and a bar, filled the way the preset fills them.
                                Rectangle {x:12;y:10;width:parent.width*.55;height:62;radius:12;color:root.th.alpha(root.th.level(1),modelData.a)
                                    Column {x:10;y:12;spacing:6
                                        Rectangle {width:60;height:7;radius:4;color:root.th.text;opacity:.7}
                                        Rectangle {width:90;height:16;radius:6;color:root.th.alpha(root.th.level(3),modelData.a)}
                                        Rectangle {width:90;height:16;radius:6;color:root.th.alpha(root.th.level(3),modelData.a)}}}
                                Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:8;anchors.horizontalCenter:parent.horizontalCenter;width:parent.width*.7;height:20;radius:10;color:root.th.alpha(root.th.glassIsland,modelData.b)}
                            }
                            Row {x:16;y:116;spacing:8
                                Opal.Glyph {visible:modelData.on;name:"check_circle";font.pixelSize:20;color:root.th.primary;anchors.verticalCenter:parent.verticalCenter}
                                Opal.MText {text:modelData.t;role:"titleS";color:modelData.on ? root.th.onSecondaryContainer : root.th.text}}
                            Opal.MText {x:16;y:140;text:modelData.d;role:"labelS";color:root.th.subtext}
                        }
                    }
                }
                RowLayout {Layout.fillWidth:true;Layout.topMargin:8
                    Label2 {text:"Surfaces";Layout.topMargin:0}
                    Item {Layout.fillWidth:true}
                    Rectangle {width:cst.implicitWidth+22;height:26;radius:13;color:root.th.tertiaryContainer
                        Opal.MText {id:cst;anchors.centerIn:parent;text:"Custom · Home widgets changed";role:"labelS";color:root.th.onTertiaryContainer}}
                }
                GridLayout {Layout.fillWidth:true;columns:2;columnSpacing:2;rowSpacing:2
                    Repeater {model:[{g:"web_asset",t:"Panels & sheets",s:1},{g:"menu",t:"Menus",s:1},{g:"dock_to_bottom",t:"Shelf & dock",s:0},{g:"widgets",t:"Home widgets",s:1,changed:true},{g:"tune",t:"Shade & Quick Settings",s:1},{g:"lock",t:"Lock screen",s:0}]
                        Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth:true;Layout.preferredWidth:1;implicitHeight:56
                            topLeftRadius:index===0 ? 24 : 4;topRightRadius:index===1 ? 24 : 4;bottomLeftRadius:index===4 ? 24 : 4;bottomRightRadius:index===5 ? 24 : 4
                            color:root.th.level(3)
                            RowLayout {anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:8;spacing:10
                                Opal.Glyph {name:modelData.g;color:root.th.subtext;font.pixelSize:20}
                                Opal.MText {Layout.fillWidth:true;text:modelData.t;role:"label"}
                                Rectangle {visible:!!modelData.changed;Layout.preferredWidth:8;Layout.preferredHeight:8;radius:4;color:root.th.tertiary}
                                Group2 {Layout.preferredWidth:132;Layout.maximumWidth:132;h:36;items:[{t:"Glass"},{t:"Solid"}];sel:modelData.s}
                            }
                        }
                    }
                }
                Label2 {text:"Effects"}
                GridLayout {Layout.fillWidth:true;columns:2;columnSpacing:2;rowSpacing:2
                    Repeater {model:[{g:"blur_on",t:"Compositor blur",d:"Behind glass surfaces",on:1},{g:"auto_awesome",t:"Glass edges & sheen",d:"Light rim and top highlight",on:1},{g:"shadow",t:"Elevation shadows",d:"Soft shadow under floating things",on:0},{g:"opacity",t:"App transparency",d:"Kitty and exported themes",on:0}]
                        Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth:true;Layout.preferredWidth:1;implicitHeight:68
                            topLeftRadius:index===0 ? 24 : 4;topRightRadius:index===1 ? 24 : 4;bottomLeftRadius:index===2 ? 24 : 4;bottomRightRadius:index===3 ? 24 : 4
                            color:root.th.level(3)
                            RowLayout {anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:12;spacing:10
                                Opal.Glyph {name:modelData.g;color:root.th.subtext;font.pixelSize:20}
                                ColumnLayout {Layout.fillWidth:true;spacing:1
                                    Opal.MText {Layout.fillWidth:true;text:modelData.t;role:"label"}
                                    Opal.MText {Layout.fillWidth:true;text:modelData.d;role:"labelS";color:root.th.subtext}}
                                Sw {on:modelData.on===1}
                            }
                        }
                    }
                }
                Label2 {text:"Glass density · 57%"}
                Opal.ExpressiveSlider {Layout.fillWidth:true;value:57;from:45;to:100;icon:"opacity";iconAtHandle:true;compact:true;trackHeight:36;implicitHeight:48}
            }
        }
    }}

    // Phone status and gesture bar.
    component PhoneBars:Item {
        anchors.fill:parent
        Item {width:parent.width;height:36
            Opal.MText {x:22;anchors.verticalCenter:parent.verticalCenter;text:"14:32";role:"label"}
            Row {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;spacing:5
                Opal.Glyph {name:"wifi";font.pixelSize:16} Opal.Glyph {name:"battery_5_bar";font.pixelSize:16}}
        }
        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:10;width:120;height:5;radius:3;color:root.th.text;opacity:.8}
    }

    // S5: phone, Android 16 Settings home.
    Component {id:s5;Item {
        Look {id:lk5;solidSheets:true}
        Rectangle {anchors.fill:parent;color:root.th.level(1)}
        Flickable {x:14;y:52;width:parent.width-28;height:parent.height-70;clip:true;contentHeight:nav5.implicitHeight;interactive:false
            Nav {id:nav5;width:parent.width;look:lk5}}
        PhoneBars {}
    }}

    // S6: phone subpage, scrolled: the large title has collapsed into the bar.
    Component {id:s6;Item {
        Look {id:lk6;solidSheets:true}
        Rectangle {anchors.fill:parent;color:root.th.level(1)}
        ColumnLayout {x:14;y:44;width:parent.width-28;spacing:2
            TopBar2 {t:"Apps & windows";collapsed:true}
            Item {Layout.preferredHeight:8}
            Label2 {text:"Window mode";Layout.topMargin:2}
            Group2 {Layout.fillWidth:true;items:[{g:"grid_view",t:"Tiling"},{g:"select_window",t:"Floating"}];sel:0}
            Label2 {text:"App switcher"}
            Row2 {look:lk6;first:true;last:false;g:"tab";badge:false;t:"Alt+Tab shows";value:"All windows";chevron:true}
            Row2 {look:lk6;first:false;last:false;g:"history";badge:false;t:"Recent order";d:"The last window is one quick tap away";sw:1}
            Row2 {look:lk6;first:false;last:true;g:"preview";badge:false;t:"Live previews";sw:1}
            Label2 {text:"File dialogs"}
            Row2 {look:lk6;first:true;last:false;g:"folder_open";badge:false;t:"Opal file picker";value:"Phone & tablet";chevron:true}
            Rectangle {Layout.fillWidth:true;implicitHeight:72;topLeftRadius:4;topRightRadius:4;bottomLeftRadius:24;bottomRightRadius:24;color:root.th.level(3)
                RowLayout {anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:16;spacing:16
                    Loading {lobes:9;depth:.14;width:40;height:40}
                    ColumnLayout {Layout.fillWidth:true;spacing:2
                        Opal.MText {text:"Portal";role:"titleS"}
                        Opal.MText {text:"Checking xdg-desktop-portal…";role:"bodyS";color:root.th.subtext}}
                }
            }
            Label2 {text:"Default apps"}
            Row2 {look:lk6;first:true;last:true;g:"open_in_new";badge:false;t:"Browser";value:"Firefox";chevron:true}
        }
        PhoneBars {}
    }}

    // S7: component sheet.
    Component {id:s7;Rectangle {
        color:root.th.level(1)
        component Cap:Opal.MText {role:"label";color:root.th.primary}
        GridLayout {x:40;y:32;width:parent.width-80;columns:3;columnSpacing:40;rowSpacing:26
            ColumnLayout {spacing:12;Layout.alignment:Qt.AlignTop
                Cap {text:"Loading indicator · shape morph frames"}
                Row {spacing:14
                    Repeater {model:[[4,.22,0],[5,.2,20],[7,.16,40],[9,.14,60],[12,.1,80]];Loading {required property var modelData;lobes:modelData[0];depth:modelData[1];phase:modelData[2]}}
                }
                Row {spacing:14
                    Repeater {model:[[4,.22,0],[7,.16,40],[12,.1,80]];Loading {required property var modelData;contained:false;lobes:modelData[0];depth:modelData[1];phase:modelData[2]}}
                }
                Cap {text:"Switch · cross off, check on, pressed";Layout.topMargin:8}
                Row {spacing:14;Sw {on:false} Sw {on:true} Sw {on:true;pressed:true}}
                Cap {text:"Slider";Layout.topMargin:8}
                Opal.ExpressiveSlider {Layout.preferredWidth:340;value:64;icon:"volume_up";iconAtHandle:true;compact:true;trackHeight:40;implicitHeight:56}
                Opal.LinearProgress {Layout.preferredWidth:340;value:.62}
            }
            ColumnLayout {spacing:12;Layout.alignment:Qt.AlignTop
                Cap {text:"Split buttons"}
                Row {spacing:12;Split2 {g:"wallpaper";t:"Wallpaper"} Split2 {tonal:true;g:"move_item";t:"Move to"}}
                Cap {text:"Button group · selected, and pressed (squish)";Layout.topMargin:8}
                Group2 {Layout.preferredWidth:340;items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"speed",t:"Fast"}];sel:1}
                Group2 {Layout.preferredWidth:340;items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"speed",t:"Fast"}];sel:1;pressedAt:2}
                Cap {text:"Search bar";Layout.topMargin:8}
                Search {Layout.preferredWidth:340}
                Cap {text:"Flexible top app bar · large, collapsed";Layout.topMargin:8}
                Rectangle {Layout.preferredWidth:340;Layout.preferredHeight:172;radius:20;color:root.th.level(2)
                    TopBar2 {x:14;y:10;width:312;t:"Sound";d:"Volume 64% · Speakers"}}
                Rectangle {Layout.preferredWidth:340;Layout.preferredHeight:64;radius:20;color:root.th.level(2)
                    TopBar2 {x:14;y:10;width:312;t:"Sound";collapsed:true}}
            }
            ColumnLayout {spacing:12;Layout.alignment:Qt.AlignTop
                Cap {text:"Floating toolbar · standard, vibrant"}
                Rectangle {Layout.preferredWidth:ftr.implicitWidth+16;Layout.preferredHeight:64;radius:32;color:root.th.level(3)
                    Row {id:ftr;anchors.centerIn:parent;spacing:4
                        Repeater {model:["content_cut","content_copy","content_paste","share"];Rectangle {required property string modelData;width:48;height:48;radius:24;color:"transparent";Opal.Glyph {anchors.centerIn:parent;name:modelData}}}
                        Rectangle {width:56;height:48;radius:16;color:root.th.primary;Opal.Glyph {anchors.centerIn:parent;name:"edit";color:root.th.onPrimary}}}}
                Rectangle {Layout.preferredWidth:ftr2.implicitWidth+16;Layout.preferredHeight:64;radius:32;color:root.th.primaryContainer
                    Row {id:ftr2;anchors.centerIn:parent;spacing:4
                        Repeater {model:["format_bold","format_italic","format_underlined","link"];Rectangle {required property string modelData;width:48;height:48;radius:24;color:index===0 ? root.th.alpha(root.th.onContainer,.16) : "transparent";required property int index;Opal.Glyph {anchors.centerIn:parent;name:modelData;color:root.th.onContainer}}}}}
                Cap {text:"Menu · standard and vibrant";Layout.topMargin:8}
                Row {spacing:16
                    Repeater {model:[false,true]
                        Rectangle {required property bool modelData;width:170;height:mcol.implicitHeight+12;radius:20;color:modelData ? root.th.tertiaryContainer : root.th.level(3)
                            Column {id:mcol;x:6;y:6;width:parent.width-12;spacing:2
                                Repeater {model:[{g:"open_in_new",t:"Switch",s:true},{g:"minimize",t:"Minimize"},{g:"move_item",t:"Move to",sub:true},{g:"close",t:"Close"}]
                                    Rectangle {required property var modelData;required property int index;width:parent.width;height:44
                                        topLeftRadius:index===0 ? 14 : 4;topRightRadius:topLeftRadius;bottomLeftRadius:index===3 ? 14 : 4;bottomRightRadius:bottomLeftRadius
                                        color:modelData.s ? (parent.parent.parent.modelData ? root.th.tertiary : root.th.secondaryContainer) : "transparent"
                                        readonly property color ink:modelData.s ? (parent.parent.parent.modelData ? root.th.level(0) : root.th.onSecondaryContainer) : parent.parent.parent.modelData ? root.th.onTertiaryContainer : root.th.text
                                        Opal.Glyph {x:12;anchors.verticalCenter:parent.verticalCenter;name:modelData.g;font.pixelSize:20;color:parent.ink}
                                        Opal.MText {x:44;anchors.verticalCenter:parent.verticalCenter;text:modelData.t;role:"label";color:parent.ink}
                                        Opal.Glyph {visible:!!modelData.sub;anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;name:"chevron_right";font.pixelSize:18;color:parent.ink}
                                    }
                                }
                            }
                        }
                    }
                }
                Cap {text:"Segmented list items";Layout.topMargin:8}
                ColumnLayout {Layout.preferredWidth:340;spacing:2
                    Row2 {first:true;last:false;g:"wifi";t:"Wi-Fi";d:"Opal-5G";sw:1}
                    Row2 {first:false;last:false;current:true;g:"bluetooth";tint:1;t:"Bluetooth";d:"Current page";chevron:true}
                    Row2 {first:false;last:true;g:"devices";tint:2;t:"Opal Link";chevron:true}
                }
            }
        }
    }}

    // S8: the same window in each preset, side by side over the wallpaper.
    Component {id:s8;Item {
        Wall {}
        Repeater {model:[{t:"Glass",s:false,b:false,e:true,sh:false},{t:"Mixed",s:true,b:false,e:true,sh:false},{t:"Material",s:true,b:true,e:false,sh:true}]
            Item {
                id:col
                required property var modelData
                required property int index
                x:24+index*416;y:24;width:400;height:752
                Look {id:lkx;solidSheets:col.modelData.s;solidBars:col.modelData.b;edges:col.modelData.e;shadows:col.modelData.sh}
                Rectangle {visible:col.modelData.sh;x:0;y:58;width:parent.width;height:496;radius:32;color:root.th.alpha("#000000",.35)}
                Rectangle {x:0;y:48;width:parent.width;height:496;radius:32;color:lkx.sheet(root.th.level(1),.9);border.width:col.modelData.e ? 1 : 0;border.color:root.th.glassEdge
                    ColumnLayout {x:14;y:16;width:parent.width-28;spacing:2
                        Opal.MText {text:"Quick Settings";role:"title";Layout.leftMargin:6;Layout.bottomMargin:10}
                        Row2 {look:lkx;first:true;last:false;g:"wifi";t:"Wi-Fi";d:"Opal-5G";sw:1}
                        Row2 {look:lkx;first:false;last:false;g:"bluetooth";tint:1;t:"Bluetooth";d:"2 devices";sw:1}
                        Row2 {look:lkx;first:false;last:true;g:"dark_mode";tint:2;t:"Dark theme";sw:1}
                        Item {Layout.preferredHeight:12}
                        Opal.ExpressiveSlider {Layout.fillWidth:true;value:64;icon:"volume_up";iconAtHandle:true;compact:true;trackHeight:40;implicitHeight:56}
                        Opal.ExpressiveSlider {Layout.fillWidth:true;value:40;icon:"light_mode";iconAtHandle:true;compact:true;trackHeight:40;implicitHeight:56}
                        Item {Layout.preferredHeight:10}
                        Group2 {Layout.fillWidth:true;items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"speed",t:"Fast"}];sel:1}
                    }
                }
                Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;y:0;text:col.modelData.t;role:"headline";color:"white";style:Text.Outline;styleColor:root.th.alpha("#000000",.4)}
                // Shelf at the bottom.
                Rectangle {visible:col.modelData.sh;x:20;y:592;width:parent.width-40;height:56;radius:28;color:root.th.alpha("#000000",.35)}
                Rectangle {x:20;y:584;width:parent.width-40;height:56;radius:28;color:lkx.bar(root.th.glassIsland,.82);border.width:col.modelData.e ? 1 : 0;border.color:root.th.glassEdge
                    Row {anchors.centerIn:parent;spacing:14
                        Repeater {model:["apps","language","terminal","folder","music_note"];Opal.Glyph {required property string modelData;name:modelData;font.pixelSize:24}}}
                }
            }
        }
    }}
}
