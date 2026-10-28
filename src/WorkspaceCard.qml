import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Spaces card: one mini map per workspace with its real window layout over the wallpaper, its symbol and name, a tile for a new space, and saved spaces to reopen.
Item {
    id: card
    property var screenObj: null
    signal picked()
    readonly property var spaces: (Hub.status.workspaces || []).filter(n => n > 0).slice().sort((a, b) => a - b)
    readonly property int current: Number(Hub.status.workspace)
    // The workspace whose name, symbol and colour are being edited, or -1.
    property int editing: -1
    property string symbolQuery: ""
    // The monitor in layout coordinates, so window positions map onto the tiles.
    readonly property var monitor: {
        const name = screenObj ? screenObj.name : "";
        const list = Hub.status.monitors || [];
        const m = list.find(x => x.name === name) || list[0] || {x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0};
        const turned = (m.transform || 0) % 2 === 1, scale = m.scale || 1;
        return {name: m.name || "", x: m.x || 0, y: m.y || 0, w: (turned ? m.height : m.width) / scale || 1920, h: (turned ? m.width : m.height) / scale || 1080};
    }
    readonly property real tileW: 216
    readonly property real tileH: Math.max(96, Math.min(170, tileW * monitor.h / monitor.w))
    readonly property real maxW: screenObj ? screenObj.width - 24 : 1200
    implicitWidth: editing >= 0 ? 420 : Math.min(maxW, Math.max(strip.contentWidth + 32, savedRow.implicitWidth + 40))
    implicitHeight: editing >= 0 ? editor.implicitHeight + 32 : header.height + tileH + 70 + (Spaces.saved.length ? savedRow.implicitHeight + 34 : 0)
    onEditingChanged: symbolQuery = ""

    Rectangle {
        anchors.fill: parent; radius: 32
        color: Theme.light ? Theme.surfaceLowest : Theme.level(3)
        border.width: 1; border.color: Theme.glassEdge
    }
    // The badge of a space: its symbol on its colour, else its number.
    component Badge: Rectangle {
        property var info: ({})
        property bool here: false
        property real size: 24
        width: size; height: size; radius: size / 2
        color: info.color ? info.color : here ? Theme.primary : Theme.alpha(Theme.text, .1)
        Glyph { visible: !!parent.info.icon; anchors.centerIn: parent; name: parent.info.icon || ""; font.pixelSize: parent.size * .64; color: parent.info.color ? Theme.base : parent.here ? Theme.onPrimary : Theme.text }
        MText { visible: !parent.info.icon; anchors.centerIn: parent; text: String(parent.info.ws || ""); role: "labelS"; font.weight: Font.Bold; color: parent.info.color ? Theme.base : parent.here ? Theme.onPrimary : Theme.text }
    }
    OpalMenu { id: spaceMenu; property int ws: -1 }
    function menuFor(ws, item, x, y) {
        spaceMenu.ws = ws;
        spaceMenu.entries = [
            {text: "Rename", icon: "edit", run: () => card.editing = ws},
            {text: "Symbol and colour", icon: "palette", run: () => card.editing = ws},
            {text: Spaces.isSaved(ws) ? "Save again" : "Save space", icon: "bookmark_add", run: () => Spaces.save(ws)},
            {text: "Close space", icon: "close", run: () => Spaces.closeAll(ws)}
        ];
        spaceMenu.popupFrom(item, x, y);
    }

    Row {
        id: header
        visible: card.editing < 0
        x: 20; y: 16; spacing: 10; height: 28
        Glyph { name: "space_dashboard"; font.pixelSize: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        MText { text: "Spaces"; role: "titleS"; anchors.verticalCenter: parent.verticalCenter }
        MText { text: card.spaces.length + " open"; role: "labelS"; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
    }
    Flickable {
        id: strip
        visible: card.editing < 0
        x: 16; y: header.y + header.height + 14
        width: parent.width - 32; height: card.tileH + 34
        contentWidth: row.implicitWidth; contentHeight: height
        flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds; clip: true
        Row {
            id: row
            spacing: 12
            Repeater {
                model: card.spaces
                Column {
                    id: space
                    required property var modelData
                    readonly property int ws: Number(modelData)
                    readonly property bool here: ws === card.current
                    readonly property var info: Spaces.info(ws)
                    readonly property var wins: Hub.windows.filter(w => Number(w.workspace) === ws && (!card.monitor.name || !w.monitor || w.monitor === card.monitor.name))
                    spacing: 8
                    Item {
                        id: tile
                        width: card.tileW; height: card.tileH
                        Rectangle { anchors.fill: parent; radius: 18; color: Theme.level(4) }
                        RoundedImage {
                            anchors.fill: parent; radius: 18; opacity: .55
                            visible: !!Hub.prefs.wallpaperPath
                            source: Hub.prefs.wallpaperPath || ""
                            decodeSize: Qt.size(card.tileW * 2, card.tileH * 2)
                        }
                        // The real window layout, scaled down. Each window shows its app icon.
                        Repeater {
                            model: space.wins
                            Rectangle {
                                required property var modelData
                                readonly property var at: modelData.at || [0, 0]
                                readonly property var size: modelData.size || [0, 0]
                                readonly property bool full: !!modelData.fullscreen || size[0] <= 0
                                x: full ? 4 : Math.max(4, (at[0] - card.monitor.x) / card.monitor.w * card.tileW)
                                y: full ? 4 : Math.max(4, (at[1] - card.monitor.y) / card.monitor.h * card.tileH)
                                width: full ? card.tileW - 8 : Math.max(18, Math.min(card.tileW - 4 - x, size[0] / card.monitor.w * card.tileW))
                                height: full ? card.tileH - 8 : Math.max(18, Math.min(card.tileH - 4 - y, size[1] / card.monitor.h * card.tileH))
                                radius: 8
                                color: Theme.alpha(Theme.surfaceHighest, .94)
                                border.width: 1; border.color: Theme.alpha(Theme.text, .14)
                                AppIcon { anchors.centerIn: parent; width: Math.min(30, parent.width * .55, parent.height * .55); height: width; app: Hub.appForWindow(parent.modelData) }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent; visible: space.wins.length === 0
                            width: emptyText.implicitWidth + 20; height: 26; radius: 13; color: Theme.alpha(Theme.base, .78)
                            MText { id: emptyText; anchors.centerIn: parent; text: "Empty"; role: "labelS"; color: Theme.subtext }
                        }
                        Rectangle { anchors.fill: parent; radius: 18; color: "transparent"; border.width: space.here ? 3 : 0; border.color: space.info.color || Theme.primary }
                        Rectangle { anchors.fill: parent; radius: 18; color: Theme.stateLayer; opacity: tileTap.pressed ? .16 : tileHover.hovered ? .08 : 0 }
                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: tileTap; onTapped: { card.picked(); Hub.workspace(space.ws); } onLongPressed: card.menuFor(space.ws, tile, point.position.x, point.position.y) }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: card.menuFor(space.ws, tile, point.position.x, point.position.y) }
                        MButton {
                            id: moreButton
                            visible: tileHover.hovered; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                            icon: "more_vert"; compact: true; implicitWidth: 32; implicitHeight: 32; contained: true; tooltip: "Space options"
                            onClicked: card.menuFor(space.ws, moreButton, moreButton.width / 2, moreButton.height)
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: (space.info.name || "Workspace " + space.ws) + (space.wins.length ? ", " + space.wins.length + " windows" : ", empty")
                    }
                    Row {
                        x: 2; spacing: 8
                        Badge { info: space.info; here: space.here; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            MText {
                                width: Math.min(implicitWidth, card.tileW - 40); elide: Text.ElideRight
                                text: space.info.name || (space.wins.length ? space.wins.length + (space.wins.length === 1 ? " window" : " windows") : "Empty")
                                role: "label"; font.weight: space.info.auto ? Font.Normal : Font.DemiBold; color: space.here ? Theme.primary : Theme.text
                            }
                            MText { visible: space.info.auto && space.info.name !== ""; text: "auto-named"; role: "labelS"; color: Theme.subtext }
                        }
                    }
                }
            }
            Column {
                spacing: 8
                Item {
                    width: card.tileH * .8; height: card.tileH
                    Rectangle { anchors.fill: parent; radius: 18; color: Theme.alpha(Theme.primary, newHover.hovered ? .16 : .1); border.width: 1; border.color: Theme.alpha(Theme.primary, .4) }
                    Glyph { anchors.centerIn: parent; name: "add"; font.pixelSize: 30; color: Theme.primary }
                    HoverHandler { id: newHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { card.picked(); Hub.command({action: "workspace-empty"}); } }
                    Accessible.role: Accessible.Button; Accessible.name: "New space"
                }
                MText { x: 2; height: 24; verticalAlignment: Text.AlignVCenter; text: "New"; role: "labelS"; color: Theme.subtext }
            }
        }
    }
    // Saved spaces: one click reopens a space with its apps.
    Column {
        visible: card.editing < 0 && Spaces.saved.length > 0
        x: 20; y: strip.y + strip.height + 10; spacing: 8
        MText { text: "Saved"; role: "labelS"; color: Theme.subtext }
        Flow {
            id: savedRow
            width: card.width - 40; spacing: 8
            Repeater {
                model: Spaces.saved
                Rectangle {
                    id: savedChip
                    required property var modelData
                    width: savedContent.implicitWidth + 20; height: 44; radius: 22
                    color: savedTap.pressed ? Theme.level(5) : savedHover.hovered ? Theme.surfaceHighest : Theme.level(4)
                    Row {
                        id: savedContent; anchors.centerIn: parent; spacing: 8
                        Badge { info: ({icon: savedChip.modelData.icon || "bookmark", color: savedChip.modelData.color || ""}); size: 28; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: savedChip.modelData.name; role: "label"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                        Row {
                            spacing: -6; anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: (savedChip.modelData.apps || []).slice(0, 3)
                                AppIcon { required property var modelData; width: 20; height: 20; app: Hub.apps.find(a => a.id === modelData.app) || Hub.appIndex[String(modelData.cls || "").toLowerCase()] || null }
                            }
                        }
                    }
                    HoverHandler { id: savedHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: savedTap; onTapped: { card.picked(); Spaces.open(savedChip.modelData); } }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: { spaceMenu.entries = [{text: "Open", icon: "open_in_new", run: () => { card.picked(); Spaces.open(savedChip.modelData); }}, {text: "Remove from saved", icon: "delete", run: () => Spaces.unsave(savedChip.modelData.id)}]; spaceMenu.popupFrom(savedChip, point.position.x, point.position.y); }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: "Open saved space " + modelData.name
                }
            }
        }
    }
    // Editor: name, symbol, colour and saving for one space.
    ColumnLayout {
        id: editor
        visible: card.editing >= 0
        readonly property var info: card.editing >= 0 ? Spaces.info(card.editing) : ({})
        readonly property var stored: card.editing >= 0 ? (Spaces.named[String(card.editing)] || {}) : ({})
        x: 18; y: 16; width: parent.width - 36; spacing: 14
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            MButton { icon: "back"; compact: true; implicitWidth: 40; implicitHeight: 40; contained: true; tooltip: "Back"; onClicked: card.editing = -1 }
            MText { text: "Space " + card.editing; role: "title"; Layout.fillWidth: true }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Badge { info: Object.assign({}, editor.info, {icon: editor.stored.icon || "", color: editor.stored.color || ""}); size: 56; here: card.editing === card.current }
            OpalField {
                id: nameField
                Layout.fillWidth: true; maximumLength: 40
                placeholderText: editor.info.auto && editor.info.name ? editor.info.name + " (automatic)" : "Name"
                text: editor.stored.name || ""
                onEditingFinished: Spaces.update(card.editing, {name: text.trim()})
                Keys.onReturnPressed: { Spaces.update(card.editing, {name: text.trim()}); card.editing = -1; }
            }
        }
        OpalField {
            Layout.fillWidth: true; placeholderText: "Search symbols"
            text: card.symbolQuery; onTextChanged: card.symbolQuery = text.toLowerCase().replace(/\s+/g, "_")
        }
        GridLayout {
            Layout.fillWidth: true; columns: 8; columnSpacing: 6; rowSpacing: 6
            Repeater {
                model: Spaces.symbols.filter(s => card.symbolQuery === "" || s.indexOf(card.symbolQuery) >= 0).slice(0, 24)
                Rectangle {
                    required property string modelData
                    readonly property bool chosen: editor.stored.icon === modelData
                    Layout.preferredWidth: (editor.width - 42) / 8; Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2; color: chosen ? Theme.secondaryContainer : symbolHover.hovered ? Theme.alpha(Theme.text, .12) : Theme.alpha(Theme.text, .06)
                    border.width: chosen ? 2 : 0; border.color: Theme.primary
                    Glyph { anchors.centerIn: parent; name: parent.modelData; font.pixelSize: 20; color: parent.chosen ? Theme.onSecondaryContainer : Theme.text }
                    HoverHandler { id: symbolHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Spaces.update(card.editing, {icon: parent.chosen ? "" : parent.modelData, color: editor.stored.color || Spaces.colors[card.editing % Spaces.colors.length]}) }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.replace(/_/g, " ")
                }
            }
        }
        MText { text: "Colour"; role: "labelS"; color: Theme.subtext }
        Row {
            spacing: 10
            Repeater {
                model: Spaces.colors
                Rectangle {
                    required property string modelData
                    readonly property bool chosen: editor.stored.color === modelData
                    width: 34; height: 34; radius: 17; color: modelData
                    border.width: chosen ? 3 : 0; border.color: Theme.text
                    Glyph { visible: parent.chosen; anchors.centerIn: parent; name: "check"; font.pixelSize: 18; color: Theme.base }
                    TapHandler { onTapped: Spaces.update(card.editing, {color: parent.chosen ? "" : parent.modelData}) }
                    Accessible.role: Accessible.Button; Accessible.name: "Colour " + modelData
                }
            }
        }
        SettingRow {
            Layout.fillWidth: true
            title: "Save space"; description: "Keeps its apps, layout, symbol and colour. Reopen it from Spaces or search."
            toggle: true; checked: card.editing >= 0 && Spaces.isSaved(card.editing)
            onActivated: { if (nameField.text.trim() !== "") Spaces.update(card.editing, {name: nameField.text.trim()}); if (checked) { const n = Spaces.info(card.editing).name.toLowerCase(); const s = Spaces.saved.find(x => x.name.toLowerCase() === n); if (s) Spaces.unsave(s.id); } else Spaces.save(card.editing); }
        }
        RowLayout {
            Layout.fillWidth: true
            MButton { text: "Clear"; compact: true; ink: Theme.subtext; onClicked: { Spaces.forget(card.editing); nameField.text = ""; } }
            Item { Layout.fillWidth: true }
            MButton { text: "Done"; filled: true; onClicked: { Spaces.update(card.editing, {name: nameField.text.trim()}); card.editing = -1; } }
        }
    }
}
