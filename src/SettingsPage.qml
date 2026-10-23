import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// One Settings page: a scrolling column of groups. When search opened the page, it scrolls to the found row.
Flickable {
    id:page
    default property alias content:column.data
    contentHeight:column.implicitHeight+32;clip:true;boundsBehavior:Flickable.StopAtBounds
    ScrollBar.vertical:ScrollBar {}
    ColumnLayout {id:column;width:page.width;spacing:2}
    function findRow(item) {
        for(let i=0;i<item.children.length;i++){
            const c=item.children[i];
            if(c.found===true&&c.visible)return c;
            const deeper=findRow(c);
            if(deeper)return deeper;
        }
        return null;
    }
    function reveal() {
        if(Hub.settingsFound==="")return;
        const hit=findRow(column);
        if(!hit)return;
        const y=hit.mapToItem(column,0,0).y;
        scrollTo.to=Math.max(0,Math.min(contentHeight-height,y-height*.3));scrollTo.restart();
    }
    NumberAnimation {id:scrollTo;target:page;property:"contentY";duration:Theme.motion(Theme.durLong);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}
    Timer {id:revealSoon;interval:120;onTriggered:page.reveal()}
    Component.onCompleted:revealSoon.restart()
    Connections {target:Hub;function onSettingsFoundChanged() {revealSoon.restart();}}
}
