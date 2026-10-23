import QtQuick
import Quickshell

// Phone and tablet recents: a carousel of screen-shaped cards, newest on the right and older apps to the left.
// It opens from the pose of the card the finger moved, so a swipe-up flows into it without a second animation. Tap a card to open it, swipe it up to close it.
Item {
    id:rc
    property var screenObj:null
    readonly property var slot:PhoneState.recentsSlot(screenObj)
    readonly property var inset:PhoneState.recentsInsets(screenObj)
    readonly property var list:Hub.recentWindows.filter(w=>!(w.workspaceName||"").startsWith("special:"))
    readonly property var from:PhoneState.recentsFrom||(PhoneState.activeWindow() ? {k:1,x:0,y:0,backdrop:0} : {k:slot.k*.92,x:0,y:slot.offset+48,backdrop:0,fade:true})
    readonly property var current:list[cards.currentIndex]||null
    // 0 is the start pose and 1 is the slot. Leaving towards an app runs "out" from 0 to 1.
    property real enter:0
    property real out:0
    property bool leaving:false
    // Hidden but rendered while the swipe runs; it shows when recents open.
    readonly property bool shown:PhoneState.recentsOpen
    opacity:shown ? 1 : 0
    enabled:shown
    function start() {leaving=false;out=0;cards.currentIndex=Math.max(0,list.findIndex(w=>Hub.active(w)));cards.positionViewAtIndex(cards.currentIndex,ListView.Center);enterAnim.restart();forceActiveFocus();}
    onShownChanged:if(shown)start();else enter=0
    Component.onCompleted:if(shown)start()
    NumberAnimation {id:enterAnim;target:rc;property:"enter";from:0;to:1;duration:Theme.motion(340);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}
    NumberAnimation {id:outAnim;target:rc;property:"out";from:0;to:1;duration:Theme.motion(300);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate;onFinished:PhoneState.closeRecents()}
    function lerp(a,b,t) {return a+(b-a)*t;}
    function open(w) {
        if(!w||leaving)return;
        leaving=true;
        Hub.focusWindow(w);
        outAnim.restart();
    }
    focus:true
    Keys.onPressed:event=>{
        if(event.key===Qt.Key_Left)cards.incrementCurrentIndex();
        else if(event.key===Qt.Key_Right)cards.decrementCurrentIndex();
        else if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter)rc.open(rc.current);
        else if(event.key===Qt.Key_Escape||event.key===Qt.Key_Back)PhoneState.closeRecents();
        else return;
        event.accepted=true;
    }

    // The same quiet wallpaper as the gesture, between the status and navigation bars.
    Item {
        y:rc.inset.top;width:parent.width;height:parent.height-rc.inset.top-rc.inset.bottom;clip:true
        opacity:rc.lerp(rc.from.backdrop,1,rc.enter)*(1-rc.out)
        PhoneBackdrop {y:-rc.inset.top;width:rc.width;height:rc.height;soft:1}
        Rectangle {anchors.fill:parent;color:Theme.alpha(Theme.base,.35)}
        // A tap on empty space goes home.
        MouseArea {anchors.fill:parent;onClicked:PhoneState.goHome()}
    }
    // The cards. The whole row carries the start pose, so the centre card begins exactly where the finger left it.
    Item {
        id:row
        anchors.fill:parent
        opacity:rc.from.fade ? rc.enter : 1
        transform:[
            Scale {
                origin.x:rc.slot.cx;origin.y:rc.slot.cy
                readonly property real s0:rc.from.k/rc.slot.k
                readonly property real s1:1/rc.slot.k
                xScale:rc.out>0 ? rc.lerp(1,s1,rc.out) : rc.lerp(s0,1,rc.enter);yScale:xScale
            },
            Translate {
                x:rc.lerp(rc.from.x,0,rc.enter)
                y:rc.out>0 ? rc.lerp(0,rc.height/2-rc.slot.cy,rc.out) : rc.lerp(rc.height/2+rc.from.y-rc.slot.cy,0,rc.enter)
            }
        ]
        ListView {
            id:cards
            x:0;y:rc.slot.cy-rc.slot.h/2;width:rc.width;height:rc.slot.h
            orientation:ListView.Horizontal;layoutDirection:Qt.RightToLeft
            spacing:rc.slot.gap;model:rc.list
            snapMode:ListView.SnapOneItem;highlightRangeMode:ListView.StrictlyEnforceRange
            preferredHighlightBegin:(width-rc.slot.w)/2;preferredHighlightEnd:(width+rc.slot.w)/2
            highlightMoveDuration:Theme.motion(320);boundsBehavior:Flickable.StopAtBounds
            maximumFlickVelocity:5000;flickDeceleration:2600
            interactive:!rc.leaving
            cacheBuffer:rc.width
            delegate:Item {
                id:cell
                required property var modelData
                required property int index
                readonly property bool isCurrent:ListView.isCurrentItem
                width:rc.slot.w;height:rc.slot.h
                // Swipe up to close: the card follows the finger and flies off past a third of its height.
                property real lift:0
                NumberAnimation {id:liftBack;target:cell;property:"lift";to:0;duration:Theme.motion(260);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}
                NumberAnimation {id:liftAway;target:cell;property:"lift";to:-rc.slot.h*1.3;duration:Theme.motion(220);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedAccelerate;onFinished:Hub.closeWindow(cell.modelData)}
                GestureCard {
                    entry:cell.modelData
                    width:rc.width;height:rc.height
                    x:(cell.width-width)/2;y:(cell.height-height)/2+cell.lift
                    scale:rc.slot.k;transformOrigin:Item.Center
                    radius:12+28*(1-rc.slot.k)
                    opacity:1-Math.min(.8,Math.abs(cell.lift)/rc.slot.h)
                }
                MouseArea {
                    anchors.fill:parent
                    property real startY:0
                    property real lastY:0
                    property real lastTime:0
                    property real vy:0
                    property bool dragging:false
                    preventStealing:dragging
                    onPressed:e=>{startY=e.y;lastY=e.y;lastTime=Date.now();vy=0;dragging=false;liftBack.stop();}
                    onPositionChanged:e=>{
                        const now=Date.now(),dt=Math.max(1,now-lastTime);
                        vy=vy*.6+(e.y-lastY)/dt*1000*.4;lastY=e.y;lastTime=now;
                        if(!dragging&&startY-e.y>14)dragging=true;
                        if(dragging)cell.lift=Math.min(0,e.y-startY);
                    }
                    onReleased:{
                        if(dragging){if(-cell.lift>rc.slot.h*.33||vy<-900)liftAway.restart();else liftBack.restart();dragging=false;return;}
                        if(cell.isCurrent)rc.open(cell.modelData);else cards.currentIndex=cell.index;
                    }
                    onCanceled:{if(dragging)liftBack.restart();dragging=false;}
                }
                Accessible.role:Accessible.Button;Accessible.name:modelData.title
            }
        }
    }
    MText {
        visible:rc.list.length===0;anchors.centerIn:parent;text:"No recent apps";role:"title";opacity:rc.enter
    }
    // App chip above the centre card, with the window menu.
    Rectangle {
        id:chip
        visible:!!rc.current
        readonly property var app:rc.current ? Hub.appForWindow(rc.current) : null
        anchors.horizontalCenter:parent.horizontalCenter;y:rc.slot.cy-rc.slot.h/2-height-12
        width:chipRow.implicitWidth+24;height:38;radius:19;color:Theme.fill(Theme.level(3),.94,"panels")
        opacity:Math.max(0,rc.enter*2-1)*(1-rc.out)*(cards.moving ? .0 : 1)
        Behavior on opacity {NumberAnimation {duration:Theme.motion(Theme.durShort)}}
        Row {
            id:chipRow;anchors.centerIn:parent;spacing:8
            Image {width:22;height:22;sourceSize:Qt.size(44,44);anchors.verticalCenter:parent.verticalCenter;source:Quickshell.iconPath(chip.app ? chip.app.icon : "application-x-executable",true)}
            MText {text:chip.app ? chip.app.name : rc.current ? String(rc.current.className||"App") : "";role:"label";anchors.verticalCenter:parent.verticalCenter}
            Glyph {name:"keyboard_arrow_down";font.pixelSize:18;color:Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
        }
        MouseArea {anchors.fill:parent;onClicked:menu.popup(0,chip.height+6)}
        OpalMenu {id:menu;entries:rc.current ? PhoneState.windowExtras(rc.screenObj,Hub.appForWindow(rc.current)).concat(Hub.windowMenu(rc.current)) : []}
    }
    // Actions for the carousel.
    FloatingToolbar {
        anchors.horizontalCenter:parent.horizontalCenter;y:rc.slot.cy+rc.slot.h/2+20
        opacity:Math.max(0,rc.enter*2-1)*(1-rc.out)
        visible:rc.list.length>0
        items:[{id:"shot",icon:"screenshot_monitor",text:"Screenshot"}]
            .concat(!PhoneState.isTablet(rc.screenObj)&&rc.list.length>1 ? [{id:"split",icon:"splitscreen",text:"Split"}] : [])
            .concat([{id:"clear",icon:"delete_sweep",text:"Clear all"}])
        onTriggered:id=>{
            if(id==="shot"){PhoneState.closeRecents();Hub.screenShot();}
            else if(id==="split"){const a=rc.current,b=rc.list.find(w=>w!==a);if(a&&b&&rc.screenObj&&PhoneState.startSplit(rc.screenObj,b.address,a.address))PhoneState.closeRecents();}
            else if(id==="clear"){rc.list.forEach(w=>Hub.closeWindow(w));PhoneState.goHome();}
        }
    }
}
