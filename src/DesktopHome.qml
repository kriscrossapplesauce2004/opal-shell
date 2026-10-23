import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// Desktop home on the wallpaper: ~/Desktop as icons, a free widget canvas on a grid, and a "pick up" glance while the workspace is empty.
Item {
    id: home
    property string screenName: ""
    // The desktop widgets preference. Icons and the glance stay when it is off.
    property bool widgets: true

    readonly property bool editing: HomeData.editingScreen !== "" && HomeData.editingScreen === screenName
    readonly property real cell: 80
    readonly property int columns: Math.max(8, Math.floor(width / cell))
    readonly property int rows: Math.max(6, Math.floor(height / cell))
    // The default canvas: glance, photo memory, devices and a clock at the right edge.
    readonly property var defaults: [
        {id: "glance", kind: "glance", x: columns - 6, y: 0, w: 5, h: 1},
        {id: "photos", kind: "photos", x: columns - 6, y: 1, w: 5, h: 3},
        {id: "devices", kind: "devices", x: columns - 6, y: 4, w: 2, h: 2},
        {id: "clock", kind: "clock", x: columns - 4, y: 4, w: 3, h: 2},
        {id: "live", kind: "live", x: columns - 6, y: 6, w: 5, h: 2}
    ]
    readonly property var canvas: (Array.isArray(Hub.prefs.desktopCanvas) ? Hub.prefs.desktopCanvas : defaults).map(w => Object.assign({}, w, {x: Math.min(w.x, columns - w.w), y: Math.min(w.y, rows - w.h)}))
    readonly property var monitor: (Hub.status.monitors || []).find(m => m.name === screenName) || null
    // Empty means this output's active workspace has no windows.
    readonly property bool emptyWorkspace: !!monitor && !(Hub.windows || []).some(w => w.workspace === monitor.workspace && !w.minimized)
    function save(list) { Hub.set("desktopCanvas", list.map(w => ({id: w.id, kind: w.kind, x: Math.max(0, Math.round(w.x)), y: Math.max(0, Math.round(w.y)), w: Math.round(w.w), h: Math.round(w.h)}))); }
    function place(id, change) { save(canvas.map(w => w.id === id ? Object.assign({}, w, change) : w)); }
    function remove(id) { save(canvas.filter(w => w.id !== id)); }
    function add(kind) {
        const sizes = {glance: [5, 1], media: [5, 2], photos: [4, 3], devices: [2, 2], clock: [3, 2], live: [5, 2]};
        const size = sizes[kind] || [3, 2];
        save(canvas.concat([{id: kind + Date.now() % 100000, kind: kind, x: Math.max(0, Math.floor((columns - size[0]) / 2)), y: 1, w: size[0], h: size[1]}]));
    }

    // ~/Desktop icons in a column-major grid of slots. Dragged icons keep their slot.
    Item {
        id: icons
        visible: Hub.prefs.desktopIcons !== false
        x: 12; y: 12; width: Math.min(parent.width * .45, 6 * slotW); height: parent.height - 24
        readonly property real slotW: 96
        readonly property real slotH: 104
        readonly property int perColumn: Math.max(1, Math.floor(height / slotH))
        readonly property var slots: {
            const saved = Hub.prefs.desktopSlots || {}, used = {}, out = [];
            // Icons without a saved slot fill the free slots in the chosen order: folders first, then by name, type or date.
            const sort = Hub.prefs.desktopSort || "name";
            const items = HomeData.desktopItems.slice().sort((a, b) => (b.dir - a.dir)
                || (sort === "date" ? (b.mtime || 0) - (a.mtime || 0) : sort === "type" ? String(a.type || "").localeCompare(String(b.type || "")) : 0)
                || a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
            items.forEach(it => { const s = saved[it.name]; if (typeof s === "number" && !used[s]) { used[s] = true; out.push({item: it, slot: s}); } });
            let next = 0;
            items.forEach(it => { if (out.some(o => o.item === it)) return; while (used[next]) next++; used[next] = true; out.push({item: it, slot: next}); });
            return out;
        }
        property string selected: ""
        // How many icon columns hold icons now; the glance starts after them.
        readonly property int usedColumns: slots.length ? Math.floor(Math.max.apply(null, slots.map(o => o.slot)) / perColumn) + 1 : 0
        function slotAt(x, y) { return Math.max(0, Math.floor(x / slotW)) * perColumn + Math.max(0, Math.min(perColumn - 1, Math.floor(y / slotH))); }
        function moveTo(name, slot) {
            const map = Object.assign({}, Hub.prefs.desktopSlots || {});
            const other = slots.find(o => o.slot === slot && o.item.name !== name);
            const mine = slots.find(o => o.item.name === name);
            if (other && mine) map[other.item.name] = mine.slot;
            map[name] = slot;
            // Keep only names that still exist on the desktop.
            const keep = {};
            HomeData.desktopItems.forEach(it => { if (map[it.name] !== undefined) keep[it.name] = map[it.name]; });
            Hub.set("desktopSlots", keep);
        }
        Repeater {
            model: icons.slots
            Item {
                id: tile
                required property var modelData
                readonly property var it: modelData.item
                readonly property bool chosen: icons.selected === it.path
                x: Math.floor(modelData.slot / icons.perColumn) * icons.slotW
                y: (modelData.slot % icons.perColumn) * icons.slotH
                width: icons.slotW; height: icons.slotH
                Behavior on x { enabled: !drag.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !drag.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 4; radius: 14
                    color: tile.chosen ? Theme.alpha(Theme.primary, .38) : mouse.containsMouse ? Theme.alpha("#ffffff", .18) : "transparent"
                    border.width: tile.chosen ? 1 : 0; border.color: Theme.alpha(Theme.primary, .7)
                    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 10; spacing: 6; width: parent.width - 12
                    Item {
                        width: 52; height: 52; anchors.horizontalCenter: parent.horizontalCenter
                        RoundedImage { anchors.fill: parent; visible: !!tile.it.thumb; source: tile.it.thumb || ""; radius: 10; decodeSize: Qt.size(104, 104) }
                        Image {
                            id: themeIcon
                            anchors.fill: parent; visible: !tile.it.thumb && status === Image.Ready; asynchronous: true; sourceSize: Qt.size(104, 104)
                            // An empty path when the theme has no match, so the symbol below shows instead.
                            source: tile.it.thumb ? "" : Quickshell.iconPath(tile.it.icon || "text-x-generic", true) || Quickshell.iconPath(tile.it.dir ? "folder" : "text-x-generic", true)
                        }
                        Glyph { anchors.centerIn: parent; visible: !tile.it.thumb && themeIcon.status !== Image.Ready; name: tile.it.glyph || "draft"; font.pixelSize: 40; color: Theme.primary }
                    }
                    // Plasma-style label: always white, with a small dense drop shadow that hugs the letters.
                    Item {
                        id: labelBox
                        width: parent.width; height: label.contentHeight + 6

                        MText {
                            id: label
                            anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; text: tile.it.name; role: "label"
                            maximumLineCount: tile.chosen ? 3 : 2; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; elide: Text.ElideRight
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 1; blurMax: 8; shadowBlur: .5; shadowScale: 1.04; shadowHorizontalOffset: 1; shadowVerticalOffset: 1 }
                        }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => { icons.selected = tile.it.path; if (e.button === Qt.RightButton) fileMenu.popupFrom(tile, e.x, e.y); }
                    onDoubleClicked: Hub.command({action: "desktop-open", path: tile.it.path})
                }
                DragHandler {
                    id: drag
                    target: tile
                    onActiveChanged: if (!active) icons.moveTo(tile.it.name, icons.slotAt(tile.x + tile.width / 2, tile.y + tile.height / 2))
                }
                OpalMenu {
                    id: fileMenu
                    inWindow: true
                    title: tile.it.name; icon: tile.it.dir ? "folder" : tile.it.glyph || "draft"
                    entries: [
                        {text: "Open", icon: "open_in_new", run: () => Hub.command({action: "desktop-open", path: tile.it.path})},
                        {text: "Show in Files", icon: "folder_open", run: () => Hub.command({action: "desktop-reveal", path: tile.it.path})},
                        {text: "Copy path", icon: "content_copy", run: () => Hub.command({action: "clipboard", text: tile.it.path})},
                        {text: "Move to trash", icon: "delete", run: () => Hub.command({action: "desktop-trash", path: tile.it.path})}
                    ]
                }
                Accessible.role: Accessible.Button
                Accessible.name: tile.it.name
                Accessible.onPressAction: Hub.command({action: "desktop-open", path: tile.it.path})
            }
        }
    }

    // Widget canvas. In edit mode each widget drags and resizes on the grid.
    Repeater {
        model: home.canvas
        Item {
            id: slot
            required property var modelData
            visible: home.widgets || home.editing
            x: modelData.x * home.cell + 8; y: modelData.y * home.cell + 8
            width: modelData.w * home.cell - 16; height: modelData.h * home.cell - 16
            Behavior on x { enabled: !move.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !move.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
            Behavior on width { enabled: !resize.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !resize.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
            HomeWidget { anchors.fill: parent; kind: slot.modelData.kind; editing: home.editing }
            Rectangle {
                visible: home.editing; anchors.fill: parent; anchors.margins: -4; radius: 30; color: "transparent"
                border.width: 2; border.color: Theme.alpha(Theme.primary, move.active || resize.active ? .9 : .5)
            }
            DragHandler {
                id: move
                enabled: home.editing; target: slot
                onActiveChanged: if (!active) home.place(slot.modelData.id, {x: Math.max(0, Math.min(home.columns - slot.modelData.w, Math.round((slot.x - 8) / home.cell))), y: Math.max(0, Math.min(home.rows - slot.modelData.h, Math.round((slot.y - 8) / home.cell)))})
            }
            Rectangle {
                visible: home.editing; width: 28; height: 28; radius: 14; color: Theme.primary
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: -6
                Glyph { anchors.centerIn: parent; name: "open_in_full"; font.pixelSize: 16; color: Theme.onPrimary; rotation: 90 }
                DragHandler {
                    id: resize
                    target: null
                    property real startW: 0
                    property real startH: 0
                    onActiveChanged: {
                        if (active) { startW = slot.width; startH = slot.height; }
                        else home.place(slot.modelData.id, {w: Math.max(1, Math.min(12, Math.round((slot.width + 16) / home.cell))), h: Math.max(1, Math.min(10, Math.round((slot.height + 16) / home.cell)))});
                    }
                    onTranslationChanged: if (active) { slot.width = Math.max(home.cell - 16, startW + translation.x); slot.height = Math.max(home.cell - 16, startH + translation.y); }
                }
            }
            Rectangle {
                visible: home.editing; width: 28; height: 28; radius: 14; color: Theme.error
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: -6
                Glyph { anchors.centerIn: parent; name: "close"; font.pixelSize: 16; color: Theme.base }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.remove(slot.modelData.id) }
                Accessible.role: Accessible.Button; Accessible.name: "Remove widget"
            }
        }
    }

    // Edit bar: add widgets, reset and finish.
    Rectangle {
        visible: home.editing
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 96
        width: editRow.implicitWidth + 20; height: 56; radius: 28; color: Theme.level(3)
        Row {
            id: editRow
            anchors.centerIn: parent; spacing: 8
            Repeater {
                model: [{k: "glance", t: "Glance", g: "today"}, {k: "media", t: "Media", g: "music_note"}, {k: "photos", t: "Photos", g: "photo"}, {k: "devices", t: "Devices", g: "devices"}, {k: "clock", t: "Clock", g: "schedule"}, {k: "live", t: "Live", g: "bolt"}]
                MorphChip { required property var modelData; icon: modelData.g; text: modelData.t; onClicked: home.add(modelData.k) }
            }
            Rectangle { width: 1; height: 28; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            MButton { text: "Reset"; compact: true; onClicked: Hub.set("desktopCanvas", home.defaults) }
            MButton { text: "Done"; icon: "check"; compact: true; filled: true; onClicked: HomeData.editingScreen = "" }
        }
    }

    // Pick up where you left off. It shows while this workspace is empty and fades out when a window opens.
    Item {
        id: glance
        readonly property var player: Mpris.players.values.find(p => !p.isPlaying && p.trackTitle !== "") || null
        readonly property var cards: {
            const out = [];
            (PhoneState.activity.files || []).slice(0, 2).forEach(f => out.push({icon: "description", app: "", title: f.title, detail: "Opened " + (f.ago || "recently"), run: () => Hub.command({action: "open-path", path: f.path})}));
            (PhoneState.activity.games || []).slice(0, 1).forEach(g => out.push({icon: "sports_esports", app: "", title: g.title, detail: "Played " + (g.ago || "recently"), art: g.hero || g.cover || "", run: () => { const game = (Hub.games || []).find(x => x.id === g.id); if (game) Hub.launchGame(game); }}));
            if (player) out.push({icon: "play_arrow", app: player.desktopEntry || "", title: player.trackTitle, detail: "Paused · " + (player.identity || "Media"), art: player.trackArtUrl || "", run: () => player.play()});
            (Hub.linkDevices || []).filter(d => d.reachable && d.session && d.session.app).slice(0, 1).forEach(d => {
                const app = Hub.appForClass(d.session.app);
                out.push({icon: "smartphone", app: app ? app.icon : "", title: d.session.title || (app ? app.name : d.session.app), detail: "Open on " + d.name, run: () => { if (app) Hub.launch(app); }});
            });
            return out.slice(0, Math.max(1, fit));
        }
        readonly property real start: icons.visible ? icons.x + icons.usedColumns * icons.slotW + 48 : 48
        readonly property real room: home.width - start - (home.widgets ? 460 : 48)
        readonly property int fit: Math.min(4, Math.floor((room + 14) / 228))
        visible: opacity > 0
        opacity: home.emptyWorkspace && !home.editing && cards.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durLong); easing.type: Easing.OutCubic } }
        x: Math.max(start, start + (room - width) / 2)
        y: parent.height * .3
        width: row.implicitWidth; height: col.implicitHeight
        Column {
            id: col
            spacing: 16
            // White text with a soft glow, like the icon labels, so the heading reads on any wallpaper.
            Column {
                id: heading
                spacing: 6
                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                // Big text gets a wide, faint, centred shadow; a tight offset one looks like a doubled outline at this size.
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: .55; blurMax: 32; shadowBlur: 1; shadowScale: 1; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
                MText { text: "Pick up where you left off"; role: "displayS"; color: "#ffffff" }
                MText { text: home.monitor ? "Workspace " + home.monitor.workspace + " is empty" : ""; role: "body"; color: "#ffffff" }
            }
            Row {
                id: row
                spacing: 14; topPadding: 4
                Repeater {
                    model: glance.cards
                    Rectangle {
                        id: card
                        required property var modelData
                        width: 214; height: 148; radius: 26; color: Theme.fill(Theme.level(2), .94, "widgets")
                        scale: cardMouse.pressed ? .97 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
                        RoundedImage { anchors.fill: parent; visible: !!card.modelData.art; source: card.modelData.art || ""; radius: 26; decodeSize: Qt.size(428, 296) }
                        Rectangle { anchors.fill: parent; radius: 26; visible: !!card.modelData.art; color: Theme.alpha(Theme.base, .6) }
                        Column {
                            x: 16; y: 16; width: parent.width - 32; spacing: 4
                            Item {
                                width: 30; height: 30
                                AppIcon { anchors.fill: parent; visible: !!card.modelData.app; style: "raw"; name: card.modelData.app || "" }
                                Glyph { anchors.centerIn: parent; visible: !card.modelData.app; name: card.modelData.icon; font.pixelSize: 26; color: Theme.primary }
                            }
                            Item { width: 1; height: 22 }
                            MText { width: parent.width; text: card.modelData.title; role: "titleS" }
                            MText { width: parent.width; text: card.modelData.detail; role: "labelS"; color: Theme.subtext }
                        }
                        MouseArea { id: cardMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.modelData.run() }
                        Accessible.role: Accessible.Button
                        Accessible.name: card.modelData.title + ", " + card.modelData.detail
                    }
                }
            }
        }
    }
    Component.onCompleted: PhoneState.refreshActivity()
    onEmptyWorkspaceChanged: if (emptyWorkspace) PhoneState.refreshActivity()
}
