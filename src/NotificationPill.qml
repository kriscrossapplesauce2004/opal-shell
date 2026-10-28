import QtQuick
import Quickshell

// Desktop notification pill. A new message grows it to show the sender and text for a moment; then it settles to app icons and a count. A click pops the notification card up.
Rectangle {
    id: pill
    property var output: null
    property bool framed: true
    readonly property var inbox: { const r = Notifier.revision; return Notifier.inbox; }
    // Up to three apps, newest first, one icon each.
    readonly property var apps: {
        const seen = {}, out = [];
        for (const e of inbox) {
            const n = e.notification;
            const k = n ? (n.appName || n.appIcon || "") : "";
            if (!n || seen[k]) continue;
            seen[k] = true; out.push(n);
            if (out.length === 3) break;
        }
        return out;
    }
    readonly property bool open: Hub.page === "notifications" && Hub.targetScreen === output
    readonly property var latest: Notifier.announced && Notifier.announced.notification ? Notifier.announced.notification : null
    // Grows for four seconds after a new message, unless the pills are calm or the card is open.
    property bool fresh: false
    Connections {
        target: Notifier
        function onAnnouncedAtChanged() { if (!Activities.calm && Notifier.announced) { pill.fresh = true; dwell.restart(); } }
    }
    Timer { id: dwell; interval: 4000; onTriggered: pill.fresh = false }
    readonly property bool grown: fresh && latest !== null && !open && !hover.hovered
    visible: inbox.length > 0 && !Activities.off
    height: 44; radius: height / 2
    color: open ? Theme.primaryContainer : grown ? Theme.secondaryContainer : framed ? Theme.level(3) : "transparent"
    width: (grown ? newRow.implicitWidth : restRow.implicitWidth) + (framed ? 24 : 10)
    clip: true
    Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durLong); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
    Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.stateLayer; opacity: tap.pressed ? .12 : hover.hovered ? .06 : 0 }
    Row {
        id: newRow
        x: pill.framed ? 9 : 4; anchors.verticalCenter: parent.verticalCenter; spacing: 10
        opacity: pill.grown ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
        AppIcon { width: 26; height: 26; anchors.verticalCenter: parent.verticalCenter; name: pill.latest ? pill.latest.appIcon || pill.latest.appName || "" : "" }
        MText { anchors.verticalCenter: parent.verticalCenter; text: pill.latest ? pill.latest.summary || pill.latest.appName || "" : ""; role: "label"; font.weight: Font.Bold; color: Theme.onSecondaryContainer
            width: Math.min(implicitWidth, 160); elide: Text.ElideRight }
        MText { anchors.verticalCenter: parent.verticalCenter; text: pill.latest ? String(pill.latest.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""; role: "label"; color: Theme.onSecondaryContainer
            visible: text !== ""; width: Math.min(implicitWidth, 220); elide: Text.ElideRight }
    }
    // How long until it settles.
    Rectangle {
        visible: pill.grown; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; x: 22; height: 3; radius: 2
        color: Theme.alpha(Theme.onSecondaryContainer, .45)
        width: (pill.width - 44) * dwellBar.k
        QtObject { id: dwellBar; property real k: 1 }
        NumberAnimation { target: dwellBar; property: "k"; running: pill.grown; from: 1; to: 0; duration: dwell.interval }
    }
    Row {
        id: restRow
        x: pill.framed ? 10 : 4; anchors.verticalCenter: parent.verticalCenter; spacing: 8
        opacity: pill.grown ? 0 : 1; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
        Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: -8
            Repeater {
                model: pill.apps
                Rectangle {
                    required property var modelData
                    width: 28; height: 28; radius: 14; color: pill.color
                    AppIcon { anchors.centerIn: parent; width: 22; height: 22; name: parent.modelData.appIcon || parent.modelData.appName || "" }
                }
            }
        }
        MText { anchors.verticalCenter: parent.verticalCenter; text: pill.inbox.length; role: "label"; font.weight: Font.Bold; font.features: {"tnum": 1}
            color: pill.open ? Theme.onContainer : Theme.text }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: { Hub.targetScreen = pill.output; Hub.toggle("notifications"); } }
    Accessible.role: Accessible.Button
    Accessible.name: inbox.length + " notifications. Show notifications"
}
