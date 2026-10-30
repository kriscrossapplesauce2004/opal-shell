import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Live window preview card anchored above a hovered taskbar icon, with 1-click Snap Group restore.
PanelWindow {
    id: hoverWin
    screen: Hub.taskHoverScreen || Quickshell.screens[0]
    readonly property var group: Hub.taskHoverGroup
    readonly property var wins: group && group.windows ? group.windows.slice(0, 4) : []
    readonly property var snapGroup: {
        if (!wins.length) return null;
        for (let i = 0; i < wins.length; i++) {
            const g = Hub.snapGroupFor(wins[i].address);
            if (g) return g;
        }
        return null;
    }
    readonly property string snapPartnerLabel: {
        if (!snapGroup) return "";
        const names = [];
        (snapGroup.members || []).forEach(m => {
            const w = Hub.windows.find(x => x.address === m.address);
            if (!w) return;
            const a = Hub.appForWindow(w);
            const label = a ? a.name : (w.className || w.title || "Window");
            if (names.indexOf(label) < 0) names.push(label);
        });
        return names.length > 1 ? names.join(" + ") : "";
    }
    visible: Hub.taskHoverOpen && wins.length > 0 && !Hub.taskbarContextOpen && Hub.page === ""
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "opal-task-hover"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    mask: Region {
        Region {
            x: hoverWin.visible ? card.x - 8 : 0
            y: hoverWin.visible ? card.y - 8 : 0
            width: hoverWin.visible ? card.width + 16 : 0
            height: hoverWin.visible ? card.height + 24 : 0
        }
    }

    Surface {
        id: card
        readonly property bool previews: Hub.prefs.switcherPreviews !== false
        width: body.implicitWidth + 24
        height: body.implicitHeight + 24
        radius: 26
        kind: "menus"
        translucency: Math.max(.76, Hub.prefs.glass + .18)
        elevated: false
        border.color: Theme.alpha(Theme.outline, .72)
        x: Math.max(12, Math.min(Hub.taskHoverX - width / 2, hoverWin.width - width - 12))
        y: Math.max(12, hoverWin.height - Hub.taskHoverBottom - height - 10)

        HoverHandler {
            id: cardHover
            onHoveredChanged: Hub.setTaskCardHovered(hovered)
        }

        ColumnLayout {
            id: body
            x: 12; y: 12
            spacing: 10

            // Snap Group restore banner when this app is snapped alongside another app.
            Rectangle {
                visible: hoverWin.snapPartnerLabel !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: groupMouse.containsMouse ? Theme.primary : Theme.primaryContainer
                Behavior on color { ColorAnimation { duration: Theme.motion(140) } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    Glyph { name: "splitscreen"; font.pixelSize: 17; color: groupMouse.containsMouse ? Theme.onPrimary : Theme.onContainer }
                    MText {
                        Layout.fillWidth: true
                        text: "Snap group · " + hoverWin.snapPartnerLabel
                        role: "label"
                        color: groupMouse.containsMouse ? Theme.onPrimary : Theme.onContainer
                    }
                    MText {
                        text: "Restore pair"
                        role: "labelS"
                        color: Theme.alpha(groupMouse.containsMouse ? Theme.onPrimary : Theme.onContainer, .82)
                    }
                }
                MouseArea {
                    id: groupMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const first = hoverWin.snapGroup.members[0];
                        if (first) Hub.focusSnapGroup(first.address);
                        Hub.closeTaskHover();
                    }
                }
            }

            Row {
                spacing: 10
                Repeater {
                    model: hoverWin.wins
                    Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool isActive: Hub.active(modelData)
                        readonly property bool isMin: Hub.minimized(modelData)
                        width: 204
                        height: card.previews ? 148 : 56
                        radius: 18
                        color: tileMouse.containsMouse ? Theme.level(4) : Theme.level(3)
                        border.width: isActive ? 2 : 1
                        border.color: isActive ? Theme.primary : Theme.outline
                        Behavior on color { ColorAnimation { duration: Theme.motion(120) } }

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 8
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Image {
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                    sourceSize: Qt.size(36, 36)
                                    source: Quickshell.iconPath(hoverWin.group ? hoverWin.group.icon : "application-x-executable", true)
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: tile.modelData.title || (hoverWin.group ? hoverWin.group.name : "Window")
                                    role: "label"
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: tile.modelData.workspace > 0
                                    Layout.preferredWidth: wsLabel.implicitWidth + 10; Layout.preferredHeight: 18; radius: 9
                                    color: Theme.alpha(Theme.text, .08)
                                    MText { id: wsLabel; anchors.centerIn: parent; text: tile.isMin ? "Min" : String(tile.modelData.workspace); role: "labelS"; color: Theme.subtext }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11
                                    color: closeHover.containsMouse ? Theme.error : "transparent"
                                    Glyph { anchors.centerIn: parent; name: "close"; font.pixelSize: 14; color: closeHover.containsMouse ? Theme.base : Theme.subtext }
                                    MouseArea {
                                        id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Hub.closeWindow(tile.modelData);
                                            if (hoverWin.wins.length <= 1) Hub.closeTaskHover();
                                        }
                                    }
                                }
                            }
                            Item {
                                visible: card.previews
                                Layout.fillWidth: true; Layout.fillHeight: true
                                Rectangle { anchors.fill: parent; radius: 12; color: Theme.level(2) }
                                Item {
                                    anchors.fill: parent
                                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: previewMask; maskThresholdMin: .5; maskSpreadAtMin: 1 }
                                    Loader {
                                        anchors.fill: parent
                                        asynchronous: true
                                        active: hoverWin.visible && card.previews
                                        source: Hub.status.hypr ? "HyprWindowPreview.qml" : "WindowPreview.qml"
                                        onLoaded: {
                                            if (Hub.status.hypr) item.address = Qt.binding(() => tile.modelData.address || "");
                                            else item.handle = Qt.binding(() => tile.modelData.handle || null);
                                        }
                                    }
                                }
                                Rectangle { id: previewMask; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
                            }
                        }
                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent; z: -1
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: e => {
                                if (e.button === Qt.MiddleButton) {
                                    Hub.closeWindow(tile.modelData);
                                } else {
                                    Hub.focusWindow(tile.modelData);
                                    Hub.closeTaskHover();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
