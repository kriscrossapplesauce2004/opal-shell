import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id:bar
    readonly property string layoutMode:Hub.layoutFor(screen ? screen.width : 1920,screen ? screen.height : 1080,screen ? screen.name : "")
    readonly property bool phone:layoutMode==="phone"
    readonly property bool autoHide:!phone && !!Hub.prefs.taskbarAutoHide
    readonly property bool consoleMode:Hub.prefs.mode==="console"
    property bool revealed:false
    property bool contextOpen:false
    function openSection(section) {Hub.targetScreen=bar.screen;Hub.openSection(section);}
    anchors {bottom:true;left:true;right:true}
    visible:!consoleMode
    implicitHeight:phone ? (Hub.prefs.phoneButtons ? 48 : 24) : 56
    exclusiveZone:(autoHide||consoleMode) ? 0 : implicitHeight
    color:"transparent"
    WlrLayershell.namespace:"opal-shelf"
    mask:Region {item:hitRegion}
    Item {id:hitRegion;x:0;y:bar.autoHide&&!bar.revealed ? bar.height-3 : 0;width:bar.width;height:bar.height-y}
    MouseArea {
        anchors.fill:hitRegion
        hoverEnabled:true
        acceptedButtons:Qt.RightButton
        onEntered:{hideTimer.stop();bar.revealed=true;}
        onExited:hideTimer.restart()
        onClicked:e=>taskbarMenu.popup(e.x,e.y)
    }
    Timer {id:hideTimer;interval:650;onTriggered:if(!bar.contextOpen)bar.revealed=false}
    OpalMenu {id:taskbarMenu;entries:Hub.taskbarMenu();onOpened:{bar.contextOpen=true;hideTimer.stop();}onClosed:{bar.contextOpen=false;hideTimer.restart();}}
    Rectangle {
        id:body
        x:bar.phone ? 0 : 8
        width:bar.width-(bar.phone ? 0 : 16);height:bar.height-(bar.phone ? 0 : 6)
        radius:bar.phone ? 0 : 18
        border.width:bar.phone ? 0 : 1;border.color:Theme.outline
        y:bar.autoHide&&!bar.revealed ? height-3 : 0
        color:Theme.alpha(Theme.base,Hub.prefs.glass*.65)
        Behavior on y {NumberAnimation {duration:140;easing.type:Easing.OutCubic}}
        Rectangle {visible:bar.phone;anchors.top:parent.top;width:parent.width;height:1;color:Theme.outline}
        RowLayout {
            visible:!bar.phone
            anchors {fill:parent;leftMargin:8;rightMargin:8;topMargin:3;bottomMargin:3}
            spacing:6
            MButton {icon:"apps";text:bar.width>1100 ? "Apps" : "";filled:true;compact:true;implicitHeight:38;onClicked:bar.openSection("apps")}
            MButton {icon:"search";compact:true;implicitWidth:38;implicitHeight:38;tooltip:"Search apps, = calculator, > actions";onClicked:{Hub.query="";bar.openSection("apps");}}
            Rectangle {width:1;height:24;color:Theme.outline}
            Flickable {
                id:tasks
                Layout.fillWidth:true;Layout.fillHeight:true
                contentWidth:taskRow.width;contentHeight:height
                clip:true;boundsBehavior:Flickable.StopAtBounds;flickableDirection:Flickable.HorizontalFlick
                Row {
                    id:taskRow;spacing:4;height:tasks.height
                    Repeater {
                        model:Hub.taskGroups
                        Item {
                            id:task
                            required property var modelData
                            readonly property bool focused:modelData.windows.some(w=>Hub.active(w))
                            readonly property bool labeled:Hub.prefs.taskbarLabels!==false&&modelData.windows.length>0&&bar.width>700
                            width:labeled ? Math.max(100,Math.min(184,(tasks.width-44*Hub.taskGroups.filter(g=>!g.windows.length).length)/Math.max(1,Hub.taskGroups.filter(g=>g.windows.length).length))) : 44;height:taskRow.height
                            Rectangle {anchors.fill:parent;radius:12;color:task.focused ? Theme.primaryContainer : taskMouse.containsMouse ? Theme.surfaceHigh : "transparent"}
                            Image {x:8;anchors.verticalCenter:parent.verticalCenter;width:24;height:24;source:Quickshell.iconPath(task.modelData.icon,true)}
                            MText {visible:task.labeled;x:40;width:parent.width-58;anchors.verticalCenter:parent.verticalCenter;text:task.modelData.windows.length===1 ? task.modelData.windows[0].title : task.modelData.name;font.pixelSize:12;color:task.focused ? Theme.onContainer : Theme.text}
                            MText {visible:task.modelData.windows.length>1;anchors {right:parent.right;rightMargin:6;verticalCenter:parent.verticalCenter}
text:task.modelData.windows.length;font.pixelSize:10;color:Theme.primary}
                            Rectangle {visible:task.modelData.windows.length>0;anchors {bottom:parent.bottom;horizontalCenter:parent.horizontalCenter}
height:3;width:task.focused ? 20 : 5;radius:2;color:Theme.primary}
                            OpalMenu {id:groupMenu;entries:task.modelData.app ? Hub.appMenu(task.modelData.app) : task.modelData.windows.reduce((all,w)=>all.concat(Hub.windowMenu(w)),[]);onOpened:{bar.contextOpen=true;hideTimer.stop();}onClosed:{bar.contextOpen=false;hideTimer.restart();}}
                            MouseArea {
                                id:taskMouse;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                                property bool held:false
                                onPressed:held=false
                                onClicked:e=>{if(held)return;if(e.button===Qt.RightButton)groupMenu.popup(e.x,e.y);else Hub.activateGroup(task.modelData);}
                                onPressAndHold:e=>{held=true;groupMenu.popup(e.x,e.y);}
                                onEntered:{hideTimer.stop();bar.revealed=true;}
                            }
                            ToolTip.visible:taskMouse.containsMouse
                            ToolTip.text:task.modelData.name+(task.modelData.windows.length>1 ? " · Click to cycle windows" : "")
                            ToolTip.delay:650
                        }
                    }
                }
                ScrollBar.horizontal:ScrollBar {policy:ScrollBar.AsNeeded;height:3}
            }
            MButton {icon:"desktop";text:bar.width>1200 ? "Open windows" : "";compact:true;implicitHeight:38;tooltip:"Running windows";onClicked:bar.openSection("windows")}
            MButton {icon:"convergence";compact:true;implicitHeight:38;implicitWidth:38;tooltip:"Convergence · adapt your workspace";onClicked:{Hub.targetScreen=bar.screen;Hub.page="convergence";}menuEntries:Hub.taskbarMenu()}
        }
        RowLayout {
            visible:bar.phone&&Hub.prefs.phoneButtons
            anchors.centerIn:parent;spacing:Math.min(bar.width*.12,70)
            MButton {icon:"back";implicitWidth:48;implicitHeight:44;tooltip:"Back";onClicked:Hub.close()}
            MButton {icon:"home";implicitWidth:48;implicitHeight:44;tooltip:"Home";onClicked:{Hub.mobileTab="home";Hub.page="launcher";}}
            MButton {icon:"desktop";implicitWidth:48;implicitHeight:44;tooltip:"Recent apps";onClicked:{Hub.mobileTab="recent";Hub.page="launcher";}}
        }
        Item {
            visible:bar.phone&&!Hub.prefs.phoneButtons;anchors.fill:parent
            Rectangle {anchors.centerIn:parent;width:Math.min(parent.width*.28,120);height:4;radius:2;color:Theme.subtext}
            MouseArea {anchors.fill:parent
                property real startX:0
                onPressed:e=>startX=e.x
                onReleased:e=>{Hub.mobileTab=Math.abs(e.x-startX)>45 ? "recent" : "home";Hub.page="launcher";}
                onPressAndHold:{Hub.mobileTab="recent";Hub.page="launcher";}
            }
        }
    }
}
