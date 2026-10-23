import QtQuick
import QtQuick.Layouts
// Apps and windows: window mode, the app switcher and file dialogs.
SettingsPage {
    SettingsLabel {text:"Window mode"}
    SegmentedButtons {Layout.fillWidth:true;current:!!Hub.prefs.floatingMode
        options:[{value:false,label:"Tiling",icon:"grid_view"},{value:true,label:"Floating",icon:"select_window"}]
        onPicked:value=>Hub.set("floatingMode",value)}
    MText {Layout.fillWidth:true;Layout.leftMargin:16;Layout.topMargin:6;text:Hub.prefs.floatingMode ? "Title bars, snap layouts and minimize. Turning it off tiles every window again." : "Windows tile side by side. Floating mode adds title bars and snap layouts.";role:"bodyS";color:Theme.subtext;wrapMode:Text.Wrap}
    SettingsGroup {title:"App switcher"
        SettingRow {icon:"tab";title:"Alt+Tab shows";description:"Super+Tab keeps the switcher open without holding a key"
            SegmentedButtons {width:260;buttonHeight:40;current:Hub.prefs.switcherScope==="workspace" ? "workspace" : "all"
                options:[{value:"all",label:"All windows"},{value:"workspace",label:"This workspace"}]
                onPicked:value=>Hub.set("switcherScope",value)}
        }
        SettingToggle {icon:"preview";title:"Live previews";description:"Off shows app icons only, which is lighter on old GPUs";checked:Hub.prefs.switcherPreviews!==false;onToggled:Hub.set("switcherPreviews",!checked)}
    }
    SettingsGroup {title:"File dialogs"
        SettingRow {icon:"folder_open";title:"Opal file dialogs";description:"Apps' Open and Save dialogs, once “opal portal on” has run"}
    }
    SegmentedButtons {Layout.fillWidth:true;Layout.topMargin:8;current:Hub.prefs.portalPicker||"touch"
        options:[{value:"touch",label:"Phone & tablet",icon:"phone"},{value:"always",label:"Everywhere",icon:"devices"},{value:"never",label:"Never",icon:"block"}]
        onPicked:value=>Hub.set("portalPicker",value)}
}
