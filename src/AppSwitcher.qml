import QtQuick
import QtQuick.Effects
import Quickshell

// Alt+Tab strip: every window at its real shape, most recent first; the title sits in one chip under the strip.
// In floating mode, minimized windows wait at the end behind a divider. Super+Tab keeps it open for the keyboard and pointer.
Item {
    id:sw
    property real arrival:0
    readonly property var list:Hub.switcherList
    readonly property bool previews:Hub.prefs.switcherPreviews!==false
    readonly property var chosen:list[Hub.switcherSelection]||null
    readonly property var chosenApp:chosen ? Hub.appForWindow(chosen) : null
    // Tiles keep their window's shape at one height; the height shrinks until the strip fits, then the strip scrolls.
    readonly property real gap:18
    function aspect(w) {const s=w&&w.size;return s&&s[0]>0&&s[1]>0 ? s[0]/s[1] : 1.6;}
    readonly property real naturalWidth:list.reduce((sum,w)=>sum+Math.max(.64,Math.min(1.78,aspect(w)))*150+gap,0)
    readonly property real tileHeight:Math.max(104,Math.min(150,150*(width-140)/Math.max(1,naturalWidth)))
    function tileWidth(w) {return Math.max(.64,Math.min(1.78,aspect(w)))*tileHeight;}
    focus:true
    Keys.onPressed:event=>{
        const k=event.key;
        if(k===Qt.Key_Right||k===Qt.Key_Tab||k===Qt.Key_Down)Hub.switcherMove(1);
        else if(k===Qt.Key_Left||k===Qt.Key_Backtab||k===Qt.Key_Up)Hub.switcherMove(-1);
        else if(k===Qt.Key_Return||k===Qt.Key_Enter||k===Qt.Key_Space)Hub.switcherCommit();
        else if(k===Qt.Key_Escape)Hub.switcherCancel();
        else if(k===Qt.Key_Q||k===Qt.Key_Delete)Hub.switcherCloseSelected();
        else if(k===Qt.Key_M&&sw.chosen&&Hub.prefs.floatingMode){if(Hub.minimized(sw.chosen))Hub.command({action:"window-restore",address:sw.chosen.address});else Hub.command({action:"window-minimize",address:sw.chosen.address});}
        else return;
        event.accepted=true;
    }
    Component.onCompleted:enter.restart()
    NumberAnimation {id:enter;target:sw;property:"arrival";from:0;to:1;duration:Theme.motion(180);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}

    Rectangle {anchors.fill:parent;color:Theme.alpha("#000000",.28*sw.arrival)}
    // A click beside the strip closes it.
    MouseArea {anchors.fill:parent;onClicked:Hub.switcherCancel()}

    Surface {
        id:strip
        anchors.centerIn:parent;anchors.verticalCenterOffset:-20
        width:Math.min(sw.width-80,tiles.contentWidth+48);height:sw.tileHeight+90
        radius:36;kind:"panels";elevated:true;translucency:Math.max(.86,Hub.prefs.glass)
        border.width:Theme.edges&&!Theme.solid("panels") ? 1 : 0;border.color:Theme.glassEdge
        opacity:sw.arrival;scale:.96+.04*sw.arrival
        MouseArea {anchors.fill:parent}
        ListView {
            id:tiles
            anchors.fill:parent;anchors.margins:24
            orientation:ListView.Horizontal;spacing:0;clip:true
            interactive:contentWidth>width;boundsBehavior:Flickable.StopAtBounds
            model:sw.list
            currentIndex:Hub.switcherSelection
            highlightFollowsCurrentItem:false
            onCurrentIndexChanged:positionViewAtIndex(currentIndex,ListView.Contain)
            delegate:Row {
                id:tile
                required property var modelData
                required property int index
                readonly property bool sel:index===Hub.switcherSelection
                readonly property bool mini:Hub.minimized(modelData)
                readonly property bool firstMini:mini&&(index===0||!Hub.minimized(sw.list[index-1]))
                readonly property var app:Hub.appForWindow(modelData)
                spacing:sw.gap
                height:tiles.height
                Rectangle {visible:tile.firstMini&&tile.index>0;width:2;height:sw.tileHeight;radius:1;color:Theme.alpha(Theme.text,.18)}
                Column {
                    spacing:10
                    Item {
                        width:sw.tileWidth(tile.modelData);height:sw.tileHeight
                        Rectangle {id:frame;anchors.fill:parent;radius:16;color:Theme.level(4);opacity:tile.mini ? .5 : 1}
                        // Live preview, rounded with a mask. Without previews the app icon stands in.
                        Item {
                            id:shot
                            anchors.fill:parent
                            visible:sw.previews
                            opacity:tile.mini ? .45 : 1
                            layer.enabled:GraphicsInfo.api!==GraphicsInfo.Software
                            layer.effect:MultiEffect {maskEnabled:true;maskSource:shotMask;maskThresholdMin:.5;maskSpreadAtMin:1}
                            Loader {
                                anchors.fill:parent
                                active:sw.previews&&Hub.switcherShown
                                source:Hub.status.hypr ? "HyprWindowPreview.qml" : "WindowPreview.qml"
                                onLoaded:{if(Hub.status.hypr)item.address=Qt.binding(()=>tile.modelData.address||"");else item.handle=Qt.binding(()=>tile.modelData.handle||null);}
                            }
                        }
                        Rectangle {id:shotMask;anchors.fill:parent;radius:16;visible:false;layer.enabled:true}
                        Image {visible:!sw.previews;anchors.centerIn:parent;width:Math.min(64,parent.height*.5);height:width;sourceSize:Qt.size(128,128);source:Quickshell.iconPath(tile.app ? tile.app.icon : "application-x-executable",true)}
                        // The ring sits outside the tile, so the tile itself never changes shape.
                        Rectangle {visible:tile.sel;anchors.fill:parent;anchors.margins:-5;radius:21;color:"transparent";border.width:3;border.color:Theme.primary}
                        Rectangle {
                            visible:!tile.mini&&!!tile.modelData.workspace&&tile.modelData.workspace!==Hub.status.workspace
                            anchors.right:parent.right;anchors.top:parent.top;anchors.margins:6;width:22;height:22;radius:11;color:Theme.level(5)
                            MText {anchors.centerIn:parent;text:tile.modelData.workspace;role:"labelS"}
                        }
                        Rectangle {
                            visible:tile.mini;anchors.centerIn:parent;width:miniRow.implicitWidth+20;height:30;radius:15;color:Theme.level(5)
                            Row {id:miniRow;anchors.centerIn:parent;spacing:4
                                Glyph {name:"minimize";font.pixelSize:16;anchors.verticalCenter:parent.verticalCenter}
                                MText {text:"Minimized";role:"labelS";anchors.verticalCenter:parent.verticalCenter}}
                        }
                        MouseArea {
                            anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                            acceptedButtons:Qt.LeftButton|Qt.MiddleButton
                            onEntered:Hub.switcherSelection=tile.index
                            onClicked:e=>{Hub.switcherSelection=tile.index;if(e.button===Qt.MiddleButton)Hub.switcherCloseSelected();else Hub.switcherCommit();}
                        }
                    }
                    Image {
                        anchors.horizontalCenter:parent.horizontalCenter;width:28;height:28;sourceSize:Qt.size(56,56)
                        opacity:tile.sel ? 1 : .75
                        source:Quickshell.iconPath(tile.app ? tile.app.icon : "application-x-executable",true)
                    }
                }
                Item {width:1;height:1}
                Accessible.role:Accessible.Button;Accessible.name:modelData.title
            }
        }
    }
    // The chosen window's name, in one chip under the strip.
    Rectangle {
        visible:!!sw.chosen
        anchors.horizontalCenter:parent.horizontalCenter;anchors.top:strip.bottom;anchors.topMargin:14
        width:Math.min(sw.width-80,titleRow.implicitWidth+32);height:44;radius:22;color:Theme.fill(Theme.level(3),.96,"panels")
        opacity:sw.arrival
        Row {
            id:titleRow;anchors.centerIn:parent;spacing:10
            MText {text:sw.chosenApp ? sw.chosenApp.name : sw.chosen ? String(sw.chosen.className||"App") : "";role:"titleS";anchors.verticalCenter:parent.verticalCenter}
            MText {text:sw.chosen ? sw.chosen.title||"" : "";role:"body";color:Theme.subtext;width:Math.min(implicitWidth,sw.width-260);anchors.verticalCenter:parent.verticalCenter}
        }
    }
    MText {
        visible:sw.list.length===0;anchors.centerIn:parent;text:"No open windows";role:"title";color:"white"
    }
    // Keys that work right now.
    Row {
        anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:72;spacing:22
        opacity:sw.arrival
        Repeater {
            model:Hub.switcherSticky ? [{k:"← →",t:"Choose"},{k:"Enter",t:"Switch"},{k:"Q",t:"Close window"}].concat(Hub.prefs.floatingMode ? [{k:"M",t:"Minimize / restore"}] : []).concat([{k:"Esc",t:"Cancel"}])
                                     : [{k:"Tab",t:"Next"},{k:"⇧ Tab",t:"Back"},{k:"Q",t:"Close window"},{k:"Alt",t:"Release to switch"}]
            Row {
                required property var modelData
                spacing:6
                Rectangle {width:Math.max(26,keyText.implicitWidth+14);height:24;radius:7;color:Theme.fill(Theme.level(4),.9,"panels");anchors.verticalCenter:parent.verticalCenter
                    MText {id:keyText;anchors.centerIn:parent;text:modelData.k;role:"labelS"}}
                MText {text:modelData.t;role:"label";color:"white";style:Text.Raised;styleColor:Theme.alpha("#000000",.4);anchors.verticalCenter:parent.verticalCenter}
            }
        }
    }
}
