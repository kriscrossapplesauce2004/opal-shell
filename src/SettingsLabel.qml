import QtQuick
import QtQuick.Layouts
// Group heading above a block of settings rows.
MText {
    role:"label"
    color:Theme.primary
    font.pixelSize:Hub.prefs.mode==="console" ? 15 : 12
    Layout.fillWidth:true
    Layout.leftMargin:16;Layout.topMargin:16;Layout.bottomMargin:4
    // Search can land on a heading too; it lights up like a found row.
    readonly property bool found:Hub.settingsFound!==""&&(text===Hub.settingsFound||text.indexOf(Hub.settingsFound+" ·")===0)
    Rectangle {z:-1;anchors.fill:parent;anchors.margins:-6;anchors.leftMargin:-10;anchors.rightMargin:-10;radius:12;color:Theme.primaryContainer;opacity:parent.found ? 1 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(Theme.durMedium)}}}
}
