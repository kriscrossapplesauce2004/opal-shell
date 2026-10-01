import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Merged control and notification sheet. Sections and their order come from preferences.
Item {
    id:q
    property string confirm:""
    property bool editing:false
    readonly property bool phone:Hub.targetScreen ? Hub.layoutFor(Hub.targetScreen.width,Hub.targetScreen.height,Hub.targetScreen.name)==="phone" : Hub.prefs.mode==="phone"
    readonly property var catalog:[
        {id:"sliders",title:"Brightness and volume",icon:"tune"},
        {id:"tiles",title:"Quick tiles",icon:"grid_view"},
        {id:"media",title:"Now playing",icon:"music_note"},
        {id:"notifications",title:"Notifications",icon:"notifications"},
        {id:"calendar",title:"Calendar",icon:"calendar_month"},
        {id:"monitor",title:"System monitor",icon:"speed"},
        {id:"clipboard",title:"Clipboard",icon:"content_paste"},
        {id:"focus",title:"Focus timer",icon:"timer"},
        {id:"battery",title:"Device batteries",icon:"battery_full"},
        {id:"devices",title:"Your devices",icon:"devices"}
    ]
    readonly property var sections:Array.isArray(Hub.prefs.sheetSections) ? Hub.prefs.sheetSections.filter(id=>catalog.some(c=>c.id===id)) : ["sliders","tiles","media","notifications"]
    function title(id) {const c=catalog.find(c=>c.id===id);return c ? c.title : id;}
    function icon(id) {const c=catalog.find(c=>c.id===id);return c ? c.icon : "widgets";}
    function toggleSection(id) {const list=sections.slice();const i=list.indexOf(id);if(i>=0)list.splice(i,1);else list.push(id);Hub.set("sheetSections",list);}
    function moveSection(from,to) {const list=sections.slice();if(from<0||from>=list.length)return;to=Math.max(0,Math.min(list.length-1,to));if(from===to)return;const item=list.splice(from,1)[0];list.splice(to,0,item);Hub.set("sheetSections",list);}
    Component.onCompleted:{Hub.connection("wifi","refresh");Hub.connection("bluetooth","refresh");if(Hub.page==="notifications")Qt.callLater(scrollToInbox);if(Hub.page==="clipboard"||sections.indexOf("clipboard")>=0)Hub.refreshClipboard();}
    Connections {target:Hub;function onPageChanged(){if(Hub.page==="notifications")Qt.callLater(q.scrollToInbox);}}
    function scrollToInbox() {
        const item=sectionRepeater.itemAt(sections.indexOf("notifications"));
        if(item)scroller.contentY=Math.max(0,Math.min(scroller.contentHeight-scroller.height,item.y));
    }
    // Desktop sheets shrink to fit. Zero means the host picks the height.
    readonly property real fitHeight:!q.phone&&Hub.controlDetail===""&&q.confirm==="" ? main.implicitHeight+28 : 0
    ColumnLayout {
        id:main
        visible:Hub.controlDetail==="";anchors.fill:parent;anchors.margins:14;spacing:10
        Rectangle {visible:q.phone;Layout.alignment:Qt.AlignHCenter;Layout.preferredWidth:40;Layout.preferredHeight:4;radius:2;color:Theme.outline}
        // Header: large clock and date, status on the right.
        RowLayout {Layout.fillWidth:true;Layout.leftMargin:6;Layout.rightMargin:4;spacing:8
            ColumnLayout {spacing:0
                MText {text:Qt.formatDateTime(Hub.now,"HH:mm");role:"displayS";font.features:{"tnum":1}}
                MText {text:Qt.formatDateTime(Hub.now,"dddd d MMMM");role:"label";color:Theme.subtext}
            }
            Item {Layout.fillWidth:true}
            Row {Layout.alignment:Qt.AlignVCenter;spacing:6
                Glyph {visible:Hub.status.battery>=0;name:Hub.status.charging ? "charging" : "battery";font.pixelSize:16;color:Theme.subtext;anchors.verticalCenter:parent.verticalCenter}
                MText {visible:Hub.status.battery>=0;anchors.verticalCenter:parent.verticalCenter;text:Hub.status.battery+"%";role:"label";color:Theme.subtext}
                MButton {icon:"settings";compact:true;implicitWidth:38;implicitHeight:38;ink:Theme.subtext;tooltip:"Settings";onClicked:Hub.openSettings()}
                MButton {icon:"power";compact:true;implicitWidth:38;implicitHeight:38;ink:Theme.subtext;tooltip:"Power";onClicked:q.confirm="menu"}
            }
        }
        Flickable {
            id:scroller
            Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredHeight:body.implicitHeight
            contentHeight:body.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
            Behavior on contentY {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
            ScrollBar.vertical:ScrollBar {}
            ColumnLayout {
                id:body;width:parent.width;spacing:12
                // Section editor: show, hide and drag to reorder.
                ColumnLayout {
                    visible:q.editing;Layout.fillWidth:true;spacing:4
                    MText {text:"Sections";role:"titleS";Layout.leftMargin:6}
                    MText {text:"Drag to reorder. Tap to show or hide.";role:"bodyS";color:Theme.subtext;Layout.leftMargin:6;Layout.bottomMargin:4}
                    Item {
                        id:editor
                        readonly property int rowHeight:48
                        readonly property var rows:q.sections.concat(q.catalog.map(c=>c.id).filter(id=>q.sections.indexOf(id)<0))
                        property int dragFrom:-1
                        property int dragTo:-1
                        Layout.fillWidth:true;Layout.preferredHeight:rows.length*rowHeight
                        Repeater {
                            model:editor.rows
                            Rectangle {
                                id:row
                                required property string modelData
                                required property int index
                                readonly property bool shown:q.sections.indexOf(modelData)>=0
                                readonly property bool dragged:editor.dragFrom===index
                                width:editor.width;height:editor.rowHeight-4
                                function restingY() {return index*editor.rowHeight+(editor.dragFrom>=0&&!dragged&&shown ? (editor.dragFrom<index&&index<=editor.dragTo ? -editor.rowHeight : editor.dragTo<=index&&index<editor.dragFrom ? editor.rowHeight : 0) : 0);}
                                y:restingY()
                                z:dragged ? 2 : 0
                                radius:Theme.shapeMd
                                color:dragged ? Theme.level(4) : shown ? Theme.level(3) : "transparent"
                                border.width:shown ? 0 : 1;border.color:Theme.outline
                                Behavior on y {enabled:!row.dragged;NumberAnimation {duration:Theme.motion(Theme.durShort);easing.type:Easing.OutCubic}}
                                RowLayout {anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:6;spacing:10
                                    Glyph {name:q.icon(row.modelData);font.pixelSize:19;color:row.shown ? Theme.primary : Theme.muted}
                                    MText {text:q.title(row.modelData);role:"body";color:row.shown ? Theme.text : Theme.subtext;Layout.fillWidth:true}
                                    Glyph {name:row.shown ? "check_circle" : "add_circle";font.pixelSize:20;color:row.shown ? Theme.primary : Theme.muted}
                                    Item {
                                        visible:row.shown;Layout.preferredWidth:34;Layout.fillHeight:true
                                        Glyph {anchors.centerIn:parent;name:"drag_indicator";font.pixelSize:20;color:Theme.subtext}
                                        MouseArea {
                                            anchors.fill:parent;cursorShape:Qt.SizeVerCursor;preventStealing:true
                                            drag.target:row;drag.axis:Drag.YAxis;drag.minimumY:0;drag.maximumY:(q.sections.length-1)*editor.rowHeight
                                            onPressed:{editor.dragFrom=row.index;editor.dragTo=row.index;}
                                            onPositionChanged:if(drag.active)editor.dragTo=Math.max(0,Math.min(q.sections.length-1,Math.round(row.y/editor.rowHeight)))
                                            onReleased:{const from=editor.dragFrom,to=editor.dragTo;editor.dragFrom=-1;editor.dragTo=-1;row.y=Qt.binding(()=>row.restingY());q.moveSection(from,to);}
                                        }
                                    }
                                }
                                MouseArea {anchors.fill:parent;anchors.rightMargin:row.shown ? 40 : 0;z:-1;cursorShape:Qt.PointingHandCursor;onClicked:q.toggleSection(row.modelData)}
                            }
                        }
                    }
                }
                Repeater {
                    id:sectionRepeater
                    model:q.sections
                    Loader {
                        required property string modelData
                        Layout.fillWidth:true
                        sourceComponent:modelData==="sliders" ? slidersSection : modelData==="tiles" ? tilesSection : modelData==="media" ? mediaSection : modelData==="notifications" ? inboxSection : modelData==="calendar" ? calendarSection : modelData==="monitor" ? monitorSection : modelData==="clipboard" ? clipboardSection : modelData==="focus" ? focusSection : modelData==="devices" ? devicesSection : batterySection
                    }
                }
                MText {visible:q.sections.length===0&&!q.editing;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter;text:"Nothing here yet. Edit to add sections.";role:"bodyS";color:Theme.subtext;Layout.topMargin:12;Layout.bottomMargin:12}
            }
        }
        RowLayout {Layout.fillWidth:true;spacing:8
            MButton {text:Hub.dnd ? "Do not disturb" : "";icon:Hub.dnd ? "quiet" : "bell";compact:true;implicitHeight:36;tonal:Hub.dnd;tooltip:Hub.dnd ? "Turn off Do not disturb" : "Do not disturb";onClicked:Hub.set("dnd",!Hub.dnd)}
            Item {Layout.fillWidth:true}
            MButton {icon:q.editing ? "check" : "edit";text:q.editing ? "Done" : "";compact:true;implicitHeight:36;filled:q.editing;tooltip:q.editing ? "Done" : "Customize";onClicked:q.editing=!q.editing}
        }
    }
    Component {id:slidersSection;ColumnLayout {spacing:8
        RowLayout {visible:Hub.status.brightness>=0;Layout.fillWidth:true;spacing:8
            ExpressiveSlider {Layout.fillWidth:true;implicitHeight:52;compact:true;trackHeight:44;icon:"sun";iconAtHandle:true;value:Hub.status.brightness;onMoved:Hub.command({action:"brightness",value:Math.round(value)});Accessible.name:"Brightness"}
        }
        RowLayout {Layout.fillWidth:true;spacing:8
            ExpressiveSlider {Layout.fillWidth:true;implicitHeight:52;compact:true;trackHeight:44;icon:Hub.status.muted ? "mute" : "volume";iconAtHandle:true;value:Hub.status.volume;activeColor:Hub.status.muted ? Theme.subtext : Theme.primary;onMoved:Hub.volume(value);Accessible.name:"Volume"
                TapHandler {acceptedButtons:Qt.RightButton;onTapped:Hub.command({action:"mute"})}
            }
            MButton {icon:"next";implicitWidth:44;implicitHeight:44;contained:true;tooltip:"Sound";onClicked:Hub.openAudio(Hub.targetScreen)}
        }
    }}
    Component {id:tilesSection;QuickTileDeck {editing:q.editing}}
    Component {id:mediaSection;Item {implicitHeight:Hub.status.track!=="" ? media.implicitHeight : 0;MediaCard {id:media;width:parent.width;visible:Hub.status.track!=="";compact:true;expandable:true}}}
    Component {id:inboxSection;ColumnLayout {spacing:8
        RowLayout {Layout.fillWidth:true;Layout.leftMargin:6
            MText {text:"Notifications";role:"titleS";Layout.fillWidth:true}
            MButton {visible:Notifier.inbox.length>0;text:"Clear all";compact:true;implicitHeight:30;ink:Theme.subtext;onClicked:Notifier.clear()}
        }
        NotificationGroups {Layout.fillWidth:true;visible:Notifier.inbox.length>0}
        MText {visible:Notifier.inbox.length===0;Layout.fillWidth:true;Layout.leftMargin:6;text:Hub.dnd ? "No notifications. Do not disturb is on." : "No notifications";role:"bodyS";color:Theme.subtext;Layout.bottomMargin:4}
    }}
    Component {id:calendarSection;CalendarWidget {implicitHeight:300}}
    Component {id:monitorSection;Rectangle {implicitHeight:monitorRow.implicitHeight+28;radius:Theme.shapeLg;color:Theme.level(3)
        RowLayout {id:monitorRow;anchors.fill:parent;anchors.margins:14;spacing:14
            Repeater {model:[{label:"CPU",value:Hub.status.cpu,icon:"speed"},{label:"Memory",value:Hub.status.memory,icon:"memory"}]
                ColumnLayout {required property var modelData;Layout.fillWidth:true;spacing:6
                    RowLayout {Layout.fillWidth:true;spacing:6
                        Glyph {name:modelData.icon;font.pixelSize:17;color:Theme.primary}
                        MText {text:modelData.label;role:"label";color:Theme.subtext;Layout.fillWidth:true}
                        MText {text:modelData.value+"%";role:"titleS";font.features:{"tnum":1}}
                    }
                    Rectangle {Layout.fillWidth:true;height:6;radius:3;color:Theme.alpha(Theme.primary,.18)
                        Rectangle {width:parent.width*Math.max(0,Math.min(100,modelData.value))/100;height:6;radius:3;color:Theme.primary}}
                }
            }
        }
    }}
    Component {id:clipboardSection;ColumnLayout {spacing:6
        RowLayout {Layout.fillWidth:true;Layout.leftMargin:6
            MText {text:"Clipboard";role:"titleS";Layout.fillWidth:true}
            MButton {text:"All";compact:true;implicitHeight:30;ink:Theme.subtext;onClicked:Hub.toggleClipboard()}
        }
        Repeater {model:Hub.clipboardItems.slice(0,3)
            Rectangle {required property var modelData;Layout.fillWidth:true;implicitHeight:44;radius:Theme.shapeMd;color:Theme.level(3)
                MText {anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:14;verticalAlignment:Text.AlignVCenter;text:(modelData.text||"").replace(/\s+/g," ").trim();role:"bodyS"}
                MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:Hub.copyClipboard(modelData.id,false)}
            }
        }
        MText {visible:Hub.clipboardItems.length===0;Layout.leftMargin:6;text:"Nothing copied yet";role:"bodyS";color:Theme.subtext}
    }}
    Component {id:focusSection;Item {implicitHeight:Hub.focusRunning ? focusCard.implicitHeight : startFocus.implicitHeight
        FocusCard {id:focusCard;visible:Hub.focusRunning;width:parent.width}
        MButton {id:startFocus;visible:!Hub.focusRunning;width:parent.width;icon:"timer";text:"Start a 25 minute focus";tonal:true;onClicked:Hub.timerToggle()}
    }}
    Component {id:devicesSection;ColumnLayout {spacing:6
        MText {text:"Your devices";role:"titleS";Layout.leftMargin:6}
        LinkDevices {Layout.fillWidth:true;compact:true}
    }}
    Component {id:batterySection;ColumnLayout {spacing:6
        MText {text:"Batteries";role:"titleS";Layout.leftMargin:6}
        Repeater {model:Hub.status.batteries||[]
            Rectangle {required property var modelData;Layout.fillWidth:true;implicitHeight:52;radius:Theme.shapeMd;color:Theme.level(3)
                RowLayout {anchors.fill:parent;anchors.margins:12;spacing:10
                    Glyph {name:modelData.charging ? "charging" : "battery";font.pixelSize:19;color:Theme.primary}
                    MText {text:modelData.name;role:"body";Layout.fillWidth:true}
                    MText {text:modelData.percent+"%";role:"titleS";font.features:{"tnum":1}}
                }
            }
        }
        MText {visible:!(Hub.status.batteries||[]).length;Layout.leftMargin:6;text:"No batteries found";role:"bodyS";color:Theme.subtext}
    }}
    Loader {anchors.fill:parent;anchors.margins:16;active:Hub.controlDetail!=="";visible:active;sourceComponent:Component {ConnectionPanel {kind:Hub.controlDetail||"wifi"}}}
    Rectangle {visible:q.confirm!=="";anchors.fill:parent;radius:28;color:Theme.level(2)
        MouseArea {anchors.fill:parent}
        ColumnLayout {anchors.centerIn:parent;width:parent.width-48;spacing:10
            MText {Layout.fillWidth:true;text:q.confirm==="menu" ? "Power" : q.confirm==="suspend" ? "Sleep now?" : q.confirm==="logout" ? "Log out now?" : q.confirm==="reboot" ? "Restart now?" : "Power off now?";role:"headline";wrapMode:Text.Wrap}
            Repeater {model:q.confirm==="menu" ? [{id:"suspend",title:"Sleep",icon:"sleep"},{id:"logout",title:"Log out",icon:"logout"},{id:"reboot",title:"Restart",icon:"restart"},{id:"poweroff",title:"Power off",icon:"power"}] : []
                MButton {required property var modelData;Layout.fillWidth:true;text:modelData.title;icon:modelData.icon;tonal:true;onClicked:q.confirm=modelData.id}
            }
            MButton {visible:q.confirm!=="menu";Layout.fillWidth:true;text:"Yes";filled:true;onClicked:{Hub.command({action:"power",verb:q.confirm});Hub.close();}}
            MButton {Layout.fillWidth:true;text:"Cancel";onClicked:q.confirm=""}
        }
    }
}
