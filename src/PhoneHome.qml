import QtQuick
import QtQuick.Effects
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
    // The page the home opens on: 0 is the Live page, 1 the first home page. An open foldable shows two pages, one on each side of the hinge.
    property int startPage: 1
    // False when a taskbar outside the home carries the favourite apps and the search, as on an open foldable.
    property bool ownDock: true
    // A tablet grid keeps icon cells near 168 px wide, so a large screen gets more columns and not wider cells.
    readonly property int columns: wide ? Math.max(PhoneState.columnsFor(pager.width, true) + 1, Math.floor((pager.width - 8) / 168)) : PhoneState.columnsFor(pager.width, false)
    readonly property real cellWidth: (pager.width - 8) / columns
    readonly property real cellHeight: PhoneState.cellHeight(Math.min(cellWidth, 104))
    readonly property int dockCount: wide || !ownDock ? 0 : Math.min(4, Hub.favoriteApps.length)
    // The layout changes only when the saved home changes. Other preference changes must not rebuild the pages or reset the page.
    readonly property string layoutKey: JSON.stringify(Hub.phoneHome)
    property var layout: ({pages: [{widgets: [], items: []}]})
    onLayoutKeyChanged: layout = {pages: JSON.parse(layoutKey).pages.map(p => ({widgets: p.widgets.map(norm), items: p.items}))}
    Component.onCompleted: { layout = {pages: JSON.parse(layoutKey).pages.map(p => ({widgets: p.widgets.map(norm), items: p.items}))}; fileSync.restart(); }
    readonly property var live: Activities.list.find(a => a.kind !== "media") || null
    // With the option on, the tablet home is the ~/Desktop folder too: every file there is an icon in the grid, next to the apps. With it off, the files leave the home.
    readonly property bool desktopFiles: Hub.prefs.homeDesktopFiles === true
    onDesktopFilesChanged: fileSync.restart()
    // A new file goes after the last icon; a file that leaves the folder leaves the home. Nothing happens before the first folder listing.
    function fileFor(item) { return item && typeof item === "object" && item.path ? (HomeData.desktopItems || []).find(f => f.path === item.path) || null : null; }
    function syncFiles() {
        if (!wide || desktopFiles && HomeData.desktopFolder === "" || pager.height <= 0) return;
        const paths = desktopFiles ? (HomeData.desktopItems || []).map(f => f.path) : [];
        const next = copy();
        let changed = false;
        const placed = {};
        next.pages.forEach(p => {
            const before = p.widgets.length;
            p.widgets = p.widgets.filter(w => w.kind !== "files");
            if (p.widgets.length !== before) changed = true;
            p.items.forEach((it, i) => {
                if (!it || typeof it !== "object" || !it.path) return;
                if (paths.indexOf(it.path) < 0 || placed[it.path]) { p.items[i] = null; changed = true; } else placed[it.path] = true;
            });
        });
        paths.filter(path => !placed[path]).forEach(path => {
            let n = 0;
            for (;; n++) {
                if (n >= next.pages.length) { if (next.pages.length >= 8) return; next.pages.push({widgets: [], items: []}); }
                const page = next.pages[n];
                const rows = Math.max(1, Math.floor((pager.height - pack({widgets: page.widgets.map(norm), items: page.items}).firstY) / cellHeight));
                // After the last icon, so the gaps the user left between icons stay empty.
                const free = page.items.length;
                if (free < rows * columns) { while (page.items.length <= free) page.items.push(null); page.items[free] = {path: path}; changed = true; return; }
            }
        });
        if (!changed) return;
        next.pages.forEach(p => trim(p.items));
        save(next);
    }
    // A timer owned by the home, so a sync never runs after the home is gone.
    Timer { id: fileSync; interval: 120; onTriggered: home.syncFiles() }
    Connections { target: HomeData; function onDesktopItemsChanged() { fileSync.restart(); } }
    onWideChanged: fileSync.restart()
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
    // Pack widgets row by row, then icons in the cells after the last widget row. Each result has its pixel box: px, py, pw, ph.
    function pack(page) {
        return wide ? packWide(page) : packCells(page);
    }
    function packCells(page) {
        const placed = [];
        let x = 0, y = 0, rowH = 0;
        page.widgets.forEach((w, i) => {
            const collapsed = w.kind === "live" && home.live === null && !home.editing;
            // On a phone a 4-wide widget fills the row whatever the column count.
            const ww = w.w >= 4 ? columns : Math.min(columns, Math.max(1, w.w)), hh = collapsed ? 0 : w.h;
            if (hh === 0) return;
            if (x + ww > columns) { x = 0; y += rowH; rowH = 0; }
            placed.push(Object.assign({}, w, {index: i, px: x * cellWidth + 4, py: y * cellHeight + 4, pw: ww * cellWidth - 8, ph: hh * cellHeight - 8}));
            x += ww; rowH = Math.max(rowH, hh);
            if (x >= columns) { x = 0; y += rowH; rowH = 0; }
        });
        return {widgets: placed, firstY: (y + rowH) * cellHeight};
    }
    // Width of a tablet widget for its height. Wide sizes (w 4) get the long shape, the others are square or near square.
    function wideAspect(w) {
        const long = w.w >= 4;
        return ({media: long ? 2.6 : 1.6, live: long ? 1.3 : 1.1, photos: long ? 1.6 : 1, devices: long ? 1.6 : 1, clock: long ? 1.6 : 1})[w.kind] || 1.3;
    }
    // Tablet: widgets keep their own shape and flow left to right in rows, like the Pixel Tablet home. The glance takes a full row.
    function packWide(page) {
        const placed = [], gap = 16, full = columns * cellWidth - 8;
        let x = 0, y = 0, rowH = 0;
        page.widgets.forEach((w, i) => {
            const collapsed = w.kind === "live" && home.live === null && !home.editing;
            if (collapsed) return;
            const ph = w.h * cellHeight - 8;
            let pw = w.kind === "glance" ? full : Math.min(full, Math.round(ph * wideAspect(w)));
            // A widget that almost fits shrinks a little to stay in the row; otherwise it starts a new row.
            if (x > 0 && x + pw > full) {
                if (full - x >= pw * .85) pw = full - x;
                else { x = 0; y += rowH + gap; rowH = 0; }
            }
            placed.push(Object.assign({}, w, {index: i, px: x + 4, py: y + 4, pw: pw, ph: ph}));
            x += pw + gap; rowH = Math.max(rowH, ph);
            if (w.kind === "glance") { x = 0; y += rowH + 8; rowH = 0; }
        });
        return {widgets: placed, firstY: y + rowH + (rowH > 0 ? 24 : 0)};
    }
    // Free placement: a page is a list of cells in reading order, and null is an empty cell. Trailing empty cells are not saved.
    function isEmpty(v) { return v === null || v === undefined; }
    function trim(items) { while (items.length && isEmpty(items[items.length - 1])) items.pop(); }
    function firstFree(items) { const i = items.findIndex(isEmpty); return i < 0 ? items.length : i; }
    // A drop on an empty cell puts the icon exactly there. A drop on an icon makes room, and a drop on its centre makes a folder.
    function drop(pageIndex, from, to, merge) {
        const next = copy();
        const items = next.pages[pageIndex].items;
        if (from < 0 || from >= items.length || isEmpty(items[from]) || to < 0 || to === from) return;
        while (items.length <= to) items.push(null);
        // Only an app dropped on an app or a folder makes or fills a folder; files and folders just move.
        const canMerge = typeof items[from] === "string" && (typeof items[to] === "string" || !!(items[to] && items[to].apps));
        if (merge && canMerge) {
            const moving = items[from];
            const target = items[to];
            if (typeof target === "string") items[to] = {folder: "Folder", apps: [target, moving]};
            else if (target.apps.length < 24 && target.apps.indexOf(moving) < 0) target.apps.push(moving);
            items[from] = null;
        } else if (isEmpty(items[to])) {
            items[to] = items[from];
            items[from] = null;
        } else {
            const moving = items.splice(from, 1)[0];
            items.splice(to, 0, moving);
        }
        trim(items);
        save(next);
    }
    function moveToPage(pageIndex, from, targetPage) {
        const next = copy();
        const source = next.pages[pageIndex].items;
        const moving = source[from];
        if (isEmpty(moving)) return;
        source[from] = null; trim(source);
        while (next.pages.length <= targetPage && next.pages.length < 8) next.pages.push({widgets: [], items: []});
        const items = next.pages[Math.min(targetPage, next.pages.length - 1)].items;
        items[firstFree(items)] = moving;
        save(next);
    }
    // Right click on empty home space: the home menu, opened at the pointer in the shell's context menu window.
    function homeMenu(item, x, y) {
        const p = item.mapToItem(null, x, y);
        Hub.openTaskbarContext(null, p.x, p.y + 10, [
            {text: "Edit home", icon: "edit", run: () => home.editing = true},
            {text: "Widgets", icon: "widgets", run: () => { home.editing = true; home.pickerOpen = true; }},
            {text: "Add a page", icon: "add", run: () => home.addPage()},
            {text: "Desktop files", icon: "desktop_windows", checked: home.desktopFiles, run: () => Hub.set("homeDesktopFiles", !home.desktopFiles)},
            {text: "Hide under apps", icon: "layers_clear", checked: Hub.prefs.homeHideUnderApps !== false, run: () => Hub.set("homeHideUnderApps", Hub.prefs.homeHideUnderApps === false)},
            {text: "Wallpaper", icon: "wallpaper", run: () => Hub.page = "wallpaper"},
            {text: "Home settings", icon: "settings", run: () => Hub.openSettings("phone")}
        ], false, "Home", "home");
    }
    // An app carried from the launcher lands at a place on a page. An app that is already on the home moves there.
    function insertApp(pageIndex, id, at) {
        const next = copy();
        const target = Math.max(0, Math.min(pageIndex, next.pages.length - 1));
        next.pages.forEach(p => { const i = p.items.indexOf(id); if (i >= 0) p.items[i] = null; });
        const items = next.pages[target].items;
        const toEnd = at < 0;
        if (toEnd) at = firstFree(items);
        while (items.length <= at) items.push(null);
        if (isEmpty(items[at])) items[at] = id; else items.splice(at, 0, id);
        next.pages.forEach(p => trim(p.items));
        save(next);
        const app = appFor(id);
        if (toEnd && app) Hub.message(app.name + " is on your home now");
    }
    function removeItem(pageIndex, index) { const next = copy(); const items = next.pages[pageIndex].items; items[index] = null; trim(items); save(next); }
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
        else if (folder.apps.length === 0) items[openFolderIndex] = null;
        trim(items);
        save(next);
        openFolder = typeof items[openFolderIndex] === "object" ? items[openFolderIndex] : null;
    }

    // Vertical gesture: up opens the drawer, down opens the shade. Off while editing.
    DragHandler {
        id: swipe
        enabled: !home.editing && home.openFolder === null && home.menuFor === null && !home.pickerOpen
        target: null; xAxis.enabled: false; yAxis.enabled: true
        // A clear vertical drag only: a page swipe that drifts a little up or down stays a page swipe.
        dragThreshold: 28
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
        anchors.fill: parent; anchors.leftMargin: home.wide ? 40 : 4; anchors.rightMargin: home.wide ? 40 : 4; anchors.bottomMargin: home.wide ? 14 : 4; spacing: home.wide ? 10 : 4
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
            // A page change is quick and settles without drift: short snap, firm deceleration, and no fade on the neighbours.
            orientation: ListView.Horizontal; snapMode: ListView.SnapOneItem; highlightRangeMode: ListView.StrictlyEnforceRange; highlightMoveDuration: Theme.motion(170); highlightMoveVelocity: -1
            flickDeceleration: 9000; maximumFlickVelocity: 9000
            boundsBehavior: Flickable.StopAtBounds; clip: true
            interactive: !dragging && home.menuFor === null
            property bool dragging: false
            // Index 0 is the Live page; the home pages follow.
            model: [{minus: true}].concat(home.layout.pages)
            // The page the user is on. A new model or a size change returns to it; the first home page is the default.
            property int wanted: home.startPage
            currentIndex: home.startPage
            onMovementEnded: wanted = currentIndex
            onCountChanged: Qt.callLater(() => { currentIndex = Math.min(wanted, count - 1); positionViewAtIndex(currentIndex, ListView.Beginning); })
            onWidthChanged: positionViewAtIndex(currentIndex, ListView.Beginning)
            // A mouse wheel or a touchpad scroll turns one page per notch.
            WheelHandler {
                enabled: !home.editing && home.menuFor === null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real sum: 0
                onWheel: e => {
                    sum += Math.abs(e.angleDelta.y) > Math.abs(e.angleDelta.x) ? e.angleDelta.y : e.angleDelta.x;
                    if (Math.abs(sum) < 120 || pageTurn.running) return;
                    const to = Math.max(0, Math.min(pager.count - 1, pager.currentIndex + (sum < 0 ? 1 : -1)));
                    sum = 0; pageTurn.start();
                    pager.wanted = to; pager.currentIndex = to;
                }
            }
            Timer { id: pageTurn; interval: 260 }
            delegate: Loader {
                id: pageLoader
                required property var modelData
                required property int index
                width: pager.width; height: pager.height
                // Neighbour pages recede while the finger moves, so a page change feels continuous.
                readonly property real distance: Math.min(1, Math.abs(x - pager.contentX) / Math.max(1, pager.width))
                opacity: 1 - distance * .25
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
        // On a tablet, or when an outside taskbar carries the apps, that bar carries the search, so the home does not draw a second one.
        Rectangle {
            visible: home.ownDock && (!home.wide || Hub.prefs.tabletDock === false)
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
                    visible: Hub.aiEnabled
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
                visible: Hub.aiEnabled
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
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressAndHold: e => { if (e.button !== Qt.LeftButton) return; home.menuFor = null; home.editing = true; }
                onClicked: e => { home.menuFor = null; if (e.button === Qt.RightButton && !home.editing) home.homeMenu(this, e.x, e.y); }
            }
            // An app carried from the launcher opens a gap under the finger on the page in view, and lands there.
            readonly property bool inView: number === home.pageIndex() && pager.currentIndex > 0
            // Every cell that fits on the page can take an icon, not only the cells after the last icon.
            readonly property int capacity: Math.max(pdata.items.length + 1, Math.floor(Math.max(0, height - packed.firstY) / home.cellHeight) * home.columns)
            function cellAt(gx, gy) {
                const col = Math.max(0, Math.min(home.columns - 1, Math.floor(gx / home.cellWidth)));
                return Math.max(0, Math.min(page.capacity - 1, Math.floor(Math.max(0, gy) / home.cellHeight) * home.columns + col));
            }
            function carryIndex(x, y) {
                const p = grid.mapFromItem(null, x, y);
                return page.cellAt(p.x, p.y);
            }
            Connections {
                target: PhoneState
                function onHomeDragChanged() {
                    const d = PhoneState.homeDrag;
                    if (d && page.inView) { grid.dragFrom = page.pdata.items.length; grid.hoverTarget = page.carryIndex(d.x, d.y); }
                    else if (grid.dragFrom === page.pdata.items.length) { grid.dragFrom = -1; grid.hoverTarget = -1; }
                }
                function onHomeDrop(appId, x, y) {
                    if (page.number !== home.pageIndex()) return;
                    grid.dragFrom = -1; grid.hoverTarget = -1;
                    home.insertApp(page.number, appId, x < 0 ? -1 : page.carryIndex(x, y));
                }
            }
            Flickable {
                id: scroll
                anchors.fill: parent; clip: true; boundsBehavior: Flickable.StopAtBounds
                contentHeight: page.packed.firstY + Math.ceil(page.pdata.items.length / home.columns) * home.cellHeight + 12
                interactive: !pager.dragging && contentHeight > height
                // Widgets: each spans its cells. In edit mode a chip resizes it and a badge removes it.
                Repeater {
                    model: page.packed.widgets
                    Item {
                        id: wslot
                        required property var modelData
                        x: page.gridX + modelData.px; y: modelData.py
                        width: modelData.pw; height: modelData.ph
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
                                MText { id: sizeText; text: wslot.modelData.w + "×" + wslot.modelData.h; role: "labelS"; font.weight: Font.Bold; color: Theme.onPrimary; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: home.resizeWidget(page.number, wslot.modelData.index) }
                            Accessible.role: Accessible.Button; Accessible.name: "Resize widget"
                        }
                    }
                }
                // Icons with absolute cells, so a dragged item can float over the others.
                Item {
                    id: grid
                    x: page.gridX; y: page.packed.firstY
                    width: home.columns * home.cellWidth; height: Math.max(1, Math.ceil(page.pdata.items.length / home.columns)) * home.cellHeight
                    // The cell under a dragged icon, so the others make room for it.
                    property int hoverTarget: -1
                    property int dragFrom: -1
                    function shifted(i) {
                        if (dragFrom < 0 || hoverTarget < 0 || i === dragFrom) return i;
                        // Over an empty cell nothing makes room: the icon goes exactly there.
                        if (hoverTarget >= page.pdata.items.length || home.isEmpty(page.pdata.items[hoverTarget])) return i;
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
                            readonly property bool empty: home.isEmpty(modelData)
                            readonly property var file: home.fileFor(modelData)
                            readonly property bool isFile: !empty && typeof modelData === "object" && !!modelData.path
                            readonly property bool isPair: !empty && typeof modelData === "object" && Array.isArray(modelData.pair) && modelData.pair.length === 2
                            readonly property bool folder: !empty && !isFile && !isPair && typeof modelData !== "string"
                            readonly property var app: folder || isFile || isPair ? null : home.appFor(modelData)
                            readonly property var pairLeft: isPair ? home.appFor(modelData.pair[0]) : null
                            readonly property var pairRight: isPair ? home.appFor(modelData.pair[1]) : null
                            // The long-press and right-click menu for this cell.
                            function openMenu() {
                                const p = cell.mapToItem(home, 0, 0);
                                home.menuFor = {page: page.number, index: cell.index, app: cell.app, folder: cell.folder, file: cell.file, x: p.x, y: p.y, w: cell.width, h: cell.height};
                            }
                            readonly property bool lifted: home.menuFor !== null && home.menuFor.page === page.number && home.menuFor.index === index
                            function restX() { return (grid.shifted(index) % home.columns) * home.cellWidth; }
                            function restY() { return Math.floor(grid.shifted(index) / home.columns) * home.cellHeight; }
                            x: restX(); y: restY()
                            width: home.cellWidth; height: home.cellHeight
                            visible: folder || isPair || app !== null || file !== null
                            z: dragArea.drag.active || lifted ? 10 : 0
                            scale: dragArea.drag.active || lifted ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.motion(Theme.durShort); easing.type: Easing.OutCubic } }
                            Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                            readonly property real iconSize: PhoneState.iconSize(Math.min(home.cellWidth, 104))
                            // Pointer hover: a soft plate behind the icon and its label.
                            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 22; color: Theme.alpha("#ffffff", .12); visible: dragArea.containsMouse && !dragArea.drag.active && !cell.lifted && !home.editing }
                            Rectangle { visible: cell.lifted || dragArea.drag.active; anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: cell.iconSize + 14; height: width; radius: width / 2; color: Theme.alpha("#000000", .28) }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 6; spacing: 7
                                Item {
                                    width: cell.iconSize; height: width; anchors.horizontalCenter: parent.horizontalCenter
                                    AppIcon { anchors.fill: parent; visible: !cell.folder && !cell.isFile; app: cell.app }
                                    // A Desktop file: its thumbnail, else its themed icon, else a symbol.
                                    Item {
                                        anchors.fill: parent; visible: cell.isFile
                                        RoundedImage { anchors.fill: parent; anchors.margins: 4; visible: !!(cell.file && cell.file.thumb); source: cell.file && cell.file.thumb ? cell.file.thumb : ""; radius: 12; decodeSize: Qt.size(128, 128) }
                                        Image {
                                            id: fileIcon
                                            anchors.fill: parent; visible: !!cell.file && !cell.file.thumb && status === Image.Ready; asynchronous: true; sourceSize: Qt.size(128, 128)
                                            source: !cell.file || cell.file.thumb ? "" : Quickshell.iconPath(cell.file.icon || "text-x-generic", true) || Quickshell.iconPath(cell.file.dir ? "folder" : "text-x-generic", true)
                                        }
                                        Glyph { anchors.centerIn: parent; visible: !!cell.file && !cell.file.thumb && fileIcon.status !== Image.Ready; name: cell.file && cell.file.dir ? "folder" : cell.file ? cell.file.glyph || "draft" : "draft"; font.pixelSize: cell.iconSize * .7; color: "#ffffff" }
                                    }
                                    Rectangle {
                                        visible: cell.folder; anchors.fill: parent; radius: width * .3; color: Theme.alpha(Theme.level(3), .92)
                                        Grid {
                                            anchors.centerIn: parent; columns: 2; spacing: 4
                                            Repeater { model: cell.folder ? cell.modelData.apps.slice(0, 4) : []; AppIcon { required property string modelData; width: cell.iconSize * .34; height: width; app: home.appFor(modelData); style: "raw" } }
                                        }
                                    }
                                    Rectangle {
                                        visible: cell.isPair; anchors.fill: parent; radius: width * .3; color: Theme.alpha(Theme.level(3), .92)
                                        border.width: 1; border.color: Theme.alpha(Theme.primary, .45)
                                        AppIcon { x: 6; y: 6; width: cell.iconSize * .44; height: width; app: cell.pairLeft; style: "raw" }
                                        Rectangle { anchors.centerIn: parent; width: parent.width * .68; height: 2; rotation: -45; color: Theme.alpha(Theme.primary, .55) }
                                        AppIcon { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 6; width: cell.iconSize * .44; height: width; app: cell.pairRight; style: "raw" }
                                    }
                                    Rectangle {
                                        visible: !!cell.app && Hub.windows.some(w => Hub.appForWindow(w) === cell.app)
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 2
                                        width: 5; height: 5; radius: 2.5; color: Theme.primary
                                    }
                                }
                                MText {
                                    visible: !dragArea.drag.active && !cell.lifted
                                    anchors.horizontalCenter: parent.horizontalCenter; width: home.cellWidth - 6; horizontalAlignment: Text.AlignHCenter
                                    text: cell.folder ? cell.modelData.folder : cell.isPair ? ((cell.pairLeft ? cell.pairLeft.name : "App") + " + " + (cell.pairRight ? cell.pairRight.name : "App")) : cell.app ? cell.app.name : cell.file ? cell.file.name : ""; role: "label"
                                    maximumLineCount: 2; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; elide: Text.ElideRight
                                    // Labels on the wallpaper are white with a small dense shadow, the same as the desktop labels.
                                    font.weight: Font.DemiBold; color: "#ffffff"
                                    style: GraphicsInfo.api === GraphicsInfo.Software ? Text.Outline : Text.Normal; styleColor: Theme.alpha("#000000", .45)
                                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 1; blurMax: 8; shadowBlur: .5; shadowScale: 1.04; shadowHorizontalOffset: 1; shadowVerticalOffset: 1 }
                                }
                            }
                            // Edit mode: a badge removes the icon from home.
                            Rectangle {
                                visible: home.editing && !dragArea.drag.active && !cell.isFile
                                x: parent.width / 2 + cell.iconSize / 2 - 14; y: 0; width: 24; height: 24; radius: 12; color: Theme.level(4)
                                Glyph { anchors.centerIn: parent; name: "remove"; font.pixelSize: 16; color: Theme.text }
                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: home.removeItem(page.number, cell.index) }
                            }
                            MouseArea {
                                id: dragArea
                                anchors.fill: parent; enabled: !cell.empty
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                // A long press lifts the icon and opens its menu; moving the finger then drags it.
                                drag.target: home.editing || cell.lifted || mouseDrag ? cell : null
                                // A mouse picks an icon up at once. A finger still needs the long press, so a swipe changes the page.
                                property bool mouseDrag: false
                                drag.threshold: 8
                                preventStealing: drag.target !== null
                                property bool moved: false
                                onPressed: e => { moved = false; mouseDrag = e.source === Qt.MouseEventNotSynthesized && e.button === Qt.LeftButton; }
                                onPressAndHold: e => {
                                    if (e.button !== Qt.LeftButton || home.editing) return;
                                    cell.openMenu();
                                }
                                onPositionChanged: {
                                    if (!drag.active) return;
                                    if (!moved) { moved = true; home.menuFor = null; if (!mouseDrag) home.editing = true; pager.dragging = true; grid.dragFrom = cell.index; }
                                    const cx = cell.x + cell.width / 2, cy = cell.y + cell.height / 2;
                                    grid.hoverTarget = page.cellAt(cx, cy);
                                    edgeTimer.cell = cell;
                                    edgeTimer.running = cell.x + cell.width > grid.width + 10 || cell.x < -10;
                                }
                                onReleased: {
                                    mouseDrag = false;
                                    pager.dragging = false; edgeTimer.running = false;
                                    const from = grid.dragFrom;
                                    grid.dragFrom = -1; grid.hoverTarget = -1;
                                    if (!moved) { cell.x = Qt.binding(cell.restX); cell.y = Qt.binding(cell.restY); return; }
                                    const cx = cell.x + cell.width / 2, cy = cell.y + cell.height / 2;
                                    const col = Math.max(0, Math.min(home.columns - 1, Math.floor(cx / home.cellWidth)));
                                    const row = Math.max(0, Math.floor(cy / home.cellHeight));
                                    const target = page.cellAt(cx, cy);
                                    // The centre of a cell means "drop onto": a folder forms. The rest means "move here".
                                    const fx = cx / home.cellWidth - col, fy = cy / home.cellHeight - row;
                                    const merge = fx > .3 && fx < .7 && fy > .2 && fy < .6 && target < page.pdata.items.length && !home.isEmpty(page.pdata.items[target]) && target !== from;
                                    cell.x = Qt.binding(cell.restX); cell.y = Qt.binding(cell.restY);
                                    home.drop(page.number, from, target, merge);
                                }
                                onClicked: e => {
                                    if (e.button === Qt.RightButton) {
                                        if (!moved) cell.openMenu();
                                        return;
                                    }
                                    if (moved || home.editing) return;
                                    if (home.menuFor !== null) { home.menuFor = null; return; }
                                    if (cell.folder) { home.openFolder = cell.modelData; home.openFolderPage = page.number; home.openFolderIndex = cell.index; }
                                    else if (cell.isPair) PhoneState.launchAppPair(PhoneState.homeScreen(), cell.modelData.pair[0], cell.modelData.pair[1], cell.modelData.ratio || .5);
                                    else if (cell.app) Hub.launch(cell.app);
                                    else if (cell.file) Hub.command({action: "desktop-open", path: cell.file.path});
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

    // Long-press or right-click menu: the same app actions as the dock (open, pin, close, shortcuts, its windows), then the home actions.
    Rectangle {
        anchors.fill: parent; visible: home.menuFor !== null; color: Theme.alpha("#000000", .38)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: home.menuFor = null }
    }
    Rectangle {
        id: menuCard
        visible: home.menuFor !== null
        readonly property var app: home.menuFor ? home.menuFor.app : null
        readonly property var entries: {
            const m = home.menuFor;
            if (!m) return [];
            if (m.file) {
                const f = m.file;
                return [
                    {text: "Open", icon: "open_in_new", quick: true, run: () => Hub.command({action: "desktop-open", path: f.path})},
                    {text: "Show in Files", icon: "folder_open", quick: true, run: () => Hub.command({action: "desktop-reveal", path: f.path})},
                    {text: "Copy path", icon: "content_copy", run: () => Hub.command({action: "clipboard", text: f.path})},
                    {text: "Edit home", icon: "edit", run: () => home.editing = true},
                    {text: "Move to trash", icon: "delete", danger: true, run: () => Hub.command({action: "desktop-trash", path: f.path})}
                ];
            }
            const appEntries = PhoneState.windowExtras(PhoneState.homeScreen(), menuCard.app).concat(Hub.appMenu(menuCard.app).filter(e => e.icon !== "add_to_home_screen"));
            return appEntries.concat([
                {text: "Widgets", icon: "widgets", run: () => { home.editing = true; home.pickerOpen = true; }},
                {text: "Edit home", icon: "edit", run: () => home.editing = true},
                {text: m.folder ? "Remove folder" : "Remove from home", icon: "delete", danger: true, run: () => home.removeItem(m.page, m.index)}
            ]);
        }
        width: Math.min(home.width - 24, 300)
        height: Math.min(menuBody.implicitHeight, home.height - 24)
        x: home.menuFor ? Math.max(12, Math.min(home.width - width - 12, home.menuFor.x + home.menuFor.w / 2 - width / 2)) : 0
        y: home.menuFor ? (home.menuFor.y - height - 8 > 12 ? home.menuFor.y - height - 8 : Math.min(home.height - height - 12, home.menuFor.y + home.menuFor.h + 8)) : 0
        radius: 28; color: Theme.level(3)
        scale: visible ? 1 : .9
        Behavior on scale { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
        ContextMenuBody {
            id: menuBody
            anchors.fill: parent
            entries: menuCard.entries
            title: menuCard.app ? menuCard.app.name : home.menuFor && home.menuFor.file ? home.menuFor.file.name : home.menuFor && home.menuFor.folder ? "Folder" : ""
            icon: "apps"
            maxHeight: home.height - 24
            onActivated: entry => { home.menuFor = null; if (entry.run) entry.run(); }
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
                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { const id = modelData; home.folderSet((f, items) => { f.apps = f.apps.filter(a => a !== id); items[home.firstFree(items)] = id; }); } }
                            }
                        }
                    }
                }
            }
        }
    }
}
