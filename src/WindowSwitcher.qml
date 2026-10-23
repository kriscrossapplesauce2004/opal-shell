import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell

// Open windows inside a page. Console mode is a hero carousel driven by the controller; elsewhere it is a calm grid of previews.
// Alt+Tab, Super+Tab and phone recents have their own surfaces (AppSwitcher, RecentsCarousel).
Item {
    id:s
    property string layoutMode:"desktop"
    property bool active:visible
    property string query:""
    property int selection:0
    readonly property bool touchCarousel:false
    readonly property bool gaming:layoutMode==="console"
    readonly property var allWindows:Hub.recentWindows.filter(w=>!(w.workspaceName||"").startsWith("special:")||Hub.minimized(w))
    readonly property var windows:{
        const q=query.toLowerCase().trim();
        if(!q)return allWindows;
        return allWindows.filter(w=>String(w.title||"").toLowerCase().indexOf(q)>=0||String(w.className||"").toLowerCase().indexOf(q)>=0);
    }
    function navigate(key) {
        const n=windows.length;
        if(!n)return;
        if(key==="right"||key==="down")selection=(selection+1)%n;
        else if(key==="left"||key==="up")selection=(selection-1+n)%n;
        else if(key==="accept"&&windows[selection])Hub.focusWindow(windows[selection]);
        else if(key==="back")Hub.close();
        Hub.navigate(key);
    }
    Loader {anchors.fill:parent;sourceComponent:s.gaming ? heroView : gridView}

    // Live preview clipped to a rounded shape.
    component Preview: Item {
        id:pv
        property var entry:null
        property real radius:16
        property bool live:true
        Rectangle {anchors.fill:parent;radius:pv.radius;color:Theme.level(4)}
        Item {
            anchors.fill:parent
            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
            layer.effect:MultiEffect {maskEnabled:true;maskSource:pvMask;maskThresholdMin:.5;maskSpreadAtMin:1}
            Loader {
                anchors.fill:parent;active:pv.live&&!!pv.entry&&s.active
                source:Hub.status.hypr ? "HyprWindowPreview.qml" : "WindowPreview.qml"
                onLoaded:{if(Hub.status.hypr)item.address=Qt.binding(()=>pv.entry ? pv.entry.address||"" : "");else item.handle=Qt.binding(()=>pv.entry ? pv.entry.handle||null : null);}
            }
        }
        Rectangle {id:pvMask;anchors.fill:parent;radius:pv.radius;visible:false;layer.enabled:true}
    }

    // Console: the focused app is large with its name and actions; neighbours shrink to the sides.
    Component {id:heroView;Item {
        id:hero
        readonly property real cardW:Math.min(width*.52,(height-250)*16/9)
        readonly property real cardH:cardW*9/16
        readonly property var current:s.windows[path.currentIndex]||null
        readonly property var app:current ? Hub.appForWindow(current) : null
        MText {x:8;y:0;text:"Running";role:"headline";font.pixelSize:34}
        MText {x:8;y:44;text:s.windows.length+(s.windows.length===1 ? " app" : " apps")+" · Guide opens this anywhere";role:"body";color:Theme.subtext}
        PathView {
            id:path
            y:96;width:parent.width;height:hero.cardH+20
            model:s.windows
            pathItemCount:Math.min(5,Math.max(1,s.windows.length))
            preferredHighlightBegin:.5;preferredHighlightEnd:.5;highlightRangeMode:PathView.StrictlyEnforceRange
            snapMode:PathView.SnapOneItem;highlightMoveDuration:Theme.motion(320)
            Component.onCompleted:currentIndex=Math.max(0,s.windows.findIndex(w=>Hub.active(w)))
            path:Path {
                startX:-hero.cardW*.4;startY:path.height/2
                PathAttribute {name:"k";value:.5}
                PathLine {x:path.width/2;y:path.height/2}
                PathAttribute {name:"k";value:1}
                PathLine {x:path.width+hero.cardW*.4;y:path.height/2}
                PathAttribute {name:"k";value:.5}
            }
            delegate:Item {
                id:card
                required property var modelData
                required property int index
                readonly property real k:PathView.k===undefined ? .5 : PathView.k
                readonly property bool isCurrent:PathView.isCurrentItem
                width:hero.cardW;height:hero.cardH;scale:k;z:k*10
                opacity:.45+.55*Math.pow((k-.5)/.5,2)
                Preview {anchors.fill:parent;entry:card.modelData;radius:28}
                Rectangle {visible:card.isCurrent;anchors.fill:parent;anchors.margins:-6;radius:34;color:"transparent";border.width:4;border.color:Theme.primary}
                MouseArea {anchors.fill:parent;onClicked:{if(card.isCurrent)Hub.focusWindow(card.modelData);else path.currentIndex=card.index;}}
                activeFocusOnTab:true
                onActiveFocusChanged:if(activeFocus)path.currentIndex=index
                Keys.onReturnPressed:Hub.focusWindow(modelData)
                Accessible.role:Accessible.Button;Accessible.name:modelData.title;Accessible.onPressAction:Hub.focusWindow(modelData)
            }
        }
        Column {
            visible:!!hero.current
            x:(parent.width-hero.cardW)/2;y:path.y+path.height+18;width:hero.cardW;spacing:6
            Row {spacing:12
                Image {width:40;height:40;sourceSize:Qt.size(80,80);anchors.verticalCenter:parent.verticalCenter;source:Quickshell.iconPath(hero.app ? hero.app.icon : "application-x-executable",true)}
                MText {text:hero.app ? hero.app.name : hero.current ? (String(hero.current.className).startsWith("steam_app_") ? "Game" : hero.current.className) : "";role:"headline";anchors.verticalCenter:parent.verticalCenter}
            }
            MText {width:parent.width;text:hero.current ? hero.current.title : "";role:"body";color:Theme.subtext}
            Row {spacing:10;topPadding:8
                MButton {text:"Switch";icon:"open_in_new";filled:true;onClicked:if(hero.current)Hub.focusWindow(hero.current)}
                MButton {text:"Close";icon:"close";tonal:true;onClicked:if(hero.current)Hub.closeWindow(hero.current)}
            }
        }
        MText {visible:s.windows.length===0;anchors.centerIn:parent;text:"Nothing is running";role:"title";color:Theme.subtext}
        Connections {target:Hub;function onNavigate(key) {if(!s.active)return;if(key==="left")path.decrementCurrentIndex();else if(key==="right")path.incrementCurrentIndex();else if(key==="accept"&&hero.current)Hub.focusWindow(hero.current);else if(key==="back")Hub.close();}}
    }}

    // Grid: previews at a calm common shape, the app and title under each, close on hover.
    Component {id:gridView;Item {
        GridView {
            id:grid
            anchors.fill:parent;clip:true;boundsBehavior:Flickable.StopAtBounds
            readonly property int columns:Math.max(1,Math.floor(width/250))
            cellWidth:width/columns;cellHeight:cellWidth*.62+58
            model:s.windows;cacheBuffer:0
            ScrollBar.vertical:ScrollBar {}
            delegate:Item {
                id:cell
                required property var modelData
                readonly property var app:Hub.appForWindow(modelData)
                width:grid.cellWidth;height:grid.cellHeight
                Preview {id:shot;x:8;y:8;width:parent.width-16;height:width*.62;entry:cell.modelData;radius:18;opacity:Hub.minimized(cell.modelData) ? .5 : 1}
                Rectangle {visible:Hub.active(cell.modelData);anchors.fill:shot;anchors.margins:-4;radius:22;color:"transparent";border.width:3;border.color:Theme.primary}
                Row {
                    x:10;y:shot.y+shot.height+10;width:parent.width-20;spacing:8
                    Image {width:22;height:22;sourceSize:Qt.size(44,44);source:Quickshell.iconPath(cell.app ? cell.app.icon : "application-x-executable",true)}
                    MText {width:parent.width-30;text:cell.modelData.title||(cell.app ? cell.app.name : "");role:"label";anchors.verticalCenter:parent.verticalCenter}
                }
                MouseArea {id:hover;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton
                    onClicked:e=>{if(e.button===Qt.RightButton)menu.popup(e.x,e.y);else if(e.button===Qt.MiddleButton)Hub.closeWindow(cell.modelData);else Hub.focusWindow(cell.modelData);}
                    onPressAndHold:e=>menu.popup(e.x,e.y)}
                MButton {visible:hover.containsMouse;x:shot.x+shot.width-width-8;y:shot.y+8;icon:"close";contained:true;compact:true;implicitWidth:34;implicitHeight:34;tooltip:"Close "+cell.modelData.title;onClicked:Hub.closeWindow(cell.modelData)}
                OpalMenu {id:menu;entries:Hub.windowMenu(cell.modelData)}
                activeFocusOnTab:true
                Keys.onReturnPressed:Hub.focusWindow(modelData)
                Accessible.role:Accessible.Button;Accessible.name:modelData.title;Accessible.onPressAction:Hub.focusWindow(modelData)
            }
        }
        MText {anchors.centerIn:parent;visible:s.windows.length===0;text:"Nothing open yet.";color:Theme.subtext}
    }}
}
