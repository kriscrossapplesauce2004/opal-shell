import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Game mode round 1 (2026-10-21): eight directions for the game mode overhaul. Static data; art and screenshots come from the local Steam cache.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property var g: {"cyber": {"t": "Cyberpunk 2077", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/6399de67cce3cecadce7900e03f6e09ff910a235/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/cf8cec802dc47d0f24b75f9eee135e96812e2652/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/812a216dbc8e6bc613cbbebcdb797ae707900a9c/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1091500/37680a273aeee84646db37ed0423aafee948d845/logo.png", "p": "20 Oct"}, "dr": {"t": "DELTARUNE", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/7ccda5b1631d2e60cc756a3271e845dbb9168821/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/logo.png", "p": "14 Sep"}, "stel": {"t": "Stellaris", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/9fb67f416cc0043ce46d7cd3a45bbfc16232bf91/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/72e801b06fe78ee7885e831d23dfe19f480d5074/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/678809da179ad4e4ea35c506cbf291068c597145/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/281990/5dfcd45fee7702e8d6610f93d55098762ab2c987/logo.png", "p": "7 Oct"}, "ksp": {"t": "Kerbal Space Program", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/220200/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/220200/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/220200/logo.png", "p": "20 Oct"}, "pp": {"t": "People Playground", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1118200/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1118200/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1118200/logo.png", "p": "21 Oct"}, "among": {"t": "Among Us", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/945360/372646d565c6306fbbf078e0832468822f1cc9bb/logo.png", "p": "26 Sep"}, "powder": {"t": "The Powder Toy", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1148350/logo.png", "p": "1 Sep"}, "uni": {"t": "Universe Sandbox", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/250f463d25378ede273ffe655f59733c079124b2/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/4dce237510cc3fd40337965f265097012ab5452d/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/545bdaaf055f7305911ba78ee3c534d8e815fb60/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/230290/fa3bfc64b459695c09d97c9a3fba450981f912a3/logo.png", "p": "24 Aug"}, "vrc": {"t": "VRChat", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/438100/logo.png", "p": "20 Aug"}, "plasma": {"t": "Plasma", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1409160/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1409160/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/1409160/logo.png", "p": "13 Aug"}, "brain": {"t": "Brainrot Online", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/bc15bc3081d469a831899543dfe1b60854a135d8/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/da2ad91c5842c759abc6f70c0f867ab52aa5bc3a/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/885d8c73aebb37f8462babda27aad3d94dce35cb/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4233550/bdea0a93b5dafabc3171e85db94fd10adda0f95b/logo.png", "p": "11 Aug"}, "ucn": {"t": "Ultimate Custom Night", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/871720/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/871720/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/871720/logo.png", "p": "10 Aug"}, "peak": {"t": "PEAK", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/480bd879ac737921bfa2529a6fea15961267ad21/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/d75184257596a3d2b402c58db0ef28844804e952/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/31bac6b2eccf09b368f5e95ce510bae2baf3cfcd/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/3527290/7df31d9d967539cfcb161cea0a69edca82f04cdb/logo.png", "p": "9 Aug"}, "ut": {"t": "Undertale", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/391540/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/391540/library_hero.jpg", "hd": "", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/391540/logo.png", "p": ""}, "sd": {"t": "StellarDrive Demo", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/8129451c7a88ff1416e2074a839b60ec79b6e9f9/library_capsule.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/69ca708e32bfa92ddda69014b5f57aa9b5546b08/library_hero.jpg", "hd": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/4db1ddae8d83694e7585ad791dbef2040dc3e43e/library_header.jpg", "l": "file:///home/melissa/.local/share/Steam/appcache/librarycache/4689730/36d411d61ade4e0872da2d684c54836832410cff/logo.png", "p": "27 Sep"}, "gevr": {"t": "Google Earth VR", "c": "file:///home/melissa/.local/share/Steam/appcache/librarycache/348250/library_600x900.jpg", "h": "file:///home/melissa/.local/share/Steam/appcache/librarycache/348250/library_hero.jpg", "hd": "", "l": "", "p": ""}}
    readonly property var shots: {"stel": ["file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621034531_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035059_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035318_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035334_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621035341_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621171030_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621171038_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621172402_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260621172420_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260825231150_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260825231525_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/281990/screenshots/20260826211111_1.jpg"], "dr": ["file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260609213617_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260624154810_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260624204301_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260820011409_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/1671210/screenshots/20260820012301_1.jpg"], "ksp": ["file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260803232049_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260803232050_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260812170904_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260812171747_1.jpg", "file:///home/melissa/.local/share/Steam/userdata/1053023536/760/remote/220200/screenshots/20260819223745_1.jpg"]}
    readonly property string wall:"file:///home/melissa/Pictures/Wallpapers/default.png"
    // Art-less entries get generated covers. Names are cleaned (no .exe) and Minecraft instances are grouped.
    readonly property var mc:({gen:true,t:"Minecraft",g:"deployed_code",sub:"4 instances",n:4})
    readonly property var deltatale:({gen:true,t:"DELTATALE",g:"sports_esports",sub:"Steam shortcut"})
    readonly property var factorio:({gen:true,t:"Factorio",g:"factory",sub:"Steam shortcut"})

    Window {
        id:fixture
        width:1280;height:800;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"g1-01-spotlight-home",view:spotlight},
            {name:"g1-02-shelves-home",view:shelves},
            {name:"g1-03-library-peek",view:library},
            {name:"g1-04-game-page",view:gamePage},
            {name:"g1-05-quick-access",view:quickAccess},
            {name:"g1-06-quick-access-morph",view:quickMorph},
            {name:"g1-07-desktop-game-pill",view:desktopPill},
            {name:"g1-08-guide-glance",view:glance}
        ]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
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

    // ---------- 1. Spotlight home ----------
    // Full-bleed art for the focused game, its logo, one row of covers. The focused cover grows into a wide card.
    Component {id:spotlight
        Item {
            id:sp
            readonly property var fg:root.g.cyber
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Art {id:spHero;width:parent.width;height:parent.height*.8;radius:0;source:sp.fg.h;decodeSize:Qt.size(1920,1240)}
            Rectangle {anchors.fill:spHero
                gradient:Gradient {orientation:Gradient.Horizontal
                    GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,.9)}
                    GradientStop {position:.48;color:Opal.Theme.alpha(Opal.Theme.base,.3)}
                    GradientStop {position:1;color:Opal.Theme.alpha(Opal.Theme.base,0)}}}
            Rectangle {width:parent.width;y:spHero.height*.3;height:spHero.height*.7+1
                gradient:Gradient {GradientStop {position:0;color:"transparent"} GradientStop {position:1;color:Opal.Theme.base}}}
            // Top bar: one segmented nav pill and the status island.
            Row {x:48;y:28;spacing:10
                Rectangle {width:36;height:28;radius:8;color:Opal.Theme.alpha(Opal.Theme.level(4),.7);anchors.verticalCenter:parent.verticalCenter
                    Opal.MText {anchors.centerIn:parent;text:"LB";role:"labelS";font.weight:Font.Bold;color:Opal.Theme.subtext}}
                Seg {items:[{g:"home",t:"Home"},{g:"grid_view",t:"Library"},{g:"apps",t:"Apps"},{g:"search"}];sel:0;h:40}
                Rectangle {width:36;height:28;radius:8;color:Opal.Theme.alpha(Opal.Theme.level(4),.7);anchors.verticalCenter:parent.verticalCenter
                    Opal.MText {anchors.centerIn:parent;text:"RB";role:"labelS";font.weight:Font.Bold;color:Opal.Theme.subtext}}
            }
            StatusIsland {anchors.right:parent.right;anchors.rightMargin:48;y:28}
            Column {
                x:56;y:136;spacing:18
                Opal.MText {text:"CONTINUE PLAYING";role:"labelS";font.letterSpacing:1.6;font.weight:Font.Bold;color:Opal.Theme.primary}
                Logo {source:sp.fg.l;width:420;height:140}
                Row {spacing:8
                    Pill {g:"history";t:"Played yesterday"}
                    Pill {g:"schedule";t:"76 h 54 min"}
                    Pill {g:"tune";t:"Profile · 60 FPS · Balanced";tonal:true}
                }
                Row {spacing:10
                    Action {b:"A";t:"Play";g:"play_arrow"}
                    RoundIcon {g:"info";s:52}
                    RoundIcon {g:"keep";s:52}
                }
            }
            SectionLabel {x:56;y:496;t:"Jump back in";meta:"Recently played"}
            Item {
                x:56;y:534;width:parent.width-56;height:200;clip:false
                Row {spacing:16
                    Cover {width:400;height:188;wide:true;sel:true;gm:root.g.cyber;kicker:"Last played yesterday"}
                    Cover {width:125;height:188;gm:root.g.pp}
                    Cover {width:125;height:188;gm:root.g.ksp}
                    Cover {width:125;height:188;gm:root.mc}
                    Cover {width:125;height:188;gm:root.g.stel}
                    Cover {width:125;height:188;gm:root.g.sd}
                    Cover {width:125;height:188;gm:root.g.among}
                }
            }
            Opal.MText {x:56;y:758;text:"20 games";role:"label";color:Opal.Theme.subtext}
            Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:48;y:744
                items:[{b:"A",t:"Play"},{b:"X",t:"Pin"},{b:"Y",t:"Search"},{b:"LB RB",t:"Sections"},{b:"☰",t:"Quick Access"}]}
        }
    }

    // ---------- 2. Shelves home ----------
    // Navigation rail, a featured card plus two local-data cards, then rows. Minecraft is one row of instance chips.
    Component {id:shelves
        Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            // Rail.
            Rectangle {
                x:12;y:12;width:84;height:parent.height-24;radius:28;color:Opal.Theme.level(1)
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
            Opal.MText {x:128;y:30;text:"Home";role:"displayS"}
            StatusIsland {anchors.right:parent.right;anchors.rightMargin:40;y:30}
            // Featured card.
            Item {
                id:feature
                x:128;y:92;width:716;height:296
                Art {anchors.fill:parent;radius:28;source:root.g.ksp.h;decodeSize:Qt.size(1432,592)}
                Rectangle {anchors.fill:parent;radius:28
                    gradient:Gradient {orientation:Gradient.Horizontal
                        GradientStop {position:0;color:Opal.Theme.alpha("#000000",.78)}
                        GradientStop {position:.6;color:Opal.Theme.alpha("#000000",.2)}
                        GradientStop {position:1;color:"transparent"}}}
                Column {x:28;y:26;spacing:14
                    Opal.MText {text:"CONTINUE";role:"labelS";font.letterSpacing:1.6;font.weight:Font.Bold;color:Opal.Theme.primary}
                    Logo {source:root.g.ksp.l;width:300;height:100}
                    Row {spacing:8
                        Pill {g:"schedule";t:"1,313 h";fill:Opal.Theme.alpha("#000000",.42)}
                        Pill {g:"history";t:"Played today";fill:Opal.Theme.alpha("#000000",.42)}
                    }
                    Action {b:"A";t:"Play";g:"play_arrow";h:48}
                }
                Ring {r:28}
            }
            // Local-data cards: new screenshots and something not played yet.
            Column {
                x:860;y:92;spacing:12
                Item {width:380;height:142
                    Art {anchors.fill:parent;radius:24;source:root.shots.stel[root.shots.stel.length-1];decodeSize:Qt.size(760,284)}
                    Rectangle {anchors.fill:parent;radius:24;gradient:Gradient {GradientStop {position:.25;color:"transparent"} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.8)}}}
                    Column {anchors {left:parent.left;bottom:parent.bottom;margins:16} spacing:2
                        Opal.MText {text:"CAPTURES";role:"labelS";font.letterSpacing:1.4;font.weight:Font.Bold;color:Opal.Theme.primary}
                        Opal.MText {text:"Stellaris · 12 screenshots";role:"titleS";color:"#ffffff"}}
                }
                Item {width:380;height:142
                    Art {anchors.fill:parent;radius:24;source:root.g.ut.h;decodeSize:Qt.size(760,284)}
                    Rectangle {anchors.fill:parent;radius:24;gradient:Gradient {GradientStop {position:.25;color:"transparent"} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.8)}}}
                    Column {anchors {left:parent.left;bottom:parent.bottom;margins:16} spacing:2
                        Opal.MText {text:"NOT PLAYED YET";role:"labelS";font.letterSpacing:1.4;font.weight:Font.Bold;color:Opal.Theme.primary}
                        Opal.MText {text:"Undertale";role:"titleS";color:"#ffffff"}}
                }
            }
            SectionLabel {x:128;y:410;t:"Pinned";meta:"8"}
            GridLayout {x:128;y:444;columns:8;columnSpacing:14
                Repeater {model:[root.g.dr,root.deltatale,root.g.cyber,root.g.stel,root.g.pp,root.g.powder,root.g.uni,root.g.vrc]
                    Cover {required property var modelData;required property int index;Layout.preferredWidth:122;Layout.preferredHeight:183;gm:modelData;r:16}}
            }
            SectionLabel {x:128;y:642;t:"Minecraft";meta:"Prism Launcher · 4 instances"}
            Rectangle {
                x:128;y:672;width:parent.width-168;height:60;radius:30;color:Opal.Theme.level(2)
                Row {anchors.verticalCenter:parent.verticalCenter;x:10;spacing:8
                    Rectangle {width:44;height:44;radius:22;color:Opal.Theme.tertiaryContainer
                        Opal.Glyph {anchors.centerIn:parent;name:"deployed_code";font.pixelSize:24;color:Opal.Theme.onTertiaryContainer}}
                    Pill {h:44;g:"play_arrow";t:"JevCraft — Survival AI";tonal:true}
                    Pill {h:44;g:"play_arrow";t:"1.21"}
                    Pill {h:44;g:"play_arrow";t:"26.1.2"}
                    Pill {h:44;g:"play_arrow";t:"prism... BLOW"}
                    Pill {h:44;g:"add";t:"New instance"}
                }
            }
            Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:40;y:742
                items:[{b:"A",t:"Play"},{b:"X",t:"Pin"},{b:"Y",t:"Search"},{b:"☰",t:"Quick Access"}]}
        }
    }

    // ---------- 3. Library grid with a peek pane ----------
    Component {id:library
        Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Row {x:48;y:28;spacing:16
                Opal.MText {text:"Library";role:"displayS";anchors.verticalCenter:parent.verticalCenter}
                Rectangle {width:300;height:44;radius:22;color:Opal.Theme.level(3);anchors.verticalCenter:parent.verticalCenter
                    Row {anchors.verticalCenter:parent.verticalCenter;x:16;spacing:10
                        Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                        Opal.MText {text:"Search games, instances, apps";role:"body";color:Opal.Theme.muted;anchors.verticalCenter:parent.verticalCenter}}
                    Rectangle {anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;width:24;height:24;radius:12;color:Opal.Theme.secondaryContainer
                        Opal.MText {anchors.centerIn:parent;text:"Y";role:"labelS";font.weight:Font.Black;color:Opal.Theme.onSecondaryContainer}}
                }
            }
            StatusIsland {anchors.right:parent.right;anchors.rightMargin:48;y:30}
            Row {x:48;y:94;spacing:8
                Pill {g:"check";t:"All  20";tonal:true;h:36}
                Pill {t:"Steam  16";h:36}
                Pill {t:"Minecraft  4";h:36}
                Pill {t:"Shortcuts  3";h:36}
                Pill {t:"Not played  2";h:36}
                Pill {t:"Installed size";g:"hard_drive";h:36}
            }
            Pill {anchors.right:peek.right;y:94;h:36;g:"sort";t:"Recently played  ▾"}
            GridLayout {
                x:52;y:156;columns:5;columnSpacing:18;rowSpacing:18
                Repeater {model:[root.g.pp,root.g.ksp,root.g.cyber,root.mc,root.g.stel,root.g.sd,root.g.among,root.g.dr,root.g.powder,root.g.uni,root.g.vrc,root.factorio,root.g.plasma,root.g.brain,root.g.ucn]
                    Cover {required property var modelData;required property int index;Layout.preferredWidth:134;Layout.preferredHeight:201;gm:modelData;sel:index===4;r:16}}
            }
            Rectangle {anchors.left:parent.left;anchors.right:peek.left;y:parent.height-130;height:130
                gradient:Gradient {GradientStop {position:0;color:"transparent"} GradientStop {position:.55;color:Opal.Theme.base}}}
            // Peek: the focused game without leaving the grid.
            Rectangle {
                id:peek
                x:840;y:152;width:392;height:572;radius:28;color:Opal.Theme.level(2)
                Art {id:peekHero;width:parent.width;height:170;radius:28;source:root.g.stel.h;decodeSize:Qt.size(784,340)}
                Rectangle {anchors.fill:peekHero;radius:28;gradient:Gradient {GradientStop {position:.3;color:"transparent"} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.7)}}}
                Logo {x:20;y:96;width:220;height:60;source:root.g.stel.l}
                Column {
                    x:20;y:186;width:parent.width-40;spacing:14
                    Flow {width:parent.width;spacing:8
                        Pill {g:"schedule";t:"195 h"}
                        Pill {g:"history";t:"7 Oct"}
                        Pill {g:"hard_drive";t:"30.1 GB"}
                    }
                    Row {spacing:10
                        Action {b:"A";t:"Play";g:"play_arrow";h:48}
                        Action {b:"LT";t:"Details";filled:false;h:48}
                    }
                    SectionLabel {t:"Screenshots";meta:"12"}
                    Grid {columns:2;spacing:8
                        Repeater {model:root.shots.stel.slice(-4)
                            Art {required property var modelData;width:172;height:97;radius:14;source:modelData;decodeSize:Qt.size(344,194)}}
                    }
                }
            }
            Opal.ControllerHints {anchors.left:parent.left;anchors.leftMargin:48;y:744
                items:[{b:"A",t:"Play"},{b:"LB RB",t:"Filter"},{b:"RT",t:"Sort"},{b:"LT",t:"Details"},{b:"☰",t:"Quick Access"}]}
        }
    }

    // ---------- 4. Game page ----------
    Component {id:gamePage
        Item {
            id:gp
            readonly property var fg:root.g.dr
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Art {id:gpHero;width:parent.width;height:440;radius:0;source:gp.fg.h;decodeSize:Qt.size(1920,1240)}
            Rectangle {width:parent.width;y:120;height:321;gradient:Gradient {GradientStop {position:0;color:"transparent"} GradientStop {position:1;color:Opal.Theme.base}}}
            Rectangle {anchors.fill:gpHero;gradient:Gradient {orientation:Gradient.Horizontal;GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,.65)} GradientStop {position:.55;color:"transparent"}}}
            Row {x:48;y:28;spacing:8
                Action {b:"B";t:"Library";g:"arrow_back";filled:false;h:40}
            }
            StatusIsland {anchors.right:parent.right;anchors.rightMargin:48;y:28}
            Logo {x:56;y:196;width:520;height:150;source:gp.fg.l}
            Row {x:56;y:372;spacing:10
                Action {b:"A";t:"Play";g:"play_arrow";h:56}
                Rectangle {height:56;width:profRow.implicitWidth+40;radius:28;color:Opal.Theme.secondaryContainer
                    Row {id:profRow;anchors.centerIn:parent;spacing:10
                        Opal.Glyph {name:"tune";font.pixelSize:22;color:Opal.Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter}
                        Column {anchors.verticalCenter:parent.verticalCenter
                            Opal.MText {text:"Battery saver";role:"titleS";color:Opal.Theme.onSecondaryContainer}
                            Opal.MText {text:"40 FPS · 8 W · this game only";role:"labelS";color:Opal.Theme.alpha(Opal.Theme.onSecondaryContainer,.8)}}
                        Opal.Glyph {name:"expand_more";font.pixelSize:20;color:Opal.Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter}}
                    Ring {r:28}
                }
                RoundIcon {g:"keep";s:56}
                RoundIcon {g:"folder_open";s:56}
                RoundIcon {g:"more_horiz";s:56}
            }
            Row {x:56;y:452;spacing:10
                Repeater {model:[{g:"schedule",l:"Playtime",v:"95 h 51 min"},{g:"history",l:"Last played",v:"14 Sep 2026"},{g:"hard_drive",l:"Size",v:"890 MB"},{g:"cloud_done",l:"Steam Cloud",v:"Synced"}]
                    Rectangle {required property var modelData;width:220;height:62;radius:20;color:Opal.Theme.level(2)
                        Row {anchors.verticalCenter:parent.verticalCenter;x:14;spacing:12
                            Rectangle {width:36;height:36;radius:18;color:Opal.Theme.alpha(Opal.Theme.primary,.16);anchors.verticalCenter:parent.verticalCenter
                                Opal.Glyph {anchors.centerIn:parent;name:modelData.g;font.pixelSize:19;color:Opal.Theme.primary}}
                            Column {anchors.verticalCenter:parent.verticalCenter
                                Opal.MText {text:modelData.l;role:"labelS";color:Opal.Theme.subtext}
                                Opal.MText {text:modelData.v;role:"titleS";font.features:{"tnum":1}}}
                        }
                    }
                }
            }
            SectionLabel {x:56;y:540;t:"Your screenshots";meta:"5 · saved by Steam"}
            Row {x:56;y:574;spacing:12
                Repeater {model:root.shots.dr.slice(0,5)
                    Art {required property var modelData;width:224;height:126;radius:18;source:modelData;decodeSize:Qt.size(448,252)}}
            }
            Opal.ControllerHints {anchors.right:parent.right;anchors.rightMargin:48;y:744
                items:[{b:"A",t:"Play"},{b:"X",t:"Pin"},{b:"Y",t:"Profile"},{b:"B",t:"Back"}]}
        }
    }

    // ---------- 5. Quick Access, one scroll ----------
    component GameBackdrop:Item {
        property url src:root.shots.ksp[4]
        property real dim:.3
        anchors.fill:parent
        Art {anchors.fill:parent;radius:0;source:parent.src;decodeSize:Qt.size(1280,800)}
        Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",parent.dim)}
    }
    component NowPlaying:Item {
        height:128
        Art {anchors.fill:parent;radius:24;source:root.g.ksp.h;decodeSize:Qt.size(816,256)}
        Rectangle {anchors.fill:parent;radius:24;gradient:Gradient {orientation:Gradient.Horizontal;GradientStop {position:0;color:Opal.Theme.alpha("#000000",.82)} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.25)}}}
        Logo {x:16;y:14;width:170;height:52;source:root.g.ksp.l}
        Column {x:16;anchors.bottom:parent.bottom;anchors.bottomMargin:14;spacing:1
            Opal.MText {text:"Playing for 1 h 12 min";role:"titleS";color:"#ffffff"}
            Opal.MText {text:"Steam · native Linux";role:"labelS";color:Opal.Theme.alpha("#ffffff",.75)}}
        Row {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:12;spacing:8
            RoundIcon {g:"close";s:40}
            Action {b:"";t:"Resume";g:"play_arrow";h:40}
        }
    }
    component Readouts:Row {
        spacing:6
        Pill {h:30;g:"stadia_controller";t:"64%"}
        Pill {h:30;g:"battery_5_bar";t:"73% · 2 h 10 min"}
        Pill {h:30;g:"thermostat";t:"68°"}
        Pill {h:30;g:"bolt";t:"14 W"}
    }
    component Sheet:Rectangle {
        x:parent.width-width-12;y:12;width:440;height:parent.height-24;radius:32
        color:Opal.Theme.alpha(Opal.Theme.level(2),.97);border.width:1;border.color:Opal.Theme.outline
    }
    Component {id:quickAccess
        Item {
            GameBackdrop {}
            Sheet {
                Column {
                    x:16;y:16;width:parent.width-32;spacing:12
                    NowPlaying {width:parent.width}
                    Readouts {}
                    Item {width:1;height:2}
                    SectionLabel {t:"Performance";meta:"Saved for this game"}
                    Seg {items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"rocket_launch",t:"Max"},{g:"tune",t:"Custom"}];sel:1;h:48;segW:(parent.width-9)/4;showCheck:true}
                    Grid {columns:2;spacing:8
                        Repeater {model:[
                                {g:"speed",t:"Frame limit",s:"60 FPS",on:true},
                                {g:"monitoring",t:"Overlay",s:"Compact",on:true},
                                {g:"do_not_disturb_on",t:"Do not disturb",s:"Until you quit",on:true},
                                {g:"timer",t:"Quiet session",s:"No sleep",on:false},
                                {g:"wifi",t:"Wi-Fi",s:"Home-5G",on:true},
                                {g:"bluetooth",t:"Bluetooth",s:"DualSense",on:true},
                                {g:"screenshot_monitor",t:"Screenshot",s:"A in this menu",on:false},
                                {g:"replay_30",t:"Save last 30 s",s:"Replay buffer",on:false}]
                            Item {required property var modelData;required property int index;width:200;height:60
                                Opal.ShadeTile {anchors.fill:parent;dense:true;icon:modelData.g;title:modelData.t;subtitle:modelData.s;active:modelData.on}
                                Ring {visible:index===0;r:22}
                            }
                        }
                    }
                    Opal.ExpressiveSlider {width:parent.width;icon:"light_mode";value:72}
                    Opal.ExpressiveSlider {width:parent.width;icon:"volume_up";value:45}
                    Rectangle {width:parent.width;height:48;radius:24;color:Opal.Theme.level(3)
                        Row {anchors.verticalCenter:parent.verticalCenter;x:14;spacing:10
                            Opal.Glyph {name:"notifications";font.pixelSize:20;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
                            Opal.MText {text:"3 notifications · Discord, Steam";role:"titleS";anchors.verticalCenter:parent.verticalCenter}}
                        Opal.Glyph {anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;name:"chevron_right";font.pixelSize:20;color:Opal.Theme.subtext}
                    }
                }
            }
            Opal.ControllerHints {x:40;y:740;items:[{b:"A",t:"Toggle"},{b:"X",t:"Open"},{b:"B",t:"Back to game"},{b:"Guide",t:"Close"}]}
        }
    }

    // ---------- 6. Quick Access: the Custom tile morphed into its sheet ----------
    component Steps:Item {
        id:st
        property var stops:[]
        property int sel:0
        height:58
        readonly property real gap:(width-24)/(stops.length-1)
        Rectangle {x:12;y:12;width:st.width-24;height:14;radius:7;color:Opal.Theme.alpha(Opal.Theme.tile,.95)}
        Rectangle {x:12;y:12;width:st.gap*st.sel-6;height:14;radius:7;color:Opal.Theme.primary}
        Repeater {model:st.stops
            Item {required property var modelData;required property int index
                x:12+index*st.gap;y:0
                Rectangle {visible:index!==st.sel;x:-2.5;y:16.5;width:5;height:5;radius:2.5;color:index<st.sel ? Opal.Theme.onPrimary : Opal.Theme.subtext}
                Opal.MText {x:-width/2;y:36;text:modelData;role:"label";font.weight:index===st.sel ? Font.Bold : Font.Medium;color:index===st.sel ? Opal.Theme.primary : Opal.Theme.subtext}
            }
        }
        Rectangle {x:12+st.gap*st.sel-2;y:2;width:4;height:34;radius:2;color:Opal.Theme.primary}
    }
    component SettingRow:Column {
        property string g:""
        property string t:""
        property string v:""
        spacing:10
        Row {width:parent.width;spacing:10
            Opal.Glyph {name:parent.parent.g;font.pixelSize:20;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:parent.parent.t;role:"titleS";anchors.verticalCenter:parent.verticalCenter;width:parent.width-90}
            Opal.MText {text:parent.parent.v;role:"title";font.features:{"tnum":1};color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter;width:60;horizontalAlignment:Text.AlignRight}
        }
    }
    Component {id:quickMorph
        Item {
            GameBackdrop {}
            Sheet {
                Column {
                    x:16;y:16;width:parent.width-32;spacing:12
                    // Now playing has shrunk to a row.
                    Rectangle {width:parent.width;height:56;radius:28;color:Opal.Theme.level(3)
                        Art {x:8;y:8;width:40;height:40;radius:20;source:root.g.ksp.c;decodeSize:Qt.size(80,120)}
                        Column {x:60;anchors.verticalCenter:parent.verticalCenter
                            Opal.MText {text:"Kerbal Space Program";role:"titleS"}
                            Opal.MText {text:"1 h 12 min · 58 FPS";role:"labelS";color:Opal.Theme.subtext}}
                        Row {anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;spacing:6
                            Pill {h:30;g:"thermostat";t:"68°"}
                            Pill {h:30;g:"bolt";t:"14 W"}}
                    }
                    // The Custom segment grew into this card.
                    Rectangle {
                        width:parent.width;height:520;radius:28;color:Opal.Theme.level(3)
                        Column {x:18;y:18;width:parent.width-36;spacing:18
                            Row {spacing:10
                                Rectangle {width:36;height:36;radius:18;color:Opal.Theme.alpha(Opal.Theme.level(5),.9)
                                    Opal.Glyph {anchors.centerIn:parent;name:"arrow_back";font.pixelSize:20}}
                                Opal.MText {text:"Custom profile";role:"headline";font.pixelSize:22;anchors.verticalCenter:parent.verticalCenter}
                            }
                            SettingRow {width:parent.width;g:"speed";t:"Frame limit";v:"60"}
                            Item {width:parent.width;height:58
                                Steps {width:parent.width;stops:["Off","30","40","45","60","72","90","120"];sel:4}
                                Ring {r:16;anchors.margins:-8}
                            }
                            SettingRow {width:parent.width;g:"bolt";t:"Power limit";v:"14 W"}
                            Opal.ExpressiveSlider {width:parent.width;icon:"";showIcon:false;value:48;trackHeight:28}
                            SettingRow {width:parent.width;g:"memory";t:"GPU clock";v:""}
                            Seg {items:[{t:"Auto"},{t:"Low"},{t:"High"}];sel:0;h:40;segW:(parent.width-6)/3;showCheck:true}
                            SettingRow {width:parent.width;g:"monitoring";t:"Overlay";v:""}
                            Seg {items:[{t:"Off"},{t:"FPS"},{t:"Compact"},{t:"Full"}];sel:2;h:40;segW:(parent.width-9)/4;showCheck:true}
                        }
                    }
                    Rectangle {width:parent.width;height:56;radius:28;color:Opal.Theme.level(3)
                        Column {x:20;anchors.verticalCenter:parent.verticalCenter
                            Opal.MText {text:"Only for Kerbal Space Program";role:"titleS"}
                            Opal.MText {text:"Back to Balanced when you quit";role:"labelS";color:Opal.Theme.subtext}}
                        Rectangle {anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;width:52;height:32;radius:16;color:Opal.Theme.primary
                            Rectangle {x:24;y:4;width:24;height:24;radius:12;color:Opal.Theme.onPrimary
                                Opal.Glyph {anchors.centerIn:parent;name:"check";font.pixelSize:16;color:Opal.Theme.primary}}}
                    }
                    // The tile grid has shrunk to chips.
                    Row {spacing:8
                        Repeater {model:["do_not_disturb_on","timer","wifi","bluetooth","screenshot_monitor","replay_30","light_mode"]
                            RoundIcon {required property var modelData;required property int index;g:modelData;s:46;tonal:index<1||index===2||index===3}}
                    }
                }
            }
            Opal.ControllerHints {x:40;y:740;items:[{b:"← →",t:"Frame limit"},{b:"A",t:"Done"},{b:"B",t:"Back"}]}
        }
    }

    // ---------- 7. Desktop: the game gets a Shelf pill ----------
    Component {id:desktopPill
        Item {
            Art {anchors.fill:parent;radius:0;source:root.wall;decodeSize:Qt.size(1280,800)}
            // The game, tiled as a normal window.
            Rectangle {x:10;y:10;width:parent.width-20;height:parent.height-84;radius:14;color:"#000000";border.width:2;border.color:Opal.Theme.alpha(Opal.Theme.primary,.55)
                Art {anchors.fill:parent;anchors.margins:2;radius:12;fit:true;source:root.shots.dr[3];decodeSize:Qt.size(1280,720)}}
            // Shelf.
            Rectangle {x:12;y:parent.height-62;width:shelfLeft.implicitWidth+16;height:52;radius:26;color:Opal.Theme.alpha(Opal.Theme.glassIsland,.96)
                Row {id:shelfLeft;x:6;anchors.verticalCenter:parent.verticalCenter;spacing:10
                    Rectangle {width:42;height:42;radius:21;color:Opal.Theme.primaryContainer
                        Opal.Glyph {anchors.centerIn:parent;name:"apps";font.pixelSize:22;color:Opal.Theme.onContainer}}
                    Rectangle {width:180;height:42;radius:21;color:Opal.Theme.alpha(Opal.Theme.base,.6)
                        Row {x:14;anchors.verticalCenter:parent.verticalCenter;spacing:8
                            Opal.Glyph {name:"search";font.pixelSize:18;color:Opal.Theme.subtext}
                            Opal.MText {text:"Search";role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                    Repeater {model:[{g:"language",t:"Firefox"},{g:"folder",t:""},{g:"terminal",t:"kitty"}]
                        Row {required property var modelData;spacing:8;anchors.verticalCenter:parent.verticalCenter;leftPadding:6;rightPadding:6
                            Opal.Glyph {name:modelData.g;font.pixelSize:20;color:Opal.Theme.primary}
                            Opal.MText {visible:modelData.t!=="";text:modelData.t;role:"label";anchors.verticalCenter:parent.verticalCenter}}}
                }
            }
            Row {anchors.right:parent.right;anchors.rightMargin:12;y:parent.height-62;spacing:8
                // Game pill: the running game as an activity.
                Rectangle {id:gamePill;width:gpRow.implicitWidth+20;height:52;radius:26;color:Opal.Theme.alpha(Opal.Theme.glassIsland,.96);border.width:2;border.color:Opal.Theme.primary
                    Row {id:gpRow;x:6;anchors.verticalCenter:parent.verticalCenter;spacing:10
                        Art {width:40;height:40;radius:20;source:root.g.dr.h;decodeSize:Qt.size(80,120)}
                        Opal.MText {text:"DELTARUNE";role:"label";font.weight:Font.Bold;anchors.verticalCenter:parent.verticalCenter}
                        Opal.MText {text:"0:38";role:"label";color:Opal.Theme.subtext;font.features:{"tnum":1};anchors.verticalCenter:parent.verticalCenter}
                        Rectangle {width:fpsT.implicitWidth+16;height:24;radius:12;color:Opal.Theme.secondaryContainer;anchors.verticalCenter:parent.verticalCenter
                            Opal.MText {id:fpsT;anchors.centerIn:parent;text:"30 FPS";role:"labelS";font.weight:Font.Bold;color:Opal.Theme.onSecondaryContainer}}
                    }
                }
                Rectangle {width:116;height:52;radius:26;color:Opal.Theme.alpha(Opal.Theme.glassIsland,.96)
                    Row {anchors.centerIn:parent;spacing:14
                        Opal.Glyph {name:"stadia_controller";font.pixelSize:19;color:Opal.Theme.text}
                        Opal.Glyph {name:"volume_up";font.pixelSize:19;color:Opal.Theme.text}
                        Opal.Glyph {name:"wifi";font.pixelSize:19;color:Opal.Theme.text}}}
                Rectangle {id:clockPill;width:clockRow.implicitWidth+32;height:52;radius:26;color:Opal.Theme.primaryContainer
                    Row {id:clockRow;anchors.centerIn:parent;spacing:8
                        Opal.MText {text:"Wed 21";role:"label";color:Opal.Theme.alpha(Opal.Theme.onContainer,.8);anchors.verticalCenter:parent.verticalCenter}
                        Opal.MText {text:"21:33";role:"title";font.features:{"tnum":1};color:Opal.Theme.onContainer;anchors.verticalCenter:parent.verticalCenter}}}
            }
            // The card that popped up from the game pill.
            Rectangle {
                width:384;height:cardCol.implicitHeight+28;radius:28
                x:Math.min(parent.width-12-width,parent.width-12-clockPill.width-8-116-8-gamePill.width/2-width/2)
                y:parent.height-62-10-height
                color:Opal.Theme.alpha(Opal.Theme.level(2),.98);border.width:1;border.color:Opal.Theme.outline
                Column {id:cardCol;x:14;y:14;width:parent.width-28;spacing:12
                    Item {width:parent.width;height:92
                        Art {anchors.fill:parent;radius:18;source:root.g.dr.h;decodeSize:Qt.size(712,184)}
                        Rectangle {anchors.fill:parent;radius:18;gradient:Gradient {orientation:Gradient.Horizontal;GradientStop {position:0;color:Opal.Theme.alpha("#000000",.8)} GradientStop {position:1;color:"transparent"}}}
                        Logo {x:14;y:12;width:150;height:44;source:root.g.dr.l}
                        Opal.MText {x:14;anchors.bottom:parent.bottom;anchors.bottomMargin:10;text:"38 min · 30 FPS · 52°";role:"label";color:"#ffffff"}
                    }
                    Seg {items:[{g:"eco",t:"Saver"},{g:"balance",t:"Balanced"},{g:"rocket_launch",t:"Max"}];sel:1;h:40;segW:(parent.width-6)/3;showCheck:true}
                    Grid {columns:2;spacing:8
                        Opal.ShadeTile {width:174;height:56;dense:true;icon:"monitoring";title:"Overlay";subtitle:"Compact";active:true}
                        Opal.ShadeTile {width:174;height:56;dense:true;icon:"do_not_disturb_on";title:"Do not disturb";subtitle:"While playing";active:true}
                    }
                    Row {spacing:8
                        Action {b:"";g:"screenshot_monitor";t:"Capture";filled:false;h:40}
                        Action {b:"";g:"open_in_full";t:"Quick Access";filled:false;h:40}
                        RoundIcon {g:"close";s:40}
                    }
                }
            }
        }
    }

    // ---------- 8. Guide glance: the smallest state ----------
    Component {id:glance
        Item {
            Art {anchors.fill:parent;radius:0;source:root.shots.stel[3];decodeSize:Qt.size(1280,800)}
            Rectangle {
                anchors.horizontalCenter:parent.horizontalCenter;y:20
                width:glRow.implicitWidth+16;height:60;radius:30
                color:Opal.Theme.alpha(Opal.Theme.level(2),.96);border.width:1;border.color:Opal.Theme.outline
                Row {id:glRow;x:8;anchors.verticalCenter:parent.verticalCenter;spacing:8
                    Rectangle {height:44;width:gameChip.implicitWidth+16;radius:22;color:Opal.Theme.level(4)
                        Row {id:gameChip;x:4;anchors.verticalCenter:parent.verticalCenter;spacing:10
                            Art {width:36;height:36;radius:18;source:root.g.stel.c;decodeSize:Qt.size(72,108)}
                            Column {anchors.verticalCenter:parent.verticalCenter
                                Opal.MText {text:"Stellaris";role:"titleS"}
                                Opal.MText {text:"47 min";role:"labelS";color:Opal.Theme.subtext}}}}
                    Pill {h:44;g:"speed";t:"60 FPS"}
                    Pill {h:44;g:"stadia_controller";t:"64%"}
                    Pill {h:44;g:"battery_5_bar";t:"73%"}
                    Pill {h:44;g:"notifications";t:"2";tonal:true}
                    Rectangle {height:44;width:clk.implicitWidth+28;radius:22;color:Opal.Theme.primaryContainer
                        Opal.MText {id:clk;anchors.centerIn:parent;text:"21:33";role:"title";font.features:{"tnum":1};color:Opal.Theme.onContainer}}
                }
            }
            Opal.ControllerHints {anchors.horizontalCenter:parent.horizontalCenter;y:92
                items:[{b:"Guide",t:"Quick Access"},{b:"Hold",t:"Claude"},{b:"A",t:"Screenshot"},{b:"B",t:"Hide"}]}
        }
    }
}
