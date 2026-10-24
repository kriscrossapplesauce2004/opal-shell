import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
// Pages of the switch assistant: this computer, what comes along, a few choices, then the switch itself. switch.qml is the window and the engine pipe.
Item {
    id: root
    focus: true
    signal send(var cmd)
    signal quit()
    readonly property bool narrow: width < 860
    // Engine state, fed by handle().
    property var checks: null
    property string phase: "checking"
    property var stages: []
    property var log: []
    property string error: ""
    property string message: ""
    property bool showLog: false
    // Choices sent with the switch.
    property bool importLook: true
    property bool importPins: true
    property bool importKeyboard: true
    property string windows: "floating"
    property bool ai: true
    property bool fonts: true
    readonly property var steps: [
        {id: "hello", label: "This computer", icon: "computer", shape: 1},
        {id: "bring", label: "Bring along", icon: "move_item", shape: 5},
        {id: "choose", label: "Choices", icon: "tune", shape: 3},
        {id: "go", label: "Switch", icon: "rocket_launch", shape: 8}
    ]
    property int step: 0
    property int direction: 1
    readonly property var cur: steps[step]
    readonly property var found: checks ? checks.found || {} : {}
    readonly property string desktop: checks && checks.desktop ? checks.desktop : "your desktop"
    readonly property bool blocked: !checks || (checks.problems || []).length > 0
    readonly property bool busy: phase === "running" || phase === "undoing"

    function go(next) {
        if (busy || next < 0 || next >= steps.length || next === step) return;
        direction = next > step ? 1 : -1;
        step = next;
    }
    function next() { if (step < steps.length - 1 && !(step === 0 && blocked)) go(step + 1); }
    function back() { go(step - 1); }
    function detect() { phase = "checking"; error = ""; send({action: "detect"}); }
    function start() {
        error = ""; message = ""; log = []; stages = []; phase = "running";
        send({action: "switch", options: {importLook: importLook, importPins: importPins, importKeyboard: importKeyboard, windows: windows, ai: ai, fonts: fonts, mode: "auto"}});
    }
    function undo() { error = ""; log = []; stages = []; phase = "undoing"; go(steps.length - 1); send({action: "undo"}); }
    function cancel() { send({action: "cancel"}); }
    function close() { if (busy) cancel(); quit(); }
    // One engine event: detect, plan, stage, log, error, message or done.
    function handle(e) {
        if (!e || typeof e !== "object") return;
        if (e.event === "detect") { checks = e.data; phase = "ready"; wear(); }
        else if (e.event === "plan") stages = e.stages || [];
        else if (e.event === "stage") stages = stages.map(s => s.id === e.id ? Object.assign({}, s, e) : s);
        else if (e.event === "log") log = log.concat([e.text]).slice(-400);
        else if (e.event === "error") error = e.text || "";
        else if (e.event === "message") message = e.text || "";
        else if (e.event === "done") phase = phase === "undoing" ? (e.ok ? "undone" : "failed") : e.cancelled ? "ready" : e.ok ? "done" : "failed";
    }
    // The assistant wears the old desktop's light or dark theme and accent, so the first look at Opal already feels familiar.
    function wear() {
        const f = found, p = {};
        if (importLook && f.light !== undefined) p.light = f.light;
        if (importLook && f.palette !== undefined) { p.palette = f.palette; p.dynamicColors = false; }
        if (Object.keys(p).length) Hub.prefs = Object.assign({}, Hub.prefs, p);
    }
    onImportLookChanged: if (importLook) wear()
    // The same plan the engine makes, shown before the switch starts.
    readonly property var planned: {
        if (!checks) return [];
        const s = [];
        if ((checks.missing || []).length) s.push({id: "packages", title: "Install Hyprland, Quickshell and helpers", icon: "package_2", root: true});
        if (!checks.sessionInstalled) s.push({id: "session", title: "Add Opal to the login screen", icon: "login", root: true});
        if (fonts && Object.values(checks.fonts || {}).some(v => !v)) s.push({id: "fonts", title: "Get the Opal fonts", icon: "font_download"});
        if (!checks.hyprConfig) s.push({id: "hyprland", title: "Write a Hyprland setup", icon: "settings_applications"});
        s.push({id: "opal", title: "Install Opal", icon: "download"});
        s.push({id: "settings", title: "Bring your desktop along", icon: "move_item"});
        return s;
    }
    readonly property bool needsPassword: planned.some(s => s.root)
    readonly property var checkRows: {
        const c = checks, r = [];
        if (!c) return r;
        const have = c.have || {}, avail = c.available || {};
        r.push({s: "ok", i: "desktop_windows", t: (c.desktop || "Your desktop") + " stays installed", d: "Pick it or Opal on the login screen, any time"});
        r.push(have.hyprland ? {s: "ok", i: "window", t: "Hyprland " + (c.hyprVersion || "is installed"), d: "Opal runs on it"}
             : avail.hyprland === false ? {s: "fail", i: "window", t: "No Hyprland package", d: "Your distribution doesn't ship Hyprland"}
             : {s: "info", i: "window", t: "Hyprland will be installed", d: "The compositor Opal runs on, from your " + (c.manager || "system") + " repositories"});
        r.push(have.quickshell ? {s: "ok", i: "widgets", t: "Quickshell is installed", d: "Opal is drawn with it"}
             : avail.quickshell === false ? {s: "fail", i: "widgets", t: "No Quickshell package", d: "Build it from quickshell.org first"}
             : {s: "info", i: "widgets", t: "Quickshell will be installed", d: avail.quickshell === "copr" ? "From the Quickshell COPR, which Opal turns on" : "Opal is drawn with it"});
        const helpers = (c.missing || []).filter(m => m !== "hyprland" && m !== "quickshell");
        if (helpers.length) r.push({s: "info", i: "build", t: helpers.length + " helpers will be installed", d: helpers.slice(0, 6).join(", ") + (helpers.length > 6 ? "…" : "")});
        r.push(c.sessionInstalled ? {s: "ok", i: "login", t: "Opal is on the login screen", d: c.dm || "Your login screen"}
             : {s: "info", i: "login", t: "Opal will be added to " + (c.dm || "the login screen"), d: "Next to " + (c.desktop || "your desktop")});
        if (Object.values(c.fonts || {}).some(v => !v)) r.push({s: "info", i: "font_download", t: "Opal's fonts will be downloaded", d: "Google Sans Flex and Material Symbols, into your home folder"});
        r.push(c.hyprConfig ? {s: "ok", i: "description", t: "Your hyprland.lua stays as it is", d: "Opal adds a small hook you can remove"}
             : {s: "info", i: "description", t: "A Hyprland setup will be written", d: "From Hyprland's own example, with your terminal and keyboard"});
        (c.warnings || []).forEach(w => r.push({s: "warn", i: "warning", t: w, d: ""}));
        (c.problems || []).forEach(p => r.push({s: "fail", i: "error", t: p, d: ""}));
        return r;
    }
    function appIcon(id) {
        const e = DesktopEntries.heuristicLookup(id);
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }
    function appName(id) { const e = DesktopEntries.heuristicLookup(id); return e ? e.name : id; }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape) { back(); e.accepted = true; }
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && step < steps.length - 1) { next(); e.accepted = true; }
    }
    Component.onCompleted: forceActiveFocus()

    // ---------- backdrop ----------
    Image {
        id: wall
        anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
        source: root.importLook && root.found.wallpaper ? "file://" + root.found.wallpaper : ""; sourceSize: Qt.size(width / 4, height / 4)
        visible: false
    }
    MultiEffect { anchors.fill: parent; source: wall; visible: wall.status === Image.Ready; blurEnabled: true; blur: 1; blurMax: 64; saturation: .1; opacity: .5 }
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.base, wall.status === Image.Ready ? .66 : 1) }
    MorphShape {
        width: Math.max(root.width, root.height) * .6; height: width
        x: root.narrow ? root.width - width * .5 : root.width * .6
        y: root.narrow ? -height * .5 : root.height * .4
        shape: root.phase === "done" ? 0 : root.cur.shape
        fill: Theme.alpha(Theme.primaryContainer, .5); fill2: Theme.alpha(Theme.mix(Theme.primaryContainer, Theme.tertiary, .4), .3)
        spinMs: 60000
    }

    // ---------- top: brand, steps, close ----------
    RowLayout {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.narrow ? 16 : 24 }
        height: 44; spacing: 12
        RowLayout { spacing: 10; Layout.preferredWidth: root.narrow ? -1 : 200
            MorphShape { Layout.preferredWidth: 30; Layout.preferredHeight: 30; shape: 8; fill: Theme.primary; spinMs: 14000 }
            MText { visible: !root.narrow; text: "Switch to Opal"; role: "title" }
            Item { Layout.fillWidth: true } }
        Item { Layout.fillWidth: true }
        Row {
            spacing: 6
            Repeater { model: root.steps
                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.step
                    readonly property bool done: index < root.step || root.phase === "done"
                    readonly property bool dot: root.narrow && !current
                    anchors.verticalCenter: parent.verticalCenter
                    height: dot ? 10 : 36; radius: height / 2
                    width: current ? chipRow.implicitWidth + 28 : dot ? 10 : 36
                    color: current ? Theme.primaryContainer : done ? Theme.primary : Theme.alpha(Theme.level(3), .9)
                    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durLong); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
                    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durMedium) } }
                    clip: true
                    Row { id: chipRow; anchors.centerIn: parent; spacing: 6; visible: !chip.dot
                        Glyph { name: chip.done && !chip.current ? "check" : chip.modelData.icon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                            color: chip.current ? Theme.onContainer : chip.done ? Theme.onPrimary : Theme.subtext }
                        MText { visible: chip.current; text: chip.modelData.label; role: "label"; color: Theme.onContainer; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; enabled: chip.index < root.step && !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.go(chip.index) }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.label
                }
            }
        }
        Item { Layout.fillWidth: true }
        Item { Layout.preferredWidth: root.narrow ? 40 : 200; Layout.preferredHeight: 40
            MButton { anchors.right: parent.right; icon: "close"; tooltip: root.busy ? "Stop and close" : "Close"; compact: true; onClicked: root.close() } }
    }

    // ---------- pages ----------
    Item {
        id: stage
        anchors { left: parent.left; right: parent.right; top: topBar.bottom; bottom: bottomBar.top; leftMargin: root.narrow ? 16 : 64; rightMargin: root.narrow ? 16 : 64; topMargin: 12; bottomMargin: 12 }
        Loader {
            id: page
            width: parent.width; height: parent.height
            property real slide: 0
            x: slide * 70 * root.direction; opacity: 1 - Math.abs(slide)
            sourceComponent: root.phase === "checking" ? checkingPage : ({hello: helloPage, bring: bringPage, choose: choosePage, go: goPage})[root.cur.id]
            onLoaded: enter.restart()
            NumberAnimation { id: enter; target: page; property: "slide"; from: 1; to: 0; duration: Theme.motion(520); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate }
        }
    }

    // ---------- bottom: back, next ----------
    RowLayout {
        id: bottomBar
        visible: root.cur.id !== "go" && root.phase !== "checking"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: root.narrow ? 16 : 24 }
        height: visible ? 56 : 0
        MButton { visible: root.step > 0; text: "Back"; icon: "back"; onClicked: root.back() }
        MButton { visible: root.step === 0; text: "Check again"; icon: "refresh"; onClicked: root.detect() }
        Item { Layout.fillWidth: true }
        MButton { text: "Next"; trailingIcon: "arrow_forward"; filled: true; enabled: !(root.step === 0 && root.blocked); implicitHeight: 52; Layout.minimumWidth: 140; onClicked: root.next() }
    }

    // ---------- shared pieces ----------
    component StepLayout: GridLayout {
        id: sl
        property string icon
        property string title
        property string body
        default property alias content: panel.data
        property real panelWidth: .58
        columns: root.narrow ? 1 : 2; columnSpacing: 56; rowSpacing: 18
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: !root.narrow; Layout.preferredWidth: root.narrow ? -1 : sl.width * (1 - sl.panelWidth)
            Layout.alignment: Qt.AlignTop; spacing: 14
            Item { Layout.fillHeight: true; visible: !root.narrow }
            Rectangle { Layout.preferredWidth: root.narrow ? 52 : 68; Layout.preferredHeight: Layout.preferredWidth; radius: Layout.preferredWidth * .36; color: Theme.primary
                Glyph { anchors.centerIn: parent; name: sl.icon; font.pixelSize: parent.width * .52; color: Theme.onPrimary } }
            MText { Layout.fillWidth: true; text: sl.title; role: root.narrow ? "headline" : "displayS"; wrapMode: Text.Wrap; font.pixelSize: root.narrow ? 28 : 40 }
            MText { Layout.fillWidth: true; text: sl.body; role: "body"; font.pixelSize: root.narrow ? 14 : 16; color: Theme.subtext; wrapMode: Text.Wrap; lineHeight: 1.15 }
            Item { Layout.fillHeight: true; visible: !root.narrow }
            Item { Layout.preferredHeight: root.narrow ? 0 : 56 }
        }
        Item { id: panel; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: root.narrow ? -1 : sl.width * sl.panelWidth }
    }
    component Card: Surface {
        kind: "panels"; radius: Theme.shapeXl; level: 2; translucency: .92
        border.width: Theme.edges && !Theme.solid("panels") ? 1 : 0; border.color: Theme.glassEdge
    }
    component SectionLabel: MText { role: "titleS"; color: Theme.primary }
    component CheckRow: RowLayout {
        property var row
        spacing: 12
        Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; Layout.alignment: Qt.AlignTop; radius: 18
            color: row.s === "ok" ? Theme.primaryContainer : row.s === "fail" ? Theme.alpha(Theme.error, .18) : row.s === "warn" ? Theme.alpha(Theme.tertiary, .24) : Theme.level(4)
            Glyph { anchors.centerIn: parent; name: row.s === "ok" ? "check" : row.s === "fail" ? "close" : row.i; font.pixelSize: 19
                color: row.s === "ok" ? Theme.onContainer : row.s === "fail" ? Theme.error : row.s === "warn" ? Theme.tertiary : Theme.text } }
        ColumnLayout { Layout.fillWidth: true; spacing: 0
            MText { Layout.fillWidth: true; text: row.t; role: "titleS"; wrapMode: Text.Wrap; color: row.s === "fail" ? Theme.error : Theme.text }
            MText { Layout.fillWidth: true; visible: text !== ""; text: row.d; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } }
    }
    component PickCard: Rectangle {
        id: pc
        property string title
        property string detail
        property bool chosen
        default property alias art: artBox.data
        signal picked()
        radius: Theme.shapeLg
        color: chosen ? Theme.primaryContainer : Theme.level(3)
        Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: pcMouse.pressed ? .12 : pcMouse.containsMouse ? .06 : 0 }
        Rectangle { anchors.fill: parent; anchors.margins: -4; radius: parent.radius + 4; color: "transparent"; border.width: 2; border.color: Theme.primary; visible: pc.chosen }
        ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 6
            Item { id: artBox; Layout.fillWidth: true; Layout.fillHeight: true }
            MText { Layout.fillWidth: true; text: pc.title; role: "titleS"; color: pc.chosen ? Theme.onContainer : Theme.text }
            MText { Layout.fillWidth: true; visible: text !== ""; text: pc.detail; role: "bodyS"; color: pc.chosen ? Theme.alpha(Theme.onContainer, .8) : Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 2 } }
        MouseArea { id: pcMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pc.picked() }
        Accessible.role: Accessible.RadioButton; Accessible.name: title; Accessible.checked: chosen
    }
    component BringRow: Rectangle {
        id: br
        property string icon
        property string title
        property string detail
        property bool checked
        property bool available: true
        default property alias extra: extraBox.data
        signal toggled(bool value)
        Layout.fillWidth: true; implicitHeight: brCol.implicitHeight + 28; radius: Theme.shapeLg
        color: checked && available ? Theme.level(3) : Theme.alpha(Theme.level(3), .5)
        opacity: available ? 1 : .6
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: brMouse.pressed ? .1 : brMouse.containsMouse ? .05 : 0 }
        MouseArea { id: brMouse; anchors.fill: parent; enabled: br.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: br.toggled(!br.checked) }
        ColumnLayout { id: brCol; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 } spacing: 10
            RowLayout { Layout.fillWidth: true; spacing: 14
                Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 14; color: br.checked && br.available ? Theme.primaryContainer : Theme.level(4)
                    Glyph { anchors.centerIn: parent; name: br.icon; font.pixelSize: 21; color: br.checked && br.available ? Theme.onContainer : Theme.subtext } }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                    MText { Layout.fillWidth: true; text: br.title; role: "titleS" }
                    MText { Layout.fillWidth: true; text: br.detail; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight } }
                MSwitch { visible: br.available; checked: br.checked; onToggled: v => br.toggled(v) } }
            Item { id: extraBox; Layout.fillWidth: true; Layout.leftMargin: 54; implicitHeight: childrenRect.height; visible: children.length > 0 && br.checked && br.available }
        }
    }

    // ---------- checking ----------
    Component { id: checkingPage; ColumnLayout {
        Item { Layout.fillHeight: true }
        LoadingIndicator { Layout.alignment: Qt.AlignHCenter; contained: true; implicitWidth: 72; implicitHeight: 72 }
        MText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 14; text: "Looking at this computer…"; role: "headline" }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Your desktop, packages, login screen and graphics"; role: "body"; color: Theme.subtext }
        Item { Layout.fillHeight: true } } }

    // ---------- 0 this computer ----------
    Component { id: helloPage; StepLayout {
        icon: "computer"; title: root.checks && root.checks.desktop ? "Coming from " + root.checks.desktop : "Switch to Opal"
        body: "This assistant installs Opal next to " + root.desktop + ", brings your wallpaper, theme and pinned apps along, and adds Opal to your login screen. Nothing is removed, and you can undo it."
        Card {
            anchors.fill: parent
            Flickable {
                anchors.fill: parent; anchors.margins: 22; contentHeight: checkCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout { id: checkCol; width: parent.width - 8; spacing: 14
                    Flow { Layout.fillWidth: true; spacing: 8
                        Repeater { model: [root.checks.distro.name, root.checks.session === "wayland" ? "Wayland" : root.checks.session === "x11" ? "X11" : "", root.checks.arch,
                                           root.checks.gpu.nvidia ? (root.checks.gpu.other ? "Hybrid graphics" : "NVIDIA") : "AMD or Intel graphics"].filter(t => !!t)
                            Rectangle { required property string modelData; implicitHeight: 30; implicitWidth: ct.implicitWidth + 24; radius: 15; color: Theme.secondaryContainer
                                MText { id: ct; anchors.centerIn: parent; text: modelData; role: "label"; color: Theme.onSecondaryContainer } } } }
                    Repeater { model: root.checkRows; CheckRow { required property var modelData; row: modelData; Layout.fillWidth: true } }
                    // Already switched: the same window takes it back out.
                    Rectangle { visible: root.checks.sessionInstalled; Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: undoRow.implicitHeight + 28; radius: Theme.shapeLg; color: Theme.level(3)
                        RowLayout { id: undoRow; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 } spacing: 14
                            Glyph { name: "undo"; font.pixelSize: 24; color: Theme.primary }
                            ColumnLayout { Layout.fillWidth: true; spacing: 0
                                MText { Layout.fillWidth: true; text: "Opal is already here"; role: "titleS" }
                                MText { Layout.fillWidth: true; text: "Run the switch again to update it, or take Opal off the login screen and put your settings back."; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } }
                            MButton { text: "Undo the switch"; tonal: true; onClicked: root.undo() } } }
                }
            }
        }
    } }

    // ---------- 1 bring along ----------
    Component { id: bringPage; StepLayout {
        icon: "move_item"; title: "Bring " + root.desktop + " along"
        body: Object.keys(root.found).length ? "Opal found these in " + root.desktop + ". Keep what you like. The setup screen still opens at your first login, with these already picked."
            : "Opal found nothing to bring from " + root.desktop + ", so it starts with its own look. The setup screen helps you make it yours at your first login."
        Flickable {
            anchors.fill: parent; contentHeight: Math.max(height, bringCol.implicitHeight); clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: bringCol; y: Math.max(0, (parent.parent.height - implicitHeight) / 2); width: parent.width - 10; spacing: 12
                // Preview: the old wallpaper with an Opal bar holding the old pins.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: Math.min(260, width * .45); radius: Theme.shapeXl; clip: true; color: Theme.level(1)
                    Image { anchors.fill: parent; visible: root.importLook; source: root.found.wallpaper ? "file://" + root.found.wallpaper : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 900 }
                    MorphShape { visible: !root.importLook || !root.found.wallpaper; anchors.centerIn: parent; width: parent.height * 1.1; height: width; shape: 5; fill: Theme.primaryContainer; fill2: Theme.mix(Theme.primaryContainer, Theme.tertiary, .4) }
                    Surface { kind: "bars"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; height: 46; radius: 23; level: 3; translucency: .8
                        width: Math.min(parent.width - 28, pinRow.implicitWidth + 28)
                        border.width: Theme.edges ? 1 : 0; border.color: Theme.glassEdge
                        Row { id: pinRow; anchors.centerIn: parent; spacing: 8
                            Rectangle { width: 30; height: 30; radius: 11; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                                Glyph { anchors.centerIn: parent; name: "apps"; font.pixelSize: 18; color: Theme.onPrimary } }
                            Repeater { model: root.importPins ? (root.found.pins || []).slice(0, 8) : []
                                Item { required property string modelData; width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter
                                    Image { id: pinIcon; anchors.fill: parent; source: root.appIcon(modelData); sourceSize: Qt.size(60, 60); asynchronous: true }
                                    Rectangle { anchors.fill: parent; radius: 15; visible: pinIcon.status !== Image.Ready; color: Theme.alpha(Theme.text, .2) } } }
                            Repeater { model: root.importPins && (root.found.pins || []).length ? 0 : 4
                                Rectangle { width: 30; height: 30; radius: 15; anchors.verticalCenter: parent.verticalCenter; color: Theme.alpha(Theme.text, .18) } } } }
                    Surface { kind: "widgets"; x: 16; y: 16; width: clockText.implicitWidth + 32; height: 56; radius: 22; level: 2; translucency: .8
                        border.width: Theme.edges ? 1 : 0; border.color: Theme.glassEdge
                        MText { id: clockText; anchors.centerIn: parent; text: Qt.formatTime(new Date(), root.found.clock24 === false ? "h:mm AP" : "hh:mm"); role: "headline" } }
                }
                BringRow {
                    icon: "palette"; title: "Wallpaper and theme"; checked: root.importLook; onToggled: v => root.importLook = v
                    available: !!root.found.wallpaper || root.found.light !== undefined || root.found.palette !== undefined
                    detail: available ? [root.found.wallpaper ? root.found.wallpaper.split("/").pop() : "", root.found.light === undefined ? "" : root.found.light ? "Light" : "Dark",
                                         root.found.palette === undefined ? "" : Theme.palettes[root.found.palette].name + " colours" + (root.found.accent ? " from your " + (root.found.accent.charAt(0) === "#" ? "" : root.found.accent + " ") + "accent" : "")].filter(t => !!t).join(" · ")
                        : "Nothing found"
                    Row { spacing: 8
                        Repeater { model: root.found.palette === undefined ? [] : [Theme.palettes[root.found.palette]]
                            Rectangle { required property var modelData; width: 28; height: 28; radius: 14; color: modelData.seed
                                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 14; height: 14; radius: 7; color: modelData.primary; border.width: 2; border.color: Theme.level(3) } } }
                        Rectangle { visible: !!root.found.accent && root.found.accent.charAt(0) === "#"; width: 28; height: 28; radius: 14; color: root.found.accent || "transparent" } }
                }
                BringRow {
                    icon: "keep"; title: "Pinned apps"; checked: root.importPins; onToggled: v => root.importPins = v
                    available: (root.found.pins || []).length > 0
                    detail: available ? root.found.pins.length + " apps on your " + (root.desktop === "KDE Plasma" ? "taskbar" : "dock") + ", pinned to Opal's bar" : "Nothing pinned in " + root.desktop
                    Flow { width: parent.width; spacing: 6
                        Repeater { model: (root.found.pins || []).slice(0, 12)
                            Rectangle { required property string modelData; height: 32; width: pinChip.implicitWidth + 20; radius: 16; color: Theme.level(4)
                                Row { id: pinChip; anchors.centerIn: parent; spacing: 6
                                    Image { width: 18; height: 18; source: root.appIcon(modelData); sourceSize: Qt.size(36, 36); anchors.verticalCenter: parent.verticalCenter; asynchronous: true }
                                    MText { text: root.appName(modelData); role: "labelS"; anchors.verticalCenter: parent.verticalCenter } } } } }
                }
                BringRow {
                    icon: "keyboard"; title: "Keyboard and touchpad"; checked: root.importKeyboard; onToggled: v => root.importKeyboard = v
                    available: !!root.found.keyboard || root.found.naturalScroll !== undefined
                    detail: available ? [root.found.keyboard ? root.found.keyboard.toUpperCase() + " layout" + (root.found.keyboard.indexOf(",") >= 0 ? "s" : "") : "",
                                         root.found.naturalScroll === undefined ? "" : root.found.naturalScroll ? "natural scrolling" : "traditional scrolling"].filter(t => !!t).join(" · ")
                        : "Opal uses Hyprland's defaults"
                }
            }
        }
    } }

    // ---------- 2 choices ----------
    Component { id: choosePage; StepLayout {
        icon: "tune"; title: "A few choices"
        body: "Opal can work like " + root.desktop + " or in its own ways. Change any of these later in Settings."
        Flickable {
            anchors.fill: parent; contentHeight: Math.max(height, chooseCol.implicitHeight); clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: chooseCol; y: Math.max(0, (parent.parent.height - implicitHeight) / 2); width: parent.width - 10; spacing: 14
                SectionLabel { text: "Windows" }
                RowLayout { Layout.fillWidth: true; spacing: 12
                    PickCard { id: floatCard; Layout.fillWidth: true; Layout.preferredHeight: 176; title: "Floating"; detail: "Title bars, snapping and minimize, like " + root.desktop; chosen: root.windows === "floating"; onPicked: root.windows = "floating"
                        WindowArt { anchors.fill: parent; tiling: false; on: floatCard.chosen } }
                    PickCard { id: tileCard; Layout.fillWidth: true; Layout.preferredHeight: 176; title: "Tiling"; detail: "Windows sit side by side and never overlap"; chosen: root.windows === "tiling"; onPicked: root.windows = "tiling"
                        WindowArt { anchors.fill: parent; tiling: true; on: tileCard.chosen } } }
                SectionLabel { text: "AI"; Layout.topMargin: 6 }
                RowLayout { Layout.fillWidth: true; spacing: 12
                    PickCard { Layout.fillWidth: true; Layout.preferredHeight: 150; title: "Use Claude"; detail: "An assistant in Start and its own panel"; chosen: root.ai; onPicked: root.ai = true
                        MorphShape { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * .95; height: width; shape: 8; spin: root.ai; fill: root.ai ? Theme.primary : Theme.alpha(Theme.text, .18)
                            Glyph { anchors.centerIn: parent; name: "auto_awesome"; font.pixelSize: parent.width * .45; color: root.ai ? Theme.onPrimary : Theme.subtext } } }
                    PickCard { Layout.fillWidth: true; Layout.preferredHeight: 150; title: "No AI"; detail: "No assistant and no AI anywhere in Opal"; chosen: !root.ai; onPicked: root.ai = false
                        MorphShape { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * .95; height: width; shape: 0; spin: false; fill: !root.ai ? Theme.primary : Theme.alpha(Theme.text, .18)
                            Glyph { anchors.centerIn: parent; name: "block"; font.pixelSize: parent.width * .45; color: !root.ai ? Theme.onPrimary : Theme.subtext } } } }
                SectionLabel { text: "Fonts"; Layout.topMargin: 6; visible: Object.values(root.checks.fonts || {}).some(v => !v) }
                BringRow { visible: Object.values(root.checks.fonts || {}).some(v => !v); icon: "font_download"; title: "Get Opal's fonts"; checked: root.fonts; onToggled: v => root.fonts = v
                    detail: "Google Sans Flex and Material Symbols, about 12 MB, into ~/.local/share/fonts. Without them Opal falls back to your system font." }
            }
        }
    } }
    // Floating or tiling, drawn as two small windows.
    component WindowArt: Item {
        property bool tiling
        property bool on
        readonly property color ink: on ? Theme.onContainer : Theme.primary
        Rectangle { anchors.centerIn: parent; width: Math.min(parent.width * .82, parent.height * 1.5); height: width / 1.6; radius: 10; color: "transparent"; border.width: 2; border.color: Theme.alpha(Theme.text, .3)
            Rectangle { x: tiling ? 5 : parent.width * .1; y: tiling ? 5 : parent.height * .14; width: tiling ? parent.width / 2 - 7.5 : parent.width * .52; height: tiling ? parent.height - 10 : parent.height * .55; radius: 6
                color: Theme.alpha(parent.parent.ink, .85)
                Behavior on x { NumberAnimation { duration: Theme.motion(Theme.durMedium) } } }
            Rectangle { x: tiling ? parent.width / 2 + 2.5 : parent.width * .38; y: tiling ? 5 : parent.height * .36; width: tiling ? parent.width / 2 - 7.5 : parent.width * .52; height: tiling ? parent.height - 10 : parent.height * .55; radius: 6
                color: Theme.alpha(parent.parent.ink, .45); border.width: tiling ? 0 : 2; border.color: Theme.level(3)
                Row { visible: !tiling; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 5; spacing: 3
                    Repeater { model: 3; Rectangle { width: 6; height: 6; radius: 3; color: Theme.alpha(Theme.base, .8) } } } } }
    }

    // ---------- 3 switch ----------
    Component { id: goPage; Loader {
        sourceComponent: root.phase === "running" || root.phase === "undoing" ? runningView : root.phase === "done" ? doneView : root.phase === "undone" ? undoneView : root.phase === "failed" ? failedView : reviewView
    } }

    Component { id: reviewView; StepLayout {
        icon: "rocket_launch"; title: "Ready to switch"
        body: "This takes a few minutes. " + (root.needsPassword ? "You'll be asked for your password once, to install packages and add Opal to the login screen. " : "") + "You can keep using " + root.desktop + " while it runs."
        Card {
            anchors.fill: parent
            ColumnLayout { anchors.fill: parent; anchors.margins: 22; spacing: 12
                Repeater { model: root.planned
                    RowLayout { required property var modelData; required property int index; Layout.fillWidth: true; spacing: 14
                        Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 14; color: Theme.secondaryContainer
                            Glyph { anchors.centerIn: parent; name: modelData.icon; font.pixelSize: 21; color: Theme.onSecondaryContainer } }
                        MText { Layout.fillWidth: true; text: modelData.title; role: "titleS" }
                        Glyph { visible: !!modelData.root; name: "lock"; font.pixelSize: 18; color: Theme.subtext } } }
                Item { Layout.fillHeight: true }
                Flow { Layout.fillWidth: true; spacing: 8
                    Repeater { model: [
                        {i: root.windows === "floating" ? "select_window" : "dashboard", t: root.windows === "floating" ? "Floating windows" : "Tiling windows"},
                        {i: root.ai ? "auto_awesome" : "block", t: root.ai ? "Claude" : "No AI"},
                        {i: "palette", t: root.importLook && (root.found.wallpaper || root.found.light !== undefined) ? "Your look" : "Opal's look"},
                        {i: "keep", t: root.importPins && (root.found.pins || []).length ? root.found.pins.length + " pinned apps" : "No pins"}]
                        Rectangle { required property var modelData; height: 34; width: rr.implicitWidth + 24; radius: 17; color: Theme.level(3)
                            Row { id: rr; anchors.centerIn: parent; spacing: 6
                                Glyph { name: modelData.i; font.pixelSize: 17; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                MText { text: modelData.t; role: "label"; anchors.verticalCenter: parent.verticalCenter } } } } }
                RowLayout { Layout.fillWidth: true; Layout.topMargin: 6; spacing: 10
                    MButton { text: "Back"; icon: "back"; onClicked: root.back() }
                    Item { Layout.fillWidth: true }
                    MButton { text: "Switch to Opal"; icon: root.needsPassword ? "lock_open" : "rocket_launch"; filled: true; implicitHeight: 52; enabled: !root.blocked; onClicked: root.start() } }
            }
        }
    } }

    Component { id: runningView; ColumnLayout {
        id: runCol
        spacing: 14
        readonly property int doneCount: root.stages.filter(s => s.state === "done" || s.state === "skipped").length
        readonly property var active: root.stages.find(s => s.state === "running") || null
        RowLayout { Layout.fillWidth: true; spacing: 16
            LoadingIndicator { implicitWidth: 56; implicitHeight: 56; contained: true }
            ColumnLayout { Layout.fillWidth: true; spacing: 2
                MText { text: root.phase === "undoing" ? "Undoing the switch" : "Switching to Opal"; role: "headline" }
                MText { Layout.fillWidth: true; text: runCol.active ? runCol.active.title + "…" : root.stages.length ? "Waiting for your password…" : "Getting ready…"; role: "body"; color: Theme.subtext } }
            MButton { visible: root.phase === "running"; text: "Cancel"; tonal: true; onClicked: root.cancel() } }
        WavyProgress { Layout.fillWidth: true
            progress: { const n = Math.max(1, root.stages.length), a = runCol.active, part = a && a.progress >= 0 ? a.progress : 0; return root.stages.length ? (runCol.doneCount + part) / n : -1; } }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: stageCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: stageCol; width: parent.width - 8; spacing: 4
                Repeater { model: root.stages
                    Rectangle {
                        id: stageRow
                        required property var modelData
                        readonly property bool running: modelData.state === "running"
                        Layout.fillWidth: true; implicitHeight: rowCol.implicitHeight + 24; radius: Theme.shapeLg
                        color: running ? Theme.level(3) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
                        ColumnLayout { id: rowCol; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 } spacing: 8
                            RowLayout { spacing: 14
                                Item { Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    LoadingIndicator { anchors.fill: parent; visible: stageRow.running }
                                    Rectangle { anchors.fill: parent; radius: 15; visible: !stageRow.running
                                        color: stageRow.modelData.state === "done" ? Theme.primary : stageRow.modelData.state === "failed" ? Theme.error : Theme.level(4)
                                        Glyph { anchors.centerIn: parent; font.pixelSize: 18
                                            name: stageRow.modelData.state === "done" ? "check" : stageRow.modelData.state === "failed" ? "close" : stageRow.modelData.state === "skipped" ? "remove" : "more_horiz"
                                            color: stageRow.modelData.state === "done" ? Theme.onPrimary : stageRow.modelData.state === "failed" ? Theme.base : Theme.subtext } } }
                                MText { Layout.fillWidth: true; text: stageRow.modelData.title; role: stageRow.running ? "titleS" : "body"; color: stageRow.modelData.state === "waiting" ? Theme.subtext : Theme.text } }
                            ColumnLayout { visible: stageRow.running; Layout.fillWidth: true; Layout.leftMargin: 44; spacing: 6
                                WavyProgress { Layout.fillWidth: true; progress: stageRow.modelData.progress === undefined ? -1 : stageRow.modelData.progress }
                                MText { Layout.fillWidth: true; role: "bodyS"; color: Theme.subtext; elide: Text.ElideRight; text: stageRow.modelData.detail || ""; visible: text !== "" } }
                        }
                    }
                }
            }
        }
        LogDrawer { Layout.fillWidth: true }
    } }

    component LogDrawer: ColumnLayout {
        spacing: 6
        MButton { text: root.showLog ? "Hide details" : "Details"; icon: root.showLog ? "expand_less" : "terminal"; compact: true; onClicked: root.showLog = !root.showLog }
        Rectangle {
            visible: root.showLog; Layout.fillWidth: true; Layout.preferredHeight: 160; radius: Theme.shapeMd; color: Theme.level(1)
            ListView {
                id: logView; anchors.fill: parent; anchors.margins: 10; clip: true; model: root.log
                onCountChanged: positionViewAtEnd()
                delegate: Text { required property string modelData; width: logView.width; text: modelData; font.family: "monospace"; font.pixelSize: 11; color: Theme.subtext; wrapMode: Text.WrapAnywhere }
            }
        }
    }

    Component { id: doneView; Item {
        id: done
        property real pop: 0
        Component.onCompleted: popIn.start()
        NumberAnimation { id: popIn; target: done; property: "pop"; from: 0; to: 1; duration: Theme.motion(700); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        ColumnLayout {
            anchors.centerIn: parent; width: Math.min(parent.width, 640); spacing: 16
            Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 120; Layout.preferredHeight: 120; radius: 60; color: Theme.primary; scale: done.pop
                Glyph { anchors.centerIn: parent; name: "check"; font.pixelSize: 72; color: Theme.onPrimary } }
            MText { Layout.alignment: Qt.AlignHCenter; text: "Opal is ready"; role: "displayM"; font.pixelSize: root.narrow ? 40 : 60 }
            MText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; role: "body"; font.pixelSize: 16; color: Theme.subtext
                text: "Log out, then choose Opal on " + (root.checks && root.checks.dm ? root.checks.dm : "the login screen") + ". " + root.desktop + " is still there whenever you want it." }
            // Login screen sketch: the session picker with Opal chosen.
            Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; implicitWidth: sessRow.implicitWidth + 16; implicitHeight: 48; radius: 24; color: Theme.level(3)
                Row { id: sessRow; anchors.centerIn: parent; spacing: 6
                    Repeater { model: [root.desktop, "Opal"]
                        Rectangle { required property string modelData; required property int index; height: 36; width: sessText.implicitWidth + 28; radius: 18; color: index === 1 ? Theme.primary : "transparent"
                            MText { id: sessText; anchors.centerIn: parent; text: modelData; role: "label"; color: index === 1 ? Theme.onPrimary : Theme.subtext } } } } }
            MText { Layout.fillWidth: true; visible: root.message !== ""; horizontalAlignment: Text.AlignHCenter; text: root.message; role: "bodyS"; color: Theme.tertiary; wrapMode: Text.Wrap }
            RowLayout { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 14; spacing: 12
                MButton { text: "Later"; tonal: true; implicitHeight: 52; onClicked: root.quit() }
                MButton { text: "Log out now"; icon: "logout"; filled: true; implicitHeight: 52; implicitWidth: 200; onClicked: root.send({action: "logout"}) } }
            MText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; text: "Changed your mind? Run opal-switch --undo"; role: "bodyS"; color: Theme.subtext }
        }
    } }

    Component { id: undoneView; ColumnLayout {
        spacing: 14
        Item { Layout.fillHeight: true }
        Rectangle { Layout.alignment: Qt.AlignHCenter; width: 96; height: 96; radius: 34; color: Theme.secondaryContainer
            Glyph { anchors.centerIn: parent; name: "undo"; font.pixelSize: 50; color: Theme.onSecondaryContainer } }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Opal is off the login screen"; role: "headline" }
        MText { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 560; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; role: "body"; color: Theme.subtext
            text: "Your settings are back as they were. Opal and the packages it brought stay installed, so switching again is quick." }
        MButton { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 10; text: "Close"; filled: true; onClicked: root.quit() }
        Item { Layout.fillHeight: true } } }

    Component { id: failedView; ColumnLayout {
        spacing: 14
        Item { Layout.fillHeight: true }
        Rectangle { Layout.alignment: Qt.AlignHCenter; width: 88; height: 88; radius: 30; color: Theme.alpha(Theme.error, .16)
            Glyph { anchors.centerIn: parent; name: "error"; font.pixelSize: 46; color: Theme.error } }
        MText { Layout.alignment: Qt.AlignHCenter; text: "The switch stopped"; role: "headline" }
        MText { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 620; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; role: "body"; color: Theme.subtext
            text: (root.error || "Something went wrong.") + " " + root.desktop + " still works as before." }
        RowLayout { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; spacing: 12
            MButton { text: "Back"; tonal: true; onClicked: { root.phase = "ready"; root.go(0); root.detect(); } }
            MButton { text: "Try again"; icon: "refresh"; filled: true; onClicked: root.start() } }
        LogDrawer { Layout.fillWidth: true; Layout.maximumWidth: 900; Layout.alignment: Qt.AlignHCenter }
        Item { Layout.fillHeight: true } } }
}
