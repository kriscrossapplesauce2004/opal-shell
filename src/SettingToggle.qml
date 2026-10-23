import QtQuick
// Settings row with an M3E switch. The whole row toggles; it is a SettingRow, so groups round its ends and search can find it.
SettingRow {
    signal toggled()
    toggle:true
    onActivated:toggled()
    Accessible.role:Accessible.CheckBox
    Accessible.checked:checked
}
