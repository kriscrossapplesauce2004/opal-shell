import QtQuick
import Quickshell
import Quickshell.Wayland

// Snap Assist: after a window snaps into part of a layout, the other windows of the workspace are offered for the empty parts.
// Pick a window and it fills that part; Escape or a click outside the parts keeps things as they are.
Scope {
    id: assist
    // From the backend's snapAssist event: monitor, workspace, cells [{cell, rect}] and the windows that already have a place.
    property var data: null
    property var cells: []
    property var taken: []
    property real reveal: 0
    readonly property bool open: cells.length > 0 && candidates.length > 0
    readonly property var candidates: !data ? [] : Hub.windows.filter(w => Number(w.workspace) === Number(data.workspace) && !Hub.minimized(w)
        && (data.exclude || []).indexOf(w.address) < 0 && taken.indexOf(w.address) < 0)
    function show(event) { console.warn("ASSISTDBG show " + JSON.stringify(event.cells.map(c => c.cell))); data = event; cells = event.cells || []; taken = []; }
    function dismiss() { console.warn("ASSISTDBG dismiss"); cells = []; }
    // The Repeater hands out copies of the cells, so the picked part goes by its index.
    function pick(entry, index) {
        const cell = cells[index];
        if (!cell) return;
        Hub.command({action: "window-snap", address: entry.address, cell: cell.cell, monitor: data.monitor, assist: true});
        taken = taken.concat([entry.address]);
        cells = cells.filter((c, i) => i !== index);
    }
    onOpenChanged: { grow.to = open ? 1 : 0; grow.restart(); }
    // A new drag or another workspace ends the offer.
    Connections {
        target: Hub
        function onStatusChanged() {
            if (!assist.open) return;
            const drag = Hub.status.windowDrag;
            if (drag && drag.kind === "begin") assist.dismiss();
            else if (assist.data && Number(Hub.status.workspace) !== Number(assist.data.workspace) && Hub.status.activeMonitor === assist.data.monitor) assist.dismiss();
        }
    }
    NumberAnimation { id: grow; target: assist; property: "reveal"; duration: Theme.motion(grow.to > 0 ? 320 : 180); easing.type: Easing.BezierSpline; easing.bezierCurve: grow.to > 0 ? Theme.emphasizedDecelerate : Theme.emphasizedAccelerate }
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => assist.data && s.name === assist.data.monitor) || Quickshell.screens[0]
        visible: assist.open || assist.reveal > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-snap-assist"
        WlrLayershell.keyboardFocus: assist.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        // The whole screen takes input, transparent parts included, so a press anywhere else ends it.
        mask: Region { x: 0; y: 0; width: win.screen ? win.screen.width : 0; height: win.screen ? win.screen.height : 0 }
        // A press outside the empty parts ends the offer.
        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: console.warn("ASSISTDBG scrim hover"); onPressed: { console.warn("ASSISTDBG scrim press"); assist.dismiss(); } }
        Item {
            anchors.fill: parent
            focus: assist.open
            Keys.onEscapePressed: assist.dismiss()
            Repeater {
                model: assist.cells
                Rectangle {
                    id: part
                    required property var modelData
                    required property int index
                    // The column count that gives the largest cards that still fit the part without scrolling.
                    readonly property var fit: {
                        const n = Math.max(1, assist.candidates.length), w = width - 32, h = height - 80;
                        let best = {columns: 1, width: Math.min(380, w)};
                        for (let c = 1; c <= n; c++) {
                            const rows = Math.ceil(n / c), cw = Math.min(380, (w - (c - 1) * 12) / c);
                            if (rows * (cw * .62 + 44) + (rows - 1) * 12 <= h) { best = {columns: c, width: cw}; break; }
                            best = {columns: c, width: cw};
                        }
                        return best;
                    }
                    readonly property int columns: fit.columns
                    readonly property real cardWidth: fit.width
                    x: modelData.rect[0]; y: modelData.rect[1]; width: modelData.rect[2]; height: modelData.rect[3]
                    radius: Theme.shapeLg
                    color: Theme.alpha(Theme.level(2), .94)
                    border.width: 1; border.color: Theme.outline
                    opacity: assist.reveal
                    scale: .96 + .04 * assist.reveal
                    clip: true
                    MouseArea { anchors.fill: parent }
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 14
                        Row {
                            spacing: 8
                            Glyph { name: "auto_awesome_mosaic"; font.pixelSize: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            MText { text: "Choose a window for this space"; role: "titleS"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Flickable {
                            width: parent.width; height: parent.height - 48
                            contentHeight: grid.implicitHeight; clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Grid {
                                id: grid
                                columns: part.columns; spacing: 12
                                Repeater {
                                    model: assist.candidates
                                    Rectangle {
                                        id: card
                                        required property var modelData
                                        required property int index
                                        readonly property var app: Hub.appForWindow(modelData)
                                        width: part.cardWidth; height: width * .62 + 44
                                        radius: Theme.shapeMd
                                        color: hover.containsMouse ? Theme.alpha(Theme.primary, .16) : Theme.alpha(Theme.text, .05)
                                        border.width: activeFocus || hover.containsMouse ? 2 : 0; border.color: Theme.primary
                                        scale: hover.pressed ? .97 : 1
                                        // Cards rise in one after another.
                                        property real entrance: 0
                                        opacity: entrance; transform: Translate { y: 14 * (1 - card.entrance) }
                                        Component.onCompleted: enter.restart()
                                        SequentialAnimation { id: enter
                                            PauseAnimation { duration: Theme.motion(Math.min(card.index, 6) * 30 + 60) }
                                            NumberAnimation { target: card; property: "entrance"; to: 1; duration: Theme.motion(280); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate }
                                        }
                                        Behavior on color { ColorAnimation { duration: Theme.motion(120) } }
                                        Behavior on scale { NumberAnimation { duration: Theme.motion(120) } }
                                        Rectangle {
                                            x: 6; y: 6; width: parent.width - 12; height: parent.height - 50; radius: Theme.shapeSm
                                            color: Theme.alpha(Theme.base, .55); clip: true
                                            Loader { anchors.fill: parent; anchors.margins: 2; active: assist.open; source: "HyprWindowPreview.qml"; onLoaded: item.address = Qt.binding(() => card.modelData.address || "") }
                                        }
                                        Row {
                                            x: 12; y: parent.height - 38; width: parent.width - 24; spacing: 8
                                            Image { id: icon; width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter; source: Quickshell.iconPath(card.app ? card.app.icon : "application-x-executable", true) }
                                            MText { width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; text: card.modelData.title || (card.app ? card.app.name : card.modelData.className); elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.DemiBold }
                                        }
                                        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: assist.pick(card.modelData, part.index) }
                                        activeFocusOnTab: true
                                        Keys.onReturnPressed: assist.pick(card.modelData, part.index)
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Snap " + (card.modelData.title || "window") + " here"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
