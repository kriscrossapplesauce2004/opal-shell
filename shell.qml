import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    function show(page) {Hub.targetScreen=Hub.chooseScreen();Hub.toggle(page);}
    IpcHandler {
        target:"opal"
        function launcher():void {Hub.launcherSection="apps";root.show("launcher");}
        function clipboard():void {Hub.targetScreen=Hub.chooseScreen();Hub.toggleClipboard();}
        function controls():void {root.show("controls");}
        function notifications():void {root.show("notifications");}
        function phone():void {Hub.targetScreen=Hub.chooseScreen();Hub.mode("phone");}
        function gaming():void {Hub.mode("console");}
        function desktop():void {Hub.mode("desktop");}
        function adaptive():void {Hub.mode("auto");}
        function appearance():void {root.show("appearance");}
        function convergence():void {root.show("convergence");}
        function close():void {Hub.close();}
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
            PanelWindow {
                id:desktop
                screen:output.modelData
                anchors {top:true;bottom:true;left:true;right:true}
                exclusionMode:ExclusionMode.Ignore
                WlrLayershell.layer:WlrLayer.Background
                WlrLayershell.namespace:"opal-wallpaper"
                WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
                color:Theme.base
                Wallpaper {anchors.fill:parent;showWidgets:output.layoutMode==="desktop"&&Hub.prefs.desktopWidgets!==false}
                // Non-exclusive homes live behind applications. Only the explicit overlay takes keys.
                Loader {
                    anchors {fill:parent;topMargin:Hub.prefs.mode==="console" ? 0 : 56;bottomMargin:Hub.prefs.mode==="console" ? 0 : output.layoutMode==="phone" ? 54 : 84}
                    active:output.layoutMode!=="desktop"&&Hub.page===""
                    sourceComponent:output.layoutMode==="phone" ? phoneHome : gameHome
                }
                Component {id:phoneHome;MobileHome {embedded:true}}
                Component {id:gameHome;ConsoleHome {embedded:true}}
                OpalMenu {id:desktopMenu;entries:[
                    {text:"Applications",icon:"apps",run:()=>{Hub.launcherSection="apps";output.show("launcher");}},
                    {text:"Personalize desktop",icon:"palette",run:()=>output.show("appearance")},
                    {text:Theme.light ? "Dark appearance" : "Light appearance",icon:"moon",run:()=>Hub.set("light",!Theme.light)},
                    {text:"Taskbar options",icon:"settings",run:()=>output.show("appearance")}
                ]}
                MouseArea {id:desktopMouse;anchors.fill:parent;acceptedButtons:Qt.RightButton;onClicked:e=>{Hub.targetScreen=output.modelData;desktopMenu.openAt(desktopMouse,e.x,e.y);}}
            }
            PanelWindow {
                id:statusbar
                screen:output.modelData
                visible:Hub.prefs.mode!=="console"
                anchors {top:true;left:true;right:true}
                implicitHeight:output.layoutMode==="phone" ? 40 : 44
                exclusiveZone:Hub.prefs.mode==="console" ? 0 : implicitHeight
                WlrLayershell.namespace:"opal-bar"
                color:Theme.alpha(Theme.base,.48)
                Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Theme.outline}
                IdleInhibitor {window:statusbar;enabled:Hub.keepAwake||Hub.gameSession}
                OpalMenu {id:statusMenu;entries:Hub.taskbarMenu()}
                MouseArea {
                    id:statusMouse;anchors.fill:parent;acceptedButtons:Qt.RightButton
                    onClicked:e=>{Hub.targetScreen=output.modelData;statusMenu.openAt(statusMouse,e.x,e.y);}
                }
                RowLayout {
                    anchors {left:parent.left;verticalCenter:parent.verticalCenter;leftMargin:8}
                    spacing:6
                    MButton {visible:output.layoutMode!=="phone";icon:"apps";compact:true;implicitWidth:32;implicitHeight:30;tooltip:"All apps";menuEntries:Hub.taskbarMenu();onClicked:{Hub.launcherSection="apps";output.show("launcher");}}
                    MText {text:Qt.formatDateTime(Hub.now,statusbar.width<700 ? "HH:mm" : "HH:mm   ddd, d MMM");font.pixelSize:12;font.weight:Font.DemiBold}
                    MButton {visible:statusbar.width>1300&&output.layoutMode==="desktop";text:Hub.status.title.substring(0,36);compact:true;implicitHeight:30;ink:Theme.subtext;tooltip:"Running windows";onClicked:{Hub.targetScreen=output.modelData;Hub.openSection("windows");}}
                }
                Rectangle {
                    visible:statusbar.width>800&&Hub.status.hypr&&output.layoutMode!=="phone"
                    anchors.centerIn:parent
                    width:workspaces.implicitWidth+16;height:32;radius:16;color:Theme.alpha(Theme.surfaceHigh,.65)
                    WheelHandler {
                        onWheel:e=>{const delta=e.angleDelta.y||e.angleDelta.x;if(delta)Hub.workspace(Math.max(1,Math.min(12,Hub.status.workspace+(delta>0 ? -1 : 1))));e.accepted=true;}
                    }
                    Row {
                        id:workspaces;anchors.centerIn:parent;spacing:4
                        Repeater {
                            model:Math.min(12,Math.max(5,Hub.status.workspace))
                            Rectangle {
                                id:ws
                                required property int index
                                property bool current:Hub.status.workspace===index+1
                                width:32;height:28;radius:current ? 10 : 14
                                color:current ? Theme.primary : Hub.status.workspaces.indexOf(index+1)>=0 ? Theme.alpha(Theme.primary,.3) : "transparent"
                                MText {anchors.centerIn:parent;text:String(index+1);font.pixelSize:12;color:ws.current ? Theme.primaryText : Theme.muted}
                                OpalMenu {id:workspaceMenu;entries:[{text:"Switch to workspace "+(ws.index+1),icon:"desktop",run:()=>Hub.workspace(ws.index+1)},
                                    {text:"Show running windows",icon:"list",run:()=>{Hub.targetScreen=output.modelData;Hub.openSection("windows");}}]}
                                MouseArea {id:workspaceMouse;anchors.fill:parent;cursorShape:Qt.PointingHandCursor
acceptedButtons:Qt.LeftButton|Qt.RightButton;onClicked:e=>{if(e.button===Qt.RightButton)workspaceMenu.openAt(workspaceMouse,e.x,e.y);else Hub.workspace(ws.index+1);}}
                            }
                        }
                    }
                }
                RowLayout {
                    anchors {right:parent.right;verticalCenter:parent.verticalCenter;rightMargin:8}
                    spacing:2
                    MButton {visible:Hub.focusRunning&&statusbar.width>1300;icon:"timer";text:Math.floor(Hub.focusSeconds/60)+":"+(Hub.focusSeconds%60).toString().padStart(2,"0");filled:true;compact:true;implicitHeight:28;onClicked:output.show("controls")}
                    MButton {visible:Hub.status.track!==""&&statusbar.width>1600;icon:Hub.status.playing ? "music" : "pause";text:Hub.status.track.substring(0,20);compact:true;implicitHeight:30;onClicked:Hub.media("play-pause");menuEntries:[{text:"Previous track",icon:"previous",run:()=>Hub.media("previous")},{text:"Next track",icon:"skip",run:()=>Hub.media("next")}]}
                    Repeater {
                        model:statusbar.width>600 ? SystemTray.items : null
                        Item {required property var modelData;width:24;height:30
                            Image {anchors.centerIn:parent;width:16;height:16;source:modelData.icon}
                            MouseArea {anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;onClicked:e=>{if(e.button===Qt.RightButton&&modelData.hasMenu)modelData.display(statusbar,statusbar.width-40,30);else modelData.activate();}}
                        }
                    }
                    MButton {icon:Hub.dnd ? "quiet" : "bell";text:Hub.unread ? String(Hub.unread) : "";compact:true;implicitHeight:30;implicitWidth:Hub.unread ? 48 : 30;tooltip:"Notifications";onClicked:output.show("notifications");menuEntries:[{text:Hub.dnd ? "Allow notifications" : "Do not disturb",icon:"quiet",run:()=>Hub.set("dnd",!Hub.dnd)}]}
                    MButton {icon:Hub.status.wifi ? "wifi" : "wifiOff";compact:true;implicitWidth:30;implicitHeight:30;tooltip:Hub.status.network;onClicked:output.show("controls");menuEntries:[{text:"Network settings",icon:"wifi",run:()=>Hub.settings("network")}]}
                    MButton {visible:statusbar.width>700;icon:Hub.status.muted ? "mute" : "volume";compact:true;implicitWidth:30;implicitHeight:30;tooltip:"Volume "+Hub.status.volume+"% · Scroll to adjust";scrollable:true;onScrolled:steps=>Hub.volume(Hub.status.volume+steps*5);onClicked:output.show("volume");menuEntries:[{text:"Toggle mute",icon:"mute",run:()=>Hub.command({action:"mute"})},{text:"Audio mixer",icon:"volume",run:()=>Hub.settings("audio")}]}
                    MButton {visible:Hub.status.battery>=0;icon:Hub.status.charging ? "charging" : "battery";text:Hub.status.battery+"%";compact:true;implicitHeight:30;onClicked:output.show("controls")}
                    MButton {icon:"settings";compact:true;implicitWidth:30;implicitHeight:30;onClicked:output.show("controls")}
                }
            }
            Taskbar {screen:output.modelData}
            PanelWindow {
                screen:output.modelData
                visible:(Hub.toast!==""||Hub.osd!=="")&&Hub.page===""
                anchors {bottom:true;right:true}
                margins {bottom:90;right:12}
                implicitWidth:Math.min(390,output.modelData.width-24);implicitHeight:Hub.toast!=="" ? 100 : 60
                exclusionMode:ExclusionMode.Ignore
                WlrLayershell.namespace:"opal-toast"
                color:"transparent"
                Surface {
                    anchors.fill:parent;radius:30
                    RowLayout {anchors {fill:parent;margins:18} spacing:12
                        Glyph {name:Hub.toast!=="" ? "bell" : "volume";color:Theme.primary}
                        MText {text:Hub.toast||Hub.osd;Layout.fillWidth:true;font.pixelSize:13;maximumLineCount:4;wrapMode:Text.Wrap}
                    }
                    MouseArea {anchors.fill:parent;onClicked:{Hub.toast="";Hub.osd="";}}
                }
            }
        }
    }
    PanelWindow {
        id:dockingWelcome
        screen:Hub.dockScreen || Quickshell.screens[0]
        visible:Hub.dockNotice&&Hub.page===""
        anchors {top:true;right:true}
        margins {top:64;right:16}
        implicitWidth:Math.min(580,screen ? screen.width-32 : 580)
        implicitHeight:width<450 ? 310 : 244
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-toast"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        color:"transparent"
        DockWelcome {id:dockCard;anchors.fill:parent
            property real arrival:1
            opacity:arrival;transform:Translate {y:(1-dockCard.arrival)*-28}
            scale:.94+.06*arrival
            Connections {target:Hub;function onDockNoticeChanged(){if(Hub.dockNotice)dockArrival.restart();}}
            NumberAnimation {id:dockArrival;target:dockCard;property:"arrival";from:0;to:1;duration:Theme.motion(520);easing.type:Easing.OutCubic}
        }
    }
    PanelWindow {
        id:notificationPopups
        screen:Notifier.popupScreen || Quickshell.screens[0]
        visible:Notifier.popups.length>0 && Hub.page===""
        anchors {top:true;right:true}
        margins {top:64;right:12}
        implicitWidth:Math.min(390,screen ? screen.width-24 : 390)
        implicitHeight:Math.min(popupColumn.implicitHeight,screen ? screen.height-110 : 700)
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-toast"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        color:"transparent"
        Flickable {
            anchors.fill:parent;contentHeight:popupColumn.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
            Column {id:popupColumn;width:parent.width;spacing:10
                Repeater {model:Notifier.popups;NotificationCard {required property var modelData;entry:modelData;popup:true;width:popupColumn.width}}
            }
        }
    }
    PanelWindow {
        id:overlay
        screen:Hub.targetScreen || Quickshell.screens[0]
        visible:Hub.page!==""
        readonly property string layoutMode:Hub.layoutFor(screen ? screen.width : 1920,screen ? screen.height : 1080,screen ? screen.name : "")
        readonly property bool phone:layoutMode==="phone"
        readonly property bool game:layoutMode==="console"
        readonly property bool launcher:Hub.page==="launcher"
        readonly property bool volumePopover:Hub.page==="volume"
        readonly property bool fullScreenCard:phone||game&&launcher
        readonly property bool centeredCard:launcher||Hub.page==="windows"||Hub.page==="appearance"||Hub.page==="convergence"||Hub.page==="wallpaper"
        readonly property real cardWidth:fullScreenCard ? (screen ? screen.width : 1920) : Math.min((screen ? screen.width : 1920)-(launcher ? 24 : 40),Hub.page==="volume" ? 360 : launcher ? 960 : Hub.page==="windows" ? 1100 : Hub.page==="wallpaper" ? 1060 : Hub.page==="convergence" ? 800 : Hub.page==="appearance" ? 660 : 490)
        readonly property real cardHeight:fullScreenCard ? (screen ? screen.height : 1080) : launcher ? Math.min((screen ? screen.height : 1080)-88,740) : Math.min((screen ? screen.height : 1080)-(centeredCard ? 112 : 88),Hub.page==="volume" ? 116 : Hub.page==="clipboard" ? 650 : 760)
        // One layer owns the card AND outside input. Separate transparent
        // layer windows are not a reliable click-away target on the compositor.
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"opal-overlay"
        WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Restore the launcher's frosted backdrop. Other panels remain clear
        // outside the card; the existing ignore_alpha blur rule skips alpha 0.
        color:launcher ? Theme.alpha(Theme.base,.12) : "transparent"
        MouseArea {
            anchors.fill:parent
            acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton
            onPressed:Hub.close()
        }
        Surface {
            id:panel
            property real arrival:1
            opacity:arrival
            Connections {target:overlay;function onVisibleChanged(){if(overlay.visible)panelArrival.restart();}}
            NumberAnimation {id:panelArrival;target:panel;property:"arrival";from:0;to:1;duration:Theme.motion(360);easing.type:Easing.OutCubic}
            width:overlay.fullScreenCard ? overlay.width : overlay.cardWidth
            height:overlay.fullScreenCard ? overlay.height : overlay.cardHeight
            x:overlay.fullScreenCard ? 0 : overlay.centeredCard ? (overlay.width-width)/2 : overlay.width-width-12
            y:overlay.fullScreenCard ? 0 : overlay.centeredCard ? Math.max(0,(overlay.height-height)/2) : 52
            readonly property bool phone:overlay.phone
            readonly property bool game:overlay.game
            readonly property bool launcher:overlay.launcher
            readonly property bool fullScreenCard:overlay.fullScreenCard
            readonly property bool centeredCard:overlay.centeredCard
            radius:fullScreenCard ? 0 : launcher ? 36 : overlay.volumePopover ? 24 : 28
            translucency:phone&&launcher ? Math.min(.35,Hub.prefs.glass) : Hub.prefs.glass
            elevated:false
            border.width:overlay.volumePopover ? 0 : 1
            MouseArea {anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton}
            Loader {
                id:overlayContent
                anchors.fill:parent;active:overlay.visible
                onLoaded:contentArrival.restart()
                NumberAnimation {id:contentArrival;target:overlayContent;property:"opacity";from:0;to:1;duration:Theme.motion(180)}
                sourceComponent:Hub.page==="volume" ? volumeComponent : Hub.page==="launcher" ? (panel.phone ? mobileComponent : panel.game ? consoleComponent : launcherComponent) : Hub.page==="clipboard" ? clipboardComponent : Hub.page==="appearance" ? appearanceComponent : Hub.page==="convergence" ? convergenceComponent : Hub.page==="wallpaper" ? wallpaperComponent : Hub.page==="windows" ? windowsComponent : controlsComponent
            }
            Rectangle {visible:Hub.toast!=="";anchors {bottom:parent.bottom;left:parent.left;right:parent.right;margins:12} height:72;radius:24;color:Theme.surfaceHigh;z:5
                MText {anchors {fill:parent;margins:14} text:Hub.toast;font.pixelSize:12;wrapMode:Text.Wrap;maximumLineCount:3;verticalAlignment:Text.AlignVCenter}
                MouseArea {anchors.fill:parent;onClicked:Hub.toast=""}
            }
        }
        Component {id:windowsComponent;ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
            RowLayout {Layout.fillWidth:true;MText {text:"App switcher";font.pixelSize:28;Layout.fillWidth:true}MButton {icon:"close";onClicked:Hub.close()}}
            WindowSwitcher {Layout.fillWidth:true;Layout.fillHeight:true;layoutMode:panel.game ? "console" : panel.phone ? "phone" : "desktop";focus:true}
        }}
        Component {id:wallpaperComponent;WallpaperPicker {}}
        Component {id:convergenceComponent;Convergence {}}
        Component {id:launcherComponent;Launcher {}}
        Component {id:mobileComponent;MobileHome {}}
        Component {id:consoleComponent;ConsoleHome {}}
        Component {id:controlsComponent;QuickSettings {}}
        Component {id:volumeComponent;ColumnLayout {
            anchors.fill:parent;anchors.margins:16;spacing:4
            RowLayout {Layout.fillWidth:true
                MText {text:"Volume · "+Hub.status.volume+"%";Layout.fillWidth:true;font.weight:Font.DemiBold}
                MButton {icon:"close";compact:true;implicitHeight:28;implicitWidth:28;onClicked:Hub.close()}
            }
            RowLayout {Layout.fillWidth:true;spacing:8
                MButton {icon:Hub.status.muted ? "mute" : "volume";tonal:true;compact:true;tooltip:"Toggle mute";onClicked:Hub.command({action:"mute"})}
                ExpressiveSlider {Layout.fillWidth:true;value:Hub.status.volume;icon:Hub.status.muted ? "mute" : "volume";onMoved:Hub.volume(value)}
            }
        }}
        Component {id:clipboardComponent;ClipboardPanel {touchMode:panel.phone}}
        Component {id:appearanceComponent;ColumnLayout {
            anchors {fill:parent;margins:20} spacing:16
            RowLayout {Layout.fillWidth:true;MText {text:"Make it yours";font.pixelSize:26;font.weight:Font.DemiBold;Layout.fillWidth:true}MButton {icon:"close";tonal:true;onClicked:Hub.close()}}
            Appearance {Layout.fillWidth:true;Layout.fillHeight:true;compact:panel.phone}
        }}
        Shortcut {sequence:"Escape";enabled:!(panel.game&&panel.launcher);onActivated:Hub.close()}
    }
}
