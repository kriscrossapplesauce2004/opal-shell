import QtQuick
import QtQuick.Layouts
// A labelled group of connected rows. The first and last visible rows round the group ends by themselves.
ColumnLayout {
    id:group
    property string title:""
    default property alias rows:body.data
    Layout.fillWidth:true
    spacing:2
    SettingsLabel {visible:group.title!=="";text:group.title}
    ColumnLayout {
        id:body
        Layout.fillWidth:true;spacing:2
        // Visibility hooks on the rows, removed again when the group goes away.
        property var hooks:[]
        function shape() {
            const shown=[];
            for(let i=0;i<children.length;i++){
                const c=children[i];
                if(c.first===undefined)continue;
                // Rows that show or hide later reshape the group.
                if(!c.groupWatched){c.groupWatched=true;const f=()=>reshape.restart();c.visibleChanged.connect(f);hooks.push({row:c,f:f});}
                if(c.visible)shown.push(c);
            }
            shown.forEach((c,i)=>{c.first=i===0;c.last=i===shown.length-1;});
        }
        onChildrenChanged:Qt.callLater(shape)
        Component.onCompleted:Qt.callLater(shape)
        Component.onDestruction:hooks.forEach(h=>{try{h.row.visibleChanged.disconnect(h.f);}catch(e){}})
        Timer {id:reshape;interval:0;onTriggered:body.shape()}
    }
}
