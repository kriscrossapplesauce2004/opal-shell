import QtQuick
import QtQuick.Layouts
import Quickshell
// Home and shelf: the layout of each screen, the shelf, pinned apps, desktop widgets and weather.
SettingsPage {
    id:page
    readonly property var layoutModes:[{value:"auto",label:"Automatic",icon:"auto_mode"},{value:"desktop",label:"Desktop",icon:"desktop_windows"},{value:"phone",label:"Phone",icon:"smartphone"},{value:"console",label:"Console",icon:"sports_esports"}]
    SettingsLabel {text:"Layout";Layout.topMargin:0}
    SegmentedButtons {Layout.fillWidth:true;current:Hub.prefs.mode||"auto";options:page.layoutModes;onPicked:value=>Hub.mode(value)}
    MText {Layout.fillWidth:true;Layout.leftMargin:16;Layout.topMargin:6;role:"bodyS";color:Theme.subtext;wrapMode:Text.Wrap
        text:({auto:"Each screen picks phone, tablet or desktop by its size.",desktop:"A shelf with running apps and a compact app drawer.",phone:"Edge-to-edge home, app drawer, recents and touch actions.",console:"Large game tiles, controller and D-pad navigation."})[Hub.prefs.mode||"auto"]}
    SettingsLabel {text:"Bar style"}
    SegmentedButtons {Layout.fillWidth:true;current:Hub.prefs.barStyle||"islands"
        options:[{value:"islands",label:"Islands",icon:"view_column"},{value:"dock",label:"Dock",icon:"call_to_action"},{value:"split",label:"Split",icon:"splitscreen"},{value:"edge",label:"Edge",icon:"bottom_navigation"}]
        onPicked:value=>Hub.set("barStyle",value)}
    SettingsGroup {title:"Shelf"
        SettingToggle {icon:"vertical_align_bottom";title:"Hide the shelf automatically";description:"Move to the bottom edge to reveal it";checked:!!Hub.prefs.taskbarAutoHide;onToggled:Hub.set("taskbarAutoHide",!checked)}
        SettingToggle {icon:"format_align_center";title:"Center apps";description:"System controls stay on the right";checked:!!Hub.prefs.taskbarCenter;onToggled:Hub.set("taskbarCenter",!checked)}
        SettingToggle {icon:"label";title:"Window labels";description:"Titles appear when there is room";checked:!!Hub.prefs.taskbarLabels;onToggled:Hub.set("taskbarLabels",!checked)}
        SettingToggle {icon:"calendar_month";title:"Date beside the clock";checked:Hub.prefs.taskbarClockDate!==false;onToggled:Hub.set("taskbarClockDate",!checked)}
    }
    SettingsGroup {title:"Pinned apps · "+Hub.favoriteApps.length
        Repeater {
            model:Hub.favoriteApps
            SettingRow {
                required property var modelData
                title:modelData.name;iconSource:Quickshell.iconPath(modelData.icon,true)
                MButton {icon:"keep_off";compact:true;implicitWidth:36;implicitHeight:36;tooltip:"Unpin "+modelData.name;onClicked:Hub.pin(modelData)}
            }
        }
    }
    MText {visible:Hub.favoriteApps.length===0;Layout.fillWidth:true;Layout.leftMargin:16;text:"Right-click any app and choose Pin.";role:"bodyS";color:Theme.subtext}
    SettingsGroup {title:"Home"
        SettingToggle {icon:"widgets";title:"Desktop widgets";description:"Glance, media and calendar cards on the desktop";checked:Hub.prefs.desktopWidgets!==false;onToggled:Hub.set("desktopWidgets",!checked)}
        SettingToggle {icon:"history";title:"Pick up where you left off";description:"Show recent files, games, media and device sessions on Home";checked:Hub.prefs.resumeSuggestions!==false;onToggled:Hub.set("resumeSuggestions",!checked)}
        SettingToggle {icon:"layers_clear";title:"Hide the home under apps";description:"Icons and widgets fade out while a window is open";checked:Hub.prefs.homeHideUnderApps!==false;onToggled:Hub.set("homeHideUnderApps",!checked)}
        SettingToggle {icon:"desktop_windows";title:"Desktop files on the tablet home";description:"Files in ~/Desktop show as icons next to your apps";checked:Hub.prefs.homeDesktopFiles===true;onToggled:Hub.set("homeDesktopFiles",!checked)}
    }
    SettingsLabel {text:"Weather city"}
    // Weather comes from Open-Meteo for this city. Leave it empty to turn weather off.
    RowLayout {
        Layout.fillWidth:true;spacing:8
        Rectangle {
            Layout.fillWidth:true;Layout.preferredHeight:52;radius:26;color:Theme.alpha(Theme.light ? "#ffffff" : Theme.glassRaised,Theme.light ? .8 : .6)
            Glyph {x:16;anchors.verticalCenter:parent.verticalCenter;name:"location_on";font.pixelSize:20;color:Theme.subtext}
            TextInput {
                id:cityField
                anchors.fill:parent;anchors.leftMargin:46;anchors.rightMargin:16;verticalAlignment:TextInput.AlignVCenter
                text:Hub.prefs.weatherCity||"";color:Theme.text;font.family:Theme.font;font.pixelSize:15;maximumLength:80;clip:true
                onEditingFinished:if(text.trim()!==(Hub.prefs.weatherCity||""))Hub.set("weatherCity",text.trim())
                MText {anchors.verticalCenter:parent.verticalCenter;visible:!cityField.text&&!cityField.activeFocus;text:"City for weather, like Lisbon";color:Theme.subtext}
            }
        }
        SegmentedButtons {Layout.preferredWidth:140;buttonHeight:52;current:!!Hub.prefs.weatherFahrenheit;options:[{value:false,label:"°C"},{value:true,label:"°F"}];onPicked:value=>Hub.set("weatherFahrenheit",value)}
    }
    MText {Layout.fillWidth:true;Layout.leftMargin:16;Layout.topMargin:6;visible:!!HomeData.weather;text:HomeData.weather ? "Now in "+HomeData.weather.place+": "+HomeData.weather.temp+HomeData.weather.unit+", "+HomeData.weather.text.toLowerCase() : "";role:"bodyS";color:Theme.subtext}
}
