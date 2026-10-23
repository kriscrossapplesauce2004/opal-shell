import QtQuick
// Workspace pill for the desktop Shelf: the current number and one dot per workspace. A switch grows it for a moment to show the new workspace's apps; a click pops the workspace card up out of it.
Rectangle {
    id: pill
    property var output: null
    property real panelHeight: 64
    property bool framed: true
    readonly property var spaces: {
        const list = (Hub.status.workspaces || []).filter(n => n > 0).slice().sort((a, b) => a - b);
        return list.indexOf(current) >= 0 || current <= 0 ? list : list.concat([current]).sort((a, b) => a - b);
    }
    readonly property int current: Number(Hub.status.workspace) || 0
    readonly property bool open: PhoneState.spacesOpen && PhoneState.spacesScreen === output
    // One window per app, so three Steam windows show one Steam icon.
    readonly property var apps: {
        const seen = {}, out = [];
        for (const w of Hub.windows) {
            if (Number(w.workspace) !== current || String(w.workspaceName || "").startsWith("special:")) continue;
            const k = String(w.className || w.title || "").toLowerCase();
            if (!seen[k]) { seen[k] = true; out.push(w); }
        }
        return out;
    }
    // The first value after startup is only a baseline, so login and reload stay quiet.
    property int seen: -1
    property bool flashing: false
    onCurrentChanged: {
        if (current <= 0) return;
        if (seen < 0) { seen = current; return; }
        flashing = true; flash.restart();
    }
    Timer { id: flash; interval: 1800; onTriggered: pill.flashing = false }
    function toggle() {
        if (open) { PhoneState.spacesOpen = false; return; }
        PhoneState.spacesScreen = output;
        PhoneState.spacesBottom = panelHeight - 4;
        PhoneState.spacesX = pill.mapToItem(null, 0, 0).x;
        PhoneState.spacesOpen = true;
    }
    readonly property bool wide: flashing || hover.hovered
    visible: Hub.status.hypr && current > 0
    radius: height / 2
    color: open ? Theme.primaryContainer : framed ? Theme.level(3) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
    width: row.implicitWidth + (framed ? 16 : 6)
    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durLong); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
    clip: true
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: tap.pressed ? .12 : hover.hovered ? .06 : 0 }
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter; x: pill.framed ? 8 : 3; spacing: 8
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(30, numText.implicitWidth + 16); height: 30; radius: 15; color: Theme.primary
            MText { id: numText; anchors.centerIn: parent; text: String(pill.current); role: "label"; font.weight: Font.Bold; color: Theme.onPrimary }
        }
        // A switch or hover shows the apps on this workspace.
        Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: 4
            visible: pill.wide && pill.apps.length > 0
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durMedium) } }
            Repeater {
                model: pill.wide ? pill.apps.slice(0, 4) : []
                AppIcon { required property var modelData; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22
                    app: Hub.appForWindow(modelData); name: app ? app.icon || "" : String(modelData.className || "") }
            }
            MText { visible: pill.apps.length > 4; anchors.verticalCenter: parent.verticalCenter; text: "+" + (pill.apps.length - 4); role: "labelS"; color: Theme.subtext }
        }
        MText { visible: pill.wide && pill.apps.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Empty"; role: "label"; color: Theme.subtext }
        // One dot per workspace; the current one is a short bar, and a workspace that wants attention is tinted.
        Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: 4; rightPadding: 4
            visible: pill.spaces.length > 1
            Repeater {
                model: pill.spaces
                Rectangle {
                    required property var modelData
                    readonly property bool on: Number(modelData) === pill.current
                    readonly property bool urgent: Hub.windows.some(w => Number(w.workspace) === Number(modelData) && Hub.urgent(w))
                    anchors.verticalCenter: parent.verticalCenter
                    width: on ? 14 : 6; height: 6; radius: 3
                    color: on ? (pill.open ? Theme.containerInk : Theme.primary) : urgent ? Theme.tertiary
                        : Theme.alpha(pill.open ? Theme.containerInk : Theme.text, Hub.windows.some(w => Number(w.workspace) === Number(modelData)) ? .6 : .28)
                    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
                }
            }
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: pill.toggle() }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => { const d = e.angleDelta.y || -e.angleDelta.x; if (!d) return; const i = pill.spaces.indexOf(pill.current), next = pill.spaces[i + (d < 0 ? 1 : -1)]; Hub.workspace(next !== undefined ? next : pill.current + (d < 0 ? 1 : 0)); }
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Workspace " + current + " of " + spaces.length + (apps.length ? ", " + apps.length + " apps" : ", empty") + ". Show workspaces"
}
