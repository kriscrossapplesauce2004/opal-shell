import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id:menu
    property var entries:[]
    readonly property alias popupWindow:window
    readonly property alias anchor:window.anchor
    signal opened()
    signal closed()
    visible:window.visible
    function openAt(item, localX, localY) {
        if(!item||entries.length===0)return;
        window.visible=false;
        // Use a compositor popup with an explicit pointer-sized anchor.
        // Qt Controls Menu.popup() can re-anchor to the entire layer window.
        window.anchor.item=item;
        window.anchor.rect.x=localX;
        window.anchor.rect.y=localY;
        window.anchor.rect.width=1;
        window.anchor.rect.height=1;
        window.visible=true;
        content.forceActiveFocus();
    }
    function popup() {if(parent)openAt(parent,0,parent.height);}
    function close() {window.visible=false;}
    PopupWindow {
        id:window
        visible:false
        grabFocus:true
        color:"transparent"
        implicitWidth:260
        implicitHeight:Math.min(rows.implicitHeight+16,screen ? screen.height-16 : 700)
        anchor.edges:Edges.Bottom|Edges.Right
        anchor.gravity:Edges.Bottom|Edges.Right
        onVisibleChanged:{if(visible)menu.opened();else menu.closed();}
        Rectangle {
            id:content;anchors.fill:parent;radius:18;color:Theme.surface
            border.width:1;border.color:Theme.outline
            Keys.onEscapePressed:menu.close()
            Flickable {
                anchors.fill:parent;anchors.margins:8
                contentHeight:rows.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                ScrollBar.vertical:ScrollBar {}
                Column {
                    id:rows;width:parent.width;spacing:0
                    Repeater {
                        model:menu.entries
                        delegate:ItemDelegate {
                            id:row
                            required property var modelData
                            width:rows.width;height:40
                            text:modelData.text
                            enabled:modelData.enabled!==false
                            contentItem:Row {
                                spacing:12
                                Glyph {width:22;height:row.availableHeight;name:row.modelData.icon||"next";font.pixelSize:20;color:Theme.primary}
                                MText {width:row.availableWidth-34;height:row.availableHeight;text:row.text;font.pixelSize:13;color:row.enabled ? Theme.text : Theme.muted}
                            }
                            background:Rectangle {radius:12;color:row.hovered||row.activeFocus ? Theme.primaryContainer : "transparent"}
                            onClicked:{const action=modelData.run;menu.close();if(action)action();}
                            Accessible.name:text
                        }
                    }
                }
            }
        }
    }
}
