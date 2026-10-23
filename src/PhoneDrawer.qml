import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
// App drawer sheet: search, suggested apps, categories, an A-Z grid with a fast scrubber, and pull-down to close.
Item {
    id:drawer
    property bool keyboardOpen:false
    // Floating: the full-screen tablet launcher. There is no sheet and no drag handle; the blurred wallpaper is the background.
    property bool floating:false
    // Dense: tablet icon cells near 150 px. The full-screen launcher and the tablet sheet are both dense.
    property bool dense:floating
    // Room at the bottom for a dock that floats over the sheet.
    property int bottomInset:0
    property string category:"All apps"
    readonly property string filter:Hub.query.trim()
    readonly property bool math:filter!==""&&(filter.startsWith("=")||Hub.looksLikeMath(filter))
    readonly property int inset:dense ? 48 : 12
    // The tablet sheet keeps icon cells near 150 px, so a wide sheet gets more columns and not wider gaps.
    readonly property int columns:dense ? Math.max(6,Math.floor((width-inset)/150)) : PhoneState.columnsFor(width-32,width>=720)
    readonly property real cellW:(width-inset-(rail.visible ? 26 : 0))/columns
    // The system keyboard covers the bottom of the sheet, so the sheet leaves room for it.
    readonly property int keyboardInset:Hub.systemOskVisible&&Hub.systemOskReady ? Math.round(height*.38) : 0
    readonly property var apps:math ? [] : Hub.searchApps(filter,filter ? "All apps" : category)
    readonly property var letters:{
        const seen=[];
        apps.forEach(a=>{const l=(a.name||"#").charAt(0).toUpperCase();const k=/[A-Z]/.test(l) ? l : "#";if(seen.indexOf(k)<0)seen.push(k);});
        return seen;
    }
    signal closeRequested()
    // Dense drawers let a long-pressed app be carried out onto the home. Points are in window coordinates.
    signal appLifted(var app, real x, real y)
    signal appDragged(real x, real y)
    signal appDropped(real x, real y)
    function focusSearch() {search.forceActiveFocus();keyboardOpen=true;PhoneState.refreshActivity();}
    // A kept drawer opens like a new one: all apps, at the top, with no keyboard.
    function reset() {category="All apps";keyboardOpen=false;search.focus=false;grid.positionViewAtBeginning();}
    function jump(letter) {
        const index=apps.findIndex(a=>{const l=(a.name||"#").charAt(0).toUpperCase();return letter==="#" ? !/[A-Z]/.test(l) : l===letter;});
        if(index>=0)grid.positionViewAtIndex(index,GridView.Beginning);
    }
    Connections {
        target:Hub
        function onQueryChanged() { if(search.text!==Hub.query)search.text=Hub.query; }
    }

    Rectangle {
        id:sheet
        anchors.fill:parent
        topLeftRadius:32;topRightRadius:32;bottomLeftRadius:drawer.floating ? 32 : 0;bottomRightRadius:drawer.floating ? 32 : 0
        color:drawer.floating ? "transparent" : Theme.alpha(Theme.light ? Theme.surfaceLow : Theme.mix(Theme.base,Theme.primaryContainer,.12),.97)
        ColumnLayout {
            anchors.fill:parent;anchors.leftMargin:drawer.dense ? 24 : 6;anchors.rightMargin:drawer.dense ? 24 : 6;anchors.topMargin:drawer.floating ? 20 : 8;anchors.bottomMargin:8+drawer.bottomInset+drawer.keyboardInset;spacing:12
            Behavior on anchors.bottomMargin {NumberAnimation {duration:Theme.motion(200);easing.type:Easing.OutCubic}}
            // Handle and header: dragging down here closes the drawer.
            Item {
                visible:!drawer.floating
                Layout.fillWidth:true;Layout.preferredHeight:20
                Rectangle {anchors.centerIn:parent;width:36;height:4;radius:2;color:Theme.alpha(Theme.text,.35)}
                DragHandler {target:null;xAxis.enabled:false;onActiveChanged:if(!active&&translation.y>50)drawer.closeRequested()}
                TapHandler {onTapped:drawer.closeRequested()}
            }
            Rectangle {
                Layout.fillWidth:true;Layout.maximumWidth:drawer.dense ? 720 : 100000;Layout.alignment:Qt.AlignHCenter
                Layout.preferredHeight:56;radius:28;Layout.bottomMargin:drawer.floating ? 8 : 0
                color:Theme.light ? "#ffffff" : drawer.floating ? Theme.alpha(Theme.level(3),.92) : Theme.mix(Theme.base,Theme.primaryContainer,.5)
                RowLayout {
                    anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:8;spacing:10
                    Glyph {name:"search";font.pixelSize:22;color:Theme.subtext}
                    TextField {
                        id:search
                        Layout.fillWidth:true;Layout.fillHeight:true
                        placeholderText:"Search apps, files, settings";text:Hub.query
                        color:Theme.text;placeholderTextColor:Theme.subtext
                        font.family:Theme.font;font.pixelSize:16;selectByMouse:true
                        onTextEdited:Hub.query=text
                        onActiveFocusChanged:if(activeFocus)drawer.keyboardOpen=true
                        onAccepted:{if(drawer.filter!=="")phoneSearch.accept(false);}
                        Keys.onEscapePressed:{if(Hub.query!=="")Hub.query="";else drawer.closeRequested();}
                        background:Item {}
                    }
                    MButton {visible:search.text!=="";icon:"close";compact:true;implicitWidth:40;implicitHeight:40;onClicked:{Hub.query="";search.forceActiveFocus();}}
                    MButton {visible:search.text==="";icon:"settings";compact:true;implicitWidth:40;implicitHeight:40;hoverHalo:true;tooltip:"Phone settings";onClicked:Hub.openSettings("phone")}
                }
            }
            // Suggested: recent apps as a single row when not searching.
            ColumnLayout {
                visible:drawer.filter===""&&Hub.recentApps.length>0;Layout.fillWidth:true;spacing:2
                MText {text:"Suggested";font.pixelSize:12;font.weight:Font.Medium;color:Theme.primary;Layout.leftMargin:6}
                RowLayout {
                    Layout.fillWidth:true;spacing:0
                    Repeater {
                        model:Hub.recentApps.slice(0,drawer.columns)
                        Item {
                            required property var modelData
                            Layout.fillWidth:true;Layout.preferredHeight:PhoneState.cellHeight(drawer.cellW)
                            PhoneAppIcon {anchors.centerIn:parent;app:parent.modelData;size:PhoneState.iconSize(drawer.cellW);onActivated:Hub.launch(app)}
                        }
                    }
                }
            }
            Flickable {
                visible:drawer.filter==="";Layout.fillWidth:true;Layout.preferredHeight:38;contentWidth:chipRow.width;clip:true
                flickableDirection:Flickable.HorizontalFlick;boundsBehavior:Flickable.StopAtBounds
                Row {
                    id:chipRow;spacing:6
                    Repeater {
                        model:(Hub.hasAndroidApps||Hub.waydroid.installed) ? ["All apps","Android","Games","Create","Work","Internet","System"] : ["All apps","Games","Create","Work","Internet","System"]
                        Chip {required property string modelData;text:modelData;implicitHeight:36;selected:drawer.category===modelData;glass:!selected;onClicked:drawer.category=modelData}
                    }

                }
            }
            // While typing, the shared search in touch posture replaces the grid.
            Flickable {
                id:searchScroll
                visible:drawer.filter!=="";Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                contentHeight:phoneSearch.implicitHeight;boundsBehavior:Flickable.StopAtBounds
                OpalSearch {id:phoneSearch;width:searchScroll.width;ownField:false;touch:true;inset:0}
            }
            Item {
                visible:drawer.filter==="";Layout.fillWidth:true;Layout.fillHeight:true
                GridView {
                    id:grid
                    anchors.fill:parent;anchors.rightMargin:rail.visible ? 26 : 0
                    clip:true;model:drawer.apps;cacheBuffer:400
                    cellWidth:width/drawer.columns;cellHeight:PhoneState.cellHeight(drawer.cellW)
                    boundsBehavior:Flickable.DragOverBounds
                    // Pulling past the top closes the drawer, like a phone launcher.
                    onDragEnded:if(contentY<-70)drawer.closeRequested()
                    delegate:Item {
                        required property var modelData
                        required property int index
                        width:GridView.view.cellWidth;height:GridView.view.cellHeight
                        PhoneAppIcon {
                            anchors.centerIn:parent;app:parent.modelData;size:PhoneState.iconSize(drawer.cellW);selected:drawer.filter!==""&&parent.index===0;onActivated:Hub.launch(app)
                            dragOut:drawer.dense
                            onLifted:(x,y)=>drawer.appLifted(app,x,y)
                            onDragged:(x,y)=>drawer.appDragged(x,y)
                            onDropped:(x,y)=>drawer.appDropped(x,y)
                        }
                    }
                    Column {
                        anchors.centerIn:parent;visible:drawer.apps.length===0;spacing:10
                        MText {anchors.horizontalCenter:parent.horizontalCenter;text:drawer.filter ? "No apps match “"+drawer.filter+"”" : "Nothing here yet";color:Theme.subtext}
                        MButton {visible:drawer.filter!=="";anchors.horizontalCenter:parent.horizontalCenter;text:"Search the web";icon:"language";tonal:true;onClicked:{Hub.command({action:"web",text:drawer.filter});Hub.close();}}
                    }
                }
                // A-Z scrubber: slide along the edge to jump; a bubble shows the letter under the finger.
                Item {
                    id:rail
                    visible:drawer.filter===""&&drawer.letters.length>6
                    anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:parent.bottom;width:24
                    property string active:""
                    Column {
                        anchors.centerIn:parent
                        Repeater {
                            model:drawer.letters
                            MText {
                                required property string modelData
                                width:24;height:Math.min(20,(rail.height-8)/Math.max(1,drawer.letters.length))
                                horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
                                text:modelData;font.pixelSize:10;font.weight:rail.active===modelData ? Font.Bold : Font.Medium
                                color:rail.active===modelData ? Theme.primary : Theme.subtext
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill:parent;preventStealing:true
                        function pick(y) {
                            const step=Math.min(20,(rail.height-8)/Math.max(1,drawer.letters.length));
                            const top=(rail.height-step*drawer.letters.length)/2;
                            const i=Math.max(0,Math.min(drawer.letters.length-1,Math.floor((y-top)/step)));
                            if(rail.active!==drawer.letters[i]){rail.active=drawer.letters[i];drawer.jump(rail.active);}
                        }
                        onPressed:e=>pick(e.y)
                        onPositionChanged:e=>pick(e.y)
                        onReleased:rail.active=""
                        onCanceled:rail.active=""
                    }
                    Rectangle {
                        visible:rail.active!=="";width:56;height:56;radius:28;x:-72
                        y:Math.max(0,Math.min(rail.height-height,drawer.letters.indexOf(rail.active)*Math.min(20,(rail.height-8)/Math.max(1,drawer.letters.length))+(rail.height-Math.min(20,(rail.height-8)/Math.max(1,drawer.letters.length))*drawer.letters.length)/2-18))
                        color:Theme.primary
                        MText {anchors.centerIn:parent;text:rail.active;font.pixelSize:24;font.weight:Font.Medium;color:Theme.onPrimary}
                    }
                }
            }
            SearchKeyboard {
                visible:drawer.keyboardOpen&&!Hub.systemOskReady
                Layout.fillWidth:true;Layout.preferredHeight:Math.min(implicitHeight,drawer.height*.42)
                inputTarget:search;contextLabel:"Search apps";returnLabel:"Go"
                onInsert:Hub.query=search.text
                onErase:Hub.query=search.text
                onAccept:{search.accepted();drawer.keyboardOpen=false;}
                onDismiss:{drawer.keyboardOpen=false;search.focus=false;}
            }
        }
    }
}
