import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Settings › Power key: what the menu holds and where it starts, the countdown, the other presses and favourite contacts.
Item {
    id:page
    // Folder indexes from the top level down to the folder being edited.
    property var path:[]
    // "" or the open sheet: add, app, command, link, folder, press, contacts.
    property string sheet:""
    property string pressSlot:""
    Component.onCompleted:Hub.command({action:"powerkey-refresh"})

    function copy(v) {return JSON.parse(JSON.stringify(v));}
    function levelOf(tree,p) {let items=tree;for(const i of p){items=(items[i]||{}).items||[];}return items;}
    readonly property var level:levelOf(PowerKey.tree,path)
    readonly property string levelTitle:path.length ? PowerKey.nodeLabel(levelOf(PowerKey.tree,path.slice(0,-1))[path[path.length-1]]) : "Menu"
    // Every change edits a copy of the stored tree and saves it whole.
    function edit(fn) {const tree=copy(PowerKey.tree);fn(levelOf(tree,path));Hub.set("powerMenu",tree);}
    function move(from,to) {if(from===to)return;edit(items=>{const n=items.splice(from,1)[0];items.splice(Math.max(0,Math.min(items.length,to)),0,n);});}
    function remove(i) {edit(items=>items.splice(i,1));}
    function add(node) {
        if(page.sheet==="press"){const p=Object.assign({},PowerKey.presses);p[page.pressSlot]=node;Hub.set("powerPress",p);}
        else edit(items=>items.push(node));
        page.sheet="";
    }
    function has(id) {return page.level.some(n=>n.action===id);}
    function pressLabel(slot) {const n=PowerKey.presses[slot];return n ? PowerKey.nodeLabel(n) : "Nothing";}

    Flickable {
        anchors.fill:parent;contentHeight:column.implicitHeight+24;clip:true;boundsBehavior:Flickable.StopAtBounds
        ScrollBar.vertical:ScrollBar {}
        ColumnLayout {
            id:column
            width:parent.width;spacing:8

            Label2 {text:"Power key"}
            SegmentedButtons {
                Layout.fillWidth:true;current:Hub.prefs.powerKey||"auto"
                options:[{value:"auto",label:"Automatic",icon:"auto_mode"},{value:"on",label:"Always",icon:"power_settings_new"},{value:"off",label:"Never",icon:"block"}]
                onPicked:value=>Hub.set("powerKey",value)
            }
            MText {
                Layout.fillWidth:true;Layout.leftMargin:6;wrapMode:Text.WordWrap;role:"bodyS";color:Theme.subtext
                text:PowerKey.device.enabled ? "A tap on power opens this menu. Volume keys move, power picks. Super+Escape and Guide+B open it too."
                    : PowerKey.device.handset ? "The power key sleeps the device as usual. Super+Escape and Guide+B still open the menu."
                    : "This computer keeps its power key. Super+Escape, or Guide+B on a controller, opens the menu."
            }

            RowLayout {
                Layout.fillWidth:true;Layout.topMargin:12
                MButton {visible:page.path.length>0;icon:"arrow_back";compact:true;implicitWidth:36;implicitHeight:36;tooltip:"Back";onClicked:page.path=page.path.slice(0,-1)}
                Label2 {Layout.fillWidth:true;text:page.levelTitle}
            }
            Rectangle {
                Layout.fillWidth:true;implicitHeight:rows.implicitHeight+12;radius:Theme.shapeLg;color:Theme.level(2)
                Column {
                    id:rows;x:6;y:6;width:parent.width-12
                    Repeater {
                        id:rowRepeater
                        model:page.level
                        Item {
                            id:rowItem
                            required property var modelData
                            required property int index
                            readonly property bool start:page.path.length===0&&modelData.action===PowerKey.startAction
                            readonly property bool folder:modelData.action==="folder"
                            width:rows.width;height:50;z:handle.active ? 2 : 0
                            transform:Translate {y:handle.active ? handle.translation.y : 0}
                            Rectangle {anchors.fill:parent;radius:16;color:rowItem.start ? Theme.alpha(Theme.primary,.12) : handle.active ? Theme.level(4) : "transparent"}
                            // A folder opens; any other top-level row becomes where the menu starts.
                            MouseArea {anchors.fill:parent;onClicked:{if(rowItem.folder)page.path=page.path.concat([rowItem.index]);else if(page.path.length===0)Hub.set("powerMenuStart",rowItem.modelData.action);}}
                            RowLayout {
                                anchors.fill:parent;anchors.leftMargin:4;anchors.rightMargin:4;spacing:10
                                Item {
                                    Layout.preferredWidth:32;Layout.fillHeight:true
                                    Glyph {anchors.centerIn:parent;name:"drag_indicator";font.pixelSize:20;color:Theme.muted}
                                    DragHandler {
                                        id:handle;target:null;xAxis.enabled:false
                                        onActiveChanged:if(!active)page.move(rowItem.index,rowItem.index+Math.round(translation.y/rowItem.height))
                                    }
                                }
                                Glyph {name:PowerKey.nodeIcon(rowItem.modelData);font.pixelSize:20;color:Theme.primary}
                                ColumnLayout {
                                    Layout.fillWidth:true;spacing:0
                                    MText {Layout.fillWidth:true;text:PowerKey.nodeLabel(rowItem.modelData);role:"body";elide:Text.ElideRight}
                                    MText {Layout.fillWidth:true;visible:text!=="";role:"bodyS";color:Theme.subtext;elide:Text.ElideRight
                                        text:rowItem.modelData.command||rowItem.modelData.url||(rowItem.folder ? (rowItem.modelData.items||[]).length+" actions" : "")}
                                }
                                Rectangle {
                                    visible:rowItem.start;implicitWidth:startText.implicitWidth+16;implicitHeight:24;radius:12;color:Theme.primaryContainer
                                    MText {id:startText;anchors.centerIn:parent;text:"Starts here";role:"labelS";color:Theme.onContainer}
                                }
                                Glyph {visible:rowItem.folder;name:"chevron_right";font.pixelSize:20;color:Theme.muted}
                                MButton {icon:"remove_circle_outline";compact:true;implicitWidth:34;implicitHeight:34;tooltip:"Remove";onClicked:page.remove(rowItem.index)}
                            }
                        }
                    }
                    MText {visible:page.level.length===0;width:parent.width;height:44;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter;text:"Nothing here yet";role:"bodyS";color:Theme.subtext}
                }
            }
            Flow {
                Layout.fillWidth:true;spacing:8
                MButton {text:"Add action";icon:"add";filled:true;onClicked:page.sheet="add"}
                MButton {text:"New submenu";icon:"create_new_folder";tonal:true;visible:page.path.length<3;onClicked:page.sheet="folder"}
                MButton {text:"Reset";icon:"restart_alt";visible:page.path.length===0;onClicked:{Hub.set("powerMenu",[]);Hub.set("powerMenuStart","sleep");}}
            }
            MText {visible:page.path.length===0;Layout.fillWidth:true;Layout.leftMargin:6;wrapMode:Text.WordWrap;role:"bodyS";color:Theme.subtext
                text:"Drag the handles to reorder. Tap a row to make the menu open on it."}

            Label2 {text:"Countdown to sleep";Layout.topMargin:12}
            SegmentedButtons {
                Layout.fillWidth:true;current:PowerKey.countdownMs
                options:[{value:0,label:"Off"},{value:1000,label:"1 s"},{value:2000,label:"2 s"},{value:3000,label:"3 s"}]
                onPicked:value=>Hub.set("powerMenuCountdown",value)
            }
            MText {Layout.fillWidth:true;Layout.leftMargin:6;wrapMode:Text.WordWrap;role:"bodyS";color:Theme.subtext
                text:"When the menu opens on Sleep, it sleeps by itself after this long. Any key or touch stops it."}

            Label2 {text:"Other presses";Layout.topMargin:12}
            Rectangle {
                Layout.fillWidth:true;implicitHeight:presses.implicitHeight+12;radius:Theme.shapeLg;color:Theme.level(2)
                Column {
                    id:presses;x:6;y:6;width:parent.width-12
                    Repeater {
                        model:[{slot:"double",title:"Double-press"},{slot:"hold",title:"Hold"},{slot:"chord",title:"Power + volume down"}]
                        Rectangle {
                            required property var modelData
                            width:presses.width;height:48;radius:16;color:pressMouse.containsMouse ? Theme.alpha(Theme.text,.06) : "transparent"
                            MouseArea {id:pressMouse;anchors.fill:parent;hoverEnabled:true;onClicked:{page.pressSlot=modelData.slot;page.sheet="press";}}
                            RowLayout {anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:12
                                MText {Layout.fillWidth:true;text:modelData.title;role:"body"}
                                MText {text:page.pressLabel(modelData.slot);role:"body";color:Theme.subtext}
                                Glyph {name:"unfold_more";font.pixelSize:18;color:Theme.muted}}
                        }
                    }
                }
            }

            Label2 {text:"Favourite contacts";Layout.topMargin:12}
            Flow {
                Layout.fillWidth:true;spacing:8
                Repeater {
                    model:(Hub.prefs.powerContacts||[]).map(uid=>PowerKey.contacts.find(c=>c.uid===uid)).filter(Boolean)
                    Chip {required property var modelData;text:modelData.name;icon:"person";trailingIcon:"close";selected:true
                        onClicked:Hub.set("powerContacts",(Hub.prefs.powerContacts||[]).filter(u=>u!==modelData.uid))}
                }
                Chip {text:PowerKey.contacts.length ? "Add favourite" : "No contacts found";icon:"person_add";enabled:PowerKey.contacts.length>0;onClicked:page.sheet="contacts"}
            }
            MText {Layout.fillWidth:true;Layout.leftMargin:6;wrapMode:Text.WordWrap;role:"bodyS";color:Theme.subtext
                text:"Contacts come from your address books (vCard folders and Evolution). Without favourites, starred contacts show first."}
        }
    }

    component Label2:MText {font.pixelSize:12;font.weight:Font.Medium;color:Theme.primary;Layout.leftMargin:6;Layout.bottomMargin:2}

    // ---------- Sheet ----------
    Rectangle {anchors.fill:parent;visible:page.sheet!=="";color:"#000000";opacity:.4;MouseArea {anchors.fill:parent;onClicked:page.sheet=""}}
    Rectangle {
        id:sheetBox
        visible:page.sheet!==""
        anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
        height:Math.min(parent.height-24,sheetColumn.implicitHeight+40)
        topLeftRadius:28;topRightRadius:28;color:Theme.level(1)
        MouseArea {anchors.fill:parent}
        Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:10;width:36;height:4;radius:2;color:Theme.alpha(Theme.text,.35)}
        Flickable {
            anchors.fill:parent;anchors.topMargin:24;anchors.leftMargin:18;anchors.rightMargin:18;anchors.bottomMargin:16
            contentHeight:sheetColumn.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
            ColumnLayout {
                id:sheetColumn;width:parent.width;spacing:10
                RowLayout {
                    Layout.fillWidth:true
                    MText {Layout.fillWidth:true;role:"title"
                        text:({add:"Add action",press:"When you "+({double:"double-press",hold:"hold",chord:"press power + volume down"})[page.pressSlot]+" power",app:"Open app",command:"Run command",link:"Open link",folder:"New submenu",contacts:"Favourite contacts"})[page.sheet]||""}
                    MButton {icon:"close";compact:true;implicitWidth:36;implicitHeight:36;tooltip:"Close";onClicked:page.sheet=""}
                }

                // Catalogue chips, grouped. In add mode a chip already in this menu is ticked, and a tap takes it out again.
                Repeater {
                    model:page.sheet==="add"||page.sheet==="press" ? ["Power","Device","Capture","Shell","Media & people","Yours"] : []
                    ColumnLayout {
                        required property string modelData
                        Layout.fillWidth:true;spacing:6
                        MText {text:modelData;role:"label";color:Theme.subtext}
                        Flow {
                            Layout.fillWidth:true;spacing:8
                            Repeater {
                                model:PowerKey.catalog.filter(c=>c.group===modelData&&!(page.sheet==="press"&&c.id==="folder"))
                                Chip {
                                    required property var modelData
                                    text:modelData.label;icon:modelData.icon;glass:false
                                    selected:page.sheet==="add"&&!modelData.custom&&page.has(modelData.id)||page.sheet==="press"&&(PowerKey.presses[page.pressSlot]||{}).action===modelData.id
                                    onClicked:{
                                        if(modelData.custom){page.sheet=modelData.id;return;}
                                        if(page.sheet==="add"&&selected){page.edit(items=>{const i=items.findIndex(n=>n.action===modelData.id);if(i>=0)items.splice(i,1);});return;}
                                        page.add({action:modelData.id});
                                    }
                                }
                            }
                        }
                    }
                }
                Chip {visible:page.sheet==="press";text:"Nothing";icon:"block";glass:false;selected:!PowerKey.presses[page.pressSlot]
                    onClicked:{const p=Object.assign({},PowerKey.presses);p[page.pressSlot]=null;Hub.set("powerPress",p);page.sheet="";}}

                // Custom actions.
                Field {id:labelField;visible:["command","link","folder"].indexOf(page.sheet)>=0;hint:page.sheet==="folder" ? "Name, like Toggles" : "Label"}
                Field {id:commandField;visible:page.sheet==="command";hint:"Command, like ~/bin/dots-sync"}
                Field {id:urlField;visible:page.sheet==="link";hint:"https://, tel:, mailto: …"}
                MButton {
                    visible:["command","link","folder"].indexOf(page.sheet)>=0;text:"Add";icon:"add";filled:true
                    enabled:page.sheet==="folder" ? labelField.text.trim()!=="" : page.sheet==="command" ? commandField.text.trim()!=="" : /^(https?|mailto|tel|sms|geo|file):/i.test(urlField.text.trim())
                    onClicked:{
                        const label=labelField.text.trim().slice(0,64);
                        const node=page.sheet==="folder" ? {action:"folder",label:label||"Submenu",items:[]} : page.sheet==="command" ? {action:"command",command:commandField.text.trim()} : {action:"link",url:urlField.text.trim()};
                        if(label&&page.sheet!=="folder")node.label=label;
                        labelField.text="";commandField.text="";urlField.text="";
                        page.add(node);
                    }
                }
                Field {id:appSearch;visible:page.sheet==="app";hint:"Search apps"}
                Repeater {
                    model:page.sheet==="app" ? Hub.apps.filter(a=>a.name.toLowerCase().indexOf(appSearch.text.toLowerCase())>=0).slice(0,40) : []
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth:true;implicitHeight:46;radius:16;color:appMouse.containsMouse ? Theme.alpha(Theme.text,.06) : "transparent"
                        MouseArea {id:appMouse;anchors.fill:parent;hoverEnabled:true;onClicked:{appSearch.text="";page.add({action:"app",app:modelData.id});}}
                        RowLayout {anchors.fill:parent;anchors.leftMargin:10;spacing:12
                            AppIcon {Layout.preferredWidth:28;Layout.preferredHeight:28;app:modelData}
                            MText {Layout.fillWidth:true;text:modelData.name;role:"body";elide:Text.ElideRight}}
                    }
                }
                Repeater {
                    model:page.sheet==="contacts" ? PowerKey.contacts : []
                    Rectangle {
                        required property var modelData
                        readonly property bool on:(Hub.prefs.powerContacts||[]).indexOf(modelData.uid)>=0
                        Layout.fillWidth:true;implicitHeight:48;radius:16;color:on ? Theme.alpha(Theme.primary,.12) : "transparent"
                        MouseArea {anchors.fill:parent;onClicked:{
                            const list=(Hub.prefs.powerContacts||[]).filter(u=>u!==modelData.uid);
                            if(!parent.on&&list.length<24)list.push(modelData.uid);
                            Hub.set("powerContacts",list);}}
                        RowLayout {anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:12;spacing:12
                            Glyph {name:"person";font.pixelSize:20;color:Theme.primary}
                            ColumnLayout {Layout.fillWidth:true;spacing:0
                                MText {Layout.fillWidth:true;text:modelData.name;role:"body";elide:Text.ElideRight}
                                MText {Layout.fillWidth:true;text:(modelData.phones||[])[0]||(modelData.emails||[])[0]||"";role:"bodyS";color:Theme.subtext;elide:Text.ElideRight}}
                            Glyph {visible:parent.parent.on;name:"star";font.pixelSize:20;color:Theme.primary}}
                    }
                }
            }
        }
    }
    component Field:Rectangle {
        property alias text:input.text
        property string hint:""
        Layout.fillWidth:true;implicitHeight:46;radius:23;color:Theme.level(3)
        TextField {id:input;anchors.fill:parent;anchors.leftMargin:16;anchors.rightMargin:16;placeholderText:parent.hint;color:Theme.text;placeholderTextColor:Theme.subtext;font.family:Theme.font;font.pixelSize:15;background:Item {}}
    }
}
