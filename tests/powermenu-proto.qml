import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Round 5 (2026-10-21): the power-button menu. Tap power opens it, volume keys move, power picks. Static data only.
// OPAL_VIDEO=1 saves frames of the three list motions side by side instead of the stills.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string home:"file:///home/melissa/.local/state/opal/artifacts/launcher-prototypes/round4/r4-01-phone-home.png"
    readonly property string wall:"file:///home/melissa/Pictures/Wallpapers/default.png"
    readonly property bool video:Quickshell.env("OPAL_VIDEO")==="1"

    readonly property var topItems:[
        {g:"devices",t:"Displays",s:"Phone mode",sub:true,locked:true},
        {g:"contacts",t:"Contacts",s:"4 favourites",sub:true,locked:true},
        {g:"bedtime",t:"Sleep",s:"",sub:false},
        {g:"power_settings_new",t:"Power",s:"",sub:true},
        {g:"play_circle",t:"Media",s:"The Keyboard Is Dead",sub:true},
        {g:"switch_account",t:"Switch user",s:"",sub:false,locked:true}]
    // A user-customised top level: extra quick actions mixed in with the defaults.
    readonly property var customItems:[
        {g:"flashlight_on",t:"Flashlight",s:"On",on:true},
        {g:"screenshot_region",t:"Screenshot",s:"Whole screen"},
        {g:"bedtime",t:"Sleep",s:"",sub:false},
        {g:"power_settings_new",t:"Power",s:"",sub:true},
        {g:"play_circle",t:"Media",s:"The Keyboard Is Dead",sub:true},
        {g:"devices",t:"Displays",s:"Phone mode",sub:true},
        {g:"contacts",t:"Contacts",s:"4 favourites",sub:true},
        {g:"auto_awesome",t:"Ask Claude",s:"Hold to talk"},
        {g:"folder",t:"Toggles",s:"Wi-Fi, DND, rotation lock",sub:true},
        {g:"terminal",t:"Sync dotfiles",s:"~/bin/dots-sync"},
        {g:"switch_account",t:"Switch user",s:"",sub:false}]
    readonly property var powerItems:[
        {g:"arrow_back",t:"Back",back:true},
        {g:"restart_alt",t:"Restart"},
        {g:"power_settings_new",t:"Shut down",danger:true},
        {g:"logout",t:"Log out"},
        {g:"lock",t:"Lock"}]
    readonly property var displayItems:[
        {g:"arrow_back",t:"Back",back:true},
        {g:"smartphone",t:"Phone",group:"Mode",on:true},
        {g:"tablet",t:"Tablet"},
        {g:"desktop_windows",t:"Desktop"},
        {g:"sports_esports",t:"Game"},
        {g:"screen_share",t:"Mirror",group:"Outputs · Living room TV"},
        {g:"splitscreen_right",t:"Extend",on:true},
        {g:"cast",t:"Cast…"}]

    Window {
        id:fixture
        width:480;height:960;visible:true;color:"#0b0a0d"
        property int step:0
        property int frame:0
        property var cases:[
            {name:"p5-01-drum-edge",style:"drum",place:"edge",pos:2,ring:.62},
            {name:"p5-02-list-edge",style:"list",place:"edge",pos:2,ring:.62},
            {name:"p5-03-wrap-edge",style:"wrap",place:"edge",pos:0,ring:-1},
            {name:"p5-04-drum-centre",style:"drum",place:"centre",pos:2,ring:.62},
            {name:"p5-05-drum-full",style:"drum",place:"full",pos:2,ring:.62},
            {name:"p5-06-list-centre",style:"list",place:"centre",pos:2,ring:.62},
            {name:"p5-07-list-full",style:"list",place:"full",pos:2,ring:.62},
            {name:"p5-08-power-submenu",style:"drum",place:"edge",pos:1,ring:-1,items:"power"},
            {name:"p5-09-displays-submenu",style:"drum",place:"edge",pos:2,ring:-1,items:"displays"},
            {name:"p5-10-locked",style:"drum",place:"edge",pos:2,ring:-1,locked:true},
            {name:"p5-11-custom-menu",style:"drum",place:"edge",pos:2,ring:.3,items:"custom"},
            {name:"p5-12-settings-editor",view:"settings"},
            {name:"p5-13-add-action",view:"catalog"}
        ]
        property var current:cases[0]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            current=cases[step];
            loader.sourceComponent=null;loader.sourceComponent=current.view==="settings" ? settingsView : current.view==="catalog" ? catalogView : still;
            grab.restart();
        }
        Timer {id:grab;interval:1800;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}

        // Video timeline at 30 fps: open, countdown, cancel by volume, walk down, walk up past the top.
        readonly property int total:300
        function ease(t) {t=Math.max(0,Math.min(1,t));return t<.5 ? 4*t*t*t : 1-Math.pow(-2*t+2,3)/2;}
        // Each key press is [frame, delta]. Steps animate over 7 frames.
        readonly property var presses:[[80,1],[110,1],[150,-1],[175,-1],[200,-1],[225,-1],[250,-1]]
        function posAt(f) {let p=2;for(const k of presses){p+=k[1]*ease((f-k[0])/7);}return p;}
        function keyAt(f) {for(const k of presses){if(f>=k[0]-2&&f<k[0]+6)return k[1]>0 ? "down" : "up";}return "";}
        function vframe() {
            const f=frame;
            const open=ease(f/12), ring=f<80 ? Math.min(1,Math.max(0,(f-14)/60))*.85 : -1;
            for(const s of [vd,vl,vw]){s.open=open;s.pos=posAt(f);s.ring=f>=14 ? ring : -1;s.key=keyAt(f);}
            vgrab.restart();
        }
        Timer {id:vgrab;interval:40;onTriggered:fixture.contentItem.grabToImage(r=>{
            r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/frame-"+String(fixture.frame).padStart(4,"0")+".png");
            fixture.frame++;
            if(fixture.frame>=fixture.total){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();}else fixture.vframe();})}
        Component.onCompleted:{
            if(root.video){fixture.width=1440;fixture.height=1000;loader.sourceComponent=videoView;vstart.start();}
            else Qt.callLater(run);
        }
        Timer {id:vstart;interval:1500;onTriggered:fixture.vframe()}
        property Item vd;property Item vl;property Item vw
    }

    Component {id:still
        Device {anchors.fill:parent;style:fixture.current.style||"drum";place:fixture.current.place||"edge";pos:fixture.current.pos||0;ring:fixture.current.ring===undefined ? -1 : fixture.current.ring
            locked:!!fixture.current.locked;which:fixture.current.items||"top"}
    }
    Component {id:videoView
        Item {
            Row {
                anchors.centerIn:parent;spacing:0
                Repeater {
                    model:[{s:"drum",t:"Drum picker"},{s:"list",t:"Fixed list, moving highlight"},{s:"wrap",t:"Wrap-around drum"}]
                    Column {
                        required property var modelData
                        spacing:6
                        Device {
                            id:dv;width:480;height:960;style:modelData.s;place:"edge";pos:2;ring:-1;open:0
                            Component.onCompleted:{if(modelData.s==="drum")fixture.vd=dv;else if(modelData.s==="list")fixture.vl=dv;else fixture.vw=dv;}
                        }
                        Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:modelData.t;role:"title";color:"#ffffff";y:-30}
                    }
                }
            }
        }
    }

    // A OnePlus 7 shaped body: volume rocker on the left, alert slider and power key on the right.
    Component {id:settingsView;Frame {SettingsPage {anchors.fill:parent}}}
    Component {id:catalogView
        Frame {
            SettingsPage {anchors.fill:parent}
            CatalogSheet {anchors.fill:parent}
        }
    }

    // Same body as Device, around arbitrary screen content.
    component Frame:Item {
        id:fr
        default property alias content:scr.data
        anchors.fill:parent
        Rectangle {x:12;y:196;width:8;height:160;radius:3;color:"#2a272e"}
        Rectangle {x:parent.width-20;y:150;width:8;height:56;radius:3;color:"#2a272e"}
        Rectangle {x:parent.width-20;y:304;width:8;height:76;radius:3;color:"#3a2f2a"}
        Rectangle {
            x:18;y:12;width:parent.width-36;height:parent.height-24;radius:52;color:"#141216";border.width:2;border.color:"#2a272e"
            Item {id:scr;x:16;y:16;width:412;height:900;clip:true}
        }
    }
    component SBar:Item {
        height:40
        Opal.MText {x:22;anchors.verticalCenter:parent.verticalCenter;text:"18:24";role:"label";font.pixelSize:14;font.weight:Font.DemiBold}
        Row {anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;spacing:6
            Opal.Glyph {name:"wifi";font.pixelSize:17}
            Opal.Glyph {name:"battery_5_bar";font.pixelSize:17}
            Opal.MText {text:"76%";role:"label";anchors.verticalCenter:parent.verticalCenter}}
    }
    component Chip2:Rectangle {
        property string g:""
        property string t:""
        property bool on:false
        property bool added:false
        implicitWidth:cr.implicitWidth+28;implicitHeight:36;radius:12
        color:on ? Opal.Theme.secondaryContainer : "transparent"
        border.width:on ? 0 : 1;border.color:Opal.Theme.alpha(Opal.Theme.text,.22)
        Row {id:cr;anchors.centerIn:parent;spacing:6
            Opal.Glyph {name:parent.parent.added ? "check" : parent.parent.g;font.pixelSize:18;color:parent.parent.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:parent.parent.t;role:"label";font.pixelSize:13;font.weight:Font.DemiBold;color:parent.parent.on ? Opal.Theme.onSecondaryContainer : Opal.Theme.text;anchors.verticalCenter:parent.verticalCenter}}
    }
    component Seg:Row {
        id:sg
        property var opts:[]
        property int at:0
        spacing:3
        Repeater {model:sg.opts
            Rectangle {required property var modelData;required property int index
                width:(sg.width-3*(sg.opts.length-1))/sg.opts.length;height:40
                topLeftRadius:index===0 ? 20 : 6;bottomLeftRadius:index===0 ? 20 : 6
                topRightRadius:index===sg.opts.length-1 ? 20 : 6;bottomRightRadius:index===sg.opts.length-1 ? 20 : 6
                color:index===sg.at ? Opal.Theme.primary : Opal.Theme.level(3)
                Opal.MText {anchors.centerIn:parent;text:modelData;role:"label";font.pixelSize:13;font.weight:Font.DemiBold;color:index===sg.at ? Opal.Theme.onPrimary : Opal.Theme.text}}}
    }

    // Settings › Power key: the editable menu, what it starts on, the countdown and other presses.
    component SettingsPage:Rectangle {
        color:Opal.Theme.base
        SBar {width:parent.width;y:4}
        Row {x:12;y:52;spacing:8
            Rectangle {width:44;height:44;radius:22;color:"transparent";Opal.Glyph {anchors.centerIn:parent;name:"arrow_back"}}
            Opal.MText {text:"Power key";role:"headline";anchors.verticalCenter:parent.verticalCenter}}
        Column {
            x:16;y:112;width:parent.width-32;spacing:10
            Opal.MText {text:"MENU";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2}
            Rectangle {
                width:parent.width;height:mc.implicitHeight+12;radius:24;color:Opal.Theme.level(2)
                Column {id:mc;x:6;y:6;width:parent.width-12
                    Repeater {model:root.customItems.slice(0,8)
                        Rectangle {required property var modelData;required property int index
                            width:mc.width;height:46;radius:16;color:modelData.t==="Sleep" ? Opal.Theme.alpha(Opal.Theme.primary,.12) : "transparent"
                            RowLayout {anchors.fill:parent;anchors.leftMargin:8;anchors.rightMargin:8;spacing:12
                                Opal.Glyph {name:"drag_indicator";font.pixelSize:20;color:Opal.Theme.muted}
                                Opal.Glyph {name:modelData.g;font.pixelSize:20;color:Opal.Theme.primary}
                                Opal.MText {Layout.fillWidth:true;text:modelData.t;role:"body"}
                                Rectangle {visible:modelData.t==="Sleep";width:st.implicitWidth+16;height:24;radius:12;color:Opal.Theme.primaryContainer
                                    Opal.MText {id:st;anchors.centerIn:parent;text:"Starts here";role:"labelS";color:Opal.Theme.containerInk}}
                                Opal.Glyph {visible:!!modelData.sub;name:"chevron_right";font.pixelSize:20;color:Opal.Theme.muted}
                                Opal.Glyph {visible:!modelData.sub&&modelData.t!=="Sleep";name:"remove_circle_outline";font.pixelSize:20;color:Opal.Theme.muted}}}}
                    Opal.MText {x:46;height:30;verticalAlignment:Text.AlignVCenter;text:"+ 3 more";role:"bodyS";color:Opal.Theme.subtext}
                }
            }
            Row {spacing:8
                Rectangle {width:ad.implicitWidth+32;height:40;radius:20;color:Opal.Theme.primary
                    Row {id:ad;anchors.centerIn:parent;spacing:6
                        Opal.Glyph {name:"add";font.pixelSize:20;color:Opal.Theme.onPrimary}
                        Opal.MText {text:"Add action";role:"label";font.pixelSize:13;font.weight:Font.DemiBold;color:Opal.Theme.onPrimary;anchors.verticalCenter:parent.verticalCenter}}}
                Chip2 {g:"create_new_folder";t:"New submenu";height:40}
                Chip2 {g:"restart_alt";t:"Reset";height:40}
            }
            Opal.MText {text:"COUNTDOWN TO SLEEP";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2;topPadding:8}
            Seg {width:parent.width;opts:["Off","1 s","2 s","3 s"];at:2}
            Opal.MText {text:"OTHER PRESSES";role:"labelS";color:Opal.Theme.primary;font.letterSpacing:1.2;topPadding:8}
            Rectangle {
                width:parent.width;height:oc.implicitHeight+12;radius:24;color:Opal.Theme.level(2)
                Column {id:oc;x:14;y:6;width:parent.width-28
                    Repeater {model:[{t:"Double-press",v:"Flashlight"},{t:"Hold",v:"Ask Claude"},{t:"Power + volume down",v:"Screenshot"}]
                        RowLayout {required property var modelData;width:oc.width;height:48
                            Opal.MText {Layout.fillWidth:true;text:modelData.t;role:"body"}
                            Opal.MText {text:modelData.v;role:"body";color:Opal.Theme.subtext}
                            Opal.Glyph {name:"unfold_more";font.pixelSize:18;color:Opal.Theme.muted}}}}
            }
        }
    }

    // Add action: a sheet of chips grouped by kind, plus custom commands and apps.
    component CatalogSheet:Item {
        Rectangle {anchors.fill:parent;color:"#000000";opacity:.45}
        Rectangle {
            x:0;y:parent.height-height;width:parent.width;height:cc.implicitHeight+40;topLeftRadius:32;topRightRadius:32;color:Opal.Theme.level(1)
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:10;width:36;height:4;radius:2;color:Opal.Theme.alpha(Opal.Theme.text,.35)}
            Column {
                id:cc;x:18;y:28;width:parent.width-36;spacing:10
                Opal.MText {text:"Add action";role:"title"}
                Rectangle {width:parent.width;height:44;radius:22;color:Opal.Theme.level(3)
                    Row {x:14;anchors.verticalCenter:parent.verticalCenter;spacing:10
                        Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext}
                        Opal.MText {text:"Search actions, apps, settings";role:"body";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                Repeater {
                    model:[
                        {h:"Device",c:[["flashlight_on","Flashlight",1],["screen_rotation","Rotation lock"],["airplanemode_active","Airplane"],["do_not_disturb_on","Do not disturb"],["wifi_tethering","Hotspot"],["coffee","Keep awake"],["vibration","Ring / vibrate"]]},
                        {h:"Capture",c:[["screenshot_region","Screenshot",1],["screen_record","Record screen"],["photo_camera","Camera"],["mic","Voice memo"]]},
                        {h:"Shell",c:[["auto_awesome","Ask Claude",1],["search","Search"],["notifications","Notifications"],["tune","Quick settings"],["content_paste","Clipboard"],["sports_esports","Game mode"],["lock","Lock"]]},
                        {h:"Media & people",c:[["play_circle","Media"],["contacts","Contacts"],["volume_up","Output"],["cast","Cast"]]},
                        {h:"Yours",c:[["apps","Open app…"],["terminal","Run command…"],["link","Open link…"],["create_new_folder","Submenu…"]]}]
                    Column {required property var modelData;width:cc.width;spacing:8
                        Opal.MText {text:modelData.h;role:"label";color:Opal.Theme.subtext;topPadding:4}
                        Flow {width:parent.width;spacing:8
                            Repeater {model:modelData.c;Chip2 {required property var modelData;g:modelData[0];t:modelData[1];on:!!modelData[2];added:!!modelData[2]}}}}
                }
            }
        }
    }

    component Device:Item {
        id:dev
        property string style:"drum"
        property string place:"edge"
        property real pos:2
        property real ring:-1
        property real open:1
        property bool locked:false
        property string which:"top"
        property string key:""
        readonly property var items:which==="custom" ? root.customItems : which==="power" ? root.powerItems : which==="displays" ? root.displayItems : root.topItems
        // Hardware keys in screen coordinates.
        readonly property real volUpY:236
        readonly property real volDownY:316
        readonly property real powerY:330
        Rectangle {x:12;y:volUpY-40;width:8;height:160;radius:3;color:"#2a272e"}
        Rectangle {x:12;y:volUpY-40;width:8;height:80;radius:3;color:dev.key==="up" ? Opal.Theme.primary : "#2a272e"}
        Rectangle {x:12;y:volUpY+40;width:8;height:80;radius:3;color:dev.key==="down" ? Opal.Theme.primary : "#2a272e"}
        Rectangle {x:parent.width-20;y:150;width:8;height:56;radius:3;color:"#2a272e"}
        Rectangle {x:parent.width-20;y:dev.powerY-26;width:8;height:76;radius:3;color:"#3a2f2a"}
        Rectangle {
            id:body;x:18;y:12;width:parent.width-36;height:parent.height-24;radius:52;color:"#141216"
            border.width:2;border.color:"#2a272e"
            Item {
                id:screen;x:16;y:16;width:412;height:900;clip:true
                Image {anchors.fill:parent;source:dev.locked ? root.wall : root.home;fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(412,915)}
                LockFace {anchors.fill:parent;visible:dev.locked}
                Rectangle {anchors.fill:parent;color:"#000000";opacity:dev.open*(dev.place==="full" ? .7 : dev.place==="centre" ? .55 : .45)}
                Rectangle {anchors.fill:parent;visible:dev.place==="full";color:Opal.Theme.base;opacity:dev.open*.82}

                // Hints sit at the physical keys while the menu is open.
                KeyHint {x:8;y:dev.volUpY-16-16;g:"keyboard_arrow_up";opacity:dev.open;lit:dev.key==="up"}
                KeyHint {x:8;y:dev.volDownY-16-16;g:"keyboard_arrow_down";opacity:dev.open;lit:dev.key==="down"}
                KeyHint {x:screen.width-40;y:dev.powerY-16-16+12;g:"radio_button_checked";opacity:dev.open;visible:dev.place!=="edge"}

                Menu {
                    id:menu
                    style:dev.style;place:dev.place;pos:dev.pos;ring:dev.ring;items:dev.items;locked:dev.locked;which:dev.which
                    width:dev.place==="edge" ? 262 : dev.place==="centre" ? 316 : screen.width
                    height:dev.place==="full" ? screen.height : implicitHeight
                    x:dev.place==="edge" ? screen.width-width-12+(1-dev.open)*(width+20) : (screen.width-width)/2
                    y:dev.place==="edge" ? Math.max(70,Math.min(screen.height-height-30,dev.powerY-16-height*.45)) : dev.place==="centre" ? (screen.height-height)/2 : 0
                    opacity:dev.place==="edge" ? 1 : dev.open
                    scale:dev.place==="centre" ? .92+.08*dev.open : 1
                }
            }
        }
    }

    component KeyHint:Rectangle {
        property string g:""
        property bool lit:false
        width:32;height:32;radius:16
        color:lit ? Opal.Theme.primary : Opal.Theme.alpha(Opal.Theme.level(3),.92)
        Opal.Glyph {anchors.centerIn:parent;name:parent.g;font.pixelSize:20;color:parent.lit ? Opal.Theme.onPrimary : Opal.Theme.text}
    }

    component LockFace:Item {
        Column {
            anchors.horizontalCenter:parent.horizontalCenter;y:120;spacing:4
            Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:"18:24";role:"displayL";font.pixelSize:96;color:"#ffffff"}
            Opal.MText {anchors.horizontalCenter:parent.horizontalCenter;text:"Wednesday, 21 October";role:"title";color:"#ffffff"}
        }
        Opal.Glyph {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:60;name:"lock";font.pixelSize:26;color:"#ffffff"}
    }

    // Countdown ring around the Sleep icon.
    component Ring:Canvas {
        property real value:.6
        property color ink:Opal.Theme.primary
        property real lw:3
        onValueChanged:requestPaint()
        Component.onCompleted:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();if(value<0)return;const r=Math.min(width,height)/2-lw/2-1;
            c.lineWidth=lw;c.lineCap="round";c.strokeStyle=String(ink);
            c.globalAlpha=.25;c.beginPath();c.arc(width/2,height/2,r,0,2*Math.PI);c.stroke();
            c.globalAlpha=1;c.beginPath();c.arc(width/2,height/2,r,-Math.PI/2,-Math.PI/2+2*Math.PI*value);c.stroke();
        }
    }

    // One menu row. sel is 0..1 so the highlight can fade between rows while moving.
    component Row1:Item {
        id:r
        property var d:({})
        property real sel:0
        property real ring:-1
        property bool big:false
        property bool locked:false
        property bool onPanel:true
        readonly property bool isLocked:locked&&!!d.locked
        readonly property color ink:Opal.Theme.mix(Opal.Theme.text,d.danger ? Opal.Theme.error : Opal.Theme.containerInk,sel)
        height:big ? 82 : 54
        RowLayout {
            anchors.fill:parent;anchors.leftMargin:big ? 28 : 12;anchors.rightMargin:big ? 28 : 14;spacing:big ? 18 : 14
            Item {
                Layout.preferredWidth:big ? 44 : 36;Layout.preferredHeight:big ? 44 : 36
                Rectangle {anchors.fill:parent;radius:width/2;color:Opal.Theme.alpha(r.d.danger ? Opal.Theme.error : Opal.Theme.primary,.16+.0*r.sel);visible:r.sel>.5||r.big}
                Opal.Glyph {anchors.centerIn:parent;name:r.d.g||"";font.pixelSize:r.big ? 26 : 22;color:r.d.danger ? Opal.Theme.error : r.sel>.5 ? r.ink : Opal.Theme.primary;opacity:r.isLocked ? .45 : 1}
                Ring {anchors.fill:parent;anchors.margins:-4;visible:r.ring>=0;value:r.ring;lw:3.2;ink:Opal.Theme.containerInk}
            }
            ColumnLayout {
                Layout.fillWidth:true;spacing:0
                Opal.MText {Layout.fillWidth:true;text:r.d.t||"";role:r.big ? "displayS" : "title";color:r.ink;opacity:r.isLocked ? .5 : 1
                    font.pixelSize:r.big ? 30+8*r.sel : 17}
                Opal.MText {Layout.fillWidth:true;visible:text!=="";role:"bodyS";color:Opal.Theme.alpha(r.ink,.72)
                    text:r.ring>=0&&r.sel>.5 ? "Sleeping in "+Math.max(1,Math.ceil((1-r.ring)*2.5))+" s" : r.isLocked ? "Unlock to use" : (r.d.s||"")}
            }
            Opal.Glyph {visible:!!r.d.sub||r.isLocked||!!r.d.on;name:r.isLocked ? "lock" : r.d.on ? "check" : "chevron_right";font.pixelSize:20;color:Opal.Theme.alpha(r.ink,.8)}
        }
    }

    component Menu:Item {
        id:m
        property string style:"drum"
        property string place:"edge"
        property string which:"top"
        property real pos:2
        property real ring:-1
        property var items:[]
        property bool locked:false
        readonly property bool big:place==="full"
        readonly property real rowH:big ? 82 : 54
        readonly property int n:items.length
        readonly property int visibleRows:style==="list" ? n : 5
        readonly property real header:which==="top"||which==="custom" ? 0 : 44
        implicitHeight:header+(style==="list" ? n*rowH : visibleRows*rowH)+16
        // Wrapped selection index for highlight and ring.
        function wrapIndex(p) {return ((Math.round(p)%n)+n)%n;}
        readonly property real clampPos:style==="wrap" ? pos : Math.max(0,Math.min(n-1,pos))

        Rectangle {
            anchors.fill:parent;visible:m.place!=="full";radius:30
            color:Opal.Theme.level(3);border.width:1;border.color:Opal.Theme.outline
        }
        Opal.MText {
            visible:m.header>0;x:m.big ? 28 : 18;y:m.big ? 120 : 14;text:m.which==="power" ? "Power" : "Displays";role:"label";color:Opal.Theme.subtext
            font.capitalization:Font.AllUppercase;font.letterSpacing:1.2
        }
        Opal.MText {
            visible:m.big;x:28;y:70;text:m.which==="top"||m.which==="custom" ? "Power key" : "";role:"label";color:Opal.Theme.subtext
            font.capitalization:Font.AllUppercase;font.letterSpacing:1.2
        }
        Item {
            id:view
            x:m.big ? 0 : 8;width:parent.width-(m.big ? 0 : 16)
            y:m.big ? (parent.height-height)/2 : 8+m.header;height:parent.height-(m.big ? 0 : 16+m.header)
            clip:true
            readonly property real centreY:m.style==="list" ? 0 : height/2-m.rowH/2

            // Fixed highlight in the centre for the drums; a moving one for the list.
            Rectangle {
                x:m.big ? 14 : 0;width:parent.width-(m.big ? 28 : 0);height:m.rowH;radius:m.rowH/2
                y:m.style==="list" ? m.clampPos*m.rowH+(m.big ? (view.height-m.n*m.rowH)/2 : 0) : view.centreY
                color:(m.items[m.wrapIndex(m.clampPos)]||{}).danger ? Opal.Theme.alpha(Opal.Theme.error,.22) : Opal.Theme.primaryContainer
            }
            Repeater {
                // Wrap renders the list three times so rows exist above the first item.
                model:m.style==="wrap" ? m.n*3 : m.n
                Row1 {
                    required property int index
                    readonly property int i:m.style==="wrap" ? index-m.n : index
                    readonly property real dist:Math.abs(i-m.clampPos)
                    readonly property real slot:m.style==="list" ? i*m.rowH+(m.big ? (view.height-m.n*m.rowH)/2 : 0) : view.centreY+(i-m.clampPos)*m.rowH
                    d:m.items[((i%m.n)+m.n)%m.n]
                    width:view.width;y:slot;big:m.big;locked:m.locked
                    sel:Math.max(0,1-dist)
                    ring:dist<.5&&(m.items[((i%m.n)+m.n)%m.n]||{}).t==="Sleep" ? m.ring : -1
                    opacity:m.style==="list" ? 1 : Math.max(0,1-Math.max(0,dist-.6)*.36)
                    visible:slot>-m.rowH&&slot<view.height
                }
            }
            // A thin seam marks where the wrapped list starts over.
            Repeater {
                model:m.style==="wrap" ? 3 : 0
                Rectangle {
                    required property int index
                    readonly property real sy:view.centreY+((index-1)*m.n-m.clampPos)*m.rowH
                    x:40;width:view.width-80;height:1;y:sy-.5;color:Opal.Theme.alpha(Opal.Theme.text,.18)
                    visible:sy>2&&sy<view.height-2
                }
            }
        }
        Opal.MText {
            visible:m.big;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:70
            text:"Volume keys move · power picks";role:"label";color:Opal.Theme.subtext
        }
    }
}
