import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
    id: a
    property string text: ""
    property string icon: ""
    property string tooltip: text
    property bool filled: false
    property bool tonal: false
    property bool compact: false
    property color accent: Theme.primary
    property color ink: filled ? Theme.primaryText : tonal ? Theme.onContainer : Theme.text
    property var menuEntries: []
    property bool scrollable: false
    signal scrolled(int steps)
    signal clicked()
    implicitWidth: Math.max(compact ? 42 : 48, content.implicitWidth + (compact ? 24 : 32))
    implicitHeight: compact ? 38 : 48
    radius: mouse.pressed ? 10 : filled ? Math.min(14,height/2) : height/2
    color: filled ? accent : tonal ? Theme.primaryContainer : mouse.containsMouse || activeFocus ? Theme.surfaceHigh : "transparent"
    border.width: activeFocus ? 2 : 0
    border.color: Theme.primary
    opacity: enabled ? 1 : 0.35
    scale: mouse.pressed ? 0.96 : 1
    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 160 } }
    RowLayout { id: content; anchors.centerIn: parent; width: Math.min(implicitWidth, Math.max(0,a.width-(a.text!=="" ? 16 : 0))); spacing: 9
        Glyph { visible: a.icon!==""; name:a.icon; color:a.ink; font.pixelSize:a.compact ? 19 : 22 }
        MText { visible:a.text!==""; text:a.text; textFormat:Text.PlainText; Layout.fillWidth:true; horizontalAlignment:Text.AlignHCenter; elide:Text.ElideRight; color:a.ink; font.pixelSize:a.compact ? 12 : 14; font.weight:Font.DemiBold }
    }
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    OpalMenu {id:buttonMenu;entries:a.menuEntries}
    MouseArea {
        id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
        acceptedButtons:Qt.LeftButton|(a.menuEntries.length ? Qt.RightButton : Qt.NoButton)
        property bool held:false
        onWheel:e=>{if(a.scrollable){const delta=e.angleDelta.y||e.angleDelta.x;if(delta!==0)a.scrolled(delta>0 ? 1 : -1);e.accepted=true;}else e.accepted=false;}
        onPressed:held=false
        onClicked:e=>{if(held)return;if(e.button===Qt.RightButton){if(a.menuEntries.length)buttonMenu.openAt(mouse,e.x,e.y);}else a.clicked();}
        onPressAndHold:e=>{if(a.menuEntries.length){held=true;buttonMenu.openAt(mouse,e.x,e.y);}}
    }
    ToolTip.visible: mouse.containsMouse && tooltip!==""
    ToolTip.text: tooltip
    ToolTip.delay: 650
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Accessible.onPressAction: clicked()
}
