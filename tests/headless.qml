import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import QtTest
import Quickshell
import "src" as Opal

// Isolated renderer. The runner removes DISPLAY/WAYLAND_DISPLAY and supplies
// an offscreen platform, disposable HOME, and a nonexistent session bus.
ShellRoot {
    Component.onCompleted:Quickshell.watchFiles=false
    Window {
        id:fixture
        width:960;height:650;visible:true;color:Opal.Theme.base
        property int step:0
        property real musicVolume:40
        property var consoleGames:[]
        Timer {id:linkFixture;interval:400;onTriggered:{Opal.Hub.linkStatus="running";Opal.Hub.linkDevices=[{id:"a".repeat(32),name:"OnePlus 7",type:"phone",reachable:true,paired:true,battery:76,charging:false,opal:false,session:{}},{id:"b".repeat(32),name:"Living room PC",type:"desktop",reachable:true,paired:true,battery:-1,charging:false,opal:true,session:{app:"firefox",track:"",playing:false}},{id:"c".repeat(32),name:"Pixel Tablet",type:"tablet",reachable:true,paired:false,pairRequested:true,opal:false,session:{}}];Opal.Hub.apps=[{id:"firefox",name:"Firefox",icon:"firefox",categories:[],keywords:[],execute:()=>{}}];}}
        Timer {id:monitorFixture;interval:400;onTriggered:Opal.Hub.monitors=[{name:"eDP-1",description:"Built-in display",width:2560,height:1600,refresh:120,x:0,y:0,scale:1.5,transform:0,disabled:false,mirror:"none",modes:["2560x1600@120.00Hz","2560x1600@60.00Hz","1920x1200@60.00Hz"]},{name:"HDMI-A-1",description:"Dell U2720Q",width:1920,height:1080,refresh:60,x:1707,y:0,scale:1,transform:0,disabled:false,mirror:"none",modes:["1920x1080@60.00Hz","1280x720@60.00Hz"]}]}
        property var cases:[
            {name:"start-beauty",ui:"start",w:600,h:680},
            {name:"workspace-pill",ui:"bars",w:600,h:120,pill:true},
            {name:"workspace-pill-light",ui:"bars",w:600,h:120,pill:true,light:true},
            {name:"lock-idle",ui:"lock",w:1440,h:900,music:true},
            {name:"lock-revealed",ui:"lock",w:1440,h:900,music:true,reveal:true,lockError:true},
            {name:"lock-light-small",ui:"lock",w:420,h:860,light:true,reveal:true},
            {name:"greeter",ui:"lock",w:1440,h:900,greeter:true},
            {name:"greeter-whats-new",ui:"lock",w:1440,h:900,greeter:true,whatsNew:true,light:true},
            {name:"polkit",ui:"polkit",w:640,h:520},
            {name:"dock-menu",ui:"dockmenu",w:1280,h:720},
            {name:"dock-menu-light",ui:"dockmenu",w:1280,h:720,light:true},
            {name:"dock-menu-phone",ui:"dockmenu",w:400,h:860},
            {name:"phone-docked",ui:"phonedock",w:400,h:860},
            {name:"bar-islands",ui:"bars",w:1440,h:300,music:true,barStyle:"islands"},
            {name:"bar-islands-light",ui:"bars",w:1440,h:300,light:true,tide:true,barStyle:"islands"},
            {name:"bar-dock",ui:"bars",w:1440,h:300,barStyle:"dock"},
            {name:"bar-split",ui:"bars",w:1440,h:300,music:true,barStyle:"split"},
            {name:"bar-edge",ui:"bars",w:1440,h:300,light:true,barStyle:"edge"},
            {name:"bar-osd",ui:"bars",w:1440,h:300,barStyle:"islands",osd:true,flash:true},
            {name:"context-menus",ui:"menus",w:980,h:560},
            {name:"context-menus-light",ui:"menus",w:980,h:560,light:true},
            {name:"search-empty",ui:"search",w:1280,h:800},
            {name:"search-apps",ui:"search",w:1280,h:800,searchText:"fi",light:true},
            {name:"search-math",ui:"search",w:1280,h:800,searchText:"12*(3+4)"},
            {name:"settings-taskbar",ui:"settings",w:980,h:800,section:"taskbar"},
            {name:"settings-phone-navigation",ui:"settings",w:360,h:740,section:"phone",light:true},
            {name:"settings-phone-gestures",ui:"settings",w:980,h:900,section:"phone"},
            {name:"settings-network",ui:"settings",w:980,h:800,section:"network"},
            {name:"settings-sound",ui:"settings",w:980,h:800,section:"sound",music:true},
            {name:"settings-about",ui:"settings",w:980,h:800,section:"about",light:true},
            {name:"settings-power-wide",ui:"settings",w:980,h:800,section:"power"},
            {name:"settings-power",ui:"settings",w:360,h:740,section:"power"},
            {name:"compact-control-panel",ui:"shade",w:420,h:520},
            {name:"compact-control-panel-light",ui:"shade",w:420,h:520,light:true},
            {name:"settings-displays",ui:"settings",w:980,h:900,section:"displays",monitors:true},
            {name:"settings-convergence",ui:"settings",w:980,h:1100,section:"screens",monitors:true},
            {name:"settings-convergence-light",ui:"settings",w:420,h:1500,section:"screens",monitors:true,light:true},
            {name:"undo-toast",ui:"undotoast",w:480,h:260},
            {name:"undo-toast-light",ui:"undotoast",w:480,h:260,light:true,detail2:true},
            {name:"layout-morph",ui:"layoutmorph",w:480,h:260},
            {name:"settings-schedules",ui:"settings",w:980,h:800,section:"schedules",light:true,schedules:true},
            {name:"settings-apptheme",ui:"settings",w:980,h:800,section:"apptheme"},
            {name:"settings-apptheme-light",ui:"settings",w:980,h:800,section:"apptheme",light:true},
            {name:"settings-profiles",ui:"settings",w:980,h:800,section:"profiles",profiles:true},
            {name:"settings-system",ui:"settings",w:980,h:800,section:"system",health:true},
            {name:"onboarding-bar",ui:"onboarding",w:660,h:640,step:2},
            {name:"onboarding-welcome-light",ui:"onboarding",w:660,h:640,step:0,light:true},
            {name:"settings-link",ui:"settings",w:980,h:800,section:"link",link:true},
            {name:"settings-home",ui:"settings",w:980,h:800},
            {name:"settings-phone",ui:"settings",w:360,h:740,light:true},
            {name:"volume-osd-dark",ui:"osd",w:340,h:112},
            {name:"volume-osd-light",ui:"osd",w:320,h:112,light:true},
            {name:"expressive-controls",ui:"shapes",w:600,h:310},
            {name:"audio-drawer-dark",ui:"audio",w:444,h:354,music:true,wheel:true},
            {name:"audio-drawer-light",ui:"audio",w:360,h:354,music:true,light:true},
            {name:"shade-reference",ui:"shade",w:360,h:768,music:true},
            {name:"material-shade-light",ui:"shade",w:360,h:768,music:true,light:true},
            {name:"wallpaper-browser",ui:"wallpaper",w:800,h:860,browse:true},
            {name:"wallpaper-studio",ui:"wallpaper",w:800,h:860},
            {name:"wallpaper-studio-light",ui:"wallpaper",w:800,h:860,light:true},
            {name:"wallpaper-studio-images",ui:"wallpaper",w:800,h:860,photo:true},
            {name:"wallpaper-studio-phone",ui:"wallpaper",w:360,h:740},
            {name:"touch-apps-monitor",ui:"phone",w:1920,h:1080,drawer:true},
            {name:"dock-welcome",ui:"dock",w:440,h:250},
            {name:"dock-welcome-docked",ui:"dock",w:440,h:250,docked:true},
            {name:"dock-welcome-phone",ui:"dock",w:412,h:330,phone:true,docked:true},
            {name:"dock-welcome-phone-light",ui:"dock",w:360,h:440,phone:true,docked:true,light:true},
            {name:"phone-switcher-monitor",ui:"switcher",w:1080,h:880,recent:true,phone:true},
            {name:"glass",ui:"glass",w:960,h:740},
            {name:"convergence-dark",ui:"convergence",w:800,h:820},
            {name:"convergence-light",ui:"convergence",w:800,h:820,light:true},
            {name:"convergence-phone",ui:"convergence",w:360,h:740},
            {name:"tablet-home",ui:"phone",w:1000,h:740},
            {name:"desktop",ui:"desktop",w:960,h:650},
            {name:"desktop-light",ui:"desktop",w:960,h:740,light:true},
            {name:"wifi-phone",ui:"shade",w:360,h:640,detail:"wifi"},
            {name:"bluetooth-devices",ui:"shade",w:400,h:640,detail:"bluetooth",devices:true},
            {name:"wifi-networks-light",ui:"shade",w:400,h:640,detail:"wifi",devices:true,light:true},
            {name:"bluetooth-light",ui:"shade",w:490,h:740,detail:"bluetooth",light:true},
            {name:"workspace-dark",ui:"workspace",w:1440,h:900},
            {name:"workspace-light",ui:"workspace",w:1440,h:900,light:true},
            {name:"desktop-shelf-reference",ui:"workspace",w:1280,h:720,shelf:true},
            {name:"desktop-shelf-light",ui:"workspace",w:1280,h:720,shelf:true,light:true},
            {name:"desktop-shelf-narrow",ui:"workspace",w:640,h:480,shelf:true},
            {name:"reference-desktop-light",ui:"reference",w:1280,h:720,light:true,tide:true},
            {name:"reference-desktop-dark",ui:"reference",w:1280,h:720},
            {name:"reference-desktop-tall",ui:"reference",w:1440,h:900,music:true},
            {name:"shade-dark",ui:"shade",w:490,h:860},
            {name:"shade-light",ui:"shade",w:490,h:860,light:true},
            {name:"shade-phone",ui:"shade",w:360,h:640},
            {name:"qs-phone-expanded",ui:"shade",w:412,h:820,qs:1,music:true},
            {name:"qs-phone-expanded-light",ui:"shade",w:412,h:820,qs:1,light:true},
            {name:"qs-phone-detail-grow",ui:"shade",w:412,h:820,qs:0,detailGrow:.5},
            {name:"shade-phone-wide",ui:"shade",w:460,h:800,phone:true},
            {name:"shade-tablet",ui:"shade",w:800,h:900,phone:true},
            {name:"shade-phone-light",ui:"shade",w:360,h:640,light:true},
            {name:"shade-phone-small",ui:"shade",w:320,h:568},
            {name:"shade-phone-scrolled",ui:"shade",w:360,h:640,scroll:true},
            {name:"appearance-dark",ui:"appearance",w:620,h:800},
            {name:"appearance-light",ui:"appearance",w:620,h:800,light:true},
            {name:"appearance-phone",ui:"appearance",w:328,h:740},
            {name:"shade-scrolled",ui:"shade",w:490,h:700,scroll:true},
            {name:"appearance-scrolled",ui:"appearance",w:620,h:800,scroll:true},
            {name:"phone-412",ui:"phone",w:412,h:915,task:true},
            {name:"phone-412-light",ui:"phone",w:412,h:915,task:true,light:true},
            {name:"phone-412-drawer",ui:"phone",w:412,h:915,apps:true,task:true,filterText:"fi"},
            {name:"tablet-1280",ui:"phone",w:1280,h:800,task:true},
            {name:"tablet-1280-light",ui:"phone",w:1280,h:800,task:true,light:true},
            {name:"tablet-dock",ui:"tabletdock",w:1280,h:180},
            {name:"tablet-dock-light",ui:"tabletdock",w:1280,h:180,light:true},
            {name:"tablet-dock-gestures",ui:"tabletdock",w:1280,h:180,gestures:true},
            {name:"phone-battery",ui:"battery",w:412,h:915},
            {name:"phone-battery-light",ui:"battery",w:412,h:915,light:true},
            {name:"gesture-home",ui:"gesture",w:412,h:915,gesture:"home",progress:.45},
            {name:"gesture-recents",ui:"gesture",w:412,h:915,gesture:"recents",progress:.5},
            {name:"gesture-switch",ui:"gesture",w:412,h:915,gesture:"switch",dx:150},
            {name:"gesture-back",ui:"gesture",w:412,h:915,gesture:"back",progress:1,light:true},
            {name:"gesture-edge-held",ui:"gesture",w:412,h:915,gesture:"back",progress:1,held:true,edge:1,edgeY:.7,gestures:{rightLower:"back",rightLowerHold:"screenshot"}},
            {name:"gesture-edge-assigned",ui:"gesture",w:412,h:915,gesture:"back",progress:1,edgeY:.25,gestures:{leftUpper:"notifications"}},
            {name:"lock-extras",ui:"lockfx",w:412,h:915},
            {name:"lock-ambient",ui:"lockfx",w:412,h:915,ambient:true},
            {name:"phone-home",ui:"phone",w:390,h:844},
            {name:"phone-home-light",ui:"phone",w:390,h:844,light:true},
            {name:"phone-switcher",ui:"phone",w:390,h:844,recent:true},
            {name:"desktop-switcher",ui:"switcher",w:900,h:650,recent:true},
            {name:"console-switcher",ui:"switcher",w:1100,h:750,recent:true,game:true},
            {name:"phone-apps",ui:"phone",w:390,h:844,apps:true},
            {name:"small-phone",ui:"phone",w:360,h:740,apps:true},
            {name:"keyboard-dark",ui:"keyboard",w:390,h:380},
            {name:"keyboard-light",ui:"keyboard",w:390,h:380,light:true},
            {name:"keyboard-narrow",ui:"keyboard",w:320,h:360},
            {name:"launcher-phone-keyboard",ui:"desktop",w:390,h:844,osk:true},
            {name:"phone-landscape",ui:"phone",w:800,h:480},
            {name:"console",ui:"console",w:1280,h:800},
            {name:"console-search",ui:"console",w:1280,h:800,search:true},
            {name:"console-actions",ui:"console",w:1280,h:800,menu:true},
            {name:"console-session",ui:"console",w:960,h:600,menu:true,section:1},
            {name:"console-setup-light",ui:"console",w:960,h:600,menu:true,section:3,light:true,nintendo:true},
            {name:"phone-bars",ui:"phonebars",w:390,h:844},
            {name:"phone-bars-light",ui:"phonebars",w:360,h:740,light:true,buttons:true},
            {name:"activity-shelf-1",ui:"bars",w:1440,h:300,barStyle:"islands",activities:1},
            {name:"activity-shelf-3-light",ui:"bars",w:1440,h:300,barStyle:"islands",activities:3,light:true},
            {name:"activity-shelf-3-dock",ui:"bars",w:1440,h:300,barStyle:"dock",activities:3},
            {name:"activity-pill-expanded",ui:"pill",w:620,h:140,activities:3},
            {name:"activity-pill-expanded-light",ui:"pill",w:620,h:140,activities:3,light:true},
            {name:"activity-pill-compact",ui:"pill",w:620,h:140,activities:3,compact:true},
            {name:"activity-phone-status",ui:"phonebars",w:390,h:844,activities:3},
            {name:"activity-phone-status-open-light",ui:"phonebars",w:390,h:844,activities:3,pinPill:true,light:true},
            {name:"activity-lock",ui:"lockfx",w:412,h:915,activities:3},
            {name:"activity-lock-open",ui:"lockfx",w:412,h:915,activities:3,pinPill:true},
            {name:"suggestion-chips",ui:"chips",w:620,h:200},
            {name:"suggestion-chips-light",ui:"chips",w:620,h:200,light:true},
            {name:"handheld",ui:"console",w:960,h:600},
            {name:"clipboard-empty",ui:"clipboard",w:470,h:650,empty:true},
            {name:"clipboard-text",ui:"clipboard",w:470,h:650},
            {name:"clipboard-phone",ui:"clipboard",w:390,h:844,phone:true},
            {name:"clipboard-widget",ui:"dashboard",w:840,h:700},
            {name:"hypr-urgent-dark",ui:"workspace",w:1280,h:120,shelf:true,hyprFix:true,submap:"resize"},
            {name:"hypr-urgent-light",ui:"workspace",w:1280,h:120,shelf:true,hyprFix:true,submap:"resize",light:true},
            {name:"hypr-submap-reset",ui:"workspace",w:1280,h:120,shelf:true,hyprFix:true,submap:"reset"},
            {name:"taskbar-drag",ui:"taskbar",w:700,h:64,drag:true},
            {name:"start-home",ui:"start",w:1280,h:800},
            {name:"start-home-light",ui:"start",w:1280,h:800,light:true},
            {name:"start-search",ui:"start",w:1280,h:800,searchText:"firefx"},
            {name:"start-windows",ui:"start",w:1280,h:800,searchText:"@ Project"},
            {name:"start-actions",ui:"start",w:1280,h:800,searchText:">"},
            {name:"start-empty",ui:"start",w:1280,h:800,searchText:"zzzzzzzz"},
            {name:"start-claude",ui:"start",w:1280,h:800,searchText:"! make the bar a dock",claude:true},
            {name:"start-calculator",ui:"start",w:1280,h:800,searchText:"= 12 * (3 + 4)"},
            {name:"start-small",ui:"start",w:640,h:560,allApps:true},
            {name:"qa-game-hd",ui:"quickaccess",w:1280,h:800,tab:0,pad:["down"]},
            {name:"qa-game-fhd-light",ui:"quickaccess",w:1920,h:1080,tab:0,light:true,pad:["down","down"]},
            {name:"qa-game-empty",ui:"quickaccess",w:1280,h:800,tab:0,noGame:true,pad:["down"]},
            {name:"qa-performance-hd",ui:"quickaccess",w:1280,h:800,tab:1,pad:["down","down"]},
            {name:"qa-performance-fhd-light",ui:"quickaccess",w:1920,h:1080,tab:1,light:true,pad:["down","down","down"]},
            {name:"qa-performance-no-tdp",ui:"quickaccess",w:1280,h:800,tab:1,noTdp:true,pad:["down"]},
            {name:"qa-quick-hd",ui:"quickaccess",w:1280,h:800,tab:0,pad:["down","down","down","down","down"]},
            {name:"qa-quick-fhd-light",ui:"quickaccess",w:1920,h:1080,tab:0,light:true,pad:["down","down","down","down","down","down"]},
            {name:"qa-alerts-hd",ui:"quickaccess",w:1280,h:800,tab:2,pad:[]},
            {name:"qa-glance-hd",ui:"quickaccess",w:1280,h:800,tab:0,glance:true,pad:[]},
            {name:"pad-shade",ui:"shade",w:420,h:560,pad:["down","down","right"]},
            {name:"pad-shade-light",ui:"shade",w:420,h:560,light:true,pad:["down","down","down"]},
            {name:"pad-settings",ui:"padsettings",w:980,h:800,section:"power",pad:["down","right","down"]},
            {name:"pad-settings-light",ui:"padsettings",w:980,h:800,light:true,pad:["down"]},
            {name:"pad-polkit",ui:"padpolkit",w:640,h:520,pad:["down"]},
            {name:"pad-polkit-keyboard",ui:"padpolkit",w:900,h:640,light:true,pad:["accept"]},
            {name:"console-hero-hd",ui:"console",w:1280,h:800},
            {name:"console-hero-fhd-light",ui:"console",w:1920,h:1080,light:true,tab:"All"},
            {name:"console-detail-hd",ui:"console",w:1280,h:800,detail:true,pad:["down"]},
            {name:"console-detail-light",ui:"console",w:1280,h:800,detail:true,light:true,pad:["down","down"]},
            {name:"console-hub-library",ui:"console",w:1280,h:800,hub:4},
            {name:"pad-guard",ui:"shapes",w:600,h:310,guard:true,pad:[]},
            {name:"qa-close",ui:"quickaccess",w:1280,h:800,tab:0,pad:["down","back"],expectClosed:true},
            {name:"qa-tab-step",ui:"quickaccess",w:1280,h:800,tab:0,pad:["nextTab","nextTab","down"],expectTab:2},
            {name:"pad-lock",ui:"lock",w:1440,h:900,reveal:true,music:true,pad:["accept"]},
            {name:"pad-lock-light",ui:"lock",w:1440,h:900,reveal:true,light:true,pad:["down"]},
            {name:"tile-editor",ui:"tiles",w:360,h:900},
            {name:"assistant-desktop-dark",ui:"assistant",w:470,h:780,layout:"desktop",chat:true},
            {name:"assistant-desktop-light",ui:"assistant",w:470,h:780,layout:"desktop",chat:true,light:true},
            {name:"assistant-empty-context",ui:"assistant",w:470,h:620,layout:"desktop"},
            {name:"assistant-confirm-dark",ui:"assistant",w:470,h:780,layout:"desktop",chat:true,confirm:true},
            {name:"assistant-confirm-light",ui:"assistant",w:470,h:780,layout:"desktop",chat:true,confirm:true,light:true},
            {name:"assistant-phone-dark",ui:"assistant",w:390,h:760,layout:"phone",phone:true,chat:true,confirm:true},
            {name:"assistant-phone-light",ui:"assistant",w:390,h:760,layout:"phone",phone:true,chat:true,light:true},
            {name:"assistant-console",ui:"assistant",w:960,h:640,layout:"console",confirm:true},
            {name:"assistant-auto-dark",ui:"assistant",w:470,h:780,layout:"desktop",chat:true,auto:true}
        ]
        Rectangle {anchors.fill:parent;color:Opal.Theme.base}
        Loader {id:view;anchors.fill:parent}
        TestCase {id:input;name:"TaskbarDrag";when:false}
        Component {id:assistantView;Item {
            Opal.Wallpaper {anchors.fill:parent;showWidgets:false}
            Opal.Surface {
                anchors.fill:parent;anchors.margins:(fixture.cases[fixture.step]||{}).layout==="phone" ? 0 : 10;radius:(fixture.cases[fixture.step]||{}).layout==="phone" ? 28 : 32;translucency:.9
                Opal.AssistantPanel {anchors.fill:parent;layoutMode:(fixture.cases[fixture.step]||{}).layout||"desktop"}
            }
        }}
        function assistantFixture(test) {
            const A=Opal.AssistantState;
            A.busy=false;A.available=true;A.approvals=[];A.turns=[];

            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{assistantMode:test.auto ? "auto" : "ask"});
            A.ctxApp="firefox";A.ctxTitle="Hyprland wiki - Configuring";A.ctxSelection="Lua config reload";A.ctxClipboard="";A.useApp=true;A.useSelection=true;A.useClipboard=true;
            if(!test.chat&&!test.confirm)return;
            if(test.chat) {
                A.ctxApp="";A.ctxSelection="";
                A.turns=[
                    {role:"user",text:"Open my notes app and put it next to Firefox"},
                    {role:"assistant",id:1,done:true,error:false,stopped:false,tools:[{id:"a",name:"list_windows",label:"Looking at your windows",running:"Looking at your windows",doneLabel:"Looked at your windows",icon:"select_window",detail:"",status:"done",error:"",auto:false},{id:"b",name:"launch_app",label:"Opening an app",running:"Opening an app",doneLabel:"Opened an app",icon:"open_in_new",detail:"Kate",status:"done",error:"",auto:false},{id:"c",name:"move_window",label:"Moving a window",running:"Moving a window",doneLabel:"Moved a window",icon:"open_with",detail:"kate",status:"error",error:"Window is no longer available",auto:false}],
                     text:"I opened **Kate** on workspace 2. Moving it failed because the window had not appeared yet.\n\n- Firefox is on workspace 1\n- Kate is on workspace 2\n\nUse `Super+2` to switch, or ask me to try the move again."},
                    {role:"user",text:"Try again, then summarize the Hyprland page"},
                    {role:"assistant",id:2,done:true,error:false,stopped:false,tools:[{id:"d",name:"move_window",label:"Moving a window",running:"Moving a window",doneLabel:"Moved a window",icon:"open_with",detail:"kate",status:"done",error:"",auto:true},{id:"e",name:"desktop_ui_read",label:"Reading",running:"Reading",doneLabel:"Read",icon:"article",detail:"Configuring – Hyprland Wiki",status:"done",error:"",auto:true}],
                     text:"## Moved\n\nKate now sits on workspace 1.\n\nThe page covers reloading the **Lua config**:\n\n```\nhyprctl reload\n```\n\nRead more at [the wiki](https://wiki.hyprland.org)."}
                ];
            }
            if(test.confirm) {
                A.busy=true;A.ctxApp="";A.ctxSelection="";
                A.turns=A.turns.concat([{role:"user",text:"Close the old Firefox windows and clean my downloads"},{role:"assistant",id:3,done:false,error:false,stopped:false,tools:[{id:"f",name:"list_windows",label:"Looking at your windows",running:"Looking at your windows",doneLabel:"Looked at your windows",icon:"select_window",detail:"",status:"done",error:"",auto:false},{id:"g",name:"close_window",label:"Closing a window",running:"Closing a window",doneLabel:"Closed a window",icon:"close",detail:"firefox",status:"running",error:"",auto:false}],text:"I found two Firefox windows."}]);
                A.approvals=[{id:"x1",tool:"close_window",label:"Close a window",detail:"firefox",risk:"high"},{id:"x2",tool:"open_target",label:"Open a link or file",detail:"https://wiki.hyprland.org/Configuring/",risk:"medium"}];
            }
        }
        Component {id:taskbarView;Opal.TaskStrip {labels:false}}
        Component {id:audioView;Opal.AudioPanel {}}
        Component {id:settingsView;Opal.Settings {}}
        Component {id:tilesView;Opal.QuickTileDeck {editing:true}}
        Timer {interval:80;repeat:true;running:fixture.step<fixture.cases.length&&fixture.cases[fixture.step].ui==="start"
            onTriggered:{
                const pins=["firefox","files","terminal","code","music","notes"];
                if(JSON.stringify(Opal.Hub.prefs.favorites)!==JSON.stringify(pins))Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{favorites:pins,pinsConfigured:true,recent:["code","firefox"],light:!!fixture.cases[fixture.step].light,palette:1});
            }
        }
        Timer {interval:80;repeat:true;running:fixture.step<fixture.cases.length&&fixture.cases[fixture.step].name.startsWith("compact-control-panel")
            onTriggered:Opal.Hub.status=Object.assign({},Opal.Hub.status,{brightness:62,volume:48,muted:false,wifi:true,network:"Home Wi-Fi",bluetooth:true,profile:"balanced",track:""})
        }
        Component {id:osdView;Opal.VolumeOsd {}}
        Component {id:shapeView;Item {
            id:shapeFixture
            property alias slider:shapeSlider
            property alias enabledTile:onStateTile
            property alias disabledTile:offStateTile
            property int toggleHits:0
            property int navigationHits:0
            ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
                Opal.MText {text:"Split tracks · expressive states";font.pixelSize:20}
                Opal.ExpressiveSlider {id:shapeSlider;Layout.fillWidth:true;icon:"sun";value:58}
                RowLayout {Layout.fillWidth:true;spacing:12
                    Opal.ShadeTile {id:offStateTile;Layout.fillWidth:true;icon:"coffee";title:"Keep awake";subtitle:"Off";active:false}
                    Opal.ShadeTile {id:onStateTile;Layout.fillWidth:true;icon:"quiet";title:"Do not disturb";subtitle:"On";active:true;onToggled:shapeFixture.toggleHits++;onClicked:shapeFixture.navigationHits++}
                }
                RowLayout {Layout.alignment:Qt.AlignHCenter;spacing:14
                    Opal.MButton {icon:"moon";morph:true;checked:false;tonal:true}
                    Opal.MButton {icon:"moon";morph:true;checked:true;filled:true}
                }
            }
        }}
        Timer {interval:100;repeat:true;running:fixture.step<fixture.cases.length&&!!fixture.cases[fixture.step].music
            onTriggered:Opal.Hub.status=Object.assign({},Opal.Hub.status,{track:"A little evening music",artist:"Local player",art:"file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-1.png",playing:true,volume:fixture.musicVolume,audioOutput:"Headphones"})
        }
        Component {id:switcherView;Opal.WindowSwitcher {}}
        Component {id:wallpaperStudio;Opal.WallpaperPicker {}}
        Component {id:dockView;Opal.DockWelcome {}}
        Component {id:glassView;Item {Opal.Wallpaper {anchors.fill:parent;showWidgets:false} Opal.Surface {anchors.fill:parent;anchors.margins:24;translucency:.55;Opal.Convergence {anchors.fill:parent}}}}
        Component {id:undoToastView;Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Opal.UndoToast {anchors.centerIn:parent;text:"Keyboard connected · Desktop layout · 3 apps moved";detail:fixture.cases[fixture.step].detail2 ? "Built-in display idle while the lid is closed" : "";remaining:.62}
        }}
        Component {id:morphView;Item {
            property alias morph:morph
            Opal.LayoutMorph {
                id:morph;anchors.fill:parent;layout:"phone"
                Rectangle {anchors.fill:parent;color:morph.shown==="phone" ? Opal.Theme.tertiaryContainer : Opal.Theme.primaryContainer
                    Opal.MText {anchors.centerIn:parent;text:"Layout: "+morph.shown;font.pixelSize:28}}
            }
        }}
        Component {id:convergenceView;Opal.Convergence {}}
        Component {id:desktop;Opal.Launcher {}}
        Component {id:startView;Item {
            property alias menu:startMenu
            Opal.Wallpaper {anchors.fill:parent;showWidgets:false}
            Opal.Surface {x:18;y:parent.height-height-72;width:Math.min(760,parent.width-36);height:Math.min(620,parent.height-88);radius:28
                Opal.StartMenu {id:startMenu;anchors.fill:parent}
            }
            Opal.DesktopShelf {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:64}
        }}
        Component {id:phone;Opal.MobileHome {}}
        Component {id:tabletDockView;Item {
            Opal.Wallpaper {anchors.fill:parent;showWidgets:false}
            Opal.TabletBar {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:Opal.PhoneState.tabletNavHeight;screenObj:null;keys:!(fixture.cases[fixture.step]||{}).gestures}
        }}
        Component {id:batteryView;Opal.BatteryStats {}}
        Component {id:gestureView;Item {
            Opal.Wallpaper {anchors.fill:parent;showWidgets:false}
            Opal.GestureStage {anchors.fill:parent}
        }}
        Component {id:lockFxView;Item {
            Opal.Wallpaper {anchors.fill:parent;showWidgets:false}
            property alias extras:lockExtras
            Opal.LockExtras {
                id:lockExtras;anchors.fill:parent
                scene:Item {property bool revealed:false;property bool greeter:false}
                fixtureItems:[{notification:{appName:"Messages",summary:"Sam: dinner at 7?",appIcon:""}},{notification:{appName:"Calendar",summary:"Design review in 10 min",appIcon:""}},{notification:{appName:"Firefox",summary:"Download finished",appIcon:""}}]
                ambientOn:!!fixture.cases[fixture.step].ambient
            }
        }}
        Component {id:phoneBars;Item {
            property alias navigation:phoneNav
            property alias statusBar:phoneStatusBar
            Opal.PhoneStatus {id:phoneStatusBar;anchors.top:parent.top;width:parent.width;height:48}
            Opal.MobileHome {anchors.fill:parent;anchors.topMargin:48;anchors.bottomMargin:phoneNav.height}
            Opal.PhoneNavigation {id:phoneNav;anchors.bottom:parent.bottom;width:parent.width;height:implicitHeight}
        }}
        Component {id:pillView;Item {
            property alias pill:fixturePill
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Opal.ActivityPill {id:fixturePill;anchors.centerIn:parent;pillHeight:44;pinned:!fixture.cases[fixture.step].compact;maxExpanded:560}
        }}
        Component {id:chipsView;Item {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Opal.SuggestionChips {anchors.centerIn:parent;width:parent.width-48}
        }}
        function activityFixture(count) {
            const all=[
                {id:"n:9",nid:9,kind:"transfer",icon:"download",title:"Downloading photos.zip",subtitle:"Firefox · 64%",progress:.64,priority:70,since:1,until:0,controls:[{id:"note-action",index:0,label:"Cancel"}]},
                {id:"focus",kind:"focus",icon:"timer",title:"17:42",subtitle:"Focus session",progress:.29,priority:60,since:2,until:0,controls:[{id:"focus-toggle",icon:"pause"},{id:"focus-stop",icon:"close"}]},
                {id:"media",kind:"media",icon:"music",art:"file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-1.png",title:"A little evening music",subtitle:"Local player",progress:-1,priority:50,since:3,until:0,controls:[{id:"media-previous",icon:"previous"},{id:"media-pause",icon:"pause"},{id:"media-next",icon:"skip"}]}
            ];
            return count===1 ? [all[2]] : all;
        }
        Component {id:gaming;Opal.ConsoleLibrary {}}
        Component {id:keyboardView;Item {
            property alias keyboard:demoKeyboard
            property alias input:demoInput
            ColumnLayout {anchors.fill:parent;anchors.margins:12;spacing:10
                TextField {
                    id:demoInput;Layout.fillWidth:true;Layout.preferredHeight:52
                    placeholderText:"Type something";font.family:Opal.Theme.font;font.pixelSize:16
                    color:Opal.Theme.text;placeholderTextColor:Opal.Theme.muted;leftPadding:18;rightPadding:18
                    background:Rectangle {radius:26;color:Opal.Theme.surfaceHigh}
                }
                Opal.SearchKeyboard {id:demoKeyboard;Layout.fillWidth:true;Layout.fillHeight:true;inputTarget:demoInput;contextLabel:"Message";returnLabel:"Done"}
            }
        }}
        Component {id:clipboardView;Opal.ClipboardPanel {}}
        Component {id:dashboardView;Opal.Dashboard {}}
        Component {id:shadeView;Opal.QuickSettings {}}
        Component {id:appearanceView;Opal.Appearance {}}
        Component {id:menusView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Row {x:20;y:20;spacing:20
                Opal.Surface {width:300;height:appMenu.implicitHeight;radius:24;translucency:.9
                    Opal.ContextMenuBody {id:appMenu;anchors.fill:parent;title:"Firefox";icon:"web";entries:[{text:"New window",icon:"add",quick:true},{text:"Unpin",icon:"keep_off",quick:true},{text:"Close all",icon:"close",quick:true,danger:true},{text:"New private window",icon:"bolt"},{text:"Final report.pdf",detail:"Workspace 2",icon:"desktop"},{text:"A good playlist",detail:"Workspace 3",icon:"desktop"}]}
                }
                Opal.Surface {width:300;height:winMenu.implicitHeight;radius:24;translucency:.9
                    Opal.ContextMenuBody {id:winMenu;anchors.fill:parent;title:"Project notes";icon:"desktop";entries:[{text:"Maximize",icon:"open_in_full",quick:true},{text:"Minimize",icon:"minimize",quick:true},{text:"Close",icon:"close",quick:true,danger:true},{text:"Switch to window",icon:"desktop"},{text:"1",chip:true,group:"Move to workspace"},{text:"3",chip:true,group:"Move to workspace"},{text:"4",chip:true,group:"Move to workspace"}]}
                }
                Opal.Surface {width:300;height:barMenu.implicitHeight;radius:24;translucency:.9
                    Opal.ContextMenuBody {id:barMenu;anchors.fill:parent;title:"Shelf";icon:"desktop";entries:Opal.Hub.taskbarMenu()}
                }
            }
        }}
        Component {id:searchView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Opal.Surface {x:72;y:parent.height-height-72;width:640;height:Math.min(parent.height-100,searchPanel.fitHeight);radius:32
                Opal.SearchPanel {id:searchPanel;anchors.fill:parent}
            }
            Opal.DesktopShelf {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:64}
        }}
        Component {id:referenceView;Item {
            property alias shelf:referenceShelf
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0}
            Opal.Surface {anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.rightMargin:18;anchors.bottomMargin:72;width:380;height:Math.min(parent.height-100,referencePanel.fitHeight>0 ? referencePanel.fitHeight : 470);radius:32
                Opal.QuickSettings {id:referencePanel;anchors.fill:parent}
            }
            Opal.DesktopShelf {id:referenceShelf;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:64}
        }}
        Component {id:lockView;Item {
            readonly property var test:fixture.cases[fixture.step]
            Opal.LockScene {
                id:lockScene;anchors.fill:parent
                mode:parent.test.greeter ? "greeter" : "lock"
                userName:"Melissa"
                error:parent.test.lockError ? "That password didn't work. Try again." : ""
                notificationGroups:[{app:"Firefox",icon:"firefox",count:3},{app:"Discord",icon:"discord",count:1}]
                users:[{login:"melissa",name:"Melissa"},{login:"teleop",name:"teleop"}]
                sessions:[{id:"hyprland",name:"Hyprland"},{id:"niri",name:"Niri"}]
                keyboardLayout:"GB"
                whatsNewOpen:!!parent.test.whatsNew
                whatsNew:[{icon:"view_column",title:"A calmer bar",text:"Fewer, bolder islands. Choose islands, dock, split or edge in Settings."},{icon:"bolt",title:"Live activity",text:"Music and focus timers sit in the bar."},{icon:"notifications",title:"Better notifications",text:"Smaller popups, and an inbox grouped by app."}]
                Component.onCompleted:if(parent.test.reveal)reveal()
            }
        }}
        // The real status poller also runs in this scene, so Quick Access values are pinned until capture.
        Timer {interval:60;repeat:true;running:fixture.step<fixture.cases.length&&fixture.cases[fixture.step].ui==="quickaccess"
            onTriggered:{
                const want={profile:"balanced",battery:73,charging:false,brightness:62,volume:48,muted:false,wifi:true,network:"Home Wi-Fi",bluetooth:true};
                if(Object.keys(want).some(k=>Opal.Hub.status[k]!==want[k]))Opal.Hub.status=Object.assign({},Opal.Hub.status,want);
            }
        }
        // The real library scan also runs in this scene and would empty the fixture library.
        Timer {interval:60;repeat:true;running:fixture.step<fixture.cases.length&&fixture.cases[fixture.step].ui==="console"
            onTriggered:{
                if(Opal.Hub.games.length!==fixture.consoleGames.length)Opal.Hub.games=fixture.consoleGames;
                if(Opal.GameState.detail.playtimeMinutes!==754)Opal.GameState.detail={id:"steam:1",playtimeMinutes:754,lastPlayed:1790000000,sizeBytes:5400000000,uninstallable:true};
            }
        }
        Component {id:quickAccessView;Item {
            property alias qa:quickAccessItem
            Rectangle {anchors.fill:parent;gradient:Gradient {GradientStop {position:0;color:"#1b2b3a"} GradientStop {position:1;color:"#0b1018"}}}
            Opal.QuickAccess {id:quickAccessItem;anchors.fill:parent}
        }}
        Component {id:padSettingsView;Item {
            Opal.Settings {id:padSettings;anchors.fill:parent}
            Opal.ControllerFocus {anchors.fill:parent;root:padSettings;priority:5;closeOnBack:false;tabHints:true}
        }}
        Component {id:padPolkitView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Rectangle {anchors.fill:parent;color:"#66000000"}
            Opal.PolkitCard {id:padCard;anchors.centerIn:parent;message:"Authentication is required to install software.";identity:"unix-user:melissa"}
            Opal.ControllerFocus {anchors.fill:parent;root:padCard;priority:30;closeOnBack:false;preferText:true}
        }}
        Component {id:polkitView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Rectangle {anchors.fill:parent;color:"#66000000"}
            Opal.PolkitCard {anchors.centerIn:parent;message:"Authentication is required to install software.";identity:"unix-user:melissa"}
        }}
        Component {id:onboardingView;Item {
            Opal.Surface {anchors.fill:parent;radius:0
                Opal.Onboarding {anchors.fill:parent;step:fixture.cases[fixture.step].step||0}}
        }}
        Component {id:dockMenuView;Opal.DockScene {output:"HDMI-A-1";description:"Living room TV";apps:[{address:"0x1",title:"Mozilla Firefox",className:"firefox"},{address:"0x3",title:"Deltarune",className:"steam_app_1"}];modes:["3840x2160@60.00Hz","1920x1080@60.00Hz"];remembered:({mode:"console",phoneMode:"trackpad",resolution:"",scale:1})}}
        Component {id:phoneDockView;Opal.PhoneDockPanel {}}
        Component {id:barsView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Opal.WorkspacePill {visible:!!fixture.cases[fixture.step].pill;anchors.horizontalCenter:parent.horizontalCenter;y:10;shown:2}
            Opal.DesktopShelf {visible:Opal.Hub.prefs.barStyle==="split"&&!fixture.cases[fixture.step].pill;part:"top";anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;height:56}
            Opal.DesktopShelf {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:Opal.Hub.prefs.barStyle==="edge" ? 52 : 64}
        }}
        Component {id:workspaceView;Item {
            property alias shelf:workspaceShelf
            Opal.Wallpaper {anchors.fill:parent}
            Opal.DesktopShelf {id:workspaceShelf;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:64}
        }}
        // Re-applied while a scene renders, because the isolated backend also answers.
        function applyTaskFixture() {
            const test=cases[step];
            if(test.task||test.ui==="tabletdock"||test.ui==="battery"||test.ui==="gesture"||test.ui==="lockfx") {
                Opal.PhoneState.activity={files:[{title:"Trip budget.ods",path:"/x/a",icon:"description",ago:"12 min ago",when:1},{title:"Boarding pass.pdf",path:"/x/b",icon:"picture_as_pdf",ago:"2 h ago",when:1},{title:"Beach.jpg",path:"/x/c",icon:"image",ago:"Yesterday",when:1}],games:[{id:"steam:1",title:"Celeste",cover:"",ago:"Yesterday",when:1}]};
                Opal.PhoneState.torch={available:true,on:false,name:"white:flash"};
                Opal.PhoneState.battery={available:true,status:test.light ? "Charging" : "Discharging",percent:64,watts:3.4,volts:3.92,hours:6.4,health:91,cycles:212,celsius:31.5};
                const base=Date.now()-3600000;Opal.PhoneState.batteryHistory=Array.from({length:30},(_,i)=>({t:base+i*120000,percent:Math.round(80-i*.55),watts:3}));
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{track:"Evening Drive",artist:"Local player",playing:false,battery:64,charging:!!test.light,profile:"balanced"});
                Opal.Hub.linkDevices=[{id:"a".repeat(32),name:"OnePlus 7",paired:true,reachable:true,session:{app:"firefox",appName:"Firefox",title:"Hyprland wiki",track:"",playing:false}}];
            }
        }
        Timer {interval:100;repeat:true;running:fixture.step<fixture.cases.length&&!!(fixture.cases[fixture.step].task||fixture.cases[fixture.step].ui==="battery");onTriggered:fixture.applyTaskFixture()}
        function scrollEnd(item) {
            if(item.contentHeight!==undefined&&item.contentHeight>item.height)item.contentY=item.contentHeight-item.height;
            for(let child of item.children||[])scrollEnd(child);
        }
        function next() {
            if(step>=cases.length) {console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            // Every "on" colour must contrast with its container; a stuck binding shows up as black on dark.
            Qt.callLater(()=>{const T=Opal.Theme;const lin=v=>v<=.03928 ? v/12.92 : Math.pow((v+.055)/1.055,2.4);const lum=c=>{c=Qt.color(c);return .2126*lin(c.r)+.7152*lin(c.g)+.0722*lin(c.b);};
                [["onSecondaryContainer","secondaryContainer"],["onTertiaryContainer","tertiaryContainer"],["onContainer","primaryContainer"],["onPrimary","primary"],["text","base"]].forEach(([fg,bg])=>{
                    const l1=lum(T[fg]),l2=lum(T[bg]);const ratio=(Math.max(l1,l2)+.05)/(Math.min(l1,l2)+.05);
                    if(ratio<4.5)console.error("ASSERTION_FAILED: low contrast "+fg+" "+T[fg]+" on "+bg+" "+T[bg]+" ("+ratio.toFixed(2)+") palette "+Opal.Hub.prefs.palette+" dynamic "+!!Opal.Hub.prefs.dynamicColors+" light "+T.light+" in "+cases[step].name);});});
            const test=cases[step];
            view.sourceComponent=null;
            width=test.w;height=test.h;musicVolume=40;
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{mode:test.ui==="convergence"||test.ui==="glass"||test.ui==="dock" ? "auto" : test.ui,light:!!test.light,phoneButtons:!!test.buttons,controllerLayout:test.nintendo ? "nintendo" : "standard",phoneGestures:test.gestures||{}});
            Opal.Hub.mobileTab=test.recent ? "recent" : test.apps||test.drawer ? "apps" : "home";
            if(test.recent) {
                const fixtureWindows=[{title:"Project notes",className:"org.kde.kate",workspace:1,address:"fixture-1"},{title:"A good playlist",className:"firefox",workspace:2,address:"fixture-2"}];
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,windows:fixtureWindows});
                Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=fixtureWindows;
            } else {
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:false});
                Opal.Hub.compositorActive=false;Opal.Hub.compositorWindows=[];
            }
            Opal.Hub.controlDetail=test.detail||"";
            if(test.ui==="assistant")assistantFixture(test);
            if(test.devices)Qt.callLater(()=>{const c=Object.assign({},Opal.Hub.connectivity);
                c.bluetooth=Object.assign({},c.bluetooth,{powered:true,busy:false,error:"",items:[{address:"AA",name:"soundcore Q20i",active:true,paired:true},{address:"BB",name:"Pixel Buds",active:false,paired:true},{address:"CC",name:"Living room speaker",active:false,paired:false}]});
                c.wifi=Object.assign({},c.wifi,{powered:true,busy:false,error:"",items:[{ssid:"Home Wi-Fi",signal:82,security:"WPA2",device:"wlan0",active:true,saved:true},{ssid:"Office",signal:60,security:"WPA2",device:"wlan0",active:false,saved:true},{ssid:"Cafe guest",signal:30,security:"",device:"wlan0",active:false,saved:false}]});
                Opal.Hub.connectivity=c;});
            if(test.ui==="clipboard"||test.ui==="dashboard") {
                const samples=["A little thought worth keeping.","https://m3.material.io/","const idea = {\n  color: 'expressive',\n  mood: 'quiet'\n};","Meet at 16:30. Bring the good playlist."];
                Opal.Hub.clipboardAvailable=true;
                Opal.Hub.clipboardItems=test.empty ? [] : samples.map((t,i)=>({id:"fixture-"+i,text:t,chars:t.length,lines:t.split(String.fromCharCode(10)).length,kind:i===1 ? "Link" : i===2 ? "Snippet" : "Text",captured:0}));
            }
            if(test.ui==="dock") {
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{displayModes:{"phone-fixture":"phone"}});
                if(Opal.Hub.layoutFor(1920,1080,"monitor-fixture")!=="desktop"||Opal.Hub.layoutFor(1080,1920,"phone-fixture")!=="phone"||Opal.Hub.layoutFor(390,844,"small-fixture")!=="phone")console.error("ASSERTION_FAILED: per-display convergence");
                if(Opal.Hub.dockNotice)console.error("ASSERTION_FAILED: docking welcome opened at startup");
                const ready=Opal.Hub.displaysReady;
                const known=Opal.Hub.knownDisplays;
                const page=Opal.Hub.page;
                Opal.Hub.displaysReady=true;Opal.Hub.knownDisplays=["internal-fixture"];
                Opal.Hub.updateDisplays([{name:"internal-fixture"},{name:"external-fixture"}]);
                if(!Opal.Hub.dockNotice||Opal.Hub.dockScreen.name!=="external-fixture"||Opal.Hub.page!==page)console.error("ASSERTION_FAILED: nonexclusive hotplug welcome");
                if(Opal.Hub.dockMenu)console.error("ASSERTION_FAILED: hotplug opened the full dock menu");
                Opal.Hub.updateDisplays([{name:"internal-fixture"}]);
                if(Opal.Hub.dockNotice||Opal.Hub.dockScreen!==null)console.error("ASSERTION_FAILED: unplug cleanup");
                Opal.Hub.knownDisplays=known;Opal.Hub.displaysReady=ready;
            }
            if(test.drag) {
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{favorites:[],pinsConfigured:true,taskbarOrder:[]});
                const fixtureWindows=Array.from({length:40},(_,i)=>({className:"Fixture-"+i,title:"Fixture "+i,address:"fixture-"+i,workspace:1}));
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,windows:fixtureWindows});
                Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=fixtureWindows;
            }
            if(test.ui==="phonebars")Opal.Hub.status=Object.assign({},Opal.Hub.status,{battery:73,charging:true,wifi:true,network:"Home Wi-Fi"});
            if(test.ui==="search") {
                Opal.Hub.apps=[{id:"firefox",name:"Firefox",genericName:"Web browser",icon:"firefox",keywords:["internet"],categories:["Network"],execute:()=>{}},{id:"files",name:"Files",genericName:"File manager",icon:"system-file-manager",keywords:["folders"],categories:["System"],execute:()=>{}},{id:"terminal",name:"Terminal",genericName:"Command line",icon:"utilities-terminal",keywords:["shell"],categories:["System"],execute:()=>{}},{id:"code",name:"Visual Studio Code",genericName:"Code editor",icon:"code",keywords:["editor"],categories:["Development"],execute:()=>{}},{id:"music",name:"Music",icon:"multimedia-player",keywords:[],categories:["AudioVideo"],execute:()=>{}},{id:"notes",name:"Notes",icon:"text-editor",keywords:[],categories:["Office"],execute:()=>{}}];
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{palette:1,dynamicColors:!test.light,favorites:["firefox","files"],pinsConfigured:true,recent:["files","code","firefox","notes"]});
                Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=[{title:"Final report.pdf",className:"firefox",address:"fixture-report",workspace:2}];
                Opal.Hub.query=test.searchText||"";
                if(test.searchText&&test.searchText.startsWith("12"))Opal.Hub.calculation="84";
            }
            if(test.ui==="console"){const art=i=>"file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-"+(i%3+1)+".png";
                fixture.consoleGames=[{id:"steam:1",title:"Deltarune",source:"Steam",cover:art(0),hero:"file://"+Quickshell.env("HOME")+"/Ocean.png",lastPlayed:1790000000,windowClass:"steam_app_1"},{id:"steam:2",title:"Kerbal Space Program",source:"Steam",cover:art(1),lastPlayed:1789000000,windowClass:""},{id:"prism:a",title:"JevCraft Survival",source:"Minecraft",cover:"",lastPlayed:1788000000,windowClass:"Minecraft"},{id:"prism:b",title:"1.21",source:"Minecraft",cover:"",lastPlayed:0,windowClass:"Minecraft"},{id:"steam:3",title:"Stellaris",source:"Steam",cover:art(2),lastPlayed:0,windowClass:""},{id:"lutris:x",title:"Celeste",source:"Lutris",cover:"",lastPlayed:0,windowClass:""}];Opal.Hub.games=fixture.consoleGames;}
            Opal.Activities.fixture=test.activities ? activityFixture(test.activities) : null;
            Opal.Activities.chipFixture=test.ui==="chips" ? [{id:"code:1:554433",kind:"code",label:"Copy code 554433",detail:"Bank",icon:"copy",arg:"554433"},{id:"dock:HDMI-A-1",kind:"dock",label:"Use as desktop",detail:"HDMI-A-1",icon:"desktop",arg:"HDMI-A-1"},{id:"continue:a:firefox",kind:"continue",label:"Continue Firefox",detail:"Living room PC",icon:"link",arg:"firefox"},{id:"saver",kind:"saver",label:"Battery saver",detail:"12%",icon:"battery",arg:""}] : null;
            if(test.monitors)monitorFixture.restart();
            if(false)Qt.callLater(()=>Opal.Hub.monitors=[{name:"eDP-1",description:"Built-in display",width:2560,height:1600,refresh:120,x:0,y:0,scale:1.5,transform:0,disabled:false,mirror:"none",modes:["2560x1600@120.00Hz","2560x1600@60.00Hz","1920x1200@60.00Hz"]},{name:"HDMI-A-1",description:"Dell U2720Q",width:1920,height:1080,refresh:60,x:1707,y:0,scale:1,transform:0,disabled:false,mirror:"none",modes:["1920x1080@60.00Hz","1280x720@60.00Hz"]}]);
            if(test.schedules)Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{schedules:{nightLight:{enabled:true,mode:"sun",temperature:3800},darkMode:{enabled:true,mode:"custom",from:"19:30",to:"07:00"}}});
            if(test.profiles)Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{profiles:{"Work":{barStyle:"edge",light:true},"Gaming night":{barStyle:"dock",light:false}}});
            if(test.health)Qt.callLater(()=>{Opal.Hub.health={disks:[{label:"System",total:495810760704,used:415556063232,percent:84}],temperatures:{k10temp:58,amdgpu:52,nvme:41},hottest:58};Opal.Hub.updates={pacman:12,flatpak:3};});
            if(test.link){Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{linkEnabled:true});linkFixture.restart();}
            if(test.ui==="phonedock"){Opal.Hub.docked=true;Opal.Hub.dockOutput="HDMI-A-1";Opal.Hub.phoneDockMode="trackpad";}
            if(test.ui==="lock")Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{wallpaperPath:"file://"+Quickshell.env("HOME")+"/Ocean.png",wallpaperDim:0});
            if(test.ui==="reference"||test.ui==="bars") {
                Opal.Hub.apps=[{id:"firefox",name:"Firefox",genericName:"Web browser",icon:"firefox",keywords:["internet"],categories:["Network"],execute:()=>{}},{id:"files",name:"Files",genericName:"File manager",icon:"system-file-manager",keywords:["folders"],categories:["System"],execute:()=>{}},{id:"terminal",name:"Terminal",genericName:"Command line",icon:"utilities-terminal",keywords:["shell"],categories:["System"],execute:()=>{}},{id:"code",name:"Visual Studio Code",genericName:"Code editor",icon:"code",keywords:["editor"],categories:["Development"],execute:()=>{}},{id:"music",name:"Music",icon:"multimedia-player",keywords:[],categories:["AudioVideo"],execute:()=>{}},{id:"notes",name:"Notes",icon:"text-editor",keywords:[],categories:["Office"],execute:()=>{}}];
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{palette:1,dynamicColors:!test.tide,desktopWidgets:true,recent:["files","code","firefox","notes"],favorites:["firefox","files"]});
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{battery:73,charging:true,wifi:true,network:"Oasis WLAN",bluetooth:false,brightness:58,volume:32,muted:false,profile:"balanced",hypr:true,workspace:2,workspaces:[1,2,3,5]});
                Opal.Hub.focusRunning=!!test.music;Opal.Hub.focusSeconds=17*60+42;
            }
            if(test.shelf) {
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{palette:1});
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{battery:73,charging:true,wifi:true});
            }
            // Hyprland event fixture: two windows, the web one urgent, and an optional submap.
            Opal.Hub.status=Object.assign({},Opal.Hub.status,{urgent:test.hyprFix ? ["fixture-web"] : [],submap:test.submap||""});
            if(test.hyprFix){Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=[{title:"Project notes",className:"code",address:"fixture-project",workspace:1,at:[0,0],size:[960,1080]},{title:"Mozilla Firefox",className:"firefox",address:"fixture-web",workspace:1,at:[960,0],size:[960,1080]}];Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,workspace:1,workspaces:[1],activeAddress:"fixture-project",monitors:[{name:"M",workspace:1,x:0,y:0,width:1920,height:1080,scale:1,transform:0}]});}
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{barStyle:test.barStyle||"islands"});
            if(test.ui==="bars")Opal.Hub.compositorActive=true,Opal.Hub.compositorWindows=[{title:"Project notes",className:"code",address:"fixture-project",workspace:2},{title:"Mozilla Firefox",className:"firefox",address:"fixture-web",workspace:1}];
            Opal.Hub.osdScreen=null;Opal.Hub.osd=test.osd ? "Volume" : "";
            if(test.music)Opal.Hub.status=Object.assign({},Opal.Hub.status,{track:"A little evening music",artist:"Local player",art:"file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-1.png",playing:true,volume:40,audioOutput:"Headphones"});
            if(test.ui==="osd")Opal.Hub.status=Object.assign({},Opal.Hub.status,{volume:64,muted:false,audioOutput:"Speakers · Built-in audio"});
            if(test.ui==="start") {
                Opal.Hub.apps=[{id:"firefox",name:"Firefox",genericName:"Web browser",icon:"firefox",keywords:["internet"],categories:["Network"],execute:()=>{}},{id:"files",name:"Files",genericName:"File manager",icon:"system-file-manager",keywords:["folders"],categories:["System"],execute:()=>{}},{id:"terminal",name:"Terminal",genericName:"Command line",icon:"utilities-terminal",keywords:["shell"],categories:["System"],execute:()=>{}},{id:"code",name:"Visual Studio Code",genericName:"Code editor",icon:"code",keywords:["editor"],categories:["Development"],execute:()=>{}},{id:"music",name:"Music",icon:"multimedia-player",keywords:[],categories:["AudioVideo"],execute:()=>{}},{id:"notes",name:"Notes",icon:"text-editor",keywords:[],categories:["Office"],execute:()=>{}}];
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{palette:1,favorites:["firefox","files","terminal","code","music","notes"],pinsConfigured:true,recent:["code","firefox"]});
                Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=[{title:"Project notes",className:"code",address:"fixture-project",workspace:2}];
                Opal.Hub.query=test.searchText||"";Opal.Hub.page="launcher";Opal.Hub.launcherSection="apps";
                Opal.Hub.claudeAnswer=test.claude ? "Done. Your bar is now a **dock**: one pill with apps on the left and status on the right." : "";Opal.Hub.claudeTools=test.claude ? ["get preferences","set preference"] : [];
            }
            applyTaskFixture();
            if(test.ui==="gesture") {
                const gw=[{title:"Project notes",className:"org.kde.kate",workspace:1,address:"fixture-1"},{title:"A good playlist",className:"firefox",workspace:2,address:"fixture-2"}];
                Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=gw;Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:false,activeAddress:"fixture-1"});
                Opal.PhoneState.phase=test.gesture;Opal.PhoneState.progress=test.progress||0;Opal.PhoneState.dx=test.dx||0;Opal.PhoneState.dy=test.gesture==="back" ? test.h*(test.edgeY||.4) : -(test.progress||0)*test.h*.5;Opal.PhoneState.edge=test.edge||-1;Opal.PhoneState.edgeY=test.edgeY||.4;Opal.PhoneState.edgeHeld=!!test.held;
            } else if(Opal.PhoneState.phase!=="")Opal.PhoneState.finish();
            if(test.filterText)Opal.Hub.query=test.filterText;
            // Quick Access and controller-focus fixtures. A controller is "connected" only in these scenes.
            Opal.GameState.quickAccess=false;Opal.Hub.controller=!!test.pad;Opal.ControllerNav.usingController=!!test.pad;
            Opal.Hub.locked=!!test.pad&&test.ui==="lock";
            if(test.ui==="quickaccess") {
                const art=i=>"file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-"+(i%3+1)+".png";
                Opal.Hub.games=[{id:"steam:1",title:"Deltarune",source:"Steam",cover:art(0),hero:"file://"+Quickshell.env("HOME")+"/Ocean.png",lastPlayed:1790000000,windowClass:"steam_app_1"},{id:"steam:2",title:"Kerbal Space Program",source:"Steam",cover:art(1),lastPlayed:1789000000,windowClass:"steam_app_2"},{id:"lutris:x",title:"Celeste",source:"Lutris",cover:"",lastPlayed:1788000000,windowClass:""}];
                const live=test.noGame ? [] : [{title:"Deltarune",className:"steam_app_1",address:"fixture-game",workspace:1},{title:"Mozilla Firefox",className:"firefox",address:"fixture-web",workspace:2}];
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,windows:live,battery:73,charging:false,brightness:62,volume:48,muted:false,wifi:true,network:"Home Wi-Fi",bluetooth:true,profile:"balanced",fullscreenMonitors:test.noGame ? [] : ["fixture"]});
                Opal.Hub.compositorActive=true;Opal.Hub.compositorWindows=live;
                Opal.GameState.seenAt=new Date(Date.now()-42*60000);
                Opal.GameState.receive({event:"gamePerf",fpsLimit:60,overlay:"compact",mangohud:true,gamemode:{available:true,active:true,clients:1},profiles:{available:true,profiles:["power-saver","balanced","performance"],active:"balanced"},tdp:test.noTdp ? null : {watts:15,min:4,max:25},gpu:test.noTdp ? null : {level:"auto"},controllers:[{name:"DualSense",percent:64,charging:false},{name:"Xbox Controller",percent:12,charging:false}]});
                Opal.GameState.stage=test.glance ? "glance" : "sheet";
                Opal.GameState.quickAccess=true;
            }
            view.sourceComponent=test.ui==="assistant" ? assistantView : test.ui==="pill" ? pillView : test.ui==="chips" ? chipsView : test.ui==="undotoast" ? undoToastView : test.ui==="layoutmorph" ? morphView : test.ui==="tabletdock" ? tabletDockView : test.ui==="battery" ? batteryView : test.ui==="gesture" ? gestureView : test.ui==="lockfx" ? lockFxView : test.ui==="start" ? startView : test.ui==="osd" ? osdView : test.ui==="phonebars" ? phoneBars : test.ui==="shapes" ? shapeView : test.ui==="audio" ? audioView : test.ui==="taskbar" ? taskbarView : test.ui==="switcher" ? switcherView : test.ui==="wallpaper" ? wallpaperStudio : test.ui==="dock" ? dockView : test.ui==="glass" ? glassView : test.ui==="convergence" ? convergenceView : test.ui==="keyboard" ? keyboardView : test.ui==="desktop" ? desktop : test.ui==="phone" ? phone : test.ui==="clipboard" ? clipboardView : test.ui==="dashboard" ? dashboardView : test.ui==="workspace" ? workspaceView : test.ui==="bars" ? barsView : test.ui==="dockmenu" ? dockMenuView : test.ui==="phonedock" ? phoneDockView : test.ui==="onboarding" ? onboardingView : test.ui==="lock" ? lockView : test.ui==="polkit" ? polkitView : test.ui==="reference" ? referenceView : test.ui==="search" ? searchView : test.ui==="menus" ? menusView : test.ui==="shade" ? shadeView : test.ui==="appearance" ? appearanceView : test.ui==="quickaccess" ? quickAccessView : test.ui==="padsettings" ? padSettingsView : test.ui==="padpolkit" ? padPolkitView : gaming;
            if(test.ui==="quickaccess"){view.item.qa.tabIndex=test.tab||0;}
            if(test.qs!==undefined)view.item.phone=true;
            // A sheet made with a detail request must show that detail, not a blank card.
            if(test.ui==="shade"&&test.detail&&view.item.detailKind!==test.detail)console.error("ASSERTION_FAILED: detail lost at sheet creation in "+test.name);
            if(test.detailGrow!==undefined){const it=view.item;it.detailOrigin=Qt.rect(14,150,150,36);it.detailKind="wifi";it.detail=test.detailGrow;}
            if(test.ui==="console"){
                if(test.tab)view.item.category=test.tab;
                if(test.hub!==undefined){view.item.menuTab=test.hub;view.item.menuOpen=true;}
                if(test.detail){Opal.GameState.detail={id:"steam:1",playtimeMinutes:754,lastPlayed:1790000000,sizeBytes:5400000000,uninstallable:true};view.item.detailOpen=true;}
                else Opal.GameState.detail=({id:"steam:1",playtimeMinutes:754,lastPlayed:1790000000,sizeBytes:5400000000,uninstallable:true});
            }
            if(test.ui==="padsettings")Opal.Hub.settingsSection=test.section||"";
            if(test.pad)padInput.restart();
            if(test.pinPill){const holder=test.ui==="lockfx" ? view.item.extras : view.item.statusBar;Qt.callLater(()=>holder.pill.pinned=true);}
            if(test.ui==="start") {
                view.item.menu.section=test.allApps ? "all" : "pinned";
                Qt.callLater(()=>{
                    const menu=view.item.menu;
                    if(test.searchText==="firefx"&&(!menu.selected||menu.selected.data.id!=="firefox"))console.error("ASSERTION_FAILED: start typo ranking");
                    if(test.searchText==="@ Project"&&(!menu.selected||menu.selected.kind!=="window"))console.error("ASSERTION_FAILED: start window search");
                    if(test.searchText===">") {
                        menu.move(1);
                        if(menu.selection!==1||menu.selected.kind!=="action")console.error("ASSERTION_FAILED: start action navigation");
                    }
                    if(test.searchText==="zzzzzzzz"&&menu.results.length)console.error("ASSERTION_FAILED: start empty search");
                    if(!test.searchText&&!test.allApps) {
                        Opal.Hub.query="Firefox";menu.goBack();
                        if(Opal.Hub.query!==""||Opal.Hub.page!=="launcher")console.error("ASSERTION_FAILED: Escape must clear search before closing");
                    }
                });
            }
            if(test.ui==="layoutmorph") {
                const morph=view.item.morph;
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{reduceMotion:true});
                morph.layout="desktop";
                if(morph.shown!=="desktop")console.error("ASSERTION_FAILED: reduced motion morph must swap at once");
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{reduceMotion:false});
                morph.layout="phone";
                if(!morph.morphing||morph.shown!=="desktop")console.error("ASSERTION_FAILED: morph must hold the old layout during phase one");
                Qt.callLater(()=>{});
            }
            if(test.ui==="settings") {Opal.Hub.settingsSection=test.section||"";view.sourceComponent=settingsView;}
            if(test.ui==="tiles") {
                view.sourceComponent=tilesView;
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{quickTiles:["wifi","theme","bluetooth"]});
                view.item.move("bluetooth",-1);
                if(view.item.order.join(",")!=="wifi,bluetooth,theme")console.error("ASSERTION_FAILED: quick tile reorder");
                view.item.change("wifi");
                if(view.item.order.indexOf("wifi")!==-1)console.error("ASSERTION_FAILED: quick tile removal");
                view.item.change("capture");
                if(view.item.order[view.item.order.length-1]!=="capture")console.error("ASSERTION_FAILED: quick tile addition");
            }
            if(test.ui==="keyboard") {
                const field=view.item.input;
                const keyboard=view.item.keyboard;
                field.text="abcd";field.cursorPosition=2;keyboard.press("x");
                if(field.text!=="abxcd"||field.cursorPosition!==3)console.error("ASSERTION_FAILED: keyboard middle insertion",field.text,field.cursorPosition);
                field.select(1,4);keyboard.press("q");
                if(field.text!=="aqd"||field.cursorPosition!==2)console.error("ASSERTION_FAILED: keyboard selection replacement",field.text,field.cursorPosition);
                field.text="A😀";field.cursorPosition=field.text.length;keyboard.press("⌫");
                if(field.text!=="A")console.error("ASSERTION_FAILED: keyboard emoji backspace",field.text);
                field.text="é";field.cursorPosition=field.text.length;keyboard.press("⌫");
                if(field.text!=="")console.error("ASSERTION_FAILED: keyboard combining backspace",field.text);
                field.text="ab";field.cursorPosition=1;keyboard.press("RIGHT");keyboard.press("LEFT");
                if(field.cursorPosition!==1)console.error("ASSERTION_FAILED: keyboard cursor movement",field.cursorPosition);
                field.text="";field.cursorPosition=0;keyboard.press("SHIFT");keyboard.press("q");
                if(field.text!=="Q"||keyboard.shift)console.error("ASSERTION_FAILED: keyboard one-shot shift",field.text,keyboard.shift);
                keyboard.toggleCaps();keyboard.press("w");keyboard.press("e");
                if(field.text!=="QWE"||!keyboard.capsLock)console.error("ASSERTION_FAILED: keyboard caps lock",field.text,keyboard.capsLock);
                keyboard.press("SHIFT");field.text="repeat";field.cursorPosition=field.text.length;keyboard.beginBackspace();keyboard.endBackspace();
                if(field.text!=="repea")console.error("ASSERTION_FAILED: keyboard backspace press",field.text);
                field.text="Material You";field.cursorPosition=field.text.length;
            }
            if(test.osk)view.item.keyboardOpen=true;
            if(test.shelf||test.ui==="reference") {
                view.item.shelf.strip.groups=Array.from({length:7},(_,i)=>({key:"shelf-"+i,name:"Application "+i,icon:["system-file-manager","utilities-terminal","web-browser","preferences-system","text-editor","multimedia-player","mail-client"][i],windows:[]}));
                Qt.callLater(()=>{
                    const shelf=view.item.shelf;
                    if(shelf.leftIsland.x+shelf.leftIsland.width>shelf.rightIsland.x-8)console.error("ASSERTION_FAILED: shelf islands overlap");
                    if(shelf.strip.labels!==(!!Opal.Hub.prefs.taskbarLabels&&shelf.strip.groups.length<=6)||!shelf.strip.islandStyle)console.error("ASSERTION_FAILED: shelf preferences not applied");
                });
            }
            if(test.ui==="phonebars") {
                view.item.navigation.go("recent");
                if(!Opal.PhoneState.recentsOpen)console.error("ASSERTION_FAILED: phone recents");
                view.item.navigation.back();
                if(Opal.PhoneState.recentsOpen)console.error("ASSERTION_FAILED: phone recents dismiss");
                view.item.navigation.go("apps");
                view.item.navigation.back();
                if(Opal.Hub.mobileTab!=="home"||Opal.Hub.page!=="launcher")console.error("ASSERTION_FAILED: phone contextual back");
                view.item.navigation.back();
                if(Opal.Hub.page!=="")console.error("ASSERTION_FAILED: phone dismiss");
            }
            if(test.ui==="switcher") {
                view.item.layoutMode=test.phone ? "phone" : test.game ? "console" : "desktop";
                if(test.phone)Qt.callLater(()=>{if(view.item.touchCarousel)console.error("ASSERTION_FAILED: wide phone switcher uses carousel");});
                view.item.navigate("right");
                if(view.item.selection!==1)console.error("ASSERTION_FAILED: switcher navigation");
                view.item.query="Project";
                if(view.item.windows.length!==1)console.error("ASSERTION_FAILED: switcher filtering");
                view.item.query="";
            }
            if(test.ui==="dock") {
                view.item.phone=!!test.phone;view.item.hasPhone=!!test.phone;
                view.item.displayName=test.phone ? "Dell U2720Q" : "LG UltraFine";
                view.item.screenMode=test.docked ? "desktop" : "";
                view.item.result=test.docked ? {moved:3} : null;
            }
            if(test.ui==="wallpaper") {
                const original=JSON.stringify(Opal.Hub.prefs);
                view.item.draftPath="";view.item.draftDim=.15;
                if(test.browse)Opal.Hub.browseWallpaperFolder(Quickshell.env("HOME")+"/Pictures");
                if(test.photo){view.item.draftPath="file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-1.png";Opal.Hub.browseWallpapers(Quickshell.env("HOME")+"/Pictures/Wallpapers");}
                if(JSON.stringify(Opal.Hub.prefs)!==original)console.error("ASSERTION_FAILED: preview mutated preferences");
            }
            if(test.drawer&&view.item.columns>7)console.error("ASSERTION_FAILED: unbounded touch grid");
            if(test.phone&&test.ui==="clipboard")view.item.touchMode=true;
            if(test.scroll)Qt.callLater(()=>scrollEnd(view.item));
            if(test.apps)view.item.keyboardOpen=true;
            if(test.search) {
                view.item.navigate("search");
                view.item.navigate("accept");
                view.item.navigate("right");
                view.item.navigate("accept");
                if(view.item.query!=="qw")console.error("ASSERTION_FAILED: controller keyboard",view.item.query);
            }
            if(test.menu) {
                view.item.navigate("menu");
                view.item.navigate("nextTab");
                if(view.item.menuTab!==1||view.item.menuIndex!==0)console.error("ASSERTION_FAILED: play hub category");
                view.item.navigate("down");
                if(view.item.menuIndex!==1)console.error("ASSERTION_FAILED: play hub selection");
                view.item.navigate("back");
                if(view.item.menuOpen)console.error("ASSERTION_FAILED: play hub back");
                view.item.navigate("menu");view.item.menuTab=test.section||0;view.item.menuIndex=0;
                if(test.nintendo&&view.item.acceptButton!=="B")console.error("ASSERTION_FAILED: swapped button hints");
            }
            if(test.ui==="console"&&!test.search&&!test.menu&&!test.detail&&test.hub===undefined) {
                view.item.navigate("right");
                if(view.item.library.length>1&&view.item.selection!==1)console.error("ASSERTION_FAILED: controller grid");
                view.item.navigate("left");
            }
            if(test.ui==="shapes")Qt.callLater(()=>{
                if(Opal.Theme.onPrimary.toString()!==Opal.Theme.primaryInk.toString())console.error("ASSERTION_FAILED: primary foreground alias lost its color");
                if(view.item.enabledTile.color.toString()===view.item.disabledTile.color.toString())console.error("ASSERTION_FAILED: tile states need different fills");
                if(view.item.enabledTile.radius>=view.item.disabledTile.radius)console.error("ASSERTION_FAILED: on/off shape morph");
                if(view.item.enabledTile.toggleSize<=view.item.enabledTile.iconSize)console.error("ASSERTION_FAILED: toggle target did not grow beyond icon");
                if(view.item.enabledTile.color.toString()!==Opal.Theme.tileActive.toString())console.error("ASSERTION_FAILED: active tile lost its accent fill");
                if(view.item.disabledTile.toggleColor.toString()===Opal.Theme.primary.toString())console.error("ASSERTION_FAILED: inactive toggle target looks enabled");
                if(view.item.enabledTile.toggleRadius>=view.item.enabledTile.toggleSize/2)console.error("ASSERTION_FAILED: active toggle lost its rounded-square shape");
                if(view.item.disabledTile.toggleRadius!==view.item.disabledTile.toggleSize/2)console.error("ASSERTION_FAILED: inactive toggle is not circular");
                const tile=view.item.enabledTile;
                const togglePoint=tile.mapToItem(view.item,8+tile.toggleSize/2,tile.height/2);
                input.mousePress(view.item,togglePoint.x,togglePoint.y,Qt.LeftButton);
                input.mouseRelease(view.item,togglePoint.x,togglePoint.y,Qt.LeftButton);
                const detailsPoint=tile.mapToItem(view.item,tile.mainHitLeft+16,tile.height/2);
                input.mousePress(view.item,detailsPoint.x,detailsPoint.y,Qt.LeftButton);
                input.mouseRelease(view.item,detailsPoint.x,detailsPoint.y,Qt.LeftButton);
                if(view.item.toggleHits!==1||view.item.navigationHits!==1)console.error("ASSERTION_FAILED: split tile actions are not independent");
                if(view.item.slider.handle.height<=view.item.slider.background.height)console.error("ASSERTION_FAILED: tall slider handle");
            });
            if(test.wheel)Qt.callLater(()=>{
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{volume:40});
                input.mouseWheel(view.item,220,150,0,120);
                if(Opal.Hub.status.volume!==42)console.error("ASSERTION_FAILED: audio wheel volume");
                input.mouseWheel(view.item,220,277,0,120);
                if(Opal.Hub.status.volume!==44)console.error("ASSERTION_FAILED: audio slider wheel double handled");
                fixture.musicVolume=Opal.Hub.status.volume;
            });
            if(test.drag)Qt.callLater(()=>{
                input.mousePress(view.item,22,32,Qt.LeftButton);
                input.mouseMove(view.item,58,32,40);
                input.mouseMove(view.item,130,32,40);
                if(!view.item.dragging)console.error("ASSERTION_FAILED: taskbar mouse drag did not begin");
            });
            console.log("THEME",test.name,Opal.Theme.primary,Opal.Theme.onPrimary);
            capture.restart();
        }
        Timer {
            id:padInput;interval:220
            onTriggered:{
                const test=fixture.cases[fixture.step];
                if(test.guard) {
                    Opal.Hub.page="";Opal.GameState.quickAccess=false;
                // Nothing is open: only Guide may react, so a game never loses its input to Opal.
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{mode:"desktop"});
                ["accept","down","back","pin","menu","nextTab"].forEach(key=>Opal.ControllerNav.input(key));
                if(Opal.GameState.quickAccess||Opal.Hub.page!=="")console.error("ASSERTION_FAILED: controller input leaked with nothing open");
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{quickAccessGuide:false});
                Opal.ControllerNav.input("home");
                if(Opal.GameState.quickAccess)console.error("ASSERTION_FAILED: Guide ignored the quickAccessGuide setting");
                Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{quickAccessGuide:true});
                // No game in front: Guide opens the sheet and closes it.
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{fullscreenMonitors:[]});Opal.Hub.compositorWindows=[];
                Opal.ControllerNav.input("home");
                if(!Opal.GameState.quickAccess||Opal.GameState.stage!=="sheet")console.error("ASSERTION_FAILED: Guide did not open the Quick Access sheet");
                Opal.ControllerNav.input("home");
                if(Opal.GameState.quickAccess)console.error("ASSERTION_FAILED: Guide did not close Quick Access");
                // A game in front: glance, then the sheet, then closed.
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{fullscreenMonitors:["fixture"]});
                Opal.ControllerNav.input("home");
                if(Opal.GameState.stage!=="glance")console.error("ASSERTION_FAILED: Guide over a game did not show the glance");
                Opal.ControllerNav.input("home");
                if(!Opal.GameState.quickAccess||Opal.GameState.stage!=="sheet")console.error("ASSERTION_FAILED: Guide on the glance did not open the sheet");
                Opal.ControllerNav.input("home");
                if(Opal.GameState.quickAccess)console.error("ASSERTION_FAILED: Guide on the sheet did not close Quick Access");
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{fullscreenMonitors:[]});
            }
                // Settings page: the first press chooses a start item. Later presses move through the real focus engine.
                (test.pad||[]).forEach(key=>Opal.ControllerNav.input(key));
                if(test.expectClosed&&Opal.GameState.quickAccess)console.error("ASSERTION_FAILED: B did not close Quick Access");
                if(test.expectTab!==undefined&&view.item.qa.tabIndex!==test.expectTab)console.error("ASSERTION_FAILED: RB did not switch sections",view.item.qa.tabIndex);
            }
        }
        Timer {
            id:capture;interval:600
            onTriggered:{
                if(fixture.cases[fixture.step].ui==="keyboard"&&view.item.input.text!=="Material You")console.error("ASSERTION_FAILED: keyboard repeat did not cancel",view.item.input.text);
                fixture.contentItem.grabToImage(result=>{
                    result.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");
                    console.log("RENDERED",fixture.cases[fixture.step].name,view.item.width,view.item.height);
                    if(fixture.cases[fixture.step].drag){
                        input.mouseRelease(view.item,130,32,Qt.LeftButton);
                        if(view.item.dragging||(Opal.Hub.prefs.taskbarOrder||[]).indexOf("Fixture-0")<1)console.error("ASSERTION_FAILED: taskbar drop order");
                        if(Opal.Hub.pendingFocus!==null)console.error("ASSERTION_FAILED: taskbar drag activated window");
                    }
                    fixture.step++;Qt.callLater(fixture.next);
                });
            }
        }
        // OPAL_ONLY=name keeps only the scenes whose name contains it.
        Component.onCompleted:{const only=Quickshell.env("OPAL_ONLY");if(only)cases=cases.filter(c=>c.name.indexOf(only)>=0);Qt.callLater(next);}
    }
}
