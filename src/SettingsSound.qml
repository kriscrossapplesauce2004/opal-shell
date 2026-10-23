import QtQuick
import QtQuick.Layouts
// Sound: output volume, mutes, what is playing and the mixers.
SettingsPage {
    SettingsLabel {text:"Output · "+(Hub.status.audioOutput||"Default device")}
    RowLayout {Layout.fillWidth:true;Layout.bottomMargin:10;spacing:10
        ExpressiveSlider {Layout.fillWidth:true;implicitHeight:56;compact:true;trackHeight:44;icon:Hub.status.muted ? "mute" : "volume";iconAtHandle:true;value:Hub.status.volume;activeColor:Hub.status.muted ? Theme.subtext : Theme.primary;onMoved:Hub.volume(value);Accessible.name:"Output volume"}
        MText {Layout.preferredWidth:44;horizontalAlignment:Text.AlignRight;text:Hub.status.volume+"%";role:"titleS";font.features:{"tnum":1}}
    }
    SettingsGroup {
        SettingToggle {icon:"volume_off";title:"Mute output";checked:!!Hub.status.muted;onToggled:Hub.command({action:"mute"})}
        SettingToggle {icon:"mic_off";title:"Mute microphone";description:"Applies to the default input device";checked:!!Hub.status.micMuted;onToggled:Hub.command({action:"mic"})}
    }
    SettingsLabel {visible:Hub.status.track!=="";text:"Now playing"}
    MediaCard {visible:Hub.status.track!=="";Layout.fillWidth:true;Layout.preferredHeight:150;compact:true}
    SettingsGroup {title:"More"
        SettingRow {icon:"graphic_eq";title:"Sound drawer";description:"Outputs, apps and players";chevron:true;onActivated:Hub.openAudio(Hub.targetScreen)}
        SettingRow {icon:"tune";title:"Advanced mixer";description:"Opens the system volume control";chevron:true;onActivated:Hub.settings("audio")}
    }
}
