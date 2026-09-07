import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id:c
    property bool embedded:false
    property string category:"Games"
    property string query:""
    property bool searching:false
    property bool menuOpen:false
    property int menuIndex:0
    property int selection:0
    readonly property int columns:Math.max(2,Math.min(6,Math.floor((width-64)/260)))
    readonly property var tabs:["Continue","Games","Pinned","All apps"]
    readonly property var library:query!=="" ? Hub.searchApps(query,"All apps") : category==="Continue" ? Hub.recentApps.filter(a=>(a.categories||[]).indexOf("Game")>=0) : Hub.searchApps("",category)
    readonly property var selected:library.length ? library[Math.min(selection,library.length-1)] : null
    readonly property var selectedWindows:selected ? Hub.windows.filter(w=>Hub.appForWindow(w)===selected) : []
    readonly property var actions:(selected ? Hub.appMenu(selected) : []).concat([
        {text:"App switcher",icon:"desktop",run:()=>Hub.page="windows"},
        {text:"Steam Big Picture",icon:"game",run:()=>Hub.settings("steam")},
        {text:"Switch to desktop layout",icon:"desktop",run:()=>Hub.mode("desktop")},
        {text:"Close library",icon:"back",run:()=>Hub.close()}
    ])
    onLibraryChanged:selection=0
    function launch() {if(selectedWindows.length)Hub.focusWindow(selectedWindows[0]);else if(selected)Hub.launch(selected);}
    function changeTab(delta) {category=tabs[(tabs.indexOf(category)+delta+tabs.length)%tabs.length];query="";selection=0;}
    function searchToggle() {if(embedded){Hub.page="launcher";return;}searching=!searching;if(searching)search.forceActiveFocus();}
    function navigate(key) {
        if(menuOpen) {
            if(key==="back"||key==="menu")menuOpen=false;
            else if(key==="up") {menuIndex=Math.max(0,menuIndex-1);actionList.positionViewAtIndex(menuIndex,ListView.Contain);}
            else if(key==="down") {menuIndex=Math.min(actions.length-1,menuIndex+1);actionList.positionViewAtIndex(menuIndex,ListView.Contain);}
            else if(key==="accept") {const action=actions[menuIndex];menuOpen=false;if(action)action.run();}
            return;
        }
        if(searching&&key!=="search") {keyboard.navigation(key);return;}
        if(key==="search") {searchToggle();return;}
        if(key==="menu") {menuIndex=0;menuOpen=true;return;}
        if(key==="pin") {if(selected){Hub.pin(selected);Hub.message("Updated favorites");}return;}
        if(key==="back") {if(query){query="";return;}Hub.close();return;}
        if(key==="accept") {launch();return;}
        if(key==="previousTab") {changeTab(-1);return;}
        if(key==="nextTab") {changeTab(1);return;}
        const delta={left:-1,right:1,up:-columns,down:columns}[key];
        if(delta!==undefined) {selection=Math.max(0,Math.min(library.length-1,selection+delta));grid.positionViewAtIndex(selection,GridView.Contain);}
    }
    Connections {target:Hub;function onNavigate(key){if(!c.embedded&&Hub.page==="launcher"&&Hub.prefs.mode==="console")c.navigate(key);}}
    focus:!embedded
    Keys.onPressed:e=>{
        const map={}
map[Qt.Key_Left]="left";map[Qt.Key_Right]="right";map[Qt.Key_Up]="up";map[Qt.Key_Down]="down";map[Qt.Key_Return]="accept";map[Qt.Key_Enter]="accept";map[Qt.Key_Escape]="back";map[Qt.Key_Menu]="menu";
        if(map[e.key]){c.navigate(map[e.key]);e.accepted=true;}
        else if(e.key===Qt.Key_Tab){c.changeTab(e.modifiers&Qt.ShiftModifier ? -1 : 1);e.accepted=true;}
        else if(e.key===Qt.Key_F3){c.searchToggle();e.accepted=true;}
    }
    Component.onCompleted:if(!embedded)forceActiveFocus()
    ColumnLayout {
        anchors {fill:parent;margins:Math.min(width*.035,48)}
spacing:20
        RowLayout {
            visible:!c.searching
            Layout.fillWidth:true;spacing:14
            Flower {width:46;height:46;fill:Theme.primary;lobes:8;Glyph {anchors.centerIn:parent;name:"game";color:Theme.primaryText;font.pixelSize:24}}
            MText {visible:c.width>1000;text:"PLAY";font.pixelSize:20;font.weight:Font.Bold;font.letterSpacing:4;Layout.rightMargin:20}
            MButton {text:"LB";compact:true;tonal:true;tooltip:"Previous category";onClicked:c.changeTab(-1)}
            HorizontalScroller {Layout.fillWidth:true;Layout.preferredHeight:48;contentWidth:categoryRow.width
                Row {id:categoryRow;spacing:8
                    Repeater {model:c.tabs
                        MButton {required property string modelData;text:modelData;filled:c.category===modelData;onClicked:{c.category=modelData;c.query="";}}
                    }
                }
            }
            MButton {text:"RB";compact:true;tonal:true;tooltip:"Next category";onClicked:c.changeTab(1)}
            MText {visible:c.width>900;text:Qt.formatDateTime(Hub.now,"HH:mm");font.pixelSize:18;color:Theme.subtext}
            MButton {icon:"desktop";tooltip:"App switcher";onClicked:Hub.page="windows"}
            MButton {icon:"settings";tooltip:"Library actions · Menu / Select";onClicked:{c.menuIndex=0;c.menuOpen=true;}}
        }
        Rectangle {
            visible:!c.searching
            Layout.fillWidth:true;Layout.preferredHeight:Math.max(132,Math.min(168,c.height*.21));radius:30
            color:Theme.primaryContainer;clip:true
            Image {anchors {fill:parent;margins:12}
source:Hub.artFor(c.selected).hero||"";fillMode:Image.PreserveAspectCrop;opacity:.48;asynchronous:true}
            Rectangle {anchors {fill:parent;margins:12}
gradient:Gradient {orientation:Gradient.Horizontal;GradientStop {position:0;color:Theme.primaryContainer}GradientStop {position:1;color:Theme.alpha(Theme.primaryContainer,.15)}}}
            RowLayout {
                anchors {fill:parent;margins:c.height<700 ? 14 : 18}
spacing:16
                Rectangle {
                    Layout.preferredWidth:Math.min(96,parent.height-36);Layout.preferredHeight:width;radius:24;color:Theme.alpha(Theme.primary,.12)
                    Flower {anchors {fill:parent;margins:8}
fill:Theme.alpha(Theme.primary,.22);lobes:8;rotation:12}
                    Image {anchors.centerIn:parent;width:parent.width*.62;height:width;source:c.selected ? Quickshell.iconPath(c.selected.icon,true) : ""}
                    Glyph {visible:!c.selected;anchors.centerIn:parent;name:"game";font.pixelSize:60;color:Theme.primary}
                }
                ColumnLayout {
                    Layout.fillWidth:true;spacing:6
                    MText {text:c.selectedWindows.length ? "READY TO RESUME" : c.selected ? "READY TO LAUNCH" : "YOUR LOCAL LIBRARY";color:Theme.onContainer;font.pixelSize:11;font.letterSpacing:2}
                    MText {text:c.selected ? c.selected.name : c.category==="Continue" ? "Your next session starts here." : "Choose something to play.";Layout.fillWidth:true;font.pixelSize:Math.min(30,c.width/38);font.weight:Font.DemiBold;maximumLineCount:1;wrapMode:Text.Wrap;elide:Text.ElideRight;color:Theme.onContainer}
                    MText {visible:c.height>700;text:c.selected ? c.selected.comment||c.selected.genericName||"Installed on this device" : "Open Steam or choose All apps. No fake recommendations.";Layout.fillWidth:true;font.pixelSize:13;color:Theme.subtext}
                    RowLayout {spacing:10
                        MButton {visible:!!c.selected;text:c.selectedWindows.length ? "A  Resume" : "A  Launch";icon:"play";filled:true;onClicked:c.launch()}
                        MButton {visible:!!c.selected;text:Hub.pinned(c.selected||{}) ? "X  Unpin" : "X  Pin";icon:"pin";tonal:true;onClicked:Hub.pin(c.selected)}
                        MButton {text:"Steam Big Picture";icon:"game";tonal:true;onClicked:Hub.settings("steam")}
                    }
                }
            }
        }
        HorizontalScroller {visible:!c.searching;Layout.fillWidth:true;Layout.preferredHeight:56;contentWidth:sessionRow.implicitWidth
            RowLayout {id:sessionRow;height:52;spacing:10
                MButton {text:Hub.gameSession ? "End session · "+Hub.gameMinutes+"m" : "Start play session";icon:"game";filled:Hub.gameSession;tonal:true;tooltip:"Quiet popups, prevent idle and hide shelf; saved preferences stay untouched";onClicked:Hub.toggleGameSession()}
                MButton {text:"CPU "+Hub.status.cpu+"% · RAM "+Hub.status.memory+"%";icon:"cpu";tonal:true;onClicked:Hub.page="controls"}
                MButton {visible:Hub.status.profile!=="";text:Hub.status.profile;icon:"battery";tonal:true;tooltip:"Switch power profile";onClicked:Hub.command({action:"profile",value:Hub.status.profile==="performance" ? "balanced" : "performance"})}
                ExpressiveSlider {Layout.preferredWidth:190;value:Hub.status.volume;icon:"volume";onMoved:Hub.volume(value)}
                MButton {icon:"capture";text:"Screenshot";tonal:true;onClicked:Hub.screenShot()}
            }
        }
        RowLayout {visible:c.searching;Layout.fillWidth:true
            MText {text:"Find your next session";font.pixelSize:30;font.weight:Font.DemiBold;Layout.fillWidth:true}
            MButton {icon:"close";tooltip:"Return to library";onClicked:{c.searching=false;c.forceActiveFocus();}}
        }
        TextField {
            id:search;visible:c.searching||c.query!==""
            Layout.fillWidth:true;Layout.preferredHeight:56;leftPadding:22;rightPadding:22
            text:c.query;onTextEdited:c.query=text
            color:Theme.text;placeholderTextColor:Theme.muted;font.family:Theme.font;font.pixelSize:19
            placeholderText:"Search your installed apps and games"
            background:Rectangle {radius:28;color:Theme.surfaceHigh}
            onAccepted:{c.searching=false;c.forceActiveFocus();}
            Keys.onEscapePressed:{c.searching=false;c.forceActiveFocus();}
        }
        GridView {
            id:grid
            visible:!c.searching
            Layout.fillWidth:true;Layout.fillHeight:true
            clip:true;model:c.library
            cellWidth:width/c.columns;cellHeight:Math.max(120,Math.min(220,height/Math.max(1,Math.round(height/200))))
            ScrollBar.vertical:ScrollBar {}
            boundsBehavior:Flickable.StopAtBounds;currentIndex:c.selection
            delegate:Item {
                required property var modelData;required property int index
                width:grid.cellWidth;height:grid.cellHeight
                GameTile {anchors {fill:parent;margins:7}
                    app:modelData;selected:c.selection===index
                    onActivated:{if(c.selection===index)c.launch();else c.selection=index;}
                }
            }
            MText {anchors.centerIn:parent;visible:c.library.length===0;text:c.query ? "Nothing matched. Try another search." : c.category==="Pinned" ? "Press X on a title to add it here." : "No entries yet. Choose another category or open Steam.";color:Theme.subtext;font.pixelSize:20}
        }
        MText {visible:c.searching;text:c.library.length+" matches · Done to browse results";color:Theme.subtext;font.pixelSize:14}
        ColumnLayout {visible:c.searching;Layout.fillWidth:true;Layout.fillHeight:true;spacing:6
            Repeater {model:c.height>720 ? c.library.slice(0,3) : []
                MButton {required property var modelData;Layout.fillWidth:true;text:modelData.name;icon:"game";tonal:true;onClicked:{c.query=modelData.name;c.searching=false;c.forceActiveFocus();}}
            }
            Item {Layout.fillHeight:true}
        }
        SearchKeyboard {id:keyboard;visible:c.searching;Layout.fillWidth:true;Layout.preferredHeight:Math.min(320,c.height*.38);controllerMode:true
            onInsert:text=>c.query+=text
            onErase:c.query=c.query.slice(0,-1)
            onAccept:{c.searching=false;c.forceActiveFocus();}
            onDismiss:{c.searching=false;c.forceActiveFocus();}
        }
        RowLayout {
            visible:!c.searching
            Layout.fillWidth:true;spacing:14
            Glyph {name:"game";color:Hub.controller ? Theme.secondary : Theme.muted}
            MText {text:Hub.controller ? (Hub.controllerName||"Controller connected") : "Keyboard ready";color:Theme.subtext;font.pixelSize:12;Layout.maximumWidth:280}
            Item {Layout.fillWidth:true}
            MButton {text:"Y  Search";icon:"search";tonal:true;onClicked:c.searchToggle()}
            MButton {text:"Menu  Actions";tonal:true;onClicked:{c.menuIndex=0;c.menuOpen=true;}}
            MButton {visible:!c.embedded;text:"B  Back";icon:"back";onClicked:c.navigate("back")}
        }
    }
    Rectangle {
        visible:c.menuOpen;anchors.fill:parent;color:Theme.alpha(Theme.base,.97)
        MouseArea {anchors.fill:parent;onClicked:c.menuOpen=false}
        ColumnLayout {
            anchors.centerIn:parent;width:Math.min(parent.width-64,600);height:Math.min(parent.height-80,c.actions.length*60+120);spacing:8
            MText {text:"Library actions";font.pixelSize:30;font.weight:Font.DemiBold;Layout.bottomMargin:16}
            ListView {id:actionList;model:c.actions;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:8
                delegate:MButton {required property var modelData;required property int index;implicitWidth:ListView.view.width;implicitHeight:52;text:modelData.text;icon:modelData.icon;filled:index===c.menuIndex;tonal:index!==c.menuIndex;onClicked:{c.menuOpen=false;modelData.run();}}
            }
            MText {text:"↑ ↓ Choose · A / Enter Confirm · B / Escape Back";color:Theme.subtext;font.pixelSize:13;Layout.topMargin:14}
        }
    }
}
