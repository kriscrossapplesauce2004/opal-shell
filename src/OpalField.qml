import QtQuick
import QtQuick.Controls

// Text field in Opal's style: a filled rounded field that outlines in the accent while focused.
TextField {
    id: field
    color: Theme.text; placeholderTextColor: Theme.subtext; selectByMouse: true
    font.family: Theme.font; font.pixelSize: 14
    leftPadding: 14; rightPadding: 14; topPadding: 12; bottomPadding: 12
    background: Rectangle { radius: Theme.shapeMd; color: Theme.level(1); border.width: field.activeFocus ? 2 : 0; border.color: Theme.primary }
}
