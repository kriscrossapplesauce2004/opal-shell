import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The Claude assistant: conversation, context chips, confirmations and a composer. Desktop, phone and console share it.
Item {
    id:panel
    property string layoutMode:"desktop"
    readonly property bool phone:layoutMode==="phone"
    readonly property bool couch:layoutMode==="console"
    readonly property var turns:AssistantState.turns
    readonly property bool hasContext:(AssistantState.ctxApp!==""&&AssistantState.useApp)||(AssistantState.ctxSelection!==""&&AssistantState.useSelection)||(AssistantState.ctxClipboard!==""&&AssistantState.useClipboard)
    property int suggestIndex:0
    property alias input:field
    readonly property string acceptButton:Hub.prefs.controllerLayout==="nintendo" ? "B" : "A"
    readonly property string backButton:Hub.prefs.controllerLayout==="nintendo" ? "A" : "B"
    function submit() {
        if(AssistantState.busy||field.text.trim()==="")return;
        AssistantState.send(field.text);field.text="";
    }
    // Qt draws markdown links in a fixed blue that is unreadable on dark panels, so links show as bold text with the address in code.
    function plainLinks(text) {return text.replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g,"**$1** (`$2`)");}
    function follow() {chat.positionViewAtEnd();}
    onTurnsChanged:Qt.callLater(follow)
    // Controller: up and down pick a suggestion, accept answers a confirmation or sends it, back declines or closes.
    Connections {
        target:Hub
        enabled:Hub.page==="assistant"&&panel.couch
        function onNavigate(key) {
            const pending=AssistantState.approvals;
            if(key==="accept") {
                if(pending.length)AssistantState.approve(pending[0].id,true);
                else if(turns.length===0)AssistantState.send(AssistantState.suggestions[panel.suggestIndex].prompt);
            } else if(key==="back") {
                if(pending.length)AssistantState.approve(pending[0].id,false);
                else if(AssistantState.busy)AssistantState.stop();
                else Hub.close();
            } else if(key==="down") {
                if(turns.length===0)panel.suggestIndex=Math.min(AssistantState.suggestions.length-1,panel.suggestIndex+1);
                else chat.contentY=Math.min(Math.max(0,chat.contentHeight-chat.height),chat.contentY+160);
            } else if(key==="up") {
                if(turns.length===0)panel.suggestIndex=Math.max(0,panel.suggestIndex-1);
                else chat.contentY=Math.max(0,chat.contentY-160);
            } else if(key==="menu")AssistantState.newChat();
        }
    }
    ColumnLayout {
        anchors {fill:parent;margins:panel.couch ? 28 : panel.phone ? 16 : 18}
        spacing:12
        RowLayout {
            Layout.fillWidth:true;spacing:12
            Flower {Layout.preferredWidth:42;Layout.preferredHeight:42;fill:Theme.primary;lobes:8;Glyph {anchors.centerIn:parent;name:"spark";color:Theme.onPrimary;font.pixelSize:22}}
            ColumnLayout {
                Layout.fillWidth:true;spacing:2
                MText {text:"Claude";role:"title"}
                MText {
                    Layout.fillWidth:true;role:"labelS";color:AssistantState.available ? Theme.subtext : Theme.error
                    text:!AssistantState.available ? "Claude Code is not installed" : AssistantState.busy ? "Working…" : AssistantState.jev ? "Can use apps through accessibility" : "Uses your Claude Code sign-in"
                }
            }
            MButton {icon:"add";compact:true;tonal:true;tooltip:"New chat";enabled:turns.length>0||AssistantState.busy;onClicked:AssistantState.newChat()}
            MButton {icon:"close";compact:true;tooltip:"Close · Escape";onClicked:Hub.close()}
        }
        Item {
            Layout.fillWidth:true;Layout.fillHeight:true
            ListView {
                id:chat
                anchors.fill:parent;clip:true;spacing:14;model:panel.turns;boundsBehavior:Flickable.StopAtBounds
                visible:panel.turns.length>0
                ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                onContentHeightChanged:if(AssistantState.busy&&!moving)positionViewAtEnd()
                delegate:Item {
                    id:row
                    required property var modelData
                    required property int index
                    readonly property bool mine:modelData.role==="user"
                    readonly property bool last:index===panel.turns.length-1
                    width:chat.width
                    implicitHeight:mine ? bubble.height : answer.implicitHeight
                    height:implicitHeight
                    Rectangle {
                        id:bubble
                        visible:row.mine;anchors.right:parent.right
                        width:Math.min(row.width*.86,userText.implicitWidth+28);height:userText.implicitHeight+20
                        radius:20;color:Theme.primary
                        MText {id:userText;x:14;y:10;width:parent.width-28;text:row.modelData.text;wrapMode:Text.Wrap;color:Theme.onPrimary;font.pixelSize:panel.couch ? 17 : 14;elide:Text.ElideNone}
                    }
                    ColumnLayout {
                        id:answer
                        visible:!row.mine;width:parent.width;spacing:8
                        Flow {
                            Layout.fillWidth:true;spacing:6;visible:(row.modelData.tools||[]).length>0
                            Repeater {
                                model:row.modelData.tools||[]
                                AssistantChip {
                                    required property var modelData
                                    text:modelData.label;maxWidth:chat.width
                                    icon:modelData.status==="running" ? "more_horiz" : modelData.status==="error" ? "error" : "check"
                                    tone:modelData.status==="error" ? "error" : "neutral"
                                }
                            }
                        }
                        MText {
                            visible:!row.modelData.done&&row.modelData.text===""&&(row.modelData.tools||[]).length===0
                            text:"Thinking…";color:Theme.subtext;font.pixelSize:14
                        }
                        Text {
                            id:markdown
                            visible:row.modelData.text!==""
                            Layout.fillWidth:true;wrapMode:Text.Wrap
                            textFormat:Text.MarkdownText;text:panel.plainLinks(row.modelData.text)
                            color:row.modelData.error ? Theme.error : Theme.text;linkColor:Theme.primary;palette.link:Theme.primary
                            font.family:Theme.font;font.pixelSize:panel.couch ? 17 : 14;renderType:Text.NativeRendering
                            onLinkActivated:link=>{if(/^https?:\/\//.test(link))Qt.openUrlExternally(link);}
                        }
                        MText {
                            visible:!!row.modelData.stopped;text:"Stopped";role:"labelS";color:Theme.subtext
                        }
                        RowLayout {
                            visible:!!row.modelData.done;spacing:6
                            MButton {visible:row.modelData.text!=="";icon:"copy";text:panel.phone ? "" : "Copy";compact:true;tooltip:"Copy answer";onClicked:AssistantState.copy(row.modelData.text)}
                            MButton {visible:row.last&&!AssistantState.busy;icon:"refresh";text:panel.phone ? "" : "Retry";compact:true;tooltip:"Ask again";onClicked:AssistantState.retry()}
                        }
                    }
                }
            }
            ColumnLayout {
                visible:panel.turns.length===0
                anchors.fill:parent;spacing:8
                Item {Layout.fillHeight:true}
                MText {text:"What can I do for you?";role:"title";Layout.fillWidth:true}
                MText {
                    text:"Ask a question or tell me what to do on your desktop. I can open apps, move windows and change settings. I ask before closing windows or running commands.";wrapMode:Text.Wrap
                    Layout.fillWidth:true;role:"bodyS";color:Theme.subtext;elide:Text.ElideNone
                }
                Repeater {
                    model:AssistantState.suggestions
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth:true;Layout.preferredHeight:panel.couch ? 56 : 46;radius:height/2
                        color:panel.couch&&panel.suggestIndex===index ? Theme.primaryContainer : Theme.surfaceHigh
                        border.width:panel.couch&&panel.suggestIndex===index ? 2 : 0;border.color:Theme.primary
                        RowLayout {
                            anchors {fill:parent;leftMargin:16;rightMargin:16} spacing:12
                            Glyph {name:modelData.icon;font.pixelSize:20;color:Theme.primary}
                            MText {text:modelData.text;Layout.fillWidth:true;font.pixelSize:panel.couch ? 16 : 14}
                        }
                        MouseArea {anchors.fill:parent;onClicked:AssistantState.send(modelData.prompt)}
                        Accessible.role:Accessible.Button;Accessible.name:modelData.text
                    }
                }
            }
        }
        Repeater {
            model:AssistantState.approvals
            Rectangle {
                required property var modelData
                Layout.fillWidth:true;Layout.preferredHeight:ask.implicitHeight+28;radius:24
                color:modelData.risk==="high" ? Theme.alpha(Theme.error,.2) : Theme.tertiaryContainer
                border.width:modelData.risk==="high" ? 1 : 0;border.color:Theme.error
                ColumnLayout {
                    id:ask;anchors {left:parent.left;right:parent.right;top:parent.top;margins:14} spacing:8
                    RowLayout {
                        spacing:8
                        Glyph {name:modelData.risk==="high" ? "warning" : "shield";font.pixelSize:20;color:modelData.risk==="high" ? Theme.error : Theme.onTertiaryContainer}
                        MText {text:"Claude wants to: "+modelData.label;font.weight:Font.DemiBold;color:Theme.text;Layout.fillWidth:true;font.pixelSize:14}
                    }
                    MText {
                        visible:modelData.detail!=="";text:modelData.detail;Layout.fillWidth:true;maximumLineCount:4;wrapMode:Text.WrapAnywhere
                        font.family:"monospace";font.pixelSize:12;color:Theme.subtext;elide:Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth:true;spacing:8
                        MText {visible:panel.couch;text:panel.backButton+" Deny   "+panel.acceptButton+" Allow";role:"labelS";color:Theme.subtext;Layout.fillWidth:true}
                        Item {visible:!panel.couch;Layout.fillWidth:true}
                        MButton {text:"Deny";compact:true;tonal:true;onClicked:AssistantState.approve(modelData.id,false)}
                        MButton {text:"Allow";compact:true;filled:true;onClicked:AssistantState.approve(modelData.id,true)}
                    }
                }
            }
        }
        Flow {
            Layout.fillWidth:true;spacing:6;visible:panel.turns.length===0||!AssistantState.busy
            AssistantChip {
                visible:AssistantState.ctxApp!==""&&AssistantState.useApp;icon:"desktop";removable:true;maxWidth:panel.width-60
                text:AssistantState.ctxApp+(AssistantState.ctxTitle!=="" ? " · "+AssistantState.ctxTitle : "")
                onRemoved:AssistantState.useApp=false
            }
            AssistantChip {
                visible:AssistantState.ctxSelection!==""&&AssistantState.useSelection;icon:"edit";removable:true;maxWidth:panel.width-60
                text:"Selection · "+AssistantState.ctxSelection.length+" chars"
                onRemoved:AssistantState.useSelection=false
            }
            AssistantChip {
                visible:AssistantState.ctxClipboard!==""&&AssistantState.useClipboard;icon:"clipboard";removable:true;maxWidth:panel.width-60
                text:"Clipboard · "+AssistantState.ctxClipboard.length+" chars"
                onRemoved:AssistantState.useClipboard=false
            }
            AssistantChip {
                visible:!panel.hasContext&&!AssistantState.busy;icon:"add";text:"Add screen context"
                onClicked:AssistantState.capture()
            }
        }
        Rectangle {
            Layout.fillWidth:true;Layout.preferredHeight:Math.max(52,Math.min(140,field.implicitHeight+16));radius:height>60 ? 26 : 26
            color:Theme.surfaceHigh
            visible:!panel.couch||panel.turns.length>0
            RowLayout {
                anchors {fill:parent;leftMargin:18;rightMargin:6;topMargin:4;bottomMargin:4} spacing:6
                ScrollView {
                    Layout.fillWidth:true;Layout.fillHeight:true
                    TextArea {
                        id:field
                        placeholderText:AssistantState.turns.length ? "Ask a follow-up…" : "Ask Claude…"
                        placeholderTextColor:Theme.muted;color:Theme.text;wrapMode:TextArea.Wrap;background:Item {}
                        font.family:Theme.font;font.pixelSize:14;selectByMouse:true;verticalAlignment:TextArea.AlignVCenter
                        topPadding:12;bottomPadding:12;leftPadding:0
                        Keys.onPressed:e=>{
                            if((e.key===Qt.Key_Return||e.key===Qt.Key_Enter)&&!(e.modifiers&Qt.ShiftModifier)) {panel.submit();e.accepted=true;}
                            else if(e.key===Qt.Key_Escape) {Hub.close();e.accepted=true;}
                        }
                        Component.onCompleted:if(!panel.phone)forceActiveFocus()
                    }
                }
                MButton {visible:AssistantState.busy;icon:"stop";filled:true;tooltip:"Stop";Layout.alignment:Qt.AlignVCenter;onClicked:AssistantState.stop()}
                MButton {visible:!AssistantState.busy;icon:"send";filled:true;tooltip:"Send · Enter";enabled:field.text.trim()!=="";Layout.alignment:Qt.AlignVCenter;onClicked:panel.submit()}
            }
        }
        MText {
            visible:panel.couch;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter;role:"labelS";color:Theme.subtext
            text:panel.acceptButton+" Select   "+panel.backButton+" Back   Menu New chat   Up and Down Scroll"
        }
    }
}
