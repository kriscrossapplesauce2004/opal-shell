import QtQuick
import QtQuick.Layouts
// Notifications: Do not disturb and the inbox.
SettingsPage {
    SettingsGroup {
        SettingToggle {icon:"do_not_disturb_on";title:"Do not disturb";description:"Silence popups. Notifications stay in your inbox.";checked:Hub.dnd;onToggled:Hub.set("dnd",!checked)}
        SettingRow {icon:"inbox";title:"Notification inbox";value:String(Hub.inbox.length);chevron:true;onActivated:Hub.page="notifications"}
        SettingRow {icon:"schedule";title:"Quiet hours";description:"Do not disturb on a schedule";chevron:true;onActivated:Hub.findSetting("routines","Do not disturb")}
    }
    MButton {visible:Hub.inbox.length>0;Layout.alignment:Qt.AlignRight;Layout.topMargin:10;text:"Clear all";icon:"clear_all";tonal:true;onClicked:Notifier.clear()}
}
