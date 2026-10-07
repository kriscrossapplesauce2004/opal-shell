import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Whole phone stack as the shell places it: status bar, home and navigation bar on one output. Run: OPAL_ENTRY=phone-stack.qml bash tests/render-offscreen.sh
ShellRoot {
    Component.onCompleted:Quickshell.watchFiles=false
    Window {
        id:fixture
        width:412;height:915;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"stack-phone-classic-buttons",style:"classic",buttons:true},
            {name:"stack-phone-rooms-gestures",style:"rooms",buttons:false},
            {name:"stack-phone-rooms-empty",style:"rooms",buttons:true,empty:true},
            {name:"stack-tablet-rooms-buttons",style:"rooms",buttons:true,w:1280,h:800},
            {name:"stack-tablet-rooms-gestures",style:"rooms",buttons:false,w:1280,h:800},
            {name:"stack-1080-rooms-empty",style:"rooms",buttons:true,w:1920,h:1080,empty:true},
            {name:"stack-1080-classic",style:"classic",buttons:true,w:1920,h:1080}
        ]
        property var c:cases[0]
        // A fake output with the size of the case, so tablet checks work.
        readonly property var output:({name:"FIX-1",width:fixture.width,height:fixture.height})
        function seed() {
            const W=c.w||412,H=c.h||915;
            const wins=c.empty ? [
                {title:"opal — Dolphin",className:"org.kde.dolphin",address:"0x1",workspace:1,monitor:"FIX-1",at:[0,0],size:[W,H],floating:false,fullscreen:1},
                {title:"stellaris how to remove alloys upkeep",className:"google-chrome",address:"0x2",workspace:2,monitor:"FIX-1",at:[0,0],size:[W,H],floating:false,fullscreen:1},
                {title:"Stellaris",className:"steam_app_281990",address:"0x3",workspace:3,monitor:"FIX-1",at:[0,0],size:[W,H],floating:false,fullscreen:2}
            ] : [
                {title:"claude — ~/opal",className:"kitty",address:"0x1",workspace:1,monitor:"FIX-1",at:[0,0],size:[W*.5,H],floating:false,fullscreen:0},
                {title:"Hyprland Wiki",className:"google-chrome",address:"0x2",workspace:1,monitor:"FIX-1",at:[W*.5,0],size:[W*.5,H],floating:false,fullscreen:0},
                {title:"DELTARUNE",className:"steam_app_1671210",address:"0x4",workspace:2,monitor:"FIX-1",at:[0,0],size:[W,H],floating:false,fullscreen:2}
            ];
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{phoneStyle:c.style,phoneButtons:c.buttons,light:false,mode:"phone",phoneDisplay:"FIX-1"});
            Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=wins;
            Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,workspace:c.empty ? 4 : 1,workspaces:c.empty ? [1,2,3,4] : [1,2],monitors:[{name:"FIX-1",workspace:c.empty ? 4 : 1,x:0,y:0,width:W,height:H,scale:1,transform:0}],activeAddress:c.empty ? "" : "0x1",track:"",wifi:true,network:"VM9385031",battery:-1});
        }
        readonly property bool tablet:Math.min(width,height)>=600
        readonly property int navH:tablet ? 68 : c.buttons ? 64 : 48
        Image {anchors.fill:parent;source:"file:///home/melissa/Pictures/Wallpapers/default.png";sourceSize:Qt.size(1600,1600);fillMode:Image.PreserveAspectCrop}
        Loader {id:home;anchors {fill:parent;topMargin:48;bottomMargin:fixture.navH}}
        Rectangle {id:statusBg;width:parent.width;height:48;color:Opal.Theme.alpha(Opal.Theme.base,.48)
            Loader {id:status;anchors.fill:parent}}
        Rectangle {id:navBg;anchors.bottom:parent.bottom;width:parent.width;height:fixture.navH;color:Opal.Theme.alpha(Opal.Theme.dockTint,Opal.Hub.prefs.glass)
            Loader {id:nav;anchors.fill:parent}}
        Component {id:homeView;Opal.MobileHome {embedded:true}}
        Component {id:statusView;Opal.PhoneStatus {output:fixture.output}}
        Component {id:navView;Opal.PhoneNavigation {output:fixture.output}}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            c=cases[step];width=c.w||412;height=c.h||915;seed();
            home.sourceComponent=null;status.sourceComponent=null;nav.sourceComponent=null;
            home.sourceComponent=homeView;status.sourceComponent=statusView;nav.sourceComponent=navView;
            prep.restart();
        }
        Timer {id:prep;interval:600;onTriggered:{fixture.seed();grab.restart();}}
        Timer {id:grab;interval:1200;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }
}
