import QtQuick
import QtQuick.Effects
// Theme changes ripple out from the finger: a snapshot of the old look covers the window, and a growing circle wipes it away once the new colours arrive.
// One per window; Hub.withReveal finds the one in the caller's window.
Item {
    id:reveal
    parent:Window.contentItem
    anchors.fill:parent
    z:100000
    visible:false
    property real cx:0
    property real cy:0
    property real radius:0
    readonly property real reach:Math.hypot(Math.max(cx,width-cx),Math.max(cy,height-cy))+40
    property string before:""
    Component.onCompleted:Hub.revealers=Hub.revealers.concat([reveal])
    Component.onDestruction:Hub.revealers=Hub.revealers.filter(r=>r!==reveal)

    // Window root items made in C++ have no QML engine and cannot be grabbed. Try the caller's ancestors from the top down;
    // grabToImage returns false for an item it cannot grab.
    function run(item,x,y,apply) {
        if(Theme.reduceMotion||!Window.contentItem||grow.running||visible) { apply();return; }
        const chain=[];
        for(let a=item;a&&a!==Window.contentItem;a=a.parent)if(!String(a).startsWith("ProxyWindowContentItem"))chain.unshift(a);
        const p=item.mapToItem(Window.contentItem,x,y);
        for(const source of chain) {
            const at=source.mapToItem(Window.contentItem,0,0);
            const started=source.grabToImage(result=>{
                frame.x=at.x;frame.y=at.y;frame.width=source.width;frame.height=source.height;
                cx=p.x;cy=p.y;radius=0;
                snapshot.source=result.url;
                before=""+Theme.base+Theme.primary+Theme.light;
                visible=true;
                apply();
                giveUp.restart();
            });
            if(started)return;
        }
        // Nothing could be grabbed: the theme still applies, just without the ripple.
        apply();
    }
    // The new palette arrives from the backend a moment later; the wipe starts then.
    Connections {
        target:Theme
        enabled:reveal.visible&&!grow.running
        function onBaseChanged() {reveal.start();}
        function onPrimaryChanged() {reveal.start();}
    }
    function start() { if(""+Theme.base+Theme.primary+Theme.light!==before){giveUp.stop();grow.restart();} }
    Timer {id:giveUp;interval:1500;onTriggered:fade.restart()}
    NumberAnimation {
        id:grow;target:reveal;property:"radius";from:0;to:reveal.reach;duration:Theme.motion(720)
        easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized
        onFinished:reveal.finish()
    }
    NumberAnimation {id:fade;target:reveal;property:"opacity";to:0;duration:Theme.motion(200);onFinished:reveal.finish()}
    function finish() { visible=false;opacity=1;radius=0;snapshot.source=""; }

    // The old look covers the grabbed item; everything outside the circle still shows it.
    Item {
        id:frame
        Image {id:snapshot;anchors.fill:parent;visible:false;cache:false}
        Item {
            id:hole
            anchors.fill:parent;visible:false;layer.enabled:true
            Rectangle {x:reveal.cx-frame.x-reveal.radius;y:reveal.cy-frame.y-reveal.radius;width:reveal.radius*2;height:width;radius:reveal.radius;color:"black"}
        }
        MultiEffect {
            anchors.fill:parent;source:snapshot
            maskEnabled:true;maskSource:hole;maskInverted:true
            maskThresholdMin:.5;maskSpreadAtMin:.25
        }
        // The wavefront: a thin ring in the new accent that fades as it grows, kept inside the grabbed surface.
        Item {
            anchors.fill:parent;clip:true
            Rectangle {
                x:reveal.cx-frame.x-reveal.radius;y:reveal.cy-frame.y-reveal.radius;width:reveal.radius*2;height:width;radius:reveal.radius
                color:"transparent";border.width:3;border.color:Theme.primary
                opacity:grow.running ? 1-reveal.radius/reveal.reach : 0
            }
        }
    }
    MouseArea {anchors.fill:parent}
}
