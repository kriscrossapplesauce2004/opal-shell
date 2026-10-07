import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "src" as Opal

// Navigation bar prototypes for tablets and phones. Static data only. Run: OPAL_ENTRY=navbar-proto.qml bash tests/render-offscreen.sh
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string pap:"/usr/share/icons/Papirus/64x64/apps/"
    function icon(n) {
        const fixed={kitty:"/usr/share/pixmaps/kitty.png",steam:"/usr/share/pixmaps/steam.png",chrome:pap+"google-chrome.svg",files:pap+"org.gnome.Nautilus.svg",dolphin:pap+"org.kde.dolphin.svg",kate:pap+"org.kde.kate.svg"};
        return "file://"+(fixed[n]||pap+n+".svg");
    }
    readonly property var apps:[{n:"chrome",run:true},{n:"kitty",run:true,front:true,name:"kitty"},{n:"files",run:true},{n:"kate"},{n:"steam"}]
    Window {
        id:fixture
        width:1280;height:200;visible:true;color:"#000"
        property int step:0
        property var cases:[
            {name:"nav-tablet-a-islands",view:tabA,w:1280,h:200},
            {name:"nav-tablet-b-pill",view:tabB,w:1280,h:200},
            {name:"nav-tablet-c-flat",view:tabC,w:1280,h:200},
            {name:"nav-tablet-a-light",view:tabA,w:1280,h:200,light:true},
            {name:"nav-tablet-d-wide-islands",view:tabD,w:1280,h:200},
            {name:"nav-tablet-d-wide-islands-light",view:tabD,w:1280,h:200,light:true},
            {name:"nav-mix-1-two-rows",view:mix1,w:412,h:240,bar:128},
            {name:"nav-mix-2-strip-in-pill",view:mix2,w:412,h:240,bar:128},
            {name:"nav-mix-3-one-row",view:mix3,w:412,h:200,bar:84},
            {name:"nav-mix-1-two-rows-light",view:mix1,w:412,h:240,bar:128,light:true},
            {name:"nav-phone-a",view:phA,w:412,h:200},
            {name:"nav-phone-b",view:phB,w:412,h:200},
            {name:"nav-phone-c-gesture",view:phC,w:412,h:200}
        ]
        Image {anchors.fill:parent;source:"file:///home/melissa/Pictures/Wallpapers/default.png";sourceSize:Qt.size(1600,1600);fillMode:Image.PreserveAspectCrop;verticalAlignment:Image.AlignBottom}
        // A slice of an app above the bar, so the bar is seen over content.
        Rectangle {x:0;y:0;width:parent.width;height:parent.height-loader.height;color:"#0d0f12"
            Text {x:20;y:16;text:"~/opal $ claude\n✻ Rendering navigation bar prototypes…";color:"#cfd2d6";font.family:"CaskaydiaCove Nerd Font";font.pixelSize:13}}
        Loader {id:loader;anchors.bottom:parent.bottom;width:parent.width;height:fixture.barH}
        property int barH:84
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const c=cases[step];width=c.w;height=c.h;barH=c.bar||84;
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:!!c.light});
            loader.sourceComponent=null;loader.sourceComponent=c.view;grab.restart();
        }
        Timer {id:grab;interval:1100;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }

    component Ico:Image {property string n:"";source:n ? root.icon(n) : "";sourceSize:Qt.size(96,96);smooth:true;fillMode:Image.PreserveAspectFit}
    // Back, home and recents drawn as outlines.
    component Keys:Row {
        property real gap:4
        property int size:44
        spacing:gap
        Item {width:parent.size;height:parent.size;Opal.Glyph {anchors.centerIn:parent;name:"play_arrow";rotation:180;font.pixelSize:24;color:Opal.Theme.text}}
        Item {width:parent.size;height:parent.size;Rectangle {anchors.centerIn:parent;width:18;height:18;radius:9;color:"transparent";border.width:2.5;border.color:Opal.Theme.text}}
        Item {width:parent.size;height:parent.size;Rectangle {anchors.centerIn:parent;width:16;height:16;radius:4;color:"transparent";border.width:2.5;border.color:Opal.Theme.text}}
    }
    // App icon; the app in front grows into a chip with its name.
    component AppSlot:Item {
        property var app:null
        property bool showName:true
        property int size:40
        width:app&&app.front&&showName ? chipRow.implicitWidth+20 : size+12;height:size+12
        Rectangle {anchors.fill:parent;radius:height/2;visible:!!app&&!!app.front;color:Opal.Theme.secondaryContainer}
        Row {id:chipRow;anchors.centerIn:parent;spacing:8
            Ico {n:parent.parent.app ? parent.parent.app.n : "";width:parent.parent.size-6;height:width;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {visible:!!parent.parent.app&&!!parent.parent.app.front&&parent.parent.showName;text:parent.parent.app&&parent.parent.app.name ? parent.parent.app.name : "";role:"label";color:Opal.Theme.onSecondaryContainer;anchors.verticalCenter:parent.verticalCenter}}
        Rectangle {visible:!!app&&!!app.run&&!app.front;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:-2;width:5;height:5;radius:2.5;color:Opal.Theme.primary}
    }
    component Island:Rectangle {radius:height/2;color:Opal.Theme.alpha(Opal.Theme.level(2),.94);border.width:1;border.color:Opal.Theme.outline}
    component RoundButton:Rectangle {
        property string icon:""
        property bool filled:false
        width:44;height:44;radius:22;color:filled ? Opal.Theme.primaryContainer : "transparent"
        Opal.Glyph {anchors.centerIn:parent;name:parent.icon;font.pixelSize:22;color:parent.filled ? Opal.Theme.containerInk : Opal.Theme.text}
    }
    component RoomChip:Rectangle {
        height:40;width:rr.implicitWidth+24;radius:20;color:Opal.Theme.alpha(Opal.Theme.text,.06)
        Row {id:rr;anchors.centerIn:parent;spacing:6
            Opal.Glyph {name:"space_dashboard";font.pixelSize:17;color:Opal.Theme.primary;anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:"1 · opal";role:"label";anchors.verticalCenter:parent.verticalCenter}
            Opal.MText {text:"+2";role:"labelS";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}
    }

    // Tablet D: islands that share the full width. The app island grows into the free space.
    Component {id:tabD
        Item {
            Island {id:leftD;x:12;anchors.verticalCenter:parent.verticalCenter;height:60;width:keysD.width+24;Keys {id:keysD;anchors.centerIn:parent}}
            Island {id:rightD;anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;height:60;width:rightRow.implicitWidth+20
                Row {id:rightRow;anchors.centerIn:parent;spacing:6
                    RoomChip {anchors.verticalCenter:parent.verticalCenter}
                    RoundButton {icon:"auto_awesome";anchors.verticalCenter:parent.verticalCenter}
                    RoundButton {icon:"apps";filled:true;anchors.verticalCenter:parent.verticalCenter}}}
            Island {
                anchors {left:leftD.right;right:rightD.left;leftMargin:8;rightMargin:8;verticalCenter:parent.verticalCenter}
                height:60
                Row {x:10;anchors.verticalCenter:parent.verticalCenter;spacing:4
                    Repeater {model:root.apps;AppSlot {required property var modelData;app:modelData}}}
                Rectangle {anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;height:44;width:sd.implicitWidth+28;radius:22;color:Opal.Theme.alpha(Opal.Theme.text,.06)
                    Row {id:sd;anchors.centerIn:parent;spacing:8;Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext} Opal.MText {text:"Search";role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
            }
        }
    }
    // Phone mix 1: recent apps float above; below, the front-app chip, the keys pill and Claude.
    Component {id:mix1
        Item {
            Row {anchors.horizontalCenter:parent.horizontalCenter;y:6;spacing:6
                Repeater {model:root.apps.filter(a=>!a.front);AppSlot {required property var modelData;app:modelData;size:30}}}
            Island {x:10;y:62;height:52;width:frontRow.implicitWidth+24
                Row {id:frontRow;anchors.centerIn:parent;spacing:8;Ico {n:"kitty";width:28;height:28;anchors.verticalCenter:parent.verticalCenter} Opal.MText {text:"kitty";role:"label";anchors.verticalCenter:parent.verticalCenter}}}
            Island {anchors.horizontalCenter:parent.horizontalCenter;anchors.horizontalCenterOffset:14;y:62;height:52;width:km.width+20;Keys {id:km;anchors.centerIn:parent;size:40}}
            Island {anchors.right:parent.right;anchors.rightMargin:10;y:62;width:52;height:52;Opal.Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:22}}
        }
    }
    // Phone mix 2: one island holds the recent apps, with the front app as a named chip; the keys pill sits under it.
    Component {id:mix2
        Item {
            Island {anchors.horizontalCenter:parent.horizontalCenter;y:4;height:52;width:stripRow.implicitWidth+16
                Row {id:stripRow;anchors.centerIn:parent;spacing:2;Repeater {model:root.apps.slice(0,4);AppSlot {required property var modelData;app:modelData;size:30}}}}
            Island {anchors.horizontalCenter:parent.horizontalCenter;y:66;height:52;width:km2.width+20;Keys {id:km2;anchors.centerIn:parent;size:40}}
            Island {x:10;y:66;width:52;height:52;Opal.Glyph {anchors.centerIn:parent;name:"apps";font.pixelSize:22}}
            Island {anchors.right:parent.right;anchors.rightMargin:10;y:66;width:52;height:52;Opal.Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:22}}
        }
    }
    // Phone mix 3: one row. The front app chip carries the recent apps as small icons beside its name.
    Component {id:mix3
        Item {
            Island {x:10;anchors.verticalCenter:parent.verticalCenter;height:52;width:m3.implicitWidth+20
                Row {id:m3;anchors.centerIn:parent;spacing:4
                    AppSlot {app:root.apps[1];size:30}
                    Repeater {model:root.apps.filter(a=>a.run&&!a.front);AppSlot {required property var modelData;app:modelData;size:26}}}}
            Island {anchors.right:claude3.left;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;height:52;width:k3.width+16;Keys {id:k3;anchors.centerIn:parent;size:38;gap:0}}
            Island {id:claude3;anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;width:52;height:52;Opal.Glyph {anchors.centerIn:parent;name:"auto_awesome";font.pixelSize:22}}
        }
    }
    // Tablet A: islands.
    Component {id:tabA
        Item {
            Island {x:12;anchors.verticalCenter:parent.verticalCenter;height:60;width:keysA.width+24;Keys {id:keysA;anchors.centerIn:parent}}
            Island {anchors.centerIn:parent;height:60;width:appsA.implicitWidth+20
                Row {id:appsA;anchors.centerIn:parent;spacing:4;Repeater {model:root.apps;AppSlot {required property var modelData;app:modelData}}}}
            Island {anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;height:60;width:rightA.implicitWidth+20
                Row {id:rightA;anchors.centerIn:parent;spacing:6
                    RoomChip {anchors.verticalCenter:parent.verticalCenter}
                    RoundButton {icon:"auto_awesome";anchors.verticalCenter:parent.verticalCenter}
                    RoundButton {icon:"apps";filled:true;anchors.verticalCenter:parent.verticalCenter}}}
        }
    }
    // Tablet B: one pill with everything, keys at the end.
    Component {id:tabB
        Item {
            Island {anchors.centerIn:parent;height:64;width:rowB.implicitWidth+24
                Row {id:rowB;anchors.centerIn:parent;spacing:8
                    RoundButton {icon:"apps";filled:true;anchors.verticalCenter:parent.verticalCenter}
                    Rectangle {width:1;height:32;color:Opal.Theme.outline;anchors.verticalCenter:parent.verticalCenter}
                    Repeater {model:root.apps;AppSlot {required property var modelData;app:modelData;anchors.verticalCenter:parent.verticalCenter}}
                    Rectangle {width:1;height:32;color:Opal.Theme.outline;anchors.verticalCenter:parent.verticalCenter}
                    RoomChip {anchors.verticalCenter:parent.verticalCenter}
                    RoundButton {icon:"auto_awesome";anchors.verticalCenter:parent.verticalCenter}
                    Rectangle {width:1;height:32;color:Opal.Theme.outline;anchors.verticalCenter:parent.verticalCenter}
                    Keys {size:40;gap:0;anchors.verticalCenter:parent.verticalCenter}}}
        }
    }
    // Tablet C: refined flat bar.
    Component {id:tabC
        Rectangle {
            color:Opal.Theme.alpha(Opal.Theme.dockTint,.92)
            Rectangle {width:parent.width;height:1;color:Opal.Theme.outline}
            Keys {x:16;anchors.verticalCenter:parent.verticalCenter}
            Row {anchors.centerIn:parent;spacing:6;Repeater {model:root.apps;AppSlot {required property var modelData;app:modelData;showName:false;size:44}}}
            Row {anchors.right:parent.right;anchors.rightMargin:16;anchors.verticalCenter:parent.verticalCenter;spacing:8
                Rectangle {height:44;width:sr.implicitWidth+28;radius:22;color:Opal.Theme.alpha(Opal.Theme.text,.07);anchors.verticalCenter:parent.verticalCenter
                    Row {id:sr;anchors.centerIn:parent;spacing:8;Opal.Glyph {name:"search";font.pixelSize:20;color:Opal.Theme.subtext} Opal.MText {text:"Search";role:"label";color:Opal.Theme.subtext;anchors.verticalCenter:parent.verticalCenter}}}
                RoundButton {icon:"auto_awesome";anchors.verticalCenter:parent.verticalCenter}}
        }
    }
    // Phone A: keys in a tonal pill with the front app as a chip on the left and Claude on the right.
    Component {id:phA
        Item {
            AppSlot {x:12;anchors.verticalCenter:parent.verticalCenter;app:root.apps[1];size:32}
            Island {anchors.centerIn:parent;height:52;width:keysPA.width+20;Keys {id:keysPA;anchors.centerIn:parent;size:40;gap:2}}
            RoundButton {anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter;icon:"auto_awesome"}
        }
    }
    // Phone B: flat keys spread wide, with a recent-app strip above them.
    Component {id:phB
        Rectangle {
            color:Opal.Theme.alpha(Opal.Theme.dockTint,.92)
            Row {anchors.horizontalCenter:parent.horizontalCenter;y:6;spacing:10
                Repeater {model:root.apps.filter(a=>a.run);AppSlot {required property var modelData;app:modelData;showName:false;size:24}}}
            Keys {anchors.horizontalCenter:parent.horizontalCenter;y:38;size:44;gap:56}
        }
    }
    // Phone C: gesture handle with the front app chip that the handle switches.
    Component {id:phC
        Item {
            Rectangle {anchors.centerIn:parent;anchors.verticalCenterOffset:-10;height:40;width:pc.implicitWidth+28;radius:20;color:Opal.Theme.alpha(Opal.Theme.level(2),.94);border.width:1;border.color:Opal.Theme.outline
                Row {id:pc;anchors.centerIn:parent;spacing:10
                    Ico {n:"chrome";width:20;height:20;opacity:.55;anchors.verticalCenter:parent.verticalCenter}
                    Row {spacing:6;anchors.verticalCenter:parent.verticalCenter;Ico {n:"kitty";width:24;height:24} Opal.MText {text:"kitty";role:"label";anchors.verticalCenter:parent.verticalCenter}}
                    Ico {n:"files";width:20;height:20;opacity:.55;anchors.verticalCenter:parent.verticalCenter}}}
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:8;width:120;height:5;radius:3;color:Opal.Theme.alpha(Opal.Theme.text,.75)}
        }
    }
}
