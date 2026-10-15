import QtQuick
import QtQuick.Layouts
import Quickshell

// Phone and tablet home: a -1 "Live" page, then pages where widgets and icons share one grid. Pixel-style editing: long-press an icon for its menu, keep holding to drag it.
Item {
    id: home
    property bool wide: width >= 720
    property bool editing: false
    property bool batteryOpen: false
    property bool pickerOpen: false
    property var openFolder: null
    property int openFolderPage: -1
    property int openFolderIndex: -1
    // The icon whose long-press menu is open: {page, index, app, x, y}.
    property var menuFor: null
    property alias pager: pager
    readonly property int columns: PhoneState.columnsFor(pager.width, wide) + (wide ? 1 : 0)
    readonly property real cellWidth: (pager.width - 8) / columns
    readonly property real cellHeight: PhoneState.cellHeight(Math.min(cellWidth, 104))
    readonly property int dockCount: wide ? 0 : Math.min(4, Hub.favoriteApps.length)
    // The layout changes only when the saved home changes. Other preference changes must not rebuild the pages or reset the page.
    readonly property string layoutKey: JSON.stringify(Hub.phoneHome)
    property var layout: ({pages: [{widgets: [], items: []}]})
    onLayoutKeyChanged: layout = {pages: JSON.parse(layoutKey).pages.map(p => ({widgets: p.widgets.map(norm), items: p.items}))}
    Component.onCompleted: layout = {pages: JSON.parse(layoutKey).pages.map(p => ({widgets: p.widgets.map(norm), items: p.items}))}
    readonly property var live: Activities.list.find(a => a.kind !== "media") || null
    PenWatcher { anchors.fill: parent }
    signal dragProgress(real value)
    signal dragFinished(bool open)
    signal openDrawer(bool search)

    // Old layouts store widgets as names. A name becomes a full-width widget with its usual height.
    function norm(w) {
        if (typeof w === "string") return {kind: w, w: 4, h: ({glance: 1, battery: 1, focus: 1, clock: 2, devices: 2, photos: 2, media: 2, stack: 2, calendar: 2, live: 2})[w] || 2};
        return {kind: w.kind, w: w.w, h: w.h};
    }
    function copy() { return JSON.parse(JSON.stringify(layout)); }
    function appFor(id) { return Hub.apps.find(a => a.id === id) || null; }
    // While editing, empty pages stay so items can move onto them. Leaving edit mode trims them.
    function save(next) { Hub.setPhoneHome(next, editing); }
    function finishEditing() { editing = false; pickerOpen = false; Hub.setPhoneHome(copy(), false); }
    function pageIndex() { return Math.max(0, pager.currentIndex - 1); }
    // Pack widgets row by row, then icons in the cells after the last widget row.
    function pack(page) {
        const placed = [];
        let x = 0, y = 0, rowH = 0;
        page.widgets.forEach((w, i) => {
            const collapsed = w.kind === "live" && home.live === null && !home.editing;
            // On a phone a 4-wide widget fills the row whatever the column count.
            const ww = !home.wide && w.w >= 4 ? columns : Math.min(columns, Math.max(1, w.w)), hh = collapsed ? 0 : w.h;
            if (hh === 0) return;
            if (x + ww > columns) { x = 0; y += rowH; rowH = 0; }
            placed.push(Object.assign({}, w, {index: i, x: x, y: y, cw: ww, ch: hh}));
            x += ww; rowH = Math.max(rowH, hh);
            if (x >= columns) { x = 0; y += rowH; rowH = 0; }
        });
        return {widgets: placed, firstRow: y + rowH};
    }
    function drop(pageIndex, from, to, merge) {
        const next = copy();
        const items = next.pages[pageIndex].items;
        if (from < 0 || from >= items.length) return;
        if (merge && to >= 0 && to < items.length && to !== from) {
            const moving = items[from];
            if (typeof moving !== "string") return;
            const target = items[to];
            if (typeof target === "string") items[to] = {folder: "Folder", apps: [target, moving]};
            else if (target.apps.length < 24 && target.apps.indexOf(moving) < 0) target.apps.push(moving);
            items.splice(from, 1);
        } else {
            const moving = items.splice(from, 1)[0];
            items.splice(Math.max(0, Math.min(items.length, to)), 0, moving);
        }
        save(next);
    }
    function moveToPage(pageIndex, from, targetPage) {
        const next = copy();
        const moving = next.pages[pageIndex].items.splice(from, 1)[0];
        if (moving === undefined) return;
        while (next.pages.length <= targetPage && next.pages.length < 8) next.pages.push({widgets: [], items: []});
        next.pages[Math.min(targetPage, next.pages.length - 1)].items.push(moving);
        save(next);
    }
    function removeItem(pageIndex, index) { const next = copy(); next.pages[pageIndex].items.splice(index, 1); save(next); }
    function removeWidget(pageIndex, index) { const next = copy(); next.pages[pageIndex].widgets.splice(index, 1); save(next); }
    // Tap the size chip to step through the sizes: wide short, wide tall, wide taller, half square.
    function resizeWidget(pageIndex, index) {
        const next = copy(), w = next.pages[pageIndex].widgets[index];
        const sizes = [[4, 1], [4, 2], [4, 3], [2, 2]];
        const at = sizes.findIndex(s => s[0] === w.w && s[1] === w.h);
        const size = sizes[(at + 1) % sizes.length];
        w.w = size[0]; w.h = size[1];
        save(next);
    }
    function addWidget(kind, w, h) {
        const next = copy();
        const page = next.pages[pageIndex()];
        if (!page.widgets.some(x => x.kind === kind) && page.widgets.length < 6) page.widgets.unshift({kind: kind, w: w, h: h});
        save(next);
    }
    function addPage() {
        const next = copy();
        if (next.pages.length < 8) next.pages.push({widgets: [], items: []});
        save(next);
        pager.wanted = next.pages.length;
        Qt.callLater(() => pager.positionViewAtIndex(next.pages.length, ListView.Beginning));
    }
    function folderSet(change) {
        const next = copy();
        const items = next.pages[openFolderPage].items;
        const folder = items[openFolderIndex];
        if (!folder || typeof folder === "string") return;
        change(folder, items);
        if (folder.apps.length === 1) items[openFolderIndex] = folder.apps[0];
        else if (folder.apps.length === 0) items.splice(openFolderIndex, 1);
        save(next);
        openFolder = typeof items[openFolderIndex] === "object" ? items[openFolderIndex] : null;
    }

    // Vertical gesture: up opens the drawer, down opens the shade. Off while editing.
    DragHandler {
        id: swipe
        enabled: !home.editing && home.openFolder === null && home.menuFor === null && !home.pickerOpen
        target: null; xAxis.enabled: false; yAxis.enabled: true
        grabPermissions: PointerHandler.CanTakeOverFromItems
        onTranslationChanged: if (active && translation.y < 0) home.dragProgress(Math.min(1, -translation.y / (home.height * .55)))
        onActiveChanged: {
            if (active) return;
            if (translation.y > 70) { home.dragProgress(0); Hub.page = "controls"; return; }
            const progress = -translation.y / (home.height * .55);
            home.dragFinished(progress > .28 || centroid.velocity.y < -600);
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: home.wide ? 40 : 12; anchors.rightMargin: home.wide ? 40 : 12; anchors.bottomMargin: 14; spacing: 10
        // Edit bar: add widgets, add a page, change the wallpaper, finish.
        RowLayout {
            visible: home.editing; Layout.fillWidth: true; spacing: 8
            MButton { text: "Widgets"; icon: "widgets"; tonal: true; compact: true; onClicked: home.pickerOpen = true }
            MButton { text: "Page"; icon: "add"; compact: true; enabled: home.layout.pages.length < 8; onClicked: home.addPage() }
            MButton { icon: "wallpaper"; compact: true; tooltip: "Wallpaper"; onClicked: Hub.page = "wallpaper" }
            Item { Layout.fillWidth: true }
            MButton { text: "Done"; filled: true; compact: true; onClicked: home.finishEditing() }
        }
        ListView {
            id: pager
            Layout.fillWidth: true; Layout.fillHeight: true
            orientation: ListView.Horizontal; snapMode: ListView.SnapOneItem; highlightRangeMode: ListView.StrictlyEnforceRange; highlightMoveDuration: Theme.motion(300)
            boundsBehavior: Flickable.StopAtBounds; clip: true
            interactive: !dragging && home.menuFor === null
            property bool dragging: false
            // Index 0 is the Live page; the home pages follow.
            model: [{minus: true}].concat(home.layout.pages)
            // The page the user is on. A new model or a size change returns to it; the first home page is the default.
            property int wanted: 1
            currentIndex: 1
            onMovementEnded: wanted = currentIndex
            onCountChanged: Qt.callLater(() => { currentIndex = Math.min(wanted, count - 1); positionViewAtIndex(currentIndex, ListView.Beginning); })
            onWidthChanged: positionViewAtIndex(currentIndex, ListView.Beginning)
            delegate: Loader {
                id: pageLoader
                required property var modelData
                required property int index
                width: pager.width; height: pager.height
                // Neighbour pages recede while the finger moves, so a page change feels continuous.
                readonly property real distance: Math.min(1, Math.abs(x - pager.contentX) / Math.max(1, pager.width))
                opacity: 1 - distance * .55; scale: 1 - distance * .05
                sourceComponent: modelData.minus ? minusPage : homePage
                property var pageData: modelData
                property int pageNumber: index - 1
            }
        }
        // Page dots: the Live page is a small bolt, the current page stretches into a pill.
        Row {
            Layout.alignment: Qt.AlignHCenter; spacing: 6
            Glyph { name: "bolt"; font.pixelSize: 12; color: pager.currentIndex === 0 ? Theme.primary : Theme.alpha(Theme.text, .4); anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: Math.max(0, pager.count - 1)
                Rectangle {
                    required property int index
                    width: index + 1 === pager.currentIndex ? 18 : 7; height: 7; radius: 4
                    color: index + 1 === pager.currentIndex ? Theme.text : Theme.alpha(Theme.text, .35)
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                }
            }
        }
        // Dock, then the search bar.
        RowLayout {
            visible: home.dockCount > 0; Layout.fillWidth: true; Layout.fillHeight: false; Layout.preferredHeight: 72; Layout.maximumHeight: 72; spacing: 0
            Repeater {
                model: Hub.favoriteApps.slice(0, home.dockCount)
                Item {
                    required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true
                    PhoneAppIcon { anchors.centerIn: parent; app: parent.modelData; label: false; size: 56; onActivated: Hub.launch(app) }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.maximumWidth: home.wide ? 560 : 10000; Layout.alignment: Qt.AlignHCenter; Layout.preferredHeight: 56; radius: 28
            color: Theme.alpha(Theme.level(3), .95)
            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: searchMouse.pressed ? .1 : 0 }
            MouseArea { id: searchMouse; anchors.fill: parent; onClicked: home.openDrawer(true) }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 8; spacing: 12
                Glyph { name: "search"; font.pixelSize: 22; color: Theme.text }
                MText { text: "Search apps, files, settings"; role: "body"; font.pixelSize: 16; color: Theme.subtext; Layout.fillWidth: true }
                PhoneTorch { implicitWidth: 40; implicitHeight: 40; compact: true }
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20; color: Theme.tertiaryContainer
                    Glyph { anchors.centerIn: parent; name: "auto_awesome"; font.pixelSize: 20; color: Theme.onTertiaryContainer }
                    MouseArea { anchors.fill: parent; onClicked: Hub.openAssistant("") }
                    Accessible.role: Accessible.Button; Accessible.name: "Ask Claude"
                }
            }
            Accessible.role: Accessible.Button; Accessible.name: "Search"
        }
    }

    // The -1 page: every live activity as its card, and Claude at the bottom.
    Component {
        id: minusPage
        Item {
            Flickable {
                anchors.fill: parent; anchors.bottomMargin: 72; contentHeight: liveColumn.implicitHeight + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: liveColumn
                    width: Math.min(parent.width, 560); x: (parent.width - width) / 2; spacing: 10
                    Column {
                        leftPadding: 10; topPadding: 6; bottomPadding: 6; spacing: 2
                        MText { text: "Live"; role: "displayS" }
                        MText {
                            role: "bodyS"; color: Theme.subtext
                            readonly property int waiting: Activities.list.filter(a => a.priority >= 88).length
                            text: Activities.list.length === 0 ? "Nothing running right now" : Activities.list.length + " running" + (waiting ? " · " + waiting + " need" + (waiting === 1 ? "s" : "") + " you" : "")
                        }
                    }
                    Repeater {
                        model: Activities.list
                        ActivityCard { required property var modelData; width: liveColumn.width; a: modelData; compactPlayer: true; onOpened: Activities.open(modelData, null) }
                    }
                    Column {
                        visible: Activities.list.length === 0; width: parent.width; topPadding: 40; spacing: 8
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: "bolt"; font.pixelSize: 40; color: Theme.alpha(Theme.text, .3) }
                        MText { anchors.horizontalCenter: parent.horizontalCenter; text: "Downloads, timers, music and agents show up here."; role: "bodyS"; color: Theme.subtext }
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 8, 560); height: 56; radius: 28; color: Theme.level(3)
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 16; spacing: 12
                    Glyph { name: "auto_awesome"; font.pixelSize: 22; color: Theme.tertiary }
                    MText { Layout.fillWidth: true; text: "Ask Claude…"; role: "body"; font.pixelSize: 16; color: Theme.subtext }
                    Glyph { name: "arrow_forward"; font.pixelSize: 22; color: Theme.subtext }
                }
                MouseArea { anchors.fill: parent; onClicked: Hub.openAssistant("") }
                Accessible.role: Accessible.Button; Accessible.name: "Ask Claude"
            }
        }
    }

    // One home page: widgets and icons in one grid.
    Component {
        id: homePage
        Item {
            id: page
            readonly property var pdata: parent ? parent.pageData : ({widgets: [], items: []})
            readonly property int number: parent ? parent.pageNumber : 0
            readonly property var packed: home.pack(pdata)
            readonly property real gridX: (width - home.columns * home.cellWidth) / 2
            // Long-press on empty space enters edit mode.
            MouseArea { anchors.fill: parent; onPressAndHold: { home.menuFor = null; home.editing = true; } onClicked: home.menuFor = null }
            Flickable {
                id: scroll
                anchors.fill: parent; clip: true; boundsBehavior: Flickable.StopAtBounds
                contentHeight: (page.packed.firstRow + Math.ceil(page.pdata.items.length / home.columns)) * home.cellHeight + 12
                interactive: !pager.dragging && contentHeight > height
                // Widgets: each spans its cells. In edit mode a chip resizes it and a badge removes it.
                Repeater {
                    model: page.packed.widgets
                    Item {
                        id: wslot
                        required property var modelData
                        x: page.gridX + modelData.x * home.cellWidth + 4; y: modelData.y * home.cellHeight + 4
                        width: modelData.cw * home.cellWidth - 8; height: modelData.ch * home.cellHeight - 8
                        Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                        readonly property bool legacy: ["stack", "calendar", "battery", "focus"].indexOf(modelData.kind) >= 0
                        Loader {
                            anchors.fill: parent
                            sourceComponent: wslot.legacy ? legacyWidget : newWidget
                            Component { id: newWidget; HomeWidget { kind: wslot.modelData.kind; editing: home.editing } }
                            Component {
                                id: legacyWidget
                                PhoneWidget { kind: wslot.modelData.kind; editing: false; onLongPressed: home.editing = true; onTapped: if (wslot.modelData.kind === "battery" && !home.editing) home.batteryOpen = true }
                            }
                        }
                        MouseArea { anchors.fill: parent; enabled: !home.editing; acceptedButtons: Qt.NoButton }
                        Rectangle { visible: home.editing; anchors.fill: parent; anchors.margins: -3; radius: 30; color: "transparent"; border.width: 2; border.color: Theme.alpha(Theme.primary, .55) }
                        Rectangle {
                            visible: home.editing; width: 28; height: 28; radius: 14; color: Theme.level(4)
                            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: -6
                            Glyph { anchors.centerIn: parent; name: "remove"; font.pixelSize: 18; color: Theme.text }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: home.removeWidget(page.number, wslot.modelData.index) }
                            Accessible.role: Accessible.Button; Accessible.name: "Remove widget"
                        }
                        Rectangle {
                            visible: home.editing; height: 30; width: sizeText.implicitWidth + 36; radius: 15; color: Theme.primary
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: -6
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Glyph { name: "open_in_full"; font.pixelSize: 15; color: Theme.onPrimary; anchors.verticalCenter: parent.verticalCenter }
                                MText { id: sizeText; text: wslot.modelData.cw + "×" + wslot.modelData.ch; role: "labelS"; font.weight: Font.Bold; color: Theme.onPrimary; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: home.resizeWidget(page.number, wslot.modelData.index) }
                            Accessible.role: Accessible.Button; Accessible.name: "Resize widget"
                        }
                    }
                }
                // Icons with absolute cells, so a dragged item can float over the others.
                Item {
                    id: grid
                    x: page.gridX; y: page.packed.firstRow * home.cellHeight
                    width: home.columns * home.cellWidth; height: Math.max(1, Math.ceil(page.pdata.items.length / home.columns)) * home.cellHeight
                    // The cell under a dragged icon, so the others make room for it.
                    property int hoverTarget: -1
                    property int dragFrom: -1
                    function shifted(i) {
                        if (dragFrom < 0 || hoverTarget < 0 || i === dragFrom) return i;
                        if (dragFrom < hoverTarget && i > dragFrom && i <= hoverTarget) return i - 1;
                        if (dragFrom > hoverTarget && i >= hoverTarget && i < dragFrom) return i + 1;
                        return i;
                    }
                    Repeater {
                        model: page.pdata.items
                        Item {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property bool folder: typeof modelData !== "string"
                            readonly property var app: folder ? null : home.appFor(modelData)
                            readonly property bool lifted: home.menuFor !== null && home.menuFor.page === page.number && home.menuFor.index === index
                            function restX() { return (grid.shifted(index) % home.columns) * home.cellWidth; }
                            function restY() { return Math.floor(grid.shifted(index) / home.columns) * home.cellHeight; }
                            x: restX(); y: restY()
                            width: home.cellWidth; height: home.cellHeight
                            visible: folder || app !== null
                            z: dragArea.drag.active || lifted ? 10 : 0
                            scale: dragArea.drag.active || lifted ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.motion(Theme.durShort); easing.type: Easing.OutCubic } }
                            Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                            readonly property real iconSize: PhoneState.iconSize(Math.min(home.cellWidth, 104))
                            Rectangle { visible: cell.lifted || dragArea.drag.active; anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: cell.iconSize + 14; height: width; radius: width / 2; color: Theme.alpha("#000000", .28) }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 6; spacing: 7
                                Item {
                                    width: cell.iconSize; height: width; anchors.horizontalCenter: parent.horizontalCenter
                                    AppIcon { anchors.fill: parent; visible: !cell.folder; app: cell.app }
                                    Rectangle {
                                        visible: cell.folder; anchors.fill: parent; radius: width * .3; color: Theme.alpha(Theme.level(3), .92)
                                        Grid {
                                            anchors.centerIn: parent; columns: 2; spacing: 4
                                            Repeater { model: cell.folder ? cell.modelData.apps.slice(0, 4) : []; AppIcon { required property string modelData; width: cell.iconSize * .34; height: width; app: home.appFor(modelData); style: "raw" } }
                                        }
                                    }
                                    Rectangle {
                                        visible: !cell.folder && Hub.windows.some(w => Hub.appForWindow(w) === cell.app)
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 2
                                        width: 5; height: 5; radius: 2.5; color: Theme.primary
                                    }
                                }
                                MText {
                                    visible: !dragArea.drag.active && !cell.lifted
                                    anchors.horizontalCenter: parent.horizontalCenter; width: home.cellWidth - 6; horizontalAlignment: Text.AlignHCenter
                                    text: cell.folder ? cell.modelData.folder : cell.app ? cell.app.name : ""; role: "label"
                                    style: Text.Raised; styleColor: Theme.alpha(Theme.light ? "#ffffff" : "#000000", .35)
                                }
                            }
                            // Edit mode: a badge removes the icon from home.
                            Rectangle {
                                visible: home.editing && !dragArea.drag.active
                                x: parent.width / 2 + cell.iconSize / 2 - 14; y: 0; width: 24; height: 24; radius: 12; color: Theme.level(4)
                                Glyph { anchors.centerIn: parent; name: "remove"; font.pixelSize: 16; color: Theme.text }
                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: home.removeItem(page.number, cell.index) }
                            }
                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                // A long press lifts the icon and opens its menu; moving the finger then drags it.
                                drag.target: home.editing || cell.lifted ? cell : null
                                drag.threshold: 8
                                preventStealing: drag.target !== null
                                property bool moved: false
                                onPressed: moved = false
                                onPositionChanged: {
                                    if (!drag.active) return;
                                    if (!moved) { moved = true; home.menuFor = null; home.editing = true; pager.dragging = true; grid.dragFrom = cell.index; }
                                    const cx = cell.x + cell.width / 2, cy = cell.y + cell.height / 2;
                                    grid.hoverTarget = Math.max(0, Math.min(page.pdata.items.length - 1, Math.floor(cy / home.cellHeight) * home.columns + Math.max(0, Math.min(home.columns - 1, Math.floor(cx / home.cellWidth)))));
                                    edgeTimer.cell = cell;
                                    edgeTimer.running = cell.x + cell.width > grid.width + 10 || cell.x < -10;
                                }
                                onReleased: {
                                    pager.dragging = false; edgeTimer.running = false;
                                    const from = grid.dragFrom;
                                    grid.dragFrom = -1; grid.hoverTarget = -1;
                                    if (!moved) { cell.x = Qt.binding(cell.restX); cell.y = Qt.binding(cell.restY); return; }
                                    const cx = cell.x + cell.width / 2, cy = cell.y + cell.height / 2;
                                    const col = Math.max(0, Math.min(home.columns - 1, Math.floor(cx / home.cellWidth)));
                                    const row = Math.max(0, Math.floor(cy / home.cellHeight));
                                    const target = row * home.columns + col;
                                    // The centre of a cell means "drop onto": a folder forms. The rest means "move here".
                                    const fx = cx / home.cellWidth - col, fy = cy / home.cellHeight - row;
                                    const merge = fx > .3 && fx < .7 && fy > .2 && fy < .6 && target < page.pdata.items.length && target !== from;
                                    cell.x = Qt.binding(cell.restX); cell.y = Qt.binding(cell.restY);
                                    home.drop(page.number, from, target, merge);
                                }
                                onClicked: {
                                    if (moved || home.editing) return;
                                    if (home.menuFor !== null) { home.menuFor = null; return; }
                                    if (cell.folder) { home.openFolder = cell.modelData; home.openFolderPage = page.number; home.openFolderIndex = cell.index; }
                                    else if (cell.app) Hub.launch(cell.app);
                                }
                                onPressAndHold: {
                                    if (home.editing) return;
                                    const p = cell.mapToItem(home, 0, 0);
                                    home.menuFor = {page: page.number, index: cell.index, app: cell.app, folder: cell.folder, x: p.x, y: p.y, w: cell.width, h: cell.height};
                                }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: cell.folder ? "Folder " + cell.modelData.folder : cell.app ? cell.app.name : ""
                        }
                    }
                }
            }
            // Holding a dragged icon at the page edge moves it to the next or the previous page.
            Timer {
                id: edgeTimer
                property var cell: null
                interval: 650
                onTriggered: if (cell) {
                    const forward = cell.x > 0;
                    const target = page.number + (forward ? 1 : -1);
                    if (target < 0) return;
                    pager.dragging = false;
                    home.moveToPage(page.number, cell.index, target);
                    pager.wanted = target + 1;
                    Qt.callLater(() => pager.positionViewAtIndex(target + 1, ListView.Beginning));
                }
            }
        }
    }

    // Long-press menu: the app's shortcuts, then Widgets, Edit and Remove.
    Rectangle {
        anchors.fill: parent; visible: home.menuFor !== null; color: Theme.alpha("#000000", .38)
        MouseArea { anchors.fill: parent; onClicked: home.menuFor = null }
    }
    Rectangle {
        id: menuCard
        visible: home.menuFor !== null
        readonly property var app: home.menuFor ? home.menuFor.app : null
        readonly property var shortcuts: app && app.actions ? app.actions.slice(0, 4) : []
        width: Math.min(home.width - 24, 280)
        height: menuColumn.implicitHeight + 20
        x: home.menuFor ? Math.max(12, Math.min(home.width - width - 12, home.menuFor.x + home.menuFor.w / 2 - width / 2)) : 0
        y: home.menuFor ? (home.menuFor.y - height - 8 > 60 ? home.menuFor.y - height - 8 : home.menuFor.y + home.menuFor.h + 8) : 0
        radius: 28; color: Theme.level(3)
        scale: visible ? 1 : .9
        Behavior on scale { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
        ColumnLayout {
            id: menuColumn
            x: 10; y: 10; width: parent.width - 20; spacing: 2
            Repeater {
                model: menuCard.shortcuts
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 18; color: shortcutMouse.pressed ? Theme.alpha(Theme.text, .08) : "transparent"
                    Row {
                        x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                        Glyph { name: "bolt"; font.pixelSize: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: modelData.name; role: "body"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: shortcutMouse; anchors.fill: parent; onClicked: { modelData.execute(); home.menuFor = null; } }
                }
            }
            Rectangle { visible: menuCard.shortcuts.length > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 4; Layout.bottomMargin: 6; color: Theme.outline }
            Row {
                Layout.alignment: Qt.AlignHCenter; spacing: 6
                MButton { text: "Widgets"; icon: "widgets"; tonal: true; compact: true; onClicked: { home.menuFor = null; home.editing = true; home.pickerOpen = true; } }
                MButton { icon: "edit"; tonal: true; compact: true; tooltip: "Edit home"; onClicked: { home.menuFor = null; home.editing = true; } }
                MButton { icon: "delete"; tonal: true; compact: true; tooltip: "Remove from home"; onClicked: { const m = home.menuFor; home.menuFor = null; home.removeItem(m.page, m.index); } }
            }
        }
    }

    // Battery page.
    Rectangle {
        anchors.fill: parent; visible: home.batteryOpen; color: Theme.alpha(Theme.base, .97)
        MouseArea { anchors.fill: parent }
        Loader { anchors.fill: parent; active: home.batteryOpen; sourceComponent: BatteryStats { onCloseRequested: home.batteryOpen = false } }
    }

    // Widget picker: a bottom sheet with live previews at their sizes.
    Rectangle { anchors.fill: parent; visible: home.pickerOpen; color: Theme.alpha("#000000", .4); MouseArea { anchors.fill: parent; onClicked: home.pickerOpen = false } }
    Rectangle {
        id: picker
        visible: y < home.height
        anchors.left: parent.left; anchors.right: parent.right
        height: Math.min(home.height * .8, pickerColumn.implicitHeight + 48)
        y: home.pickerOpen ? home.height - height : home.height
        Behavior on y { NumberAnimation { duration: Theme.motion(Theme.durLong); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        topLeftRadius: 32; topRightRadius: 32; color: Theme.level(1)
        MouseArea { anchors.fill: parent }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 36; height: 4; radius: 2; color: Theme.alpha(Theme.text, .35) }
        Flickable {
            anchors.fill: parent; anchors.topMargin: 24; contentHeight: pickerColumn.implicitHeight + 24; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: pickerColumn
                x: 18; width: parent.width - 36; spacing: 14
                MText { text: "Widgets"; role: "headline" }
                Repeater {
                    model: [{kind: "glance", name: "Glance", w: 4, h: 1}, {kind: "media", name: "Media", w: 4, h: 2}, {kind: "live", name: "Live activity", w: 4, h: 2},
                            {kind: "photos", name: "Photos", w: 2, h: 2}, {kind: "devices", name: "Devices", w: 2, h: 2}, {kind: "clock", name: "Clock", w: 2, h: 2}]
                    Column {
                        id: option
                        required property var modelData
                        readonly property bool added: ((home.layout.pages[home.pageIndex()] || {widgets: []}).widgets || []).some(x => x.kind === modelData.kind)
                        spacing: 6
                        Item {
                            width: modelData.w === 4 ? pickerColumn.width : pickerColumn.width / 2 - 6
                            height: Math.min(200, modelData.h * home.cellHeight * .8)
                            HomeWidget { anchors.fill: parent; kind: option.modelData.kind; editing: true; enabled: false }
                            Rectangle { anchors.fill: parent; radius: 28; color: "transparent"; border.width: option.added ? 2 : 0; border.color: Theme.primary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!option.added) { home.addWidget(option.modelData.kind, option.modelData.w, option.modelData.h); home.pickerOpen = false; } }
                        }
                        MText { text: option.modelData.name + " · " + option.modelData.w + "×" + option.modelData.h + (option.added ? " · on this page" : ""); role: "labelS"; color: Theme.subtext }
                    }
                }
            }
        }
    }

    // Folder overlay.
    Rectangle {
        anchors.fill: parent; color: Theme.alpha("#000000", .4)
        visible: home.openFolder !== null
        MouseArea { anchors.fill: parent; onClicked: home.openFolder = null }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 360); height: folderColumn.implicitHeight + 40
            radius: Theme.shapeXl; color: Theme.level(2)
            MouseArea { anchors.fill: parent }
            Column {
                id: folderColumn; x: 20; y: 20; width: parent.width - 40; spacing: 16
                TextInput {
                    width: parent.width; horizontalAlignment: TextInput.AlignHCenter
                    text: home.openFolder ? home.openFolder.folder : ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Bold
                    maximumLength: 40; selectByMouse: true
                    onEditingFinished: if (home.openFolder && text.trim() !== "" && text !== home.openFolder.folder) { const name = text.trim(); home.folderSet(f => f.folder = name); }
                }
                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter; columns: 3; spacing: 8
                    Repeater {
                        model: home.openFolder ? home.openFolder.apps : []
                        Item {
                            required property string modelData
                            width: (folderColumn.width - 16) / 3; height: 96
                            PhoneAppIcon { anchors.horizontalCenter: parent.horizontalCenter; app: home.appFor(modelData) || ({name: modelData, icon: ""}); size: 52; enabled: !home.editing; onActivated: { const a = home.appFor(modelData); home.openFolder = null; if (a) Hub.launch(a); } }
                            Rectangle {
                                visible: home.editing; x: parent.width / 2 + 14; y: 0; width: 22; height: 22; radius: 11; color: Theme.level(4)
                                Glyph { anchors.centerIn: parent; name: "remove"; font.pixelSize: 16; color: Theme.text }
                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { const id = modelData; home.folderSet((f, items) => { f.apps = f.apps.filter(a => a !== id); items.push(id); }); } }
                            }
                        }
                    }
                }
            }
        }
    }
}
