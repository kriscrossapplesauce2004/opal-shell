import QtQuick

// Tablet app launcher. Over the home it fills the screen on a blurred wallpaper. Over an app it is a bottom sheet, like the Android taskbar's app drawer, and the app stays in view behind a dim.
// The status bar and the dock stay still in both forms; only the launcher content moves, and only up.
Item {
    id: launcher
    property var screenObj: null
    // 0 is closed, 1 is open. The overlay drives it.
    property real arrival: 1
    // Set once at open, so the form does not change while the launcher is up.
    property bool overApp: false
    // While an app is carried out, the launcher fades away so the home shows through, and the icon follows the finger.
    property var carried: null
    property point carryAt: Qt.point(0, 0)
    readonly property real show: carried ? 0 : 1
    function lift(app, x, y) { carried = app; carryAt = Qt.point(x, y); PhoneState.homeDrag = {app: app.id, x: x, y: y}; }
    function move(x, y) { if (!carried) return; carryAt = Qt.point(x, y); PhoneState.homeDrag = {app: carried.id, x: x, y: y}; }
    function drop(x, y) {
        if (!carried) return;
        const id = carried.id;
        carried = null; PhoneState.homeDrag = null;
        if (x >= 0) { PhoneState.homeDrop(id, launcher.overApp ? -1 : x, launcher.overApp ? -1 : y); Hub.close(); }
    }
    readonly property var drawer: overApp ? sheetDrawer : fullDrawer
    function focusSearch() { drawer.focusSearch(); }
    // The launcher stays loaded between opens. Each open picks its form again and starts at the top of the list.
    function prepare() {
        overApp = Hub.windows.some(w => Number(w.workspace) === Number(Hub.status.workspace) && (!screenObj || !w.monitor || w.monitor === screenObj.name));
        carried = null; PhoneState.homeDrag = null;
        drawer.reset();
        if (Hub.drawerSearch) { Hub.drawerSearch = false; Qt.callLater(focusSearch); }
    }
    Component.onCompleted: prepare()

    // Over the home: the blurred wallpaper with a calm tint, so labels read on any wallpaper.
    Item {
        anchors.fill: parent; visible: !launcher.overApp; opacity: launcher.arrival * launcher.fade
        PhoneBackdrop { anchors.fill: parent; soft: 1 }
        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.base, Theme.light ? .45 : .4) }
    }
    // Over an app: only a dim, so the app stays in view.
    Rectangle { anchors.fill: parent; visible: launcher.overApp; color: Theme.alpha("#000000", .42 * launcher.arrival); opacity: launcher.fade }
    property real fade: show
    Behavior on fade { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
    // A tap on empty space closes the launcher.
    MouseArea { anchors.fill: parent; onClicked: Hub.close() }

    Item {
        id: stage
        visible: !launcher.overApp
        anchors.fill: parent; anchors.topMargin: PhoneState.statusFor(launcher.screenObj) + 8; anchors.bottomMargin: PhoneState.tabletNavHeight + 8
        opacity: Math.min(1, launcher.arrival * 1.4) * launcher.fade
        transform: Translate { y: (1 - launcher.arrival) * 64 + (1 - launcher.fade) * 40 }
        PhoneDrawer {
            id: fullDrawer
            floating: true
            width: Math.min(parent.width - 64, 1400); height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            onCloseRequested: Hub.close()
            onAppLifted: (app, x, y) => launcher.lift(app, x, y)
            onAppDragged: (x, y) => launcher.move(x, y)
            onAppDropped: (x, y) => launcher.drop(x, y)
        }
    }

    // The sheet slides up from the bottom edge; the dock floats over its lower part.
    Item {
        visible: launcher.overApp
        width: Math.min(parent.width - 48, 1440); height: parent.height - 72
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height * launcher.arrival * (.25 + .75 * launcher.fade)
        opacity: launcher.fade
        // The sheet catches taps, so only the dim closes the launcher.
        MouseArea { anchors.fill: parent }
        PhoneDrawer {
            id: sheetDrawer
            anchors.fill: parent
            dense: true
            bottomInset: PhoneState.tabletNavHeight
            opacity: Math.min(1, launcher.arrival * 1.3)
            onCloseRequested: Hub.close()
            onAppLifted: (app, x, y) => launcher.lift(app, x, y)
            onAppDragged: (x, y) => launcher.move(x, y)
            onAppDropped: (x, y) => launcher.drop(x, y)
        }
    }

    // The carried icon, a little larger than in the grid, with a soft shadow disc.
    Item {
        visible: launcher.carried !== null
        x: launcher.carryAt.x - 40; y: launcher.carryAt.y - 52; width: 80; height: 80; z: 10
        Rectangle { anchors.centerIn: parent; width: 84; height: 84; radius: 42; color: Theme.alpha("#000000", .22) }
        AppIcon { anchors.centerIn: parent; width: 68; height: 68; app: launcher.carried }
    }
    PhoneStatus { anchors.top: parent.top; width: parent.width; height: PhoneState.statusFor(launcher.screenObj); output: launcher.screenObj }
    TabletBar {
        // The same place as the bar in the navigation window, so the two never jump when the launcher opens.
        y: parent.height - PhoneState.tabletNavHeight; width: parent.width; height: 88
        screenObj: launcher.screenObj; keys: !!Hub.prefs.phoneButtons
        onBack: Hub.close(); onHome: { if (launcher.screenObj) Hub.targetScreen = launcher.screenObj; PhoneState.goHome(); }
        onRecents: PhoneState.showRecents(launcher.screenObj, null)
    }
}
