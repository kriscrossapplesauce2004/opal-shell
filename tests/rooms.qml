import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Rooms renders with fixture compositor data. Run: OPAL_ENTRY=rooms.qml bash tests/render-offscreen.sh
ShellRoot {
    Component.onCompleted:Quickshell.watchFiles=false
    Window {
        id:fixture
        width:412;height:820;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"rooms-phone"},
            {name:"rooms-phone-light",light:true},
            {name:"rooms-chip-mid",chip:.45},
            {name:"rooms-chip-open",chip:1},
            {name:"rooms-dock-mid",dock:.5},
            {name:"rooms-docked",dock:1},
            {name:"rooms-tablet",w:1280,h:752}
        ]
        property var c:cases[0]
        function seed() {
            const phone={name:"DSI-1",workspace:1,x:0,y:0,width:1080,height:2400,scale:2.625,transform:0};
            const tablet={name:"DSI-1",workspace:1,x:0,y:0,width:2560,height:1600,scale:2,transform:0};
            const m=c.w ? tablet : phone;const W=c.w ? 1280 : 411,H=c.w ? 800 : 914;
            const wins=[
                {title:"claude — ~/opal",className:"kitty",address:"0x1",workspace:1,monitor:"DSI-1",at:[0,0],size:c.w ? [W*.55,H] : [W,H*.5],floating:false,fullscreen:0},
                {title:"Lua configuration – Hyprland Wiki",className:"google-chrome",address:"0x2",workspace:1,monitor:"DSI-1",at:c.w ? [W*.55,0] : [0,H*.5],size:c.w ? [W*.45,H*.6] : [W,H*.5],floating:false,fullscreen:0},
                {title:"Wallpapers",className:"org.kde.dolphin",address:"0x3",workspace:1,monitor:"DSI-1",at:c.w ? [W*.55,H*.6] : [W*.1,H*.62],size:c.w ? [W*.45,H*.4] : [W*.8,H*.3],floating:!c.w,fullscreen:0},
                {title:"DELTARUNE",className:"steam_app_1671210",address:"0x4",workspace:2,monitor:"DSI-1",at:[0,0],size:[W,H],floating:false,fullscreen:2},
                {title:"opal-dock — PCB Editor",className:"kicad",address:"0x5",workspace:3,monitor:"DSI-1",at:[0,0],size:[W,H],floating:false,fullscreen:0}
            ];
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:!!c.light,phoneStyle:"rooms"});
            Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=wins;
            Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,workspace:1,workspaces:[1,2,3],monitors:[m],activeAddress:"0x1",track:"snowfall",artist:"lofi girl",playing:true});
            Opal.PhoneState.activity={files:[{kind:"file",title:"ROADMAP-2026-10.md",path:"/tmp/none.md",when:"1 h ago"},{kind:"file",title:"board-notes.txt",path:"/tmp/none.txt"}],games:[{kind:"game",id:"steam:1",title:"Prism: Fabulously Optimized"},{kind:"game",id:"steam:2",title:"Kerbal Space Program"}]};
            Opal.Hub.monitors=[{name:"HDMI-A-1",description:"Dell Inc. DELL U2720Q (HDMI-A-1)"}];
            Opal.Hub.dockOutput="HDMI-A-1";
        }
        Image {anchors.fill:parent;source:"file:///home/melissa/Pictures/Wallpapers/default.png";sourceSize:Qt.size(1600,1600);fillMode:Image.PreserveAspectCrop}
        Loader {id:loader;anchors.fill:parent;anchors.topMargin:8}
        Component {id:roomsView;Opal.RoomsHome {}}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            c=cases[step];width=c.w||412;height=c.h||820;
            seed();
            loader.sourceComponent=null;loader.sourceComponent=roomsView;
            prepare.restart();
        }
        Timer {id:prepare;interval:500;onTriggered:{
            fixture.seed();
            const home=loader.item;
            if(fixture.c.dock!==undefined){home.holdDock=true;home.docked=true;home.dockT=fixture.c.dock;}
            if(fixture.c.chip!==undefined){const flow=fixture.findChip(home);if(flow){flow.t=fixture.c.chip;}}
            grab.restart();
        }}
        function findChip(item) {
            if(!item)return null;
            if(item.sheetWidth!==undefined&&item.text==="snowfall")return item;
            for(let i=0;i<item.children.length;i++){const f=fixture.findChip(item.children[i]);if(f)return f;}
            return null;
        }
        Timer {id:grab;interval:1200;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }
}
