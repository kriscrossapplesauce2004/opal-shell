import QtQuick
import QtQuick.Window
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
            {name:"wallpaper-studio",ui:"wallpaper",w:800,h:860},
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
            {name:"clipboard-widget",ui:"dashboard",w:840,h:700}
        ]
        Rectangle {anchors.fill:parent;color:Opal.Theme.base}
        Loader {id:view;anchors.fill:parent}
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
            view.sourceComponent=test.ui==="switcher" ? switcherView : test.ui==="wallpaper" ? wallpaperStudio : test.ui==="dock" ? dockView : test.ui==="glass" ? glassView : test.ui==="convergence" ? convergenceView : test.ui==="desktop" ? desktop : test.ui==="phone" ? phone : test.ui==="clipboard" ? clipboardView : test.ui==="dashboard" ? dashboardView : test.ui==="workspace" ? workspaceView : test.ui==="shade" ? shadeView : test.ui==="appearance" ? appearanceView : gaming;
            if(test.ui==="switcher") {
                const focus=Opal.Hub.focusArgs({address:"0xabc123",workspace:7});
                if(focus[2]!=="dispatch workspace 7; dispatch focuswindow address:0xabc123")console.error("ASSERTION_FAILED: workspace-before-focus");
                if(Opal.Hub.focusArgs({address:"0x123; exit",workspace:7}).length)console.error("ASSERTION_FAILED: invalid focus address");
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
            console.log("THEME",test.name,Opal.Theme.primary,Opal.Theme.onPrimary);
            capture.restart();
        }
        Timer {
            id:capture;interval:600
            onTriggered:{
                fixture.contentItem.grabToImage(result=>{
                    result.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");
                    console.log("RENDERED",fixture.cases[fixture.step].name,view.item.width,view.item.height);
                    fixture.step++;Qt.callLater(fixture.next);
                });
            }
        }
        Component.onCompleted:Qt.callLater(next)
    }
}
