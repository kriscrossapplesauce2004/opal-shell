import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// The portal file picker over the sandbox home that render-offscreen.sh builds (generated wallpapers in Pictures).
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property string home:Quickshell.env("HOME")
    readonly property var filters:[{name:"All files",globs:["*"],mimes:[]},{name:"Images",globs:["*.png","*.jpg"],mimes:["image/*"]}]
    Window {
        id:fixture
        width:412;height:915;visible:true;color:"#000000"
        property int step:0
        property var cases:[
            {name:"portal-phone-open",request:{kind:"open",title:"Open image",app:"org.inkscape.Inkscape",multiple:true,filters:root.filters,filter:1,folder:root.home+"/Pictures/Wallpapers"},pick:2},
            {name:"portal-phone-list",request:{kind:"open",title:"Attach files",app:"firefox",multiple:true,filters:[],filter:-1,folder:root.home+"/Pictures"},view:"list"},
            {name:"portal-phone-save",request:{kind:"save",title:"Save drawing",app:"org.inkscape.Inkscape",filters:root.filters,filter:0,folder:root.home+"/Pictures",name:"Ocean.png"},check:true},
            {name:"portal-phone-light",request:{kind:"open",title:"Open image",app:"org.gnome.Loupe",filters:[],filter:-1,folder:root.home+"/Pictures/Wallpapers"},light:true,pick:1},
            {name:"portal-tablet",request:{kind:"open",title:"Open",app:"org.kde.krita",multiple:false,filters:root.filters,filter:1,folder:root.home+"/Pictures/Wallpapers"},w:1280,h:800,pick:1},
            {name:"portal-desktop-sheet",request:{kind:"open",title:"Upload",app:"chromium",multiple:true,filters:[],filter:-1,folder:root.home+"/Pictures/Wallpapers"},w:1440,h:900,desktop:true,pick:3}
        ]
        property var current:cases[0]
        Rectangle {anchors.fill:parent;color:"#2a4a5e";visible:!!fixture.current.desktop
            Rectangle {anchors.fill:parent;color:"#000000";opacity:.42}}
        Loader {id:loader;anchors.centerIn:parent;width:fixture.current.desktop ? Math.min(parent.width-48,1040) : parent.width;height:fixture.current.desktop ? Math.min(parent.height-48,720) : parent.height}
        Component {id:pickerView;Opal.FilePicker {touch:!fixture.current.desktop}}
        function run() {
            if(step>=cases.length){console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();return;}
            const c=cases[step];current=c;
            Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{light:!!c.light,portalView:c.view||"grid"});
            Opal.Hub.portalFolder=null;Opal.Hub.portalSaveCheck=null;
            Opal.Hub.portalRequest=Object.assign({token:"t"+step},c.request);
            fixture.width=c.w||412;fixture.height=c.h||915;
            loader.sourceComponent=null;loader.sourceComponent=pickerView;
            grab.restart();
        }
        Timer {id:grab;interval:2200;onTriggered:{
            const c=fixture.current,p=loader.item;
            // Select some files the way a long-press would.
            if(c.pick&&p) {const files=p.entries.filter(e=>!e.dir);p.selecting=c.request.multiple===true;p.selected=files.slice(0,c.pick).map(e=>e.uri);}
            if(c.check&&p) p.confirmReplace=p.folder.folder+"/Ocean.png";
            shot.restart();}}
        Timer {id:shot;interval:600;onTriggered:fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+fixture.cases[fixture.step].name+".png");fixture.step++;fixture.run();})}
        Component.onCompleted:Qt.callLater(run)
    }
}
