import QtQuick
import QtQuick.Layouts

Item {
    id:bar
    property var output:null
    property bool fpsEnabled:false
    property int fps:0
    property alias pill:activityPill
    property var shownStatus:Hub.status
    // Tablet: a slim bar with smaller type and icons, spread a little wider.
    readonly property bool compact:!!output&&PhoneState.isTablet(output)
    readonly property int iconSize:compact ? 14 : 16
    implicitHeight:compact ? 34 : 48
    readonly property string timeText:Qt.formatDateTime(Hub.now,"HH:mm")
    readonly property string clockTooltip:Qt.formatDateTime(Hub.now,"dddd, d MMMM")+" · tap for notifications"
    readonly property string focusText:Math.ceil(Hub.focusSeconds/60)+"m focus"
    readonly property string audioIcon:shownStatus.playing ? "music" : shownStatus.muted ? "mute" : "volume"
    readonly property string networkIcon:shownStatus.wifi ? "wifi" : "wifiOff"
    readonly property string batteryText:shownStatus.battery>=0 ? (shownStatus.charging ? "+ " : "")+shownStatus.battery+"%" : ""
    readonly property string networkTooltip:"Quick Settings · "+(shownStatus.network||"Offline")+(shownStatus.charging ? " · Charging" : "")
    function show(page) {if(output)Hub.targetScreen=output;Hub.toggle(page);}
    Timer {id:statusFrame;interval:16;repeat:false;onTriggered:bar.shownStatus=Hub.status}
    Connections {target:Hub;function onStatusChanged(){if(!statusFrame.running)statusFrame.start();}}
    DragHandler {target:null;yAxis.enabled:true;xAxis.enabled:false;onActiveChanged:if(!active&&translation.y>24)bar.show("controls")}
    // Pointer hover lights a soft pill behind the half of the bar that a click opens.
    Rectangle {
        visible:bar.compact;opacity:leftHalf.containsMouse ? 1 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(120)}}
        x:12;y:3;height:parent.height-6;width:Math.min(parent.width/2-24,timeRowEnd.x+32);radius:height/2;color:Theme.alpha(Theme.text,.08)
    }
    Rectangle {
        visible:bar.compact;opacity:rightHalf.containsMouse ? 1 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(120)}}
        anchors.right:parent.right;anchors.rightMargin:12;y:3;height:parent.height-6;width:Math.min(parent.width/2-24,parent.width-28-iconsStart.x);radius:height/2;color:Theme.alpha(Theme.text,.08)
    }
    // Pixel status bar: the time and alerts on the left, plain system icons on the right. Each half is a tap target.
    RowLayout {
        anchors.fill:parent;anchors.leftMargin:bar.compact ? 28 : 22;anchors.rightMargin:bar.compact ? 26 : 20;spacing:bar.compact ? 12 : 8
        MText {text:bar.timeText;font.pixelSize:bar.compact ? 13 : 15;font.weight:Font.Medium;font.letterSpacing:bar.compact ? .4 : 0}
        Glyph {visible:Hub.unread>0;name:"notifications";font.pixelSize:15;color:Theme.subtext}
        MText {visible:Hub.unread>1;text:String(Math.min(99,Hub.unread));font.pixelSize:11;color:Theme.subtext}
        // Space for the activity pill. The pill itself floats above the bar so it can expand in place.
        Item {id:pillSlot;visible:activityPill.visible;Layout.preferredWidth:activityPill.width*activityPill.scale;Layout.preferredHeight:30}
        Item {id:timeRowEnd;width:1;height:1}
        MText {visible:bar.fpsEnabled;text:bar.fps+" FPS";font.pixelSize:11;font.weight:Font.DemiBold;color:Theme.primary}
        Item {Layout.fillWidth:true}
        Item {id:iconsStart;width:1;height:1}
        Glyph {visible:Hub.dnd;name:"do_not_disturb_on";font.pixelSize:bar.iconSize;color:Theme.text}
        Glyph {visible:!!bar.shownStatus.bluetooth;name:"bluetooth";font.pixelSize:bar.iconSize;color:Theme.text}
        Glyph {visible:bar.shownStatus.playing;name:"music_note";font.pixelSize:bar.iconSize;color:Theme.text}
        Glyph {name:bar.networkIcon;font.pixelSize:bar.iconSize;color:Theme.text}
        Glyph {visible:bar.shownStatus.battery>=0;name:bar.shownStatus.charging ? "battery_charging_full" : bar.shownStatus.battery<=15 ? "battery_alert" : "battery_full";font.pixelSize:bar.iconSize;color:bar.shownStatus.battery<=15&&!bar.shownStatus.charging ? Theme.error : Theme.text}
        MText {visible:bar.shownStatus.battery>=0;text:bar.shownStatus.battery+"%";font.pixelSize:bar.compact ? 12 : 13;font.weight:Font.Medium}
    }
    MouseArea {
        id:leftHalf
        anchors.left:parent.left;anchors.top:parent.top;anchors.bottom:parent.bottom;width:parent.width/2
        hoverEnabled:true;cursorShape:Qt.PointingHandCursor
        onClicked:bar.show("notifications")
        onPressAndHold:Hub.set("dnd",!Hub.dnd)
        Accessible.role:Accessible.Button;Accessible.name:bar.clockTooltip
    }
    MouseArea {
        id:rightHalf
        anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:parent.bottom;width:parent.width/2
        hoverEnabled:true;cursorShape:Qt.PointingHandCursor
        onClicked:bar.show("controls")
        onPressAndHold:bar.show("convergence")
        Accessible.role:Accessible.Button;Accessible.name:bar.networkTooltip
    }
    // Live activities: the top one as a chip and a count. Tap opens the shade with that card on top.
    ActivityChip {
        id:activityPill
        visible:Activities.list.length>0
        a:Activities.primary||({})
        more:Math.max(0,Activities.list.length-1)
        width:Math.min(implicitWidth,bar.width*.45)
        // The slim tablet bar shows the pill a little smaller.
        scale:bar.compact ? .84 : 1;transformOrigin:Item.Left
        x:Math.max(10,Math.min(pillSlot.mapToItem(bar,0,0).x,bar.width-width-10))
        y:(bar.height-height)/2
        onClicked:Activities.show(Activities.primary,bar.output)
    }

}
