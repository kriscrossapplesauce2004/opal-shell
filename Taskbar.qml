import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id:bar
    readonly property string layoutMode:Hub.layoutFor(screen ? screen.width : 1920,screen ? screen.height : 1080,screen ? screen.name : "")
    readonly property bool phone:layoutMode==="phone"
    readonly property bool autoHide:!phone&&!!Hub.prefs.taskbarAutoHide
    readonly property bool consoleMode:layoutMode==="console"
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
    MouseArea {id:barMouse;anchors.fill:hitRegion;hoverEnabled:true;acceptedButtons:Qt.RightButton
        onEntered:{hideTimer.stop();bar.revealed=true;}
        onExited:hideTimer.restart()
        onClicked:e=>taskbarMenu.openAt(barMouse,e.x,e.y)
    }
    Timer {id:hideTimer;interval:650;onTriggered:if(!bar.contextOpen&&!strip.interacting&&!strip.hovered)bar.revealed=false}
    OpalMenu {id:taskbarMenu;entries:Hub.taskbarMenu();onOpened:{bar.contextOpen=true;hideTimer.stop();}onClosed:{bar.contextOpen=false;hideTimer.restart();}}
    Rectangle {
        id:body;x:bar.phone ? 0 : 8
        width:bar.width-(bar.phone ? 0 : 16);height:bar.height-(bar.phone ? 0 : 6)
        radius:bar.phone ? 0 : 18;border.width:bar.phone ? 0 : 1;border.color:Theme.outline
        y:bar.autoHide&&!bar.revealed ? height-3 : 0
        color:Theme.alpha(Theme.base,Hub.prefs.glass*.65)
        Behavior on y {NumberAnimation {duration:Theme.motion(140);easing.type:Easing.OutCubic}}
        Rectangle {visible:bar.phone;anchors.top:parent.top;width:parent.width;height:1;color:Theme.outline}
        RowLayout {
            visible:!bar.phone;anchors.fill:parent;anchors.leftMargin:8;anchors.rightMargin:8;anchors.topMargin:3;anchors.bottomMargin:3;spacing:6
            MButton {icon:"apps";text:bar.width>1100 ? "Apps" : "";filled:true;compact:true;implicitHeight:38;onClicked:bar.openSection("apps")}
            MButton {icon:"search";compact:true;implicitWidth:38;implicitHeight:38;tooltip:"Search apps, = calculator, > actions";onClicked:{Hub.query="";bar.openSection("apps");}}
            Rectangle {width:1;height:24;color:Theme.outline}
            TaskStrip {id:strip;Layout.fillWidth:true;Layout.fillHeight:true;labels:Hub.prefs.taskbarLabels!==false
                onEngaged:{hideTimer.stop();bar.revealed=true;}
                onReleased:hideTimer.restart()
            }
            MButton {icon:"desktop";text:bar.width>1200 ? "Open windows" : "";compact:true;implicitHeight:38;tooltip:"Running windows";onClicked:bar.openSection("windows")}
            MButton {icon:"convergence";compact:true;implicitHeight:38;implicitWidth:38;tooltip:"Convergence · adapt your workspace";onClicked:{Hub.targetScreen=bar.screen;Hub.page="convergence";}menuEntries:Hub.taskbarMenu()}
        }
        RowLayout {visible:bar.phone&&Hub.prefs.phoneButtons;anchors.centerIn:parent;spacing:Math.min(bar.width*.12,70)
            MButton {icon:"back";implicitWidth:48;implicitHeight:44;tooltip:"Back";onClicked:Hub.close()}
            MButton {icon:"home";implicitWidth:48;implicitHeight:44;tooltip:"Home";onClicked:{Hub.targetScreen=bar.screen;Hub.mobileTab="home";Hub.page="launcher";}}
            MButton {icon:"desktop";implicitWidth:48;implicitHeight:44;tooltip:"Recent apps";onClicked:{Hub.targetScreen=bar.screen;Hub.mobileTab="recent";Hub.page="launcher";}}
        }
        Item {visible:bar.phone&&!Hub.prefs.phoneButtons;anchors.fill:parent
            Rectangle {anchors.centerIn:parent;width:Math.min(parent.width*.28,120);height:4;radius:2;color:Theme.subtext}
            MouseArea {anchors.fill:parent;property real startX:0
                onPressed:e=>startX=e.x
                onReleased:e=>{Hub.targetScreen=bar.screen;Hub.mobileTab=Math.abs(e.x-startX)>45 ? "recent" : "home";Hub.page="launcher";}
                onPressAndHold:{Hub.targetScreen=bar.screen;Hub.mobileTab="recent";Hub.page="launcher";}
            }
        }
    }
}
