import QtQuick
import QtQuick.Layouts
import Quickshell

// Tablet navigation: one island at the left with the keys and the workspaces, and a floating dock in the middle.
Item {
    id:bar
    property var screenObj:null
    property bool keys:true
    property alias workspaces:spaces
    signal back()
    signal home()
    signal recents()
    readonly property var pinned:Hub.favoriteApps.slice(0,8)
    // Running apps that are not pinned, one per app.
    readonly property var running:{
        const seen={};pinned.forEach(a=>seen[a.id]=true);
        const list=[];
        Hub.windows.forEach(w=>{const a=Hub.appForWindow(w);if(a&&!seen[a.id]){seen[a.id]=true;list.push(a);}});
        return list.slice(0,6);
    }
    // Opens a menu centred above an item of the bar, in screen coordinates. The bar window and the launcher window both span the full screen width.
    function menuAt(item, entries, title, icon) {
        const p=item.mapToItem(null,item.width/2,0);
        const windowHeight=item.Window.height;
        const screenHeight=bar.screenObj ? bar.screenObj.height : windowHeight;
        // An action started from the launcher's copy of the bar closes the launcher first, so its result is not hidden behind it.
        const wrapped=entries.map(e=>e.run ? Object.assign({},e,{run:()=>{if(Hub.page==="launcher")Hub.close();e.run();}}) : e);
        Hub.openTaskbarContext(bar.screenObj,p.x,screenHeight-windowHeight+p.y,wrapped,true,title,icon);
    }
    readonly property var frontApp:{const w=PhoneState.activeWindow();return w ? Hub.appForWindow(w) : null;}

    // Left island, as tall as the dock: the navigation keys as a connected button group, then the workspace chip.
    Island {
        id:side
        visible:bar.keys||Hub.status.hypr
        x:12;anchors.verticalCenter:parent.verticalCenter
        width:visible ? sideRow.implicitWidth+20 : 0;height:72
        Row {
            id:sideRow;anchors.centerIn:parent;spacing:12
            Row {
                visible:bar.keys;spacing:3;anchors.verticalCenter:parent.verticalCenter
                Segment {first:true;tooltip:"Back";onActivated:bar.back()
                    NavTriangle {anchors.centerIn:parent;width:18;height:18}}
                Segment {tooltip:"Home · hold for assistant";onActivated:bar.home();onHeld:Hub.openAssistant("")
                    Rectangle {anchors.centerIn:parent;width:18;height:18;radius:9;color:"transparent";border.width:2.5;border.color:Theme.text}}
                Segment {last:true;tooltip:"Recent apps";onActivated:bar.recents()
                    Rectangle {anchors.centerIn:parent;width:16;height:16;radius:4;color:"transparent";border.width:2.5;border.color:Theme.text}}
            }
            // Workspaces: one chip that pops the workspace card up out of the bar.
            WorkspaceSwitcher {id:spaces;visible:Hub.status.hypr;screenObj:bar.screenObj;anchors.verticalCenter:parent.verticalCenter}
        }
    }
    // The dock floats in the middle like the Pixel Tablet dock: all apps, search with Claude, pinned apps, then running apps.
    readonly property real leftEnd:side.visible ? side.x+side.width : 0
    readonly property real slotWidth:PhoneState.hit+8
    // Pinned and running apps that fit beside the side island.
    readonly property int fit:Math.max(1,Math.floor((bar.width-leftEnd-48-searchPill.width-appsButton.width-60)/slotWidth))
    Island {
        id:dock
        x:Math.max(bar.leftEnd+12,(bar.width-width)/2);anchors.verticalCenter:parent.verticalCenter
        width:dockRow.implicitWidth+16;height:72
        Behavior on width {NumberAnimation {duration:Theme.motion(220);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}}
        Row {
            id:dockRow
            x:8;anchors.verticalCenter:parent.verticalCenter;spacing:4
            // All apps sits first, at the left of the dock, like the Android taskbar.
            MButton {
                id:appsButton
                anchors.verticalCenter:parent.verticalCenter;icon:"apps";contained:true;implicitWidth:52;implicitHeight:52;tooltip:"All apps"
                onClicked:{if(bar.screenObj)Hub.targetScreen=bar.screenObj;Hub.mobileTab="apps";Hub.page="launcher";}
            }
            Rectangle {
                id:searchPill
                anchors.verticalCenter:parent.verticalCenter
                width:240;height:56;radius:28;color:Theme.level(4)
                Rectangle {anchors.fill:parent;radius:parent.radius;color:Theme.stateLayer;opacity:searchTap.pressed ? .12 : searchHover.hovered ? .07 : 0}
                HoverHandler {id:searchHover;cursorShape:Qt.PointingHandCursor}
                Row {
                    x:18;anchors.verticalCenter:parent.verticalCenter;spacing:12
                    Glyph {name:"search";font.pixelSize:22;color:Theme.text;anchors.verticalCenter:parent.verticalCenter}
                    MText {text:"Search";role:"body";font.pixelSize:16;color:Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                }
                TapHandler {id:searchTap;onTapped:{if(bar.screenObj)Hub.targetScreen=bar.screenObj;Hub.drawerHandoff=0;Hub.mobileTab="apps";Hub.drawerSearch=true;Hub.page="launcher";}}
                Accessible.role:Accessible.Button;Accessible.name:"Search"
                Rectangle {
                    anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter
                    width:40;height:40;radius:20;color:Theme.tertiaryContainer
                    Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:20;color:Theme.onTertiaryContainer}
                    MouseArea {anchors.fill:parent;onClicked:Hub.openAssistant("")}
                    Accessible.role:Accessible.Button;Accessible.name:"Ask Claude"
                }
            }
            Item {width:6;height:1}
            Repeater {model:bar.pinned.slice(0,bar.fit);AppSlot {required property var modelData;app:modelData}}
            Divider {visible:bar.running.length>0&&bar.fit>bar.pinned.length}
            Repeater {model:bar.running.slice(0,Math.max(0,bar.fit-bar.pinned.length));AppSlot {required property var modelData;app:modelData}}
        }
    }

    component Divider:Rectangle {width:2;height:36;radius:1;color:Theme.outline;anchors.verticalCenter:parent.verticalCenter}
    component Island:Rectangle {radius:height/2;color:Theme.alpha(Theme.level(3),Math.max(.94,Hub.prefs.glass))}
    // One segment of a connected button group: outer corners round, inner corners small, and a small gap to the next segment.
    component Segment:Rectangle {
        id:seg
        property bool first:false
        property bool last:false
        property bool selected:false
        property string tooltip:""
        signal activated()
        signal held()
        width:52;height:52
        topLeftRadius:first ? 26 : 8;bottomLeftRadius:first ? 26 : 8;topRightRadius:last ? 26 : 8;bottomRightRadius:last ? 26 : 8
        color:selected ? Theme.primary : Theme.alpha(Theme.text,segMouse.pressed ? .16 : segMouse.containsMouse ? .11 : .07)
        Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durShort)}}
        MouseArea {id:segMouse;anchors.fill:parent;hoverEnabled:true;onClicked:seg.activated();onPressAndHold:seg.held()}
        Accessible.role:Accessible.Button;Accessible.name:tooltip;Accessible.onPressAction:activated()
    }
    // App icon. Running apps have a line under the icon; the app in front has a longer one.
    component AppSlot:Item {
        id:slot
        property var app:null
        readonly property var windows:Hub.windows.filter(w=>Hub.appForWindow(w)===slot.app)
        readonly property bool front:!!app&&bar.frontApp===app
        width:bar.slotWidth
        height:56
        Rectangle {anchors.centerIn:parent;width:parent.width-4;height:52;radius:20;color:Theme.stateLayer;opacity:tap.pressed ? .14 : slotHover.hovered ? .08 : 0}
        HoverHandler {id:slotHover;cursorShape:Qt.PointingHandCursor}
        AppIcon {anchors.centerIn:parent;anchors.verticalCenterOffset:-2;width:Math.min(46,PhoneState.hit);height:width;app:slot.app}
        // Running apps get a short line under the icon; the app in front gets a longer one, like the Android taskbar.
        Rectangle {
            visible:slot.windows.length>0
            anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:-3
            width:slot.front ? 18 : 6;height:4;radius:2;color:slot.front ? Theme.primary : Theme.alpha(Theme.text,.55)
            Behavior on width {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
        }
        // The menu opens in the shell's context menu window above the bar. A popup window from a bar panel can be moved aside by the compositor.
        function menuEntries() {
            if(!slot.app)return [];
            return PhoneState.windowExtras(bar.screenObj,slot.app).concat(Hub.appMenu(slot.app));
        }
        TapHandler {id:tap;onTapped:Hub.launch(slot.app);onLongPressed:bar.menuAt(slot,slot.menuEntries(),slot.app ? slot.app.name : "","apps")}
        TapHandler {acceptedButtons:Qt.RightButton;onTapped:bar.menuAt(slot,slot.menuEntries(),slot.app ? slot.app.name : "","apps")}
        Accessible.role:Accessible.Button;Accessible.name:slot.app ? slot.app.name : ""
    }
}
