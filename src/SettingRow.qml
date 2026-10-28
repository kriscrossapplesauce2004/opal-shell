import QtQuick
import QtQuick.Layouts
// Segmented list item: one card of a connected settings group. Ends round to 24, the middle keeps 4. A search hit is filled and outlined for a moment.
Rectangle {
    id:row
    property string icon:""
    // An image instead of a glyph, such as an app icon.
    property string iconSource:""
    property string title:""
    property string description:""
    property string value:""
    property bool chevron:false
    property bool first:true
    property bool last:true
    property bool current:false
    // Set once by SettingsGroup, which then follows this row's visibility.
    property bool groupWatched:false
    // Icon in a tinted circle, as on the Settings home; plain icons elsewhere.
    property bool badge:false
    property color badgeColor:Theme.secondaryContainer
    property color badgeInk:Theme.onSecondaryContainer
    // A SettingToggle turns the switch on; checked is its state.
    property bool toggle:false
    property bool checked:false
    property bool large:Hub.prefs.mode==="console"
    default property alias trailing:trail.data
    signal activated()
    readonly property bool found:Hub.settingsFound!==""&&Hub.settingsFound===title
    Layout.fillWidth:true
    implicitHeight:(description ? 72 : 60)+(large ? 12 : 0)
    topLeftRadius:first ? 24 : 4;topRightRadius:topLeftRadius
    bottomLeftRadius:last ? 24 : 4;bottomRightRadius:bottomLeftRadius
    color:current ? Theme.secondaryContainer : found ? Theme.primaryContainer : Theme.alpha(Theme.light ? "#ffffff" : Theme.glassRaised,Theme.light ? .8 : .6)
    border.width:found||row.activeFocus ? 2 : 0;border.color:Theme.primary
    opacity:enabled ? 1 : .45
    Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durMedium)}}
    readonly property color ink:current ? Theme.onSecondaryContainer : found ? Theme.onContainer : Theme.text
    readonly property color softInk:current ? Theme.alpha(Theme.onSecondaryContainer,.75) : found ? Theme.alpha(Theme.onContainer,.8) : Theme.subtext
    Rectangle {anchors.fill:parent;topLeftRadius:row.topLeftRadius;topRightRadius:row.topRightRadius;bottomLeftRadius:row.bottomLeftRadius;bottomRightRadius:row.bottomRightRadius;color:Theme.stateLayer;opacity:mouse.pressed ? .12 : mouse.lit ? .06 : 0}
    // Hover clears on click until the pointer moves again; touch never sends a leave, so it would stay lit.
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;enabled:row.enabled;cursorShape:Qt.PointingHandCursor
        property bool stale:false
        readonly property bool lit:containsMouse&&!stale
        onPositionChanged:if(!pressed)stale=false
        onExited:stale=false
        onClicked:{stale=true;row.activated();}}
    RowLayout {
        anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:16;spacing:16
        Image {visible:row.iconSource!=="";Layout.preferredWidth:32;Layout.preferredHeight:32;Layout.leftMargin:4;Layout.rightMargin:4;sourceSize:Qt.size(64,64);asynchronous:true;source:row.iconSource}
        Rectangle {
            visible:row.icon!==""&&row.iconSource==="";Layout.preferredWidth:40;Layout.preferredHeight:40;radius:20
            color:row.badge ? row.badgeColor : "transparent"
            Glyph {anchors.centerIn:parent;name:row.icon;font.pixelSize:22;color:row.badge ? row.badgeInk : row.softInk}
        }
        ColumnLayout {
            Layout.fillWidth:true;spacing:2
            MText {Layout.fillWidth:true;text:row.title;role:"titleS";font.pixelSize:row.large ? 18 : 15;color:row.ink}
            MText {visible:row.description!=="";Layout.fillWidth:true;text:row.description;role:"bodyS";font.pixelSize:row.large ? 15 : 13;color:row.softInk;wrapMode:Text.Wrap;maximumLineCount:2}
        }
        Row {id:trail;Layout.alignment:Qt.AlignVCenter;spacing:8}
        MText {visible:row.value!=="";text:row.value;role:"label";color:row.softInk}
        MSwitch {visible:row.toggle;checked:row.checked;interactive:false;held:mouse.pressed}
        Glyph {visible:row.chevron;name:"chevron_right";font.pixelSize:22;color:row.softInk}
    }
    activeFocusOnTab:true
    Keys.onReturnPressed:activated()
    Keys.onSpacePressed:activated()
    Accessible.role:Accessible.Button
    Accessible.name:title
    Accessible.description:description
    Accessible.onPressAction:activated()
}
