import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Game mode round 3 (2026-10-21): Shelves is the base and the Spotlight lives inside it; widgets act. Static data; art, sizes, updates and instances are read from this machine.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property var g: {"cyber": {"t": "Cyberpunk 2077", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/6399de67cce3cecadce7900e03f6e09ff910a235/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/cf8cec802dc47d0f24b75f9eee135e96812e2652/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/812a216dbc8e6bc613cbbebcdb797ae707900a9c/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/37680a273aeee84646db37ed0423aafee948d845/logo.png", "p": "20 Oct"}, "dr": {"t": "DELTARUNE", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/7ccda5b1631d2e60cc756a3271e845dbb9168821/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/logo.png", "p": "14 Sep"}, "stel": {"t": "Stellaris", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/9fb67f416cc0043ce46d7cd3a45bbfc16232bf91/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/72e801b06fe78ee7885e831d23dfe19f480d5074/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/678809da179ad4e4ea35c506cbf291068c597145/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/5dfcd45fee7702e8d6610f93d55098762ab2c987/logo.png", "p": "7 Oct"}, "ksp": {"t": "Kerbal Space Program", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/220200/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/220200/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/220200/logo.png", "p": "20 Oct"}, "pp": {"t": "People Playground", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1118200/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1118200/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1118200/logo.png", "p": "21 Oct"}, "among": {"t": "Among Us", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/372646d565c6306fbbf078e0832468822f1cc9bb/logo.png", "p": "26 Sep"}, "powder": {"t": "The Powder Toy", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/logo.png", "p": "1 Sep"}, "uni": {"t": "Universe Sandbox", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/250f463d25378ede273ffe655f59733c079124b2/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/4dce237510cc3fd40337965f265097012ab5452d/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/545bdaaf055f7305911ba78ee3c534d8e815fb60/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/fa3bfc64b459695c09d97c9a3fba450981f912a3/logo.png", "p": "24 Aug"}, "vrc": {"t": "VRChat", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/logo.png", "p": "20 Aug"}, "plasma": {"t": "Plasma", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1409160/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1409160/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1409160/logo.png", "p": "13 Aug"}, "brain": {"t": "Brainrot Online", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/bc15bc3081d469a831899543dfe1b60854a135d8/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/da2ad91c5842c759abc6f70c0f867ab52aa5bc3a/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/885d8c73aebb37f8462babda27aad3d94dce35cb/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/bdea0a93b5dafabc3171e85db94fd10adda0f95b/logo.png", "p": "11 Aug"}, "ucn": {"t": "Ultimate Custom Night", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/871720/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/871720/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/871720/logo.png", "p": "10 Aug"}, "peak": {"t": "PEAK", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/480bd879ac737921bfa2529a6fea15961267ad21/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/d75184257596a3d2b402c58db0ef28844804e952/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/31bac6b2eccf09b368f5e95ce510bae2baf3cfcd/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/7df31d9d967539cfcb161cea0a69edca82f04cdb/logo.png", "p": "9 Aug"}, "ut": {"t": "Undertale", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/391540/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/391540/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/391540/logo.png", "p": ""}, "sd": {"t": "StellarDrive Demo", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/8129451c7a88ff1416e2074a839b60ec79b6e9f9/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/69ca708e32bfa92ddda69014b5f57aa9b5546b08/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/4db1ddae8d83694e7585ad791dbef2040dc3e43e/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/36d411d61ade4e0872da2d684c54836832410cff/logo.png", "p": "27 Sep"}, "gevr": {"t": "Google Earth VR", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/348250/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/348250/library_hero.jpg", "hd": "", "l": "", "p": ""}}
    readonly property var shots: {"stel": ["file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621034531_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035059_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035318_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035334_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035341_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621171030_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621171038_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621172402_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621172420_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260825231150_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260825231525_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260826211111_1.jpg"], "dr": ["file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260609213617_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260624154810_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260624204301_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260820011409_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260820012301_1.jpg"], "ksp": ["file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260803232049_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260803232050_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260812170904_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260812171747_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260819223745_1.jpg"]}
    readonly property var mc:({gen:true,t:"Minecraft",g:"deployed_code",sub:"4 instances",n:4})
    readonly property var deltatale:({gen:true,t:"DELTATALE",g:"sports_esports",sub:"Steam shortcut"})
    // Prism instances: name, game version, loader, mods, playtime, last launch.
    readonly property var instances:[
        {t:"1.21",v:"1.21.1",l:"Fabric",mods:21,time:"4 h 12 min",last:"16 Oct"},
        {t:"prism... BLOW",v:"1.21.1",l:"NeoForge",mods:36,time:"18 h 29 min",last:"11 Oct"},
        {t:"26.1.2",v:"26.1.2",l:"Fabric",mods:14,time:"11 h 45 min",last:"7 Oct"},
        {t:"JevCraft",v:"1.18.2",l:"Fabric",mods:7,time:"1 h 23 min",last:"20 Sep"}]

    Window {
        id:fixture
        width:1280;height:800;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"g3-01-home",view:home3},
            {name:"g3-02-home-row-focus",view:homeFocus3},
            {name:"g3-03-home-scrolled",view:scrolled3},
            {name:"g3-04-edit-widgets",view:edit3}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            loader.sourceComponent=null;loader.sourceComponent=cases[step].view;
            grab.restart();
        }
        Timer {id:grab;interval:2800;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        // OPAL_CASE=<name part> renders matching cases only.
        Component.onCompleted:{const only=Quickshell.env("OPAL_CASE");if(only)cases=cases.filter(c=>c.name.indexOf(only)>=0);Qt.callLater(run);}
    }

    // ---------- Shared pieces ----------

    // Rounded, cropped art. Canvas clipping works on the software renderer used for offscreen renders.
    component Art:Item {
        id:art
        property url source
        property real radius:0
        property size decodeSize
        property bool fit:false
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
                if(art.fit){const s=Math.min(w/iw,h/ih);ctx.drawImage(src,0,0,iw,ih,(w-iw*s)/2,(h-ih*s)/2,iw*s,ih*s);return;}
                const s=Math.max(w/iw,h/ih),sw=w/s,sh=h/s;
                ctx.drawImage(src,(iw-sw)/2,(ih-sh)/2,sw,sh,0,0,w,h);
            }
        }
    }

    // Assist chip: a read-only fact or a small action.
    component Pill:Rectangle {
        id:pl
        property string g:""
        property string t:""
        property bool tonal:false
        property real h:32
        property color fill:tonal ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.level(4),.86)
        height:h;width:plRow.implicitWidth+(g!=="" ? 24 : 28);radius:h/2;color:fill
        Row {id:plRow;anchors.centerIn:parent;spacing:6
            Opal.Glyph {visible:pl.g!=="";name:pl.g;font.pixelSize:pl.h>30 ? 18 : 16;color:pl.tonal ? Opal.Theme.onSecondaryContainer : Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:pl.t;role:"label";font.weight:Font.DemiBold;font.features:{"tnum":1};color:pl.tonal ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // One pill split into segments. Selection only changes colour, never shape.
    component Seg:Row {
        id:seg
        property var items:[]
        property int sel:0
        property real h:40
        property real segW:0
        property bool showCheck:false
        spacing:3
        Repeater {model:seg.items
            Rectangle {
                id:segItem
                required property var modelData
                required property int index
                readonly property bool chosen:index===seg.sel
                readonly property real outer:height/2
                height:seg.h
                width:seg.segW>0 ? seg.segW : segRow.implicitWidth+(seg.h>=44 ? 36 : 26)
                topLeftRadius:index===0 ? outer : 6;bottomLeftRadius:index===0 ? outer : 6
                topRightRadius:index===seg.items.length-1 ? outer : 6;bottomRightRadius:index===seg.items.length-1 ? outer : 6
                color:chosen ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.level(4),.88)
                Row {id:segRow;anchors.centerIn:parent;spacing:6
                    Opal.Glyph {visible:segItem.chosen&&seg.showCheck;name:"check";font.pixelSize:17;color:Opal.Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter}
                    Opal.Glyph {visible:!!segItem.modelData.g&&!(segItem.chosen&&seg.showCheck);name:segItem.modelData.g||"";font.pixelSize:18;color:segItem.chosen ? Opal.Theme.onSecondaryContainer : Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                    Opal.MText {visible:!!segItem.modelData.t;text:segItem.modelData.t||"";role:"label";font.pixelSize:seg.h>=44 ? 14 : 12;font.weight:segItem.chosen ? Font.Bold : Font.Medium;color:segItem.chosen ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}
                }
            }
        }
    }
    // Filled or tonal action with its controller button.
    component Action:Rectangle {
        id:ac
        property string b:"A"
        property string t:"Play"
        property string g:""
        property bool filled:true
        property real h:52
        readonly property color ink:filled ? Opal.Theme.onPrimary : Opal.Theme.onSecondaryContainer
        height:h;width:acRow.implicitWidth+(h>=48 ? 44 : 30);radius:h/2
        color:filled ? Opal.Theme.primary : Opal.Theme.secondaryContainer
        Row {id:acRow;anchors.centerIn:parent;spacing:ac.h>=48 ? 10 : 8
            Rectangle {visible:ac.b!=="";width:ac.b.length>1 ? 32 : 24;height:24;radius:ac.b.length>1 ? 8 : 12;color:Opal.Theme.alpha(ac.ink,.16);anchors.verticalCenter:parent.verticalCenter
                Opal.MText {anchors.centerIn:parent;text:ac.b;role:"labelS";font.weight:Font.Black;color:ac.ink}}
            Opal.Glyph {visible:ac.g!==""&&ac.b==="";name:ac.g;font.pixelSize:ac.h>=48 ? 22 : 18;color:ac.ink;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:ac.t;role:ac.h>=48 ? "title" : "titleS";color:ac.ink;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    component RoundIcon:Rectangle {
        property string g:"info"
        property real s:48
        property bool tonal:false
        width:s;height:s;radius:s/2
        color:tonal ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.level(4),.86)
        Opal.Glyph {anchors.centerIn:parent;name:parent.g;font.pixelSize:parent.s*.46;color:parent.tonal ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
    }
    // Clock, battery, controller and network in one island.
    component StatusIsland:Rectangle {
        height:40;width:siRow.implicitWidth+30;radius:20;color:Opal.Theme.alpha(Opal.Theme.level(3),.9)
        Row {id:siRow;anchors.centerIn:parent;spacing:14
            Row {spacing:4;anchors.verticalCenter:parent.verticalCenter
                Opal.Glyph {name:"stadia_controller";font.pixelSize:18;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
                Opal.MText {text:"64%";role:"label";font.weight:Font.Bold;anchors.verticalCenter:parent.verticalCenter}}
            Row {spacing:4;anchors.verticalCenter:parent.verticalCenter
                Opal.Glyph {name:"battery_5_bar";font.pixelSize:18;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                Opal.MText {text:"73%";role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}
            Opal.Glyph {name:"wifi";font.pixelSize:18;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:"21:33";role:"title";font.features:{"tnum":1};anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // A cover. Portrait by default; a wide cover is the focused card grown to landscape.
    component Cover:Item {
        id:cv
        property var gm:null
        property bool sel:false
        property bool wide:false
        property bool running:false
        property string kicker:""
        property real r:18
        readonly property bool gen:!!gm&&!!gm.gen
        readonly property int tint:gm ? Math.abs(gm.t.split("").reduce((h,ch)=>(h*31+ch.charCodeAt(0))|0,7))%3 : 0
        readonly property color genFill:[Opal.Theme.primaryContainer,Opal.Theme.secondaryContainer,Opal.Theme.tertiaryContainer][tint]
        readonly property color genInk:[Opal.Theme.onContainer,Opal.Theme.onSecondaryContainer,Opal.Theme.onTertiaryContainer][tint]
        Rectangle {anchors.fill:parent;radius:cv.r;color:cv.gen ? cv.genFill : Opal.Theme.level(3)}
        Art {anchors.fill:parent;radius:cv.r;visible:!cv.gen;source:cv.gm&&!cv.gen ? (cv.wide ? (cv.gm.hd||cv.gm.h) : cv.gm.c) : "";decodeSize:cv.wide ? Qt.size(920,430) : Qt.size(300,450)}
        Rectangle {visible:cv.wide&&!cv.gen;anchors.fill:parent;radius:cv.r
            gradient:Gradient {GradientStop {position:.3;color:"transparent"} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.8)}}}
        Column {visible:cv.wide&&!cv.gen;anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:16} spacing:2
            Opal.MText {visible:cv.kicker!=="";text:cv.kicker.toUpperCase();role:"labelS";font.letterSpacing:1.4;font.weight:Font.Bold;color:Opal.Theme.primary}
            Opal.MText {width:parent.width;text:cv.gm ? cv.gm.t : "";role:"title";font.pixelSize:20;color:"#ffffff"}
        }
        // Generated cover: glyph, title, and the group size.
        Opal.Glyph {visible:cv.gen;x:16;y:16;name:cv.gm&&cv.gm.g ? cv.gm.g : "sports_esports";font.pixelSize:Math.min(40,cv.width*.3);color:cv.genInk}
        Column {visible:cv.gen;anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:14} spacing:4
            Opal.MText {width:parent.width;text:cv.gm ? cv.gm.t : "";role:"title";font.pixelSize:Math.max(15,Math.min(20,cv.width/7));fontSizeMode:Text.HorizontalFit;minimumPixelSize:11;wrapMode:Text.WordWrap;maximumLineCount:2;color:cv.genInk}
            Opal.MText {width:parent.width;text:cv.gm&&cv.gm.sub ? cv.gm.sub : "";role:"labelS";color:Opal.Theme.alpha(cv.genInk,.75)}
        }
        // Stacked edge: a group shows the instances behind it.
        Rectangle {visible:cv.gen&&!!cv.gm.n;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:10;width:28;height:28;radius:14;color:Opal.Theme.alpha(cv.genInk,.16)
            Opal.MText {anchors.centerIn:parent;text:cv.gm&&cv.gm.n ? cv.gm.n : "";role:"label";font.weight:Font.Bold;color:cv.genInk}}
        Rectangle {visible:cv.running;anchors {top:parent.top;left:parent.left;margins:10} width:runText.implicitWidth+20;height:24;radius:12;color:Opal.Theme.primary
            Opal.MText {id:runText;anchors.centerIn:parent;text:"Running";role:"labelS";font.weight:Font.Bold;color:Opal.Theme.onPrimary}}
        Rectangle {visible:cv.sel;anchors.fill:parent;anchors.margins:-5;radius:cv.r+5;color:"transparent";border.width:3;border.color:Opal.Theme.primary}
    }
    component Logo:Image {
        fillMode:Image.PreserveAspectFit;horizontalAlignment:Image.AlignLeft;verticalAlignment:Image.AlignBottom
        sourceSize.width:900;smooth:true;mipmap:true
    }
    component SectionLabel:Row {
        property string t:""
        property string meta:""
        spacing:10
        Opal.MText {text:parent.t;role:"title";anchors.verticalCenter:parent.verticalCenter}
        Opal.MText {visible:parent.meta!=="";text:parent.meta;role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
    }
    // Focus ring around any rectangle-shaped child.
    component Ring:Rectangle {
        property real r:24
        anchors.fill:parent;anchors.margins:-4;radius:r+4;color:"transparent";border.width:3;border.color:Opal.Theme.primary
    }


    // ---------- Widgets ----------
    // Every widget is a card that does one job in place and grows into a sheet on X.
    component WCard:Rectangle {
        id:wc
        property string g:""
        property string label:""
        property string meta:""
        property bool focused:false
        property bool glass:false
        property bool editing:false
        default property alias content:body.data
        radius:28;color:glass ? Opal.Theme.alpha(Opal.Theme.level(2),.86) : Opal.Theme.level(2)
        border.width:editing&&!focused ? 2 : 0;border.color:Opal.Theme.alpha(Opal.Theme.primary,.4)
        Row {visible:wc.label!=="";x:18;y:16;spacing:8
            Opal.Glyph {name:wc.g;font.pixelSize:18;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:wc.label;role:"label";font.weight:Font.Bold;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}
        Opal.MText {visible:wc.meta!=="";anchors.right:parent.right;anchors.rightMargin:18;y:17;text:wc.meta;role:"labelS";color:Opal.Theme.muted}
        Item {id:body;anchors.fill:parent}
        Ring {visible:wc.focused;r:28}
        // Edit mode: a grip shows the card can move.
        Rectangle {visible:wc.editing;anchors.horizontalCenter:parent.horizontalCenter;y:-11;width:44;height:22;radius:11;color:wc.focused ? Opal.Theme.primary : Opal.Theme.level(5)
            Opal.Glyph {anchors.centerIn:parent;name:"drag_indicator";font.pixelSize:16;rotation:90;color:wc.focused ? Opal.Theme.onPrimary : Opal.Theme.text}}
    }
    // Music: Pixel-style, art behind, a squiggle that seeks.
    component MusicW:WCard {
        id:mw
        Art {anchors.fill:parent;radius:28;source:root.g.dr.h}
        Rectangle {anchors.fill:parent;radius:28;gradient:Gradient {GradientStop {position:0;color:Opal.Theme.alpha("#000000",.35)} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.82)}}}
        Pill {x:14;y:14;h:28;g:"music_note";t:"Chromium";fill:Opal.Theme.alpha("#000000",.45)}
        Column {x:18;anchors.bottom:ctl.top;anchors.bottomMargin:8;width:parent.width-36;spacing:0
            Opal.MText {width:parent.width;text:"Field of Hopes and Dreams";role:"titleS";color:"#ffffff"}
            Opal.MText {text:"Toby Fox";role:"labelS";color:Opal.Theme.alpha("#ffffff",.8)}}
        Row {id:ctl;x:14;anchors.bottom:parent.bottom;anchors.bottomMargin:14;spacing:10
            Opal.Glyph {name:"skip_previous";font.pixelSize:24;color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}
            Canvas {width:mw.width-150;height:20;anchors.verticalCenter:parent.verticalCenter
                onPaint:{const c=getContext("2d");c.reset();const split=width*.42;c.lineWidth=3;c.lineCap="round";
                    c.strokeStyle=String(Opal.Theme.primary);c.beginPath();for(let x=2;x<=split;x+=1){const y=10+3.5*Math.sin(x/4.5);if(x===2)c.moveTo(x,y);else c.lineTo(x,y);}c.stroke();
                    c.strokeStyle="rgba(255,255,255,0.35)";c.beginPath();c.moveTo(split+8,10);c.lineTo(width-2,10);c.stroke();
                    c.fillStyle=String(Opal.Theme.primary);c.fillRect(split-1.5,1,3,18);}}
            Opal.Glyph {name:"skip_next";font.pixelSize:24;color:"#ffffff";anchors.verticalCenter:parent.verticalCenter}
            Rectangle {width:44;height:44;radius:16;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter
                Opal.Glyph {anchors.centerIn:parent;name:"pause";font.pixelSize:24;color:Opal.Theme.onPrimary}}
        }
    }
    // Devices: battery rings, and a pair button that starts controller pairing.
    component DevicesW:WCard {
        g:"devices";label:"Devices"
        Grid {anchors.horizontalCenter:parent.horizontalCenter;y:50;columns:2;columnSpacing:26;rowSpacing:10
            Repeater {model:[{g:"stadia_controller",v:64,t:"64%"},{g:"headphones",v:80,t:"80%"},{g:"battery_5_bar",v:73,t:"73%"},{g:"add",v:-1,t:"Pair"}]
                Column {required property var modelData;spacing:4
                    Item {width:48;height:48;anchors.horizontalCenter:parent.horizontalCenter
                        Opal.ProgressRing {anchors.fill:parent;visible:modelData.v>=0;value:modelData.v/100;lineWidth:4}
                        Rectangle {anchors.fill:parent;visible:modelData.v<0;radius:24;color:Opal.Theme.tertiaryContainer}
                        Opal.Glyph {anchors.centerIn:parent;name:modelData.g;font.pixelSize:22;color:modelData.v<0 ? Opal.Theme.onTertiaryContainer : Opal.Theme.text}}
                    Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:modelData.t;role:"labelS";font.weight:Font.Bold;font.features:{"tnum":1}}
                }
            }
        }
    }
    // Updates: what Steam has queued, with one button.
    component UpdatesW:WCard {
        g:"download";label:"Updates"
        Action {anchors.right:parent.right;anchors.rightMargin:12;y:10;b:"";g:"download";t:"Update all";filled:false;h:34}
        Column {x:16;y:56;width:parent.width-32;spacing:10
            Repeater {model:[{a:root.g.uni,t:"Universe Sandbox",s:"627 KB"},{a:root.g.brain,t:"Brainrot Online",s:"6 KB"},{a:root.g.plasma,t:"Plasma",s:"Queued"}]
                Row {required property var modelData;width:parent.width;spacing:10
                    Art {width:30;height:30;radius:9;source:modelData.a.c}
                    Opal.MText {text:modelData.t;role:"label";font.weight:Font.DemiBold;width:parent.width-110;anchors.verticalCenter:parent.verticalCenter}
                    Opal.MText {text:modelData.s;role:"labelS";color:Opal.Theme.subtext;width:60;horizontalAlignment:Text.AlignRight;anchors.verticalCenter:parent.verticalCenter}}
            }
        }
    }
    // Storage: free space, what the games take, the biggest one.
    component StorageW:WCard {
        g:"hard_drive";label:"Storage";meta:"/home"
        Column {x:18;y:46;width:parent.width-36;spacing:10
            Row {spacing:6
                Opal.MText {text:"100 GB";role:"headline";font.features:{"tnum":1}}
                Opal.MText {text:"free of 462";role:"label";color:Opal.Theme.subtext;topPadding:12}}
            StorageBar {width:parent.width;h:14}
            Row {spacing:12
                Repeater {model:[{c:Opal.Theme.primary,t:"Games 113"},{c:Opal.Theme.alpha(Opal.Theme.text,.35),t:"Other 245"}]
                    Row {required property var modelData;spacing:5
                        Rectangle {width:9;height:9;radius:4.5;color:modelData.c;anchors.verticalCenter:parent.verticalCenter}
                        Opal.MText {text:modelData.t;role:"labelS";color:Opal.Theme.subtext}}}}
            Opal.MText {width:parent.width;text:"Biggest: Cyberpunk 2077 · 61.8 GB";role:"labelS";color:Opal.Theme.text}
        }
    }
    component StorageBar:Row {
        id:sb
        property real h:14
        property bool split:false
        spacing:3
        // GB: Cyberpunk 61.8, Stellaris 28.0, other games 23.0, everything else 245, free 100.
        readonly property var parts:split ? [{v:61.8,c:Opal.Theme.primary},{v:28,c:Opal.Theme.tertiary},{v:23,c:Opal.Theme.secondary},{v:245,c:Opal.Theme.alpha(Opal.Theme.text,.35)},{v:100,c:Opal.Theme.level(4)}]
            : [{v:112.8,c:Opal.Theme.primary},{v:245,c:Opal.Theme.alpha(Opal.Theme.text,.35)},{v:100,c:Opal.Theme.level(4)}]
        Repeater {model:sb.parts
            Rectangle {required property var modelData;required property int index
                width:(sb.width-sb.spacing*(sb.parts.length-1))*modelData.v/457.8;height:sb.h
                topLeftRadius:index===0 ? sb.h/2 : 3;bottomLeftRadius:index===0 ? sb.h/2 : 3
                topRightRadius:index===sb.parts.length-1 ? sb.h/2 : 3;bottomRightRadius:index===sb.parts.length-1 ? sb.h/2 : 3
                color:modelData.c}}
    }
    // Profile: the preset for the next game, one press.
    component ProfileW:WCard {
        g:"tune";label:"Next game";meta:"Applies on launch"
        Column {x:16;y:48;width:parent.width-32;spacing:10
            Seg {items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"rocket_launch",t:"Max"}];sel:1;h:40;segW:(parent.width-6)/3;showCheck:true}
            Opal.MText {text:"Per-game profiles win: Stellaris uses its own.";role:"labelS";color:Opal.Theme.subtext}
        }
    }
    // Captures: the newest screenshot.
    component CapturesW:WCard {
        Art {anchors.fill:parent;radius:28;source:root.shots.stel[root.shots.stel.length-1]}
        Rectangle {anchors.fill:parent;radius:28;gradient:Gradient {GradientStop {position:.3;color:"transparent"} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.8)}}}
        Column {x:16;anchors.bottom:parent.bottom;anchors.bottomMargin:14;spacing:1
            Opal.MText {text:"CAPTURES";role:"labelS";font.letterSpacing:1.4;font.weight:Font.Bold;color:Opal.Theme.primary}
            Opal.MText {text:"Stellaris · 12";role:"titleS";color:"#ffffff"}}
        Row {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:12;spacing:6
            RoundIcon {g:"photo_library";s:38}
            RoundIcon {g:"content_copy";s:38}}
    }
    // Minecraft shelf: each instance chip launches it; the cube opens the sheet.
    component MinecraftRow:Rectangle {
        property bool focusOn:false
        height:60;radius:30;color:Opal.Theme.level(2)
        Row {anchors.verticalCenter:parent.verticalCenter;x:8;spacing:8
            Rectangle {width:44;height:44;radius:22;color:Opal.Theme.tertiaryContainer
                Opal.Glyph {anchors.centerIn:parent;name:"deployed_code";font.pixelSize:24;color:Opal.Theme.onTertiaryContainer}
                Ring {visible:parent.parent.parent.focusOn;r:22}}
            Repeater {model:root.instances
                Pill {required property var modelData;required property int index;h:44;g:"play_arrow";t:modelData.t+"  ·  "+modelData.v;tonal:index===0}}
        }
    }
    component TopNav:Item {
        property int sel:0
        width:parent.width;height:40
        Row {x:48;spacing:10
            Rectangle {width:36;height:28;radius:8;color:Opal.Theme.alpha(Opal.Theme.level(4),.7);anchors.verticalCenter:parent.verticalCenter
                Opal.MText {anchors.centerIn:parent;text:"LB";role:"labelS";font.weight:Font.Bold;color:Opal.Theme.subtext}}
            Seg {items:[{g:"home",t:"Home"},{g:"grid_view",t:"Library"},{g:"apps",t:"Apps"},{g:"search"}];sel:parent.parent.sel;h:40}
            Rectangle {width:36;height:28;radius:8;color:Opal.Theme.alpha(Opal.Theme.level(4),.7);anchors.verticalCenter:parent.verticalCenter
                Opal.MText {anchors.centerIn:parent;text:"RB";role:"labelS";font.weight:Font.Bold;color:Opal.Theme.subtext}}
        }
        StatusIsland {anchors.right:parent.right;anchors.rightMargin:48}
    }


    // ---------- Round 3: Shelves is the base, the Spotlight lives inside it ----------
    component Rail:Rectangle {
        x:12;y:12;width:84;height:parent.height-24;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(1),.88)
        Column {anchors.horizontalCenter:parent.horizontalCenter;y:24;spacing:14
            Repeater {model:[{g:"home",t:"Home"},{g:"grid_view",t:"Library"},{g:"collections_bookmark",t:"Pinned"},{g:"photo_library",t:"Captures"},{g:"search",t:"Search"}]
                Item {required property var modelData;required property int index
                    width:72;height:58
                    Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:56;height:32;radius:16;color:index===0 ? Opal.Theme.secondaryContainer : "transparent"
                        Opal.Glyph {anchors.centerIn:parent;name:modelData.g;font.pixelSize:22;color:index===0 ? Opal.Theme.onSecondaryContainer : Opal.Theme.subtext}}
                    Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;y:37;text:modelData.t;role:"labelS";font.weight:index===0 ? Font.Bold : Font.Medium;color:index===0 ? Opal.Theme.text : Opal.Theme.subtext}
                }
            }
        }
        Opal.Glyph {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:24;name:"settings";font.pixelSize:22;color:Opal.Theme.subtext}
    }
    // Devices as one row of rings, to sit under Updates.
    component DevicesRowW:WCard {
        g:"devices";label:"Devices"
        Row {x:18;y:46;spacing:22
            Repeater {model:[{g:"stadia_controller",v:64,t:"64%"},{g:"headphones",v:80,t:"80%"},{g:"battery_5_bar",v:73,t:"73%"},{g:"add",v:-1,t:"Pair"}]
                Column {required property var modelData;spacing:3
                    Item {width:44;height:44;anchors.horizontalCenter:parent.horizontalCenter
                        Opal.ProgressRing {anchors.fill:parent;visible:modelData.v>=0;value:modelData.v/100;lineWidth:4}
                        Rectangle {anchors.fill:parent;visible:modelData.v<0;radius:22;color:Opal.Theme.tertiaryContainer}
                        Opal.Glyph {anchors.centerIn:parent;name:modelData.g;font.pixelSize:20;color:modelData.v<0 ? Opal.Theme.onTertiaryContainer : Opal.Theme.text}}
                    Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:modelData.t;role:"labelS";font.weight:Font.Bold;font.features:{"tnum":1}}
                }
            }
        }
    }
    component NextW:WCard {
        g:"tune";label:"Next game"
        Column {x:16;y:48;width:parent.width-32;spacing:10
            Seg {items:[{t:"Saver"},{t:"Balanced"},{t:"Max"}];sel:1;h:40;segW:(parent.width-6)/3}
            Opal.MText {width:parent.width;text:"Games with their own profile keep it";role:"labelS";color:Opal.Theme.subtext;wrapMode:Text.WordWrap}
        }
    }
    // The Spotlight inside Shelves: the focused game's art washes the top of the page, and the featured card follows focus.
    component ShelvesHome:Item {
        id:sh
        property var fg:root.g.ksp
        property string kicker:"CONTINUE"
        property var facts:[]
        property string profile:""
        property bool featureFocus:true
        property int wideIndex:-1
        property var rowGames:[]
        Rectangle {anchors.fill:parent;color:Opal.Theme.base}
        Art {id:wash;width:parent.width;height:520;source:sh.fg.h;opacity:.42}
        Rectangle {anchors.fill:wash;gradient:Gradient {GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,.35)} GradientStop {position:1;color:Opal.Theme.base}}}
        Rail {}
        Opal.MText {x:128;y:28;text:"Home";role:"displayS"}
        StatusIsland {anchors.right:parent.right;anchors.rightMargin:40;y:30}
        // Featured card, led by the logo.
        Item {
            x:128;y:92;width:716;height:308
            Art {anchors.fill:parent;radius:28;source:sh.fg.h}
            Rectangle {anchors.fill:parent;radius:28
                gradient:Gradient {orientation:Gradient.Horizontal
                    GradientStop {position:0;color:Opal.Theme.alpha("#000000",.8)}
                    GradientStop {position:.62;color:Opal.Theme.alpha("#000000",.18)}
                    GradientStop {position:1;color:"transparent"}}}
            Column {x:28;y:26;spacing:14
                Opal.MText {text:sh.kicker;role:"labelS";font.letterSpacing:1.6;font.weight:Font.Bold;color:Opal.Theme.primary}
                Logo {source:sh.fg.l;width:320;height:96}
                Row {spacing:8
                    Repeater {model:sh.facts
                        Pill {required property var modelData;g:modelData.g;t:modelData.t;fill:Opal.Theme.alpha("#000000",.45)}}
                }
                Row {spacing:8
                    Action {b:sh.featureFocus ? "A" : "";g:sh.featureFocus ? "" : "play_arrow";t:"Play";h:48}
                    Pill {h:48;g:"tune";t:sh.profile;tonal:true}
                    RoundIcon {g:"info";s:48;color:Opal.Theme.alpha("#000000",.45)}
                }
            }
            Ring {visible:sh.featureFocus;r:28}
        }
        // Right column: widgets that act.
        Column {x:860;y:92;spacing:12
            UpdatesW {width:380;height:176}
            DevicesRowW {width:380;height:120}
        }
        SectionLabel {x:128;y:420;t:"Jump back in";meta:"Recently played"}
        Row {x:128;y:452;spacing:14
            Repeater {model:sh.rowGames
                Cover {required property var modelData;required property int index
                    width:index===sh.wideIndex ? 372 : 117;height:176;wide:index===sh.wideIndex;sel:index===sh.wideIndex;gm:modelData;kicker:"Played "+(modelData.p||"")}}
        }
        SectionLabel {x:128;y:646;t:"Minecraft";meta:"Prism Launcher · 4 instances"}
        MinecraftRow {x:128;y:676;width:parent.width-168}
    }

    Component {id:home3
        Item {
            ShelvesHome {anchors.fill:parent
                fg:root.g.ksp;kicker:"CONTINUE";featureFocus:true;wideIndex:-1;profile:"Balanced · 60 FPS"
                facts:[{g:"schedule",t:"1,313 h"},{g:"history",t:"Played today"}]
                rowGames:[root.g.pp,root.g.cyber,root.mc,root.g.stel,root.g.sd,root.g.among,root.g.dr,root.g.powder]}
            Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:40;y:748;items:[{b:"A",t:"Play"},{b:"Y",t:"Profile"},{b:"→",t:"Widgets"},{b:"☰",t:"Quick Access"}]}
        }
    }
    Component {id:homeFocus3
        Item {
            ShelvesHome {anchors.fill:parent
                fg:root.g.stel;kicker:"PLAYED 7 OCT";featureFocus:false;wideIndex:3;profile:"Saver · 45 FPS"
                facts:[{g:"schedule",t:"195 h"},{g:"hard_drive",t:"28.0 GB"},{g:"photo_library",t:"12 captures"}]
                rowGames:[root.g.pp,root.g.cyber,root.mc,root.g.stel,root.g.sd,root.g.among,root.g.dr]}
            Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:40;y:748;items:[{b:"A",t:"Play Stellaris"},{b:"X",t:"Pin"},{b:"↑",t:"Featured"},{b:"☰",t:"Quick Access"}]}
        }
    }
    // Scrolled: the widget shelf, pinned, Minecraft, captures. The rail stays.
    component ShelvesScrolled:Item {
        id:ss
        property bool editing:false
        Rectangle {anchors.fill:parent;color:Opal.Theme.base}
        Art {width:parent.width;height:300;source:root.g.ksp.h;opacity:.22}
        Rectangle {width:parent.width;height:301;gradient:Gradient {GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,.4)} GradientStop {position:1;color:Opal.Theme.base}}}
        Rail {}
        Opal.MText {x:128;y:28;text:"Home";role:"displayS"}
        // The featured card has shrunk to a chip next to the title.
        Rectangle {x:270;y:30;height:44;width:contRow.implicitWidth+12;radius:22;color:Opal.Theme.level(3)
            Row {id:contRow;x:4;anchors.verticalCenter:parent.verticalCenter;spacing:10
                Art {width:36;height:36;radius:18;source:root.g.ksp.c}
                Opal.MText {text:"Kerbal Space Program";role:"label";font.weight:Font.Bold;anchors.verticalCenter:parent.verticalCenter}
                Action {b:"";g:"play_arrow";t:"Play";h:36}}}
        StatusIsland {anchors.right:parent.right;anchors.rightMargin:40;y:32}
        Row {x:128;y:96;spacing:16
            MusicW {width:280;height:200;editing:ss.editing}
            StorageW {width:280;height:200;editing:ss.editing}
            CapturesW {width:256;height:200;editing:ss.editing}
            NextW {width:248;height:200;editing:ss.editing}
        }
        SectionLabel {x:128;y:318;t:"Pinned";meta:"8"}
        GridLayout {x:128;y:350;columns:8;columnSpacing:14
            Repeater {model:[root.g.dr,root.deltatale,root.g.cyber,root.g.stel,root.g.pp,root.g.powder,root.g.uni,root.g.vrc]
                Cover {required property var modelData;required property int index;Layout.preferredWidth:122;Layout.preferredHeight:183;gm:modelData;r:16}}
        }
        SectionLabel {x:128;y:556;t:"Minecraft";meta:"Prism Launcher · 4 instances"}
        MinecraftRow {x:128;y:588;width:parent.width-168}
        SectionLabel {x:128;y:668;t:"Captures";meta:"Steam · 34"}
        Row {x:128;y:700;spacing:12
            Repeater {model:root.shots.stel.slice(-3).concat(root.shots.ksp.slice(2,4)).concat(root.shots.dr.slice(0,2))
                Art {required property var modelData;width:160;height:90;radius:16;source:modelData}}}
        Rectangle {width:parent.width;y:700;height:100;gradient:Gradient {GradientStop {position:0;color:"transparent"} GradientStop {position:.75;color:Opal.Theme.base}}}
    }
    Component {id:scrolled3
        Item {
            ShelvesScrolled {anchors.fill:parent}
            Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:40;y:748;items:[{b:"A",t:"Use"},{b:"X",t:"Open"},{b:"Hold ☰",t:"Edit"},{b:"☰",t:"Quick Access"}]}
        }
    }
    Component {id:edit3
        Item {
            ShelvesScrolled {anchors.fill:parent;editing:true}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.3)}
            Rectangle {
                x:108;width:parent.width-108-24;y:parent.height-336;height:312;radius:32
                color:Opal.Theme.level(2);border.width:1;border.color:Opal.Theme.outline
                Opal.MText {x:24;y:22;text:"Add a widget";role:"headline";font.pixelSize:22}
                Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:20;y:14;items:[{b:"A",t:"Add"},{b:"Y",t:"Arrange"},{b:"B",t:"Done"}]}
                Grid {x:24;y:68;columns:5;spacing:10
                    Repeater {model:[
                            {g:"music_note",t:"Music",d:"Play, skip, seek",on:true},
                            {g:"devices",t:"Devices",d:"Batteries, pair",on:true},
                            {g:"download",t:"Updates",d:"Steam queue",on:true},
                            {g:"hard_drive",t:"Storage",d:"Free space, uninstall",on:true},
                            {g:"photo_library",t:"Captures",d:"Newest screenshot",on:true},
                            {g:"tune",t:"Next game",d:"Saver, Balanced, Max",on:true},
                            {g:"deployed_code",t:"Minecraft",d:"Launch an instance"},
                            {g:"timer",t:"Play time",d:"This week, per game"},
                            {g:"toggle_on",t:"Toggles",d:"Wi-Fi, Bluetooth, DND"},
                            {g:"auto_awesome",t:"Ask Claude",d:"Hold Guide to talk"}]
                        Rectangle {required property var modelData;required property int index
                            width:(1148-48-40)/5;height:104;radius:24;color:index===7 ? Opal.Theme.level(4) : Opal.Theme.level(3)
                            Rectangle {x:14;y:14;width:38;height:38;radius:19;color:modelData.on ? Opal.Theme.secondaryContainer : Opal.Theme.alpha(Opal.Theme.primary,.16)
                                Opal.Glyph {anchors.centerIn:parent;name:modelData.on ? "check" : modelData.g;font.pixelSize:20;color:modelData.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.primary}}
                            Column {x:14;anchors.bottom:parent.bottom;anchors.bottomMargin:12;width:parent.width-28
                                Opal.MText {text:modelData.t;role:"titleS"}
                                Opal.MText {width:parent.width;text:modelData.d;role:"labelS";color:Opal.Theme.subtext}}
                            Ring {visible:index===7;r:24}
                        }
                    }
                }
            }
        }
    }
}
