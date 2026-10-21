import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
// Opal's file chooser for apps' Open and Save dialogs (opal_portal.py). Touch first: places as chips, tiles with real thumbnails, long-press to select several.
Rectangle {
    id:picker
    property bool touch:true
    readonly property var request:Hub.portalRequest || ({})
    readonly property var folder:Hub.portalFolder || ({entries:[],crumbs:[]})
    readonly property bool saving:request.kind==="save"||request.kind==="savefiles"
    readonly property bool directory:!!request.directory||request.kind==="savefiles"
    property bool showRecent:false
    property bool grid:Hub.prefs.portalView!=="list"
    property bool hidden:false
    property string query:""
    property string sort:"name"
    property int filterIndex:request.filter===undefined ? -1 : request.filter
    property var selected:[]
    property bool selecting:false
    property string confirmReplace:""
    readonly property var rule:filterIndex>=0&&request.filters&&request.filters[filterIndex] ? request.filters[filterIndex] : null
    readonly property var source:showRecent ? Hub.portalRecent : (folder.entries||[])
    readonly property var entries:{
        const q=query.trim().toLowerCase();
        const list=source.filter(e=>!q||e.name.toLowerCase().indexOf(q)>=0);
        const by=sort==="recent" ? (a,b)=>b.modified-a.modified : sort==="size" ? (a,b)=>b.size-a.size : null;
        if(by)list.sort((a,b)=>a.dir!==b.dir ? (a.dir ? -1 : 1) : by(a,b));
        return list;
    }
    readonly property string acceptLabel:request.accept ? request.accept.replace(/_/g,"") : saving ? "Save" : directory ? "Select folder" : selected.length>1 ? "Open "+selected.length : "Open"
    color:Theme.base
    radius:touch ? 0 : 32
    clip:true
    focus:true

    function browse(uri) { showRecent=false;selected=[];query="";Hub.command({action:"portal-browse",folder:uri,hidden:hidden,rule:rule,directories:directory}); }
    function reload() { browse(folder.folder||request.folder||""); }
    function size(bytes) { const u=["B","KB","MB","GB","TB"];let i=0,n=bytes;while(n>=1024&&i<4){n/=1024;i++;} return (i ? n.toFixed(n<10 ? 1 : 0) : n)+" "+u[i]; }
    function date(seconds) { const d=new Date(seconds*1000),now=new Date();return d.toDateString()===now.toDateString() ? Qt.formatTime(d,"hh:mm") : Qt.formatDate(d,d.getFullYear()===now.getFullYear() ? "d MMM" : "d MMM yyyy"); }
    function glyph(kind) { return ({folder:"folder",image:"image",video:"movie",audio:"music_note",archive:"folder_zip",document:"description",code:"code"})[kind]||"draft"; }
    function isSelected(uri) { return selected.indexOf(uri)>=0; }
    function activate(entry) {
        if(entry.dir) { browse(entry.uri);return; }
        if(saving) { nameField.text=entry.name;return; }
        if(directory) return;
        if(request.multiple&&(selecting||selected.length>0)) { toggle(entry.uri);return; }
        if(isSelected(entry.uri)) { accept();return; }
        selected=[entry.uri];
    }
    function toggle(uri) { const next=selected.slice();const i=next.indexOf(uri);if(i>=0)next.splice(i,1);else next.push(uri);selected=next;selecting=next.length>0; }
    function hold(entry) { if(entry.dir||!request.multiple||saving)return;selecting=true;toggle(entry.uri); }
    function accept() {
        if(saving&&request.kind==="save") { Hub.command({action:"portal-check",folder:folder.folder,name:nameField.text});return; }
        if(saving||directory) { Hub.portalAnswer({uris:[folder.folder],filter:filterIndex});return; }
        if(selected.length) Hub.portalAnswer({uris:selected,filter:filterIndex});
    }
    Connections {
        target:Hub
        function onPortalSaveCheckChanged() {
            const c=Hub.portalSaveCheck;
            if(!c)return;
            if(c.exists&&picker.confirmReplace!==c.uri) picker.confirmReplace=c.uri;
            else Hub.portalAnswer({uris:[c.uri],filter:picker.filterIndex});
        }
    }
    Component.onCompleted:{
        Hub.command({action:"portal-places",rule:rule,directories:directory});
        browse(request.folder||(request.file ? request.file.replace(/\/[^\/]*$/,"") : ""));
        if(saving) nameField.text=request.name||(request.file ? request.file.replace(/.*\//,"") : "");
        if(saving) nameField.forceActiveFocus(); else picker.forceActiveFocus();
        if(saving) { const dot=nameField.text.lastIndexOf(".");nameField.select(0,dot>0 ? dot : nameField.text.length); }
    }
    Keys.onEscapePressed:Hub.portalAnswer({cancel:true})
    Keys.onReturnPressed:accept()
    Keys.onPressed:e=>{ if(e.key===Qt.Key_Backspace&&!searchField.activeFocus&&!nameField.activeFocus&&folder.parent) { browse(folder.parent);e.accepted=true; } }

    ColumnLayout {
        anchors.fill:parent
        anchors.margins:picker.touch ? 0 : 8
        spacing:0
        // Top app bar.
        RowLayout {
            Layout.fillWidth:true;Layout.preferredHeight:64;Layout.leftMargin:8;Layout.rightMargin:12;spacing:6
            MButton {icon:picker.selecting ? "close" : "close";tooltip:picker.selecting ? "Clear selection" : "Cancel";onClicked:if(picker.selecting){picker.selected=[];picker.selecting=false;} else Hub.portalAnswer({cancel:true})}
            ColumnLayout {Layout.fillWidth:true;spacing:0
                MText {Layout.fillWidth:true;role:"title";text:picker.selecting ? picker.selected.length+" selected" : picker.request.title||"Open"}
                MText {Layout.fillWidth:true;role:"labelS";color:Theme.subtext;visible:!picker.selecting&&!!picker.request.app;text:picker.request.app}
            }
            MButton {icon:picker.grid ? "view_list" : "grid_view";tooltip:picker.grid ? "List" : "Grid";onClicked:Hub.set("portalView",picker.grid ? "list" : "grid")}
            MButton {icon:picker.hidden ? "visibility" : "visibility_off";tooltip:picker.hidden ? "Hide hidden files" : "Show hidden files";onClicked:{picker.hidden=!picker.hidden;picker.reload();}}
            MButton {visible:(picker.saving||picker.directory)&&picker.folder.writable===true;icon:"create_new_folder";tooltip:"New folder";onClicked:{newFolder.visible=true;newFolderField.text="";newFolderField.forceActiveFocus();}}
            MButton {visible:!picker.saving;filled:true;text:picker.acceptLabel;enabled:picker.directory||picker.selected.length>0;onClicked:picker.accept()}
        }
        // Places: recent files, the user's folders, bookmarks and drives.
        ListView {
            Layout.fillWidth:true;Layout.preferredHeight:40;Layout.leftMargin:12;Layout.rightMargin:12
            orientation:ListView.Horizontal;spacing:6;clip:true;boundsBehavior:Flickable.StopAtBounds
            model:(picker.directory ? [] : [{name:"Recent",icon:"history",recent:true}]).concat(Hub.portalPlaces)
            delegate:Chip {
                required property var modelData
                text:modelData.name;icon:modelData.icon
                selected:modelData.recent ? picker.showRecent : !picker.showRecent&&picker.folder.folder===modelData.uri
                onClicked:if(modelData.recent){picker.showRecent=true;picker.selected=[];} else picker.browse(modelData.uri)
            }
        }
        // Where you are: each folder on the path is a chip.
        RowLayout {
            Layout.fillWidth:true;Layout.topMargin:8;Layout.leftMargin:12;Layout.rightMargin:12;spacing:6
            visible:!picker.showRecent
            MButton {compact:true;icon:"arrow_upward";enabled:!!picker.folder.parent;tooltip:"Up";onClicked:picker.browse(picker.folder.parent)}
            ListView {
                id:crumbs
                Layout.fillWidth:true;Layout.preferredHeight:32
                orientation:ListView.Horizontal;spacing:2;clip:true;boundsBehavior:Flickable.StopAtBounds
                model:picker.folder.crumbs||[]
                onCountChanged:Qt.callLater(positionViewAtEnd)
                delegate:Row {
                    required property var modelData
                    required property int index
                    spacing:2
                    Glyph {visible:index>0;name:"chevron_right";font.pixelSize:16;color:Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                    Chip {glass:false;text:modelData.name;selected:index===crumbs.count-1;onClicked:picker.browse(modelData.uri)}
                }
            }
        }
        // Search, sort and the app's file type filters.
        Flow {
            Layout.fillWidth:true;Layout.topMargin:8;Layout.leftMargin:12;Layout.rightMargin:12;spacing:6
            Rectangle {
                width:Math.min(260,parent.width);height:36;radius:18;color:Theme.level(2)
                Glyph {x:10;anchors.verticalCenter:parent.verticalCenter;name:"search";font.pixelSize:18;color:Theme.subtext}
                TextInput {
                    id:searchField
                    anchors.fill:parent;anchors.leftMargin:36;anchors.rightMargin:12;verticalAlignment:TextInput.AlignVCenter
                    color:Theme.text;font.family:Theme.font;font.pixelSize:14;clip:true
                    onTextChanged:picker.query=text
                    MText {anchors.verticalCenter:parent.verticalCenter;visible:!parent.text&&!parent.activeFocus;text:picker.showRecent ? "Search recent files" : "Search this folder";color:Theme.subtext}
                }
            }
            Repeater {model:[{id:"name",icon:"sort_by_alpha",text:"Name"},{id:"recent",icon:"schedule",text:"Newest"},{id:"size",icon:"straighten",text:"Largest"}]
                Chip {required property var modelData;icon:modelData.icon;text:modelData.text;selected:picker.sort===modelData.id;onClicked:picker.sort=modelData.id}
            }
            Repeater {model:picker.request.filters||[]
                Chip {required property var modelData;required property int index;glass:false;icon:"filter_list";text:modelData.name;selected:picker.filterIndex===index
                    onClicked:{picker.filterIndex=index;Hub.command({action:"portal-places",rule:picker.rule,directories:picker.directory});picker.reload();}}
            }
        }
        MText {
            Layout.fillWidth:true;Layout.leftMargin:16;Layout.topMargin:6;visible:Hub.portalError!==""
            text:Hub.portalError;color:Theme.error;role:"bodyS";wrapMode:Text.Wrap
        }
        // New folder, inline.
        Rectangle {
            id:newFolder
            visible:false
            Layout.fillWidth:true;Layout.preferredHeight:52;Layout.margins:12;radius:26;color:Theme.secondaryContainer
            RowLayout {anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:6;spacing:8
                Glyph {name:"create_new_folder";color:Theme.onSecondaryContainer}
                TextInput {id:newFolderField;Layout.fillWidth:true;color:Theme.onSecondaryContainer;font.family:Theme.font;font.pixelSize:15;clip:true
                    onAccepted:createButton.clicked()
                    Keys.onEscapePressed:newFolder.visible=false}
                MButton {id:createButton;filled:true;text:"Create";enabled:newFolderField.text.trim()!=="";onClicked:{Hub.command({action:"portal-mkdir",folder:picker.folder.folder,name:newFolderField.text,hidden:picker.hidden,rule:picker.rule,directories:picker.directory});newFolder.visible=false;}}
            }
        }
        // The files.
        GridView {
            id:files
            Layout.fillWidth:true;Layout.fillHeight:true;Layout.topMargin:10
            clip:true;boundsBehavior:Flickable.StopAtBounds
            readonly property int columns:picker.grid ? Math.max(2,Math.floor((width-16)/(picker.touch ? 116 : 132))) : 1
            leftMargin:8;rightMargin:8;bottomMargin:16
            cellWidth:Math.floor((width-16)/columns);cellHeight:picker.grid ? cellWidth+38 : 60
            model:picker.entries
            ScrollBar.vertical:ScrollBar {}
            delegate:Item {
                id:tile
                required property var modelData
                readonly property bool chosen:picker.isSelected(modelData.uri)
                readonly property bool dim:picker.saving&&!modelData.dir
                width:files.cellWidth;height:files.cellHeight
                opacity:dim ? .55 : 1
                Rectangle {
                    anchors.fill:parent;anchors.margins:4;radius:tile.chosen ? 28 : 18
                    color:tile.chosen ? Theme.secondaryContainer : mouse.containsMouse ? Theme.level(2) : "transparent"
                    Behavior on radius {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized}}
                    Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durShort)}}
                }
                // Grid: a thumbnail or a tonal icon well, with the name under it.
                Item {
                    visible:picker.grid
                    anchors.fill:parent;anchors.margins:10
                    Rectangle {
                        id:well
                        width:parent.width;height:width;radius:tile.chosen ? width/2.6 : 16;clip:true
                        color:tile.modelData.dir ? Theme.primaryContainer : Theme.level(3)
                        Behavior on radius {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized}}
                        Glyph {anchors.centerIn:parent;visible:thumb.status!==Image.Ready;name:picker.glyph(tile.modelData.kind);font.pixelSize:parent.width*.4;color:tile.modelData.dir ? Theme.onContainer : Theme.subtext}
                        Image {
                            id:thumb
                            anchors.fill:parent
                            visible:status===Image.Ready
                            source:tile.modelData.kind==="image"&&picker.grid&&tile.modelData.size<64*1024*1024 ? tile.modelData.uri : ""
                            sourceSize:Qt.size(220,220);asynchronous:true;cache:true;fillMode:Image.PreserveAspectCrop
                        }
                    }
                    MText {anchors {top:well.bottom;topMargin:6;left:parent.left;right:parent.right} text:tile.modelData.name;horizontalAlignment:Text.AlignHCenter;role:"labelS";elide:Text.ElideMiddle}
                }
                // List: icon, name, then size and date.
                RowLayout {
                    visible:!picker.grid
                    anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:16;spacing:14
                    Rectangle {Layout.preferredWidth:40;Layout.preferredHeight:40;radius:tile.chosen ? 20 : 12;color:tile.modelData.dir ? Theme.primaryContainer : Theme.level(3);clip:true
                        Glyph {anchors.centerIn:parent;visible:listThumb.status!==Image.Ready;name:picker.glyph(tile.modelData.kind);font.pixelSize:20;color:tile.modelData.dir ? Theme.onContainer : Theme.subtext}
                        Image {id:listThumb;anchors.fill:parent;visible:status===Image.Ready;source:tile.modelData.kind==="image"&&!picker.grid&&tile.modelData.size<64*1024*1024 ? tile.modelData.uri : "";sourceSize:Qt.size(80,80);asynchronous:true;fillMode:Image.PreserveAspectCrop}
                    }
                    ColumnLayout {Layout.fillWidth:true;spacing:2
                        MText {Layout.fillWidth:true;text:tile.modelData.name;role:"body";elide:Text.ElideMiddle}
                        MText {Layout.fillWidth:true;role:"labelS";color:Theme.subtext
                            text:picker.showRecent ? tile.modelData.folder.replace(Quickshell.env("HOME"),"~")+" · "+picker.date(tile.modelData.modified) : tile.modelData.dir ? picker.date(tile.modelData.modified) : picker.size(tile.modelData.size)+" · "+picker.date(tile.modelData.modified)}
                    }
                }
                Flower {
                    visible:tile.chosen&&(picker.request.multiple||picker.grid)
                    width:26;height:26;x:parent.width-width-10;y:10;fill:Theme.primary;lobes:6
                    Glyph {anchors.centerIn:parent;name:"check";font.pixelSize:15;color:Theme.onPrimary}
                }
                MouseArea {
                    id:mouse
                    anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                    pressAndHoldInterval:420
                    onClicked:picker.activate(tile.modelData)
                    onDoubleClicked:if(!tile.modelData.dir&&!picker.saving&&!picker.directory){picker.selected=[tile.modelData.uri];picker.accept();}
                    onPressAndHold:picker.hold(tile.modelData)
                }
            }
            MText {
                anchors.centerIn:parent;width:parent.width-48;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap
                visible:files.count===0;color:Theme.subtext;role:"body"
                text:picker.query ? "Nothing here matches “"+picker.query+"”" : picker.showRecent ? "No recent files" : picker.directory ? "No folders inside" : "This folder is empty"
            }
        }
        // Save: the file name, and a replace check when it already exists.
        Rectangle {
            visible:picker.saving
            Layout.fillWidth:true;Layout.preferredHeight:picker.confirmReplace ? 132 : 76
            color:Theme.level(2);radius:picker.touch ? 0 : 24
            Behavior on Layout.preferredHeight {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized}}
            ColumnLayout {anchors.fill:parent;anchors.margins:12;spacing:8
                RowLayout {Layout.fillWidth:true;visible:!!picker.confirmReplace;spacing:8
                    Glyph {name:"warning";color:Theme.error}
                    MText {Layout.fillWidth:true;text:"“"+nameField.text+"” already exists here. Replace it?";role:"bodyS";wrapMode:Text.Wrap}
                    MButton {text:"Keep both";tonal:true;compact:true;onClicked:{const t=nameField.text,dot=t.lastIndexOf(".");nameField.text=dot>0 ? t.slice(0,dot)+" (2)"+t.slice(dot) : t+" (2)";picker.confirmReplace="";}}
                    MButton {text:"Replace";filled:true;compact:true;accent:Theme.error;onClicked:{const u=picker.confirmReplace;picker.confirmReplace="";Hub.portalAnswer({uris:[u],filter:picker.filterIndex});}}
                }
                RowLayout {Layout.fillWidth:true;spacing:10
                    Rectangle {Layout.fillWidth:true;Layout.preferredHeight:52;radius:26;color:Theme.level(4)
                        Glyph {x:16;anchors.verticalCenter:parent.verticalCenter;name:"edit";font.pixelSize:20;color:Theme.subtext}
                        TextInput {
                            id:nameField
                            anchors.fill:parent;anchors.leftMargin:46;anchors.rightMargin:18;verticalAlignment:TextInput.AlignVCenter
                            color:Theme.text;font.family:Theme.font;font.pixelSize:16;clip:true;selectByMouse:true
                            onTextChanged:picker.confirmReplace=""
                            onAccepted:picker.accept()
                        }
                    }
                    MButton {filled:true;icon:"save";text:picker.acceptLabel;enabled:picker.request.kind==="savefiles"||nameField.text.trim()!=="";onClicked:picker.accept()}
                }
            }
        }
    }
}
