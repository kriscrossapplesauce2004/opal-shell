import QtQuick
import QtQuick.Layouts
// Omarchy-format themes. Each card is a small Opal desktop in that theme; choosing one restyles the shell and every app Opal themes.
ColumnLayout {
    id:gallery
    property string filter:"all"
    property bool expanded:false
    readonly property string selected:Hub.prefs.dynamicColors ? Hub.prefs.omarchyTheme||"" : ""
    readonly property int columns:width>=620 ? 4 : width>=420 ? 3 : 2
    readonly property real cardWidth:Math.floor((width-(columns-1)*10)/columns)
    readonly property var shown:Hub.omarchyThemes.filter(t=>filter==="all"||filter===t.mode||filter==="installed"&&t.source==="installed")
    spacing:12
    Component.onCompleted:Hub.command({action:"omarchy-themes"})
    Flow {Layout.fillWidth:true;spacing:6
        Repeater {model:[{id:"all",text:"All",icon:"palette"},{id:"dark",text:"Dark",icon:"dark_mode"},{id:"light",text:"Light",icon:"light_mode"},{id:"installed",text:"Installed",icon:"folder"}]
            Chip {required property var modelData;text:modelData.text;icon:modelData.icon;selected:gallery.filter===modelData.id;onClicked:gallery.filter=modelData.id}
        }
    }
    Flow {
        Layout.fillWidth:true;spacing:10
        Repeater {model:gallery.expanded ? gallery.shown : gallery.shown.slice(0,gallery.columns*2)
            Item {
                id:card
                required property var modelData
                readonly property bool active:gallery.selected===modelData.id
                width:gallery.cardWidth;height:width*.62+34
                Rectangle {
                    id:frame
                    width:parent.width;height:parent.width*.62;radius:card.active ? 28 : 16;clip:true
                    color:card.modelData.background
                    border.width:card.active ? 3 : 1;border.color:card.active ? Theme.primary : Theme.alpha(Theme.text,.12)
                    Behavior on radius {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized}}
                    scale:hit.pressed ? .96 : 1
                    Behavior on scale {NumberAnimation {duration:Theme.motion(Theme.durShort)}}
                    RoundedImage {anchors.fill:parent;anchors.margins:frame.border.width;radius:frame.radius-frame.border.width;source:card.modelData.wallpaper||"";visible:!!card.modelData.wallpaper;decodeSize:Qt.size(320,200)}
                    // A tiny shelf: Start dot in the accent, then the palette as app bubbles.
                    Rectangle {
                        anchors {left:parent.left;right:parent.right;bottom:parent.bottom;margins:9}
                        height:22;radius:11;color:Theme.alpha(card.modelData.background,.86)
                        Row {anchors.verticalCenter:parent.verticalCenter;x:5;spacing:4
                            Rectangle {width:12;height:12;radius:6;color:card.modelData.accent}
                            Repeater {model:card.modelData.swatches.slice(1,6)
                                Rectangle {required property string modelData;width:8;height:8;radius:4;anchors.verticalCenter:parent.verticalCenter;color:modelData}
                            }
                        }
                        Rectangle {anchors.right:parent.right;anchors.rightMargin:6;anchors.verticalCenter:parent.verticalCenter;width:26;height:6;radius:3;color:Theme.alpha(card.modelData.foreground,.7)}
                    }
                    // A window card in the theme's foreground, so plain themes still read as themselves.
                    Rectangle {
                        visible:!card.modelData.wallpaper
                        x:12;y:12;width:parent.width*.55;height:parent.height*.42;radius:8
                        color:Qt.lighter(card.modelData.background,card.modelData.mode==="dark" ? 1.35 : .96)
                        Column {x:8;y:8;spacing:5
                            Rectangle {width:40;height:5;radius:2.5;color:card.modelData.accent}
                            Rectangle {width:56;height:4;radius:2;color:Theme.alpha(card.modelData.foreground,.7)}
                            Rectangle {width:32;height:4;radius:2;color:Theme.alpha(card.modelData.foreground,.45)}
                        }
                    }
                    Flower {
                        visible:card.active;width:30;height:30;anchors {right:parent.right;top:parent.top;margins:8}
                        fill:Theme.primary;lobes:6
                        Glyph {anchors.centerIn:parent;name:"check";font.pixelSize:16;color:Theme.onPrimary}
                    }
                }
                RowLayout {
                    anchors {left:parent.left;right:parent.right;top:frame.bottom;topMargin:7}
                    spacing:5
                    MText {Layout.fillWidth:true;text:card.modelData.name;role:"label";elide:Text.ElideRight;color:card.active ? Theme.primary : Theme.text}
                    Glyph {name:card.modelData.mode==="light" ? "light_mode" : "dark_mode";font.pixelSize:14;color:Theme.subtext}
                    Glyph {visible:Hub.omarchyCurrent===card.modelData.id;name:"sync";font.pixelSize:14;color:Theme.primary}
                }
                MouseArea {id:hit;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:Hub.command({action:"omarchy-apply",id:card.modelData.id})}
            }
        }
    }
    MButton {
        visible:gallery.shown.length>gallery.columns*2;Layout.alignment:Qt.AlignHCenter;compact:true;tonal:true
        icon:gallery.expanded ? "expand_less" : "expand_more";text:gallery.expanded ? "Fewer themes" : "Show all "+gallery.shown.length+" themes"
        onClicked:gallery.expanded=!gallery.expanded
    }
    MText {visible:gallery.shown.length===0;Layout.fillWidth:true;text:gallery.filter==="installed" ? "No themes in ~/.config/omarchy/themes or ~/.config/opal/themes yet." : "Loading themes…";color:Theme.subtext;role:"bodyS";wrapMode:Text.Wrap}
    SettingToggle {
        Layout.fillWidth:true;icon:"wallpaper";title:"Use the theme's wallpaper"
        description:"Themes with backgrounds also set your wallpaper"
        checked:Hub.prefs.omarchyWallpaper!==false;onToggled:Hub.set("omarchyWallpaper",!checked)
        first:true;last:!Hub.omarchyInstalled
    }
    SettingToggle {
        visible:Hub.omarchyInstalled;Layout.fillWidth:true;icon:"sync";title:"Follow Omarchy"
        description:Hub.omarchyCurrent ? "Wear whatever Omarchy switches to · now "+Hub.omarchyCurrent : "Wear whatever Omarchy switches to"
        checked:Hub.prefs.omarchyFollow===true;onToggled:Hub.set("omarchyFollow",!checked)
        first:false;last:true
    }
    MButton {
        Layout.fillWidth:true;icon:"ios_share";tonal:true
        text:"Save this look as an Omarchy theme"
        onClicked:Hub.command({action:"omarchy-export",light:Theme.light,roles:Theme.roles()})
    }
    MText {Layout.fillWidth:true;text:"Drop any Omarchy theme folder into ~/.config/opal/themes. Opal reads its colours and wallpapers only and never runs anything a theme ships.";wrapMode:Text.Wrap;color:Theme.subtext;font.pixelSize:11}
}
