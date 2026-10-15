import QtQuick
import QtQuick.Layouts
import Quickshell

// Tablet navigation: islands that share the full width. Keys at the left, apps and search fill the middle, Claude and the drawer sit at the right.
Item {
    id:bar
    property var screenObj:null
    property bool keys:true
    signal back()
    signal home()
    signal recents()
    readonly property var pinned:Hub.favoriteApps.slice(0,8)
    // Pinned apps first, then running apps that are not pinned.
    readonly property var apps:{
        const seen={};const list=pinned.slice();
        list.forEach(a=>seen[a.id]=true);
        Hub.windows.forEach(w=>{const a=Hub.appForWindow(w);if(a&&!seen[a.id]){seen[a.id]=true;list.push(a);}});
        return list.slice(0,10);
    }
    readonly property var frontApp:{const w=PhoneState.activeWindow();return w ? Hub.appForWindow(w) : null;}

    Island {
        id:left
        visible:bar.keys
        x:12;anchors.verticalCenter:parent.verticalCenter
        width:visible ? keyRow.implicitWidth+16 : 0;height:56
        Row {
            id:keyRow;anchors.centerIn:parent;spacing:0
            Key {tooltip:"Back";onActivated:bar.back()
                NavTriangle {anchors.centerIn:parent;width:18;height:18}}
            Key {tooltip:"Home · hold for assistant";onActivated:bar.home();onHeld:Hub.openAssistant("")
                Rectangle {anchors.centerIn:parent;width:18;height:18;radius:9;color:"transparent";border.width:2.5;border.color:Theme.text}}
            Key {tooltip:"Recent apps";onActivated:bar.recents()
                Rectangle {anchors.centerIn:parent;width:16;height:16;radius:4;color:"transparent";border.width:2.5;border.color:Theme.text}}
        }
    }
    // Workspaces: one chip per workspace and a plus for a new one. Tap switches; windows stay where they are.
    Island {
        id:spaces
        visible:Hub.status.hypr
        x:left.visible ? left.x+left.width+8 : 12;anchors.verticalCenter:parent.verticalCenter
        width:visible ? spaceRow.implicitWidth+16 : 0;height:56
        Row {
            id:spaceRow;anchors.centerIn:parent;spacing:4
            Repeater {
                model:(Hub.status.workspaces||[]).slice().sort((a,b)=>a-b)
                Rectangle {
                    required property var modelData
                    readonly property bool current:Number(modelData)===Number(Hub.status.workspace)
                    readonly property bool busy:Hub.windows.some(w=>Number(w.workspace)===Number(modelData))
                    width:current ? 44 : 32;height:32;radius:16;anchors.verticalCenter:parent.verticalCenter
                    color:current ? Theme.primary : busy ? Theme.alpha(Theme.text,.14) : "transparent"
                    border.width:current||busy ? 0 : 1;border.color:Theme.outline
                    Behavior on width {NumberAnimation {duration:Theme.motion(Theme.durShort);easing.type:Easing.OutCubic}}
                    MText {anchors.centerIn:parent;text:String(modelData);role:"label";font.weight:Font.Bold;color:parent.current ? Theme.onPrimary : Theme.text}
                    MouseArea {anchors.fill:parent;anchors.margins:-4;onClicked:Hub.workspace(Number(modelData))}
                    Accessible.role:Accessible.Button;Accessible.name:"Workspace "+modelData
                }
            }
            Rectangle {
                width:32;height:32;radius:16;color:"transparent";border.width:1;border.color:Theme.outline;anchors.verticalCenter:parent.verticalCenter
                Glyph {anchors.centerIn:parent;name:"add";font.pixelSize:18;color:Theme.subtext}
                MouseArea {anchors.fill:parent;anchors.margins:-4;onClicked:Hub.command({action:"workspace-empty"})}
                Accessible.role:Accessible.Button;Accessible.name:"New workspace"
            }
        }
    }
    Island {
        id:right
        anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter
        width:rightRow.implicitWidth+16;height:56
        Row {
            id:rightRow;anchors.centerIn:parent;spacing:6
            MButton {anchors.verticalCenter:parent.verticalCenter;icon:"auto_awesome";implicitWidth:44;implicitHeight:44;tooltip:"Ask Claude";onClicked:Hub.openAssistant("")}
            MButton {anchors.verticalCenter:parent.verticalCenter;icon:"apps";filled:true;implicitWidth:44;implicitHeight:44;tooltip:"All apps";onClicked:{if(bar.screenObj)Hub.targetScreen=bar.screenObj;Hub.mobileTab="apps";Hub.page="launcher";}}
        }
    }
    // The middle island takes all the space between the other two.
    Island {
        anchors {left:spaces.visible ? spaces.right : bar.keys ? left.right : parent.left;right:right.left;leftMargin:spaces.visible||bar.keys ? 8 : 12;rightMargin:8;verticalCenter:parent.verticalCenter}
        height:56
        Row {
            id:appRow
            x:8;anchors.verticalCenter:parent.verticalCenter;spacing:2
            Repeater {model:bar.apps;AppSlot {required property var modelData;app:modelData}}
        }
        Rectangle {
            anchors.right:parent.right;anchors.rightMargin:6;anchors.verticalCenter:parent.verticalCenter
            visible:appRow.x+appRow.width+searchRow.implicitWidth+40<parent.width
            height:44;width:searchRow.implicitWidth+28;radius:22;color:Theme.alpha(Theme.text,.06)
            Row {id:searchRow;anchors.centerIn:parent;spacing:8
                Glyph {name:"search";font.pixelSize:20;color:Theme.subtext}
                MText {text:"Search";role:"label";color:Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}
            TapHandler {onTapped:{if(bar.screenObj)Hub.targetScreen=bar.screenObj;Hub.mobileTab="apps";Hub.drawerSearch=true;Hub.page="launcher";}}
            Accessible.role:Accessible.Button;Accessible.name:"Search"
        }
    }

    component Island:Rectangle {radius:height/2;color:Theme.alpha(Theme.level(2),Math.max(.88,Hub.prefs.glass));border.width:1;border.color:Theme.outline}
    component Key:Item {
        id:key
        property string tooltip:""
        signal activated()
        signal held()
        width:PhoneState.hit+4;height:48
        Rectangle {anchors.centerIn:parent;width:48;height:40;radius:20;color:Theme.stateLayer;opacity:keyMouse.pressed ? .14 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(120)}}}
        MouseArea {id:keyMouse;anchors.fill:parent;onClicked:key.activated();onPressAndHold:key.held()}
        Accessible.role:Accessible.Button;Accessible.name:tooltip;Accessible.onPressAction:activated()
    }
    // App icon. The app in front grows into a chip with its name; running apps have a dot.
    component AppSlot:Item {
        id:slot
        property var app:null
        readonly property var windows:Hub.windows.filter(w=>Hub.appForWindow(w)===slot.app)
        readonly property bool front:!!app&&bar.frontApp===app
        width:front ? chip.implicitWidth+24 : PhoneState.hit+4
        height:48
        Behavior on width {NumberAnimation {duration:Theme.motion(220);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}}
        Rectangle {anchors.fill:parent;radius:height/2;color:Theme.secondaryContainer;opacity:slot.front ? 1 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(160)}}}
        Rectangle {anchors.centerIn:parent;width:44;height:44;radius:16;color:Theme.stateLayer;opacity:tap.pressed ? .14 : 0}
        Row {
            id:chip;anchors.centerIn:parent;spacing:8
            AppIcon {width:PhoneState.hit-12;height:width;app:slot.app;anchors.verticalCenter:parent.verticalCenter}
            MText {visible:slot.front;text:slot.app ? slot.app.name : "";role:"label";color:Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter;width:Math.min(implicitWidth,120);elide:Text.ElideRight}
        }
        Rectangle {
            visible:slot.windows.length>0&&!slot.front
            anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:-1
            width:5;height:5;radius:2.5;color:Theme.primary
        }
        OpalMenu {
            id:menu;title:slot.app ? slot.app.name : "";icon:"apps"
            entries:{
                if(!slot.app)return [];
                const extra=[];const w=slot.windows[0];
                if(w&&Hub.status.hypr){
                    const active=PhoneState.activeWindow();
                    if(active&&active.address!==w.address)extra.push({text:"Open beside current app",icon:"splitscreen_vertical_add",run:()=>PhoneState.startSplit(bar.screenObj,active.address,w.address)});
                    extra.push({text:"Slide over",icon:"picture_in_picture",run:()=>PhoneState.slideOver(bar.screenObj,w.address)});
                }
                return extra.concat(Hub.appMenu(slot.app));
            }
        }
        TapHandler {id:tap;onTapped:Hub.launch(slot.app);onLongPressed:menu.popup(slot.width/2,0)}
        TapHandler {acceptedButtons:Qt.RightButton;onTapped:menu.popup(slot.width/2,0)}
        Accessible.role:Accessible.Button;Accessible.name:slot.app ? slot.app.name : ""
    }
}
