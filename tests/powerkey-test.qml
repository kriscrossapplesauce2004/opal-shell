import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// Beauty shots of the real power key menu, lock screen and Settings page. Live state is set directly; no backend calls.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string home:"file:///home/melissa/.local/state/opal/artifacts/launcher-prototypes/round4/r4-01-phone-home.png"
    readonly property string desk:"file:///home/melissa/.local/state/opal/artifacts/beauty-shots/reference-desktop-dark.png"
    readonly property var custom:[{action:"flashlight"},{action:"screenshot"},{action:"sleep"},{action:"power"},{action:"media"},{action:"displays"},{action:"contacts"},
        {action:"assistant"},{action:"folder",label:"Toggles",items:[{action:"dnd"},{action:"rotation-lock"},{action:"airplane"}]},{action:"command",label:"Sync dotfiles",command:"~/bin/dots-sync"},{action:"switch-user"}]
    readonly property var people:[{uid:"1",name:"Ada Lovelace",phones:["+44 20 7946 0000"],emails:["ada@example.org"],favourite:true},
        {uid:"2",name:"Grace Hopper",phones:["+1 202 555 0142"],emails:[],favourite:true},{uid:"3",name:"Alan Turing",phones:["+44 161 555 0199"],emails:[],favourite:true},
        {uid:"4",name:"Katherine Johnson",phones:["+1 757 555 0110"],emails:["kj@example.org"],favourite:true},{uid:"5",name:"Linus Torvalds",phones:[],emails:["linus@example.org"]}]

    Window {
        id:fixture
        width:480;height:960;visible:true;color:"#0b0a0d"
        property int step:0
        property var cases:[
            {name:"pk-01-phone-menu",view:phoneView,index:2,ring:.55},
            {name:"pk-02-power-submenu",view:phoneView,index:1,stack:[{action:"power"}]},
            {name:"pk-03-contacts",view:phoneView,index:1,stack:[{action:"contacts"}]},
            {name:"pk-04-contact-actions",view:phoneView,index:1,stack:[{action:"contacts"},{action:"contact",uid:"1"}]},
            {name:"pk-05-custom-menu",view:phoneView,index:2,ring:.2,tree:"custom"},
            {name:"pk-06-locked",view:lockView,index:2,ring:.4},
            {name:"pk-07-settings",view:settingsView},
            {name:"pk-08-settings-add",view:settingsView,sheet:"add",tree:"custom"},
            {name:"pk-09-desktop-shortcut",view:desktopView,index:2,w:1600,h:900,source:"shortcut"}
        ]
        property var current:cases[0]
        Loader {id:loader;anchors.fill:parent}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const c=cases[step];current=c;
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:false,powerMenu:c.tree==="custom" ? root.custom : [],powerMenuStart:"sleep",powerMenuCountdown:2000,
                powerPress:{double:{action:"flashlight"},hold:{action:"assistant"}},powerContacts:[],mode:"phone"});
            Opal.Hub.status=Object.assign({},Opal.Hub.status,{track:"The Keyboard Is Dead",artist:"Ben Vallack",playing:true});
            Opal.PowerKey.device={enabled:true,handset:c.source!=="shortcut",power:{edge:"right",at:.3},volume:{edge:"left",at:.26}};
            Opal.PowerKey.contacts=root.people;
            Opal.PowerKey.source=c.source||"key";
            Opal.PowerKey.stack=c.stack||[];
            Opal.PowerKey.index=c.index||0;
            Opal.PowerKey.open=c.view!==settingsView;
            Opal.PowerKey.countdown=c.ring===undefined ? -1 : c.ring;
            Opal.Hub.locked=c.view===lockView;
            fixture.width=c.w||480;fixture.height=c.h||960;
            loader.sourceComponent=null;loader.sourceComponent=c.view;
            grab.restart();
        }
        // The sandbox backend reports this computer's keys, so the OnePlus 7 layout is set again just before each grab.
        Timer {id:grab;interval:1800;onTriggered:{const c=fixture.current;Opal.PowerKey.device={enabled:c.source!=="shortcut",handset:c.source!=="shortcut",power:{edge:"right",at:.3},volume:{edge:"left",at:.26}};Opal.PowerKey.contacts=root.people;Opal.Hub.status=Object.assign({},Opal.Hub.status,{track:"The Keyboard Is Dead",artist:"Ben Vallack",playing:true});shot.restart();}}
        Timer {id:shot;interval:120;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    // A OnePlus 7 shaped body: volume rocker on the left, alert slider and power key on the right.
    component Body:Item {
        default property alias content:screen.data
        anchors.fill:parent
        Rectangle {x:12;y:16+900*.26-60;width:8;height:120;radius:3;color:"#2a272e"}
        Rectangle {x:parent.width-20;y:150;width:8;height:56;radius:3;color:"#2a272e"}
        Rectangle {x:parent.width-20;y:16+900*.3-26;width:8;height:76;radius:3;color:"#3a2f2a"}
        Rectangle {
            x:18;y:12;width:parent.width-36;height:parent.height-24;radius:52;color:"#141216";border.width:2;border.color:"#2a272e"
            Item {id:screen;x:16;y:16;width:412;height:900;clip:true}
        }
    }
    Component {id:phoneView
        Body {
            Image {anchors.fill:parent;source:root.home;fillMode:Image.PreserveAspectCrop}
            Opal.PowerMenu {anchors.fill:parent}
        }
    }
    Component {id:lockView
        Body {
            Opal.LockScene {anchors.fill:parent;mode:"lock";userName:"melissa"}
        }
    }
    Component {id:settingsView
        Body {
            Rectangle {anchors.fill:parent;color:Opal.Theme.base}
            Opal.SettingsPowerKey {
                anchors.fill:parent;anchors.topMargin:40;anchors.leftMargin:14;anchors.rightMargin:14
                Component.onCompleted:sheet=fixture.current.sheet||""
            }
        }
    }
    Component {id:desktopView
        Item {
            Image {anchors.fill:parent;source:root.desk;fillMode:Image.PreserveAspectCrop}
            Opal.PowerMenu {anchors.fill:parent}
        }
    }
}
