import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Round 4 (2026-10-14): homes, contextual pills, the media player, search and floating mode. Static data only.
// Spec: docs/HOME-PILLS-2026-10.md.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string wall:"file:///home/melissa/Pictures/Wallpapers/default.png"
    readonly property string art:"file:///home/melissa/Pictures/Wallpapers/0j1z5q.jpeg"
    readonly property string photo:"file:///home/melissa/Pictures/Wallpapers/3kg8qd.jpeg"
    readonly property string hero:"file:///home/melissa/.local/share/Steam/appcache/librarycache/1671210/library_hero.jpg"
    readonly property string pap:"/usr/share/icons/Papirus/64x64/"
    function icon(n) {
        const fixed={kitty:"/usr/share/pixmaps/kitty.png",files:"apps/org.kde.dolphin.svg",calc:"apps/org.gnome.Calculator.svg",signal:"apps/signal-desktop.svg",
            md:"mimetypes/text-markdown.svg",png:"mimetypes/image-png.svg",pdf:"mimetypes/application-pdf.svg",folder:"places/folder-blue.svg",txt:"mimetypes/text-x-generic.svg"};
        const f=fixed[n];
        return "file://"+(f ? (f.startsWith("/") ? f : pap+f) : pap+"apps/"+n+".svg");
    }
    // Pill and card colour per kind. Calm tonal tint where the kind means something; neutral for plain progress.
    function bg(k) {
        const T=Opal.Theme;
        return k==="agent" ? T.tertiaryContainer : k==="rec" ? T.mix(T.base,T.error,T.light ? .2 : .22) : k==="device" ? T.secondaryContainer
             : k==="focus" ? T.mix(T.base,T.primary,T.light ? .26 : .2) : k==="media" ? T.level(3) : T.level(2);
    }
    function ink(k) {
        const T=Opal.Theme;
        return k==="agent" ? T.onTertiaryContainer : k==="rec" ? T.mix(T.error,T.light ? "#000000" : "#ffffff",.3) : k==="device" ? T.onSecondaryContainer
             : k==="focus" ? T.mix(T.primary,T.light ? "#000000" : "#ffffff",.35) : T.text;
    }
    function accent(k) {
        const T=Opal.Theme;
        return k==="agent" ? T.tertiary : k==="rec" ? T.error : k==="focus" ? T.primary : k==="device" ? T.secondary : T.alpha(T.text,.13);
    }
    function onAccent(k) {return k==="neutral"||k==="media" ? root.ink(k) : Opal.Theme.base;}
    readonly property var gridApps:[{i:"kitty",t:"Terminal"},{i:"files",t:"Files"},{i:"steam",t:"Steam"},{i:"spotify",t:"Spotify"},{i:"signal",t:"Signal"},{i:"calc",t:"Calculator"},{i:"kicad",t:"KiCad"},{i:"blender",t:"Blender"}]
    readonly property var dockApps:["firefox","discord","thunderbird","kate"]

    Window {
        id:fixture
        width:412;height:915;visible:true;color:"#000"
        property int step:0
        property var cases:[
            {name:"r4-01-phone-home",view:phoneHomeView},
            {name:"r4-02-phone-minus-one",view:minusOneView},
            {name:"r4-03-phone-shade-pill",view:shadeView},
            {name:"r4-04-phone-longpress",view:phoneHomeView,menu:true},
            {name:"r4-05-phone-widget-picker",view:pickerView},
            {name:"r4-06-pills-and-cards",view:pillsView,w:1240,h:900},
            {name:"r4-07-player-panel",view:playerView,w:480,h:730},
            {name:"r4-08-tablet-home",view:tabletView,w:1280,h:800},
            {name:"r4-09-desktop-home",view:desktopView,w:1600,h:900},
            {name:"r4-10-desktop-pill-card",view:desktopView,w:1600,h:900,card:true},
            {name:"r4-11-search-idle",view:searchView,w:900,h:620,q:""},
            {name:"r4-12-search-setting",view:searchView,w:900,h:700,q:"dark"},
            {name:"r4-13-search-claude",view:searchView,w:900,h:620,q:"how do i make window gaps smaller"},
            {name:"r4-14-floating-mode",view:floatingView,w:1600,h:900},
            {name:"r4-15-phone-home-light",view:phoneHomeView,light:true}
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
        Timer {id:grab;interval:2200;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    // ---------- Shared parts ----------
    component Ico:Image {property string n:"";source:n ? root.icon(n) : "";sourceSize:Qt.size(128,128);smooth:true;fillMode:Image.PreserveAspectFit}
    // Rounded, cover-cropped art. Canvas clipping works in the software renderer, unlike layer masks.
    component RArt:Canvas {
        id:ra
        property string src:""
        property real r:24
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onImageLoaded:requestPaint()
        Component.onCompleted:loadImage(src)
        onPaint:{
            const c=getContext("2d");c.reset();
            c.beginPath();c.roundedRect(0,0,width,height,r,r);c.clip();
            if(isImageLoaded(src)){
                const d=c.createImageData(src);const s=Math.max(width/d.width,height/d.height);
                c.drawImage(src,(width-d.width*s)/2,(height-d.height*s)/2,d.width*s,d.height*s);
            }
        }
    }
    component Squiggle:Canvas {
        id:sq
        property real progress:.32
        property color ink:Opal.Theme.text
        property bool playing:true
        implicitHeight:18
        onWidthChanged:requestPaint()
        Component.onCompleted:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();
            const mid=height/2,px=Math.max(6,width*progress);
            c.lineWidth=3.5;c.lineCap="round";c.strokeStyle=String(ink);
            c.beginPath();
            for(let x=3;x<=px-6;x+=1){const y=mid+(playing ? Math.sin(x/24*2*Math.PI)*3 : 0);if(x===3)c.moveTo(x,y);else c.lineTo(x,y);}
            c.stroke();
            c.globalAlpha=.3;c.beginPath();c.moveTo(px+6,mid);c.lineTo(width-3,mid);c.stroke();
            c.globalAlpha=1;c.fillStyle=String(ink);c.beginPath();c.roundedRect(px-2,mid-8,4,16,2,2);c.fill();
        }
    }
    component Ring:Canvas {
        property real value:.6
        property color ink:Opal.Theme.primary
        property real lw:3
        onWidthChanged:requestPaint()
        Component.onCompleted:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();const r=Math.min(width,height)/2-lw/2-1;
            c.lineWidth=lw;c.lineCap="round";c.strokeStyle=String(ink);
            c.globalAlpha=.22;c.beginPath();c.arc(width/2,height/2,r,0,2*Math.PI);c.stroke();
            c.globalAlpha=1;c.beginPath();c.arc(width/2,height/2,r,-Math.PI/2,-Math.PI/2+2*Math.PI*value);c.stroke();
        }
    }
    // M3 Expressive linear progress: active track, a gap, the rest, and a stop dot.
    component LinBar:Item {
        id:lb
        property real value:.5
        property color ink:Opal.Theme.primary
        implicitHeight:8
        Rectangle {width:Math.max(lb.height,(lb.width-6)*lb.value);height:lb.height;radius:lb.height/2;color:lb.ink}
        Rectangle {x:(lb.width-6)*lb.value+6;width:Math.max(0,lb.width-x);height:lb.height;radius:lb.height/2;color:Opal.Theme.alpha(lb.ink,.2)}
        Rectangle {x:lb.width-lb.height/2-2;y:(lb.height-4)/2;width:4;height:4;radius:2;color:lb.ink}
    }
    component Btn:Rectangle {
        id:b
        property string t:""
        property string g:""
        property color ink:Opal.Theme.text
        implicitWidth:br.implicitWidth+(t ? 30 : 18);implicitHeight:38;radius:19
        color:Opal.Theme.alpha(Opal.Theme.text,.1)
        Row {id:br;anchors.centerIn:parent;spacing:6
            Opal.Glyph {visible:b.g!=="";name:b.g;font.pixelSize:18;color:b.ink;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {visible:b.t!=="";text:b.t;role:"label";font.pixelSize:13;font.weight:Font.DemiBold;color:b.ink;anchors.verticalCenter:parent.verticalCenter}}
    }
    // Compact pill: what the status bar, Shelf and lock screen show.
    component CPill:Rectangle {
        id:cp
        property string k:"neutral"
        property string g:""
        property string artSrc:""
        property string t:""
        property real prog:-1
        property int more:0
        property bool dot:false
        property bool bars:false
        readonly property color ink:root.ink(k)
        implicitHeight:30;implicitWidth:cpr.implicitWidth+(t ? 22 : 16);radius:15;color:root.bg(k)
        Row {id:cpr;anchors.centerIn:parent;spacing:6
            Rectangle {visible:cp.dot;width:8;height:8;radius:4;color:Opal.Theme.error;anchors.verticalCenter:parent.verticalCenter}
            RArt {visible:cp.artSrc!=="";src:cp.artSrc;r:6;width:20;height:20;anchors.verticalCenter:parent.verticalCenter}
            Opal.Glyph {visible:cp.g!=="";name:cp.g;font.pixelSize:17;color:cp.k==="neutral" ? cp.ink : root.accent(cp.k);anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {visible:cp.t!=="";text:cp.t;role:"label";font.weight:Font.DemiBold;color:cp.ink;anchors.verticalCenter:parent.verticalCenter}
            Opal.Glyph {visible:cp.bars;name:"graphic_eq";font.pixelSize:17;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
            Ring {visible:cp.prog>=0;value:cp.prog;ink:cp.ink;lw:2.6;width:17;height:17;anchors.verticalCenter:parent.verticalCenter}
            Rectangle {visible:cp.more>0;width:26;height:20;radius:10;color:Opal.Theme.alpha(cp.ink,.16);anchors.verticalCenter:parent.verticalCenter
                Opal.MText {anchors.centerIn:parent;text:"+"+cp.more;role:"labelS";font.weight:Font.Bold;color:cp.ink}}
        }
    }
    // Rich card: the same component is the expanded pill, the shade card and the home widget.
    component ActCard:Rectangle {
        id:ac
        property string k:"neutral"
        property string g:"download"
        property string ico:""
        property string t:""
        property string s:""
        property string meta:""
        property real prog:-1
        property string progText:""
        property string code:""
        property var acts:[]
        property bool ring:false
        property string ringText:""
        readonly property color ink:root.ink(k)
        radius:26;color:root.bg(k)
        implicitHeight:col.implicitHeight+32
        ColumnLayout {
            id:col;x:16;y:16;width:ac.width-32;spacing:12
            RowLayout {Layout.fillWidth:true;spacing:12
                Rectangle {Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20;color:ac.ico!=="" ? Opal.Theme.alpha(ac.ink,.13) : root.accent(ac.k)
                    Opal.Glyph {anchors.centerIn:parent;visible:ac.ico==="";name:ac.g;font.pixelSize:22;color:root.onAccent(ac.k)}
                    Ico {anchors.centerIn:parent;visible:ac.ico!=="";width:26;height:26;n:ac.ico}}
                ColumnLayout {Layout.fillWidth:true;spacing:1
                    Opal.MText {Layout.fillWidth:true;text:ac.t;role:"titleS";color:ac.ink}
                    Opal.MText {Layout.fillWidth:true;text:ac.s;role:"bodyS";color:Opal.Theme.alpha(ac.ink,.74)}}
                Opal.MText {visible:ac.meta!=="";text:ac.meta;role:"labelS";color:Opal.Theme.alpha(ac.ink,.7);Layout.alignment:Qt.AlignTop}
                Item {visible:ac.ring;Layout.preferredWidth:58;Layout.preferredHeight:58
                    Ring {anchors.fill:parent;value:ac.prog;ink:ac.ink;lw:5}
                    Opal.MText {anchors.centerIn:parent;text:ac.ringText;role:"label";font.weight:Font.Bold;color:ac.ink}}
            }
            Rectangle {
                visible:ac.code!=="";Layout.fillWidth:true;Layout.preferredHeight:ct.implicitHeight+20;radius:14
                color:Opal.Theme.alpha(Opal.Theme.light ? "#ffffff" : "#000000",Opal.Theme.light ? .55 : .26)
                Text {id:ct;x:12;y:10;width:parent.width-24;text:ac.code;color:ac.ink;font.family:"CaskaydiaCove Nerd Font";font.pixelSize:12;wrapMode:Text.WrapAnywhere}
            }
            ColumnLayout {visible:ac.prog>=0&&!ac.ring;Layout.fillWidth:true;spacing:6
                LinBar {Layout.fillWidth:true;value:Math.max(0,ac.prog);ink:ac.ink}
                Opal.MText {Layout.fillWidth:true;text:ac.progText;role:"labelS";color:Opal.Theme.alpha(ac.ink,.74)}}
            Row {visible:ac.acts.length>0;Layout.alignment:Qt.AlignRight;spacing:8
                Repeater {model:ac.acts
                    Btn {required property var modelData;t:modelData.t||"";g:modelData.g||"";ink:modelData.f ? ac.color : ac.ink
                        color:modelData.f ? ac.ink : Opal.Theme.alpha(ac.ink,.13)}}}
        }
    }
    // Pixel Quick Settings style player. Calm art, the source app, a squiggle that seeks. Never the output device.
    component Player:Item {
        id:pl
        property bool small:false
        property bool playing:true
        implicitHeight:small ? 156 : 196
        RArt {anchors.fill:parent;src:root.art;r:28}
        Rectangle {anchors.fill:parent;radius:28
            gradient:Gradient {
                GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,Opal.Theme.light ? .5 : .55)}
                GradientStop {position:1;color:Opal.Theme.alpha(Opal.Theme.base,Opal.Theme.light ? .82 : .88)}}}
        RowLayout {x:18;y:16;width:pl.width-36;spacing:8
            Ico {Layout.preferredWidth:20;Layout.preferredHeight:20;n:"firefox"}
            Opal.MText {text:"Firefox · YouTube";role:"label";color:Opal.Theme.subtext;Layout.fillWidth:true}
            // Two players are active: a page dot per player.
            Row {spacing:4
                Rectangle {width:14;height:6;radius:3;color:Opal.Theme.text}
                Rectangle {width:6;height:6;radius:3;color:Opal.Theme.alpha(Opal.Theme.text,.35)}}
        }
        ColumnLayout {x:18;y:pl.small ? 46 : 56;width:pl.width-36-80;spacing:2
            Opal.MText {Layout.fillWidth:true;text:"The Keyboard Is Dead. Now What?";role:pl.small ? "titleS" : "title"}
            Opal.MText {Layout.fillWidth:true;text:"Ben Vallack";role:"bodyS";color:Opal.Theme.subtext}}
        Rectangle {anchors.right:parent.right;anchors.rightMargin:18;y:pl.small ? 42 : 50;width:62;height:62;radius:22;color:Opal.Theme.primaryContainer
            Opal.Glyph {anchors.centerIn:parent;name:pl.playing ? "pause" : "play_arrow";font.pixelSize:30;color:Opal.Theme.containerInk}}
        RowLayout {anchors.bottom:parent.bottom;anchors.bottomMargin:14;x:12;width:pl.width-24;spacing:8
            Opal.Glyph {name:"skip_previous";font.pixelSize:24}
            Opal.MText {text:"4:12";role:"labelS";color:Opal.Theme.subtext}
            Squiggle {Layout.fillWidth:true;Layout.preferredHeight:18;progress:.32;playing:pl.playing}
            Opal.MText {text:"13:05";role:"labelS";color:Opal.Theme.subtext}
            Opal.Glyph {name:"skip_next";font.pixelSize:24}
        }
    }
    component Slab:Rectangle {
        id:sl
        property string g:"light_mode"
        property real value:.6
        implicitHeight:48;radius:24;color:Opal.Theme.level(3)
        Rectangle {width:Math.max(48,sl.width*sl.value);height:sl.height;radius:24;color:Opal.Theme.primary}
        Opal.Glyph {x:14;anchors.verticalCenter:parent.verticalCenter;name:sl.g;font.pixelSize:20;color:Opal.Theme.onPrimary}
    }
    component QTile:Rectangle {
        id:qt
        property string g:"wifi"
        property string t:""
        property string s:""
        property bool on:false
        implicitHeight:64;radius:22;color:on ? Opal.Theme.primary : Opal.Theme.level(3)
        RowLayout {anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:12;spacing:10
            Opal.Glyph {name:qt.g;font.pixelSize:22;color:qt.on ? Opal.Theme.onPrimary : Opal.Theme.text}
            ColumnLayout {visible:qt.t!=="";Layout.fillWidth:true;spacing:0
                Opal.MText {Layout.fillWidth:true;text:qt.t;role:"label";font.pixelSize:13;font.weight:Font.DemiBold;color:qt.on ? Opal.Theme.onPrimary : Opal.Theme.text}
                Opal.MText {Layout.fillWidth:true;text:qt.s;role:"labelS";color:qt.on ? Opal.Theme.alpha(Opal.Theme.onPrimary,.8) : Opal.Theme.subtext}}}
    }
    component AppCell:Column {
        id:cell
        property string i:""
        property string t:""
        property real size:56
        spacing:6
        Ico {anchors.horizontalCenter:parent.horizontalCenter;width:cell.size;height:cell.size;n:cell.i}
        Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;width:cell.width;horizontalAlignment:Text.AlignHCenter;text:cell.t;role:"label";visible:cell.t!==""
            style:Text.Raised;styleColor:Opal.Theme.alpha(Opal.Theme.light ? "#ffffff" : "#000000",.35)}
    }
    component Scrim:Rectangle {
        gradient:Gradient {
            GradientStop {position:0;color:Opal.Theme.alpha(Opal.Theme.base,Opal.Theme.light ? .55 : .30)}
            GradientStop {position:.3;color:Opal.Theme.alpha(Opal.Theme.base,.08)}
            GradientStop {position:.7;color:Opal.Theme.alpha(Opal.Theme.base,.12)}
            GradientStop {position:1;color:Opal.Theme.alpha(Opal.Theme.base,.55)}}
    }
    component PhoneBar:Item {
        property bool pill:true
        height:40
        Opal.MText {x:22;anchors.verticalCenter:parent.verticalCenter;text:"18:24";role:"label";font.pixelSize:14;font.weight:Font.DemiBold}
        CPill {visible:parent.pill;x:72;anchors.verticalCenter:parent.verticalCenter;k:"agent";g:"terminal";t:"Needs you";more:2}
        Row {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;spacing:6
            Opal.Glyph {name:"wifi";font.pixelSize:17}
            Opal.Glyph {name:"battery_5_bar";font.pixelSize:17}
            Opal.MText {text:"76%";role:"label";anchors.verticalCenter:parent.verticalCenter}}
    }
    component Glance:Column {
        property real big:24
        spacing:6
        Row {spacing:10
            Opal.MText {text:"Wed, Oct 15";font.pixelSize:parent.parent.big;font.weight:Font.DemiBold;anchors.verticalCenter:parent.verticalCenter}
            Opal.Glyph {name:"partly_cloudy_day";font.pixelSize:parent.parent.big;color:Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:"18°";font.pixelSize:parent.parent.big;font.weight:Font.DemiBold;anchors.verticalCenter:parent.verticalCenter}}
        Row {spacing:8
            Opal.Glyph {name:"event";font.pixelSize:16;color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:"Opal sync · 16:00 · in 40 min";role:"bodyS";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}
    }
    component PhotoW:Item {
        RArt {anchors.fill:parent;src:root.photo;r:28}
        Rectangle {anchors.fill:parent;radius:28;gradient:Gradient {GradientStop {position:.55;color:"transparent"} GradientStop {position:1;color:Opal.Theme.alpha("#000000",.55)}}}
        Column {x:16;anchors.bottom:parent.bottom;anchors.bottomMargin:14;spacing:0
            Opal.MText {text:"1 year ago";role:"titleS";color:"#ffffff"}
            Opal.MText {text:"Memories";role:"labelS";color:Opal.Theme.alpha("#ffffff",.8)}}
    }
    component DevicesW:Rectangle {
        id:dw
        radius:28;color:Opal.Theme.alpha(Opal.Theme.level(2),.94)
        readonly property var items:[{g:"smartphone",t:"OnePlus 7",v:.76},{g:"headphones",t:"Pixel Buds",v:.8},{g:"sports_esports",t:"Controller",v:.35},{g:"system_update",t:"Updates",v:-1,n:"42"}]
        Grid {anchors.centerIn:parent;columns:2;rowSpacing:14;columnSpacing:22
            Repeater {model:dw.items
                Column {required property var modelData;spacing:6;width:(dw.width-70)/2
                    Item {width:48;height:48;anchors.horizontalCenter:parent.horizontalCenter
                        Ring {anchors.fill:parent;visible:modelData.v>=0;value:Math.max(0,modelData.v);lw:4;ink:modelData.v<.4 ? Opal.Theme.error : Opal.Theme.primary}
                        Rectangle {anchors.fill:parent;visible:modelData.v<0;radius:24;color:Opal.Theme.tertiaryContainer}
                        Opal.Glyph {anchors.centerIn:parent;name:modelData.g;font.pixelSize:20;color:modelData.v<0 ? Opal.Theme.onTertiaryContainer : Opal.Theme.text}}
                    Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:modelData.v>=0 ? Math.round(modelData.v*100)+"%" : modelData.n;role:"label";font.weight:Font.Bold}}}}
    }
    component SearchBar:Rectangle {
        id:sb
        property string hint:"Search"
        height:56;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(3),.95)
        RowLayout {anchors.fill:parent;anchors.leftMargin:20;anchors.rightMargin:8;spacing:12
            Opal.Glyph {name:"search";font.pixelSize:22;color:Opal.Theme.text}
            Opal.MText {Layout.fillWidth:true;text:sb.hint;role:"body";font.pixelSize:16;color:Opal.Theme.subtext}
            Rectangle {Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20;color:Opal.Theme.tertiaryContainer
                Opal.Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:20;color:Opal.Theme.onTertiaryContainer}}}
    }
    component Dots:Row {
        property int count:3
        property int at:0
        spacing:6
        Repeater {model:parent.count;Rectangle {required property int index;width:index===parent.at ? 18 : 7;height:7;radius:4;color:index===parent.at ? Opal.Theme.text : Opal.Theme.alpha(Opal.Theme.text,.35)}}
    }

    // ---------- Phone ----------
    component PhoneHomeScene:Item {
        id:hs
        property bool menu:false
        readonly property real cellW:(width-24)/4
        Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1200,1200);fillMode:Image.PreserveAspectCrop}
        Scrim {anchors.fill:parent}
        PhoneBar {width:parent.width;y:4}
        Glance {x:24;y:62}
        Player {x:14;y:140;width:parent.width-28;height:186}
        // A live pill docked onto the home as its card.
        ActCard {x:14;y:338;width:parent.width-28;k:"agent";g:"terminal";t:"Claude Code needs you";s:"~/opal · wants to run git push";meta:"now"
            acts:[{t:"Deny"},{t:"Allow",f:true}]}
        Grid {
            id:grid;x:12;y:484;columns:4;rowSpacing:14
            Repeater {model:root.gridApps;AppCell {required property var modelData;required property int index;width:hs.cellW;i:modelData.i;t:modelData.t
                opacity:hs.menu&&index===0 ? 0 : 1}}
        }
        Dots {visible:!hs.menu;anchors.horizontalCenter:parent.horizontalCenter;y:684;count:3;at:0}
        Row {anchors.horizontalCenter:parent.horizontalCenter;y:712;spacing:(hs.width-24-4*58)/4
            Repeater {model:root.dockApps;Ico {required property string modelData;width:58;height:58;n:modelData}}}
        SearchBar {x:14;y:794;width:parent.width-28;hint:"Search apps, files, settings"}
        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:9;width:108;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.6)}

        // Long-press: everything else dims, the icon lifts, and a menu grows out of it.
        Rectangle {anchors.fill:parent;visible:hs.menu;color:Opal.Theme.alpha("#000000",.42)}
        Item {
            visible:hs.menu;x:grid.x;y:grid.y;width:hs.cellW;height:90
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:-2;width:70;height:70;radius:35;color:Opal.Theme.alpha("#000000",.35)}
            AppCell {width:parent.width;i:"kitty";t:"";size:64;y:-6}
        }
        Rectangle {
            visible:hs.menu;x:14;y:grid.y-menuCol.implicitHeight-34;width:250;height:menuCol.implicitHeight+20;radius:28;color:Opal.Theme.level(3)
            ColumnLayout {id:menuCol;x:10;y:10;width:parent.width-20;spacing:2
                Repeater {model:[{g:"add_box",t:"New window"},{g:"tab",t:"New tab"},{g:"folder_open",t:"Open ~/opal"}]
                    Rectangle {required property var modelData;Layout.fillWidth:true;Layout.preferredHeight:46;radius:16;color:"transparent"
                        Row {x:12;anchors.verticalCenter:parent.verticalCenter;spacing:14
                            Opal.Glyph {name:modelData.g;font.pixelSize:20;color:Opal.Theme.primary}
                            Opal.MText {text:modelData.t;role:"body";anchors.verticalCenter:parent.verticalCenter}}}}
                Rectangle {Layout.fillWidth:true;Layout.preferredHeight:1;Layout.topMargin:4;Layout.bottomMargin:6;color:Opal.Theme.outline}
                Row {Layout.alignment:Qt.AlignHCenter;spacing:6
                    Btn {g:"widgets";t:"Widgets"}
                    Btn {g:"info"}
                    Btn {g:"delete";ink:Opal.Theme.error}}
            }
        }
        Opal.MText {visible:hs.menu;anchors.horizontalCenter:parent.horizontalCenter;y:678;text:"Drag to move · hold at the edge to change page";role:"label";color:"#ffffff"}
    }
    Component {id:phoneHomeView;PhoneHomeScene {menu:!!fixture.current.menu}}

    Component {id:minusOneView
        Item {
            Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1200,1200);fillMode:Image.PreserveAspectCrop}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.86)}
            PhoneBar {width:parent.width;y:4;pill:false}
            Column {x:24;y:58;spacing:2
                Opal.MText {text:"Live";role:"displayS"}
                Opal.MText {text:"4 running · 1 needs you";role:"bodyS";color:Opal.Theme.subtext}}
            Column {
                x:14;y:142;width:parent.width-28;spacing:10
                ActCard {width:parent.width;k:"agent";g:"terminal";t:"Claude Code needs you";s:"~/opal · Bash";meta:"now";code:"$ git push origin overhaul-2026-10"
                    acts:[{g:"open_in_new"},{t:"Deny"},{t:"Allow",f:true}]}
                Player {width:parent.width;small:true}
                ActCard {width:parent.width;k:"neutral";g:"system_update";t:"Updating 42 packages";s:"pacman · mesa, qt6-base, linux-cachyos";prog:.61;progText:"26 of 42 · about a minute left"}
                ActCard {width:parent.width;k:"agent";g:"auto_awesome";t:"Assistant";s:"Tidying ~/Downloads · step 3 of 5";prog:.6;progText:"Moved 18 screenshots to ~/Pictures/Screenshots";acts:[{g:"stop",t:"Stop"}]}
            }
            Rectangle {
                x:14;anchors.bottom:parent.bottom;anchors.bottomMargin:30;width:parent.width-28;height:56;radius:28;color:Opal.Theme.level(3)
                RowLayout {anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:16;spacing:12
                    Opal.Glyph {name:"auto_awesome";font.pixelSize:22;color:Opal.Theme.tertiary}
                    Opal.MText {Layout.fillWidth:true;text:"Ask Claude…";role:"body";font.pixelSize:16;color:Opal.Theme.subtext}
                    Opal.Glyph {name:"mic";font.pixelSize:22;color:Opal.Theme.subtext}}}
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:9;width:108;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.6)}
        }
    }

    // Tapping the status-bar pill opens the shade with that activity on top; the others wait as chips.
    Component {id:shadeView
        Rectangle {
            color:Opal.Theme.level(1)
            PhoneBar {width:parent.width;y:4;pill:false}
            Column {
                x:14;y:52;width:parent.width-28;spacing:12
                ActCard {width:parent.width;k:"agent";g:"terminal";t:"Claude Code needs you";s:"~/opal · Bash";meta:"now";code:"$ git push origin overhaul-2026-10"
                    acts:[{g:"open_in_new"},{t:"Deny"},{t:"Allow",f:true}]}
                Flow {width:parent.width;spacing:8
                    CPill {k:"media";artSrc:root.art;t:"Keyboard Is Dead";bars:true}
                    CPill {k:"neutral";g:"system_update";t:"42";prog:.61}
                    CPill {k:"agent";g:"auto_awesome";t:"3 of 5"}}
                Opal.ExpressiveSlider {width:parent.width;implicitHeight:52;compact:true;trackHeight:44;icon:"sun";iconAtHandle:true;value:70}
                Opal.ExpressiveSlider {width:parent.width;implicitHeight:52;compact:true;trackHeight:44;icon:"volume";iconAtHandle:true;value:52}
                // The live shade's own tiles (ShadeTile, dense): wide tiles keep a glass body and only the icon square lights up.
                Grid {width:parent.width;columns:2;rowSpacing:8;columnSpacing:8
                    Opal.ShadeTile {width:(parent.width-8)/2;height:64;dense:true;icon:"wifi";title:"Internet";subtitle:"Opal-5G";active:true}
                    Opal.ShadeTile {width:(parent.width-8)/2;height:64;dense:true;icon:"bluetooth";title:"Bluetooth";subtitle:"Pixel Buds";active:true}
                    Opal.ShadeTile {width:(parent.width-8)/2;height:64;dense:true;icon:"quiet";title:"Do not disturb";subtitle:"Off"}
                    Opal.ShadeTile {width:(parent.width-8)/2;height:64;dense:true;icon:"coffee";title:"Keep awake";subtitle:"Off"}}
                Row {spacing:8
                    Repeater {model:[{g:"moon",on:true},{g:"battery",on:true},{g:"keyboard"},{g:"capture"}]
                        Opal.ShadeTile {required property var modelData;width:(384-24)/4;height:64;dense:true;iconOnly:true;icon:modelData.g;active:!!modelData.on}}}
                Grid {width:parent.width;columns:2;rowSpacing:8;columnSpacing:8
                    Opal.ShadeTile {width:(parent.width-8)/2;height:64;dense:true;icon:"mic";title:"Microphone";subtitle:"On";active:true}
                    Opal.ShadeTile {width:(parent.width-8)/2;height:64;dense:true;icon:"desktop";title:"Auto-hide shelf";subtitle:"Off"}}
                Opal.MText {text:"Notifications";role:"titleS";topPadding:4}
                Rectangle {width:parent.width;height:76;radius:22;color:Opal.Theme.level(2)
                    RowLayout {anchors.fill:parent;anchors.margins:14;spacing:12
                        Ico {Layout.preferredWidth:36;Layout.preferredHeight:36;n:"discord"}
                        ColumnLayout {Layout.fillWidth:true;spacing:1
                            Opal.MText {text:"#opal-dev";role:"titleS"} Opal.MText {Layout.fillWidth:true;text:"pills look so good now omg";role:"bodyS";color:Opal.Theme.subtext}}
                        Opal.MText {text:"2m";role:"labelS";color:Opal.Theme.subtext;Layout.alignment:Qt.AlignTop}}}
            }
        }
    }

    Component {id:pickerView
        Item {
            PhoneHomeScene {anchors.fill:parent}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha("#000000",.4)}
            Rectangle {
                anchors {left:parent.left;right:parent.right;bottom:parent.bottom}
                height:parent.height*.78;radius:32;color:Opal.Theme.level(1)
                Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:10;width:36;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.35)}
                Column {
                    x:18;y:28;width:parent.width-36;spacing:14
                    Opal.MText {text:"Widgets";role:"headline"}
                    Rectangle {width:parent.width;height:48;radius:24;color:Opal.Theme.level(3)
                        Row {x:16;anchors.verticalCenter:parent.verticalCenter;spacing:10
                            Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
                            Opal.MText {text:"Search widgets";role:"body";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                    Row {spacing:10
                        Rectangle {width:30;height:30;radius:15;color:Opal.Theme.primaryContainer;Opal.Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:17;color:Opal.Theme.containerInk}}
                        Opal.MText {text:"Opal";role:"titleS";anchors.verticalCenter:parent.verticalCenter}
                        Opal.MText {text:"4 widgets";role:"labelS";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}
                    Rectangle {width:parent.width;height:96;radius:24;color:Opal.Theme.level(2)
                        Glance {x:18;y:18;big:20}
                        Opal.MText {anchors.right:parent.right;anchors.rightMargin:14;anchors.bottom:parent.bottom;anchors.bottomMargin:10;text:"Glance · 4×1";role:"labelS";color:Opal.Theme.subtext}}
                    Item {width:parent.width;height:172
                        Player {width:parent.width;height:156;small:true}
                        Opal.MText {anchors.right:parent.right;anchors.bottom:parent.bottom;text:"Media · 4×2";role:"labelS";color:Opal.Theme.subtext}}
                    Row {spacing:12
                        Column {spacing:6
                            PhotoW {width:(412-36-12)/2;height:160}
                            Opal.MText {text:"Photos · 2×2";role:"labelS";color:Opal.Theme.subtext}}
                        Column {spacing:6
                            DevicesW {width:(412-36-12)/2;height:160}
                            Opal.MText {text:"Devices · 2×2";role:"labelS";color:Opal.Theme.subtext}}}
                    Row {spacing:10
                        Ico {width:30;height:30;n:"thunderbird"}
                        Opal.MText {text:"Calendar";role:"titleS";anchors.verticalCenter:parent.verticalCenter}}
                }
            }
        }
    }

    // ---------- Pills and their cards ----------
    Component {id:pillsView
        Rectangle {
            color:Opal.Theme.base
            Column {
                x:36;y:32;width:330;spacing:14
                Opal.MText {text:"Compact pills";role:"headline"}
                Opal.MText {width:parent.width;text:"Status bar, Shelf and lock screen. Tint only where the kind means something.";role:"bodyS";color:Opal.Theme.subtext;wrapMode:Text.Wrap}
                Repeater {
                    model:[
                        {k:"media",art:true,t:"Keyboard Is Dead",bars:true,c:"Media"},
                        {k:"agent",g:"terminal",t:"Needs you",c:"Claude Code · waiting"},
                        {k:"agent",g:"auto_awesome",t:"3 of 5",c:"Assistant task"},
                        {k:"neutral",g:"system_update",t:"42",p:.61,c:"pacman · neutral"},
                        {k:"neutral",g:"download",t:"66%",p:.66,c:"Download · neutral"},
                        {k:"focus",g:"timer",t:"18:20",p:.7,c:"Focus timer"},
                        {k:"rec",dot:true,t:"0:42",c:"Recording"},
                        {k:"device",g:"videocam",t:"",c:"Camera + mic in use"},
                        {k:"device",g:"headphones",t:"80%",c:"Pixel Buds connected"},
                        {k:"neutral",g:"content_copy",t:"Copy 482913",c:"Suggestion (short-lived)"},
                        {k:"agent",g:"terminal",t:"Needs you",m:3,c:"Stacked: more behind it"}
                    ]
                    RowLayout {
                        required property var modelData
                        width:330;spacing:14
                        Item {Layout.preferredWidth:180;Layout.preferredHeight:30
                            CPill {k:modelData.k;g:modelData.g||"";artSrc:modelData.art ? root.art : "";t:modelData.t;prog:modelData.p===undefined ? -1 : modelData.p;dot:!!modelData.dot;bars:!!modelData.bars;more:modelData.m||0}}
                        Opal.MText {Layout.fillWidth:true;text:modelData.c;role:"bodyS";color:Opal.Theme.subtext}
                    }
                }
            }
            Opal.MText {x:410;y:32;text:"Rich cards";role:"headline"}
            Column {
                x:410;y:82;width:390;spacing:12
                ActCard {width:parent.width;k:"agent";g:"terminal";t:"Claude Code needs you";s:"~/opal · Bash";meta:"now";code:"$ git push origin overhaul-2026-10";acts:[{g:"open_in_new"},{t:"Deny"},{t:"Allow",f:true}]}
                Player {width:parent.width;height:186}
                ActCard {width:parent.width;k:"neutral";g:"download";ico:"firefox";t:"kicad-9.0.2.tar.zst";s:"Firefox · Downloads";prog:.66;progText:"340 of 512 MB · 12 MB/s · 14 s left";acts:[{t:"Pause"},{t:"Cancel"}]}
                ActCard {width:parent.width;k:"neutral";g:"system_update";t:"Updating 42 packages";s:"pacman · mesa, qt6-base, linux-cachyos";prog:.61;progText:"26 of 42 · about a minute left";acts:[{t:"Details"}]}
            }
            Column {
                x:820;y:82;width:384;spacing:12
                ActCard {width:parent.width;k:"focus";g:"timer";t:"Focus";s:"Ends at 18:42";ring:true;prog:.7;ringText:"18:20";acts:[{t:"+5 min"},{t:"Pause",f:true}]}
                ActCard {width:parent.width;k:"agent";g:"auto_awesome";t:"Assistant";s:"Tidying ~/Downloads · step 3 of 5";prog:.6;progText:"Moved 18 screenshots to ~/Pictures/Screenshots";acts:[{g:"stop",t:"Stop"}]}
                ActCard {width:parent.width;k:"rec";g:"radio_button_checked";t:"Recording screen";s:"OBS Studio · 0:42 · 1.2 GB free";acts:[{g:"pause"},{g:"stop",t:"Stop",f:true}]}
                ActCard {width:parent.width;k:"device";g:"videocam";t:"Camera and mic in use";s:"Firefox · meet.jit.si";acts:[{t:"Stop sharing",f:true}]}
                Rectangle {
                    width:parent.width;height:118;radius:26;color:root.bg("device")
                    RowLayout {anchors.fill:parent;anchors.margins:16;spacing:16
                        Rectangle {Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20;color:root.accent("device");Layout.alignment:Qt.AlignTop
                            Opal.Glyph {anchors.centerIn:parent;name:"headphones";font.pixelSize:22;color:root.onAccent("device")}}
                        ColumnLayout {Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:10;Layout.alignment:Qt.AlignTop;spacing:1
                            Opal.MText {Layout.fillWidth:true;text:"Pixel Buds Pro";role:"titleS";color:root.ink("device")}
                            Opal.MText {Layout.fillWidth:true;text:"Connected · ANC on";role:"bodyS";color:Opal.Theme.alpha(root.ink("device"),.74)}}
                        Repeater {model:[{t:"L",v:.8},{t:"R",v:.78},{t:"Case",v:.45}]
                            Column {required property var modelData;spacing:4
                                Item {width:40;height:40;anchors.horizontalCenter:parent.horizontalCenter
                                    Ring {anchors.fill:parent;value:modelData.v;lw:4;ink:root.ink("device")}
                                    Opal.MText {anchors.centerIn:parent;text:Math.round(modelData.v*100);role:"labelS";font.weight:Font.Bold;color:root.ink("device")}}
                                Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:modelData.t;role:"labelS";color:root.ink("device")}}}
                    }
                }
            }
        }
    }

    // ---------- Player panel: output and volume move to their own section ----------
    Component {id:playerView
        Rectangle {
            color:Opal.Theme.mix(Opal.Theme.base,"#000000",.2)
            Rectangle {
                x:14;y:14;width:parent.width-28;height:parent.height-28;radius:32;color:Opal.Theme.level(1)
                Column {
                    x:16;y:16;width:parent.width-32;spacing:14
                    RowLayout {width:parent.width
                        Opal.MText {Layout.fillWidth:true;text:"Sound & music";role:"title";leftPadding:6}
                        Btn {g:"close"}}
                    Player {width:parent.width;height:196}
                    Opal.MText {text:"Output";role:"labelS";font.letterSpacing:1;color:Opal.Theme.primary;leftPadding:6}
                    Column {width:parent.width;spacing:4
                        Repeater {model:[{g:"monitor",t:"LG UltraGear",s:"HDMI · Navi 21",on:true},{g:"headphones",t:"Pixel Buds Pro",s:"Bluetooth · 80%"},{g:"speaker",t:"Desk speakers",s:"USB"}]
                            Rectangle {required property var modelData;width:parent.width;height:56;radius:20;color:modelData.on ? Opal.Theme.secondaryContainer : "transparent"
                                RowLayout {anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:14;spacing:12
                                    Opal.Glyph {Layout.preferredWidth:26;name:modelData.g;font.pixelSize:22;color:modelData.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
                                    ColumnLayout {Layout.fillWidth:true;spacing:0
                                        Opal.MText {Layout.fillWidth:true;text:modelData.t;role:"titleS";color:modelData.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text}
                                        Opal.MText {Layout.fillWidth:true;text:modelData.s;role:"labelS";color:Opal.Theme.subtext}}
                                    Opal.Glyph {visible:!!modelData.on;name:"check";font.pixelSize:20;color:Opal.Theme.onSecondaryContainer}}}}}
                    Opal.MText {text:"Volume";role:"labelS";font.letterSpacing:1;color:Opal.Theme.primary;leftPadding:6}
                    Slab {width:parent.width;g:"volume_up";value:.52
                        Opal.MText {anchors.right:parent.right;anchors.rightMargin:16;anchors.verticalCenter:parent.verticalCenter;text:"52%";role:"label";font.weight:Font.Bold}}
                    Repeater {model:[{i:"firefox",v:.8},{i:"spotify",v:.45}]
                        RowLayout {required property var modelData;width:parent.width;spacing:12
                            Ico {Layout.preferredWidth:26;Layout.preferredHeight:26;Layout.leftMargin:10;n:modelData.i}
                            Item {Layout.fillWidth:true;Layout.preferredHeight:16
                                Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width;height:6;radius:3;color:Opal.Theme.level(3)}
                                Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width*modelData.v;height:6;radius:3;color:Opal.Theme.primary}
                                Rectangle {anchors.verticalCenter:parent.verticalCenter;x:parent.width*modelData.v-2;width:4;height:18;radius:2;color:Opal.Theme.primary}}
                            Opal.MText {text:Math.round(modelData.v*100)+"%";role:"labelS";color:Opal.Theme.subtext;Layout.preferredWidth:34}}}
                }
            }
        }
    }

    // ---------- Tablet: Pixel Tablet home with real pages and a running-apps dock ----------
    Component {id:tabletView
        Item {
            id:tv
            Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1600,1000);fillMode:Image.PreserveAspectCrop}
            Scrim {anchors.fill:parent}
            Item {width:parent.width;height:36
                Opal.MText {x:28;anchors.verticalCenter:parent.verticalCenter;text:"18:24";role:"label";font.pixelSize:14;font.weight:Font.DemiBold}
                CPill {x:84;anchors.verticalCenter:parent.verticalCenter;k:"agent";g:"terminal";t:"Needs you";more:2}
                Row {anchors.right:parent.right;anchors.rightMargin:28;anchors.verticalCenter:parent.verticalCenter;spacing:6
                    Opal.Glyph {name:"wifi";font.pixelSize:17} Opal.Glyph {name:"battery_5_bar";font.pixelSize:17} Opal.MText {text:"76%";role:"label";anchors.verticalCenter:parent.verticalCenter}}}
            Glance {x:56;y:66;big:28}
            Row {
                x:56;y:150;spacing:16
                Player {width:520;height:200}
                PhotoW {width:200;height:200}
                DevicesW {width:200;height:200}
                ActCard {width:248;k:"agent";g:"terminal";t:"Claude Code";s:"Wants to run git push";acts:[{t:"Deny"},{t:"Allow",f:true}]}
            }
            Grid {
                x:56;y:392;columns:7;rowSpacing:20
                Repeater {model:root.gridApps.concat([{i:"krita",t:"Krita"},{i:"gimp",t:"GIMP"},{i:"obs",t:"OBS"},{i:"code",t:"Code"},{i:"freecad",t:"FreeCAD"},{i:"google-chrome",t:"Chrome"}])
                    AppCell {required property var modelData;width:(tv.width-112)/7;size:60;i:modelData.i;t:modelData.t}}
            }
            Dots {anchors.horizontalCenter:parent.horizontalCenter;y:626;count:3;at:0}
            Rectangle {
                id:tdock
                anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:18
                width:dockRow.implicitWidth+24;height:80;radius:30;color:Opal.Theme.alpha(Opal.Theme.level(3),.94)
                Row {
                    id:dockRow;anchors.centerIn:parent;spacing:14
                    SearchBar {width:260;height:56;hint:"Search";anchors.verticalCenter:parent.verticalCenter;color:Opal.Theme.level(4)}
                    Repeater {model:["firefox","discord","thunderbird","kate","files"];Ico {required property string modelData;width:52;height:52;n:modelData;anchors.verticalCenter:parent.verticalCenter}}
                    Rectangle {width:1;height:44;color:Opal.Theme.outline;anchors.verticalCenter:parent.verticalCenter}
                    Repeater {model:["kitty","spotify","steam"]
                        Item {required property string modelData;width:52;height:64;anchors.verticalCenter:parent.verticalCenter
                            Ico {width:52;height:52;n:modelData}
                            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;width:14;height:4;radius:2;color:Opal.Theme.primary}}}
                }
            }
        }
    }

    // ---------- Desktop: ~/Desktop icons, a widget canvas, and the glance on an empty workspace ----------
    component Shelf:Item {
        id:sh
        height:64
        property bool cardOpen:false
        Rectangle {
            x:18;anchors.verticalCenter:parent.verticalCenter;width:leftRow.implicitWidth+16;height:52;radius:26;color:Opal.Theme.level(3)
            Row {id:leftRow;anchors.centerIn:parent;spacing:8
                Rectangle {width:42;height:42;radius:21;color:Opal.Theme.primaryContainer;anchors.verticalCenter:parent.verticalCenter
                    Opal.Glyph {anchors.centerIn:parent;name:"apps";font.pixelSize:22;color:Opal.Theme.containerInk}}
                Rectangle {width:200;height:42;radius:21;color:Opal.Theme.level(4);anchors.verticalCenter:parent.verticalCenter
                    Row {x:14;anchors.verticalCenter:parent.verticalCenter;spacing:10
                        Opal.Glyph {name:"search";font.pixelSize:19;color:Opal.Theme.subtext}
                        Opal.MText {text:"Search";role:"body";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                Repeater {model:["firefox","kitty","discord","spotify","files"]
                    Item {required property string modelData;required property int index;width:44;height:44;anchors.verticalCenter:parent.verticalCenter
                        Ico {anchors.centerIn:parent;width:32;height:32;n:modelData}
                        Rectangle {visible:index<4;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;width:index===1 ? 14 : 5;height:4;radius:2;color:Opal.Theme.primary}}}
            }
        }
        // Right side stays as separate pills, like the live Shelf: activity, status, then a tinted clock.
        Row {
            anchors.right:parent.right;anchors.rightMargin:18;anchors.verticalCenter:parent.verticalCenter;spacing:8
            Rectangle {width:actPill.width+12;height:44;radius:22;color:Opal.Theme.alpha(Opal.Theme.level(3),.94);anchors.verticalCenter:parent.verticalCenter
                CPill {id:actPill;anchors.centerIn:parent;k:"agent";g:"terminal";t:"Needs you";more:2;border.width:sh.cardOpen ? 2 : 0;border.color:Opal.Theme.tertiary}}
            Rectangle {width:statusRow.implicitWidth+32;height:44;radius:22;color:Opal.Theme.alpha(Opal.Theme.level(3),.94);anchors.verticalCenter:parent.verticalCenter
                Row {id:statusRow;anchors.centerIn:parent;spacing:12
                    Opal.Glyph {name:"volume_up";font.pixelSize:18} Opal.Glyph {name:"wifi";font.pixelSize:18}
                    Item {width:18;height:18
                        Opal.Glyph {anchors.centerIn:parent;name:"quiet";font.pixelSize:18}
                        Rectangle {x:12;y:-2;width:7;height:7;radius:4;color:Opal.Theme.error}}}}
            Rectangle {width:clockRow.implicitWidth+32;height:44;radius:22;color:Opal.Theme.primaryContainer;anchors.verticalCenter:parent.verticalCenter
                Row {id:clockRow;anchors.centerIn:parent;spacing:10
                    Opal.MText {text:"Wed 15";role:"label";color:Opal.Theme.containerInk;anchors.verticalCenter:parent.verticalCenter}
                    Opal.MText {text:"18:24";role:"titleS";font.weight:Font.Bold;color:Opal.Theme.containerInk;anchors.verticalCenter:parent.verticalCenter}}}
        }
    }
    Component {id:desktopView
        Item {
            id:dv
            readonly property bool card:!!fixture.current.card
            Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1920,1080);fillMode:Image.PreserveAspectCrop}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.18)}
            // ~/Desktop, as real files.
            Column {
                x:20;y:24;spacing:16
                Repeater {model:[{i:"md",t:"ROADMAP-2026-10.md"},{i:"png",t:"kris-sprite.png"},{i:"pdf",t:"AU1388.pdf"},{i:"folder",t:"Prints"},{i:"steam",t:"DELTARUNE"}]
                    AppCell {required property var modelData;width:96;size:48;i:modelData.i;t:modelData.t}}
            }
            // Widget canvas: placed freely, snapped to the grid.
            Glance {x:dv.width-420;y:40;big:30}
            PhotoW {x:dv.width-420;y:130;width:396;height:220}
            DevicesW {x:dv.width-420;y:366;width:190;height:190}
            Rectangle {x:dv.width-214;y:366;width:190;height:190;radius:28;color:Opal.Theme.alpha(Opal.Theme.level(2),.94)
                Column {anchors.centerIn:parent;spacing:4
                    Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:"18:24";font.pixelSize:44;font.weight:Font.Black}
                    Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:"Lisbon 19:24";role:"labelS";color:Opal.Theme.subtext}}}
            // The glance shows because this workspace is empty; it fades as soon as a window opens.
            Column {
                x:150;y:230;width:900;spacing:18
                Opal.MText {text:"Pick up where you left off";role:"displayS"}
                Opal.MText {text:"Workspace 3 is empty";role:"body";color:Opal.Theme.subtext}
                Row {
                    spacing:14;topPadding:6
                    Repeater {
                        model:[{i:"kate",t:"ROADMAP-2026-10.md",m:"Kate · 1 h ago"},{i:"steam",t:"DELTARUNE",m:"Paused 2 h ago",hero:true},{i:"google-chrome",t:"Hyprland Wiki",m:"Open on OnePlus 7",link:true},{i:"firefox",t:"The Keyboard Is Dead",m:"Paused at 4:12",media:true}]
                        Rectangle {
                            required property var modelData
                            width:214;height:148;radius:26;color:Opal.Theme.alpha(Opal.Theme.level(2),.94);clip:false
                            RArt {anchors.fill:parent;visible:!!modelData.hero||!!modelData.media;src:modelData.hero ? root.hero : root.art;r:26}
                            Rectangle {anchors.fill:parent;radius:26;visible:!!modelData.hero||!!modelData.media;color:Opal.Theme.alpha(Opal.Theme.base,.62)}
                            Column {x:16;y:16;width:parent.width-32;spacing:4
                                Ico {width:30;height:30;n:modelData.i}
                                Item {width:1;height:22}
                                Opal.MText {width:parent.width;text:modelData.t;role:"titleS"}
                                Row {spacing:6
                                    Opal.Glyph {visible:!!modelData.link;name:"smartphone";font.pixelSize:14;color:Opal.Theme.tertiary}
                                    Opal.MText {text:modelData.m;role:"labelS";color:Opal.Theme.subtext}}}
                        }
                    }
                }
            }
            Shelf {anchors.bottom:parent.bottom;anchors.bottomMargin:6;width:parent.width;cardOpen:dv.card}
            // The pill pops up into its card, anchored to the Shelf.
            ActCard {
                visible:dv.card;width:400;anchors.right:parent.right;anchors.rightMargin:18;anchors.bottom:parent.bottom;anchors.bottomMargin:82
                k:"agent";g:"terminal";t:"Claude Code needs you";s:"~/opal · Bash";meta:"now";code:"$ git push origin overhaul-2026-10"
                acts:[{g:"open_in_new"},{t:"Deny"},{t:"Allow",f:true}]
            }
            Row {
                visible:dv.card;anchors.right:parent.right;anchors.rightMargin:18;anchors.bottom:parent.bottom;anchors.bottomMargin:82+224;spacing:8
                CPill {k:"media";artSrc:root.art;t:"Keyboard Is Dead";bars:true}
                CPill {k:"neutral";g:"system_update";t:"42";prog:.61}}
        }
    }

    // ---------- Search: one component; minimal idle, inline answers, deep sources ----------
    Component {id:searchView
        Item {
            id:sv
            readonly property string q:fixture.current.q||""
            Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1600,1000);fillMode:Image.PreserveAspectCrop}
            Rectangle {anchors.fill:parent;color:Opal.Theme.alpha(Opal.Theme.base,.25)}
            Shelf {anchors.bottom:parent.bottom;anchors.bottomMargin:6;width:parent.width}
            Rectangle {
                x:72;anchors.bottom:parent.bottom;anchors.bottomMargin:78;width:640;height:panelCol.implicitHeight+28;radius:32;color:Opal.Theme.level(1)
                ColumnLayout {
                    id:panelCol;x:14;y:14;width:parent.width-28;spacing:14
                    Rectangle {
                        Layout.fillWidth:true;Layout.preferredHeight:56;radius:28;color:Opal.Theme.level(3)
                        RowLayout {anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:8;spacing:12
                            Opal.Glyph {name:"search";font.pixelSize:22}
                            Opal.MText {Layout.fillWidth:true;text:sv.q!=="" ? sv.q : "Search apps, files, settings or ask Claude";role:"body";font.pixelSize:16;color:sv.q!=="" ? Opal.Theme.text : Opal.Theme.subtext}
                            Rectangle {Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20;color:Opal.Theme.tertiaryContainer
                                Opal.Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:20;color:Opal.Theme.onTertiaryContainer}}}
                    }
                    // Idle: five frequent apps, then suggestion pills. Nothing else.
                    Row {
                        visible:sv.q==="";Layout.leftMargin:8;spacing:0
                        Repeater {model:[{i:"firefox",t:"Firefox"},{i:"kitty",t:"Terminal"},{i:"files",t:"Files"},{i:"steam",t:"Steam"},{i:"discord",t:"Discord"}]
                            AppCell {required property var modelData;width:118;size:48;i:modelData.i;t:modelData.t}}
                    }
                    Flow {visible:sv.q==="";Layout.fillWidth:true;Layout.leftMargin:4;Layout.bottomMargin:4;spacing:8
                        CPill {k:"neutral";g:"content_copy";t:"Copy 482913"}
                        CPill {k:"device";g:"smartphone";t:"Continue Hyprland Wiki"}
                        CPill {k:"neutral";g:"download_done";t:"Open kicad-9.0.2.tar.zst"}}
                    // A setting answers inline with its own switch.
                    Rectangle {
                        visible:sv.q==="dark";Layout.fillWidth:true;Layout.preferredHeight:72;radius:24;color:Opal.Theme.secondaryContainer
                        RowLayout {anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:18;spacing:14
                            Rectangle {Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20;color:Opal.Theme.alpha(Opal.Theme.onSecondaryContainer,.13)
                                Opal.Glyph {anchors.centerIn:parent;name:"dark_mode";font.pixelSize:22;color:Opal.Theme.onSecondaryContainer}}
                            ColumnLayout {Layout.fillWidth:true;spacing:0
                                Opal.MText {text:"Dark theme";role:"titleS";color:Opal.Theme.onSecondaryContainer}
                                Opal.MText {text:"Settings › Appearance · applies to Qt, GTK and Flatpak apps";role:"labelS";color:Opal.Theme.alpha(Opal.Theme.onSecondaryContainer,.75)}}
                            Rectangle {Layout.preferredWidth:52;Layout.preferredHeight:32;radius:16;color:Opal.Theme.primary
                                Rectangle {x:24;y:4;width:24;height:24;radius:12;color:Opal.Theme.onPrimary
                                    Opal.Glyph {anchors.centerIn:parent;name:"check";font.pixelSize:16;color:Opal.Theme.primary}}}}
                    }
                    Repeater {
                        model:sv.q==="dark" ? [
                            {h:"Settings"},{g:"schedule",t:"Dark theme schedule",s:"Sunset to sunrise"},
                            {h:"Files"},{i:"png",t:"dark-wallpaper.png",s:"~/Pictures/Wallpapers · 2 days ago"},
                            {h:"Media"},{i:"spotify",t:"Darkside",s:"Neoni · in your library"},
                            {h:"Games"},{i:"steam",t:"Darkest Dungeon",s:"Steam · 41 h played"}
                        ] : []
                        Item {
                            required property var modelData
                            Layout.fillWidth:true;Layout.preferredHeight:modelData.h ? 22 : 50
                            Opal.MText {visible:!!modelData.h;x:8;anchors.bottom:parent.bottom;text:modelData.h||"";role:"labelS";font.letterSpacing:1;color:Opal.Theme.primary}
                            RowLayout {visible:!modelData.h;anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:10;spacing:14
                                Item {Layout.preferredWidth:32;Layout.preferredHeight:32
                                    Ico {anchors.fill:parent;visible:!!modelData.i;n:modelData.i||""}
                                    Opal.Glyph {anchors.centerIn:parent;visible:!modelData.i;name:modelData.g||"";font.pixelSize:22;color:Opal.Theme.primary}}
                                ColumnLayout {Layout.fillWidth:true;spacing:0
                                    Opal.MText {Layout.fillWidth:true;text:modelData.t||"";role:"titleS"} Opal.MText {Layout.fillWidth:true;text:modelData.s||"";role:"labelS";color:Opal.Theme.subtext}}}
                        }
                    }
                    // Claude answers inline; the panel continues the conversation.
                    Rectangle {
                        visible:sv.q.startsWith("how");Layout.fillWidth:true;Layout.preferredHeight:claudeCol.implicitHeight+32;radius:26;color:Opal.Theme.tertiaryContainer
                        ColumnLayout {
                            id:claudeCol;x:18;y:16;width:parent.width-36;spacing:12
                            Row {spacing:10
                                Opal.Glyph {name:"auto_awesome";font.pixelSize:20;color:Opal.Theme.onTertiaryContainer}
                                Opal.MText {text:"Claude";role:"titleS";color:Opal.Theme.onTertiaryContainer}}
                            Opal.MText {
                                Layout.fillWidth:true;wrapMode:Text.Wrap;maximumLineCount:4;role:"body";color:Opal.Theme.onTertiaryContainer
                                text:"Open Settings › Appearance › Window gaps and drag Inner and Outer down. Opal writes the new values to its Hyprland include, so it applies right away. 4 px inner and 6 px outer is a tight but still readable layout."
                            }
                            Row {Layout.alignment:Qt.AlignRight;spacing:8
                                Btn {g:"tune";t:"Open Window gaps";ink:Opal.Theme.onTertiaryContainer;color:Opal.Theme.alpha(Opal.Theme.onTertiaryContainer,.13)}
                                Btn {g:"forum";t:"Continue in panel";ink:Opal.Theme.tertiaryContainer;color:Opal.Theme.onTertiaryContainer}}
                        }
                    }
                    Repeater {
                        model:sv.q.startsWith("how") ? [{h:"Settings"},{g:"view_quilt",t:"Window gaps",s:"Inner 5 px · Outer 8 px"},{g:"rounded_corner",t:"Window corners",s:"16 px"}] : []
                        Item {
                            required property var modelData
                            Layout.fillWidth:true;Layout.preferredHeight:modelData.h ? 22 : 50
                            Opal.MText {visible:!!modelData.h;x:8;anchors.bottom:parent.bottom;text:modelData.h||"";role:"labelS";font.letterSpacing:1;color:Opal.Theme.primary}
                            RowLayout {visible:!modelData.h;anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:10;spacing:14
                                Opal.Glyph {Layout.preferredWidth:32;name:modelData.g||"";font.pixelSize:22;color:Opal.Theme.primary}
                                ColumnLayout {Layout.fillWidth:true;spacing:0
                                    Opal.MText {Layout.fillWidth:true;text:modelData.t||"";role:"titleS"} Opal.MText {Layout.fillWidth:true;text:modelData.s||"";role:"labelS";color:Opal.Theme.subtext}}}
                        }
                    }
                }
            }
        }
    }

    // ---------- Floating mode (opt-in): Opal titlebars, snap layouts, real minimize ----------
    component Win:Rectangle {
        id:w
        property string i:"firefox"
        property string t:""
        property bool focused:true
        property bool hoverMax:false
        radius:16;color:Opal.Theme.level(1);border.width:1;border.color:focused ? Opal.Theme.alpha(Opal.Theme.primary,.5) : Opal.Theme.outline
        Rectangle {width:parent.width;height:42;radius:16;color:w.focused ? Opal.Theme.level(3) : Opal.Theme.level(2)
            Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:16;color:parent.color}
            RowLayout {anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:8;spacing:10
                Ico {Layout.preferredWidth:20;Layout.preferredHeight:20;n:w.i}
                Opal.MText {Layout.fillWidth:true;text:w.t;role:"label";font.pixelSize:13;color:w.focused ? Opal.Theme.text : Opal.Theme.subtext}
                Repeater {model:[{g:"remove"},{g:"crop_square",max:true},{g:"close",close:true}]
                    Rectangle {required property var modelData;Layout.preferredWidth:30;Layout.preferredHeight:30;radius:15
                        color:modelData.max&&w.hoverMax ? Opal.Theme.primaryContainer : modelData.close ? Opal.Theme.alpha(Opal.Theme.error,.16) : Opal.Theme.alpha(Opal.Theme.text,.08)
                        Opal.Glyph {anchors.centerIn:parent;name:modelData.g;font.pixelSize:16;color:modelData.close ? Opal.Theme.error : modelData.max&&w.hoverMax ? Opal.Theme.containerInk : Opal.Theme.text}}}
            }
        }
    }
    Component {id:floatingView
        Item {
            id:fv
            Image {anchors.fill:parent;source:root.wall;sourceSize:Qt.size(1920,1080);fillMode:Image.PreserveAspectCrop}
            Win {
                id:fx;x:640;y:80;width:760;height:520;i:"firefox";t:"Hyprland Wiki — Firefox";hoverMax:true;focused:false
                Column {x:24;y:66;width:parent.width-48;spacing:12
                    Rectangle {width:parent.width*.5;height:22;radius:6;color:Opal.Theme.level(3)}
                    Repeater {model:7;Rectangle {width:fx.width-48-(index%3)*90;height:10;radius:5;color:Opal.Theme.level(2)}}}
            }
            // Snap layouts grow out of the maximize button on hover.
            Rectangle {
                x:fx.x+fx.width-260;y:fx.y+44;width:236;height:snapGrid.implicitHeight+28;radius:24;color:Opal.Theme.level(3)
                border.width:1;border.color:Opal.Theme.outline
                Grid {
                    id:snapGrid;anchors.centerIn:parent;columns:3;spacing:10
                    Repeater {
                        model:[[[0,0,.5,1],[.5,0,.5,1]],[[0,0,.66,1],[.66,0,.34,1]],[[0,0,.33,1],[.33,0,.34,1],[.67,0,.33,1]],[[0,0,.5,1],[.5,0,.5,.5],[.5,.5,.5,.5]],[[0,0,.5,.5],[.5,0,.5,.5],[0,.5,.5,.5],[.5,.5,.5,.5]],[[0,0,.25,1],[.25,0,.5,1],[.75,0,.25,1]]]
                        Item {
                            required property var modelData;required property int index
                            width:62;height:42
                            Repeater {model:parent.modelData
                                Rectangle {required property var modelData;required property int index
                                    x:modelData[0]*62+1.5;y:modelData[1]*42+1.5;width:modelData[2]*62-3;height:modelData[3]*42-3;radius:6
                                    color:parent.index===0&&index===1 ? Opal.Theme.primary : Opal.Theme.alpha(Opal.Theme.text,.16)}}
                        }
                    }
                }
            }
            Win {x:1060;y:420;width:480;height:300;i:"spotify";t:"Spotify";focused:false}
            // The terminal is being dragged to the left edge: the half it will fill lights up under it.
            Rectangle {x:12;y:12;width:fv.width/2-18;height:fv.height-96;radius:18;color:Opal.Theme.alpha(Opal.Theme.primary,.16);border.width:2;border.color:Opal.Theme.alpha(Opal.Theme.primary,.7)}
            Win {
                x:-40;y:250;width:600;height:400;i:"kitty";t:"kitty — ~/opal";rotation:-1.2
                Column {x:16;y:56;spacing:4
                    Repeater {model:["~/opal $ opal floating on","Floating mode on · titlebars by Opal","~/opal $ _"]
                        Text {required property string modelData;text:modelData;color:Opal.Theme.text;font.family:"CaskaydiaCove Nerd Font";font.pixelSize:13}}}
                Opal.Glyph {x:250;y:12;name:"drag_pan";font.pixelSize:26;color:Opal.Theme.text}
            }
            Rectangle {x:fv.width/4-90;y:120;width:180;height:36;radius:18;color:Opal.Theme.primary
                Opal.MText {anchors.centerIn:parent;text:"Release to snap left";role:"label";font.weight:Font.Bold;color:Opal.Theme.onPrimary}}
            Shelf {anchors.bottom:parent.bottom;anchors.bottomMargin:6;width:parent.width}
            // Minimized windows live on the Shelf; hovering shows a preview.
            Rectangle {
                x:18+8+42+8+200+8+4*52-28;anchors.bottom:parent.bottom;anchors.bottomMargin:76;width:220;height:170;radius:22;color:Opal.Theme.level(3)
                Rectangle {x:10;y:10;width:parent.width-20;height:116;radius:14;color:Opal.Theme.level(1)
                    Column {x:10;y:12;spacing:8;Repeater {model:4;Rectangle {width:150-index*20;height:8;radius:4;color:Opal.Theme.level(3)}}}}
                Row {x:14;y:136;spacing:8
                    Ico {width:20;height:20;n:"files"}
                    Opal.MText {text:"Files — Downloads";role:"label";anchors.verticalCenter:parent.verticalCenter}}
                Opal.MText {anchors.right:parent.right;anchors.rightMargin:14;y:138;text:"Minimized";role:"labelS";color:Opal.Theme.subtext}
            }
        }
    }
}
