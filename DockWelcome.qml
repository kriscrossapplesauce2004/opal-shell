import QtQuick
import QtQuick.Layouts

Surface {
    id:d
    property string displayName:Hub.dockScreen ? Hub.dockScreen.name : "External display"
    radius:30;translucency:Math.min(Hub.prefs.glass,.72)
    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:14
        RowLayout {Layout.fillWidth:true;spacing:14
            Rectangle {width:64;height:64;radius:20;color:Theme.alpha(Theme.primary,.18)
                Glyph {anchors.centerIn:parent;name:"desktop";font.pixelSize:30;color:Theme.primary}
            }
            ColumnLayout {Layout.fillWidth:true;spacing:4
                MText {text:"CONNECTED · "+d.displayName;Layout.fillWidth:true;font.pixelSize:10;font.letterSpacing:1;color:Theme.primary}
                MText {text:"Room to do more.";Layout.fillWidth:true;font.pixelSize:26;font.weight:Font.DemiBold}
            }
            MButton {icon:"close";tooltip:"Dismiss docking welcome";onClicked:Hub.dockNotice=false}
        }
        MText {Layout.fillWidth:true;wrapMode:Text.Wrap;text:Hub.prefs.mode==="auto" ? "Your workspace has expanded. Each screen has its own home, shelf and controls; your apps stay where you left them." : "A bigger screen, a full workspace. Enable Flow to adapt each display independently, while keeping a touch home on small screens.";font.pixelSize:13;color:Theme.subtext}
        RowLayout {Layout.fillWidth:true;spacing:8
            MButton {Layout.fillWidth:true;filled:true;icon:"expand";text:Hub.prefs.mode==="auto" ? "Open workspace" : "Enable Flow";onClicked:{Hub.targetScreen=Hub.dockScreen;Hub.dockNotice=false;if(Hub.prefs.mode!=="auto")Hub.mode("auto");else Hub.openSection("apps");}}
            MButton {text:"Display setup";tonal:true;onClicked:{Hub.targetScreen=Hub.dockScreen;Hub.dockNotice=false;Hub.page="convergence";}}
        }
    }
}
