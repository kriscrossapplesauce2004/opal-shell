import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "ClipKind.js" as ClipKind

// One clip. A row that grows into a preview card with actions; compact mode is a small tile for widgets.
Item {
    id:entry
    required property var record
    property bool selected:false
    property bool compact:false
    property bool touch:false
    property bool expanded:false
    property bool closeAfterCopy:true
    property int shortcut:-1
    property string header:""
    property real now:Date.now()
    signal expandRequested()
    readonly property string kind:record.kind||"Text"
    readonly property bool image:kind==="Image"
    readonly property bool code:kind==="Snippet"
    readonly property bool openable:kind==="Link"||kind==="Email"||kind==="Path"||image
    readonly property var swatch:kind==="Color" ? ClipKind.parseColor(record.text) : null
    readonly property bool hot:hit.containsMouse||selected
    readonly property string flat:ClipKind.oneLine(record.text)
    implicitHeight:compact ? 56 : (headerLabel.visible ? headerLabel.height+6 : 0)+card.height
    function copy() {if(entry.image||entry.record.text)Hub.copyClipboard(entry.record.id,entry.closeAfterCopy);}
    function togglePin() {Hub.pinClipboard(entry.record.id,!entry.record.pinned);}
    function menuEntries() {
        const out=[
            {text:"Copy",icon:"copy",quick:true,run:()=>entry.copy()},
            {text:entry.record.pinned ? "Unpin" : "Pin",icon:entry.record.pinned ? "keep_off" : "keep",quick:true,run:()=>entry.togglePin()},
            {text:"Remove",icon:"trash",quick:true,danger:true,run:()=>Hub.deleteClipboard(entry.record.id)}
        ];
        if(entry.openable)out.push({text:entry.kind==="Link" ? "Open link" : entry.kind==="Email" ? "Write an email" : entry.image ? "Open image" : "Open location",icon:"open_in_new",run:()=>Hub.openClipboard(entry.record.id)});
        if(!entry.image&&entry.flat!==entry.record.text)out.push({text:"Copy as one line",icon:"short_text",run:()=>Hub.copyClipboardText(entry.flat,entry.closeAfterCopy)});
        if(entry.swatch)ClipKind.notations(entry.swatch).forEach(n=>out.push({text:"Copy as "+n.label,icon:"palette",run:()=>Hub.copyClipboardText(n.value,entry.closeAfterCopy)}));
        if(!entry.compact)out.push({text:entry.expanded ? "Hide preview" : "Preview",icon:entry.expanded ? "unfold_less" : "unfold_more",run:()=>entry.expandRequested()});
        return out;
    }
    function showMenu(x,y) {
        const point=hit.mapToItem(entry,x,y);
        menuX=point.x;menuY=point.y;
        if(entryMenu.item){entryMenu.item.entries=menuEntries();entryMenu.item.popup(menuX,menuY);}
        else entryMenu.active=true;
    }
    property real menuX:0
    property real menuY:0
    Component {id:entryMenuComponent;OpalMenu {entries:entry.menuEntries()}}
    Loader {id:entryMenu;active:false;sourceComponent:entryMenuComponent;onLoaded:item.popup(entry.menuX,entry.menuY)}

    MText {
        id:headerLabel
        visible:entry.header!==""
        x:6;text:entry.header.toUpperCase();font.pixelSize:10;font.weight:Font.Bold;font.letterSpacing:1.4;color:Theme.subtext
    }
    Rectangle {
        id:card
        y:headerLabel.visible ? headerLabel.height+6 : 0
        width:parent.width
        height:entry.compact ? entry.height : body.implicitHeight+(entry.compact ? 16 : 20)
        radius:entry.compact ? 18 : 20
        color:entry.selected ? Theme.primaryContainer : hit.containsMouse ? Theme.surfaceHigh : Theme.alpha(Theme.surfaceHigh,.55)
        border.width:entry.expanded ? 1 : 0
        border.color:Theme.alpha(Theme.primary,.5)
        clip:true
        scale:hit.pressed ? .99 : 1
        Behavior on color {ColorAnimation {duration:Theme.motion(140)}}
        Behavior on height {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}}
        Behavior on scale {NumberAnimation {duration:Theme.motion(120)}}
        MouseArea {
            id:hit;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
            property bool held:false
            onPressed:held=false
            onClicked:e=>{if(held)return;if(e.button===Qt.RightButton)entry.showMenu(e.x,e.y);else entry.copy();}
            onPressAndHold:e=>{held=true;entry.showMenu(e.x,e.y);}
        }
        ColumnLayout {
            id:body
            anchors {left:parent.left;right:parent.right;top:parent.top;margins:entry.compact ? 8 : 10;leftMargin:entry.compact ? 10 : 12}
            spacing:10
            RowLayout {
                Layout.fillWidth:true;spacing:12
                ClipThumb {
                    record:entry.record;selected:entry.selected
                    Layout.preferredWidth:entry.image ? (entry.compact ? 52 : 64) : entry.compact ? 34 : 40
                    Layout.preferredHeight:entry.compact ? 34 : entry.image ? 48 : 40
                    Layout.alignment:entry.code&&!entry.compact ? Qt.AlignTop : Qt.AlignVCenter
                }
                ColumnLayout {
                    Layout.fillWidth:true;spacing:3
                    MText {
                        Layout.fillWidth:true
                        text:entry.image ? ClipKind.imageTitle(entry.record) : entry.code&&!entry.compact ? entry.record.text.replace(/^\s*\n/,"") : entry.flat
                        wrapMode:entry.code||entry.kind==="Text" ? Text.Wrap : Text.NoWrap
                        maximumLineCount:entry.compact ? 1 : entry.expanded ? 1 : entry.code ? 3 : entry.kind==="Text" ? 2 : 1
                        elide:entry.kind==="Path" ? Text.ElideMiddle : Text.ElideRight
                        font.pixelSize:entry.compact ? 12 : 13
                        font.family:entry.code||entry.kind==="Color"||entry.kind==="Path" ? "CaskaydiaCove Nerd Font" : Theme.font
                        color:entry.selected ? Theme.onContainer : Theme.text
                        visible:!(entry.expanded&&!entry.image)
                    }
                    MText {
                        visible:!entry.compact
                        Layout.fillWidth:true
                        text:ClipKind.meta(entry.record,entry.now,Hub.appForClass)
                        color:entry.selected ? Theme.alpha(Theme.onContainer,.75) : Theme.subtext
                        font.pixelSize:10
                    }
                }
                // Resting state: pin mark and the Ctrl+number shortcut. Hover and selection show the actions.
                Glyph {
                    visible:!!entry.record.pinned&&(!entry.hot||entry.compact)
                    name:"keep";font.pixelSize:16
                    color:entry.selected ? Theme.onContainer : Theme.primary
                }
                MText {
                    visible:!entry.touch&&!entry.compact&&!entry.hot&&entry.shortcut>0&&entry.shortcut<10
                    text:"^"+entry.shortcut;font.pixelSize:10;font.family:"CaskaydiaCove Nerd Font";color:Theme.muted
                    Layout.rightMargin:4
                }
                Row {
                    visible:!entry.compact&&(entry.hot||entry.touch)
                    spacing:0
                    MButton {visible:!entry.touch;icon:entry.record.pinned ? "keep_off" : "keep";compact:true;implicitWidth:34;implicitHeight:34;ink:entry.selected ? Theme.onContainer : Theme.text;tooltip:entry.record.pinned ? "Unpin · Ctrl+P" : "Pin · Ctrl+P";onClicked:entry.togglePin()}
                    MButton {icon:entry.expanded ? "unfold_less" : "unfold_more";compact:true;implicitWidth:34;implicitHeight:34;ink:entry.selected ? Theme.onContainer : Theme.text;tooltip:entry.expanded ? "Hide preview · Tab" : "Preview · Tab";onClicked:entry.expandRequested()}
                    MButton {visible:!entry.touch;icon:"trash";compact:true;implicitWidth:34;implicitHeight:34;ink:entry.selected ? Theme.onContainer : Theme.text;tooltip:"Remove · Delete";onClicked:Hub.deleteClipboard(entry.record.id)}
                }
                MButton {visible:entry.compact;icon:"copy";compact:true;implicitWidth:32;implicitHeight:32;tooltip:"Copy";onClicked:entry.copy()}
            }
            // Preview card: the full clip and every action for it.
            Loader {
                Layout.fillWidth:true
                active:entry.expanded&&!entry.compact
                visible:active
                sourceComponent:previewComponent
            }
        }
    }
    Component {
        id:previewComponent
        ColumnLayout {
            spacing:10
            Rectangle {
                visible:!entry.image&&!entry.swatch
                Layout.fillWidth:true
                Layout.preferredHeight:Math.min(220,fullText.implicitHeight+20)
                radius:14
                color:entry.selected ? Theme.alpha(Theme.base,.35) : Theme.alpha(Theme.base,.45)
                Flickable {
                    id:textScroll
                    anchors.fill:parent;anchors.margins:10
                    contentHeight:fullText.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                    interactive:contentHeight>height
                    ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                    // Read-only and selectable, so part of a clip can be copied too.
                    TextEdit {
                        id:fullText
                        width:textScroll.width-8
                        text:entry.record.text
                        readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;textFormat:TextEdit.PlainText
                        font.family:entry.code ? "CaskaydiaCove Nerd Font" : Theme.font
                        font.pixelSize:entry.code ? 12 : 13
                        color:entry.selected ? Theme.onContainer : Theme.text
                        selectionColor:Theme.alpha(Theme.primary,.4)
                        selectedTextColor:Theme.text
                    }
                }
            }
            Rectangle {
                visible:entry.image
                Layout.fillWidth:true
                Layout.preferredHeight:visible ? Math.min(240,Math.max(90,entry.record.width&&entry.record.height ? (width-12)*entry.record.height/entry.record.width+12 : full.status===Image.Ready ? width*full.implicitHeight/Math.max(1,full.implicitWidth) : 160)) : 0
                radius:14;color:Theme.alpha(Theme.base,.45);clip:true
                Image {
                    id:full
                    anchors.fill:parent;anchors.margins:6
                    source:entry.image&&entry.record.image ? "file://"+entry.record.image : ""
                    sourceSize.width:900
                    fillMode:Image.PreserveAspectFit;asynchronous:true;cache:false;smooth:true;mipmap:true
                }
            }
            RowLayout {
                visible:!!entry.swatch
                Layout.fillWidth:true;spacing:10
                Rectangle {
                    Layout.preferredWidth:84;Layout.preferredHeight:84;radius:18
                    color:entry.swatch ? Qt.rgba(entry.swatch.r/255,entry.swatch.g/255,entry.swatch.b/255,entry.swatch.a) : "transparent"
                    border.width:1;border.color:Theme.alpha(Theme.text,.18)
                }
                ColumnLayout {
                    Layout.fillWidth:true;spacing:6
                    Repeater {
                        model:entry.swatch ? ClipKind.notations(entry.swatch) : []
                        Chip {
                            required property var modelData
                            Layout.fillWidth:true;glass:false
                            text:modelData.label+"   "+modelData.value;icon:"copy"
                            tooltip:"Copy "+modelData.value
                            onClicked:Hub.copyClipboardText(modelData.value,entry.closeAfterCopy)
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth:true;spacing:6
                Chip {text:"Copy";icon:"copy";selected:true;onClicked:entry.copy()}
                Chip {visible:entry.openable;glass:false;text:entry.kind==="Link" ? "Open link" : entry.kind==="Email" ? "Email" : entry.image ? "Open" : "Show";icon:"open_in_new";onClicked:Hub.openClipboard(entry.record.id)}
                Chip {visible:!entry.image&&!entry.swatch&&entry.flat!==entry.record.text;glass:false;text:"One line";icon:"short_text";onClicked:Hub.copyClipboardText(entry.flat,entry.closeAfterCopy)}
                Chip {glass:false;text:entry.record.pinned ? "Unpin" : "Pin";icon:entry.record.pinned ? "keep_off" : "keep";onClicked:entry.togglePin()}
                Chip {glass:false;text:"Remove";icon:"trash";onClicked:Hub.deleteClipboard(entry.record.id)}
            }
        }
    }
    Accessible.role:Accessible.Button
    Accessible.name:(record.pinned ? "Pinned " : "")+"Copy "+ClipKind.info(record).label.toLowerCase()+": "+(image ? "image" : flat.substring(0,100))
    Accessible.onPressAction:copy()
}
