import QtQuick
import QtQuick.Layouts
// Wallpaper and style: wallpaper, colours, themes, dark theme, icons, and the way into the Look and app themes.
SettingsPage {
    id:page
    readonly property var colorSchemes:[{value:"scheme-tonal-spot",label:"Tonal"},{value:"scheme-expressive",label:"Expressive"},{value:"scheme-vibrant",label:"Vibrant"},{value:"scheme-neutral",label:"Neutral"}]
    ThemeReveal {}
    SettingsLabel {text:"Wallpaper";Layout.topMargin:0}
    Item {
        Layout.fillWidth:true;Layout.preferredHeight:Math.min(220,width*.42)
        RoundedImage {anchors.fill:parent;radius:28;source:Hub.prefs.wallpaperPath||"";decodeSize:Qt.size(960,540)}
        MButton {anchors {right:parent.right;bottom:parent.bottom;margins:14} icon:"wallpaper";text:"Wallpaper";filled:true;onClicked:Hub.page="wallpaper"}
    }
    SettingsLabel {text:"Colour"}
    Rectangle {
        Layout.fillWidth:true;implicitHeight:88;topLeftRadius:24;topRightRadius:24;bottomLeftRadius:4;bottomRightRadius:4
        color:Theme.alpha(Theme.light ? "#ffffff" : Theme.glassRaised,Theme.light ? .8 : .6)
        Row {
            anchors.verticalCenter:parent.verticalCenter;x:16;spacing:12
            Repeater {
                model:Theme.palettes
                Item {
                    id:sw
                    required property var modelData
                    required property int index
                    readonly property bool on:!Hub.prefs.dynamicColors&&Hub.prefs.palette===index
                    width:56;height:56
                    Rectangle {anchors.fill:parent;radius:28;color:"transparent";border.width:sw.on ? 3 : 0;border.color:Theme.primary}
                    Rectangle {anchors.centerIn:parent;width:44;height:44;radius:22;color:sw.modelData.primary;clip:true
                        Rectangle {x:22;y:22;width:22;height:22;color:sw.modelData.tertiary;bottomRightRadius:22}}
                    Glyph {visible:sw.on;anchors.centerIn:parent;name:"check";font.pixelSize:20;color:sw.modelData.onPrimary}
                    MouseArea {id:swMouse;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:mouse=>Hub.withReveal(swMouse,mouse.x,mouse.y,()=>{Hub.set("dynamicColors",false);Hub.set("palette",sw.index);})}
                    Accessible.role:Accessible.RadioButton;Accessible.name:modelData.name;Accessible.checked:on
                }
            }
        }
    }
    SettingsGroup {
        SettingToggle {icon:"auto_awesome";title:"Colours from wallpaper";description:Hub.themeBusy ? "Extracting colours…" : "Matugen builds the palette from your wallpaper";checked:!!Hub.prefs.dynamicColors;enabled:!!Hub.prefs.wallpaperPath&&!Hub.themeBusy
            onToggled:{if(!checked&&!(Hub.prefs.dynamicPalette&&Hub.prefs.dynamicPalette.dark))Hub.command({action:"matugen"});else Hub.set("dynamicColors",!checked);}
            LoadingIndicator {visible:Hub.themeBusy;width:32;height:32}
        }
        SettingToggle {id:dark;icon:"dark_mode";title:"Dark theme";checked:!Theme.light;onToggled:Hub.withReveal(dark,dark.width-40,dark.height/2,()=>Hub.set("light",!Theme.light))}
    }
    SegmentedButtons {visible:!!Hub.prefs.dynamicColors;Layout.fillWidth:true;Layout.topMargin:8;buttonHeight:40;current:Hub.prefs.colorScheme||"scheme-tonal-spot";options:page.colorSchemes
        onPicked:value=>{Hub.set("colorScheme",value);Hub.command({action:"matugen"});}}
    SettingsLabel {text:"Themes"}
    ThemeGallery {Layout.fillWidth:true}
    SettingsLabel {text:"App icons"}
    SegmentedButtons {Layout.fillWidth:true;current:Hub.prefs.iconStyle||"raw"
        options:[{value:"raw",label:"Original",icon:"apps"},{value:"squircle",label:"Backplate",icon:"rounded_corner"},{value:"themed",label:"Themed",icon:"palette"}]
        onPicked:value=>Hub.set("iconStyle",value)}
    SettingsGroup {Layout.topMargin:14
        SettingRow {icon:"layers";title:"Look";description:({glass:"Glass · see-through surfaces with blur",mixed:"Mixed · solid sheets, glass bars and home",material:"Material · every surface solid"})[Theme.look]+(Theme.lookCustom ? " · Custom" : "");chevron:true;onActivated:Hub.settingsSection="look"}
        SettingRow {icon:"format_paint";title:"Theme for apps";description:"GTK, Kitty, Qt and window borders";chevron:true;onActivated:Hub.settingsSection="apptheme"}
    }
}
