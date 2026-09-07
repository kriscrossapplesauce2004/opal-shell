import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtTest
import Quickshell
import "." as Opal

// Isolated renderer. The runner removes DISPLAY/WAYLAND_DISPLAY and supplies
// an offscreen platform, disposable HOME, and a nonexistent session bus.
ShellRoot {
    Window {
        id:fixture
        width:960;height:650;visible:true;color:Opal.Theme.base
        property int step:0
        property var cases:[
            {name:"context-pointer-dark",ui:"context",w:640,h:400},
            {name:"context-pointer-light",ui:"context",w:640,h:400,light:true},
            {name:"controls-alignment-dark",ui:"primitives",w:400,h:280},
            {name:"controls-alignment-light",ui:"primitives",w:400,h:280,light:true},
            {name:"wallpaper-studio",ui:"wallpaper",w:1060,h:760},
            {name:"wallpaper-browser",ui:"wallpaper",w:1060,h:760,browse:true},
            {name:"wallpaper-browser-phone",ui:"wallpaper",w:360,h:740,browse:true},
            {name:"wallpaper-studio-light",ui:"wallpaper",w:800,h:860,light:true},
            {name:"wallpaper-studio-images",ui:"wallpaper",w:800,h:860,photo:true},
            {name:"wallpaper-studio-phone",ui:"wallpaper",w:360,h:740},
            {name:"touch-apps-monitor",ui:"phone",w:1920,h:1080,drawer:true},
            {name:"dock-welcome",ui:"dock",w:580,h:244},
            {name:"glass",ui:"glass",w:960,h:740},
            {name:"convergence-dark",ui:"convergence",w:800,h:820},
            {name:"convergence-light",ui:"convergence",w:800,h:820,light:true},
            {name:"convergence-phone",ui:"convergence",w:360,h:740},
            {name:"tablet-home",ui:"phone",w:1000,h:740},
            {name:"desktop",ui:"desktop",w:960,h:650},
            {name:"desktop-light",ui:"desktop",w:960,h:740,light:true},
            {name:"wifi-phone",ui:"shade",w:360,h:640,detail:"wifi"},
            {name:"bluetooth-light",ui:"shade",w:490,h:740,detail:"bluetooth",light:true},
            {name:"workspace-dark",ui:"workspace",w:1440,h:900},
            {name:"workspace-light",ui:"workspace",w:1440,h:900,light:true},
            {name:"shade-dark",ui:"shade",w:490,h:860},
            {name:"shade-light",ui:"shade",w:490,h:860,light:true},
            {name:"shade-phone",ui:"shade",w:360,h:640},
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
            {name:"phone-landscape",ui:"phone",w:800,h:480},
            {name:"console",ui:"console",w:1280,h:800},
            {name:"console-search",ui:"console",w:1280,h:800,search:true},
            {name:"console-actions",ui:"console",w:1280,h:800,menu:true},
            {name:"handheld",ui:"console",w:960,h:600},
            {name:"clipboard-empty",ui:"clipboard",w:470,h:650,empty:true},
            {name:"clipboard-text",ui:"clipboard",w:470,h:650},
            {name:"clipboard-phone",ui:"clipboard",w:390,h:844,phone:true},
            {name:"clipboard-widget",ui:"dashboard",w:840,h:700},
            {name:"taskbar-drag",ui:"taskbar",w:700,h:64,drag:true}
        ]
        Rectangle {anchors.fill:parent;color:Opal.Theme.base}
        Loader {id:view;anchors.fill:parent}
        TestCase {id:input;name:"TaskbarDrag";when:false}
        Component {id:contextView;Item {
            property alias menu:positionedMenu
            property alias target:menuTarget
            Rectangle {x:48;y:36;width:544;height:48;radius:16;color:Opal.Theme.surface
                Item {id:menuTarget;x:140;y:8;width:200;height:32
                    Opal.MText {anchors.centerIn:parent;text:"Right-click anywhere"}
                }
            }
            Opal.OpalMenu {id:positionedMenu;entries:[
                {text:"Applications",icon:"apps",run:()=>{}},
                {text:"Personalize desktop",icon:"palette",run:()=>{}},
                {text:"Taskbar options",icon:"settings",run:()=>{}}
            ]}
        }}
        Component {id:primitivesView;Item {
            property alias slider:wheelSlider
            Column {anchors.centerIn:parent;spacing:12;width:360
                Row {spacing:12
                    Opal.MButton {width:30;height:30;icon:"volume";compact:true}
                    Opal.MButton {width:150;text:"Centered";icon:"check";filled:true}
                    Opal.MButton {width:150;text:"Inactive";tonal:true}
                }
                Opal.ExpressiveSlider {width:360;value:0}
                Opal.ExpressiveSlider {id:wheelSlider;width:360;value:50}
                Opal.ExpressiveSlider {width:360;value:100}
            }
        }}
        Component {id:taskbarView;Opal.TaskStrip {labels:false}}
        Component {id:switcherView;Opal.WindowSwitcher {}}
        Component {id:wallpaperStudio;Opal.WallpaperPicker {}}
        Component {id:dockView;Opal.DockWelcome {displayName:"USB-C · External monitor"}}
        Component {id:glassView;Item {Opal.Wallpaper {anchors.fill:parent;showWidgets:false} Opal.Surface {anchors.fill:parent;anchors.margins:24;translucency:.55;Opal.Convergence {anchors.fill:parent}}}}
        Component {id:convergenceView;Opal.Convergence {}}
        Component {id:desktop;Opal.Launcher {}}
        Component {id:phone;Opal.MobileHome {}}
        Component {id:gaming;Opal.ConsoleHome {}}
        Component {id:clipboardView;Opal.ClipboardPanel {}}
        Component {id:dashboardView;Opal.Dashboard {}}
        Component {id:shadeView;Opal.QuickSettings {}}
        Component {id:appearanceView;Opal.Appearance {}}
        Component {id:workspaceView;Item {
            Opal.Wallpaper {anchors.fill:parent}
        }}
        function scrollEnd(item) {
            if(item.contentHeight!==undefined&&item.contentHeight>item.height)item.contentY=item.contentHeight-item.height;
            for(let child of item.children||[])scrollEnd(child);
        }
        function next() {
            if(step>=cases.length) {console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const test=cases[step];
            view.sourceComponent=null;
            width=test.w;height=test.h;
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{mode:test.ui==="convergence"||test.ui==="glass"||test.ui==="dock" ? "auto" : test.ui,light:!!test.light});
            Opal.Hub.mobileTab=test.recent ? "recent" : test.apps||test.drawer ? "apps" : "home";
            if(test.recent)Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,windows:[{title:"Project notes",className:"org.kde.kate",workspace:1,address:"fixture-1"},{title:"A good playlist",className:"firefox",workspace:2,address:"fixture-2"}]});
            else Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:false});
            Opal.Hub.controlDetail=test.detail||"";
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
                Opal.Hub.status=Object.assign({},Opal.Hub.status,{hypr:true,windows:[0,1,2,3].map(i=>({className:"Fixture-"+i,title:"Fixture "+i,address:"fixture-"+i,workspace:1}))});
            }
            view.sourceComponent=test.ui==="context" ? contextView : test.ui==="primitives" ? primitivesView : test.ui==="taskbar" ? taskbarView : test.ui==="switcher" ? switcherView : test.ui==="wallpaper" ? wallpaperStudio : test.ui==="dock" ? dockView : test.ui==="glass" ? glassView : test.ui==="convergence" ? convergenceView : test.ui==="desktop" ? desktop : test.ui==="phone" ? phone : test.ui==="clipboard" ? clipboardView : test.ui==="dashboard" ? dashboardView : test.ui==="workspace" ? workspaceView : test.ui==="shade" ? shadeView : test.ui==="appearance" ? appearanceView : gaming;
            if(test.ui==="context")Qt.callLater(()=>{
                view.item.menu.openAt(view.item.target,37,11);
                Qt.callLater(()=>{
                    const menu=view.item.menu;
                    if(menu.anchor.item!==view.item.target||menu.anchor.rect.x!==37||menu.anchor.rect.y!==11||!menu.popupWindow.grabFocus)
                        console.error("ASSERTION_FAILED: native context popup lost pointer anchor or grab");
                });
            });
            if(test.ui==="primitives")Qt.callLater(()=>{
                const slider=view.item.slider;
                input.mouseWheel(slider,slider.width/2,slider.height/2,0,120);
                if(slider.value<=50)console.error("ASSERTION_FAILED: slider wheel did not increase volume");
                input.mouseWheel(slider,slider.width/2,slider.height/2,0,-120);
                if(slider.value!==50)console.error("ASSERTION_FAILED: slider wheel did not reverse");
            });
            if(test.ui==="switcher") {
                view.item.layoutMode=test.game ? "console" : "desktop";
                view.item.navigate("right");
                if(view.item.selection!==1)console.error("ASSERTION_FAILED: switcher navigation");
                view.item.query="Project";
                if(view.item.windows.length!==1)console.error("ASSERTION_FAILED: switcher filtering");
                view.item.query="";
            }
            if(test.ui==="wallpaper") {
                const original=JSON.stringify(Opal.Hub.prefs);
                view.item.draftArt=2;view.item.draftPath="";
                if(test.browse){view.item.folder="file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers";view.item.browsing="folder";}
                if(test.photo){view.item.draftPath="file://"+Quickshell.env("HOME")+"/Pictures/Wallpapers/Fixture-1.png";view.item.tab="images";Opal.Hub.browseWallpapers(Quickshell.env("HOME")+"/Pictures/Wallpapers");}
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
            if(test.menu)view.item.navigate("menu");
            if(test.ui==="console"&&!test.search&&!test.menu) {
                view.item.navigate("right");
                if(view.item.library.length>1&&view.item.selection!==1)console.error("ASSERTION_FAILED: controller grid");
                view.item.navigate("left");
            }
            if(test.drag)Qt.callLater(()=>{
                input.mousePress(view.item,22,32,Qt.LeftButton);
                input.mouseMove(view.item,58,32,40);
                input.mouseMove(view.item,130,32,40);
                if(!view.item.dragging)console.error("ASSERTION_FAILED: taskbar mouse drag did not begin");
            });
            if(test.ui==="primitives"&&String(Opal.Theme.primaryText)!==(test.light ? "#ffffff" : "#31205f"))
                console.error("ASSERTION_FAILED: accent foreground contrast",Opal.Theme.primaryText);
            console.log("THEME",test.name,Opal.Theme.primary,Opal.Theme.primaryText);
            capture.restart();
        }
        Timer {
            id:capture;interval:600
            onTriggered:{
                const captureItem=fixture.cases[fixture.step].ui==="context" ? view.item.menu.popupWindow.contentItem : fixture.contentItem;
                captureItem.grabToImage(result=>{
                    result.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");
                    console.log("RENDERED",fixture.cases[fixture.step].name,view.item.width,view.item.height);
                    if(fixture.cases[fixture.step].ui==="context")view.item.menu.close();
                    if(fixture.cases[fixture.step].browse){
                        const picker=view.item;
                        const before=JSON.stringify(Opal.Hub.prefs);
                        const folder=picker.browser.currentFolder.toString();
                        if(!folder.endsWith("/Pictures/Wallpapers")||picker.browser.folderPath==="")console.error("ASSERTION_FAILED: embedded browser location");
                        input.mouseClick(picker.browser.folderButton);
                        if(picker.browsing!==""||picker.folder!==folder||JSON.stringify(Opal.Hub.prefs)!==before)console.error("ASSERTION_FAILED: folder choice did not return safely to gallery");
                    }
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
