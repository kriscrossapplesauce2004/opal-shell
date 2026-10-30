import QtQuick
import QtQuick.Layouts
import Quickshell

// Session and power menu with grouped rows; Log out, Restart and Shut down show a confirm step first.
Item {
    id:ps
    // An empty page is closed, "menu" shows the rows, and a verb shows its confirm step.
    property string page:""
    // desktop, touch, tv or card. A card is the small lock screen menu that sizes itself to its content.
    property string form:"desktop"
    property var verbs:["lock","logout","suspend","reboot","poweroff"]
    // When direct is false, the host runs each verb from the run signal.
    property bool direct:true
    // Set to false on the login screen, where no apps are open.
    property bool session:true
    property real radius:28
    signal run(string verb)
    readonly property bool controllerModal:true
    readonly property bool card:form==="card"
    readonly property real s:form==="tv" ? 1.25 : form==="touch" ? 1.15 : 1
    // On a tall touch screen the content sits low, near the thumb.
    readonly property bool thumb:form==="touch"&&height>width*1.3
    readonly property var catalog:({
        lock:{label:"Lock",icon:"lock",group:"Session",key:"Super+L"},
        logout:{label:"Log out",icon:"logout",group:"Session",ask:"Log out now?"},
        suspend:{label:"Sleep",icon:"sleep",group:"Power"},
        reboot:{label:"Restart",icon:"restart",group:"Power",ask:"Restart now?"},
        poweroff:{label:"Shut down",icon:"power",group:"Power",ask:"Shut down now?",danger:true}
    })
    // One flat list, ordered by group. Each row knows whether it opens or closes its group, for the header and the corners.
    readonly property var rows:{
        const heads=[],byHead={};
        for(const v of verbs){
            const e=catalog[v];if(!e)continue;
            if(!byHead[e.group]){byHead[e.group]=[];heads.push(e.group);}
            byHead[e.group].push(Object.assign({id:v},e));
        }
        const out=[];
        for(const h of heads)byHead[h].forEach((r,i,a)=>out.push(Object.assign(r,{first:i===0,last:i===a.length-1})));
        return out;
    }
    KeyedListModel {id:rowModel}
    onRowsChanged:rowModel.sync(rows)
    Component.onCompleted:rowModel.sync(rows)
    readonly property var asking:page!==""&&page!=="menu" ? catalog[page]||null : null
    readonly property color accent:asking&&asking.danger ? Theme.error : Theme.primary
    readonly property color accentInk:asking&&asking.danger ? (Theme.light ? "#ffffff" : "#690005") : Theme.onPrimary
    readonly property color dangerFill:Theme.mix(Theme.level(2),Theme.error,Theme.light ? .12 : .2)
    readonly property real fitHeight:(asking ? confirm.implicitHeight : list.implicitHeight)+(card ? 20 : 40)
    implicitHeight:fitHeight

    property real reveal:page!=="" ? 1 : 0
    Behavior on reveal {NumberAnimation {duration:Theme.motion(200);easing.type:Easing.OutCubic}}
    visible:reveal>0
    opacity:reveal

    function pick(id) {
        const e=catalog[id];if(!e)return;
        if(e.ask)page=id;else act(id);
    }
    function act(verb) {
        page="";
        if(!direct){run(verb);return;}
        if(verb==="lock"){Hub.close();Hub.lock();}
        else {Hub.command({action:"power",verb:verb});Hub.close();}
    }
    function back() {page=asking ? "menu" : "";}
    // The sheet itself takes the keyboard, so nothing looks selected until a key moves to a row.
    function focusFirst() {Qt.callLater(()=>ps.forceActiveFocus());}
    function step(down) {
        const to=asking ? (cancelButton.activeFocus ? confirmButton : cancelButton) : list.first;
        if(to)to.forceActiveFocus(Qt.TabFocusReason);
    }
    // Set to false where another field must keep the keyboard, as on the lock screen.
    property bool takeFocus:true
    onPageChanged:if(page!==""&&takeFocus)focusFirst()
    Keys.onEscapePressed:event=>{back();event.accepted=true;}
    Keys.onUpPressed:step(false)
    Keys.onDownPressed:step(true)

    Rectangle {anchors.fill:parent;radius:ps.radius;color:Theme.level(2)}
    // Taps on blank space stay in the sheet.
    MouseArea {anchors.fill:parent}

    ColumnLayout {
        id:list
        property Item first:null
        readonly property real fullWidth:Math.min(ps.width-(ps.card ? 20 : 32),460*ps.s)
        x:(ps.width-width)/2;width:fullWidth
        y:ps.card ? 10 : ps.thumb ? ps.height-implicitHeight-28 : ps.form==="desktop" ? 20 : Math.max(20,(ps.height-implicitHeight)/2)
        spacing:2*ps.s
        opacity:ps.asking ? 0 : 1
        visible:opacity>0
        Behavior on opacity {NumberAnimation {duration:Theme.motion(160)}}

        RowLayout {
            visible:!ps.card;Layout.fillWidth:true;Layout.leftMargin:8;Layout.bottomMargin:10*ps.s;spacing:8
            ColumnLayout {
                Layout.fillWidth:true;spacing:2
                MText {text:"Power";role:"headline";font.pixelSize:26*ps.s}
                MText {
                    readonly property string user:Quickshell.env("USER")||""
                    Layout.fillWidth:true;role:"bodyS";font.pixelSize:13*ps.s;color:Theme.subtext
                    text:[user,Hub.status.uptime ? "up "+Hub.status.uptime : ""].filter(t=>t!=="").join(" · ")
                    visible:text!==""
                }
            }
            MButton {visible:ps.form!=="tv";icon:"close";compact:true;contained:true;implicitWidth:40*ps.s;implicitHeight:40*ps.s;tooltip:"Close";onClicked:ps.page=""}
        }

        Repeater {
            model:rowModel
            ColumnLayout {
                id:slot
                required property var modelData
                required property int index
                readonly property var entry:modelData.data.value
                Layout.fillWidth:true;spacing:2*ps.s
                // A new group starts a little further down than the rows inside it.
                Layout.topMargin:entry.first&&index>0 ? 4*ps.s : 0
                MText {visible:entry.first&&!ps.card;Layout.leftMargin:10*ps.s;Layout.preferredHeight:30*ps.s;verticalAlignment:Text.AlignVCenter;text:slot.entry.group;role:"label";font.pixelSize:13*ps.s;font.weight:Font.DemiBold;color:Theme.primary}
                Item {
                    id:row
                    readonly property var modelData:slot.entry
                    readonly property bool leads:slot.index===0
                    readonly property bool lit:activeFocus&&focusReason!==Qt.OtherFocusReason
                    readonly property bool danger:!!modelData.danger
                    Layout.fillWidth:true;Layout.preferredHeight:64*ps.s
                    activeFocusOnTab:true
                    onLeadsChanged:if(leads)list.first=row
                    Component.onCompleted:if(leads)list.first=row
                    Component.onDestruction:if(list.first===row)list.first=null
                    Keys.onReturnPressed:ps.pick(modelData.id)
                    Keys.onEnterPressed:ps.pick(modelData.id)
                    Keys.onSpacePressed:ps.pick(modelData.id)
                    Keys.onUpPressed:nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
                    Keys.onDownPressed:nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                    Accessible.role:Accessible.Button;Accessible.name:modelData.label
                    // The outer corners of a group are round; the inner corners are small.
                    Rectangle {
                        anchors.fill:parent
                        topLeftRadius:row.modelData.first ? 22*ps.s : 6*ps.s;topRightRadius:topLeftRadius
                        bottomLeftRadius:row.modelData.last ? 22*ps.s : 6*ps.s;bottomRightRadius:bottomLeftRadius
                        color:row.lit ? Theme.primaryContainer : row.danger ? ps.dangerFill : Theme.level(3)
                        Behavior on color {ColorAnimation {duration:Theme.motion(120)}}
                        Rectangle {anchors.fill:parent;topLeftRadius:parent.topLeftRadius;topRightRadius:parent.topRightRadius;bottomLeftRadius:parent.bottomLeftRadius;bottomRightRadius:parent.bottomRightRadius;color:Theme.stateLayer;opacity:area.pressed ? .12 : area.containsMouse ? .06 : 0}
                    }
                    Rectangle {
                        x:12*ps.s;anchors.verticalCenter:parent.verticalCenter;width:40*ps.s;height:width;radius:width/2
                        color:row.danger ? Theme.error : row.lit ? Theme.primary : Theme.level(4)
                        Glyph {anchors.centerIn:parent;name:row.modelData.icon;font.pixelSize:21*ps.s;color:row.danger ? (Theme.light ? "#ffffff" : "#690005") : row.lit ? Theme.onPrimary : Theme.primary}
                    }
                    MText {x:66*ps.s;anchors.verticalCenter:parent.verticalCenter;text:row.modelData.label;role:"title";font.pixelSize:16*ps.s;font.weight:Font.Medium;color:row.danger ? Theme.error : row.lit ? Theme.onContainer : Theme.text}
                    Rectangle {
                        visible:ps.form==="desktop"&&!!row.modelData.key
                        anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter
                        height:26;width:keyText.implicitWidth+16;radius:8;color:Theme.level(4)
                        MText {id:keyText;anchors.centerIn:parent;text:row.modelData.key||"";role:"labelS";color:Theme.subtext}
                    }
                    MouseArea {id:area;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:ps.pick(row.modelData.id)}
                }
            }
        }
        ControllerHints {
            visible:ps.form==="tv";Layout.alignment:Qt.AlignHCenter;Layout.topMargin:14
            items:[{b:ControllerNav.acceptLabel,t:"Select"},{b:ControllerNav.backLabel,t:"Back"}]
        }
    }

    // Confirm step: one shape, one question, two buttons.
    ColumnLayout {
        id:confirm
        readonly property real art:(ps.card ? 96 : 150)*ps.s
        x:(ps.width-width)/2;width:list.fullWidth
        y:ps.card ? 10 : ps.thumb ? ps.height-implicitHeight-28 : Math.max(20,(ps.height-implicitHeight)/2)
        spacing:0
        opacity:ps.asking ? 1 : 0
        visible:opacity>0
        Behavior on opacity {NumberAnimation {duration:Theme.motion(160)}}
        Item {
            Layout.alignment:Qt.AlignHCenter;Layout.preferredWidth:confirm.art*1.15;Layout.preferredHeight:confirm.art*1.15
            MorphShape {anchors.fill:parent;shape:5;fill:Theme.alpha(ps.accent,.22);spinMs:30000}
            MorphShape {anchors.centerIn:parent;width:parent.width*.72;height:width;shape:5;fill:ps.accent;spinMs:42000}
            Glyph {anchors.centerIn:parent;name:ps.asking ? ps.asking.icon : "power";font.pixelSize:confirm.art*.3;color:ps.accentInk}
        }
        MText {
            Layout.fillWidth:true;Layout.topMargin:(ps.card ? 6 : 12)*ps.s
            horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap
            text:ps.asking ? ps.asking.ask : "";role:"headline";font.pixelSize:(ps.card ? 22 : 28)*ps.s
        }
        MText {
            visible:ps.session&&!ps.card
            Layout.fillWidth:true;Layout.topMargin:8*ps.s;Layout.leftMargin:12;Layout.rightMargin:12
            horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap
            text:"Open apps close first. Unsaved work in them may be lost.";role:"body";font.pixelSize:14*ps.s;color:Theme.subtext
        }
        MButton {
            id:confirmButton
            Layout.fillWidth:true;Layout.topMargin:(ps.card ? 14 : 28)*ps.s;Layout.preferredHeight:(ps.card ? 48 : 56)*ps.s
            text:ps.asking ? ps.asking.label : "";filled:true;accent:ps.accent;fillInk:ps.accentInk
            onClicked:ps.act(ps.page)
        }
        MButton {
            id:cancelButton
            Layout.fillWidth:true;Layout.topMargin:8*ps.s;Layout.preferredHeight:(ps.card ? 48 : 56)*ps.s
            text:"Cancel";tonal:true
            onClicked:ps.back()
        }
    }
}
