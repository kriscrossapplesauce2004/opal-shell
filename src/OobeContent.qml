import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
// Pages of the first-run setup. Oobe.qml is the window around them.
Item {
    id: root
    focus: true
    readonly property bool narrow: width < 860
    readonly property var steps: [
        {id: "hello", label: "Hello", icon: "waving_hand", shape: 1},
        {id: "network", label: "Wi-Fi", icon: "wifi", shape: 2},
        {id: "look", label: "Style", icon: "palette", shape: 5},
        {id: "device", label: "Layout", icon: "devices", shape: 3},
        {id: "apps", label: "Apps", icon: "apps", shape: 7},
        {id: "claude", label: "AI", icon: Hub.aiEnabled ? "auto_awesome" : "block", shape: 8},
        {id: "tips", label: "Shortcuts", icon: "keyboard", shape: 6},
        {id: "ready", label: "Done", icon: "check", shape: 0}
    ]
    property int step: 0
    property int direction: 1
    property string pendingMode: Hub.prefs.mode || "auto"
    property bool androidOpen: false
    readonly property var cur: steps[step]
    function go(next) {
        if (next < 0 || next >= steps.length || next === step) return;
        // The layout choice applies when the user leaves its step, so the shell does not change shape under each click.
        if (cur.id === "device" && pendingMode !== Hub.prefs.mode) Hub.mode(pendingMode);
        direction = next > step ? 1 : -1;
        androidOpen = false;
        step = next;
    }
    function next() { if (step === steps.length - 1) Hub.finishOobe(); else go(step + 1); }
    function back() { if (androidOpen) androidOpen = false; else go(step - 1); }
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (!(activeFocusItem instanceof TextInput)) { next(); e.accepted = true; } }
        else if (e.key === Qt.Key_Escape) { back(); e.accepted = true; }
        else if (e.key === Qt.Key_PageDown) { next(); e.accepted = true; }
        else if (e.key === Qt.Key_PageUp) { back(); e.accepted = true; }
    }
    Component.onCompleted: { forceActiveFocus(); Hub.browseWallpapers(""); }

    // ---------- backdrop ----------
    Image {
        id: wall
        anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
        source: Hub.prefs.wallpaperPath || ""; sourceSize: Qt.size(width / 4, height / 4)
        visible: false
    }
    MultiEffect { anchors.fill: parent; source: wall; visible: wall.status === Image.Ready; blurEnabled: true; blur: 1; blurMax: 64; saturation: .1; opacity: .55 }
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.base, wall.status === Image.Ready ? .62 : 1) }
    MorphShape {
        id: heroShape
        width: Math.max(root.width, root.height) * .62; height: width
        x: root.cur.id === "hello" || root.cur.id === "ready" ? (root.width - width) / 2 : root.narrow ? root.width - width * .55 : root.width * .62
        y: root.cur.id === "hello" || root.cur.id === "ready" ? (root.height - height) / 2 : root.narrow ? -height * .45 : root.height * .38
        Behavior on x { NumberAnimation { duration: Theme.motion(900); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
        Behavior on y { NumberAnimation { duration: Theme.motion(900); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
        shape: root.cur.shape
        fill: Theme.alpha(Theme.primaryContainer, .55); fill2: Theme.alpha(Theme.mix(Theme.primaryContainer, Theme.tertiary, .4), .35)
        spinMs: 60000
    }

    // ---------- top: brand, step chips, skip ----------
    RowLayout {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.narrow ? 16 : 28 }
        height: 44; spacing: 12
        RowLayout { spacing: 10; Layout.preferredWidth: root.narrow ? -1 : 180
            MorphShape { Layout.preferredWidth: 30; Layout.preferredHeight: 30; shape: 8; fill: Theme.primary; spinMs: 14000 }
            MText { visible: !root.narrow; text: "Opal"; role: "title" }
            Item { Layout.fillWidth: true } }
        Item { Layout.fillWidth: true }
        // Done steps are small check dots; the current step is a chip with its name; later steps are icons.
        Row {
            spacing: 6; visible: root.cur.id !== "hello"
            Repeater { model: root.steps
                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.step
                    readonly property bool done: index < root.step
                    // Narrow screens show the other steps as small dots.
                    readonly property bool dot: root.narrow && !current
                    anchors.verticalCenter: parent.verticalCenter
                    height: dot ? 10 : 36; radius: height / 2
                    width: current ? chipRow.implicitWidth + 28 : dot ? 10 : 36
                    Behavior on height { NumberAnimation { duration: Theme.motion(Theme.durMedium) } }
                    color: current ? Theme.primaryContainer : done ? Theme.primary : Theme.alpha(Theme.level(3), .9)
                    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durLong); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
                    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durMedium) } }
                    clip: true
                    Row { id: chipRow; anchors.centerIn: parent; spacing: 6; visible: !chip.dot
                        Glyph { name: chip.done ? "check" : chip.modelData.icon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                            color: chip.current ? Theme.onContainer : chip.done ? Theme.onPrimary : Theme.subtext }
                        MText { visible: chip.current; text: chip.modelData.label; role: "label"; color: Theme.onContainer; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; enabled: chip.done; cursorShape: Qt.PointingHandCursor; onClicked: root.go(chip.index) }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.label
                }
            }
        }
        Item { Layout.fillWidth: true }
        Item { Layout.preferredWidth: root.narrow ? skip.implicitWidth : 180; Layout.preferredHeight: 40
            MButton { id: skip; anchors.right: parent.right; text: root.cur.id === "ready" ? "" : "Skip setup"; visible: root.cur.id !== "ready"; ink: Theme.subtext; compact: true; onClicked: Hub.finishOobe() } }
    }

    // ---------- pages ----------
    Item {
        id: stage
        anchors { left: parent.left; right: parent.right; top: topBar.bottom; bottom: bottomBar.top; leftMargin: root.narrow ? 16 : 72; rightMargin: root.narrow ? 16 : 72; topMargin: 12; bottomMargin: 12 }
        Loader {
            id: page
            width: parent.width; height: parent.height
            property real slide: 0
            x: slide * 70 * root.direction; opacity: 1 - Math.abs(slide)
            sourceComponent: ({hello: helloPage, network: networkPage, look: lookPage, device: devicePage, apps: appsPage, claude: claudePage, tips: tipsPage, ready: readyPage})[root.cur.id]
            onLoaded: enter.restart()
            NumberAnimation { id: enter; target: page; property: "slide"; from: 1; to: 0; duration: Theme.motion(520); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate }
        }
    }

    // ---------- bottom: back, count, next ----------
    RowLayout {
        id: bottomBar
        visible: root.cur.id !== "hello" && root.cur.id !== "ready"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: root.narrow ? 16 : 28 }
        height: visible ? 56 : 0
        MButton { text: "Back"; icon: "back"; onClicked: root.back() }
        Item { Layout.fillWidth: true }
        MText { visible: !root.narrow; text: root.step + " of " + (root.steps.length - 2); role: "label"; color: Theme.subtext }
        Item { Layout.fillWidth: true }
        MButton { text: root.cur.id === "network" && !online ? "Skip for now" : "Next"; trailingIcon: "arrow_forward"; filled: true; implicitHeight: 52; Layout.minimumWidth: 140; onClicked: root.next()
            readonly property bool online: Hub.status.network && Hub.status.network !== "Offline" }
    }

    // ---------- shared pieces ----------
    // Left column of a step: badge, title and text. The right column holds the controls.
    component StepLayout: GridLayout {
        id: sl
        property string icon
        property string title
        property string body
        default property alias content: panel.data
        property real panelWidth: .58
        columns: root.narrow ? 1 : 2; columnSpacing: 64; rowSpacing: 20
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: !root.narrow; Layout.preferredWidth: root.narrow ? -1 : sl.width * (1 - sl.panelWidth)
            Layout.alignment: Qt.AlignTop; spacing: 16
            Item { Layout.fillHeight: true; visible: !root.narrow }
            Rectangle { Layout.preferredWidth: root.narrow ? 52 : 72; Layout.preferredHeight: Layout.preferredWidth; radius: Layout.preferredWidth * .36; color: Theme.primary
                Glyph { anchors.centerIn: parent; name: sl.icon; font.pixelSize: parent.width * .52; color: Theme.onPrimary } }
            MText { Layout.fillWidth: true; text: sl.title; role: root.narrow ? "headline" : "displayS"; wrapMode: Text.Wrap; font.pixelSize: root.narrow ? 28 : 44 }
            MText { Layout.fillWidth: true; text: sl.body; role: "body"; font.pixelSize: root.narrow ? 14 : 16; color: Theme.subtext; wrapMode: Text.Wrap; lineHeight: 1.15 }
            Item { Layout.fillHeight: true; visible: !root.narrow }
            Item { Layout.preferredHeight: root.narrow ? 0 : 60 }
        }
        Item { id: panel; Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: root.narrow ? -1 : sl.width * sl.panelWidth }
    }
    component Card: Surface {
        kind: "panels"; radius: Theme.shapeXl; level: 2; translucency: .92
        border.width: Theme.edges && !Theme.solid("panels") ? 1 : 0; border.color: Theme.glassEdge
    }
    component SectionLabel: MText { role: "titleS"; color: Theme.primary }
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
        // The ring sits outside the card, so selection never changes the card's shape.
        Rectangle { anchors.fill: parent; anchors.margins: -4; radius: parent.radius + 4; color: "transparent"; border.width: 2; border.color: Theme.primary; visible: pc.chosen }
        ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 6
            Item { id: artBox; Layout.fillWidth: true; Layout.fillHeight: true }
            MText { Layout.fillWidth: true; text: pc.title; role: "titleS"; color: pc.chosen ? Theme.onContainer : Theme.text }
            MText { Layout.fillWidth: true; visible: text !== ""; text: pc.detail; role: "bodyS"; color: pc.chosen ? Theme.alpha(Theme.onContainer, .8) : Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 2 } }
        MouseArea { id: pcMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pc.picked() }
        Accessible.role: Accessible.RadioButton; Accessible.name: title; Accessible.checked: chosen
    }

    component AppRow: Card {
        id: ar
        property string icon
        property string title
        property string detail
        default property alias trailing: trail.data
        signal activated()
        Layout.fillWidth: true; implicitHeight: 104
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: arMouse.pressed ? .1 : arMouse.containsMouse ? .05 : 0 }
        MouseArea { id: arMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ar.activated() }
        RowLayout { anchors.fill: parent; anchors.margins: 20; spacing: 18
            MorphShape { Layout.preferredWidth: 60; Layout.preferredHeight: 60; shape: 5; spin: false; fill: Theme.primaryContainer
                Glyph { anchors.centerIn: parent; name: ar.icon; font.pixelSize: 28; color: Theme.onContainer } }
            ColumnLayout { Layout.fillWidth: true; spacing: 2
                MText { text: ar.title; role: "title" }
                MText { Layout.fillWidth: true; text: ar.detail; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 2 } }
            Row { id: trail; spacing: 8 } }
    }
    readonly property var ws: Hub.waydroidSetup

    // ---------- 0 hello ----------
    Component { id: helloPage; Item {
        id: hello
        readonly property var words: ["Hello", "Bonjour", "Hola", "Hallo", "Ciao", "こんにちは", "Olá", "안녕하세요", "Hej", "Привет", "你好", "Merhaba"]
        property int w: 0
        Timer { interval: 2200; running: !Theme.reduceMotion; repeat: true; onTriggered: { swap.restart(); } }
        SequentialAnimation { id: swap
            ParallelAnimation { NumberAnimation { target: greet; property: "opacity"; to: 0; duration: Theme.motion(260) } NumberAnimation { target: greet; property: "anchors.verticalCenterOffset"; to: -110; duration: Theme.motion(260); easing.type: Easing.InCubic } }
            ScriptAction { script: hello.w = (hello.w + 1) % hello.words.length }
            PropertyAction { target: greet; property: "anchors.verticalCenterOffset"; value: -50 }
            ParallelAnimation { NumberAnimation { target: greet; property: "opacity"; to: 1; duration: Theme.motion(420) } NumberAnimation { target: greet; property: "anchors.verticalCenterOffset"; to: -80; duration: Theme.motion(520); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        }
        MText {
            id: greet
            anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -80
            text: hello.words[hello.w]; role: "displayL"; font.pixelSize: root.narrow ? 64 : 128; elide: Text.ElideNone
            color: Theme.text
        }
        MText { id: welcomeText; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: greet.bottom; anchors.topMargin: 8; text: "Welcome to Opal"; role: "title"; font.pixelSize: root.narrow ? 18 : 24; color: Theme.subtext }
        MButton { id: start; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: welcomeText.bottom; anchors.topMargin: 48
            text: "Get started"; trailingIcon: "arrow_forward"; filled: true; implicitHeight: 60; implicitWidth: 220; onClicked: root.next() }
        // Quick fixes before anything else: theme and motion.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; spacing: 10
            Repeater { model: [
                {icon: Theme.light ? "dark_mode" : "light_mode", label: Theme.light ? "Dark theme" : "Light theme", run: () => Hub.set("light", !Theme.light)},
                {icon: "motion_photos_off", label: Theme.reduceMotion ? "Motion is reduced" : "Reduce motion", run: () => Hub.set("reduceMotion", !Theme.reduceMotion)},
                {icon: Hub.aiEnabled ? "block" : "check", label: Hub.aiEnabled ? "No AI" : "AI removed", run: () => Hub.command({action: Hub.aiEnabled ? "ai-remove" : "ai-restore"})}]
                Rectangle { required property var modelData; height: 40; width: hr.implicitWidth + 28; radius: 20; color: Theme.alpha(Theme.level(3), .92)
                    Row { id: hr; anchors.centerIn: parent; spacing: 8
                        Glyph { name: modelData.icon; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: modelData.label; role: "label"; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.run() } } }
        }
    } }

    // ---------- 1 network ----------
    Component { id: networkPage; StepLayout {
        icon: "wifi"; title: "Get connected"
        body: "Opal uses the internet for weather, the app store" + (Hub.aiEnabled ? ", Android and Claude." : " and Android.") + " You can skip this and connect later from Quick Settings."
        Card {
            id: net
            anchors.fill: parent
            readonly property bool online: Hub.status.network && Hub.status.network !== "Offline"
            ColumnLayout { anchors.fill: parent; anchors.margins: 20; spacing: 14
                Rectangle { Layout.fillWidth: true; implicitHeight: 72; radius: Theme.shapeLg; color: net.online ? Theme.primaryContainer : Theme.level(3)
                    RowLayout { anchors.fill: parent; anchors.margins: 16; spacing: 14
                        Glyph { name: net.online ? "check_circle" : "wifi_find"; font.pixelSize: 30; color: net.online ? Theme.onContainer : Theme.primary }
                        ColumnLayout { Layout.fillWidth: true; spacing: 0
                            MText { text: net.online ? "You're online" : "Not connected yet"; role: "titleS"; color: net.online ? Theme.onContainer : Theme.text }
                            MText { text: net.online ? Hub.status.network : "Choose a network below"; role: "bodyS"; color: net.online ? Theme.alpha(Theme.onContainer, .8) : Theme.subtext } } } }
                ConnectionPanel { Layout.fillWidth: true; Layout.fillHeight: true; kind: "wifi" }
            }
        }
    } }

    // ---------- 2 look ----------
    Component { id: lookPage; StepLayout {
        icon: "palette"; title: "Make it yours"
        body: "Pick light or dark, your colours and how see-through Opal is. The preview and the real shell change as you choose."
        Flickable {
            anchors.fill: parent; contentHeight: Math.max(height, lookCol.implicitHeight); clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: lookCol; y: Math.max(0, (parent.parent.height - implicitHeight) / 2); width: parent.width - 10; spacing: 16
                // Live preview: wallpaper, a window and the bar, drawn with the real Look rules.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: Math.min(300, width * .5); radius: Theme.shapeXl; color: Theme.level(1); clip: true
                    Image { anchors.fill: parent; source: Hub.prefs.wallpaperPath || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 900 }
                    Rectangle { anchors.fill: parent; color: Theme.alpha("#000000", Hub.prefs.wallpaperDim || 0) }
                    Surface { kind: "panels"; x: parent.width * .08; y: parent.height * .12; width: parent.width * .52; height: parent.height * .62; radius: 18; level: 2; translucency: Hub.prefs.glass; elevated: true
                        border.width: Theme.edges && !Theme.solid("panels") ? 1 : 0; border.color: Theme.glassEdge
                        Column { anchors.fill: parent; anchors.margins: 14; spacing: 8
                            Rectangle { width: parent.width * .5; height: 10; radius: 5; color: Theme.alpha(Theme.text, .7) }
                            Rectangle { width: parent.width * .8; height: 7; radius: 3.5; color: Theme.alpha(Theme.text, .3) }
                            Rectangle { width: parent.width * .7; height: 7; radius: 3.5; color: Theme.alpha(Theme.text, .3) }
                            Row { spacing: 6; topPadding: 6
                                Rectangle { width: 60; height: 24; radius: 12; color: Theme.primary }
                                Rectangle { width: 50; height: 24; radius: 12; color: Theme.primaryContainer } } } }
                    Surface { kind: "widgets"; x: parent.width * .66; y: parent.height * .12; width: parent.width * .26; height: parent.width * .26; radius: 22; level: 2; translucency: Hub.prefs.glass
                        border.width: Theme.edges && !Theme.solid("widgets") ? 1 : 0; border.color: Theme.glassEdge
                        MText { anchors.centerIn: parent; text: Qt.formatTime(new Date(), "hh:mm"); role: "headline"; color: Theme.text } }
                    Surface { kind: "bars"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; width: parent.width * .6; height: 38; radius: 19; level: 3; translucency: Hub.prefs.glass
                        border.width: Theme.edges && !Theme.solid("bars") ? 1 : 0; border.color: Theme.glassEdge
                        Row { anchors.centerIn: parent; spacing: 10
                            Repeater { model: 6; Rectangle { width: 22; height: 22; radius: index === 0 ? 8 : 11; color: index === 0 ? Theme.primary : Theme.alpha(Theme.text, .25) } } } }
                }
                SectionLabel { text: "Theme" }
                SegmentedButtons { Layout.fillWidth: true; current: Theme.light ? "light" : "dark"
                    options: [{value: "dark", label: "Dark", icon: "dark_mode"}, {value: "light", label: "Light", icon: "light_mode"}]
                    onPicked: v => Hub.set("light", v === "light") }
                SectionLabel { text: "Colour" }
                Flow { Layout.fillWidth: true; spacing: 12
                    Repeater { model: Theme.palettes
                        Item { required property var modelData; required property int index; width: 56; height: 72
                            readonly property bool on: !Hub.prefs.dynamicColors && Hub.prefs.palette === index
                            Rectangle { width: 52; height: 52; radius: 26; x: 2; color: modelData.seed
                                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 26; height: 26; radius: 13; color: modelData.primary; border.width: 2; border.color: Theme.base }
                                Rectangle { anchors.fill: parent; anchors.margins: -4; radius: 30; color: "transparent"; border.width: 3; border.color: Theme.primary; visible: parent.parent.on }
                                Glyph { anchors.centerIn: parent; name: "check"; color: "white"; visible: parent.parent.on } }
                            MText { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: modelData.name; role: "labelS"; color: Theme.subtext }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hub.set("dynamicColors", false); Hub.set("palette", index); } } } }
                    Item { width: 56; height: 72
                        readonly property bool on: !!Hub.prefs.dynamicColors
                        Rectangle { width: 52; height: 52; radius: 26; x: 2; clip: true; color: Theme.level(4)
                            Image { anchors.fill: parent; source: Hub.prefs.wallpaperPath || ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 104; asynchronous: true; opacity: .9 }
                            Rectangle { anchors.fill: parent; anchors.margins: -4; radius: 30; color: "transparent"; border.width: 3; border.color: Theme.primary; visible: parent.parent.on }
                            Glyph { anchors.centerIn: parent; name: Hub.themeBusy ? "hourglass" : "wallpaper"; color: "white"; style: Text.Outline; styleColor: Theme.alpha("#000000", .4) } }
                        MText { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: "Wallpaper"; role: "labelS"; color: Theme.subtext }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !!Hub.prefs.wallpaperPath; onClicked: Hub.command({action: "matugen"}) } }
                }
                SectionLabel { text: "Look" }
                RowLayout { Layout.fillWidth: true; spacing: 10
                    Repeater { model: [{id: "glass", t: "Glass", d: "See-through everywhere"}, {id: "mixed", t: "Mixed", d: "Solid sheets, glass bars"}, {id: "material", t: "Material", d: "Solid, classic Material"}]
                        PickCard { required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 150; title: modelData.t; detail: modelData.d; chosen: Theme.look === modelData.id && !Theme.lookCustom
                            onPicked: { Hub.set("look", modelData.id); Hub.set("lookSurfaces", {}); Hub.set("lookEdges", modelData.id !== "material"); Hub.set("lookShadows", modelData.id === "material"); }
                            Item { anchors.fill: parent
                                Rectangle { anchors.centerIn: parent; width: parent.width * .8; height: parent.height * .8; radius: 10; color: Theme.alpha(Theme.tertiary, .5)
                                    Rectangle { anchors.centerIn: parent; width: parent.width * .7; height: parent.height * .6; radius: 8; border.width: modelData.id === "material" ? 0 : 1; border.color: Theme.alpha("#ffffff", .5)
                                        color: modelData.id === "glass" ? Theme.alpha(Theme.level(2), .55) : Theme.level(2) }
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; width: parent.width * .5; height: 8; radius: 4
                                        color: modelData.id === "material" ? Theme.level(3) : Theme.alpha(Theme.level(3), .55) } } } } } }
                SectionLabel { text: "Wallpaper" }
                ListView {
                    Layout.fillWidth: true; Layout.preferredHeight: 96; orientation: ListView.Horizontal; spacing: 10; clip: true; boundsBehavior: Flickable.StopAtBounds
                    model: (Hub.wallpaperLibrary || []).slice(0, 40)
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: (Hub.prefs.wallpaperPath || "") === modelData.path
                        width: 150; height: 92; radius: 16; color: Theme.level(4); clip: true
                        Image { anchors.fill: parent; source: modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 300 }
                        Rectangle { anchors.fill: parent; radius: 16; color: "transparent"; border.width: parent.on ? 3 : 0; border.color: Theme.primary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.command({action: "wallpaper", path: modelData.path, wallpaperFit: Hub.prefs.wallpaperFit || "crop", wallpaperDim: Hub.prefs.wallpaperDim || 0}) }
                    }
                    MText { anchors.centerIn: parent; visible: parent.count === 0; text: Hub.wallpaperLibraryBusy ? "Looking for wallpapers…" : "No wallpapers found in Pictures"; role: "bodyS"; color: Theme.subtext }
                }
            }
        }
    } }

    // ---------- 3 device ----------
    Component { id: devicePage; StepLayout {
        icon: "devices"; title: "How will you use this screen?"
        body: "Opal is one shell for desktops, tablets, phones and the couch. Choose what this screen should be. You can change it any time in Settings."
        Flickable {
            anchors.fill: parent; contentHeight: Math.max(height, devCol.implicitHeight); clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: devCol; y: Math.max(0, (parent.parent.height - implicitHeight) / 2); width: parent.width - 10; spacing: 16
                GridLayout { Layout.fillWidth: true; columns: root.narrow ? 2 : 4; columnSpacing: 12; rowSpacing: 12
                    Repeater { model: [{v: "auto", t: "Automatic", d: "Desktop or touch by screen"}, {v: "desktop", t: "Desktop", d: "Windows, a bar and search"}, {v: "phone", t: "Phone or tablet", d: "A touch home"}, {v: "console", t: "Couch", d: "Games, controller first"}]
                        PickCard { required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 190; title: modelData.t; detail: modelData.d; chosen: root.pendingMode === modelData.v; onPicked: root.pendingMode = modelData.v
                            ModeArt { anchors.fill: parent; anchors.margins: 8; mode: modelData.v; active: root.pendingMode === modelData.v } } } }
                ColumnLayout { visible: root.pendingMode === "desktop" || root.pendingMode === "auto"; Layout.fillWidth: true; spacing: 16
                    SectionLabel { text: "Windows" }
                    SegmentedButtons { Layout.fillWidth: true; current: !!Hub.prefs.floatingMode
                        options: [{value: false, label: "Tiling", icon: "dashboard"}, {value: true, label: "Floating", icon: "select_window"}]
                        onPicked: v => Hub.set("floatingMode", v) }
                    MText { Layout.fillWidth: true; text: Hub.prefs.floatingMode ? "Title bars, snap layouts and minimize, like most desktops." : "Windows sit side by side and never overlap."; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap }
                    SectionLabel { text: "Bar" }
                    RowLayout { Layout.fillWidth: true; spacing: 10
                        Repeater { model: [{v: "islands", t: "Islands"}, {v: "dock", t: "Dock"}, {v: "split", t: "Split"}, {v: "edge", t: "Edge"}]
                            PickCard { id: barCard; required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 120; title: modelData.t; chosen: (Hub.prefs.barStyle || "islands") === modelData.v; onPicked: Hub.set("barStyle", modelData.v)
                                // Bar miniatures: screen frame plus the bar shape.
                                Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: 2; border.color: Theme.alpha(Theme.text, .35)
                                    readonly property color ink: barCard.chosen ? Theme.onContainer : Theme.primary
                                    Row { visible: modelData.v === "islands"; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
                                        Rectangle { width: 22; height: 8; radius: 4; color: parent.parent.ink } Rectangle { width: 30; height: 8; radius: 4; color: parent.parent.ink } Rectangle { width: 14; height: 8; radius: 4; color: parent.parent.ink } }
                                    Rectangle { visible: modelData.v === "dock"; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * .55; height: 9; radius: 4.5; color: parent.ink }
                                    Rectangle { visible: modelData.v === "split"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 4; height: 6; radius: 3; color: parent.ink }
                                    Rectangle { visible: modelData.v === "split"; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * .4; height: 8; radius: 4; color: parent.ink }
                                    Rectangle { visible: modelData.v === "edge"; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 2; height: 9; radius: 2; color: parent.ink } } } } }
                    SectionLabel { text: "App icons" }
                    SegmentedButtons { Layout.fillWidth: true; current: Hub.prefs.iconStyle || "raw"
                        options: [{value: "raw", label: "Original"}, {value: "squircle", label: "Backplate"}, {value: "themed", label: "Themed"}]
                        onPicked: v => Hub.set("iconStyle", v) }
                }
            }
        }
    } }

    // ---------- 4 apps ----------
    Component { id: appsPage; StepLayout {
        icon: "apps"; title: root.androidOpen ? "Android apps" : "Bring your apps"
        body: root.androidOpen ? "Waydroid runs Android next to your Linux apps. Setup keeps going in the background if you move on." : "Run Android apps, find your games and pair your phone. All optional, and all in Settings later."
        Loader { anchors.fill: parent; sourceComponent: root.androidOpen ? androidPanel : appCards }
        Component { id: androidPanel; Card { WaydroidSetup { anchors.fill: parent; anchors.margins: 22; embedded: true; onOpenStore: { Hub.finishOobe(); Hub.openAndroid("store"); } } } }
        Component { id: appCards; ColumnLayout {
            spacing: 12
            Item { Layout.fillHeight: true }
            AppRow { icon: "android"; title: "Android apps"
                detail: Hub.waydroidSetup.busy ? "Setting up… " + ((Hub.waydroidSetup.stages || []).find(s => s.state === "running") || {title: ""}).title
                    : Hub.waydroid.installed && Hub.waydroid.initialized ? "Ready · " + (Hub.waydroid.appCount || 0) + " apps" : "Play Store or F-Droid apps in their own windows"
                onActivated: root.androidOpen = true
                MButton { text: Hub.waydroid.installed && Hub.waydroid.initialized ? "Manage" : Hub.waydroidSetup.busy ? "View" : "Set up"; tonal: true; onClicked: root.androidOpen = true } }
            AppRow { icon: "sports_esports"; title: "Games"
                detail: (Hub.games || []).length ? (Hub.games.length + " games found in Steam and your launchers. Super + Ctrl + G opens Gaming mode.") : "Steam and Prism games show up in Gaming mode. Super + Ctrl + G opens it."
                onActivated: Hub.command({action: "game-library"})
                Glyph { name: (Hub.games || []).length ? "check_circle" : "search"; color: Theme.primary; font.pixelSize: 26 } }
            AppRow { icon: "phonelink"; title: "Your phone"
                detail: "Opal Link shares the clipboard and notifications with a paired phone on the same network."
                onActivated: Hub.set("linkEnabled", !Hub.prefs.linkEnabled)
                MSwitch { checked: !!Hub.prefs.linkEnabled; onToggled: v => Hub.set("linkEnabled", v) } }
            Item { Layout.fillHeight: true }
        } }
    } }

    // ---------- 5 ai ----------
    // AI is a choice here: Claude, or no AI at all. "No AI" turns off every AI surface and disconnects Claude Code.
    Component { id: claudePage; StepLayout {
        icon: Hub.aiEnabled ? "auto_awesome" : "block"; title: Hub.aiEnabled ? "Meet Claude" : "No AI, no problem"
        body: Hub.aiEnabled ? "Claude lives in Opal. Ask it anything, or let it change settings, open apps and arrange windows for you. Press Super + A, or type ! in Start."
            : "Opal works the same without it. There is no assistant, no AI in search and no Ask Claude buttons. Turn it on later in Settings › AI & assistant."
        Timer { interval: 3000; repeat: true; running: Hub.aiEnabled && !AssistantState.available; onTriggered: Hub.command({action: "assistant-context"}) }
        Component.onCompleted: if (Hub.aiEnabled) Hub.command({action: "assistant-context"})
        Flickable {
            anchors.fill: parent; contentHeight: Math.max(height, aiCol.implicitHeight); clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: aiCol; y: Math.max(0, (parent.parent.height - implicitHeight) / 2); width: parent.width - 10; spacing: 16
                RowLayout { Layout.fillWidth: true; spacing: 12
                    PickCard { Layout.fillWidth: true; Layout.preferredHeight: 170; title: "Use Claude"; detail: "An assistant in Start and its own panel"; chosen: Hub.aiEnabled
                        onPicked: if (!Hub.aiEnabled) Hub.command({action: "ai-restore"})
                        MorphShape { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * .9; height: width; shape: 8; spin: Hub.aiEnabled; fill: Hub.aiEnabled ? Theme.primary : Theme.alpha(Theme.text, .18)
                            Glyph { anchors.centerIn: parent; name: "auto_awesome"; font.pixelSize: parent.width * .45; color: Hub.aiEnabled ? Theme.onPrimary : Theme.subtext } } }
                    PickCard { Layout.fillWidth: true; Layout.preferredHeight: 170; title: "No AI"; detail: "Turns off and removes every AI feature"; chosen: !Hub.aiEnabled
                        onPicked: if (Hub.aiEnabled) Hub.command({action: "ai-remove"})
                        MorphShape { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * .9; height: width; shape: 0; spin: false; fill: !Hub.aiEnabled ? Theme.primary : Theme.alpha(Theme.text, .18)
                            Glyph { anchors.centerIn: parent; name: "block"; font.pixelSize: parent.width * .45; color: !Hub.aiEnabled ? Theme.onPrimary : Theme.subtext } } }
                }
                Card {
                    visible: Hub.aiEnabled
                    Layout.fillWidth: true; Layout.preferredHeight: claudeCol.implicitHeight + 48
                    ColumnLayout { id: claudeCol; anchors.fill: parent; anchors.margins: 24; spacing: 18
                        // A sample exchange shows what Claude can do in the shell.
                        Column {
                            Layout.fillWidth: true; spacing: 10
                            Repeater { model: [{me: true, t: "Put Firefox and my terminal side by side"}, {me: false, t: "Done. Firefox is on the left, Kitty on the right."}]
                                Item { required property var modelData; width: parent.width; height: bubble.height
                                    Rectangle { id: bubble; anchors.right: modelData.me ? parent.right : undefined; anchors.left: modelData.me ? undefined : parent.left
                                        width: Math.min(parent.width * .85, bubbleRow.implicitWidth + 32); height: bubbleRow.implicitHeight + 20; radius: 20
                                        color: modelData.me ? Theme.primary : Theme.level(3)
                                        Row { id: bubbleRow; anchors.centerIn: parent; spacing: 8
                                            Glyph { visible: !modelData.me; name: "auto_awesome"; font.pixelSize: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                            MText { text: modelData.t; role: "body"; color: modelData.me ? Theme.onPrimary : Theme.text; anchors.verticalCenter: parent.verticalCenter } } } } }
                        }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 76; radius: Theme.shapeLg; color: AssistantState.available ? Theme.primaryContainer : Theme.level(3)
                            RowLayout { anchors.fill: parent; anchors.margins: 16; spacing: 14
                                Glyph { name: AssistantState.available ? "check_circle" : "download"; font.pixelSize: 28; color: AssistantState.available ? Theme.onContainer : Theme.primary }
                                ColumnLayout { Layout.fillWidth: true; spacing: 0
                                    MText { text: AssistantState.available ? "Claude Code is installed" : "Claude needs Claude Code"; role: "titleS"; color: AssistantState.available ? Theme.onContainer : Theme.text }
                                    MText { Layout.fillWidth: true; text: AssistantState.available ? "Opal talks to Claude through it. Run claude once in a terminal if you haven't signed in." : "Install it once. A terminal shows each step, then sign in."; role: "bodyS"; wrapMode: Text.Wrap; color: AssistantState.available ? Theme.alpha(Theme.onContainer, .8) : Theme.subtext } }
                                MButton { visible: !AssistantState.available; text: "Install"; filled: true; onClicked: Hub.command({action: "assistant-install"}) } } }
                        SectionLabel { text: "When Claude wants to change something" }
                        SegmentedButtons { Layout.fillWidth: true; current: AssistantState.mode
                            options: [{value: "ask", label: "Ask me first", icon: "front_hand"}, {value: "auto", label: "Just do it", icon: "bolt"}]
                            onPicked: v => AssistantState.setMode(v) }
                        MText { Layout.fillWidth: true; text: AssistantState.mode === "auto" ? "Risky actions, like closing apps or deleting files, still ask." : "Every action waits for your OK in the panel."; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap }
                    }
                }
                // AI-free summary: each row is one surface that is now gone.
                Card {
                    visible: !Hub.aiEnabled
                    Layout.fillWidth: true; Layout.preferredHeight: offCol.implicitHeight + 40
                    ColumnLayout { id: offCol; anchors.fill: parent; anchors.margins: 20; spacing: 14
                        Repeater { model: [
                            {i: "chat_bubble", t: "No assistant", d: "Super + A, the Copilot key and hold gestures do nothing"},
                            {i: "search", t: "Plain search", d: "Start shows your apps, files and settings only"},
                            {i: "touch_app", t: "No Ask Claude buttons", d: "Gone from captures, docks, homes and game mode"},
                            {i: "link_off", t: "Disconnected", d: "Opal's tools are removed from Claude Code, if it is installed"}]
                            RowLayout { required property var modelData; Layout.fillWidth: true; spacing: 14
                                Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20; color: Theme.secondaryContainer
                                    Glyph { anchors.centerIn: parent; name: modelData.i; font.pixelSize: 20; color: Theme.onSecondaryContainer } }
                                ColumnLayout { Layout.fillWidth: true; spacing: 0
                                    MText { Layout.fillWidth: true; text: modelData.t; role: "titleS" }
                                    MText { Layout.fillWidth: true; text: modelData.d; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } } } }
                    }
                }
            }
        }
    } }

    // ---------- 6 tips ----------
    Component { id: tipsPage; StepLayout {
        id: tips
        readonly property string m: root.pendingMode === "auto" ? "desktop" : root.pendingMode
        icon: m === "phone" ? "swipe" : m === "console" ? "sports_esports" : "keyboard"
        title: m === "phone" ? "A few gestures" : m === "console" ? "Your controller" : "A few shortcuts"
        body: "These work everywhere in Opal. Settings lists the rest."
        readonly property var items: m === "phone" ? [
            {k: "swipe_up", t: "Go home", d: "Swipe up from the bottom edge", g: true},
            {k: "swipe_up_alt", t: "Recent apps", d: "Swipe up and hold", g: true},
            {k: "swipe_down", t: "Quick Settings", d: "Swipe down from the top", g: true},
            {k: "swipe_right", t: "Back", d: "Swipe in from either side", g: true},
            {k: "touch_app", t: "Move apps and widgets", d: "Press and hold on the home", g: true}]
          : m === "console" ? [
            {k: "Guide", t: "Quick Access", d: "Performance, music and toggles over any game"},
            {k: "Guide + A", t: "Claude", d: "Ask without leaving the game", ai: true},
            {k: "Guide + B", t: "Power menu", d: "Sleep, restart or back to desktop"},
            {k: "A / B", t: "Choose and go back", d: "Everywhere in Opal"}]
          : [
            {k: "Super + Space", t: "Start and search", d: "Apps, files, settings and maths"},
            {k: "Alt + Tab", t: "Switch windows", d: "Hold Alt and tap Tab"},
            {k: "Super + Tab", t: "Every window", d: "Pick one with the mouse or keys"},
            {k: "Super + A", t: "Claude", d: "Ask or get things done", ai: true},
            {k: "Super + Comma", t: "Quick Settings", d: "And your notifications"},
            {k: "Super + L", t: "Lock", d: "Your session stays open"},
            {k: "Super + Ctrl + G", t: "Gaming mode", d: "Your library, controller first"}]
        Flickable {
            anchors.fill: parent; contentHeight: Math.max(height, tipGrid.implicitHeight); clip: true; boundsBehavior: Flickable.StopAtBounds
            GridLayout { id: tipGrid; y: Math.max(0, (parent.parent.height - implicitHeight) / 2); width: parent.width; columns: root.narrow ? 1 : 2; columnSpacing: 12; rowSpacing: 12
                Repeater { model: tips.items.filter(t => Hub.aiEnabled || !t.ai)
                    Card { required property var modelData; required property int index; Layout.fillWidth: true; implicitHeight: 92
                        // Cards arrive one after another.
                        opacity: 0; Component.onCompleted: arrive.start()
                        NumberAnimation on opacity { id: arrive; running: false; from: 0; to: 1; duration: Theme.motion(300 + index * 70); easing.type: Easing.OutCubic }
                        RowLayout { anchors.fill: parent; anchors.margins: 18; spacing: 16
                            Item { Layout.preferredWidth: modelData.g ? 52 : keyRow.implicitWidth; Layout.preferredHeight: 52
                                Rectangle { visible: !!modelData.g; anchors.fill: parent; radius: 18; color: Theme.primaryContainer
                                    Glyph { anchors.centerIn: parent; name: modelData.k; font.pixelSize: 28; color: Theme.onContainer } }
                                Row { id: keyRow; visible: !modelData.g; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                    Repeater { model: modelData.g ? [] : String(modelData.k).split(" + ")
                                        Rectangle { required property string modelData; height: 38; width: Math.max(38, kt.implicitWidth + 20); radius: 10; color: Theme.level(4)
                                            Rectangle { anchors.fill: parent; anchors.topMargin: parent.height - 4; radius: 10; color: Theme.alpha("#000000", .18) }
                                            MText { id: kt; anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: modelData; role: "label"; font.weight: Font.Bold } } } } }
                            ColumnLayout { Layout.fillWidth: true; spacing: 0
                                MText { Layout.fillWidth: true; text: modelData.t; role: "titleS" }
                                MText { Layout.fillWidth: true; text: modelData.d; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } } } } } }
        }
    } }

    // ---------- 7 ready ----------
    Component { id: readyPage; Item {
        id: ready
        property real pop: 0
        Component.onCompleted: popIn.start()
        NumberAnimation { id: popIn; target: ready; property: "pop"; from: 0; to: 1; duration: Theme.motion(700); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        ColumnLayout {
            anchors.centerIn: parent; width: Math.min(parent.width, 640); spacing: 18
            Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 120; Layout.preferredHeight: 120; radius: 60; color: Theme.primary; scale: ready.pop
                Glyph { anchors.centerIn: parent; name: "check"; font.pixelSize: 72; color: Theme.onPrimary } }
            MText { Layout.alignment: Qt.AlignHCenter; text: "You're all set"; role: "displayM"; font.pixelSize: root.narrow ? 40 : 64 }
            MText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Everything you picked is already on. Change any of it in Settings, or run setup again from Start."; role: "body"; font.pixelSize: 16; color: Theme.subtext; wrapMode: Text.Wrap }
            Flow { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: parent.width; spacing: 8
                Repeater { model: [
                    {i: Theme.light ? "light_mode" : "dark_mode", t: Theme.light ? "Light" : "Dark"},
                    {i: "layers", t: Theme.look.charAt(0).toUpperCase() + Theme.look.slice(1)},
                    {i: "devices", t: ({auto: "Automatic", desktop: "Desktop", phone: "Phone or tablet", console: "Couch"})[Hub.prefs.mode] || "Automatic"},
                    {i: Hub.prefs.floatingMode ? "select_window" : "dashboard", t: Hub.prefs.floatingMode ? "Floating" : "Tiling"},
                    {i: "android", t: Hub.waydroidSetup.busy ? "Android setting up" : Hub.waydroid.installed && Hub.waydroid.initialized ? "Android ready" : "No Android", dim: !(Hub.waydroid.installed || Hub.waydroidSetup.busy)},
                    Hub.aiEnabled ? {i: "auto_awesome", t: AssistantState.available ? "Claude ready" : "Claude not installed", dim: !AssistantState.available} : {i: "block", t: "No AI"}]
                    Rectangle { required property var modelData; height: 36; width: rr.implicitWidth + 26; radius: 18; color: modelData.dim ? Theme.alpha(Theme.level(3), .8) : Theme.secondaryContainer
                        Row { id: rr; anchors.centerIn: parent; spacing: 6
                            Glyph { name: modelData.i; font.pixelSize: 17; color: modelData.dim ? Theme.subtext : Theme.onSecondaryContainer; anchors.verticalCenter: parent.verticalCenter }
                            MText { text: modelData.t; role: "label"; color: modelData.dim ? Theme.subtext : Theme.onSecondaryContainer; anchors.verticalCenter: parent.verticalCenter } } } } }
            MButton { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 18; text: "Start using Opal"; trailingIcon: "arrow_forward"; filled: true; implicitHeight: 60; implicitWidth: 260; onClicked: Hub.finishOobe() }
            MButton { Layout.alignment: Qt.AlignHCenter; text: "Back"; ink: Theme.subtext; compact: true; onClicked: root.back() }
        }
    } }
}
