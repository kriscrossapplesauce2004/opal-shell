import QtQuick
import QtQuick.Effects
import Quickshell

// Capture Studio content: a frozen frame to select on, a mode toolbar, a loupe, resize handles and a toolbar of actions next to the selection.
Item {
    id: st
    property var screenObj: null
    signal delayed(int seconds, var request)
    focus: true
    property string mode: "region"
    property bool video: false
    property bool audio: true
    property int delay: 0
    // Selection in window coordinates. A width under 4 means nothing is selected.
    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0
    readonly property bool hasSel: sw >= 4 && sh >= 4
    property real mx: -1000
    property real my: -1000
    // A drag in progress: "new", "move", or a handle such as "tl" or "r".
    property string drag: ""
    property real ax: 0
    property real ay: 0
    property var start: ({x: 0, y: 0, w: 0, h: 0})
    readonly property bool frozen: Hub.captureFrozen !== "" && shot.status === Image.Ready
    // Image pixels per window unit, for the crop and the loupe.
    readonly property real k: frozen && width > 0 ? shot.implicitWidth / width : 1
    readonly property var mon: {
        const name = screenObj ? screenObj.name : "";
        const list = (Hub.status.monitors || []).length ? Hub.status.monitors : Hub.monitors || [];
        return list.find(m => m.name === name) || {x: 0, y: 0, workspace: Hub.status.workspace};
    }
    // Windows on this screen's workspace, most recently focused first, in window coordinates.
    readonly property var wins: Hub.windows.filter(w => (!w.monitor || !screenObj || w.monitor === screenObj.name) && Number(w.workspace) === Number(mon.workspace) && w.size && w.size[0] > 0)
        .slice().sort((a, b) => (a.focus || 0) - (b.focus || 0))
        .map(w => ({w: w, x: (w.at || [0, 0])[0] - (mon.x || 0), y: (w.at || [0, 0])[1] - (mon.y || 0), width: w.size[0], height: w.size[1]}))
    readonly property var hoverWin: mode === "window" && !hasSel ? (wins.find(r => mx >= r.x && mx < r.x + r.width && my >= r.y && my < r.y + r.height) || null) : null
    // The clear hole in the dim layer: the selection, or the window under the pointer.
    readonly property var hole: hasSel ? {x: sx, y: sy, w: sw, h: sh} : hoverWin ? {x: hoverWin.x, y: hoverWin.y, w: hoverWin.width, h: hoverWin.height} : null
    property real arrival: 0
    Component.onCompleted: { forceActiveFocus(); arrive.start(); }
    NumberAnimation { id: arrive; target: st; property: "arrival"; from: 0; to: 1; duration: Theme.motion(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate }

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    function setSel(x, y, w, h) { sx = clamp(x, 0, width); sy = clamp(y, 0, height); sw = clamp(w, 0, width - sx); sh = clamp(h, 0, height - sy); }
    function clear() { sw = 0; sh = 0; }
    function pickMode(m) { mode = m; clear(); if (m === "screen") setSel(0, 0, width, height); }
    function cancel() { Hub.captureClosed(false); }
    function globalGeom() { return Math.round((mon.x || 0) + sx) + "," + Math.round((mon.y || 0) + sy) + " " + Math.round(sw) + "x" + Math.round(sh); }
    function commit(intent) {
        if (!hasSel) return;
        const geom = globalGeom(), out = screenObj ? screenObj.name : "", whole = mode === "screen";
        const live = whole ? {action: "capture-take", mode: "screen", output: out, intent: intent} : {action: "capture-take", mode: "region", geometry: geom, intent: intent};
        if (video) {
            Hub.recordingRect = whole ? null : {screen: screenObj, x: sx, y: sy, w: sw, h: sh};
            Hub.captureClosed(false);
            if (delay > 0) delayed(delay, whole ? {action: "capture-record-start", output: out, audio: audio} : {action: "capture-record-start", geometry: geom, audio: audio});
            else Hub.command(whole ? {action: "capture-record-start", output: out, audio: audio} : {action: "capture-record-start", geometry: geom, audio: audio});
            return;
        }
        // A delayed shot is taken live at the end of the countdown; the frozen frame would be stale by then.
        if (delay > 0) { Hub.captureClosed(false); delayed(delay, live); return; }
        if (frozen) {
            const r = [Math.round(sx * k), Math.round(sy * k), Math.round(sw * k), Math.round(sh * k)];
            Hub.captureClosed(true);
            Hub.command({action: "capture-take", mode: mode, frozen: Hub.captureFrozen, rect: r, intent: intent});
        } else { Hub.captureClosed(false); Hub.command(live); }
    }
    function pickColor(x, y) {
        if (!frozen) return;
        Hub.command({action: "capture-color", frozen: Hub.captureFrozen, x: Math.floor(x * k), y: Math.floor(y * k)});
        Hub.captureClosed(true);
    }
    Keys.onPressed: e => {
        const step = (e.modifiers & Qt.ShiftModifier) ? 10 : 1, ctrl = e.modifiers & Qt.ControlModifier, key = e.key;
        if (key === Qt.Key_Escape) { if (hasSel && mode !== "screen") clear(); else cancel(); }
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || (ctrl && key === Qt.Key_C)) commit("copy");
        else if (ctrl && key === Qt.Key_S) commit("save");
        else if (key === Qt.Key_E && !video) commit("edit");
        else if (key === Qt.Key_T && !video) commit("ocr");
        else if (key === Qt.Key_A && !video && Hub.aiEnabled !== false) commit("ask");
        else if (key === Qt.Key_V) { video = !video; if (video && mode === "color") pickMode("region"); }
        else if (key === Qt.Key_Space) pickMode(mode === "window" ? "region" : "window");
        else if (key === Qt.Key_1) pickMode("region");
        else if (key === Qt.Key_2) pickMode("window");
        else if (key === Qt.Key_3) pickMode("screen");
        else if (key === Qt.Key_4 && !video) pickMode("color");
        else if (hasSel && (key === Qt.Key_Left || key === Qt.Key_Right || key === Qt.Key_Up || key === Qt.Key_Down)) {
            const dx = key === Qt.Key_Left ? -step : key === Qt.Key_Right ? step : 0, dy = key === Qt.Key_Up ? -step : key === Qt.Key_Down ? step : 0;
            if (ctrl) setSel(sx, sy, Math.max(4, sw + dx), Math.max(4, sh + dy));
            else setSel(clamp(sx + dx, 0, width - sw), clamp(sy + dy, 0, height - sh), sw, sh);
        } else return;
        e.accepted = true;
    }

    // Frozen frame. Without one the studio sits over the live screen.
    Image {
        id: shot
        anchors.fill: parent
        source: Hub.captureFrozen ? "file://" + Hub.captureFrozen : ""
        cache: false; smooth: true; fillMode: Image.Stretch
    }
    // Dim everything except the hole.
    Item {
        id: dim
        anchors.fill: parent
        readonly property real a: (st.mode === "screen" ? 0 : st.hole ? .58 : .38) * st.arrival
        readonly property var h: st.hole || {x: 0, y: 0, w: 0, h: 0}
        Rectangle { x: 0; y: 0; width: parent.width; height: dim.h.y; color: "black"; opacity: dim.a }
        Rectangle { x: 0; y: dim.h.y + dim.h.h; width: parent.width; height: parent.height - y; color: "black"; opacity: dim.a }
        Rectangle { x: 0; y: dim.h.y; width: dim.h.x; height: dim.h.h; color: "black"; opacity: dim.a }
        Rectangle { x: dim.h.x + dim.h.w; y: dim.h.y; width: parent.width - x; height: dim.h.h; color: "black"; opacity: dim.a }
    }
    // Crosshair guides before a region is drawn.
    Rectangle { visible: st.mode === "region" && !st.hasSel && st.drag === "" && st.mx >= 0; x: st.mx; y: 0; width: 1; height: parent.height; color: Theme.alpha("#ffffff", .55) }
    Rectangle { visible: st.mode === "region" && !st.hasSel && st.drag === "" && st.mx >= 0; x: 0; y: st.my; width: parent.width; height: 1; color: Theme.alpha("#ffffff", .55) }

    // Pointer input: draw, move, pick a window, pick a colour. Right click clears, then cancels.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: st.mode === "region" || st.mode === "color" ? Qt.CrossCursor : Qt.PointingHandCursor
        onPositionChanged: e => {
            st.mx = e.x; st.my = e.y;
            if (st.drag === "new") st.setSel(Math.min(st.ax, e.x), Math.min(st.ay, e.y), Math.abs(e.x - st.ax), Math.abs(e.y - st.ay));
            else if (st.drag === "move") st.setSel(st.clamp(st.start.x + e.x - st.ax, 0, st.width - st.start.w), st.clamp(st.start.y + e.y - st.ay, 0, st.height - st.start.h), st.start.w, st.start.h);
        }
        onPressed: e => {
            if (e.button === Qt.RightButton) { if (st.hasSel && st.mode !== "screen") st.clear(); else st.cancel(); return; }
            if (st.mode === "color") { st.pickColor(e.x, e.y); return; }
            if (st.mode === "window") { if (st.hoverWin) st.setSel(st.hoverWin.x, st.hoverWin.y, st.hoverWin.width, st.hoverWin.height); return; }
            if (st.mode === "screen") return;
            if (st.hasSel && e.x >= st.sx && e.x <= st.sx + st.sw && e.y >= st.sy && e.y <= st.sy + st.sh) { st.drag = "move"; st.ax = e.x; st.ay = e.y; st.start = {x: st.sx, y: st.sy, w: st.sw, h: st.sh}; return; }
            st.drag = "new"; st.ax = e.x; st.ay = e.y; st.setSel(e.x, e.y, 0, 0);
        }
        onReleased: { if (st.drag === "new" && !st.hasSel) st.clear(); st.drag = ""; }
        onDoubleClicked: if (st.hasSel) st.commit("copy")
    }

    // Selection frame, size chip, window name and resize handles.
    Item {
        id: frame
        visible: !!st.hole && st.mode !== "screen"
        x: st.hole ? st.hole.x : 0; y: st.hole ? st.hole.y : 0
        width: st.hole ? st.hole.w : 0; height: st.hole ? st.hole.h : 0
        Rectangle { anchors.fill: parent; anchors.margins: -2; color: "transparent"; border.width: 2; border.color: Theme.primary; radius: 3 }
        Rectangle {
            visible: st.hasSel
            x: 0; y: frame.y > 40 ? -34 : (frame.height > 60 ? 8 : frame.height + 8)
            width: sizeText.implicitWidth + 20; height: 26; radius: 13; color: Theme.primary
            MText { id: sizeText; anchors.centerIn: parent; text: Math.round(st.sw * st.k) + " × " + Math.round(st.sh * st.k); role: "label"; font.features: {"tnum": 1}; color: Theme.onPrimary }
        }
        Rectangle {
            visible: !!st.hoverWin
            anchors.centerIn: parent
            width: Math.min(parent.width - 16, winRow.implicitWidth + 28); height: 40; radius: 20; color: Theme.fill(Theme.level(3), .96, "menus")
            Row { id: winRow; anchors.centerIn: parent; spacing: 8
                AppIcon { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter; app: st.hoverWin ? Hub.appForWindow(st.hoverWin.w) : null; name: app ? app.icon || "" : st.hoverWin ? String(st.hoverWin.w.className || "") : "" }
                MText { anchors.verticalCenter: parent.verticalCenter; text: st.hoverWin ? (st.hoverWin.w.title || st.hoverWin.w.className || "") : ""; role: "label"; width: Math.min(implicitWidth, 360) } }
        }
        Repeater {
            model: st.hasSel && st.mode === "region" ? ["tl", "t", "tr", "r", "br", "b", "bl", "l"] : []
            Rectangle {
                id: handle
                required property string modelData
                readonly property real hx: modelData.indexOf("l") >= 0 ? 0 : modelData.indexOf("r") >= 0 ? frame.width : frame.width / 2
                readonly property real hy: modelData.indexOf("t") >= 0 ? 0 : modelData.indexOf("b") >= 0 ? frame.height : frame.height / 2
                x: hx - width / 2; y: hy - height / 2
                width: hm.containsMouse || hm.pressed ? 16 : 12; height: width; radius: width / 2
                color: "white"; border.width: 2; border.color: Theme.primary
                Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
                MouseArea {
                    id: hm
                    anchors.fill: parent; anchors.margins: -8; hoverEnabled: true
                    cursorShape: handle.modelData === "t" || handle.modelData === "b" ? Qt.SizeVerCursor : handle.modelData === "l" || handle.modelData === "r" ? Qt.SizeHorCursor
                        : handle.modelData === "tl" || handle.modelData === "br" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    property var s0: ({})
                    onPressed: e => { const p = mapToItem(st, e.x, e.y); s0 = {x: st.sx, y: st.sy, w: st.sw, h: st.sh, px: p.x, py: p.y}; st.drag = handle.modelData; }
                    onPositionChanged: e => {
                        if (!pressed) return;
                        const p = mapToItem(st, e.x, e.y), dx = p.x - s0.px, dy = p.y - s0.py, n = handle.modelData;
                        let x1 = s0.x, y1 = s0.y, x2 = s0.x + s0.w, y2 = s0.y + s0.h;
                        if (n.indexOf("l") >= 0) x1 += dx;
                        if (n.indexOf("r") >= 0) x2 += dx;
                        if (n.indexOf("t") >= 0) y1 += dy;
                        if (n.indexOf("b") >= 0) y2 += dy;
                        st.setSel(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1));
                        st.mx = p.x; st.my = p.y;
                    }
                    onReleased: st.drag = ""
                }
            }
        }
    }

    // Loupe: the pixels under the pointer, enlarged, with their position.
    Item {
        id: loupe
        readonly property real size: 132
        readonly property real zoom: 8
        visible: st.frozen && st.mx >= 0 && (st.mode === "color" || (st.mode === "region" && (!st.hasSel || (st.drag !== "" && st.drag !== "move"))))
        x: st.mx + 24 + size > st.width ? st.mx - 24 - size : st.mx + 24
        y: st.my + 24 + size + 30 > st.height ? st.my - 24 - size - 30 : st.my + 24
        width: size; height: size + 30
        Item {
            id: lens
            width: loupe.size; height: loupe.size
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect { maskEnabled: true; maskSource: lensMask; maskThresholdMin: .5; maskSpreadAtMin: 1 }
            Image {
                anchors.fill: parent
                source: shot.source; cache: true; smooth: false
                readonly property real span: loupe.size / loupe.zoom
                sourceClipRect: Qt.rect(Math.floor(st.mx * st.k - span / 2), Math.floor(st.my * st.k - span / 2), Math.ceil(span), Math.ceil(span))
            }
            // The centre pixel.
            Rectangle { anchors.centerIn: parent; width: loupe.zoom + 2; height: loupe.zoom + 2; color: "transparent"; border.width: 1; border.color: "white" }
        }
        Rectangle { id: lensMask; width: loupe.size; height: loupe.size; radius: 36; visible: false; layer.enabled: true }
        Rectangle { width: loupe.size; height: loupe.size; radius: 36; color: "transparent"; border.width: 3; border.color: Theme.primary }
        Rectangle {
            anchors.horizontalCenter: lens.horizontalCenter; y: loupe.size + 6
            width: coord.implicitWidth + 18; height: 24; radius: 12; color: Theme.fill(Theme.level(3), .96, "menus")
            MText { id: coord; anchors.centerIn: parent; text: Math.floor(st.mx * st.k) + ", " + Math.floor(st.my * st.k); role: "labelS"; font.features: {"tnum": 1} }
        }
    }

    // Mode toolbar at the top.
    Surface {
        id: modes
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24 - 16 * (1 - st.arrival); opacity: st.arrival
        width: modeRow.implicitWidth + 16; height: 60; radius: 30
        kind: "menus"; level: 3; elevated: true; translucency: Math.max(.9, Hub.prefs.glass)
        border.width: Theme.edges && !Theme.solid("menus") ? 1 : 0; border.color: Theme.glassEdge
        MouseArea { anchors.fill: parent }
        Row {
            id: modeRow
            anchors.centerIn: parent; spacing: 10
            SegmentedButtons {
                width: st.video ? 330 : 440; buttonHeight: 44; anchors.verticalCenter: parent.verticalCenter
                options: [{value: "region", label: "Region", icon: "crop_free"}, {value: "window", label: "Window", icon: "select_window"}, {value: "screen", label: "Screen", icon: "fullscreen"}].concat(st.video ? [] : [{value: "color", label: "Colour", icon: "colorize"}])
                current: st.mode
                onPicked: v => st.pickMode(v)
            }
            Rectangle { width: 1; height: 28; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            SegmentedButtons {
                width: 190; buttonHeight: 44; anchors.verticalCenter: parent.verticalCenter
                options: [{value: false, label: "Photo", icon: "photo_camera"}, {value: true, label: "Video", icon: "videocam"}]
                current: st.video
                onPicked: v => { st.video = v; if (v && st.mode === "color") st.pickMode("region"); }
            }
            // Delay: a tap cycles now, 3 and 10 seconds.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: delayRow.implicitWidth + 24; height: 44; radius: 22
                color: st.delay > 0 ? Theme.secondaryContainer : "transparent"; border.width: st.delay > 0 ? 0 : 1; border.color: Theme.alpha(Theme.text, .2)
                Row { id: delayRow; anchors.centerIn: parent; spacing: 6
                    Glyph { name: "timer"; font.pixelSize: 19; color: st.delay > 0 ? Theme.onSecondaryContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                    MText { text: st.delay > 0 ? st.delay + " s" : "Now"; role: "label"; color: st.delay > 0 ? Theme.onSecondaryContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.delay = st.delay === 0 ? 3 : st.delay === 3 ? 10 : 0 }
                Accessible.role: Accessible.Button; Accessible.name: "Delay " + (st.delay || "off")
            }
            MButton { visible: st.video; icon: st.audio ? "volume_up" : "volume_off"; compact: true; implicitWidth: 44; implicitHeight: 44; tooltip: st.audio ? "Recording sound" : "No sound"; tonal: st.audio; anchors.verticalCenter: parent.verticalCenter; onClicked: st.audio = !st.audio }
            MButton { icon: "close"; compact: true; implicitWidth: 44; implicitHeight: 44; tooltip: "Cancel · Esc"; anchors.verticalCenter: parent.verticalCenter; onClicked: st.cancel() }
        }
    }

    // Actions for the selection, next to it.
    FloatingToolbar {
        id: actions
        visible: st.hasSel && st.drag === ""
        kind: "menus"
        readonly property real below: st.sy + st.sh + 14
        x: st.clamp(st.sx + st.sw / 2 - width / 2, 12, st.width - width - 12)
        y: below + height + 44 < st.height ? below : st.sy - height - 14 > modes.y + modes.height + 8 ? st.sy - height - 14 : st.height - height - 64
        items: st.video ? [{id: "record", icon: "fiber_manual_record", text: st.delay > 0 ? "Record in " + st.delay + " s" : "Record", primary: true}]
            : [{id: "copy", icon: "content_copy", text: st.delay > 0 ? "Copy in " + st.delay + " s" : "Copy", primary: true}, {id: "save", icon: "download"}, {id: "edit", icon: "edit"}, {id: "ocr", icon: "text_fields"}].concat(Hub.aiEnabled !== false ? [{id: "ask", icon: "auto_awesome"}] : [])
        onTriggered: id => st.commit(id === "record" ? "copy" : id)
    }
    // Keys for the actions, in small chips under the toolbar.
    Row {
        visible: actions.visible && !st.video
        anchors.horizontalCenter: actions.horizontalCenter; y: actions.y + actions.height + 6; spacing: 6
        Repeater { model: [{k: "Enter", t: "Copy"}, {k: "Ctrl S", t: "Save"}, {k: "E", t: "Mark up"}, {k: "T", t: "Text"}].concat(Hub.aiEnabled !== false ? [{k: "A", t: "Ask Claude"}] : [])
            Rectangle { required property var modelData; height: 24; width: tipRow.implicitWidth + 14; radius: 12; color: Theme.alpha("#000000", .6)
                Row { id: tipRow; anchors.centerIn: parent; spacing: 5
                    MText { text: modelData.k; role: "labelS"; font.weight: Font.Bold; color: "white" }
                    MText { text: modelData.t; role: "labelS"; color: Theme.alpha("#ffffff", .8) } } } }
    }
    // What to do now, at the bottom.
    Rectangle {
        visible: !st.hasSel
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        width: hintText.implicitWidth + 32; height: 40; radius: 20; color: Theme.alpha("#000000", .6); opacity: st.arrival
        MText { id: hintText; anchors.centerIn: parent; role: "label"; color: "white"
            text: st.mode === "window" ? "Click a window · Space for a region · Esc to cancel" : st.mode === "color" ? "Click to copy a colour · Esc to cancel" : "Drag to select · Space for a window · 3 for the whole screen · Esc to cancel" }
    }
}
