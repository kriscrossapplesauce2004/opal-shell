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
            {name:"settings-network",ui:"settings",w:980,h:800,section:"network"},
            {name:"settings-sound",ui:"settings",w:980,h:800,section:"sound",music:true},
            {name:"settings-about",ui:"settings",w:980,h:800,section:"about",light:true},
            {name:"settings-power-wide",ui:"settings",w:980,h:800,section:"power"},
            {name:"settings-power",ui:"settings",w:360,h:740,section:"power"},
            {name:"compact-control-panel",ui:"shade",w:420,h:520},
            {name:"compact-control-panel-light",ui:"shade",w:420,h:520,light:true},
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
            {name:"dock-welcome",ui:"dock",w:580,h:290},
            {name:"dock-welcome-phone",ui:"dock",w:366,h:374,phone:true},
            {name:"dock-welcome-phone-light",ui:"dock",w:336,h:374,phone:true,light:true},
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
            {name:"handheld",ui:"console",w:960,h:600},
            {name:"clipboard-empty",ui:"clipboard",w:470,h:650,empty:true},
            {name:"clipboard-text",ui:"clipboard",w:470,h:650},
            {name:"clipboard-phone",ui:"clipboard",w:390,h:844,phone:true},
            {name:"clipboard-widget",ui:"dashboard",w:840,h:700},
            {name:"taskbar-drag",ui:"taskbar",w:700,h:64,drag:true},
            {name:"start-home",ui:"start",w:1280,h:800},
            {name:"start-home-light",ui:"start",w:1280,h:800,light:true},
            {name:"start-search",ui:"start",w:1280,h:800,searchText:"firefx"},
            {name:"start-windows",ui:"start",w:1280,h:800,searchText:"@ Project"},
            {name:"start-actions",ui:"start",w:1280,h:800,searchText:">"},
            {name:"start-empty",ui:"start",w:1280,h:800,searchText:"zzzzzzzz"},
            {name:"start-calculator",ui:"start",w:1280,h:800,searchText:"= 12 * (3 + 4)"},
            {name:"start-small",ui:"start",w:640,h:560,allApps:true},
            {name:"tile-editor",ui:"tiles",w:360,h:900}
        ]
        Rectangle {anchors.fill:parent;color:Opal.Theme.base}
        Loader {id:view;anchors.fill:parent}
        TestCase {id:input;name:"TaskbarDrag";when:false}
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
        Component {id:dockView;Opal.DockWelcome {displayName:"USB-C · External monitor"}}
        Component {id:glassView;Item {Opal.Wallpaper {anchors.fill:parent;showWidgets:false} Opal.Surface {anchors.fill:parent;anchors.margins:24;translucency:.55;Opal.Convergence {anchors.fill:parent}}}}
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
        Component {id:phoneBars;Item {
            property alias navigation:phoneNav
            Opal.PhoneStatus {anchors.top:parent.top;width:parent.width;height:48}
            Opal.MobileHome {anchors.fill:parent;anchors.topMargin:48;anchors.bottomMargin:phoneNav.height}
            Opal.PhoneNavigation {id:phoneNav;anchors.bottom:parent.bottom;width:parent.width;height:implicitHeight}
        }}
        Component {id:gaming;Opal.ConsoleHome {}}
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
        Component {id:polkitView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Rectangle {anchors.fill:parent;color:"#66000000"}
            Opal.PolkitCard {anchors.centerIn:parent;message:"Authentication is required to install software.";identity:"unix-user:melissa"}
        }}
        Component {id:barsView;Item {
            Opal.Wallpaper {anchors.fill:parent;imagePath:"file://"+Quickshell.env("HOME")+"/Ocean.png";dim:0;showWidgets:false}
            Opal.WorkspacePill {visible:!!fixture.cases[fixture.step].pill;anchors.horizontalCenter:parent.horizontalCenter;y:10;shown:2}
            Opal.DesktopShelf {visible:Opal.Hub.prefs.barStyle==="split"&&!fixture.cases[fixture.step].pill;part:"top";anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;height:56}
            Opal.DesktopShelf {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:Opal.Hub.prefs.barStyle==="edge" ? 52 : 64;flashWorkspace:fixture.cases[fixture.step].flash ? 3 : 0}
        }}
        Component {id:workspaceView;Item {
            property alias shelf:workspaceShelf
            Opal.Wallpaper {anchors.fill:parent}
            Opal.DesktopShelf {id:workspaceShelf;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:64}
        }}
        function scrollEnd(item) {
            if(item.contentHeight!==undefined&&item.contentHeight>item.height)item.contentY=item.contentHeight-item.height;
            for(let child of item.children||[])scrollEnd(child);
        }
        function next() {
            if(step>=cases.length) {console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const test=cases[step];
            view.sourceComponent=null;
            width=test.w;height=test.h;musicVolume=40;
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{mode:test.ui==="convergence"||test.ui==="glass"||test.ui==="dock" ? "auto" : test.ui,light:!!test.light,phoneButtons:!!test.buttons,controllerLayout:test.nintendo ? "nintendo" : "standard"});
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
            }
            view.sourceComponent=test.ui==="start" ? startView : test.ui==="osd" ? osdView : test.ui==="phonebars" ? phoneBars : test.ui==="shapes" ? shapeView : test.ui==="audio" ? audioView : test.ui==="taskbar" ? taskbarView : test.ui==="switcher" ? switcherView : test.ui==="wallpaper" ? wallpaperStudio : test.ui==="dock" ? dockView : test.ui==="glass" ? glassView : test.ui==="convergence" ? convergenceView : test.ui==="keyboard" ? keyboardView : test.ui==="desktop" ? desktop : test.ui==="phone" ? phone : test.ui==="clipboard" ? clipboardView : test.ui==="dashboard" ? dashboardView : test.ui==="workspace" ? workspaceView : test.ui==="bars" ? barsView : test.ui==="lock" ? lockView : test.ui==="polkit" ? polkitView : test.ui==="reference" ? referenceView : test.ui==="search" ? searchView : test.ui==="menus" ? menusView : test.ui==="shade" ? shadeView : test.ui==="appearance" ? appearanceView : gaming;
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
                if(Opal.Hub.mobileTab!=="recent")console.error("ASSERTION_FAILED: phone recents");
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
            if(test.ui==="dock")view.item.phone=!!test.phone;
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
            if(test.ui==="console"&&!test.search&&!test.menu) {
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
        Component.onCompleted:Qt.callLater(next)
    }
}
