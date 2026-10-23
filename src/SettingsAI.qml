import QtQuick
import QtQuick.Layouts
// AI & assistant: one switch for every AI feature, the Claude Code connection and a full removal for people who want no AI.
SettingsPage {
    id:page
    readonly property bool on:Hub.aiEnabled
    readonly property var st:Hub.aiStatus||({})
    property bool confirm:false
    Component.onCompleted:Hub.command({action:"ai-status"})
    // Hero: the state at a glance. Off reads as a calm, finished choice, not a warning.
    Rectangle {
        Layout.fillWidth:true;Layout.preferredHeight:heroRow.implicitHeight+40;radius:28
        color:page.on ? Theme.primaryContainer : Theme.secondaryContainer
        Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durMedium)}}
        RowLayout {id:heroRow;anchors.fill:parent;anchors.margins:20;spacing:16
            MorphShape {Layout.preferredWidth:64;Layout.preferredHeight:64;shape:page.on ? 8 : 0;spin:page.on;fill:page.on ? Theme.onContainer : Theme.onSecondaryContainer
                Glyph {anchors.centerIn:parent;name:page.on ? "auto_awesome" : "block";font.pixelSize:30;color:page.on ? Theme.primaryContainer : Theme.secondaryContainer}}
            ColumnLayout {Layout.fillWidth:true;spacing:2
                MText {Layout.fillWidth:true;text:page.on ? "AI features are on" : "Opal is AI-free";role:"title";font.pixelSize:22;color:page.on ? Theme.onContainer : Theme.onSecondaryContainer;wrapMode:Text.Wrap}
                MText {Layout.fillWidth:true;role:"bodyS";wrapMode:Text.Wrap;color:Theme.alpha(page.on ? Theme.onContainer : Theme.onSecondaryContainer,.8)
                    text:page.on ? "Claude can answer in Start and act for you from the assistant panel. Nothing runs until you ask."
                        : "No assistant, no Ask Claude buttons and no AI answers in search. Opal is not connected to any AI tool."}}
        }
    }
    SettingsGroup {title:"AI features"
        SettingToggle {icon:"auto_awesome";title:"AI features";description:"The assistant panel, Ask Claude buttons, AI answers in search and the hold gestures that open them"
            checked:page.on;onToggled:Hub.command({action:page.on ? "ai-remove" : "ai-restore"})}
    }
    SettingsGroup {title:"Claude";visible:page.on
        SettingRow {icon:"terminal";title:"Claude Code"
            description:page.st.claude===false ? "Not installed. Opal uses your own Claude Code sign-in" : "Installed. Opal talks to Claude through it"
            MButton {visible:page.st.claude===false;text:"Install";filled:true;compact:true;onClicked:Hub.command({action:"assistant-install"})}}
        SettingRow {icon:"hub";title:"Opal tools for Claude Code";visible:page.st.claude===true
            description:page.st.mcp ? "Claude Code in a terminal can also use Opal: windows, settings and apps" : "Not connected. Turn AI features off and on again to connect"
            value:page.st.mcp ? "Connected" : "Off"}
        SettingRow {icon:"front_hand";title:"When Claude wants to change something";description:AssistantState.mode==="auto" ? "Risky actions still ask" : "Every action waits for your OK"
            SegmentedButtons {width:240;buttonHeight:40;current:AssistantState.mode
                options:[{value:"ask",label:"Ask first"},{value:"auto",label:"Just do it"}]
                onPicked:value=>AssistantState.setMode(value)}}
    }
    SettingsGroup {title:"What is off";visible:!page.on
        Repeater {model:[
            {i:"chat_bubble",t:"Assistant panel",d:"Super + A, the Copilot key and hold gestures do nothing"},
            {i:"search",t:"Search",d:"Start shows only local results and the web row"},
            {i:"touch_app",t:"Buttons and widgets",d:"No Ask Claude in captures, the tablet dock, the phone home or game mode"},
            {i:"link_off",t:"Claude Code",d:"Opal's tools and pills are removed from Claude Code. Claude Code itself stays installed"}]
            SettingRow {required property var modelData;icon:modelData.i;title:modelData.t;description:modelData.d}}
    }
    // Removal goes further than the switch: it also cleans AI entries out of gestures, the power key menu and game widgets.
    SettingsGroup {title:"Remove";visible:page.on
        SettingRow {icon:"delete_sweep";title:page.confirm ? "Remove every AI feature?" : "Remove all AI"
            description:"Turns AI off, takes Claude out of your gestures, power key menu and game widgets, and disconnects Claude Code"
            MButton {visible:page.confirm;text:"Keep";compact:true;onClicked:page.confirm=false}
            MButton {text:page.confirm ? "Remove" : "Remove all";compact:true;filled:page.confirm;accent:Theme.error;fillInk:Theme.base;ink:Theme.error
                onClicked:{if(page.confirm){page.confirm=false;Hub.command({action:"ai-remove"});}else page.confirm=true;}}}
    }
}
