import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "StartSearch.js" as Search

FocusScope {
    id:menu
    // Rail selection: "pinned", "all" or a category name.
    property string section:"pinned"
    readonly property bool allApps:section!=="pinned"
    readonly property string appCategory:section==="all"||section==="pinned" ? "All apps" : section
    readonly property var rail:{
        const list=[{id:"pinned",name:"Pinned",icon:"keep"},{id:"all",name:"All apps",icon:"apps"},{id:"Games",name:"Games",icon:"sports_esports"},{id:"Create",name:"Create",icon:"brush"},{id:"Work",name:"Work",icon:"work"},{id:"Internet",name:"Internet",icon:"language"},{id:"System",name:"System",icon:"settings"}];
        if(Hub.hasAndroidApps||Hub.waydroid.installed)list.push({id:"Android",name:"Android",icon:"smartphone"});
        return list;
    }

    property string letter:""
    readonly property var library:Hub.searchApps("",appCategory).filter(app=>!letter||app.name.toUpperCase().startsWith(letter))
    property string scope:"all"
    property string confirmPower:""
    onConfirmPowerChanged:if(confirmPower!=="")Qt.callLater(()=>powerCancel.forceActiveFocus());else searchField.forceActiveFocus()
    // Result access for tests and controllers. The shared search owns the list and the selection.
    property alias selection:startSearch.selection
    readonly property var results:startSearch.flat.filter(r=>r.kind!=="web")
    readonly property var selected:startSearch.selected
    property alias searchField:searchField
    readonly property string query:Hub.query.trim()
    readonly property bool searching:query!==""
    readonly property int columns:width<520 ? 4 : width>=850 ? 8 : 6
    readonly property var actions:[
        {id:"settings",name:"Settings",detail:"All your device preferences in one place",icon:"settings",keywords:"configure phone taskbar accessibility"},
        {id:"controls",name:"Quick settings",detail:"Connectivity, sound and display",icon:"settings",keywords:"control center volume brightness wifi"},
        {id:"network",name:"Wi-Fi settings",detail:"Choose a network",icon:"wifi",keywords:"internet wireless network"},
        {id:"bluetooth",name:"Bluetooth settings",detail:"Pair and connect devices",icon:"bluetooth",keywords:"headphones pairing wireless"},
        {id:"appearance",name:"Wallpaper & style",detail:"Settings: colours, themes and the Look",icon:"palette",keywords:"theme dark light style personalize colors wallpaper omarchy"},
        {id:"wallpaper",name:"Change wallpaper",detail:"Choose a local image",icon:"palette",keywords:"background photo picture"},
        {id:"windows",name:"Running windows",detail:"Switch to an open application",icon:"desktop",keywords:"tasks switcher"},
        {id:"clipboard",name:"Clipboard history",detail:"Your session clipboard",icon:"clipboard",keywords:"copy paste text"},
        {id:"screenshot",name:"Take a screenshot",detail:"Capture your screen",icon:"capture",keywords:"screen image capture"},
        {id:"lock",name:"Lock device",detail:"Lock your current session",icon:"lock",keywords:"secure screen"},
        {id:"focus",name:"Start focus timer",detail:"25 minutes without distractions",icon:"timer",keywords:"pomodoro concentrate"},
        {id:"welcome",name:"Set up Opal",detail:Hub.aiEnabled!==false ? "Wi-Fi, look, layout, apps and Claude" : "Wi-Fi, look, layout and apps",icon:"auto_awesome",keywords:"setup onboarding welcome tour oobe first run"},
        {id:"android",name:"Android apps",detail:"Set up Android and get apps",icon:"android",keywords:"waydroid android apk play store fdroid apps install"}
    ]
    readonly property var recent:Hub.recentApps.slice(0,4)
    function move(delta) {startSearch.move(delta);}
    function goBack() {
        if(confirmPower!==""){confirmPower="";return;}
        if(searching){Hub.query="";scope="all";searchField.forceActiveFocus();}
        else if(allApps){section="pinned";searchField.forceActiveFocus();}
        else Hub.close();
    }
    function invoke(result, fresh) {
        if(!result)return;
        if(result.kind==="app"){if(fresh)Hub.launchNew(result.data);else Hub.launch(result.data);}
        else if(result.kind==="window")Hub.focusWindow(result.data);
        else {
            const id=result.data.id;
            if(id==="screenshot")Hub.openCapture();
            else if(id==="lock"||id==="network"||id==="bluetooth")Hub.settings(id);
            else if(id==="focus"){Hub.focusSeconds=25*60;Hub.focusRunning=true;Hub.close();}
            else if(id==="android")Hub.openAndroid();
            else Hub.page=id;
        }
    }
    function accept(fresh) {if(searching)startSearch.accept(fresh);}
    function focusApp(index) {
        const item=pinnedRepeater.itemAt(Math.max(0,Math.min(Hub.favoriteApps.length-1,index)));
        if(item){item.forceActiveFocus();home.contentY=Math.max(0,item.y-80);}
    }
    Connections {target:Hub;function onStartSearchRequestChanged(){searchField.forceActiveFocus();searchField.selectAll();}function onQueryChanged(){
        if(searchField.text!==Hub.query)searchField.text=Hub.query;
    }}
    Component.onCompleted:searchField.forceActiveFocus()
    Keys.onEscapePressed:event=>{goBack();event.accepted=true;}
    Keys.onPressed:event=>{
        if(confirmPower!=="")return;
        if(event.modifiers&Qt.ControlModifier&&event.key===Qt.Key_K){searchField.forceActiveFocus();searchField.selectAll();event.accepted=true;}
        else if(event.text&&!(event.modifiers&(Qt.ControlModifier|Qt.AltModifier|Qt.MetaModifier))&&!searchField.activeFocus&&event.key!==Qt.Key_Return&&event.key!==Qt.Key_Enter&&event.key!==Qt.Key_Tab){searchField.forceActiveFocus();Hub.query+=event.text;event.accepted=true;}
    }

    RowLayout {
        enabled:menu.confirmPower===""
        anchors.fill:parent;anchors.margins:12;spacing:12
    // Left rail: sections, then settings and session at the bottom.
    ColumnLayout {
        Layout.preferredWidth:164;Layout.minimumWidth:164;Layout.maximumWidth:164;Layout.fillWidth:false;Layout.fillHeight:true;spacing:2
        Repeater {model:menu.rail
            Rectangle {
                required property var modelData
                readonly property bool current:!menu.searching&&menu.section===modelData.id
                Layout.fillWidth:true;Layout.preferredHeight:44;radius:height/2
                color:current ? Theme.secondaryContainer : "transparent"
                Rectangle {anchors.fill:parent;radius:parent.radius;color:Theme.stateLayer;opacity:railMouse.pressed ? .12 : railMouse.containsMouse ? .06 : 0}
                Row {anchors.verticalCenter:parent.verticalCenter;x:14;spacing:12
                    Glyph {name:modelData.icon;font.pixelSize:20;color:parent.parent.current ? Theme.onSecondaryContainer : Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                    MText {text:modelData.name;role:"label";font.weight:parent.parent.current ? Font.DemiBold : Font.Medium;color:parent.parent.current ? Theme.onSecondaryContainer : Theme.text;anchors.verticalCenter:parent.verticalCenter}
                }
                MouseArea {id:railMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{Hub.query="";menu.section=modelData.id;menu.letter="";searchField.forceActiveFocus();}}
                Accessible.role:Accessible.Button;Accessible.name:modelData.name
            }
        }
        Item {Layout.fillHeight:true}
        RowLayout {Layout.fillWidth:true;spacing:0
            MButton {icon:"settings";compact:true;implicitWidth:40;ink:Theme.subtext;tooltip:"Settings";onClicked:Hub.openSettings()}
            MButton {icon:"folder";compact:true;implicitWidth:40;ink:Theme.subtext;tooltip:"Files";onClicked:Hub.settings("files")}
            MButton {icon:"lock";compact:true;implicitWidth:40;ink:Theme.subtext;tooltip:"Lock";onClicked:Hub.settings("lock")}
            MButton {icon:"power";compact:true;implicitWidth:40;ink:Theme.subtext;tooltip:"Power";onClicked:menu.confirmPower="menu"}
        }
    }
    ColumnLayout {
        Layout.fillWidth:true;Layout.fillHeight:true;spacing:12
        // Hero: greeting and clock in a bold colour block.
        Rectangle {
            visible:!menu.searching
            Layout.fillWidth:true;Layout.preferredHeight:112
            radius:Theme.shapeXl;color:Theme.primaryContainer
            ColumnLayout {anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;anchors.leftMargin:24;spacing:0
                MText {text:Hub.now.getHours()<12 ? "Good morning" : Hub.now.getHours()<18 ? "Good afternoon" : "Good evening";role:"headline";color:Theme.onContainer}
                MText {text:Qt.formatDateTime(Hub.now,"dddd d MMMM");role:"label";color:Theme.alpha(Theme.onContainer,.75)}
            }
            MText {visible:parent.width>=520;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.rightMargin:24;text:Qt.formatDateTime(Hub.now,"HH:mm");role:"displayM";font.features:{"tnum":1};color:Theme.onContainer}
        }
        Rectangle {
            Layout.fillWidth:true;Layout.preferredHeight:52;radius:26
            color:Theme.level(searchField.activeFocus ? 4 : 3)
            border.width:searchField.activeFocus ? 2 : 0;border.color:Theme.primary
            Behavior on color {ColorAnimation {duration:Theme.motion(160)}}
            Glyph {x:18;anchors.verticalCenter:parent.verticalCenter;name:"search";color:Theme.primary}
            TextField {
                id:searchField;anchors.fill:parent;anchors.leftMargin:48;anchors.rightMargin:46
                background:Item {}
                color:Theme.text;placeholderTextColor:Theme.subtext
                font.family:Theme.font;font.pixelSize:15;selectByMouse:true
                placeholderText:Hub.aiEnabled!==false ? "Search apps, files, settings or ask Claude" : "Search apps, files and settings";text:Hub.query
                onTextEdited:Hub.query=text
                onAccepted:menu.accept(false)
                Keys.onReturnPressed:event=>menu.accept(!!(event.modifiers&Qt.ControlModifier))
                Keys.onDownPressed:{if(menu.searching)menu.move(1);else if(menu.allApps){appGrid.forceActiveFocus();appGrid.currentIndex=0;}else menu.focusApp(0);}
                Keys.onUpPressed:menu.move(-1)
                Keys.onTabPressed:startSearch.ask()
                Keys.onEscapePressed:menu.goBack()
            }
            MButton {visible:menu.searching;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.rightMargin:5;icon:"close";compact:true;implicitWidth:36;tooltip:"Clear search";onClicked:{Hub.query="";searchField.forceActiveFocus();}}
        }
        Item {
            Layout.fillWidth:true;Layout.fillHeight:true
            Flickable {
                id:home;anchors.fill:parent;visible:!menu.searching&&!menu.allApps;clip:true
                contentHeight:homeBody.implicitHeight;boundsBehavior:Flickable.StopAtBounds
                ScrollBar.vertical:ScrollBar {}
                ColumnLayout {
                    id:homeBody;width:home.width;spacing:12
                    RowLayout {Layout.fillWidth:true
                        MText {text:"Pinned";role:"title";Layout.fillWidth:true}
                    }
                    GridLayout {
                        Layout.fillWidth:true;columns:menu.columns;columnSpacing:4;rowSpacing:4;uniformCellWidths:true
                        Repeater {id:pinnedRepeater;model:Hub.favoriteApps
                            AppTile {
                                required property var modelData;required property int index
                                app:modelData;bare:true;showPin:false;tintIndex:index;selected:activeFocus
                                Layout.fillWidth:true;Layout.maximumWidth:(home.width-20)/menu.columns;Layout.preferredWidth:80;Layout.preferredHeight:96
                                activeFocusOnTab:true;onActivated:Hub.launch(app)
                                Keys.onReturnPressed:Hub.launch(app)
                                Keys.onSpacePressed:Hub.launch(app)
                                Keys.onLeftPressed:menu.focusApp(index-1)
                                Keys.onRightPressed:menu.focusApp(index+1)
                                Keys.onDownPressed:menu.focusApp(index+menu.columns)
                                Keys.onUpPressed:{if(index<menu.columns)searchField.forceActiveFocus();else menu.focusApp(index-menu.columns);}
                            }
                        }
                    }
                    MText {visible:Hub.favoriteApps.length===0;Layout.fillWidth:true;text:"Make this space yours. Right-click an app to pin it here.";wrapMode:Text.Wrap;color:Theme.subtext}
                    RowLayout {Layout.fillWidth:true;Layout.topMargin:8
                        MText {text:"Recent";role:"title";Layout.fillWidth:true}
                        MButton {icon:"desktop";text:"Open windows";compact:true;onClicked:Hub.page="windows"}
                    }
                    GridLayout {Layout.fillWidth:true;columns:2;uniformCellWidths:true;columnSpacing:8;rowSpacing:8
                        Repeater {model:menu.recent
                            Rectangle {required property var modelData;Layout.fillWidth:true;Layout.preferredHeight:58;radius:Theme.shapeLg;color:Theme.level(3)
                                RowLayout {anchors.fill:parent;anchors.margins:12;spacing:10
                                    Item {Layout.preferredWidth:28;Layout.preferredHeight:28
                                        Image {id:recentIcon;anchors.fill:parent;source:Quickshell.iconPath(modelData.icon,true);asynchronous:true}
                                        Glyph {anchors.centerIn:parent;visible:recentIcon.status!==Image.Ready;name:Hub.glyphForApp(modelData);color:Theme.primary}
                                    }
                                    ColumnLayout {Layout.fillWidth:true;spacing:3
                                        MText {Layout.fillWidth:true;text:modelData.name;font.pixelSize:12;font.weight:Font.DemiBold}
                                        MText {Layout.fillWidth:true;text:modelData.genericName||"Application";font.pixelSize:10;color:Theme.subtext}
                                    }
                                }
                                MButton {anchors.fill:parent;radius:18;color:"transparent";tooltip:modelData.name;onClicked:Hub.launch(modelData);menuEntries:Hub.appMenu(modelData)}
                            }
                        }
                    }
                    MText {visible:menu.recent.length===0;Layout.fillWidth:true;text:"Apps you open will appear here.";color:Theme.subtext;font.pixelSize:12}
                }
            }
            ColumnLayout {
                visible:!menu.searching&&menu.allApps;anchors.fill:parent;spacing:10
                RowLayout {Layout.fillWidth:true
                    MText {text:menu.section==="all" ? "All apps" : menu.section;role:"title";Layout.fillWidth:true}
                    MText {text:menu.library.length+" apps";role:"label";color:Theme.subtext}
                }
                Flickable {Layout.fillWidth:true;Layout.preferredHeight:32;contentWidth:letters.width;clip:true;flickableDirection:Flickable.HorizontalFlick
                    Row {id:letters;spacing:2
                        Repeater {model:["All","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
                            MButton {required property string modelData;text:modelData;compact:true;implicitWidth:modelData==="All" ? 48 : 32;implicitHeight:30;filled:menu.letter===(modelData==="All" ? "" : modelData);onClicked:{menu.letter=modelData==="All" ? "" : modelData;appGrid.positionViewAtBeginning();}}
                        }
                    }
                }
                GridView {
                    id:appGrid;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;model:menu.library
                    cellWidth:width/menu.columns;cellHeight:104;boundsBehavior:Flickable.StopAtBounds
                    ScrollBar.vertical:ScrollBar {}
                    Keys.onReturnPressed:if(currentItem)Hub.launch(currentItem.modelData)
                    delegate:Item {
                        required property var modelData;required property int index
                        width:appGrid.cellWidth;height:appGrid.cellHeight
                        AppTile {anchors.fill:parent;anchors.margins:2;app:parent.modelData;bare:true;showPin:false;selected:appGrid.activeFocus&&appGrid.currentIndex===parent.index;tintIndex:parent.index;onActivated:Hub.launch(app)}
                    }
                }
            }
            Flickable {
                id:searchScroll;anchors.fill:parent;visible:menu.searching;clip:true
                contentHeight:startSearch.implicitHeight;boundsBehavior:Flickable.StopAtBounds
                ScrollBar.vertical:ScrollBar {}
                // The shared search draws results only; the field above stays Start's own.
                OpalSearch {id:startSearch;width:searchScroll.width;ownField:false;inset:0}
            }
        }
    }
    }
    Rectangle {
        visible:menu.confirmPower!=="";anchors.fill:parent;radius:28;color:Theme.level(2)
        MouseArea {anchors.fill:parent}
        ColumnLayout {anchors.centerIn:parent;width:parent.width-64;spacing:12
            MText {Layout.fillWidth:true;text:menu.confirmPower==="menu" ? "Session and power" : "Confirm "+menu.confirmPower+"?";font.pixelSize:24;wrapMode:Text.Wrap}
            Repeater {model:menu.confirmPower==="menu" ? [{id:"suspend",name:"Sleep"},{id:"logout",name:"Log out"},{id:"reboot",name:"Restart"},{id:"poweroff",name:"Shut down"}] : []
                MButton {required property var modelData;text:modelData.name;tonal:true;Layout.fillWidth:true;onClicked:menu.confirmPower=modelData.id}
            }
            MButton {visible:menu.confirmPower!=="menu";text:"Confirm";filled:true;Layout.fillWidth:true;onClicked:{Hub.command({action:"power",verb:menu.confirmPower});Hub.close();}}
            MButton {id:powerCancel;text:"Cancel";Layout.fillWidth:true;onClicked:menu.confirmPower=""}
        }
    }
}
