import QtQuick
import QtQuick.Layouts
// Assign edge gestures: tap a zone on the phone outline, then choose what a swipe and a swipe-and-hold do there.
ColumnLayout {
    id:page
    property string zone:"leftUpper"
    readonly property var gestures:Hub.prefs.phoneGestures||({})
    spacing:12
    function assign(hold,id) { const next=Object.assign({},gestures);next[zone+(hold ? "Hold" : "")]=id;Hub.set("phoneGestures",next); }
    RowLayout {
        Layout.fillWidth:true;spacing:18
        // The phone: four edge zones, each showing its swipe action.
        Rectangle {
            id:phone
            Layout.preferredWidth:150;Layout.preferredHeight:290;radius:30
            color:Theme.level(1);border.width:2;border.color:Theme.alpha(Theme.text,.18)
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:12;width:46;height:6;radius:3;color:Theme.alpha(Theme.text,.2)}
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:10;width:52;height:5;radius:2.5;color:Theme.alpha(Theme.text,.35)}
            Repeater {model:PhoneState.edgeZones
                Item {
                    id:zoneItem
                    required property string modelData
                    readonly property bool leftSide:modelData.startsWith("left")
                    readonly property bool upper:modelData.endsWith("Upper")
                    readonly property bool chosen:page.zone===modelData
                    readonly property string action:PhoneState.gestureAction(modelData,false)
                    readonly property string held:PhoneState.gestureAction(modelData,true)
                    x:leftSide ? 0 : phone.width-width;y:upper ? 40 : phone.height/2+6
                    width:phone.width/2;height:phone.height/2-46
                    // The edge strip lights up for the chosen zone.
                    Rectangle {
                        x:zoneItem.leftSide ? 4 : parent.width-10;width:6;height:parent.height;radius:3
                        color:zoneItem.chosen ? Theme.primary : Theme.alpha(Theme.text,zoneItem.action==="none"&&zoneItem.held==="none" ? .08 : .25)
                        Behavior on color {ColorAnimation {duration:Theme.motion(Theme.durShort)}}
                    }
                    Rectangle {
                        anchors.verticalCenter:parent.verticalCenter
                        x:zoneItem.leftSide ? 16 : parent.width-width-16
                        width:zoneItem.chosen ? 44 : 34;height:width;radius:zoneItem.chosen ? 14 : width/2
                        color:zoneItem.chosen ? Theme.primary : Theme.level(3)
                        Behavior on width {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasized}}
                        Behavior on radius {NumberAnimation {duration:Theme.motion(Theme.durMedium)}}
                        Glyph {anchors.centerIn:parent;name:PhoneState.actionInfo(zoneItem.action).icon;font.pixelSize:zoneItem.chosen ? 22 : 18;color:zoneItem.chosen ? Theme.onPrimary : Theme.subtext}
                        // A small badge when the zone also has a hold action.
                        Rectangle {
                            visible:zoneItem.held!=="none";width:18;height:18;radius:9;x:parent.width-12;y:-6
                            color:Theme.tertiaryContainer;border.width:2;border.color:Theme.level(1)
                            Glyph {anchors.centerIn:parent;name:PhoneState.actionInfo(zoneItem.held).icon;font.pixelSize:11;color:Theme.onTertiaryContainer}
                        }
                    }
                    MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:page.zone=zoneItem.modelData}
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth:true;spacing:6
            MText {Layout.fillWidth:true;role:"title";wrapMode:Text.Wrap;text:(page.zone.startsWith("left") ? "Left" : "Right")+" edge, "+(page.zone.endsWith("Upper") ? "upper half" : "lower half")}
            MText {Layout.fillWidth:true;role:"bodyS";color:Theme.subtext;wrapMode:Text.Wrap
                text:"Swipe in from this part of the edge. Keep holding after the bubble fills for the second action."}
            MText {Layout.fillWidth:true;Layout.topMargin:6;role:"bodyS";color:Theme.subtext;wrapMode:Text.Wrap;visible:!!Hub.prefs.phoneButtons
                text:"Edge gestures are off while three-button navigation is on."}
        }
    }
    Repeater {
        model:[{hold:false,title:"Swipe"},{hold:true,title:"Swipe and hold"}]
        ColumnLayout {
            id:group
            required property var modelData
            Layout.fillWidth:true;spacing:6
            MText {text:group.modelData.title;role:"label";color:Theme.subtext}
            Flow {
                Layout.fillWidth:true;spacing:6
                Repeater {model:PhoneState.gestureActions
                    Chip {
                        required property var modelData
                        icon:modelData.icon;text:modelData.label
                        selected:PhoneState.gestureAction(page.zone,group.modelData.hold)===modelData.id
                        onClicked:page.assign(group.modelData.hold,modelData.id)
                    }
                }
            }
        }
    }
    MButton {Layout.alignment:Qt.AlignLeft;compact:true;tonal:true;icon:"restart_alt";text:"Back on every edge";onClicked:Hub.set("phoneGestures",{})}
}
