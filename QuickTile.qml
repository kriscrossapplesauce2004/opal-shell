import QtQuick
import QtQuick.Layouts
Rectangle {
    id:t
    property string icon:""
    property string title:""
    property string subtitle:""
    property bool active:false
    property bool settings:false
    property color accent:Theme.primary
    signal clicked()
    signal openSettings()
    implicitHeight:80
    radius:mouse.pressed ? 16 : active ? 24 : height/2
    color:active ? accent : Theme.alpha(Theme.surfaceHigh,.78)
    scale:mouse.pressed ? .97 : 1
    Behavior on radius {NumberAnimation {duration:260;easing.type:Easing.OutBack}}
    Behavior on color {ColorAnimation {duration:200}}
    Behavior on scale {NumberAnimation {duration:150}}
    Glyph {x:18;width:28;anchors.verticalCenter:parent.verticalCenter;name:t.icon;color:t.active ? Theme.primaryText : Theme.text;font.pixelSize:26}
    Column {x:58;anchors.verticalCenter:parent.verticalCenter;width:Math.max(0,parent.width-x-(t.settings ? 36 : 16));spacing:3
        MText {text:t.title;width:parent.width;wrapMode:Text.WordWrap;maximumLineCount:2;font.pixelSize:13;font.weight:Font.DemiBold;color:t.active ? Theme.primaryText : Theme.text}
        MText {visible:t.subtitle!=="";text:t.subtitle;width:parent.width;font.pixelSize:10;color:t.active ? Theme.alpha(Theme.primaryText,.8) : Theme.subtext}
    }
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:t.clicked();onPressAndHold:t.openSettings()}
    MButton {visible:t.settings;anchors {verticalCenter:parent.verticalCenter;right:parent.right;rightMargin:6}
icon:"next";compact:true;implicitWidth:32;implicitHeight:32;ink:t.active ? Theme.primaryText : Theme.subtext;tooltip:"Open settings";onClicked:t.openSettings()}
    Accessible.role:Accessible.Button
    Accessible.name:title+", "+subtitle
    Accessible.onPressAction:clicked()
}
