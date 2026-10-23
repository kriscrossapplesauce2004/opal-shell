import QtQuick
import QtQuick.Layouts
// Connected devices: Bluetooth, Opal Link and game controllers.
SettingsPage {
    SettingsGroup {
        SettingRow {icon:"bluetooth";title:"Bluetooth";description:Hub.status.bluetooth ? "On" : "Off";chevron:true;onActivated:Hub.settingsSection="bluetooth"}
        SettingRow {icon:"devices";title:"Opal Link";description:Hub.prefs.linkEnabled===true ? "Your phone and other Opal devices" : "Off";chevron:true;onActivated:Hub.settingsSection="link"}
    }
    SettingsGroup {title:"Game controllers"
        SettingRow {icon:"sports_esports";title:"Controllers";description:"Button order and the Guide button";chevron:true;onActivated:Hub.settingsSection="games"}
    }
}
