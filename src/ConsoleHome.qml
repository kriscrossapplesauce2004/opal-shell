import QtQuick
import QtQuick.Layouts
import Quickshell

// Console home: Shelves with the Spotlight inside. A rail, a featured card that follows focus, widgets that act, and shelves.
// It is the compositor's base: Hyprland's empty Home workspace, or gamescope's base app. Apps come in front of it; it never covers them.
Item {
    id: home
    property bool embedded: true
    // home, library or captures.
    property string page: "home"
    // A sheet over the home: storage, minecraft, profile or edit.
    property string sheet: ""
    property var focusEntry: null
    property bool detailOpen: false
    property string confirmId: ""
    // The home takes the controller only while it is really on screen, never under a game.
    readonly property bool shown: Compositor.homeShown && Hub.page === "" && !GameState.quickAccess && !Hub.locked && visible
    readonly property real s: Math.min(1, Math.max(.78, height / 800))
    readonly property real railWidth: 84
    readonly property real contentX: railWidth + 44
    readonly property real contentW: width - contentX - 40
    readonly property bool wideLayout: contentW >= 980

    // Library entries. Minecraft instances group into one cover.
    function entry(g) { return {id: g.id, title: g.title, source: g.source, cover: g.cover || "", hero: g.hero || "", header: g.header || "", logo: g.logo || "", icon: g.icon || "", lastPlayed: g.lastPlayed || 0, data: g}; }
    readonly property var games: Hub.games.map(entry)
    readonly property var minecraft: games.filter(e => e.source === "Minecraft")
    readonly property var group: minecraft.length > 1 ? {id: "group:minecraft", title: "Minecraft", source: "Minecraft", group: true, count: minecraft.length, cover: "", hero: "", header: "", logo: "", lastPlayed: Math.max.apply(null, minecraft.map(m => m.lastPlayed))} : null
    function running(e) { return !!e && (e.group ? minecraft.some(m => Hub.gameRunning(m.data)) : !!e.data && Hub.gameRunning(e.data)); }
    readonly property var recent: {
        const list = games.filter(e => !(group && e.source === "Minecraft")).concat(group ? [group] : []);
        const live = list.filter(e => running(e));
        return live.concat(list.filter(e => e.lastPlayed > 0 && live.indexOf(e) < 0).sort((a, b) => b.lastPlayed - a.lastPlayed)).slice(0, 16);
    }
    readonly property var pinnedEntries: (Hub.prefs.gamePins || []).map(id => games.find(e => e.id === id)).filter(e => !!e)
    readonly property var continueEntry: recent.find(e => !e.group) || null
    readonly property var featured: focusEntry && !focusEntry.group ? focusEntry : continueEntry
    readonly property var widgetKinds: (Hub.prefs.consoleWidgets || ["updates", "devices", "music", "storage", "captures", "next"]).filter(k => k !== "playtime")
    readonly property var columnWidgets: wideLayout ? widgetKinds.slice(0, 2) : []
    readonly property var shelfWidgets: wideLayout ? widgetKinds.slice(2) : widgetKinds
    readonly property bool collapsed: flick.contentY > 190
    readonly property var facts: featured && GameState.detail.id === featured.id ? GameState.detail : ({})

    function minutesText(m) { return m < 60 ? m + " min" : Math.floor(m / 60).toLocaleString(Qt.locale(), "f", 0) + " h" + (m < 600 && m % 60 ? " " + (m % 60) + " min" : ""); }
    function bytesText(b) { return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : Math.max(1, Math.round(b / 1048576)) + " MB"; }
    function ago(stamp) {
        if (!stamp) return "";
        const days = Math.floor((Date.now() / 1000 - stamp) / 86400);
        return days < 1 ? "today" : days === 1 ? "yesterday" : days < 7 ? days + " days ago" : Qt.formatDate(new Date(stamp * 1000), "d MMM");
    }
    function kickerFor(e) {
        if (!e) return "";
        if (running(e)) return "RUNNING NOW";
        if (continueEntry && e.id === continueEntry.id) return "CONTINUE";
        return e.lastPlayed ? "PLAYED " + ago(e.lastPlayed).toUpperCase() : "NOT PLAYED HERE YET";
    }
    function play(e) {
        if (!e) return;
        if (e.group) { sheet = "minecraft"; return; }
        const open = Hub.gameWindows(e.data);
        if (open.length) Compositor.focusApp(open[0]);
        else Hub.launchGame(e.data);
    }
    function pin(e) { if (e && e.data) Hub.pinGame(e.data); }
    function openPage(p) { page = p; sheet = ""; if (p === "home") flick.contentY = 0; }
    function cyclePage(delta) {
        const pages = ["home", "library", "pinned", "captures", "search"];
        const at = Math.max(0, pages.indexOf(page === "library" && library.category === "Pinned" ? "pinned" : page));
        railPick(pages[(at + delta + pages.length) % pages.length]);
    }
    function railPick(id) {
        if (id === "home" || id === "captures") { openPage(id); return; }
        page = "library"; sheet = "";
        library.query = ""; library.searching = id === "search";
        library.category = id === "pinned" ? "Pinned" : "All";
        library.selection = 0;
    }

    onFeaturedChanged: detailLoad.restart()
    // A sheet takes the controller focus with it, and gives it back when it closes.
    onSheetChanged: if (ControllerNav.usingController) padFocus.selectSoon()
    onPageChanged: if (ControllerNav.usingController && page !== "library") padFocus.selectSoon()
    Timer { id: detailLoad; interval: 240; onTriggered: if (home.featured && home.featured.data && !home.featured.group) GameState.loadDetail(home.featured.id) }
    Component.onCompleted: { if (!Hub.games.length) Hub.command({action: "game-library"}); GameState.loadWidgets(); GameState.refresh(); }
    onShownChanged: if (shown) { GameState.loadWidgets(); if (ControllerNav.usingController) padFocus.selectSoon(); }
    // Widget data stays fresh while the home is on screen.
    Timer { interval: 30000; repeat: true; running: home.shown; onTriggered: GameState.loadWidgets() }

    focus: true
    Keys.onPressed: e => {
        if (home.page === "library") return;
        if (e.key === Qt.Key_F3) { home.railPick("search"); e.accepted = true; }
        else if (ControllerNav.fromKeyboard(e)) e.accepted = true;
    }

    Rectangle { anchors.fill: parent; color: Theme.base }
    // The Spotlight: the featured game's art washes the top of the page and fades as the page scrolls.
    RoundedImage {
        id: wash
        width: parent.width; height: Math.min(parent.height * .66, 560); radius: 0
        source: home.featured ? home.featured.hero || home.featured.cover || "" : ""; decodeSize: Qt.size(1920, 620)
        opacity: home.page === "home" ? .42 * Math.max(0, 1 - flick.contentY / 420) : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
    }
    Rectangle {
        anchors.fill: wash
        gradient: Gradient { GradientStop { position: 0; color: Theme.alpha(Theme.base, .35) } GradientStop { position: 1; color: Theme.base } }
    }

    Item {
        id: surface
        anchors.fill: parent

        // Rail.
        Rectangle {
            id: rail
            x: 12; y: 12; width: home.railWidth; height: parent.height - 24; radius: 28
            color: Theme.alpha(Theme.level(1), .88)
            Column {
                anchors.horizontalCenter: parent.horizontalCenter; y: 24; spacing: 14
                Repeater {
                    model: [{id: "home", g: "home", t: "Home"}, {id: "library", g: "grid_view", t: "Library"}, {id: "pinned", g: "collections_bookmark", t: "Pinned"},
                            {id: "captures", g: "photo_library", t: "Captures"}, {id: "search", g: "search", t: "Search"}]
                    Item {
                        id: railItem
                        required property var modelData
                        readonly property bool current: modelData.id === "pinned" ? home.page === "library" && library.category === "Pinned" && !library.searching
                            : modelData.id === "search" ? home.page === "library" && library.searching
                            : modelData.id === "library" ? home.page === "library" && library.category !== "Pinned" && !library.searching : home.page === modelData.id
                        width: 72; height: 58
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 32; radius: 16
                            color: railItem.current ? Theme.secondaryContainer : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
                            Glyph { anchors.centerIn: parent; name: railItem.modelData.g; font.pixelSize: 22; color: railItem.current ? Theme.onSecondaryContainer : Theme.subtext }
                        }
                        MText { anchors.horizontalCenter: parent.horizontalCenter; y: 37; text: railItem.modelData.t; role: "labelS"; font.weight: railItem.current ? Font.Bold : Font.Medium; color: railItem.current ? Theme.text : Theme.subtext }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.railPick(railItem.modelData.id) }
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.t
                    }
                }
            }
            MButton {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                icon: "settings"; tooltip: "Settings"; compact: true; ink: Theme.subtext
                onClicked: { Hub.targetScreen = Hub.chooseScreen(); Hub.openSettings(); }
            }
        }

        // Title row. Scrolled, the featured card shrinks into a chip beside the title.
        Row {
            x: home.contentX; y: 26; spacing: 18
            MText { text: home.page === "captures" ? "Captures" : "Home"; role: "displayS"; anchors.verticalCenter: parent.verticalCenter; visible: home.page !== "library" }
            Rectangle {
                visible: home.page === "home" && home.collapsed && !!home.featured
                anchors.verticalCenter: parent.verticalCenter
                height: 44; width: chipRow.implicitWidth + 10; radius: 22; color: Theme.level(3)
                Row {
                    id: chipRow; x: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    RoundedImage { width: 36; height: 36; radius: 18; source: home.featured ? home.featured.cover || home.featured.hero || "" : ""; decodeSize: Qt.size(72, 108) }
                    MText { text: home.featured ? home.featured.title : ""; role: "label"; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    MButton { text: home.running(home.featured) ? "Resume" : "Play"; icon: "play_arrow"; filled: true; compact: true; onClicked: home.play(home.featured) }
                }
            }
        }
        StatusIsland { anchors.right: parent.right; anchors.rightMargin: 40; y: 30; visible: home.page !== "library" }

        // Home page.
        Flickable {
            id: flick
            visible: home.page === "home"
            x: home.contentX; y: 88; width: home.contentW; height: parent.height - y
            contentWidth: width; contentHeight: column.implicitHeight + 120
            clip: false; boundsBehavior: Flickable.StopAtBounds; flickableDirection: Flickable.VerticalFlick
            Column {
                id: column
                width: flick.width; spacing: 22

                // Featured card and the widget column.
                Item {
                    width: parent.width; height: 308
                    Item {
                        id: feature
                        width: home.wideLayout ? parent.width - 392 : parent.width; height: parent.height
                        RoundedImage { anchors.fill: parent; radius: 28; source: home.featured ? home.featured.hero || home.featured.header || "" : ""; decodeSize: Qt.size(1432, 616) }
                        Rectangle {
                            anchors.fill: parent; radius: 28
                            color: home.featured && (home.featured.hero || home.featured.header) ? "transparent" : Theme.primaryContainer
                            gradient: home.featured && (home.featured.hero || home.featured.header) ? shade : null
                            Gradient { id: shade; orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.alpha("#000000", .8) } GradientStop { position: .62; color: Theme.alpha("#000000", .18) } GradientStop { position: 1; color: "transparent" } }
                        }
                        Column {
                            x: 28; y: 26; width: parent.width - 56; spacing: 14
                            MText { text: home.kickerFor(home.featured); role: "labelS"; font.letterSpacing: 1.6; font.weight: Font.Bold; color: Theme.primary }
                            Item {
                                width: Math.min(340, parent.width); height: 96
                                Image {
                                    id: logo
                                    anchors.fill: parent; source: home.featured ? home.featured.logo : ""
                                    fillMode: Image.PreserveAspectFit; horizontalAlignment: Image.AlignLeft; verticalAlignment: Image.AlignBottom
                                    sourceSize.width: 680; asynchronous: true; smooth: true; mipmap: true
                                }
                                MText {
                                    visible: logo.status !== Image.Ready; anchors.bottom: parent.bottom; width: parent.width
                                    text: home.featured ? home.featured.title : "Nothing played yet"; role: "displayS"; color: "#ffffff"; wrapMode: Text.Wrap; maximumLineCount: 2
                                }
                            }
                            Flow {
                                width: parent.width; spacing: 8
                                Repeater {
                                    model: {
                                        const f = home.featured, list = [];
                                        if (!f) return list;
                                        if (home.facts.playtimeMinutes) list.push({g: "schedule", t: home.minutesText(home.facts.playtimeMinutes)});
                                        if (f.lastPlayed) list.push({g: "history", t: "Played " + home.ago(f.lastPlayed)});
                                        if (home.facts.sizeBytes) list.push({g: "hard_drive", t: home.bytesText(home.facts.sizeBytes)});
                                        const shots = ((GameState.widgets.captures || {}).perGame || {})[f.id];
                                        if (shots) list.push({g: "photo_library", t: shots + (shots === 1 ? " capture" : " captures")});
                                        return list;
                                    }
                                    Rectangle {
                                        required property var modelData
                                        height: 32; width: factRow.implicitWidth + 24; radius: 16; color: Theme.alpha("#000000", .45)
                                        Row { id: factRow; anchors.centerIn: parent; spacing: 6
                                            Glyph { name: modelData.g; font.pixelSize: 17; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                            MText { text: modelData.t; role: "label"; font.weight: Font.DemiBold; font.features: {"tnum": 1}; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter } }
                                    }
                                }
                            }
                            Row {
                                spacing: 8
                                visible: !!home.featured
                                MButton { text: home.running(home.featured) ? "Resume" : "Play"; icon: "play_arrow"; filled: true; onClicked: home.play(home.featured) }
                                MButton { text: home.featured ? GameState.profileLabel(home.featured.id) : ""; icon: "tune"; tonal: true; onClicked: home.sheet = "profile" }
                                MButton { icon: "info"; tooltip: "Details"; tonal: true; onClicked: { home.detailOpen = true; GameState.loadDetail(home.featured.id); } }
                            }
                        }
                    }
                    Column {
                        visible: home.wideLayout
                        x: parent.width - 380; spacing: 12
                        Repeater {
                            model: home.columnWidgets
                            ConsoleWidget { required property var modelData; required property int index; width: 380; height: index === 0 ? 176 : 120; kind: modelData; onOpenSheet: k => home.openSheet(k) }
                        }
                    }
                }

                // Jump back in: the focused cover grows wide and becomes the featured card.
                Column {
                    width: parent.width; spacing: 12
                    visible: home.recent.length > 0
                    SectionLabel { text: "Jump back in"; meta: "Recently played" }
                    ListView {
                        id: recentRow
                        width: parent.width; height: 176; orientation: ListView.Horizontal; spacing: 14
                        clip: false; boundsBehavior: Flickable.StopAtBounds
                        model: home.recent
                        delegate: ConsoleCover {
                            required property var modelData
                            height: 176; entry: modelData; running: home.running(modelData)
                            kicker: modelData.lastPlayed ? "Played " + home.ago(modelData.lastPlayed) : ""
                            onControllerFocusedChanged: if (controllerFocused) home.focusEntry = modelData
                            onActivated: home.play(modelData)
                            onAlternate: home.pin(modelData)
                        }
                    }
                }
                // The widget shelf.
                Column {
                    width: parent.width; spacing: 12
                    SectionLabel { text: "Widgets"; meta: "A uses · X opens" }
                    ListView {
                        width: parent.width; height: 200; orientation: ListView.Horizontal; spacing: 16
                        clip: false; boundsBehavior: Flickable.StopAtBounds
                        model: home.shelfWidgets.concat(["edit"])
                        delegate: Item {
                            required property var modelData
                            width: modelData === "edit" ? 120 : modelData === "next" || modelData === "toggles" ? 268 : modelData === "devices" ? 220 : 290; height: 200
                            ConsoleWidget { anchors.fill: parent; visible: modelData !== "edit"; kind: modelData === "edit" ? "updates" : modelData; onOpenSheet: k => home.openSheet(k) }
                            Rectangle {
                                visible: modelData === "edit"; anchors.fill: parent; radius: 28; color: Theme.level(1)
                                border.width: 2; border.color: Theme.alpha(Theme.primary, .25)
                                Column { anchors.centerIn: parent; spacing: 8
                                    Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: "edit"; font.pixelSize: 26; color: Theme.primary }
                                    MText { anchors.horizontalCenter: parent.horizontalCenter; text: "Edit"; role: "titleS" } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.sheet = "edit" }
                            }
                        }
                    }
                }
                Column {
                    width: parent.width; spacing: 12
                    visible: home.pinnedEntries.length > 0
                    SectionLabel { text: "Pinned"; meta: String(home.pinnedEntries.length) }
                    ListView {
                        width: parent.width; height: 183; orientation: ListView.Horizontal; spacing: 14
                        clip: false; boundsBehavior: Flickable.StopAtBounds
                        model: home.pinnedEntries
                        delegate: ConsoleCover {
                            required property var modelData
                            height: 183; portraitWidth: 122; wideWidth: 388; entry: modelData; running: home.running(modelData)
                            onControllerFocusedChanged: if (controllerFocused) home.focusEntry = modelData
                            onActivated: home.play(modelData)
                            onAlternate: home.pin(modelData)
                        }
                    }
                }
                // Minecraft: each instance chip launches it; the cube opens the sheet.
                Column {
                    width: parent.width; spacing: 12
                    visible: (GameState.widgets.instances || []).length > 0
                    SectionLabel { text: "Minecraft"; meta: "Prism Launcher · " + (GameState.widgets.instances || []).length + " instances" }
                    Rectangle {
                        width: parent.width; height: 60; radius: 30; color: Theme.level(2)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 8
                            Rectangle {
                                width: 44; height: 44; radius: 22; color: Theme.tertiaryContainer
                                Glyph { anchors.centerIn: parent; name: "deployed_code"; font.pixelSize: 24; color: Theme.onTertiaryContainer }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.sheet = "minecraft" }
                            }
                            Repeater {
                                model: (GameState.widgets.instances || []).slice(0, 6)
                                Chip { required property var modelData; required property int index; text: modelData.title + (modelData.version ? "  ·  " + modelData.version : ""); icon: "play_arrow"; selected: index === 0; onClicked: Hub.launchGame({id: modelData.id}) }
                            }
                        }
                    }
                }
                Column {
                    width: parent.width; spacing: 12
                    visible: ((GameState.widgets.captures || {}).items || []).length > 0
                    SectionLabel { text: "Captures"; meta: "Steam · " + ((GameState.widgets.captures || {}).total || 0) }
                    ListView {
                        width: parent.width; height: 96; orientation: ListView.Horizontal; spacing: 12
                        clip: false; boundsBehavior: Flickable.StopAtBounds
                        model: ((GameState.widgets.captures || {}).items || []).slice(0, 12)
                        delegate: CaptureThumb { required property var modelData; width: 170; height: 96; shot: modelData }
                    }
                }
            }
        }

        // Captures page.
        GridView {
            id: capturesGrid
            visible: home.page === "captures"
            x: home.contentX; y: 96; width: home.contentW; height: parent.height - y
            cellWidth: width / Math.max(2, Math.floor(width / 280)); cellHeight: cellWidth * .62
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: (GameState.widgets.captures || {}).items || []
            delegate: Item {
                required property var modelData
                width: capturesGrid.cellWidth; height: capturesGrid.cellHeight
                CaptureThumb { anchors.fill: parent; anchors.margins: 7; shot: modelData; showTitle: true }
            }
            MText { anchors.centerIn: parent; visible: capturesGrid.count === 0; text: "Screenshots you take in Steam games show up here"; role: "title"; color: Theme.subtext }
        }
    }

    // Library page: the full grid, its own controller navigation.
    ConsoleLibrary {
        id: library
        visible: home.page === "library"
        x: home.contentX - 40; width: parent.width - x; height: parent.height
        embedded: true
        onLeave: home.openPage("home")
    }
    QtObject { id: libraryClaim; property int priority: 5 }
    readonly property bool libraryActive: shown && page === "library" && !detailOpen
    onLibraryActiveChanged: { if (libraryActive) ControllerNav.claim(libraryClaim); else ControllerNav.release(libraryClaim); }
    Component.onDestruction: ControllerNav.release(libraryClaim)
    Connections {
        target: ControllerNav
        function onKey(name) {
            if (ControllerNav.top !== libraryClaim) return;
            if (name === "previousTab" && !library.searching && library.category === library.tabs[0]) { home.cyclePage(-1); return; }
            library.navigate(name);
        }
    }

    // Sheets that widgets and the featured card open into.
    Rectangle {
        anchors.fill: parent; color: Theme.alpha("#000000", .55)
        visible: opacity > 0; opacity: home.sheet !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
        MouseArea { anchors.fill: parent; onClicked: home.sheet = "" }
    }
    Rectangle {
        id: sheetCard
        property bool controllerModal: home.sheet !== ""
        visible: home.sheet !== ""
        anchors.centerIn: parent
        width: Math.min(820, parent.width - 64); height: Math.min(parent.height - 80, sheetLoader.item ? sheetLoader.item.implicitHeight + 52 : 200)
        radius: 32; color: Theme.level(2); border.width: 1; border.color: Theme.outline
        scale: home.sheet !== "" ? 1 : .96
        Behavior on scale { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        MouseArea { anchors.fill: parent }
        Flickable {
            anchors.fill: parent; anchors.margins: 26; contentHeight: sheetLoader.item ? sheetLoader.item.implicitHeight : 0; clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: sheetLoader
                width: parent.width
                sourceComponent: home.sheet === "storage" ? storageSheet : home.sheet === "minecraft" ? minecraftSheet : home.sheet === "profile" ? profileSheet : home.sheet === "edit" ? editSheet : null
            }
        }
    }
    function openSheet(kind) {
        if (kind === "storage" || kind === "minecraft" || kind === "edit") sheet = kind;
        else if (kind === "captures") openPage("captures");
        else if (kind === "updates") Hub.command({action: "steam-downloads"});
        else if (kind === "devices") Hub.settings("bluetooth");
        else if (kind === "next") sheet = "edit";
        else if (kind === "music") Hub.media("next");
        else if (kind === "claude") Hub.openAssistant();
        else if (kind === "toggles") { Hub.targetScreen = Hub.chooseScreen(); Hub.toggle("controls"); }
    }

    component SheetTitle: Row {
        property string g: ""
        property string t: ""
        property string d: ""
        property color tint: Theme.primaryContainer
        property color ink: Theme.onContainer
        spacing: 12
        Rectangle { width: 44; height: 44; radius: 22; color: parent.tint; Glyph { anchors.centerIn: parent; name: parent.parent.g; font.pixelSize: 22; color: parent.parent.ink } }
        Column { anchors.verticalCenter: parent.verticalCenter
            MText { text: parent.parent.t; role: "headline" }
            MText { text: parent.parent.d; role: "label"; color: Theme.subtext } }
    }
    component SectionLabel: Row {
        property string text: ""
        property string meta: ""
        spacing: 10
        MText { text: parent.text; role: "title"; anchors.verticalCenter: parent.verticalCenter }
        MText { visible: parent.meta !== ""; text: parent.meta; role: "label"; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
    }
    component StatusIsland: Rectangle {
        height: 40; width: islandRow.implicitWidth + 30; radius: 20; color: Theme.alpha(Theme.level(3), .9)
        Row {
            id: islandRow; anchors.centerIn: parent; spacing: 14
            Repeater {
                model: (GameState.perf.controllers || []).slice(0, 2)
                Row { required property var modelData; spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Glyph { name: "stadia_controller"; font.pixelSize: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    MText { text: modelData.percent + "%"; role: "label"; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter } }
            }
            Row { visible: Hub.status.battery >= 0; spacing: 4; anchors.verticalCenter: parent.verticalCenter
                Glyph { name: Hub.status.charging ? "battery_charging_full" : "battery_5_bar"; font.pixelSize: 18; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                MText { text: Hub.status.battery + "%"; role: "label"; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter } }
            Glyph { visible: !!Hub.status.wifi; name: "wifi"; font.pixelSize: 18; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            MText { text: Qt.formatDateTime(Hub.now, "HH:mm"); role: "title"; font.features: {"tnum": 1}; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    component CaptureThumb: Item {
        id: thumb
        property var shot: null
        property bool showTitle: false
        property bool controllerFocused: false
        function controllerActivate() { if (shot) Hub.command({action: "open-path", path: shot.path}); }
        function controllerAlternate() { if (shot) Hub.command({action: "capture-copy", path: shot.path}); }
        RoundedImage { anchors.fill: parent; radius: 16; source: thumb.shot ? "file://" + thumb.shot.path : ""; decodeSize: Qt.size(Math.round(thumb.width * 1.5), Math.round(thumb.height * 1.5)) }
        Rectangle {
            visible: thumb.showTitle; anchors.fill: parent; radius: 16
            gradient: Gradient { GradientStop { position: .55; color: "transparent" } GradientStop { position: 1; color: Theme.alpha("#000000", .75) } }
        }
        MText {
            visible: thumb.showTitle; x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: parent.width - 24
            text: thumb.shot ? ((Hub.games.find(g => g.id === thumb.shot.id) || {title: "Screenshot"}).title + " · " + Qt.formatDate(new Date(thumb.shot.time * 1000), "d MMM")) : ""
            role: "label"; font.weight: Font.DemiBold; color: "#ffffff"
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => { if (e && e.button === Qt.RightButton) thumb.controllerAlternate(); else thumb.controllerActivate(); } }
    }

    Component {
        id: storageSheet
        Column {
            readonly property var st: GameState.widgets.storage || ({})
            readonly property var largest: st.largest || []
            readonly property var playtime: (GameState.widgets.playtime || {})
            spacing: 16
            SheetTitle { g: "hard_drive"; t: "Storage"; d: home.bytesText(parent.st.free || 0) + " free of " + home.bytesText(parent.st.total || 0) + " · games use " + home.bytesText(parent.st.games || 0) }
            StorageBar {
                width: parent.width; barHeight: 22; total: parent.st.total || 1
                parts: {
                    const l = parent.largest, top = l.slice(0, 2).reduce((s, g) => s + g.bytes, 0);
                    return [{v: l[0] ? l[0].bytes : 0, c: Theme.primary}, {v: l[1] ? l[1].bytes : 0, c: Theme.tertiary}, {v: Math.max(0, (parent.st.games || 0) - top), c: Theme.secondary},
                            {v: Math.max(0, (parent.st.total || 0) - (parent.st.free || 0) - (parent.st.games || 0)), c: Theme.alpha(Theme.text, .35)}, {v: parent.st.free || 0, c: Theme.level(4)}];
                }
            }
            MText { text: "Largest games"; role: "titleS"; topPadding: 4 }
            Repeater {
                model: parent.largest.slice(0, 6)
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var game: Hub.games.find(g => g.id === modelData.id) || null
                    readonly property int minutes: (GameState.widgets.storage.playtime || {})[modelData.id] || -1
                    width: parent.width; height: 58; radius: 20; color: Theme.level(3)
                    RoundedImage { x: 9; y: 9; width: 40; height: 40; radius: 12; source: row.game ? row.game.cover || row.game.hero || "" : ""; decodeSize: Qt.size(80, 120) }
                    Column {
                        x: 62; anchors.verticalCenter: parent.verticalCenter
                        Row { spacing: 8
                            MText { text: row.modelData.title; role: "titleS" }
                            Rectangle { visible: row.minutes >= 0 && row.minutes < 60 && row.modelData.bytes > 1073741824; width: hint.implicitWidth + 14; height: 20; radius: 10; color: Theme.tertiaryContainer; anchors.verticalCenter: parent.verticalCenter
                                MText { id: hint; anchors.centerIn: parent; text: "Barely played"; role: "labelS"; font.weight: Font.Bold; color: Theme.onTertiaryContainer } } }
                        MText { text: (row.minutes >= 0 ? home.minutesText(row.minutes) + " in total" : "") + (row.modelData.lastPlayed ? " · played " + home.ago(row.modelData.lastPlayed) : ""); role: "labelS"; color: Theme.subtext }
                    }
                    MText { anchors.right: uninstall.left; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: home.bytesText(row.modelData.bytes); role: "titleS"; font.features: {"tnum": 1} }
                    MButton {
                        id: uninstall
                        anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                        text: home.confirmId === row.modelData.id ? "Press again" : "Uninstall"; icon: "delete"; tonal: true; compact: true
                        onClicked: {
                            if (home.confirmId !== row.modelData.id) { home.confirmId = row.modelData.id; return; }
                            home.confirmId = ""; Hub.command({action: "game-uninstall", id: row.modelData.id});
                        }
                    }
                }
            }
            MText { text: "Steam asks for its own confirmation before it removes anything."; role: "labelS"; color: Theme.subtext }
        }
    }
    Component {
        id: minecraftSheet
        Column {
            readonly property var list: GameState.widgets.instances || []
            spacing: 10
            SheetTitle { g: "deployed_code"; t: "Minecraft"; tint: Theme.tertiaryContainer; ink: Theme.onTertiaryContainer
                d: "Prism Launcher · " + parent.list.length + " instances · " + home.minutesText(Math.round(parent.list.reduce((s, i) => s + i.seconds, 0) / 60)) }
            Repeater {
                model: parent.list
                Rectangle {
                    id: inst
                    required property var modelData
                    required property int index
                    width: parent.width; height: 76; radius: 24; color: Theme.level(3)
                    Rectangle { x: 12; y: 12; width: 52; height: 52; radius: 16; color: [Theme.tertiaryContainer, Theme.primaryContainer, Theme.secondaryContainer][inst.index % 3]
                        Glyph { anchors.centerIn: parent; name: "deployed_code"; font.pixelSize: 26 } }
                    Column {
                        x: 80; anchors.verticalCenter: parent.verticalCenter; spacing: 4; width: parent.width - 300
                        MText { width: parent.width; text: inst.modelData.title; role: "title" }
                        MText { width: parent.width; text: [inst.modelData.version ? "Minecraft " + inst.modelData.version : "", inst.modelData.loader, inst.modelData.mods + " mods", home.minutesText(Math.round(inst.modelData.seconds / 60)), inst.modelData.lastPlayed ? "last " + home.ago(inst.modelData.lastPlayed) : ""].filter(x => x).join("  ·  "); role: "labelS"; color: Theme.subtext }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        MButton { icon: "folder_open"; tooltip: "Mods folder"; tonal: true; onClicked: Hub.command({action: "open-path", path: inst.modelData.modsPath}) }
                        MButton { text: "Play"; icon: "play_arrow"; filled: inst.index === 0; tonal: inst.index !== 0; onClicked: { home.sheet = ""; Hub.launchGame({id: inst.modelData.id}); } }
                    }
                }
            }
        }
    }
    Component {
        id: profileSheet
        Column {
            readonly property var f: home.featured
            readonly property var own: f ? GameState.ownProfile(f.id) : null
            readonly property var p: f ? GameState.profileFor(f.id) : ({})
            spacing: 16
            SheetTitle { g: "tune"; t: "Performance profile"; d: parent.f ? parent.f.title + " · applied when it starts, undone when it quits" : "" }
            ChoiceGroup {
                width: parent.width; icon: "speed"; title: "Profile"; detail: parent.own ? "Only for this game" : "Uses the next-game setting"
                options: [{id: "next", name: "Next-game setting"}, {id: "saver", name: "Saver · 40", icon: "eco"}, {id: "balanced", name: "Balanced · 60", icon: "balance"}, {id: "max", name: "Max", icon: "rocket_launch"}, {id: "custom", name: "Custom", icon: "tune"}]
                current: parent.own ? parent.own.preset : "next"
                onPicked: id => {
                    if (!home.featured) return;
                    if (id === "next") GameState.setOwnProfile(home.featured.id, null);
                    else if (id === "custom") GameState.setOwnProfile(home.featured.id, Object.assign({preset: "custom", power: "balanced", fpsLimit: 60}, parent.own && parent.own.preset === "custom" ? parent.own : {}));
                    else GameState.setOwnProfile(home.featured.id, {preset: id});
                }
            }
            ChoiceGroup {
                visible: !!parent.own && parent.own.preset === "custom"; width: parent.width; icon: "speed"; title: "Frame limit"; detail: Compositor.gamescope ? "gamescope" : "MangoHud"
                options: [0, 30, 40, 45, 60, 72, 90, 120, 144].map(v => ({id: v, name: v ? String(v) : "Off"}))
                current: parent.own ? parent.own.fpsLimit || 0 : 0
                onPicked: id => GameState.setOwnProfile(home.featured.id, Object.assign({}, GameState.ownProfile(home.featured.id), {fpsLimit: id}))
            }
            ChoiceGroup {
                visible: !!parent.own && parent.own.preset === "custom"; width: parent.width; icon: "bolt"; title: "Power profile"; detail: "powerprofilesctl"
                options: [{id: "power-saver", name: "Saver", icon: "eco"}, {id: "balanced", name: "Balanced", icon: "balance"}, {id: "performance", name: "Performance", icon: "rocket_launch"}]
                current: parent.own ? parent.own.power || "balanced" : "balanced"
                onPicked: id => GameState.setOwnProfile(home.featured.id, Object.assign({}, GameState.ownProfile(home.featured.id), {power: id}))
            }
            MText { width: parent.width; wrapMode: Text.Wrap; text: "Now: " + (parent.p.name || "") + " · " + (parent.p.fpsLimit ? parent.p.fpsLimit + " FPS" : "no frame limit"); role: "label"; color: Theme.subtext }
        }
    }
    Component {
        id: editSheet
        Column {
            spacing: 14
            SheetTitle { g: "widgets"; t: "Widgets"; d: "Pick what the home shows. The first two sit beside the featured game." }
            Grid {
                columns: 3; spacing: 10; width: parent.width
                Repeater {
                    model: [{id: "updates", g: "download", t: "Updates", d: "Steam queue, update all"}, {id: "devices", g: "devices", t: "Devices", d: "Batteries, pair a controller"},
                            {id: "music", g: "music_note", t: "Music", d: "Play, skip, seek"}, {id: "storage", g: "hard_drive", t: "Storage", d: "Free space, uninstall"},
                            {id: "captures", g: "photo_library", t: "Captures", d: "Newest screenshot, copy it"}, {id: "next", g: "tune", t: "Next game", d: "Saver, Balanced, Max"},
                            {id: "minecraft", g: "deployed_code", t: "Minecraft", d: "Launch an instance"}, {id: "toggles", g: "toggle_on", t: "Toggles", d: "Wi-Fi, Bluetooth, DND"},
                            {id: "claude", g: "auto_awesome", t: "Ask Claude", d: "Hold Guide to talk"}]
                    Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool on: home.widgetKinds.indexOf(modelData.id) >= 0
                        width: (parent.width - 20) / 3; height: 96; radius: 24; color: Theme.level(3)
                        Rectangle { x: 14; y: 14; width: 36; height: 36; radius: 18; color: tile.on ? Theme.secondaryContainer : Theme.alpha(Theme.primary, .16)
                            Glyph { anchors.centerIn: parent; name: tile.on ? "check" : tile.modelData.g; font.pixelSize: 20; color: tile.on ? Theme.onSecondaryContainer : Theme.primary } }
                        Column { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: parent.width - 28
                            MText { text: tile.modelData.t; role: "titleS" }
                            MText { width: parent.width; text: tile.modelData.d; role: "labelS"; color: Theme.subtext } }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const list = home.widgetKinds.slice(), i = list.indexOf(tile.modelData.id);
                                if (i >= 0) list.splice(i, 1); else list.push(tile.modelData.id);
                                Hub.set("consoleWidgets", list);
                            }
                        }
                    }
                }
            }
            MButton { text: "Done"; icon: "check"; filled: true; onClicked: home.sheet = "" }
        }
    }

    GameDetail {
        anchors.fill: parent
        entry: home.featured && !home.featured.group ? home.featured : null
        open: home.detailOpen && !!home.featured && !home.featured.group
        running: home.running(home.featured)
        pinned: !!home.featured && (Hub.prefs.gamePins || []).indexOf(home.featured.id) >= 0
        onDismissed: home.detailOpen = false
        onPlay: { home.detailOpen = false; home.play(home.featured); }
        onPin: home.pin(home.featured)
        onQuit: { Hub.gameWindows(home.featured.data).forEach(w => Compositor.closeApp(w)); home.detailOpen = false; }
        onUninstall: { Hub.command({action: "game-uninstall", id: home.featured.id}); home.detailOpen = false; }
    }

    ControllerFocus {
        id: padFocus
        anchors.fill: parent
        root: surface.parent
        priority: 5
        active: home.shown && home.page !== "library" && !home.detailOpen
        closeOnBack: false
        tabHints: true
        extraHints: [{b: ControllerNav.altLabel, t: "Options"}, {b: "☰", t: "Quick Access"}]
        onBack: {
            if (home.sheet !== "") { home.sheet = ""; home.confirmId = ""; }
            else if (home.page !== "home") home.openPage("home");
            else flick.contentY = 0;
        }
        onTab: delta => home.cyclePage(delta)
        onAction: name => {
            if (name === "search") home.railPick("search");
            else if (name === "menu") GameState.openQuickAccess(false);
        }
    }
}
