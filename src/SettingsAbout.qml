import QtQuick
import QtQuick.Layouts
import Quickshell
// About this device: live system figures from the status adapter.
SettingsPage {
    Rectangle {
        Layout.fillWidth:true;Layout.preferredHeight:120;radius:28;color:Theme.primaryContainer
        RowLayout {anchors.fill:parent;anchors.margins:20;spacing:16
            Flower {Layout.preferredWidth:72;Layout.preferredHeight:72;lobes:8;depth:.12;fill:Theme.onContainer
                Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:30;color:Theme.primaryContainer}}
            ColumnLayout {Layout.fillWidth:true;spacing:2
                MText {text:"Opal";font.pixelSize:28;font.weight:Font.Medium;color:Theme.onContainer}
                MText {text:"Material 3 Expressive shell for Quickshell"+(Hub.status.uptime ? " · up "+Hub.status.uptime : "");role:"bodyS";color:Theme.alpha(Theme.onContainer,.8)}
            }
        }
    }
    SettingsGroup {title:"Live usage"
        Repeater {
            model:[{label:"Processor",value:Hub.load.cpu,icon:"speed"},{label:"Memory",value:Hub.load.memory,icon:"memory"}]
            SettingRow {
                required property var modelData
                icon:modelData.icon;title:modelData.label;value:Math.round(modelData.value)+"%"
                LinearProgress {width:120;value:modelData.value/100;anchors.verticalCenter:parent ? parent.verticalCenter : undefined}
            }
        }
    }
    SettingsGroup {title:"Shell"
        Repeater {
            model:[
                {label:"Layout",value:Hub.prefs.mode==="auto" ? "Automatic" : Hub.prefs.mode},
                {label:"Displays",value:Quickshell.screens.map(sc=>sc.name+" "+sc.width+"×"+sc.height).join(", ")||"None"},
                {label:"Compositor",value:Hub.status.hypr ? "Hyprland" : "Wayland (generic)"},
                {label:"Power profile",value:Hub.status.profile||"Unavailable"},
                {label:"Look",value:({glass:"Glass",mixed:"Mixed",material:"Material"})[Theme.look]+(Theme.lookCustom ? " · Custom" : "")},
                {label:"Colour",value:Hub.prefs.dynamicColors ? "Wallpaper colours · "+String(Hub.prefs.colorScheme||"").replace("scheme-","") : Theme.palette.name}]
            SettingRow {required property var modelData;title:modelData.label;value:modelData.value}
        }
    }
    SettingsGroup {title:"Setup"
        SettingRow {
            icon:"auto_awesome";title:"Set up Opal again";description:"Walk through Wi-Fi, look, layout, apps and "+(Hub.aiEnabled ? "Claude" : "shortcuts")
            MButton {text:"Start";tonal:true;compact:true;onClicked:Hub.openOobe()}
        }
    }
}
