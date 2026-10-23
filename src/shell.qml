import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property bool fpsEnabled:Quickshell.env("DET_OPAL_FPS")==="1"
    property int fpsFrames:0
    property int fps:0
    function show(page) {Hub.targetScreen=Hub.chooseScreen();Hub.toggle(page);}
    FrameAnimation {running:root.fpsEnabled;onTriggered:root.fpsFrames++}
    Timer {interval:500;repeat:true;running:root.fpsEnabled;onTriggered:{root.fps=Math.round(root.fpsFrames*2);root.fpsFrames=0;}}
    IpcHandler {
        target:"opal"
        function launcher():void {Hub.launcherSection="apps";root.show("launcher");}
        function clipboard():void {Hub.targetScreen=Hub.chooseScreen();Hub.toggleClipboard();}
        function controls():void {root.show("controls");}
        function audio():void {Hub.toggleAudio(Hub.chooseScreen());}
        function notifications():void {root.show("notifications");}
        function phone():void {Hub.targetScreen=Hub.chooseScreen();Hub.mode("phone");}
        function gaming():void {Hub.mode("console");}
        function desktop():void {Hub.mode("desktop");}
        function adaptive():void {Hub.mode("auto");}
        function appearance():void {root.show("appearance");}
        // Omarchy-format themes: wear one by folder name, or save the current look as an Omarchy theme.
        function theme(name:string):void {Hub.command({action:"omarchy-apply",id:name});}
        // The portal asks whether Opal draws an app's file dialog; "shown" means yes.
        function portalPick(encoded:string):string {return Hub.portalPick(Qt.atob(encoded));}
        function portalCancel(token:string):void {Hub.portalCancel(token);}
        function themeExport(name:string):void {Hub.command({action:"omarchy-export",name:name||"opal",light:Theme.light,roles:Theme.roles()});}
        function settings():void {Hub.targetScreen=Hub.chooseScreen();Hub.openSettings();}
        function convergence():void {root.show("convergence");}
        function assistant():void {if(Hub.page==="assistant")Hub.close();else Hub.openAssistant("");}
        function ask(text:string):void {Hub.openAssistant(text);}
        function close():void {Hub.close();}
        function quickaccess():void {GameState.toggleQuickAccess();}
        function lock():void {Hub.lock();}
        // Power key menu: the Super chord on a desktop opens it on the focused screen; the hardware key goes through the backend first.
        function powerMenu():void {PowerKey.toggle("shortcut",Hub.chooseScreen());}
        function powerKey(edge:string):void {Hub.command({action:"powerkey-edge",down:edge==="down"});}
        function powerChord():void {Hub.command({action:"powerkey-chord"});}
        function powerMenuClose():void {PowerKey.close();}
        // Used by the Opal MCP server. The backend validates every preference.
        function setPreference(key:string, value:string):string {let parsed;try{parsed=JSON.parse(value);}catch(error){return "Value must be JSON";}Hub.set(key,parsed);return "Sent "+key;}
        // The quickshell CLI splits arguments at commas, so arrays and objects come base64-encoded.
        function setPreferenceEncoded(key:string, value:string):string {let parsed;try{parsed=JSON.parse(Qt.atob(value));}catch(error){return "Value must be base64 JSON";}Hub.set(key,parsed);return "Sent "+key;}
        function preferences():string {return JSON.stringify(Hub.prefs);}
        // Read-only clipboard history for Borealis. Text only (no images), bounded, newest first.
        function clipboardHistory():string {return JSON.stringify(Hub.clipboardItems.filter(e=>e.kind!=="Image").slice(0,20).map(e=>({id:String(e.id||""),text:String(e.text||"").slice(0,4100),kind:String(e.kind||"Text")})));}
        function listNotifications():string {return JSON.stringify(Notifier.inbox.map(e=>({app:e.notification.appName||"",summary:e.notification.summary||"",body:(e.notification.body||"").slice(0,300),read:e.read,received:new Date(e.received).toISOString()})));}
        function media(action:string):string {if(["play-pause","next","previous"].indexOf(action)<0)return "Unknown action";Hub.media(action);return "ok";}
        function volume(value:int):string {Hub.volume(value);return "Volume "+Math.max(0,Math.min(100,value));}
        function toast(text:string):void {Hub.message(text);}
        // Floating mode: minimize the focused window, open the snap layouts, and snap to halves or the whole screen.
        function minimize():void {Hub.command({action:"window-minimize",address:Hub.status.activeAddress||""});}
        function snaplayouts():void {snapLayouts.show();}
        function snapLeft():void {Hub.command({action:"window-snap",cell:[0,0,.5,1],address:Hub.status.activeAddress||""});}
        function snapRight():void {Hub.command({action:"window-snap",cell:[.5,0,.5,1],address:Hub.status.activeAddress||""});}
        function snapMaximize():void {Hub.command({action:"window-snap",cell:[0,0,1,1],address:Hub.status.activeAddress||""});}
        // Maximize or restore; Super+Alt+arrows cycle snaps; Super+D shows the desktop.
        function maximize():void {Hub.command({action:"window-maximize",address:Hub.status.activeAddress||""});}
        function keySnap(direction:string):void {Hub.command({action:"window-key-snap",direction:direction,address:Hub.status.activeAddress||""});}
        function showDesktop():void {Hub.command({action:"show-desktop"});}
        // App switcher calls from the Alt+Tab binds in hyprland.lua, and Super+Tab.
        function switcherStep(hold:int, step:int):void {Hub.switcherStep(hold,step);}
        function switcherCommit(hold:int, step:int):void {Hub.switcherCommit(hold,step);}
        function switcherCancel(hold:int, step:int):void {Hub.switcherCancel(hold);}
        function switcherCloseWindow(hold:int, step:int):void {if(hold===Hub.switcherHold)Hub.switcherCloseSelected();}
        function switcherOpen():void {
            if(Hub.switcherOpen){Hub.switcherEnd();return;}
            const sc=Hub.chooseScreen(),layout=sc ? Hub.layoutFor(sc.width,sc.height,sc.name) : "desktop";
            if(layout==="desktop")Hub.openSwitcher();
            else {Hub.targetScreen=sc;Hub.openSection("windows");}
        }
        function windows():string {return JSON.stringify(Hub.windows.map(w=>({title:w.title||"",app:w.className||"",workspace:w.workspace||0})));}
        function navigate(key:string):void {Hub.navigate(key);}
        function search(text:string):void {Hub.targetScreen=Hub.chooseScreen();Hub.openSection("apps");Hub.query=text;if(text.startsWith("="))Hub.command({action:"calculate",text:text.slice(1).trim()});}
        function inspect():string {return JSON.stringify({page:Hub.page,mode:Hub.prefs.mode,apps:Hub.apps.length,query:Hub.query,controller:Hub.controller,notifications:Hub.unread,gameSession:Hub.gameSession,status:Hub.status});}
    }
    Variants {
        model:Quickshell.screens
        delegate:Scope {
            id:output
            required property var modelData
            readonly property string layoutMode:Hub.layoutFor(modelData.width,modelData.height,modelData.name)
            function show(page) {Hub.targetScreen=modelData;Hub.toggle(page);}
            // A window on this screen's workspace: with the option on, the home's icons and widgets fade out under it.
            readonly property int shownWorkspace:Number(((Hub.status.monitors||[]).find(m=>m.name===modelData.name)||{}).workspace||Hub.status.workspace)
            readonly property bool covered:Hub.prefs.homeHideUnderApps!==false&&Hub.windows.some(w=>(!w.monitor||w.monitor===modelData.name)&&Number(w.workspace)===shownWorkspace)
            // A tablet keeps its home under the launcher sheet; other pages cover it.
            readonly property bool homeShown:Hub.page===""||Hub.page==="launcher"&&Hub.mobileTab!=="recent"&&PhoneState.isTablet(modelData)
            PanelWindow {
                id:desktop
                screen:output.modelData
                anchors {top:true;bottom:true;left:true;right:true}
                exclusionMode:ExclusionMode.Ignore
                WlrLayershell.layer:WlrLayer.Background
                WlrLayershell.namespace:"opal-wallpaper"
                // The console home takes keys only while it is the thing on screen, and only when clicked or focused there.
                WlrLayershell.keyboardFocus:Hub.prefs.mode==="console"&&output.homeShown&&Compositor.homeShown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                color:Theme.base
                IdleInhibitor {window:desktop;enabled:Hub.keepAwake||Hub.gameSession}
                // The morph swaps the layout between two short phases; reduced motion swaps at once.
                LayoutMorph {
                    id:morph;anchors.fill:parent;layout:output.layoutMode
                    Loader {
                        anchors.fill:parent
                        sourceComponent:morph.shown==="phone" ? phoneBackdrop : desktopBackdrop
                    }
                    Component {id:phoneBackdrop;PhoneBackdrop {soft:output.homeShown ? 0 : 1}}
                    Component {id:desktopBackdrop;Wallpaper {showWidgets:morph.shown==="desktop"&&Hub.prefs.desktopWidgets!==false;showHome:morph.shown==="desktop";covered:output.covered;screenName:output.modelData.name}}
                    // Non-exclusive homes live behind applications. Only the explicit overlay takes keys.
                    Loader {
                        anchors {fill:parent;topMargin:Hub.prefs.mode==="console" ? 0 : morph.shown==="phone" ? PhoneState.statusFor(output.modelData) : 56;bottomMargin:Hub.prefs.mode==="console" ? 0 : morph.shown==="phone" ? PhoneState.navFor(output.modelData) : 84}
                        active:morph.shown!=="desktop"&&output.homeShown
                        // The home recedes under the tablet launcher, and comes back while an app is carried onto it.
                        opacity:output.covered&&!PhoneState.homeDrag ? 0 : Hub.page===""||PhoneState.homeDrag ? 1 : .45
                        Behavior on opacity {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
                        sourceComponent:morph.shown==="phone" ? phoneHome : gameHome
                    }
                    Component {id:phoneHome;MobileHome {embedded:true}}
                    Component {id:gameHome;ConsoleHome {embedded:true}}
                }
                OpalMenu {id:desktopMenu;inWindow:true;title:"Desktop";icon:"desktop_windows";entries:[
                    {text:"New folder",icon:"create_new_folder",quick:true,run:()=>Hub.command({action:"desktop-new-folder"})},
                    {text:"New file",icon:"note_add",quick:true,run:()=>Hub.command({action:"desktop-new-file"})},
                    {text:"Terminal",icon:"terminal",quick:true,run:()=>Hub.command({action:"desktop-terminal"})},
                    {text:"Wallpaper",icon:"wallpaper",quick:true,run:()=>output.show("wallpaper")},
                    {text:"Open Desktop in Files",icon:"folder_open",run:()=>Hub.command({action:"desktop-open-folder"})},
                    {text:"Sort by "+({name:"name",type:"type",date:"date"})[Hub.prefs.desktopSort||"name"],detail:"Click to sort by "+({name:"type",type:"date",date:"name"})[Hub.prefs.desktopSort||"name"],icon:"sort",
                        run:()=>{Hub.set("desktopSort",({name:"type",type:"date",date:"name"})[Hub.prefs.desktopSort||"name"]);Hub.set("desktopSlots",{});}},
                    {text:"Clean up icons",detail:"Put every icon back in order",icon:"grid_view",run:()=>Hub.set("desktopSlots",{})},
                    {text:"Edit widgets",icon:"edit",run:()=>{Hub.set("desktopWidgets",true);HomeData.editingScreen=output.modelData.name;}},
                    {text:"Desktop icons",icon:"apps",checked:Hub.prefs.desktopIcons!==false,run:()=>Hub.set("desktopIcons",Hub.prefs.desktopIcons===false)},
                    {text:"Desktop widgets",icon:"widgets",checked:Hub.prefs.desktopWidgets!==false,run:()=>Hub.set("desktopWidgets",Hub.prefs.desktopWidgets===false)},
                    {text:"Hide under windows",icon:"layers_clear",checked:Hub.prefs.homeHideUnderApps!==false,run:()=>Hub.set("homeHideUnderApps",Hub.prefs.homeHideUnderApps===false)},
                    {text:"Dark theme",icon:"dark_mode",checked:!Theme.light,run:()=>Hub.set("light",!Theme.light)},
                    {text:"Display settings",icon:"monitor",run:()=>{Hub.targetScreen=output.modelData;Hub.openSettings("displays");}},
                    {text:"Settings",icon:"settings",run:()=>{Hub.targetScreen=output.modelData;Hub.openSettings();}}
                ]}
                // Below the home, so desktop icons and widgets get their own right clicks first.
                MouseArea {anchors.fill:parent;z:-1;enabled:morph.shown==="desktop";acceptedButtons:Qt.RightButton;onClicked:e=>{Hub.targetScreen=output.modelData;desktopMenu.popup(e.x,e.y);}}
            }
            PanelWindow {
                id:statusbar
                screen:output.modelData
                visible:output.layoutMode==="phone"&&(Hub.status.fullscreenMonitors||[]).indexOf(output.modelData.name)<0
                anchors {top:true;left:true;right:true}
                implicitHeight:output.layoutMode==="phone" ? PhoneState.statusFor(output.modelData) : 44
                exclusiveZone:visible ? implicitHeight : 0
                // Keep bar hover effects above transient utility surfaces.
                WlrLayershell.layer:WlrLayer.Overlay
                WlrLayershell.namespace:"opal-bar"
                // On the home the status bar sits on the wallpaper. With an app in front on a phone it turns solid, like Android, so no strip of wallpaper frames the app.
                color:output.layoutMode==="phone"&&!PhoneState.isTablet(output.modelData)&&PhoneState.appInFront&&Hub.page==="" ? Theme.base : "transparent"
                Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durShort)}}
                Loader {anchors.fill:parent;active:statusbar.visible;sourceComponent:phoneStatusContent}
                Component {id:phoneStatusContent;PhoneStatus {anchors.fill:parent;output:statusbar.screen;fpsEnabled:root.fpsEnabled;fps:root.fps}}
            }
            Loader {active:output.layoutMode!=="console";sourceComponent:Component {Taskbar {target:output.modelData}}}
            Loader {active:output.layoutMode==="desktop"&&Hub.prefs.barStyle==="split";sourceComponent:Component {TopBar {screen:output.modelData}}}
            PanelWindow {
                screen:output.modelData
                visible:Hub.toast!==""&&Hub.page===""&&!Hub.audioOpen
                anchors {bottom:true;right:true}
                margins {bottom:90;right:12}
                implicitWidth:Math.min(390,output.modelData.width-24);implicitHeight:100
                exclusionMode:ExclusionMode.Ignore
                WlrLayershell.namespace:"opal-toast"
                color:"transparent"
                Surface {
                    anchors.fill:parent;radius:30
                    RowLayout {anchors {fill:parent;margins:18} spacing:12
                        Glyph {name:"bell";color:Theme.primary}
                        MText {text:Hub.toast;Layout.fillWidth:true;font.pixelSize:13;maximumLineCount:4;wrapMode:Text.Wrap}
                    }
                    MouseArea {anchors.fill:parent;onClicked:{Hub.toast="";Hub.osd="";}}
                }
            }
        }
    }
    PanelWindow {
        id:volumeOsd
        screen:Hub.osdScreen||Hub.chooseScreen()
        // Desktop bars show volume feedback in the status pill instead.
        readonly property bool inBar:screen&&Hub.layoutFor(screen.width,screen.height,screen.name)==="desktop"&&(Hub.status.fullscreenMonitors||[]).indexOf(screen.name)<0
        visible:Hub.osd!==""&&Hub.page===""&&!Hub.audioOpen&&!inBar
        anchors {bottom:true}
        margins.bottom:100
        implicitWidth:Math.min(340,screen ? screen.width-24 : 340)
        implicitHeight:112
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-volume-osd"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        color:"transparent"
        Loader {anchors.fill:parent;active:Hub.osd!=="";sourceComponent:Component {VolumeOsd {}}}
    }
    // Apps' Open and Save dialogs, drawn by Opal. Full screen on phones and tablets, a large sheet on desktops.
    LazyLoader {
        active:Hub.portalRequest!==null
        PanelWindow {
            id:portalWindow
            screen:Hub.portalScreen||Hub.chooseScreen()
            readonly property bool touch:screen ? Hub.layoutFor(screen.width,screen.height,screen.name)!=="desktop" : true
            anchors {top:true;bottom:true;left:true;right:true}
            exclusionMode:ExclusionMode.Ignore
            WlrLayershell.layer:WlrLayer.Overlay
            WlrLayershell.namespace:"opal-portal"
            WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
            color:portalWindow.touch ? "transparent" : Theme.alpha("#000000",.42)
            MouseArea {anchors.fill:parent;onClicked:Hub.portalAnswer({cancel:true})}
            FilePicker {
                touch:portalWindow.touch
                width:touch ? parent.width : Math.min(parent.width-48,1040);height:touch ? parent.height : Math.min(parent.height-48,720)
                anchors.centerIn:parent
                MouseArea {anchors.fill:parent;z:-1}
            }
        }
    }
    // First start: a quiet card offers the tour. It never takes the keyboard.
    PanelWindow {
        id:tourPrompt
        property bool dismissed:false
        screen:Hub.chooseScreen()
        visible:Hub.preferencesLoaded&&Hub.prefs.onboarded!==true&&!dismissed&&Hub.page===""&&tourDelay.elapsed
        anchors {bottom:true;right:true}
        margins {bottom:90;right:18}
        implicitWidth:360;implicitHeight:tourCard.implicitHeight
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-toast"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        color:"transparent"
        Timer {id:tourDelay;property bool elapsed:false;interval:4000;running:Hub.preferencesLoaded;onTriggered:elapsed=true}
        Rectangle {
            id:tourCard;anchors.fill:parent;implicitHeight:tourColumn.implicitHeight+32;radius:Theme.shapeXl;color:Theme.primaryContainer
            ColumnLayout {id:tourColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:16;spacing:6
                RowLayout {spacing:10
                    Glyph {name:"auto_awesome";font.pixelSize:22;color:Theme.onContainer}
                    MText {text:"Opal has a new look";role:"titleS";color:Theme.onContainer}}
                MText {Layout.fillWidth:true;wrapMode:Text.Wrap;text:"Take a one-minute tour to pick your bar, icons and theme.";role:"bodyS";color:Theme.alpha(Theme.onContainer,.85)}
                RowLayout {Layout.fillWidth:true;Layout.topMargin:4
                    Item {Layout.fillWidth:true}
                    MButton {text:"Not now";compact:true;ink:Theme.onContainer;onClicked:{tourPrompt.dismissed=true;Hub.set("onboarded",true);}}
                    MButton {text:"Take the tour";compact:true;filled:true;onClicked:{tourPrompt.dismissed=true;Hub.targetScreen=tourPrompt.screen;Hub.page="welcome";}}
                }
            }
        }
    }
    // Opal Link pairing request. It never takes the keyboard.
    PanelWindow {
        screen:Hub.chooseScreen()
        visible:Hub.linkPairRequest!==null
        anchors {bottom:true;right:true}
        margins {bottom:90;right:18}
        implicitWidth:360;implicitHeight:pairCard.implicitHeight
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-toast"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        color:"transparent"
        Rectangle {
            id:pairCard;anchors.fill:parent;implicitHeight:pairColumn.implicitHeight+32;radius:Theme.shapeXl;color:Theme.level(3)
            ColumnLayout {id:pairColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:16;spacing:6
                RowLayout {spacing:10
                    Glyph {name:"devices";font.pixelSize:22;color:Theme.primary}
                    MText {text:"Pair with "+(Hub.linkPairRequest ? Hub.linkPairRequest.name : "")+"?";role:"titleS";Layout.fillWidth:true}}
                MText {Layout.fillWidth:true;wrapMode:Text.Wrap;text:"Check that both screens show "+(Hub.linkPairRequest ? Hub.linkPairRequest.code : "")+".";role:"bodyS";color:Theme.subtext}
                RowLayout {Layout.fillWidth:true;Layout.topMargin:4
                    Item {Layout.fillWidth:true}
                    MButton {text:"Reject";compact:true;onClicked:{Hub.link("reject",Hub.linkPairRequest.id);Hub.linkPairRequest=null;}}
                    MButton {text:"Pair";compact:true;filled:true;onClicked:{Hub.link("accept",Hub.linkPairRequest.id);Hub.linkPairRequest=null;}}
                }
            }
        }
    }
    // App switcher strip on the focused screen. Alt+Tab drives it through a compositor submap, so only Super+Tab takes the keyboard.
    PanelWindow {
        id:switcherWindow
        screen:Hub.switcherScreen||Hub.chooseScreen()
        visible:Hub.switcherShown
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-switcher"
        WlrLayershell.keyboardFocus:Hub.switcherSticky ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color:"transparent"
        Loader {anchors.fill:parent;active:Hub.switcherShown;sourceComponent:Component {AppSwitcher {}}}
    }
    // A switcher submap left on without the strip, for example after a lost key release, is cleared.
    Timer {interval:1500;running:Hub.status.submap==="opal-switch"&&!Hub.switcherOpen;onTriggered:if(Hub.status.submap==="opal-switch"&&!Hub.switcherOpen)Hub.command({action:"submap-reset"})}
    WorkspaceOsd {}
    // Quick Access floats above games. Only a keyboard or IPC open takes keyboard focus.
    PanelWindow {
        screen:Hub.targetScreen||Quickshell.screens[0]
        visible:GameState.quickAccess||quickAccess.reveal>.001
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-quick-access"
        WlrLayershell.keyboardFocus:GameState.quickAccess&&GameState.keyboardOpened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color:"transparent"
        QuickAccess {id:quickAccess;anchors.fill:parent}
    }
    LockScreen {}
    PolkitDialog {}
    SystemServices {}
    AudioDrawer {}
    ActivityCardWindow {}
    WorkspaceCardWindow {}
    SnapLayouts {id:snapLayouts}
    SnapPreview {target:Hub.snapPreview}
    SnapAssist {id:snapAssist}
    DesktopSplitDivider {}
    TaskHoverCard {}
    CaptureOverlay {}
    CapturePreviewToast {}

    Connections {target:Hub;function onSnapAssistRequested(event) {snapAssist.show(event);}}
    ShadeWindow {}
    AssistantWindow {}
    PowerProfileWindow {}
    PowerMenuWindow {}
    TaskbarContextWindow {}
    DockWindow {}
    DockWelcomeWindow {}
    PhoneDock {}
    ConvergenceController {}
    PhoneGestureLayer {}
    PanelWindow {
        id:notificationPopups
        screen:Notifier.popupScreen || Quickshell.screens[0]
        readonly property bool phone:Hub.layoutFor(screen ? screen.width : 1920,screen ? screen.height : 1080,screen ? screen.name : "")==="phone"
        visible:Notifier.popups.length>0 && Hub.page===""&&!Hub.audioOpen
        anchors {top:notificationPopups.phone;bottom:!notificationPopups.phone;right:true}
        margins {top:notificationPopups.phone ? 64 : 0;bottom:notificationPopups.phone ? 0 : 76;right:18}
        implicitWidth:Math.min(360,screen ? screen.width-24 : 360)
        implicitHeight:Math.min(popupColumn.implicitHeight,screen ? screen.height-110 : 700)
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-toast"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        color:"transparent"
        Flickable {
            anchors.fill:parent;contentHeight:popupColumn.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
            Column {id:popupColumn;width:parent.width;spacing:8
                Repeater {model:Notifier.popups;NotificationCard {required property var modelData;entry:modelData;popup:true;width:popupColumn.width}}
            }
        }
    }
    // Utility pills also dismiss from outputs other than their own.
    Variants {
        model:Quickshell.screens
        delegate:PanelWindow {
            required property var modelData
            screen:modelData
            visible:overlay.wanted&&screen!==overlay.screen
            anchors {top:true;bottom:true;left:true;right:true}
            exclusionMode:ExclusionMode.Ignore
            WlrLayershell.layer:WlrLayer.Overlay
            WlrLayershell.namespace:"opal-shade-dismiss"
            WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
            color:"transparent"
            MouseArea {anchors.fill:parent;acceptedButtons:Qt.AllButtons;onPressed:Hub.close()}
        }
    }
    PanelWindow {
        id:overlay
        screen:Hub.targetScreen || Quickshell.screens[0]
        readonly property bool wanted:Hub.page!==""&&Hub.page!=="controls"&&Hub.page!=="notifications"&&Hub.page!=="assistant"
        // The last page stays latched while the panel plays its exit, so the content does not change during the animation.
        property string lastPage:""
        // Visibility follows the panel's arrival value, so the window never unmaps for a frame between close and the exit animation.
        readonly property bool leaving:!wanted&&panel.arrival>0
        readonly property string pg:wanted ? Hub.page : lastPage
        // Reads arrival directly: a binding through leaving can see a stale value for one tick and unmap the window.
        visible:wanted||panel.arrival>0
        onWantedChanged:{
            if(wanted){lastPage=Hub.page;panelDeparture.stop();panelArrival.restart();if(overlay.tabletLauncher&&tabletLayer.item)tabletLayer.item.prepare();}
            else {panelArrival.stop();panelDeparture.restart();}
        }
        Connections {target:Hub;function onPageChanged(){if(overlay.wanted)overlay.lastPage=Hub.page;}}
        readonly property string layoutMode:Hub.layoutFor(width,height,screen ? screen.name : "")
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        readonly property bool phoneLauncher:layoutMode==="phone"&&overlay.pg==="launcher"
        // Tablet: the launcher is one floating sheet above the dock, not a second home.
        readonly property bool tabletLauncher:phoneLauncher&&Hub.mobileTab!=="recent"&&PhoneState.isTablet(screen)
        readonly property bool desktopStart:layoutMode==="desktop"&&overlay.pg==="launcher"&&Hub.launcherSection==="apps"
        readonly property bool searchPanel:overlay.pg==="search"&&layoutMode!=="phone"
        WlrLayershell.namespace:"opal-overlay"
        WlrLayershell.keyboardFocus:visible&&!leaving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Transparent backdrop keeps the desktop sharp; only the panel blurs.
        // The scrim stays below the compositor blur threshold (alpha 0.1), so the screen behind a panel is never blurred.
        color:phoneLauncher||desktopStart||searchPanel ? "transparent" : Theme.alpha("#000000",.07*panel.arrival)
        mask:Region {
            // A leaving panel takes no input, so clicks reach what is under it.
            Region {x:0;y:0;width:overlay.leaving ? 0 : overlay.width;height:overlay.leaving ? 0 : overlay.height}
            Region {intersection:Intersection.Subtract;x:0;y:overlay.height-64;width:overlay.width;height:overlay.desktopStart||overlay.searchPanel ? 64 : 0}
        }
        MouseArea {anchors.fill:parent;acceptedButtons:Qt.AllButtons;onPressed:Hub.close()}
        Surface {
            id:panel
            property real arrival:0
            opacity:arrival
            // The tablet launcher has its own full-screen layer; this panel only carries the arrival value for it.
            visible:!overlay.tabletLauncher
            // Reveal from the bottom edge. Animate local content only: the
            // panel's final x/y geometry is never interpolated from (0, 0).
            transform: [
                Scale {origin.x:overlay.desktopStart||overlay.searchPanel ? 0 : panel.width/2;origin.y:panel.height;xScale:overlay.searchPanel ? .94+.06*panel.arrival : 1;yScale:panel.launcher||overlay.searchPanel ? .9+.1*panel.arrival : 1},
                Translate {y:(1-panel.arrival)*(panel.launcher||overlay.searchPanel ? 18 : 8)}
            ]
            // Arrival and departure start from the current value, so a reopen during an exit reverses smoothly.
            NumberAnimation {id:panelArrival;target:panel;property:"arrival";to:1;duration:Theme.motion(400);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}
            NumberAnimation {id:panelDeparture;target:panel;property:"arrival";to:0;duration:Theme.motion(220);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedAccelerate}
            readonly property bool phone:overlay.layoutMode==="phone"&&!overlay.tabletLauncher
            readonly property bool game:overlay.layoutMode==="console"
            readonly property bool launcher:overlay.pg==="launcher"
            readonly property bool full:phone||game&&(launcher||overlay.pg==="settings"||overlay.pg==="windows")
            width:full ? overlay.width : Math.min(overlay.width-36,overlay.searchPanel ? 640 : overlay.desktopStart ? 760 : overlay.pg==="settings" ? 1120 : launcher ? 960 : overlay.pg==="windows" ? 1100 : overlay.pg==="convergence"||overlay.pg==="wallpaper" ? 800 : overlay.pg==="appearance"||overlay.pg==="welcome" ? 660 : 490)
            readonly property real contentFit:overlayContent.item&&overlayContent.item.fitHeight!==undefined ? overlayContent.item.fitHeight : 0
            height:full ? overlay.height : Math.min(overlay.height-88,overlay.desktopStart ? 620 : launcher ? 740 : overlay.pg==="settings" ? 780 : overlay.pg==="clipboard" ? 650 : contentFit>0 ? contentFit : 860)
            Behavior on height {enabled:overlay.visible;NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
            x:full ? 0 : overlay.searchPanel ? 18+54 : overlay.desktopStart ? 18 : launcher||overlay.pg==="settings"||overlay.pg==="appearance"||overlay.pg==="welcome"||overlay.pg==="convergence"||overlay.pg==="wallpaper" ? (overlay.width-width)/2 : overlay.width-width-12
            y:full ? 0 : overlay.desktopStart||overlay.searchPanel ? overlay.height-height-72 : launcher||overlay.pg==="settings"||overlay.pg==="welcome" ? Math.max(60,(overlay.height-height)/2) : 62
            radius:full ? 0 : overlay.desktopStart ? 28 : overlay.searchPanel ? 32 : 36
            kind:phone&&launcher ? "widgets" : "panels"
            translucency:phone&&launcher ? Math.min(.35,Hub.prefs.glass) : Hub.prefs.glass
            border.width:phone&&launcher ? 0 : 1
            MouseArea {anchors.fill:parent;acceptedButtons:Qt.AllButtons}
            Loader {
                id:overlayContent
                anchors.fill:parent;anchors.topMargin:panel.phone ? PhoneState.statusFor(overlay.screen) : 0;anchors.bottomMargin:panel.phone ? PhoneState.navHeight : 0;active:overlay.visible&&!overlay.tabletLauncher
                onLoaded:contentArrival.restart()
                NumberAnimation {id:contentArrival;target:overlayContent;property:"opacity";from:0;to:1;duration:Theme.motion(180)}
                sourceComponent:overlay.pg==="search" ? (panel.phone ? mobileComponent : searchComponent) : overlay.pg==="settings" ? settingsComponent : overlay.pg==="launcher" ? (panel.phone ? mobileComponent : panel.game ? consoleComponent : overlay.desktopStart ? startComponent : launcherComponent) : overlay.pg==="clipboard" ? clipboardComponent : overlay.pg==="appearance" ? appearanceComponent : overlay.pg==="convergence" ? convergenceComponent : overlay.pg==="wallpaper" ? wallpaperComponent : overlay.pg==="windows" ? windowsComponent : overlay.pg==="welcome" ? welcomeComponent : controlsComponent
            }
            PhoneStatus {visible:panel.phone;anchors.top:parent.top;width:parent.width;height:PhoneState.statusFor(overlay.screen);output:overlay.screen}
            PhoneNavigation {visible:panel.phone;anchors.bottom:parent.bottom;width:parent.width;height:implicitHeight;output:overlay.screen}
            Rectangle {visible:Hub.toast!=="";anchors {bottom:parent.bottom;left:parent.left;right:parent.right;margins:12} height:72;radius:24;color:Theme.surfaceHigh;z:5
                MText {anchors {fill:parent;margins:14} text:Hub.toast;font.pixelSize:12;wrapMode:Text.Wrap;maximumLineCount:3;verticalAlignment:Text.AlignVCenter}
                MouseArea {anchors.fill:parent;onClicked:Hub.toast=""}
            }
        }
        Component {id:windowsComponent;WindowSwitcher {anchors.fill:parent;anchors.margins:panel.game ? 48 : 24;layoutMode:panel.game ? "console" : panel.phone ? "phone" : "desktop";focus:true}}
        Component {id:wallpaperComponent;WallpaperPicker {}}
        Component {id:welcomeComponent;Onboarding {}}
        Component {id:searchComponent;SearchPanel {}}
        Component {id:settingsComponent;Settings {}}
        Component {id:convergenceComponent;Convergence {}}
        Component {id:launcherComponent;Launcher {}}
        Component {id:startComponent;StartMenu {}}
        Component {id:mobileComponent;MobileHome {}}
        Loader {
            id:tabletLayer
            // Built once per tablet screen and kept, so opening the launcher never decodes the wallpaper or builds the app grid again.
            anchors.fill:parent;active:overlay.layoutMode==="phone"&&PhoneState.isTablet(overlay.screen)
            visible:overlay.tabletLauncher
            sourceComponent:Component {TabletLauncher {screenObj:overlay.screen;arrival:panel.arrival}}
        }
        Component {id:consoleComponent;ConsoleHome {}}
        Component {id:controlsComponent;QuickSettings {}}
        Component {id:clipboardComponent;ClipboardPanel {touchMode:panel.phone}}
        Component {id:appearanceComponent;ColumnLayout {
            anchors {fill:parent;margins:20} spacing:16
            RowLayout {Layout.fillWidth:true;MText {text:"Make it yours";font.pixelSize:26;font.weight:Font.DemiBold;Layout.fillWidth:true}MButton {icon:"close";tonal:true;onClicked:Hub.close()}}
            Appearance {Layout.fillWidth:true;Layout.fillHeight:true;compact:panel.phone}
        }}
        Shortcut {sequence:"Escape";enabled:!overlay.desktopStart&&!overlay.searchPanel&&!(panel.game&&panel.launcher);onActivated:Hub.close()}
        // Controller focus for every page in this window. Pages may define controllerTab(delta) and controllerBack().
        ControllerFocus {
            anchors.fill:parent;root:overlay.tabletLauncher ? tabletLayer : overlayContent;priority:0;closeOnBack:false;tabHints:true
            active:overlay.visible&&!(panel.game&&panel.launcher)&&!GameState.quickAccess
            onBack:{const page=overlay.tabletLauncher ? null : overlayContent.item;if(!(page&&page.controllerBack&&page.controllerBack()))Hub.close();}
            onTab:delta=>{const page=overlayContent.item;if(page&&page.controllerTab)page.controllerTab(delta);}
        }
    }
}
