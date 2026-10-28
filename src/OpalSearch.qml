import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "StartSearch.js" as Search
import "SearchModel.js" as Model

// One search for every posture. Idle is minimal; typing gives answer cards, Claude inline and grouped results from local sources. Only the web row leaves the device.
FocusScope {
    id: s
    // Touch posture: larger rows and fewer results per section.
    property bool touch: false
    // When false, the host draws the field and forwards keys to accept(), move() and ask().
    property bool ownField: true
    property string placeholder: Hub.aiEnabled !== false ? "Search apps, files, settings or ask Claude" : "Search apps, files and settings"
    readonly property string query: Hub.query.trim()
    readonly property bool searching: query !== ""
    readonly property bool math: searching && (query.startsWith("=") || Hub.looksLikeMath(query))
    readonly property var conversion: searching && !math ? Model.convert(query) : null
    // The user asked Claude on purpose (Tab, the spark button, or Enter on a question).
    property string askedFor: ""
    readonly property bool question: searching && !math && !conversion && Model.isQuestion(query)
    // With AI features off there is no inline Claude answer at all.
    readonly property bool claude: Hub.aiEnabled !== false && searching && (askedFor === query || question)
    property string sentQuery: ""
    // Space around the content. Hosts with their own padding set 0.
    property real inset: 16
    readonly property real fitHeight: layout.implicitHeight + inset * 2 + (ownField ? fieldBox.height + 12 : 0)
    implicitHeight: fitHeight

    // Saved spaces reopen from search like actions.
    readonly property var actions: allActions.filter(a => Hub.aiEnabled !== false || a.id !== "assistant")
        .concat(Spaces.saved.map(sp => ({id: "space:" + sp.id, name: sp.name, detail: "Saved space · " + (sp.apps || []).length + " apps", icon: sp.icon || "bookmark", keywords: "space workspace project saved " + sp.name})))
    readonly property var allActions: [
        {id:"controls",name:"Quick settings",detail:"Wi-Fi, sound and display",icon:"tune",keywords:"control center volume brightness"},
        {id:"wallpaper",name:"Wallpaper",detail:"Choose a background image",icon:"wallpaper",keywords:"background photo picture"},
        {id:"windows",name:"App switcher",detail:"Every open window",icon:"desktop",keywords:"tasks windows switch"},
        {id:"clipboard",name:"Clipboard history",detail:"Things you copied this session",icon:"clipboard",keywords:"copy paste"},
        {id:"capture",name:"Screenshot",detail:"Region, window or screen · Print",icon:"capture",keywords:"screen capture image snip snipping ocr text grab capture studio",boost:20},
        {id:"record",name:Hub.recordingActive ? "Stop recording" : "Record screen",detail:"Video of the screen · Super+Shift+R",icon:Hub.recordingActive ? "stop_circle" : "screen_record",keywords:"video record screencast recording capture"},
        {id:"lock",name:"Lock",detail:"Lock this session",icon:"lock",keywords:"secure screen"},
        {id:"focus",name:"Focus timer",detail:"25 minutes, no distractions",icon:"timer",keywords:"pomodoro concentrate"},
        {id:"assistant",name:"Assistant",detail:"Ask Claude in the panel",icon:"auto_awesome",keywords:"claude ai chat help"},
        // Opal's own Settings outranks other desktops' Settings apps with the same name.
        {id:"settings",name:"Settings",detail:"Opal settings",icon:"settings",keywords:"preferences configure options control panel opal",boost:60},
        {id:"android-store",name:"Android apps",detail:Hub.waydroid.installed&&Hub.waydroid.initialized ? "Get apps from F-Droid" : "Set up Android, then get apps",icon:"android",keywords:"app store apps waydroid android apk play store fdroid f-droid install aurora",boost:30},
        {id:"android-setup",name:Hub.waydroid.installed&&Hub.waydroid.initialized ? "Manage Android" : "Set up Android",detail:"Waydroid installer",icon:"install_mobile",keywords:"waydroid android install setup play store gapps",boost:10},
        {id:"setup",name:"Set up Opal",detail:Hub.aiEnabled !== false ? "Wi-Fi, look, layout, apps and Claude" : "Wi-Fi, look, layout and apps",icon:"auto_awesome",keywords:"setup onboarding welcome tour first run oobe"},
        {id:"workspaces",name:"Workspaces",detail:"Every workspace as tiles",icon:"space_dashboard",keywords:"workspace desktops overview switch virtual"}
    ]
    // Settings index. Entries with get and set show an inline switch; the others open their Settings page.
    readonly property var settingsIndex: [
        {id:"light",title:"Dark theme",path:"Settings › Wallpaper & style",icon:"dark_mode",keywords:"dark mode night theme colours colors",open:"appearance",
            get:()=>!Theme.light,set:v=>Hub.set("light",!v)},
        {id:"motion",title:"Reduced motion",path:"Settings › Accessibility",icon:"animation",keywords:"animations motion effects",open:"accessibility",
            get:()=>Theme.reduceMotion,set:v=>Hub.set("reduceMotion",v)},
        {id:"dnd",title:"Do not disturb",path:"Settings › Notifications",icon:"do_not_disturb_on",keywords:"quiet silence dnd notifications focus",open:"notifications",
            get:()=>Hub.dnd,set:v=>Hub.set("dnd",v)},
        {id:"awake",title:"Keep awake",path:"Settings › Battery & power",icon:"coffee",keywords:"caffeine sleep screen awake inhibit idle",open:"power",
            get:()=>Hub.keepAwake,set:v=>{Hub.keepAwake=v;}},
        {id:"saver",title:"Battery saver",path:"Settings › Battery & power",icon:"battery_saver",keywords:"power saver profile energy",open:"power",
            get:()=>Hub.status.profile==="power-saver",set:v=>Hub.command({action:"profile",value:v ? "power-saver" : "balanced"})},
        {id:"wifi",title:"Wi-Fi",path:"Settings › Network & internet",icon:"wifi",keywords:"wireless internet network wlan",open:"network",
            get:()=>!!Hub.status.wifi,set:v=>Hub.connection("wifi","power",{enabled:v})},
        {id:"bluetooth",title:"Bluetooth",path:"Settings › Connected devices",icon:"bluetooth",keywords:"headphones pairing wireless",open:"bluetooth",
            get:()=>!!Hub.status.bluetooth,set:v=>Hub.connection("bluetooth","power",{enabled:v})},
        {id:"mic",title:"Microphone",path:"Settings › Sound",icon:"mic",keywords:"mic mute input recording",open:"sound",
            get:()=>!Hub.status.micMuted,set:v=>{if(v===!!Hub.status.micMuted)Hub.command({action:"mic"});}},
        {id:"widgets",title:"Desktop widgets",path:"Settings › Wallpaper & style",icon:"widgets",keywords:"widgets desktop clock wallpaper",open:"appearance",
            get:()=>Hub.prefs.desktopWidgets!==false,set:v=>Hub.set("desktopWidgets",v)},
        {id:"autohide",title:"Auto-hide shelf",path:"Settings › Shelf",icon:"dock_to_bottom",keywords:"taskbar hide bar dock panel",open:"taskbar",
            get:()=>!!Hub.prefs.taskbarAutoHide,set:v=>Hub.set("taskbarAutoHide",v)},
        {id:"floating",title:"Floating windows",path:"Settings › Wallpaper & style",icon:"select_window",keywords:"float stacking titlebars snap layouts minimize windows tiling",open:"appearance",
            get:()=>!!Hub.prefs.floatingMode,set:v=>Hub.set("floatingMode",v)},
        {id:"phonebuttons",title:"Navigation buttons",path:"Settings › Phone & navigation",icon:"more_horiz",keywords:"three button gestures nav bar",open:"phone",
            get:()=>!!Hub.prefs.phoneButtons,set:v=>Hub.set("phoneButtons",v)},
        {id:"s-network",title:"Network & internet",path:"Settings",icon:"wifi",keywords:"wi-fi networks saved",open:"network"},
        {id:"s-devices",title:"Connected devices",path:"Settings",icon:"bluetooth",keywords:"bluetooth pairing",open:"bluetooth"},
        {id:"s-link",title:"Opal Link",path:"Settings",icon:"devices",keywords:"phone kde connect devices sync",open:"link"},
        {id:"s-sound",title:"Sound",path:"Settings",icon:"volume_up",keywords:"volume outputs microphone audio speakers",open:"sound"},
        {id:"s-displays",title:"Displays",path:"Settings",icon:"monitor",keywords:"monitor screens resolution docking arrangement scale",open:"displays"},
        {id:"s-power",title:"Battery & power",path:"Settings",icon:"battery_full",keywords:"profiles power sleep",open:"power"},
        {id:"s-style",title:"Wallpaper & style",path:"Settings",icon:"palette",keywords:"colours colors glass theme wallpaper icons",open:"appearance"},
        {id:"s-shelf",title:"Shelf",path:"Settings",icon:"dock_to_bottom",keywords:"taskbar bar alignment labels",open:"taskbar"},
        {id:"s-phone",title:"Phone & navigation",path:"Settings",icon:"smartphone",keywords:"gestures keyboard phone mode",open:"phone"},
        {id:"s-notes",title:"Notifications",path:"Settings",icon:"notifications",keywords:"inbox alerts popups",open:"notifications"},
        {id:"s-night",title:"Night light & schedules",path:"Settings",icon:"nightlight",keywords:"warm screen blue light schedule quiet hours",open:"schedules"},
        {id:"s-apptheme",title:"Theme for apps",path:"Settings",icon:"format_paint",keywords:"gtk qt kitty kvantum window borders",open:"apptheme"},
        {id:"s-profiles",title:"Profiles",path:"Settings",icon:"style",keywords:"setups save switch",open:"profiles"},
        {id:"s-a11y",title:"Accessibility",path:"Settings",icon:"accessibility_new",keywords:"motion readable contrast",open:"accessibility"},
        {id:"s-system",title:"Updates & health",path:"Settings",icon:"system_update",keywords:"updates storage temperatures disk",open:"system"},
        {id:"s-android",title:"Android (Waydroid)",path:"Settings › Apps & windows",icon:"android",keywords:"waydroid android apps apk play store",open:"apps"},
        {id:"s-setup",title:"Set up Opal again",path:"Settings › About",icon:"auto_awesome",keywords:"setup onboarding welcome tour first run",open:"about"},
        {id:"s-about",title:"About this device",path:"Settings",icon:"info",keywords:"system version hardware usage",open:"about"}
    ]
    readonly property var core: searching && !math ? Search.search(query, "all", Hub.appSearchIndex, Hub.windows, actions, Hub.favoriteApps.map(a => a.id), Hub.prefs.recent || []) : []
    readonly property var settingHits: searching && !math ? Model.settings(query, settingsIndex).map(x => Object.assign({}, x, {kind: "setting", key: "setting:" + x.id, detail: x.path})) : []
    readonly property var topSetting: settingHits.length && settingHits[0].score >= 580 && settingHits[0].get ? settingHits[0] : null
    readonly property var fileHits: {
        if (!searching || math || question) return [];
        const recent = (PhoneState.activity && PhoneState.activity.files || []).map(f => ({key: "file:" + f.path, title: f.title || "", detail: "Recent · " + (f.ago || String(f.folder || "").replace(/^\/home\/[^/]+/, "~")), icon: f.icon || "draft", path: f.path || "", kind: "file"}));
        const found = Hub.fileResults.query === query ? Hub.fileResults.items.map(f => ({key: "file:" + f.path, title: f.name, detail: f.folder, icon: f.dir ? "folder" : "draft", path: f.path, kind: "file"})) : [];
        const seen = {};
        return Model.rank(query, recent, 40).concat(Model.rank(query, found, 0)).filter(f => { if (seen[f.key] || !f.path) return false; seen[f.key] = true; return true; });
    }
    readonly property var gameHits: searching && !math ? Model.rank(query, (Hub.games || []).map(g => ({key: "game:" + g.id, title: g.title, detail: g.source || "Game", data: g, kind: "game"})), 0) : []
    readonly property var deviceHits: searching && !math ? Model.rank(query, (Hub.linkDevices || []).filter(d => d.reachable && d.session && d.session.app).map(d => {
        const app = Hub.appForClass(d.session.app);
        return {key: "device:" + d.id, title: (app ? app.name : d.session.app) + (d.session.title ? " · " + d.session.title : ""), detail: "Open on " + d.name, app: app, icon: "smartphone", kind: "device", keywords: d.name};
    }), 0) : []
    readonly property var built: Model.sections({
        app: core.filter(r => r.kind === "app"), window: core.filter(r => r.kind === "window"), action: core.filter(r => r.kind === "action"),
        setting: settingHits.filter(r => !topSetting || r.id !== topSetting.id), file: fileHits, game: gameHits, device: deviceHits
    }, query.length <= 2 ? 2 : touch ? 3 : 4, query.length <= 2 ? 7 : touch ? 9 : 12)
    readonly property var best: claude || conversion ? null : built.best
    readonly property var groups: built.sections
    readonly property var flat: (best ? [best] : []).concat(groups.reduce((all, g) => all.concat(g.items), [])).concat(searching && !math ? [{kind: "web", title: query, key: "web"}] : [])
    property int selection: 0
    readonly property var selected: flat[selection] || null
    onFlatChanged: selection = 0
    readonly property var frequent: {
        const list = Hub.recentApps.concat(Hub.favoriteApps), out = [];
        for (const a of list) if (a && out.indexOf(a) < 0) out.push(a);
        return out.slice(0, 5);
    }

    // Keep the chosen row inside the visible part of the list.
    function reveal(item) {
        if (!scroller.interactive) return;
        const p = item.mapToItem(layout, 0, 0);
        if (p.y < scroller.contentY) scroller.contentY = Math.max(0, p.y - 8);
        else if (p.y + item.height > scroller.contentY + scroller.height) scroller.contentY = p.y + item.height - scroller.height + 8;
    }
    function move(delta) { selection = Math.max(0, Math.min(flat.length - 1, selection + delta)); }
    function ask() { if (!searching || Hub.aiEnabled === false) return; askedFor = query; sendClaude(); }
    function sendClaude() { if (sentQuery === query || Hub.aiEnabled === false) return; sentQuery = query; Hub.askClaude(query); }
    function run(item, fresh) {
        if (!item) return;
        if (item.kind === "app") { if (fresh) Hub.launchNew(item.data); else Hub.launch(item.data); }
        else if (item.kind === "window") Hub.focusWindow(item.data);
        else if (item.kind === "web") { Hub.command({action: "web", text: query.replace(/^\?\s*/, "")}); Hub.close(); }
        else if (item.kind === "setting") { if (item.get) item.set(!item.get()); else Hub.openSettings(item.open); }
        else if (item.kind === "file") { Hub.command({action: "open-path", path: item.path}); Hub.close(); }
        else if (item.kind === "game") Hub.launchGame(item.data);
        else if (item.kind === "device") { if (item.app) Hub.launch(item.app); }
        else {
            const id = item.data.id;
            if (id === "screenshot") Hub.screenShot();
            else if (id === "capture") Hub.openCapture();
            else if (id === "record") { Hub.close(); if (Hub.recordingActive) Hub.command({action: "capture-record-stop"}); else Hub.openCapture(); }
            else if (id === "lock") Hub.settings(id);
            else if (id === "focus") { Hub.focusSeconds = 25 * 60; Hub.focusRunning = true; Hub.close(); }
            else if (id === "assistant") Hub.openAssistant("");
            else if (id === "settings") Hub.openSettings();
            else if (id === "android-store") Hub.openAndroid("store");
            else if (id === "android-setup") Hub.openAndroid("setup");
            else if (id === "setup") Hub.openOobe();
            else if (id === "workspaces") { Hub.close(); Hub.workspaceOverviewRequest(); }
            else if (id.startsWith("space:")) { Hub.close(); Spaces.open(Spaces.saved.find(sp => "space:" + sp.id === id)); }
            else Hub.page = id;
        }
    }
    function accept(fresh) {
        if (math) { if (Hub.calculation !== "") Hub.command({action: "clipboard", text: Hub.calculation}); return; }
        if (conversion) { Hub.command({action: "clipboard", text: String(Math.round(conversion.value * 1000) / 1000)}); return; }
        if (claude) { if (Hub.claudeAnswer !== "" || Hub.claudeBusy) Hub.openAssistant(query); else ask(); return; }
        run(selected, fresh);
    }
    function icon(item) {
        if (!item) return "search";
        if (item.kind === "web") return "language";
        if (item.kind === "window") return "desktop_windows";
        if (item.kind === "game") return "sports_esports";
        return item.icon || "search";
    }

    Connections {
        target: Hub
        function onStartSearchRequestChanged() { if (s.ownField) field.forceActiveFocus(); }
        function onQueryChanged() {
            if (s.ownField && field.text !== Hub.query) field.text = Hub.query;
            Hub.calculation = "";
            calc.stop(); files.stop(); claudeTimer.stop();
            if (s.math) calc.restart();
            else if (s.query.length >= 2 && !s.question) files.restart();
            if (s.question) claudeTimer.restart();
        }
    }
    Timer { id: calc; interval: 120; onTriggered: if (s.math) Hub.command({action: "calculate", text: Hub.calcExpression(s.query)}) }
    Timer { id: files; interval: 260; onTriggered: if (s.searching && !s.math) Hub.command({action: "file-search", text: s.query}) }
    // A question waits for a pause in typing before it goes to Claude.
    Timer { id: claudeTimer; interval: 800; onTriggered: if (s.question) s.sendClaude() }
    Component.onCompleted: { PhoneState.refreshActivity(); if (ownField) field.forceActiveFocus(); }
    Keys.onEscapePressed: event => { if (s.searching) Hub.query = ""; else Hub.close(); event.accepted = true; }

    Rectangle {
        id: fieldBox
        visible: s.ownField
        x: s.inset; y: s.inset; width: s.width - s.inset * 2; height: s.ownField ? (s.touch ? 60 : 56) : 0; radius: height / 2
            color: Theme.level(3)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 8; spacing: 12
                Glyph { name: "search"; font.pixelSize: 22; color: Theme.text }
                TextField {
                    id: field
                    Layout.fillWidth: true; Layout.fillHeight: true
                    background: Item {}
                    leftPadding: 0; rightPadding: 0
                    color: Theme.text; placeholderTextColor: Theme.subtext
                    font.family: Theme.font; font.pixelSize: 16; selectByMouse: true
                    placeholderText: s.placeholder
                    text: Hub.query
                    onTextEdited: Hub.query = text
                    Keys.onReturnPressed: event => s.accept(!!(event.modifiers & Qt.ControlModifier))
                    Keys.onEnterPressed: event => s.accept(!!(event.modifiers & Qt.ControlModifier))
                    Keys.onDownPressed: s.move(1)
                    Keys.onUpPressed: s.move(-1)
                    Keys.onTabPressed: s.ask()
                }
                MButton { visible: s.searching; icon: "close"; compact: true; implicitWidth: 38; implicitHeight: 38; tooltip: "Clear"; onClicked: { Hub.query = ""; field.forceActiveFocus(); } }
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
                    color: sparkMouse.containsMouse ? Theme.mix(Theme.tertiaryContainer, Theme.onTertiaryContainer, .1) : Theme.tertiaryContainer
                    Glyph { anchors.centerIn: parent; name: "auto_awesome"; font.pixelSize: 20; color: Theme.onTertiaryContainer }
                    MouseArea { id: sparkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.searching ? s.ask() : Hub.openAssistant("") }
                    Accessible.role: Accessible.Button; Accessible.name: "Ask Claude"
                }
            }
        }

    Flickable {
        id: scroller
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: fieldBox.bottom; topMargin: s.ownField ? 12 : 0 }
        clip: true; contentHeight: layout.implicitHeight + s.inset * (s.ownField ? 1 : 2); boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: scroller.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
    ColumnLayout {
        id: layout
        x: s.inset; y: s.ownField ? 0 : s.inset; width: scroller.width - s.inset * 2
        spacing: 12
        // Idle: five frequent apps and the suggestion pills. Nothing else.
        RowLayout {
            visible: !s.searching && s.frequent.length > 0
            Layout.fillWidth: true; spacing: 0
            Repeater {
                model: s.frequent
                Rectangle {
                    id: cell
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: s.touch ? 96 : 88; radius: 20
                    color: cellMouse.containsMouse ? Theme.alpha(Theme.stateLayer, .07) : "transparent"
                    Column {
                        anchors.centerIn: parent; spacing: 6; width: parent.width - 8
                        AppIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 48; height: 48; app: cell.modelData; style: "raw" }
                        MText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cell.modelData.name; role: "label" }
                    }
                    MouseArea { id: cellMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Hub.launch(cell.modelData) }
                    Accessible.role: Accessible.Button; Accessible.name: cell.modelData.name
                }
            }
        }
        Flow {
            visible: !s.searching && Activities.chips.length > 0
            Layout.fillWidth: true; Layout.leftMargin: 4; spacing: 8
            Repeater {
                model: Activities.chips
                ActivityChip { required property var modelData; a: ({kind: modelData.kind === "continue" ? "device" : "neutral", icon: modelData.icon, short: modelData.label, title: modelData.label}); onClicked: Activities.runChip(modelData) }
            }
        }

        // Answers: arithmetic, unit conversion and one setting with its own switch.
        Rectangle {
            visible: s.math || s.conversion !== null
            Layout.fillWidth: true; Layout.preferredHeight: 100; radius: 24; color: Theme.primaryContainer
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 2
                MText { text: s.math ? Hub.calcExpression(s.query) + " =" : s.conversion ? s.conversion.from + " =" : ""; role: "bodyS"; color: Theme.alpha(Theme.onContainer, .75) }
                RowLayout {
                    Layout.fillWidth: true
                    MText { Layout.fillWidth: true; text: s.math ? (Hub.calculation || "…") : s.conversion ? s.conversion.text : ""; font.pixelSize: 32; font.weight: Font.Medium; color: Theme.onContainer }
                    MButton { text: "Copy"; icon: "copy"; compact: true; filled: true; accent: Theme.onContainer; fillInk: Theme.primaryContainer; enabled: !s.math || Hub.calculation !== ""; onClicked: s.accept(false) }
                }
            }
        }
        Rectangle {
            id: settingCard
            visible: s.topSetting !== null && !s.claude
            Layout.fillWidth: true; Layout.preferredHeight: 72; radius: 24; color: Theme.secondaryContainer
            readonly property bool on: s.topSetting ? s.topSetting.get() : false
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 18; spacing: 14
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20; color: Theme.alpha(Theme.onSecondaryContainer, .13)
                    Glyph { anchors.centerIn: parent; name: s.topSetting ? s.topSetting.icon : "tune"; font.pixelSize: 22; color: Theme.onSecondaryContainer }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    MText { Layout.fillWidth: true; text: s.topSetting ? s.topSetting.title : ""; role: "titleS"; color: Theme.onSecondaryContainer }
                    MText { Layout.fillWidth: true; text: s.topSetting ? s.topSetting.path : ""; role: "labelS"; color: Theme.alpha(Theme.onSecondaryContainer, .75) }
                }
                MButton { icon: "open_in_new"; compact: true; implicitWidth: 36; implicitHeight: 36; ink: Theme.onSecondaryContainer; tooltip: "Open in Settings"; onClicked: Hub.openSettings(s.topSetting.open) }
                MSwitch { checked: settingCard.on; onToggled: v => s.topSetting.set(v) }
            }
        }

        // Claude answers inline; the panel continues the conversation.
        Rectangle {
            visible: s.claude
            Layout.fillWidth: true; Layout.preferredHeight: claudeCol.implicitHeight + 32; radius: 26; color: Theme.tertiaryContainer
            ColumnLayout {
                id: claudeCol
                x: 18; y: 16; width: parent.width - 36; spacing: 12
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Glyph { name: "auto_awesome"; font.pixelSize: 20; color: Theme.onTertiaryContainer }
                    MText { Layout.fillWidth: true; text: "Claude"; role: "titleS"; color: Theme.onTertiaryContainer }
                    MText { visible: s.sentQuery !== s.query && !Hub.claudeBusy; text: "Tab or Enter to ask"; role: "labelS"; color: Theme.alpha(Theme.onTertiaryContainer, .7) }
                }
                LinearProgress { visible: Hub.claudeBusy && Hub.claudeAnswer === ""; Layout.fillWidth: true; value: -1; ink: Theme.onTertiaryContainer }
                Text {
                    visible: Hub.claudeAnswer !== "" && s.sentQuery === s.query
                    Layout.fillWidth: true; Layout.maximumHeight: s.touch ? 220 : 180; clip: true
                    text: Hub.claudeAnswer; textFormat: Text.MarkdownText; wrapMode: Text.Wrap
                    color: Theme.onTertiaryContainer; font.family: Theme.font; font.pixelSize: 14; lineHeight: 1.15
                    onLinkActivated: link => Hub.command({action: "web-open", url: link})
                }
                Row {
                    Layout.alignment: Qt.AlignRight; spacing: 8
                    MButton { visible: Hub.claudeBusy; text: "Stop"; icon: "stop"; compact: true; ink: Theme.onTertiaryContainer; onClicked: Hub.stopClaude() }
                    MButton { visible: !Hub.claudeBusy && Hub.claudeAnswer !== ""; text: "Copy"; icon: "copy"; compact: true; ink: Theme.onTertiaryContainer; onClicked: Hub.command({action: "clipboard", text: Hub.claudeAnswer}) }
                    MButton { text: s.sentQuery === s.query ? "Continue in panel" : "Ask in panel"; icon: "forum"; compact: true; filled: true; accent: Theme.onTertiaryContainer; fillInk: Theme.tertiaryContainer; onClicked: Hub.openAssistant(s.query) }
                }
            }
        }

        // Best match: large, with its action spelled out.
        Rectangle {
            visible: !!s.best && !s.math
            Layout.fillWidth: true; Layout.preferredHeight: s.touch ? 80 : 72; radius: 24
            color: s.selection === 0 ? Theme.secondaryContainer : Theme.level(2)
            Behavior on color { ColorAnimation { duration: Theme.motion(120) } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 14
                ResultIcon { item: s.best; size: 44 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    MText { Layout.fillWidth: true; text: s.best ? s.best.title || "" : ""; role: "titleS"; font.pixelSize: 16; color: s.selection === 0 ? Theme.onSecondaryContainer : Theme.text }
                    MText { Layout.fillWidth: true; text: s.best ? s.best.detail || "" : ""; role: "labelS"; color: Theme.subtext }
                }
                MButton { text: s.best && s.best.kind === "window" ? "Switch" : s.best && s.best.kind === "setting" ? (s.best.get ? (s.best.get() ? "Turn off" : "Turn on") : "Open") : "Open"; compact: true; filled: true; onClicked: s.run(s.best, false) }
            }
            MouseArea { anchors.fill: parent; z: -1; hoverEnabled: true; onEntered: s.selection = 0; onClicked: s.run(s.best, false) }
        }

        Repeater {
            model: s.math ? [] : s.groups
            ColumnLayout {
                id: group
                required property var modelData
                Layout.fillWidth: true; spacing: 2
                MText { text: group.modelData.title; role: "labelS"; font.letterSpacing: 1; color: Theme.primary; Layout.leftMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 2 }
                Repeater { model: group.modelData.items; ResultRow { required property var modelData; item: modelData } }
            }
        }
        ResultRow { visible: s.searching && !s.math; item: s.flat.length ? s.flat[s.flat.length - 1] : null; web: true }
        MText {
            visible: s.searching && !s.math && !s.touch; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
            text: Hub.aiEnabled !== false ? "↑↓ choose   ·   Enter open   ·   Tab ask Claude   ·   Esc clear" : "↑↓ choose   ·   Enter open   ·   Esc clear"; role: "labelS"; color: Theme.subtext
        }
    }
    }

    component ResultIcon: Item {
        property var item: null
        property real size: 32
        Layout.preferredWidth: size; Layout.preferredHeight: size
        AppIcon { anchors.fill: parent; visible: !!parent.item && (parent.item.kind === "app" || (parent.item.kind === "device" && !!parent.item.app)); style: "raw"; app: parent.item ? (parent.item.kind === "app" ? parent.item.data : parent.item.app || null) : null }
        Glyph {
            anchors.centerIn: parent
            visible: !parent.item || (parent.item.kind !== "app" && !(parent.item.kind === "device" && !!parent.item.app))
            name: s.icon(parent.item); font.pixelSize: parent.size * .66; color: Theme.primary
        }
    }
    component ResultRow: Rectangle {
        id: row
        property var item: null
        property bool web: false
        readonly property int order: s.flat.indexOf(item)
        readonly property bool current: order >= 0 && order === s.selection
        onCurrentChanged: if (current) s.reveal(row)
        Layout.fillWidth: true; Layout.preferredHeight: s.touch ? 60 : 50; radius: 16
        color: current ? Theme.secondaryContainer : rowMouse.containsMouse ? Theme.alpha(Theme.stateLayer, .06) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motion(100) } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 12; spacing: 14
            ResultIcon { item: row.item; size: 30 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                MText { Layout.fillWidth: true; text: !row.item ? "" : row.web ? "Search the web for “" + s.query + "”" : row.item.title || ""; role: "titleS"; font.weight: Font.Medium; color: row.current ? Theme.onSecondaryContainer : Theme.text }
                MText { Layout.fillWidth: true; visible: !row.web && !!row.item && !!row.item.detail; text: row.item ? row.item.detail || "" : ""; role: "labelS"; color: Theme.subtext }
            }
            MSwitch { visible: !!row.item && row.item.kind === "setting" && !!row.item.get; checked: !!row.item && !!row.item.get && row.item.get(); onToggled: v => row.item.set(v) }
            Glyph { visible: row.current && !(row.item && row.item.kind === "setting" && row.item.get); name: row.web ? "open_in_new" : "keyboard_return"; font.pixelSize: 16; color: Theme.onSecondaryContainer }
        }
        MouseArea { id: rowMouse; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: if (row.order >= 0) s.selection = row.order; onClicked: s.run(row.item, false) }
        Accessible.role: Accessible.Button
        Accessible.name: row.item ? (row.web ? "Search the web for " + s.query : row.item.title) : ""
    }
}
