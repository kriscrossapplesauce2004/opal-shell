import QtQuick
import Quickshell
// Workspace switcher pill. The active slot shows its apps and a liquid indicator slides to it. Hover grows every slot into a mini map of its windows.
Item {
    id: pill
    property int shown: Hub.status.workspace || 1
    property bool out: true
    property var screenObj: null
    // Hover or a keyboard request expands the pill into tiles.
    property bool expand: false
    readonly property bool hovered: hover.hovered
    readonly property Item hitItem: track
    property real e: expand ? 1 : 0
    Behavior on e { NumberAnimation { duration: Theme.motion(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }

    readonly property var numbers: {
        const known = (Hub.status.workspaces || []).filter(n => n > 0);
        const top = Math.max(3, Math.min(10, Math.max.apply(null, known.concat([pill.shown || 1]))));
        return Array.from({length: top}, (_, i) => i + 1);
    }
    readonly property int activeIndex: Math.max(0, numbers.indexOf(shown))
    // The last index the indicator settled on, so it knows which edge leads.
    property int settledIndex: activeIndex
    onActiveIndexChanged: settle.restart()
    Timer { id: settle; interval: 460; onTriggered: pill.settledIndex = pill.activeIndex }
    readonly property bool rightward: activeIndex >= settledIndex
    readonly property var monitor: {
        const name = screenObj ? screenObj.name : "";
        const list = Hub.status.monitors || [];
        const m = list.find(x => x.name === name) || list[0] || {x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0};
        const turned = (m.transform || 0) % 2 === 1, scale = m.scale || 1;
        return {name: m.name || "", x: m.x || 0, y: m.y || 0, w: (turned ? m.height : m.width) / scale || 1920, h: (turned ? m.width : m.height) / scale || 1080};
    }
    function wins(n) { return Hub.windows.filter(w => Number(w.workspace) === n && !(w.workspaceName || "").startsWith("special:")); }
    // One icon per app, so three Steam windows show one Steam icon.
    function apps(n) {
        const seen = {}, out = [];
        for (const w of wins(n)) { const k = String(w.className || w.title || "").toLowerCase(); if (!seen[k]) { seen[k] = true; out.push(w); } }
        return out;
    }
    function urgentOn(n) { return wins(n).some(w => Hub.urgent(w)); }
    readonly property var activeApps: apps(shown)
    readonly property int iconCount: Math.min(3, activeApps.length)
    readonly property real slotW: 40
    readonly property real activeW: Math.max(58, 30 + iconCount * 28 + (activeApps.length > 3 ? 26 : 0) + (iconCount ? 4 : 0))
    readonly property real tileW: 168
    readonly property real tileH: Math.max(84, Math.min(120, tileW * monitor.h / monitor.w))
    function mixv(a, b) { return a + (b - a) * e; }
    readonly property real gap: mixv(4, 12)
    readonly property real pad: mixv(6, 12)
    readonly property real inW: mixv(slotW, tileW)
    readonly property real curW: mixv(activeW, tileW)
    readonly property real slotH: mixv(40, tileH + 30)
    readonly property real addW: e * (64 + gap)
    readonly property real trackW: pad * 2 + inW * (numbers.length - 1) + curW + gap * (numbers.length - 1) + addW
    // The focused app of the shown workspace, for the title chip.
    readonly property var focused: wins(shown).find(w => Hub.active(w)) || wins(shown)[0] || null
    width: Math.max(track.width, titleChip.width); height: track.height + 60

    Surface {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        width: pill.trackW; height: pill.slotH + pill.pad * 2
        radius: Math.min(height / 2, 26 + 8 * pill.e)
        kind: "bars"; level: 3; elevated: true; translucency: Math.max(.86, Hub.prefs.glass)
        border.width: Theme.edges && !Theme.solid("bars") ? 1 : 0; border.color: Theme.glassEdge
        y: pill.out ? 12 : -height - 24
        opacity: pill.out ? 1 : 0
        scale: pill.out ? 1 : .92
        transformOrigin: Item.Top
        Behavior on y { NumberAnimation { duration: Theme.motion(pill.out ? 460 : 220); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.out ? Theme.emphasizedDecelerate : Theme.emphasizedAccelerate } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion(pill.out ? 200 : 180) } }
        Behavior on scale { NumberAnimation { duration: Theme.motion(pill.out ? 460 : 220); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        HoverHandler { id: hover }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => { const step = (ev.angleDelta.y || -ev.angleDelta.x) < 0 ? 1 : -1; Hub.workspace(Math.max(1, Math.min(pill.numbers.length + 1, pill.shown + step))); }
        }

        // Liquid indicator: the edge in the direction of travel moves first and the other edge follows.
        Item {
            id: liquid
            readonly property real l: pill.pad + pill.activeIndex * (pill.inW + pill.gap)
            readonly property real r: l + pill.curW
            readonly property bool settled: pill.e === 0 || pill.e === 1
            property real lv: l
            property real rv: r
            Behavior on lv { enabled: liquid.settled; NumberAnimation { duration: Theme.motion(pill.rightward ? 440 : 230); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
            Behavior on rv { enabled: liquid.settled; NumberAnimation { duration: Theme.motion(pill.rightward ? 230 : 440); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
            x: lv - 3 * pill.e; y: pill.pad - 3 * pill.e; width: Math.max(pill.slotW * .6, rv - lv) + 6 * pill.e; height: pill.mixv(40, pill.tileH) + 6 * pill.e
            Rectangle {
                anchors.fill: parent
                radius: pill.mixv(Math.min(height / 2, 20), 17)
                color: Theme.alpha(Theme.primaryContainer, 1 - pill.e)
                border.width: pill.e > .5 ? 3 : 0; border.color: Theme.primary
            }
        }

        Row {
            id: slots
            x: pill.pad; y: pill.pad; spacing: pill.gap
            Repeater {
                model: pill.numbers
                Item {
                    id: slot
                    required property int modelData
                    required property int index
                    readonly property bool current: index === pill.activeIndex
                    readonly property var list: pill.wins(modelData)
                    readonly property int count: list.length
                    width: current ? pill.curW : pill.inW; height: pill.slotH
                    // Collapsed: number, dots for windows, an urgent mark.
                    Item {
                        anchors.fill: parent; opacity: Math.max(0, 1 - pill.e * 2.2); visible: opacity > 0
                        MText {
                            visible: !slot.current
                            anchors.centerIn: parent; anchors.verticalCenterOffset: slot.count > 0 ? -3 : 0
                            text: slot.modelData; role: "label"; font.pixelSize: 13
                            color: slot.count > 0 ? Theme.text : Theme.alpha(Theme.text, .38)
                        }
                        Row {
                            visible: !slot.current && slot.count > 0
                            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; spacing: 2
                            Repeater { model: Math.min(3, slot.count); Rectangle { width: 4; height: 4; radius: 2; color: Theme.subtext } }
                        }
                        Row {
                            visible: slot.current
                            anchors.centerIn: parent; spacing: 6
                            MText { anchors.verticalCenter: parent.verticalCenter; text: slot.modelData; role: "titleS"; color: Theme.onContainer }
                            Repeater {
                                model: slot.current ? pill.activeApps.slice(0, 3) : []
                                AppIcon { required property var modelData; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22
                                    app: Hub.appForWindow(modelData); name: app ? app.icon || "" : String(modelData.className || "") }
                            }
                            MText { visible: slot.current && pill.activeApps.length > 3; anchors.verticalCenter: parent.verticalCenter; text: "+" + (pill.activeApps.length - 3); role: "labelS"; color: Theme.onContainer }
                        }
                        Rectangle { visible: !slot.current && pill.urgentOn(slot.modelData); anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4; width: 8; height: 8; radius: 4; color: Theme.tertiary
                            SequentialAnimation on opacity { running: parent.visible && !Theme.reduceMotion; loops: Animation.Infinite; NumberAnimation { to: .35; duration: 600 } NumberAnimation { to: 1; duration: 600 } } }
                    }
                    // Expanded: a mini map of the workspace with its number and what is open.
                    Item {
                        anchors.fill: parent; opacity: Math.max(0, pill.e * 2 - 1); visible: opacity > 0
                        Rectangle {
                            id: map
                            width: parent.width; height: pill.tileH; radius: 14; color: Theme.level(4); clip: true
                            RoundedImage { anchors.fill: parent; radius: 14; opacity: .5; visible: !!Hub.prefs.wallpaperPath; source: visible ? Hub.prefs.wallpaperPath : ""; decodeSize: Qt.size(pill.tileW * 2, pill.tileH * 2) }
                            Repeater {
                                model: slot.list
                                Rectangle {
                                    required property var modelData
                                    readonly property var at: modelData.at || [0, 0]
                                    readonly property var sz: modelData.size || [0, 0]
                                    readonly property bool full: !!modelData.fullscreen || sz[0] <= 0
                                    x: full ? 3 : Math.max(3, (at[0] - pill.monitor.x) / pill.monitor.w * map.width)
                                    y: full ? 3 : Math.max(3, (at[1] - pill.monitor.y) / pill.monitor.h * map.height)
                                    width: full ? map.width - 6 : Math.max(14, Math.min(map.width - 3 - x, sz[0] / pill.monitor.w * map.width))
                                    height: full ? map.height - 6 : Math.max(14, Math.min(map.height - 3 - y, sz[1] / pill.monitor.h * map.height))
                                    radius: 6; color: Theme.alpha(Theme.surfaceHighest, .94)
                                    border.width: Hub.active(modelData) ? 2 : 1; border.color: Hub.active(modelData) ? Theme.primary : Theme.alpha(Theme.text, .14)
                                    AppIcon { anchors.centerIn: parent; width: Math.min(24, parent.width * .55, parent.height * .55); height: width; app: Hub.appForWindow(parent.modelData); name: app ? app.icon || "" : String(parent.modelData.className || "") }
                                }
                            }
                            MText { visible: slot.count === 0; anchors.centerIn: parent; text: "Empty"; role: "labelS"; color: Theme.subtext }
                        }
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 4; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; spacing: 6
                            Rectangle { width: 20; height: 20; radius: 10; color: slot.current ? Theme.primary : Theme.level(5); anchors.verticalCenter: parent.verticalCenter
                                MText { anchors.centerIn: parent; text: slot.modelData; role: "labelS"; color: slot.current ? Theme.onPrimary : Theme.text } }
                            MText { anchors.verticalCenter: parent.verticalCenter; width: pill.tileW - 34; role: "labelS"; color: Theme.subtext
                                text: { const names = pill.apps(slot.modelData).map(w => (Hub.appForWindow(w) || {name: String(w.className || "App")}).name); return names.length > 2 ? names.slice(0, 2).join(", ") + " +" + (names.length - 2) : names.join(", "); } }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.workspace(slot.modelData) }
                    Accessible.role: Accessible.Button; Accessible.name: "Workspace " + modelData + (count ? ", " + count + " windows" : ", empty")
                }
            }
            // New workspace, only while expanded.
            Item {
                width: Math.max(0, pill.addW - pill.gap); height: pill.slotH; visible: pill.e > .05; opacity: pill.e
                Rectangle { width: parent.width; height: pill.tileH; radius: 14; color: "transparent"; border.width: 2; border.color: Theme.alpha(Theme.text, .2)
                    Glyph { anchors.centerIn: parent; name: "add"; color: Theme.subtext } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.workspace(pill.numbers.length + 1) }
                Accessible.role: Accessible.Button; Accessible.name: "New workspace"
            }
        }
    }
    // The focused app of the shown workspace, in a chip under the pill.
    Surface {
        id: titleChip
        anchors.horizontalCenter: parent.horizontalCenter
        y: track.y + track.height + 8
        visible: !!pill.focused && opacity > 0
        width: Math.min(560, chipRow.implicitWidth + 28); height: 34; radius: 17
        kind: "bars"; level: 3; translucency: Math.max(.86, Hub.prefs.glass)
        border.width: Theme.edges && !Theme.solid("bars") ? 1 : 0; border.color: Theme.glassEdge
        opacity: pill.out ? Math.max(0, 1 - pill.e * 2) : 0
        scale: pill.out ? 1 : .85
        Behavior on opacity { NumberAnimation { duration: Theme.motion(pill.out ? 320 : 140) } }
        Behavior on scale { NumberAnimation { duration: Theme.motion(360); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
        Row {
            id: chipRow; anchors.centerIn: parent; spacing: 8
            readonly property var app: pill.focused ? Hub.appForWindow(pill.focused) : null
            readonly property string appName: app ? app.name : pill.focused ? String(pill.focused.className || "") : ""
            MText { anchors.verticalCenter: parent.verticalCenter; text: chipRow.appName; role: "label" }
            MText { anchors.verticalCenter: parent.verticalCenter; visible: text !== "" && text !== chipRow.appName; text: pill.focused ? String(pill.focused.title || "") : ""; role: "label"; color: Theme.subtext; width: Math.min(implicitWidth, 380) }
        }
    }
}
