import QtQuick
import QtQuick.Layouts
// Modes and routines: schedules for night light, dark theme and quiet hours, and saved profiles.
ColumnLayout {
    // The schedules page scrolls; the header collapse reads its position.
    readonly property real contentY:schedules.contentY
    spacing:12
    SettingsGroup {
        SettingRow {icon:"style";title:"Profiles";description:"Save and switch whole setups";chevron:true;onActivated:Hub.settingsSection="profiles"}
    }
    SettingsSchedules {id:schedules;Layout.fillWidth:true;Layout.fillHeight:true}
}
