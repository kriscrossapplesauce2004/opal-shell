import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// Android setup: checks, a choice of Android build, one password prompt, live progress, Play certification and later management.
Item {
    id: ws
    property bool embedded: false
    signal openStore()
    readonly property var st: Hub.waydroidSetup
    readonly property var ck: st.checks || {}
    readonly property string phase: st.phase === "idle" ? "checking" : st.phase
    readonly property bool wide: width > 760
    property string image: "GAPPS"
    property bool arm: (ck.arch || "x86_64").indexOf("86") >= 0
    property bool showLog: false
    property string confirm: ""
    Component.onCompleted: Hub.command({action: "waydroid-setup-check"})
    function gb(bytes) { return (bytes / 1073741824).toFixed(bytes > 10737418240 ? 0 : 1) + " GB"; }
    function mb(bytes) { return bytes >= 1073741824 ? (bytes / 1073741824).toFixed(2) + " GB" : Math.round(bytes / 1048576) + " MB"; }
    readonly property var checkRows: {
        const r = [];
        if (!ck.arch) return r;
        r.push(ck.binder === "ready" ? {s: "ok", i: "memory", t: "Your kernel supports Android", d: "Binder is built in"}
             : ck.binder === "module" ? {s: "info", i: "memory", t: "Opal will turn on Android support", d: "Loads the binder module now and at every start"}
             : {s: "fail", i: "memory", t: "This kernel can't run Android", d: "Use a kernel with binder, such as linux-zen or a CachyOS kernel"});
        r.push(ck.installed ? {s: "ok", i: "package_2", t: "Waydroid is installed", d: ck.initialized ? "Android images are ready" : "Android still needs to be downloaded"}
             : ck.available === false ? {s: "fail", i: "package_2", t: "No Waydroid package found", d: "Add the Waydroid repository for your distribution first"}
             : {s: "info", i: "package_2", t: "Waydroid comes from your " + (ck.manager || "system") + " repositories", d: "Opal installs it for you"});
        const free = ck.free || 0;
        if (!ck.initialized) r.push(free >= (ck.need || 0) ? {s: "ok", i: "hard_drive", t: gb(free) + " free", d: "Android needs about 4 GB"} : {s: "fail", i: "hard_drive", t: "Only " + gb(free) + " free", d: "Android needs about 4 GB on the system disk"});
        if (ck.firewall) r.push({s: "info", i: "shield", t: "Opal will let Android through " + ck.firewall, d: "Without this, Android has no internet"});
        if (!ck.adb) r.push({s: "info", i: "cable", t: "Opal will add adb and clipboard sharing", d: "Opal uses adb for the back key, dark mode and app updates"});
        if (ck.gpu === "nvidia") r.push({s: "info", i: "developer_board", t: "Android will use software graphics", d: "Waydroid can't use NVIDIA cards, so apps draw on the CPU. Fine for most apps, slow for 3D games"});
        r.push(ck.wayland ? {s: "ok", i: "desktop_windows", t: "Android apps open as normal windows", d: "Wayland session found"} : {s: "fail", i: "desktop_windows", t: "Waydroid needs Wayland", d: "Log in to a Wayland session"});
        return r;
    }
    readonly property bool blocked: checkRows.some(r => r.s === "fail")

    component CheckRow: RowLayout {
        property var row
        spacing: 12
        Rectangle { Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
            color: row.s === "ok" ? Theme.primaryContainer : row.s === "fail" ? Theme.alpha(Theme.error, .18) : Theme.level(4)
            Glyph { anchors.centerIn: parent; name: row.s === "ok" ? "check" : row.s === "fail" ? "close" : row.i; font.pixelSize: 19; color: row.s === "ok" ? Theme.onContainer : row.s === "fail" ? Theme.error : Theme.text } }
        ColumnLayout { Layout.fillWidth: true; spacing: 0
            MText { Layout.fillWidth: true; text: row.t; role: "titleS"; wrapMode: Text.Wrap }
            MText { Layout.fillWidth: true; text: row.d; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } }
    }
    component BuildCard: Rectangle {
        id: bc
        property string value
        property string title
        property string detail
        property string icon
        property string size
        readonly property bool chosen: ws.image === value
        Layout.fillWidth: true; Layout.preferredHeight: bcCol.implicitHeight + 32
        radius: Theme.shapeLg
        color: chosen ? Theme.primaryContainer : Theme.level(3)
        Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: bcMouse.pressed ? .12 : bcMouse.containsMouse ? .06 : 0 }
        ColumnLayout { id: bcCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 6
            RowLayout { spacing: 10
                Glyph { name: bc.icon; font.pixelSize: 26; color: bc.chosen ? Theme.onContainer : Theme.primary }
                Item { Layout.fillWidth: true }
                Rectangle { implicitWidth: sizeText.implicitWidth + 16; implicitHeight: 24; radius: 12; color: Theme.alpha(bc.chosen ? Theme.onContainer : Theme.text, .1)
                    MText { id: sizeText; anchors.centerIn: parent; text: bc.size; role: "labelS"; color: bc.chosen ? Theme.onContainer : Theme.subtext } }
                Glyph { visible: bc.chosen; name: "check_circle"; font.pixelSize: 22; color: Theme.onContainer } }
            MText { text: bc.title; role: "title"; color: bc.chosen ? Theme.onContainer : Theme.text }
            MText { Layout.fillWidth: true; text: bc.detail; role: "bodyS"; wrapMode: Text.Wrap; color: bc.chosen ? Theme.alpha(Theme.onContainer, .82) : Theme.subtext } }
        MouseArea { id: bcMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ws.image = bc.value }
        Accessible.role: Accessible.RadioButton; Accessible.name: title; Accessible.checked: chosen
    }
    component ToggleRow: RowLayout {
        property string icon
        property string title
        property string detail
        property bool checked
        signal toggled(bool value)
        spacing: 14
        Glyph { name: parent.icon; font.pixelSize: 22; color: Theme.primary; Layout.preferredWidth: 28 }
        ColumnLayout { Layout.fillWidth: true; spacing: 0
            MText { Layout.fillWidth: true; text: parent.parent.title; role: "titleS" }
            MText { Layout.fillWidth: true; text: parent.parent.detail; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } }
        MSwitch { checked: parent.checked; onToggled: v => parent.toggled(v) }
    }

    // Phone-shaped art: Android apps in a window, drawn from theme shapes.
    component Hero: Item {
        property bool done: false
        MorphShape { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * 1.02; height: width; shape: parent.done ? 6 : 2; fill: Theme.primaryContainer; fill2: Theme.mix(Theme.primaryContainer, Theme.tertiary, .35); spinMs: 40000 }
        Rectangle {
            id: phoneArt
            anchors.centerIn: parent
            height: Math.min(parent.height * .74, 300); width: height * .52; radius: width * .16
            color: Theme.level(1); border.width: 3; border.color: Theme.alpha(Theme.text, .7)
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * .18; columns: 3; spacing: parent.width * .07
                Repeater { model: 9
                    Rectangle { required property int index; width: phoneArt.width * .2; height: width; radius: index % 3 === 1 ? width * .3 : width / 2
                        color: [Theme.primary, Theme.tertiary, Theme.secondary][index % 3]; opacity: .85 } }
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * .36; height: 4; radius: 2; color: Theme.alpha(Theme.text, .6) }
        }
        Rectangle {
            anchors.left: phoneArt.right; anchors.leftMargin: -phoneArt.width * .3; anchors.bottom: phoneArt.bottom; anchors.bottomMargin: phoneArt.height * .12
            width: 64; height: 64; radius: 22; color: Theme.primary
            Glyph { anchors.centerIn: parent; name: parent.parent.done ? "check" : "android"; font.pixelSize: 36; color: Theme.onPrimary }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ws.phase === "checking" ? checkingView : ws.phase === "running" || ws.phase === "removing" ? runningView
            : ws.phase === "failed" ? failedView : ws.phase === "done" ? doneView : ws.phase === "installed" ? manageView : introView
    }

    Component { id: checkingView; ColumnLayout {
        Item { Layout.fillHeight: true }
        LoadingIndicator { Layout.alignment: Qt.AlignHCenter; contained: true; implicitWidth: 64; implicitHeight: 64 }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Checking this computer…"; role: "title"; Layout.topMargin: 12 }
        Item { Layout.fillHeight: true } } }

    Component { id: introView; GridLayout {
        columns: ws.wide ? 2 : 1; columnSpacing: 32; rowSpacing: 16
        Hero { Layout.fillWidth: !ws.wide; Layout.fillHeight: ws.wide; Layout.preferredHeight: ws.wide ? -1 : 200; Layout.preferredWidth: ws.wide ? parent.width * .38 : -1 }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 300; Layout.preferredWidth: ws.wide ? parent.width * .58 : -1
            contentHeight: introCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: introCol; width: parent.width - 8; spacing: 14
                MText { text: "Android apps, right on Opal"; role: "headline"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                MText { Layout.fillWidth: true; wrapMode: Text.Wrap; role: "body"; color: Theme.subtext
                    text: "Waydroid runs a full Android system next to your Linux apps. Android apps open in their own windows, show up in Start and follow your theme." }
                Repeater { model: ws.checkRows; CheckRow { required property var modelData; row: modelData; Layout.fillWidth: true } }
                MText { text: "Choose your Android"; role: "titleS"; color: Theme.primary; Layout.topMargin: 6 }
                RowLayout { Layout.fillWidth: true; spacing: 10
                    BuildCard { value: "GAPPS"; title: "With Google Play"; icon: "shop"; size: "≈ 1.1 GB"; detail: "Play Store and Google apps. Needs a one-time device registration." }
                    BuildCard { value: "VANILLA"; title: "Open source"; icon: "lock_open"; size: "≈ 830 MB"; detail: "No Google. Get apps from F-Droid, Aurora Store or APK files." } }
                ToggleRow { Layout.fillWidth: true; Layout.topMargin: 6; visible: (ws.ck.arch || "").indexOf("86") >= 0; icon: "developer_board"; title: "Run ARM-only apps"
                    detail: "Adds " + (ws.ck.cpu === "intel" ? "libhoudini" : "libndk") + " so most phone games and apps work. Fetches casualsnek/waydroid_script from GitHub."
                    checked: ws.arm; onToggled: v => ws.arm = v }
                Rectangle { visible: !!ws.st.error; Layout.fillWidth: true; implicitHeight: errText.implicitHeight + 24; radius: Theme.shapeMd; color: Theme.alpha(Theme.error, .14)
                    MText { id: errText; anchors.fill: parent; anchors.margins: 12; text: ws.st.error; role: "bodyS"; color: Theme.error; wrapMode: Text.Wrap } }
                RowLayout { Layout.fillWidth: true; Layout.topMargin: 4
                    MText { Layout.fillWidth: true; text: "You'll be asked for your password once."; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap }
                    MButton { text: "Install Android"; icon: "download"; filled: true; enabled: !ws.blocked && !!ws.ck.arch
                        onClicked: Hub.command({action: "waydroid-setup-install", image: ws.image, arm: ws.arm && (ws.ck.arch || "").indexOf("86") >= 0}) } }
            }
        }
    } }

    Component { id: runningView; ColumnLayout {
        id: runCol
        spacing: 14
        readonly property var stages: ws.st.stages || []
        readonly property int doneCount: stages.filter(s => s.state === "done").length
        readonly property var active: stages.find(s => s.state === "running") || null
        RowLayout { Layout.fillWidth: true; spacing: 16
            LoadingIndicator { implicitWidth: 56; implicitHeight: 56; contained: true }
            ColumnLayout { Layout.fillWidth: true; spacing: 2
                MText { text: ws.phase === "removing" ? "Removing Android" : "Setting up Android"; role: "headline" }
                MText { Layout.fillWidth: true; text: runCol.active ? runCol.active.title + "…" : "Waiting for your password…"; role: "body"; color: Theme.subtext } }
            MButton { text: "Cancel"; tonal: true; onClicked: Hub.command({action: "waydroid-setup-cancel"}) } }
        // Whole-setup progress: finished stages plus the running stage's own share.
        WavyProgress { Layout.fillWidth: true
            progress: { const n = Math.max(1, stages.length), a = active, part = a && a.progress >= 0 ? a.progress : 0; return stages.length ? (doneCount + part) / n : -1; } }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: stageCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: stageCol; width: parent.width - 8; spacing: 4
                Repeater { model: stages
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
                                        Glyph { anchors.centerIn: parent; font.pixelSize: 18; name: stageRow.modelData.state === "done" ? "check" : stageRow.modelData.state === "failed" ? "close" : "more_horiz"
                                            color: stageRow.modelData.state === "waiting" || stageRow.modelData.state === "cancelled" ? Theme.subtext : Theme.onPrimary } } }
                                MText { Layout.fillWidth: true; text: stageRow.modelData.title; role: stageRow.running ? "titleS" : "body"; color: stageRow.modelData.state === "waiting" ? Theme.subtext : Theme.text } }
                            ColumnLayout { visible: stageRow.running; Layout.fillWidth: true; Layout.leftMargin: 44; spacing: 6
                                WavyProgress { Layout.fillWidth: true; visible: stageRow.modelData.id === "init" || stageRow.modelData.progress >= 0; progress: stageRow.modelData.progress === undefined ? -1 : stageRow.modelData.progress }
                                MText { Layout.fillWidth: true; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap
                                    text: stageRow.modelData.total ? ("Android " + (stageRow.modelData.part || "system") + " image · " + ws.mb(stageRow.modelData.done || 0) + " of " + ws.mb(stageRow.modelData.total) + (stageRow.modelData.speed ? " · " + stageRow.modelData.speed : ""))
                                        : stageRow.modelData.detail || "" ; visible: text !== "" } }
                        }
                    }
                }
            }
        }
        LogDrawer { Layout.fillWidth: true }
    } }

    component LogDrawer: ColumnLayout {
        spacing: 6
        MButton { text: ws.showLog ? "Hide details" : "Details"; icon: ws.showLog ? "expand_less" : "terminal"; compact: true; onClicked: ws.showLog = !ws.showLog }
        Rectangle {
            visible: ws.showLog; Layout.fillWidth: true; Layout.preferredHeight: 150; radius: Theme.shapeMd; color: Theme.level(1)
            ListView {
                id: logView; anchors.fill: parent; anchors.margins: 10; clip: true; model: ws.st.log || []
                onCountChanged: positionViewAtEnd()
                delegate: Text { required property string modelData; width: logView.width; text: modelData; font.family: "monospace"; font.pixelSize: 11; color: Theme.subtext; wrapMode: Text.WrapAnywhere }
            }
        }
    }

    Component { id: failedView; ColumnLayout {
        spacing: 14
        Item { Layout.fillHeight: true }
        Rectangle { Layout.alignment: Qt.AlignHCenter; width: 72; height: 72; radius: 26; color: Theme.alpha(Theme.error, .16)
            Glyph { anchors.centerIn: parent; name: "error"; font.pixelSize: 38; color: Theme.error } }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Android setup stopped"; role: "headline" }
        MText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: ws.st.error || "Something went wrong."; role: "body"; color: Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 4 }
        RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 10
            MButton { text: "Back"; tonal: true; onClicked: Hub.command({action: "waydroid-setup-check"}) }
            MButton { text: "Try again"; icon: "refresh"; filled: true; onClicked: Hub.command({action: "waydroid-setup-install", image: ws.st.image || ws.image, arm: !!ws.st.arm}) } }
        Item { Layout.fillHeight: true }
        LogDrawer { Layout.fillWidth: true }
    } }

    component Step: RowLayout {
        property int n
        property string title
        property string detail
        spacing: 14
        Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 30; Layout.alignment: Qt.AlignTop; radius: 15; color: Theme.primary
            MText { anchors.centerIn: parent; text: parent.parent.n; role: "titleS"; color: Theme.onPrimary } }
        ColumnLayout { Layout.fillWidth: true; spacing: 2
            MText { Layout.fillWidth: true; text: parent.parent.title; role: "titleS"; wrapMode: Text.Wrap }
            MText { Layout.fillWidth: true; text: parent.parent.detail; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap; visible: text !== "" } }
    }
    component CertifyCard: Rectangle {
        implicitHeight: certCol.implicitHeight + 32; radius: Theme.shapeLg; color: Theme.level(3)
        ColumnLayout { id: certCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 12
            RowLayout { spacing: 10; Glyph { name: "verified_user"; color: Theme.primary }
                MText { text: "Register for the Play Store"; role: "title"; Layout.fillWidth: true } }
            MText { Layout.fillWidth: true; wrapMode: Text.Wrap; role: "bodyS"; color: Theme.subtext; text: "Google blocks the Play Store on unregistered devices. It takes three steps, once." }
            Step { Layout.fillWidth: true; n: 1; title: "Read this device's Android ID"; detail: "Open the Play Store once first. You'll be asked for your password." }
            RowLayout { Layout.leftMargin: 44; spacing: 8
                MButton { text: ws.st.androidId ? "Read again" : "Get Android ID"; icon: "fingerprint"; compact: true; tonal: !ws.st.androidId; enabled: !ws.st.busy; onClicked: Hub.command({action: "waydroid-setup-android-id"}) }
                Rectangle { visible: !!ws.st.androidId; implicitHeight: 38; implicitWidth: idRow.implicitWidth + 24; radius: 19; color: Theme.primaryContainer
                    Row { id: idRow; anchors.centerIn: parent; spacing: 8
                        MText { text: ws.st.androidId || ""; role: "titleS"; font.family: "monospace"; color: Theme.onContainer; anchors.verticalCenter: parent.verticalCenter }
                        Glyph { name: "content_copy"; font.pixelSize: 18; color: Theme.onContainer; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Hub.command({action: "clipboard", text: ws.st.androidId}); Hub.message("Android ID copied"); } } } }
            Step { Layout.fillWidth: true; n: 2; title: "Paste it on Google's registration page"; detail: "Sign in with the Google account you'll use in Android." }
            MButton { Layout.leftMargin: 44; text: "Open registration page"; icon: "open_in_new"; compact: true; tonal: true; onClicked: Hub.command({action: "waydroid-setup-certify"}) }
            Step { Layout.fillWidth: true; n: 3; title: "Wait a few minutes, then restart Android"; detail: "" }
            MButton { Layout.leftMargin: 44; text: "Restart Android"; icon: "restart_alt"; compact: true; tonal: true; onClicked: Hub.command({action: "waydroid-session", verb: "restart"}) }
            MText { visible: !!ws.st.error && !ws.st.busy; Layout.fillWidth: true; text: ws.st.error || ""; role: "bodyS"; color: Theme.error; wrapMode: Text.Wrap }
        }
    }

    Component { id: doneView; GridLayout {
        columns: ws.wide ? 2 : 1; columnSpacing: 32; rowSpacing: 16
        Hero { done: true; Layout.fillWidth: !ws.wide; Layout.fillHeight: ws.wide; Layout.preferredHeight: ws.wide ? -1 : 180; Layout.preferredWidth: ws.wide ? parent.width * .38 : -1 }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: ws.wide ? parent.width * .58 : -1; contentHeight: doneCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout { id: doneCol; width: parent.width - 8; spacing: 14
                MText { text: "Android is ready"; role: "headline" }
                MText { Layout.fillWidth: true; wrapMode: Text.Wrap; role: "body"; color: Theme.subtext; text: "Android apps appear in Start with a small badge and open in their own windows." }
                RowLayout { spacing: 10
                    MButton { text: "Get apps"; icon: "storefront"; filled: true; onClicked: ws.openStore() }
                    MButton { text: "Show Android"; icon: "smartphone"; tonal: true; onClicked: Hub.command({action: "waydroid-session", verb: "full-ui"}) } }
                CertifyCard { Layout.fillWidth: true; visible: ws.st.image === "GAPPS" }
            }
        }
    } }

    Component { id: manageView; Flickable {
        id: manageFlick
        contentHeight: manageCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        readonly property bool running: Hub.waydroid.session === "running"
        ColumnLayout { id: manageCol; width: parent.width - 8; spacing: 14
            Rectangle { Layout.fillWidth: true; implicitHeight: 96; radius: Theme.shapeXl; color: manageFlick.running ? Theme.primaryContainer : Theme.level(3)
                RowLayout { anchors.fill: parent; anchors.margins: 20; spacing: 16
                    Rectangle { Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 20; color: Theme.primary
                        Glyph { anchors.centerIn: parent; name: "android"; font.pixelSize: 32; color: Theme.onPrimary } }
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        MText { text: manageFlick.running ? "Android is running" : "Android is ready"; role: "title"; color: manageFlick.running ? Theme.onContainer : Theme.text }
                        MText { text: (Hub.waydroid.appCount || 0) + " Android apps" + (Hub.waydroid.ip ? " · " + Hub.waydroid.ip : ""); role: "bodyS"; color: manageFlick.running ? Theme.alpha(Theme.onContainer, .8) : Theme.subtext } }
                    MButton { text: manageFlick.running ? "Stop" : "Start"; icon: manageFlick.running ? "stop" : "play_arrow"; filled: true
                        onClicked: Hub.command({action: "waydroid-session", verb: manageFlick.running ? "stop" : "start"})
                    } } }
            GridLayout { Layout.fillWidth: true; columns: ws.wide ? 4 : 2; columnSpacing: 10; rowSpacing: 10
                Repeater { model: [
                    {i: "storefront", t: "Get apps", run: () => ws.openStore()},
                    {i: "smartphone", t: "Show Android", run: () => Hub.command({action: "waydroid-session", verb: "full-ui"})},
                    {i: "restart_alt", t: "Restart Android", run: () => Hub.command({action: "waydroid-session", verb: "restart"})},
                    {i: "tune", t: "Android settings", run: () => Hub.openSettings("apps")}]
                    Rectangle { required property var modelData; Layout.fillWidth: true; implicitHeight: 92; radius: Theme.shapeLg; color: Theme.level(3)
                        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: tileMouse.pressed ? .12 : tileMouse.containsMouse ? .06 : 0 }
                        ColumnLayout { anchors.centerIn: parent; spacing: 6
                            Glyph { Layout.alignment: Qt.AlignHCenter; name: modelData.i; color: Theme.primary; font.pixelSize: 26 }
                            MText { Layout.alignment: Qt.AlignHCenter; text: modelData.t; role: "label" } }
                        MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.run() } } } }
            CertifyCard { Layout.fillWidth: true }
            MText { text: "Start over"; role: "titleS"; color: Theme.primary; Layout.topMargin: 6 }
            Rectangle { Layout.fillWidth: true; implicitHeight: dangerCol.implicitHeight + 32; radius: Theme.shapeLg; color: Theme.level(2)
                ColumnLayout { id: dangerCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 10
                    RowLayout { Layout.fillWidth: true; spacing: 12
                        ColumnLayout { Layout.fillWidth: true; spacing: 0
                            MText { text: "Reinstall Android"; role: "titleS" }
                            MText { Layout.fillWidth: true; text: "Download a fresh system image and keep Waydroid installed"; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } }
                        MButton { text: "Reinstall"; compact: true; tonal: true; onClicked: Hub.command({action: "waydroid-setup-install", image: ws.image, arm: false, reinstall: true}) } }
                    RowLayout { Layout.fillWidth: true; spacing: 12
                        ColumnLayout { Layout.fillWidth: true; spacing: 0
                            MText { text: ws.confirm === "remove" ? "Delete every Android app and file?" : "Remove Android"; role: "titleS"; color: ws.confirm === "remove" ? Theme.error : Theme.text }
                            MText { Layout.fillWidth: true; text: "Deletes the Android images, apps and their data, then uninstalls Waydroid"; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap } }
                        MButton { visible: ws.confirm === "remove"; text: "Keep"; compact: true; onClicked: ws.confirm = "" }
                        MButton { text: ws.confirm === "remove" ? "Delete" : "Remove"; compact: true; filled: ws.confirm === "remove"; accent: Theme.error; fillInk: Theme.base; ink: Theme.error
                            onClicked: { if (ws.confirm === "remove") { ws.confirm = ""; Hub.command({action: "waydroid-setup-remove", uninstall: true}); } else ws.confirm = "remove"; } } } } }
        }
    } }
}
