import QtQuick
import QtQuick.Layouts
// Accessibility: motion, solid surfaces and how see-through the glass is.
SettingsPage {
    SettingsGroup {title:"Motion"
        SettingToggle {icon:"animation";title:"Reduce motion";description:"Remove transitions and decorative animation";checked:Theme.reduceMotion;onToggled:Hub.set("reduceMotion",!checked)}
    }
    SettingsGroup {title:"Readability"
        SettingToggle {icon:"layers";title:"Solid surfaces";description:"The Material look: nothing is see-through";checked:Theme.look==="material"&&!Theme.lookCustom;onToggled:{Hub.set("look",checked ? "glass" : "material");Hub.set("lookSurfaces",{});Hub.set("lookEdges",checked);Hub.set("lookShadows",!checked);}}
        SettingToggle {icon:"dark_mode";title:"Dark theme";checked:!Theme.light;onToggled:Hub.set("light",!Theme.light)}
    }
    SettingsLabel {text:"Surface opacity · "+Math.round(Hub.prefs.glass*100)+"%"}
    ExpressiveSlider {Layout.fillWidth:true;implicitHeight:52;compact:true;trackHeight:40;icon:"opacity";iconAtHandle:true;from:45;to:100;value:Hub.prefs.glass*100;onMoved:Hub.set("glass",Math.round(value)/100)}
}
