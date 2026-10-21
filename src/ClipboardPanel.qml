import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ClipKind.js" as ClipKind

Item {
    id:cp
    property bool touchMode:false
    property bool keyboardOpen:false
    property bool confirmingClear:false
    property string filter:""
    property string kindFilter:"all"
    property string expandedId:""
    property string selectedId:""
    property real now:Date.now()
    property string toast:""
    onFilterChanged:if(searchField.text!==filter)searchField.text=filter
    readonly property string normalizedFilter:filter.toLowerCase().trim()
    readonly property var counts:ClipKind.counts(Hub.clipboardItems)
    // Filter chips: All and Pinned stay; a kind chip appears only when that kind is in the history.
    readonly property var chips:ClipKind.filters.filter(f=>f.id==="all"||f.id==="pinned"&&counts.pinned>0||counts[f.id]>0&&counts[f.id]<counts.all||f.id===kindFilter)
    readonly property var items: {
        const query=normalizedFilter;
        const source=Hub.clipboardItems;
        const pinned=[],rest=[];
        for(let index=0;index<source.length;index++) {
            const item=source[index];
            if(!ClipKind.matchesFilter(item,kindFilter)||!ClipKind.matchesQuery(item,query,Hub.appForClass))continue;
            (item.pinned ? pinned : rest).push(item);
        }
        return pinned.concat(rest);
    }
    readonly property bool grouped:{
        const seen={};
        for(const item of items)seen[ClipKind.group(item,now)]=true;
        return Object.keys(seen).length>1;
    }
    readonly property var current:items.length ? items[Math.max(0,Math.min(clipList.currentIndex,items.length-1))] : null
    function select(index) {
        if(!items.length)return;
        clipList.currentIndex=Math.max(0,Math.min(items.length-1,index));
        selectedId=items[clipList.currentIndex].id;
        clipList.positionViewAtIndex(clipList.currentIndex,ListView.Contain);
    }
    function copySelected() {if(current)Hub.copyClipboard(current.id,true);}
    function copyNth(n) {if(n<items.length)Hub.copyClipboard(items[n].id,true);}
    function toggleExpand(id) {expandedId=expandedId===id ? "" : id;}
    function togglePinSelected() {if(current)Hub.pinClipboard(current.id,!current.pinned);}
    function removeSelected() {if(current)Hub.deleteClipboard(current.id);}
    function cycleFilter(step) {
        const ids=chips.map(c=>c.id);
        kindFilter=ids[(Math.max(0,ids.indexOf(kindFilter))+step+ids.length)%ids.length];
        select(0);
    }
    function back() {
        if(confirmingClear)confirmingClear=false;
        else if(expandedId!=="")expandedId="";
        else if(filter!==""||kindFilter!=="all"){filter="";kindFilter="all";}
        else Hub.close();
    }
    // The selection follows its clip when the list changes, for example after a pin or a new copy.
    onItemsChanged:{
        const keep=items.findIndex(i=>i.id===selectedId);
        clipList.currentIndex=keep>=0 ? keep : Math.max(0,Math.min(clipList.currentIndex,items.length-1));
        if(items.length)selectedId=items[clipList.currentIndex].id;
        if(expandedId!==""&&!items.some(i=>i.id===expandedId))expandedId="";
    }
    onChipsChanged:if(!chips.some(c=>c.id===kindFilter))kindFilter="all"
    Timer {interval:30000;running:cp.visible;repeat:true;onTriggered:cp.now=Date.now()}
    Connections {
        target:Hub
        function onClipboardCopiedSignal(id,success) {if(!success){cp.toast="Could not copy. Is wl-clipboard installed?";toastTimer.restart();}}
    }
    Timer {id:toastTimer;interval:2600;onTriggered:cp.toast=""}

    ColumnLayout {
        anchors {fill:parent;margins:20}
        spacing:12
        RowLayout {Layout.fillWidth:true;spacing:12
            Flower {Layout.preferredWidth:44;Layout.preferredHeight:44;fill:Hub.clipboardPaused ? Theme.tertiary : Theme.primary;lobes:8;Glyph {anchors.centerIn:parent;name:Hub.clipboardPaused ? "pause" : "clipboard";color:Theme.onPrimary;font.pixelSize:22}}
            ColumnLayout {Layout.fillWidth:true;spacing:2
                MText {text:"Clipboard";font.pixelSize:24;font.weight:Font.DemiBold;Layout.fillWidth:true}
                MText {
                    Layout.fillWidth:true;color:Theme.subtext;font.pixelSize:11
                    text:(Hub.clipboardItems.length===1 ? "1 clip" : Hub.clipboardItems.length+" clips")
                        +(cp.counts.pinned ? "  ·  "+cp.counts.pinned+" pinned" : "")+"  ·  this session only"
                }
            }
            MButton {
                icon:Hub.clipboardPaused ? "play" : "pause";compact:true;implicitWidth:40;implicitHeight:40
                tonal:Hub.clipboardPaused
                tooltip:Hub.clipboardPaused ? "Resume history" : "Pause history (private copying)"
                onClicked:Hub.pauseClipboard()
            }
            MButton {icon:"close";compact:true;implicitWidth:40;implicitHeight:40;tooltip:"Close · Escape";onClicked:Hub.close()}
        }
        // State banner: only when history is paused or unavailable.
        Rectangle {
            visible:Hub.clipboardPaused||!Hub.clipboardAvailable
            Layout.fillWidth:true;Layout.preferredHeight:visible ? 44 : 0;radius:22
            color:Hub.clipboardPaused ? Theme.tertiaryContainer : Theme.alpha(Theme.error,.14)
            RowLayout {anchors {fill:parent;leftMargin:16;rightMargin:6}spacing:10
                Glyph {name:Hub.clipboardPaused ? "visibility_off" : "error";font.pixelSize:18;color:Hub.clipboardPaused ? Theme.onTertiaryContainer : Theme.error}
                MText {Layout.fillWidth:true;text:Hub.clipboardPaused ? "Paused. New copies are not kept." : Hub.clipboardDetail;font.pixelSize:12;color:Hub.clipboardPaused ? Theme.onTertiaryContainer : Theme.text}
                MButton {visible:Hub.clipboardPaused;text:"Resume";compact:true;implicitHeight:32;ink:Theme.onTertiaryContainer;onClicked:Hub.pauseClipboard()}
            }
        }
        Rectangle {Layout.fillWidth:true;Layout.preferredHeight:48;radius:24;color:Theme.surfaceHigh
            border.width:searchField.activeFocus ? 2 : 0;border.color:Theme.alpha(Theme.primary,.7)
            Glyph {x:16;anchors.verticalCenter:parent.verticalCenter;name:"search";color:Theme.subtext;font.pixelSize:20}
            TextField {
                id:searchField;anchors {fill:parent;leftMargin:46;rightMargin:44}
                background:Item {}
                placeholderText:Hub.clipboardItems.length ? "Search "+Hub.clipboardItems.length+" clips, links and apps" : "Find something you copied…"
                color:Theme.text;placeholderTextColor:Theme.muted
                font.family:Theme.font;font.pixelSize:14;selectByMouse:true
                onTextEdited:{cp.filter=text;cp.select(0);}
                onActiveFocusChanged:if(activeFocus&&cp.touchMode)cp.keyboardOpen=true
                onAccepted:cp.copySelected()
                // The field keeps focus: arrows, Tab and shortcuts act on the list.
                Keys.onPressed:e=>{
                    const ctrl=e.modifiers&Qt.ControlModifier,alt=e.modifiers&Qt.AltModifier;
                    if(e.key===Qt.Key_Down){cp.select(clipList.currentIndex+1);e.accepted=true;}
                    else if(e.key===Qt.Key_Up){cp.select(clipList.currentIndex-1);e.accepted=true;}
                    else if(e.key===Qt.Key_PageDown){cp.select(clipList.currentIndex+5);e.accepted=true;}
                    else if(e.key===Qt.Key_PageUp){cp.select(clipList.currentIndex-5);e.accepted=true;}
                    else if(e.key===Qt.Key_Tab||e.key===Qt.Key_Backtab){if(cp.current)cp.toggleExpand(cp.current.id);e.accepted=true;}
                    else if(ctrl&&e.key===Qt.Key_P){cp.togglePinSelected();e.accepted=true;}
                    else if(e.key===Qt.Key_Delete&&(ctrl||searchField.text==="")){cp.removeSelected();e.accepted=true;}
                    else if(alt&&(e.key===Qt.Key_Left||e.key===Qt.Key_Right)){cp.cycleFilter(e.key===Qt.Key_Right ? 1 : -1);e.accepted=true;}
                    else if(ctrl&&e.key>=Qt.Key_1&&e.key<=Qt.Key_9){cp.copyNth(e.key-Qt.Key_1);e.accepted=true;}
                    else if(e.key===Qt.Key_Escape){cp.back();e.accepted=true;}
                }
                Component.onCompleted:if(!cp.touchMode)forceActiveFocus()
            }
            MButton {visible:cp.filter!=="";anchors {right:parent.right;verticalCenter:parent.verticalCenter;rightMargin:6}
                icon:"close";compact:true;implicitWidth:34;implicitHeight:34;tooltip:"Clear search";onClicked:{cp.filter="";searchField.forceActiveFocus();}}
        }
        HorizontalScroller {
            visible:cp.chips.length>1
            Layout.fillWidth:true;Layout.preferredHeight:visible ? 34 : 0
            contentWidth:chipRow.implicitWidth
            Row {
                id:chipRow;spacing:6
                Repeater {
                    model:cp.chips
                    Chip {
                        required property var modelData
                        text:modelData.label+"  "+(cp.counts[modelData.id]||0)
                        icon:modelData.icon
                        selected:cp.kindFilter===modelData.id
                        glass:false
                        tooltip:"Show "+modelData.label.toLowerCase()+" · Alt+← →"
                        onClicked:{cp.kindFilter=modelData.id;cp.select(0);if(!cp.touchMode)searchField.forceActiveFocus();}
                    }
                }
            }
        }
        ListView {
            id:clipList;Layout.fillWidth:true;Layout.fillHeight:true
            clip:true;spacing:6;model:cp.items;currentIndex:0;boundsBehavior:Flickable.StopAtBounds
            highlightFollowsCurrentItem:false
            ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
            add:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:Theme.motion(180)}}
            displaced:Transition {NumberAnimation {properties:"y";duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
            delegate:ClipboardEntry {
                required property var modelData;required property int index
                width:clipList.width;record:modelData;now:cp.now
                selected:clipList.currentIndex===index&&!cp.touchMode
                touch:cp.touchMode
                shortcut:index+1
                expanded:cp.expandedId===modelData.id
                header:cp.grouped&&(index===0||ClipKind.group(cp.items[index-1],cp.now)!==ClipKind.group(modelData,cp.now)) ? ClipKind.group(modelData,cp.now) : ""
                onExpandRequested:{cp.select(index);cp.toggleExpand(modelData.id);}
            }
            Column {anchors.centerIn:parent;visible:cp.items.length===0;width:parent.width-40;spacing:14
                Flower {width:92;height:92;anchors.horizontalCenter:parent.horizontalCenter;fill:Theme.primaryContainer;lobes:10
                    Glyph {anchors.centerIn:parent;name:cp.filter ? "search" : cp.kindFilter==="pinned" ? "keep" : Hub.clipboardPaused ? "visibility_off" : "clipboard";font.pixelSize:36;color:Theme.onContainer}}
                MText {
                    width:parent.width;horizontalAlignment:Text.AlignHCenter;font.pixelSize:20;font.weight:Font.DemiBold;wrapMode:Text.Wrap
                    text:cp.filter ? "No matching clips" : cp.kindFilter==="pinned" ? "Nothing pinned" : Hub.clipboardPaused ? "A little privacy break" : "Nothing copied yet"
                }
                MText {
                    width:parent.width;wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;color:Theme.subtext;font.pixelSize:12
                    text:cp.filter ? "Try another word, a website or an app name." : cp.kindFilter==="pinned" ? "Pin the clips you use again and again.\nPins stay when you clear the history." : Hub.clipboardPaused ? "Resume when you want to collect again." : Hub.clipboardAvailable ? "Copy text or an image and it appears here.\nPress Super+V to open this again." : Hub.clipboardDetail
                }
            }
        }
        SearchKeyboard {visible:cp.touchMode&&cp.keyboardOpen&&!Hub.systemOskReady;Layout.fillWidth:true;Layout.preferredHeight:Math.min(implicitHeight,cp.height*.38)
            inputTarget:searchField;contextLabel:"Find clipboard text";returnLabel:"Done"
            onInsert:cp.filter=searchField.text
            onErase:cp.filter=searchField.text
            onAccept:{cp.keyboardOpen=false;searchField.focus=false;}
            onDismiss:{cp.keyboardOpen=false;searchField.focus=false;}
        }
        RowLayout {Layout.fillWidth:true;spacing:8
            Flow {
                visible:!cp.touchMode;Layout.fillWidth:true;spacing:10
                Repeater {
                    model:[["↵","Copy"],["Tab","Preview"],["Ctrl P","Pin"],["Del","Remove"]]
                    Row {required property var modelData;spacing:4
                        Rectangle {width:keyText.implicitWidth+10;height:18;radius:6;color:Theme.alpha(Theme.text,.08)
                            MText {id:keyText;anchors.centerIn:parent;text:modelData[0];font.pixelSize:9;font.weight:Font.Medium;color:Theme.subtext}}
                        MText {anchors.verticalCenter:parent.verticalCenter;text:modelData[1];font.pixelSize:10;color:Theme.muted}
                    }
                }
            }
            MText {visible:cp.touchMode;text:"Tap to copy · hold for actions";color:Theme.muted;font.pixelSize:10;Layout.fillWidth:true}
            MButton {text:"Clear";icon:"trash";compact:true;tonal:true;enabled:cp.counts.all>cp.counts.pinned;tooltip:"Clear history · pins stay";onClicked:cp.confirmingClear=true}
        }
    }
    // Error snackbar.
    Rectangle {
        visible:cp.toast!==""
        anchors {horizontalCenter:parent.horizontalCenter;bottom:parent.bottom;bottomMargin:70}
        width:Math.min(parent.width-40,toastText.implicitWidth+32);height:40;radius:20;color:Theme.text
        MText {id:toastText;anchors.centerIn:parent;text:cp.toast;color:Theme.base;font.pixelSize:12;font.weight:Font.Medium}
    }
    Rectangle {
        visible:cp.confirmingClear;anchors.fill:parent;radius:28;color:Theme.alpha(Theme.base,.98)
        MouseArea {anchors.fill:parent}
        ColumnLayout {anchors {left:parent.left;right:parent.right;verticalCenter:parent.verticalCenter;margins:28}
            spacing:14
            Glyph {name:"trash";font.pixelSize:42;color:Theme.tertiary;Layout.alignment:Qt.AlignHCenter}
            MText {text:"Clear the history?";Layout.fillWidth:true;wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;font.pixelSize:24;font.weight:Font.DemiBold}
            MText {
                text:(cp.counts.pinned ? cp.counts.pinned+(cp.counts.pinned===1 ? " pinned clip stays. " : " pinned clips stay. ") : "")+"What you copied last stays on the clipboard."
                Layout.fillWidth:true;wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;color:Theme.subtext;font.pixelSize:13
            }
            MButton {Layout.fillWidth:true;text:"Clear "+(cp.counts.all-cp.counts.pinned)+(cp.counts.all-cp.counts.pinned===1 ? " clip" : " clips");filled:true;onClicked:{Hub.clearClipboard(false);cp.confirmingClear=false;}}
            MButton {visible:cp.counts.pinned>0;Layout.fillWidth:true;text:"Also remove pins";ink:Theme.error;onClicked:{Hub.clearClipboard(true);cp.confirmingClear=false;}}
            MButton {Layout.fillWidth:true;text:"Keep them";tonal:true;onClicked:cp.confirmingClear=false}
        }
    }
}
