import QtQuick
import QtQuick.Layouts
// The Look: Glass, Mixed or Material, then each surface as glass or solid, then the effects.
SettingsPage {
    id:page
    readonly property var presets:[
        {id:"glass",title:"Glass",detail:"See-through, blurred",sheet:.6,bar:.6},
        {id:"mixed",title:"Mixed",detail:"Solid sheets, glass bars",sheet:1,bar:.6},
        {id:"material",title:"Material",detail:"Every surface solid",sheet:1,bar:1}]
    readonly property var surfaces:[
        {id:"panels",title:"Panels & sheets",icon:"web_asset"},{id:"menus",title:"Menus",icon:"menu"},
        {id:"bars",title:"Shelf & dock",icon:"dock_to_bottom"},{id:"widgets",title:"Home & widgets",icon:"widgets"},
        {id:"shade",title:"Shade & Quick Settings",icon:"tune"},{id:"lock",title:"Lock screen",icon:"lock"}]
    // A preset clears the overrides and sets the effects that suit it.
    function choose(id) {Hub.set("look",id);Hub.set("lookSurfaces",{});Hub.set("lookEdges",id!=="material");Hub.set("lookShadows",id==="material");}
    function setSurface(id,solid) {const next=Object.assign({},Hub.prefs.lookSurfaces||{});if(solid===Theme.presetIsSolid(Theme.look,id))delete next[id];else next[id]=solid ? "solid" : "glass";Hub.set("lookSurfaces",next);}
    SettingsLabel {text:"Look preset"}
    GridLayout {
        Layout.fillWidth:true;columns:width>=520 ? 3 : 1;columnSpacing:10;rowSpacing:10
        Repeater {
            model:page.presets
            Rectangle {
                id:card
                required property var modelData
                readonly property bool on:Theme.look===modelData.id
                Layout.fillWidth:true;Layout.preferredHeight:172;radius:28
                color:on ? Theme.secondaryContainer : Theme.alpha(Theme.light ? "#ffffff" : Theme.glassRaised,Theme.light ? .8 : .6)
                border.width:on ? 2 : 0;border.color:Theme.primary
                Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durMedium)}}
                Item {
                    x:12;y:12;width:parent.width-24;height:100
                    RoundedImage {anchors.fill:parent;radius:18;source:Hub.prefs.wallpaperPath||"";decodeSize:Qt.size(400,240)}
                    // A sheet and a bar, filled the way this preset fills them.
                    Rectangle {x:12;y:10;width:parent.width*.56;height:62;radius:12;color:Theme.alpha(Theme.level(1),card.modelData.sheet)
                        Column {x:10;y:12;spacing:6
                            Rectangle {width:56;height:7;radius:4;color:Theme.text;opacity:.7}
                            Rectangle {width:parent.parent.width-20;height:14;radius:6;color:Theme.alpha(Theme.level(3),card.modelData.sheet)}
                            Rectangle {width:parent.parent.width-20;height:14;radius:6;color:Theme.alpha(Theme.level(3),card.modelData.sheet)}}}
                    Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:8;anchors.horizontalCenter:parent.horizontalCenter;width:parent.width*.7;height:18;radius:9;color:Theme.alpha(Theme.glassIsland,card.modelData.bar)}
                }
                Row {x:16;y:122;spacing:8
                    Glyph {visible:card.on;name:"check_circle";font.pixelSize:20;color:Theme.primary;anchors.verticalCenter:parent.verticalCenter}
                    MText {text:card.modelData.title;role:"titleS";color:card.on ? Theme.onSecondaryContainer : Theme.text;anchors.verticalCenter:parent.verticalCenter}
                }
                MText {x:16;y:146;width:parent.width-32;text:card.modelData.detail;role:"labelS";color:Theme.subtext}
                MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:page.choose(card.modelData.id)}
                Accessible.role:Accessible.RadioButton;Accessible.name:modelData.title;Accessible.checked:on
            }
        }
    }
    RowLayout {
        Layout.fillWidth:true
        SettingsLabel {text:"Surfaces";Layout.fillWidth:true}
        Rectangle {visible:Theme.lookCustom;Layout.topMargin:12;implicitWidth:customLabel.implicitWidth+22;implicitHeight:26;radius:13;color:Theme.tertiaryContainer
            MText {id:customLabel;anchors.centerIn:parent;text:"Custom";role:"labelS";color:Theme.onTertiaryContainer}}
    }
    SettingsGroup {
        Repeater {
            model:page.surfaces
            SettingRow {
                required property var modelData
                icon:modelData.icon;title:modelData.title
                description:Theme.solid(modelData.id)!==Theme.presetIsSolid(Theme.look,modelData.id) ? "Changed from the preset" : ""
                SegmentedButtons {width:180;buttonHeight:36;current:Theme.solid(modelData.id)
                    options:[{value:false,label:"Glass"},{value:true,label:"Solid"}]
                    onPicked:value=>page.setSurface(modelData.id,value)}
            }
        }
    }
    SettingsGroup {title:"Effects"
        SettingToggle {icon:"blur_on";title:"Compositor blur";description:"Hyprland blurs what is behind glass surfaces";checked:Theme.blur;onToggled:Hub.set("lookBlur",!checked)}
        SettingToggle {icon:"auto_awesome";title:"Glass edges & sheen";description:"A light rim and a top highlight on glass";checked:Theme.edges;onToggled:Hub.set("lookEdges",!checked)}
        SettingToggle {icon:"shadow";title:"Elevation shadows";description:"A soft shadow under sheets, menus and the toolbar";checked:Theme.shadows;onToggled:Hub.set("lookShadows",!checked)}
        SettingToggle {icon:"opacity";title:"App transparency";description:"Off makes Kitty and other exported app themes opaque";checked:Theme.appTransparency;onToggled:Hub.set("lookAppTransparency",!checked)}
    }
    SettingsLabel {text:"Glass density · "+Math.round(Hub.prefs.glass*100)+"%"}
    ExpressiveSlider {Layout.fillWidth:true;implicitHeight:52;compact:true;trackHeight:40;icon:"opacity";iconAtHandle:true;from:45;to:100;value:Hub.prefs.glass*100;enabled:Theme.lookSurfaces.some(s=>!Theme.solid(s));onMoved:Hub.set("glass",Math.round(value)/100)}
}
