import QtQuick
import QtQuick.Layouts
// Battery and power: charge, profiles, staying awake, the power key and the session.
SettingsPage {
    id:page
    property string armed:""
    Timer {id:disarm;interval:3000;onTriggered:page.armed=""}
    Rectangle {
        Layout.fillWidth:true;Layout.preferredHeight:120;radius:28;color:Theme.primaryContainer
        RowLayout {anchors.fill:parent;anchors.margins:22;spacing:18
            // Battery gauge: a pill that fills with the charge level.
            Rectangle {Layout.preferredWidth:38;Layout.preferredHeight:70;radius:14;color:Theme.alpha(Theme.onContainer,.14)
                Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:parent.height*Math.max(0,Math.min(100,Hub.status.battery))/100;radius:14;color:Theme.onContainer;Behavior on height {NumberAnimation {duration:Theme.motion(500);easing.type:Easing.OutCubic}}}
                Glyph {anchors.centerIn:parent;visible:Hub.status.charging;name:"bolt";font.pixelSize:20;color:Theme.primaryContainer}
            }
            ColumnLayout {Layout.fillWidth:true;spacing:2
                MText {text:Hub.status.battery>=0 ? Hub.status.battery+"%" : "No battery";font.pixelSize:38;font.weight:Font.Medium;color:Theme.onContainer}
                MText {text:Hub.status.battery>=0 ? (Hub.status.charging ? "Charging" : "On battery") : "Battery information is not available";role:"body";color:Theme.alpha(Theme.onContainer,.8)}
            }
        }
    }
    SettingsLabel {text:"Power profile"}
    SegmentedButtons {Layout.fillWidth:true;enabledAll:!!Hub.status.profile;current:Hub.status.profile
        options:[{value:"power-saver",label:"Saver",icon:"eco"},{value:"balanced",label:"Balanced",icon:"balance"},{value:"performance",label:"Performance",icon:"speed"}]
        onPicked:value=>Hub.command({action:"profile",value:value})}
    SettingsGroup {Layout.topMargin:12
        SettingToggle {icon:"coffee";title:"Keep awake";description:"The screen does not sleep while this is on";checked:Hub.keepAwake;onToggled:Hub.keepAwake=!Hub.keepAwake}
        SettingRow {icon:"power_settings_new";title:"Power key";description:"The menu behind the power button";chevron:true;onActivated:Hub.settingsSection="powerkey"}
    }
    SettingsLabel {text:"Session"}
    // Sleep, restart and shut down ask for a second tap.
    RowLayout {
        Layout.fillWidth:true;spacing:2
        Repeater {
            model:[{id:"lock",label:"Lock",icon:"lock"},{id:"suspend",label:"Sleep",icon:"bedtime"},{id:"reboot",label:"Restart",icon:"restart_alt"},{id:"poweroff",label:"Shut down",icon:"power_settings_new"}]
            Rectangle {
                id:key
                required property var modelData
                required property int index
                readonly property bool on:page.armed===modelData.id
                Layout.fillWidth:true;Layout.preferredHeight:72
                topLeftRadius:index===0 ? 24 : 8;bottomLeftRadius:topLeftRadius;topRightRadius:index===3 ? 24 : 8;bottomRightRadius:topRightRadius
                color:on ? Theme.error : Theme.alpha(Theme.light ? "#ffffff" : Theme.glassRaised,Theme.light ? .8 : .6)
                Behavior on color {ColorAnimation {duration:Theme.motion(160)}}
                Rectangle {anchors.fill:parent;topLeftRadius:parent.topLeftRadius;topRightRadius:parent.topRightRadius;bottomLeftRadius:parent.bottomLeftRadius;bottomRightRadius:parent.bottomRightRadius;color:Theme.stateLayer;opacity:keyMouse.pressed ? .12 : keyMouse.containsMouse&&!keyMouse.stale ? .06 : 0}
                Column {anchors.centerIn:parent;spacing:4
                    Glyph {anchors.horizontalCenter:parent.horizontalCenter;name:key.modelData.icon;font.pixelSize:22;color:key.on ? Theme.base : Theme.primary}
                    MText {anchors.horizontalCenter:parent.horizontalCenter;text:key.on ? "Tap again" : key.modelData.label;role:"labelS";color:key.on ? Theme.base : Theme.text}
                }
                MouseArea {id:keyMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;property bool stale:false;onPositionChanged:if(!pressed)stale=false;onExited:stale=false;onClicked:{stale=true;
                    const id=key.modelData.id;
                    if(id==="lock"){Hub.settings("lock");return;}
                    if(key.on){Hub.command({action:"power",verb:id});Hub.close();}
                    else {page.armed=id;disarm.restart();}
                }}
                Accessible.role:Accessible.Button;Accessible.name:modelData.label
            }
        }
    }
}
