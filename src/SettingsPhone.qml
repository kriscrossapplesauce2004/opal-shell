import QtQuick
import QtQuick.Layouts
import Quickshell
// Phone and gestures: the navigation bar, edge gestures, the drawer and the on-screen keyboard.
SettingsPage {
    SettingsLabel {text:"Navigation";Layout.topMargin:0}
    SegmentedButtons {Layout.fillWidth:true;current:!!Hub.prefs.phoneButtons
        options:[{value:false,label:"Gestures",icon:"swipe"},{value:true,label:"Three buttons",icon:"more_horiz"}]
        onPicked:value=>Hub.set("phoneButtons",value)}
    SettingsLabel {text:"Edge gestures"}
    SettingsGestures {Layout.fillWidth:true;Layout.bottomMargin:8}
    SettingsLabel {text:"App drawer columns"}
    SegmentedButtons {Layout.fillWidth:true;current:Hub.prefs.phoneRows||5
        options:[{value:4,label:"4"},{value:5,label:"5"},{value:6,label:"6"},{value:7,label:"7"}]
        onPicked:value=>Hub.set("phoneRows",value)}
    SettingsLabel {visible:Quickshell.screens.length>1;text:"Phone layout display"}
    SegmentedButtons {visible:Quickshell.screens.length>1;Layout.fillWidth:true;current:Hub.prefs.phoneDisplay||""
        options:Quickshell.screens.map(sc=>({value:sc.name,label:sc.name}))
        onPicked:value=>Hub.set("phoneDisplay",value)}
    SettingsGroup {Layout.topMargin:14
        SettingToggle {icon:"keyboard";title:"On-screen keyboard";description:Hub.systemOskAvailable ? "Show the system keyboard now" : "Run the installer to build the Borealis keyboard";checked:Hub.systemOskVisible;enabled:Hub.systemOskAvailable;onToggled:Hub.systemOsk("toggle")}
    }
}
