import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// The theme ripple mid-flight: Appearance in one theme, a tap on a gallery card, frames while the new theme spreads.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    readonly property var tokyo:({dark:{primary:"#7aa2f7",on_primary:"#1a1b26",primary_container:"#374465",on_primary_container:"#a9b1d6",secondary:"#ad8ee6",tertiary:"#eb927b",background:"#1a1b26",on_surface:"#a9b1d6",on_surface_variant:"#8187a5",surface_container:"#24283b",surface_container_high:"#2b2f43",outline_variant:"#292e42",error:"#f7768e"}})
    Window {
        id:fixture
        width:620;height:900;visible:true;color:"#000000"
        property int frame:0
        Rectangle {anchors.fill:parent;color:Opal.Theme.base
            Opal.Appearance {id:page;anchors.fill:parent;anchors.margins:16}
        }
        function shot(name,next) { fixture.contentItem.grabToImage(r=>{r.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT")+"/"+name+".png");next();}); }
        Timer {id:begin;interval:2500;running:true;onTriggered:{
            fixture.shot("reveal-0-before",()=>{
                Opal.Hub.withReveal(page,430,330,()=>{Opal.Hub.prefs=Object.assign({},Opal.Hub.prefs,{dynamicColors:true,dynamicPalette:root.tokyo,light:false,omarchyTheme:"tokyo-night"});});
                mid.start();
            });
        }}
        Timer {id:mid;interval:180;onTriggered:fixture.shot("reveal-1-early",()=>late.start())}
        Timer {id:late;interval:160;onTriggered:fixture.shot("reveal-2-mid",()=>done.start())}
        Timer {id:done;interval:900;onTriggered:fixture.shot("reveal-3-after",()=>{console.log("OFFSCREEN_TESTS_COMPLETE");Qt.quit();})}
    }
}
