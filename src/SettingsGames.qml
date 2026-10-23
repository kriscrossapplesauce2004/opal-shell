import QtQuick
import QtQuick.Layouts
// Games and controller: button order and the Guide button.
SettingsPage {
    SettingsLabel {text:"Controller button order";Layout.topMargin:0}
    SegmentedButtons {Layout.fillWidth:true;current:Hub.prefs.controllerLayout==="nintendo" ? "nintendo" : "standard"
        options:[{value:"standard",label:"Standard / Xbox",icon:"sports_esports"},{value:"nintendo",label:"Nintendo",icon:"videogame_asset"}]
        onPicked:value=>Hub.set("controllerLayout",value)}
    MText {Layout.fillWidth:true;Layout.leftMargin:16;Layout.topMargin:6;text:"Nintendo order swaps A and B, and X and Y, everywhere in Opal.";role:"bodyS";color:Theme.subtext;wrapMode:Text.Wrap}
    SettingsGroup {Layout.topMargin:14
        SettingToggle {icon:"gamepad";title:"Guide button opens Quick Access";description:"Tap: glance. Twice: the sheet."+(Hub.aiEnabled ? " Hold: Claude." : "")+" Turn off if Steam uses Guide";checked:Hub.prefs.quickAccessGuide!==false;onToggled:Hub.set("quickAccessGuide",!checked)}
        SettingRow {icon:"sports_esports";title:"Console layout";description:Hub.prefs.mode==="console" ? "On" : "Large game tiles on this screen";chevron:true;onActivated:Hub.mode(Hub.prefs.mode==="console" ? "auto" : "console")}
    }
}
