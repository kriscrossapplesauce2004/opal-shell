import QtQuick
import QtQuick.Controls
// Markup for a screenshot: pen, highlighter, arrow, box, text and pixelate over the image, with undo, then copy or save at full resolution.
Item {
    id: mk
    property string path: ""
    signal done()
    focus: true
    property string tool: "arrow"
    property color ink: "#FF4D4F"
    property int weight: 1
    property var shapes: []
    onShapesChanged: ink_.requestPaint()
    property var redo: []
    property var live: null
    property var typing: null
    readonly property var swatches: ["#FF4D4F", "#FFC53D", "#52C41A", "#4096FF", "#FFFFFF", "#1F1F1F"]
    readonly property real imgW: photo.implicitWidth
    readonly property real imgH: photo.implicitHeight
    // Strokes and text grow with the image, so a 4K shot does not get hairlines.
    readonly property real unit: Math.max(1, Math.min(imgW, imgH) / 900)
    readonly property real stroke: [3, 6, 11][weight] * unit
    readonly property real fontPx: [22, 32, 46][weight] * unit
    function push(shape) { shapes = shapes.concat([shape]); redo = []; ink_.requestPaint(); }
    function undo() { if (!shapes.length) return; redo = redo.concat([shapes[shapes.length - 1]]); shapes = shapes.slice(0, -1); ink_.requestPaint(); }
    function again() { if (!redo.length) return; shapes = shapes.concat([redo[redo.length - 1]]); redo = redo.slice(0, -1); ink_.requestPaint(); }
    function commitText() {
        if (typing && editor.text.trim() !== "") push({t: "text", color: String(ink), size: fontPx, x: typing.x, y: typing.y, text: editor.text});
        typing = null; editor.text = ""; mk.forceActiveFocus();
    }
    // Export renders the paper at the image's own size, so marks keep full resolution.
    function exportTo(copy) {
        commitText();
        paper.grabToImage(result => {
            if (!result.saveToFile(mk.path)) { Hub.message("Could not save the marked-up screenshot"); return; }
            if (copy) Hub.command({action: "capture-copy", path: mk.path});
            else Hub.message("Saved to Pictures/Screenshots");
            mk.done();
        }, Qt.size(imgW, imgH));
    }
    Keys.onPressed: e => {
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier, key = e.key;
        if (ctrl && key === Qt.Key_Z && !shift) undo();
        else if (ctrl && (key === Qt.Key_Y || (key === Qt.Key_Z && shift))) again();
        else if (ctrl && key === Qt.Key_C) exportTo(true);
        else if (ctrl && key === Qt.Key_S) exportTo(false);
        else if (key === Qt.Key_Escape) mk.done();
        else if (key === Qt.Key_P) tool = "pen";
        else if (key === Qt.Key_H) tool = "highlight";
        else if (key === Qt.Key_A) tool = "arrow";
        else if (key === Qt.Key_B || key === Qt.Key_R) tool = "box";
        else if (key === Qt.Key_T) tool = "text";
        else if (key === Qt.Key_X) tool = "pixelate";
        else return;
        e.accepted = true;
    }
    Component.onCompleted: forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.base, .94) }

    // Viewport: the paper is scaled to fit, but keeps the image's pixel size for export.
    Item {
        id: viewport
        anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom; margins: 32 }
        readonly property real fit: mk.imgW > 0 ? Math.min(1, width / mk.imgW, height / mk.imgH) : 1
        Item {
            id: paper
            width: mk.imgW; height: mk.imgH
            x: (viewport.width - width * viewport.fit) / 2; y: (viewport.height - height * viewport.fit) / 2
            transform: Scale { xScale: viewport.fit; yScale: viewport.fit }
            Image { id: photo; source: mk.path ? "file://" + mk.path : ""; cache: false; anchors.fill: parent }
            // Pixelated areas: the photo under the area, drawn from a tiny texture without smoothing.
            Repeater {
                model: mk.shapes.filter(s => s.t === "pix").concat(mk.live && mk.live.t === "pix" ? [mk.live] : [])
                ShaderEffectSource {
                    required property var modelData
                    x: modelData.x; y: modelData.y; width: Math.max(1, modelData.w); height: Math.max(1, modelData.h)
                    sourceItem: photo; sourceRect: Qt.rect(x, y, width, height); live: false; smooth: false
                    textureSize: Qt.size(Math.max(1, Math.round(width / (14 * mk.unit))), Math.max(1, Math.round(height / (14 * mk.unit))))
                }
            }
            Canvas {
                id: ink_
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                onPaint: {
                    const c = getContext("2d"); c.reset();
                    const all = mk.shapes.concat(mk.live ? [mk.live] : []);
                    for (const s of all) {
                        c.lineCap = "round"; c.lineJoin = "round";
                        if (s.t === "pen" || s.t === "highlight") {
                            if (s.pts.length < 2) continue;
                            c.globalAlpha = s.t === "highlight" ? .38 : 1;
                            c.lineCap = s.t === "highlight" ? "butt" : "round";
                            c.lineWidth = s.t === "highlight" ? s.size * 3.2 : s.size; c.strokeStyle = s.color;
                            c.beginPath(); c.moveTo(s.pts[0], s.pts[1]);
                            for (let i = 2; i < s.pts.length; i += 2) c.lineTo(s.pts[i], s.pts[i + 1]);
                            c.stroke(); c.globalAlpha = 1;
                        } else if (s.t === "arrow") {
                            const dx = s.x2 - s.x1, dy = s.y2 - s.y1, len = Math.hypot(dx, dy);
                            if (len < 4) continue;
                            const head = Math.min(len * .45, s.size * 4.2), ang = Math.atan2(dy, dx);
                            c.lineWidth = s.size; c.strokeStyle = s.color; c.fillStyle = s.color;
                            c.beginPath(); c.moveTo(s.x1, s.y1); c.lineTo(s.x2 - Math.cos(ang) * head * .6, s.y2 - Math.sin(ang) * head * .6); c.stroke();
                            c.beginPath(); c.moveTo(s.x2, s.y2);
                            c.lineTo(s.x2 - head * Math.cos(ang - .45), s.y2 - head * Math.sin(ang - .45));
                            c.lineTo(s.x2 - head * Math.cos(ang + .45), s.y2 - head * Math.sin(ang + .45));
                            c.closePath(); c.fill();
                        } else if (s.t === "box") {
                            c.lineWidth = s.size; c.strokeStyle = s.color;
                            const r = Math.min(s.size * 2.5, Math.abs(s.w) / 2, Math.abs(s.h) / 2);
                            c.beginPath(); c.roundedRect(s.x, s.y, s.w, s.h, r, r); c.stroke();
                        } else if (s.t === "text") {
                            c.font = "bold " + Math.round(s.size) + "px '" + Theme.font + "'";
                            c.lineWidth = Math.max(2, s.size / 7); c.strokeStyle = s.color === "#1F1F1F" ? "#ffffff" : "#000000"; c.globalAlpha = .55;
                            c.strokeText(s.text, s.x, s.y + s.size); c.globalAlpha = 1;
                            c.fillStyle = s.color; c.fillText(s.text, s.x, s.y + s.size);
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: mk.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                property real x0: 0
                property real y0: 0
                onPressed: e => {
                    if (mk.typing) { mk.commitText(); return; }
                    x0 = e.x; y0 = e.y;
                    if (mk.tool === "text") { mk.typing = {x: e.x, y: e.y}; editor.forceActiveFocus(); return; }
                    if (mk.tool === "pen" || mk.tool === "highlight") mk.live = {t: mk.tool, color: String(mk.ink), size: mk.stroke, pts: [e.x, e.y]};
                    else if (mk.tool === "arrow") mk.live = {t: "arrow", color: String(mk.ink), size: mk.stroke, x1: e.x, y1: e.y, x2: e.x, y2: e.y};
                    else mk.live = {t: mk.tool === "box" ? "box" : "pix", color: String(mk.ink), size: mk.stroke, x: e.x, y: e.y, w: 0, h: 0};
                }
                onPositionChanged: e => {
                    const s = mk.live;
                    if (!s) return;
                    if (s.t === "pen" || s.t === "highlight") s.pts.push(e.x, e.y);
                    else if (s.t === "arrow") { s.x2 = e.x; s.y2 = e.y; }
                    else { s.x = Math.min(x0, e.x); s.y = Math.min(y0, e.y); s.w = Math.abs(e.x - x0); s.h = Math.abs(e.y - y0); }
                    mk.live = Object.assign({}, s);
                    ink_.requestPaint();
                }
                onReleased: {
                    const s = mk.live;
                    mk.live = null;
                    if (s && ((s.pts && s.pts.length > 2) || (s.t === "arrow" && Math.hypot(s.x2 - s.x1, s.y2 - s.y1) > 4) || (s.w > 3 && s.h > 3))) mk.push(s);
                    else ink_.requestPaint();
                }
            }
            // Text being typed, at the click point.
            TextField {
                id: editor
                visible: !!mk.typing
                x: mk.typing ? mk.typing.x - 4 : 0; y: mk.typing ? mk.typing.y - 4 : 0
                width: Math.max(160 * mk.unit, contentWidth + 40); height: mk.fontPx * 1.5
                font.family: Theme.font; font.pixelSize: mk.fontPx; font.bold: true; color: mk.ink
                background: Rectangle { color: Theme.alpha("#000000", .25); border.width: 2 * mk.unit; border.color: mk.ink; radius: 6 * mk.unit }
                onAccepted: mk.commitText()
                Keys.onEscapePressed: { mk.typing = null; text = ""; mk.forceActiveFocus(); }
            }
        }
    }

    // Toolbar: tools, colour, weight, undo and redo, then copy, save and close.
    Surface {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter; y: 20
        width: barRow.implicitWidth + 20; height: 64; radius: 32
        kind: "menus"; level: 3; elevated: true; translucency: Math.max(.92, Hub.prefs.glass)
        border.width: Theme.edges && !Theme.solid("menus") ? 1 : 0; border.color: Theme.glassEdge
        Row {
            id: barRow
            anchors.centerIn: parent; spacing: 6
            Repeater {
                model: [{id: "pen", icon: "draw", tip: "Pen · P"}, {id: "highlight", icon: "ink_highlighter", tip: "Highlighter · H"}, {id: "arrow", icon: "north_east", tip: "Arrow · A"},
                        {id: "box", icon: "rectangle", tip: "Box · B"}, {id: "text", icon: "title", tip: "Text · T"}, {id: "pixelate", icon: "blur_on", tip: "Pixelate · X"}]
                Rectangle {
                    required property var modelData
                    readonly property bool on: mk.tool === modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44; height: 44; radius: tm.pressed ? 14 : 22
                    color: on ? Theme.primary : "transparent"
                    Behavior on radius { NumberAnimation { duration: Theme.motion(Theme.durShort) } }
                    Rectangle { anchors.fill: parent; radius: parent.radius; color: parent.on ? Theme.onPrimary : Theme.stateLayer; opacity: tm.containsMouse ? .08 : 0 }
                    Glyph { anchors.centerIn: parent; name: modelData.icon; color: parent.on ? Theme.onPrimary : Theme.text }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { mk.commitText(); mk.tool = modelData.id; } }
                    ToolTip.visible: tm.containsMouse; ToolTip.text: modelData.tip; ToolTip.delay: 500
                    Accessible.role: Accessible.RadioButton; Accessible.name: modelData.tip; Accessible.checked: on
                }
            }
            Rectangle { width: 1; height: 28; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: mk.swatches
                Rectangle {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14; color: modelData; border.width: 1; border.color: Theme.alpha(Theme.text, .25)
                    Rectangle { anchors.fill: parent; anchors.margins: -5; radius: 19; color: "transparent"; border.width: 2; border.color: Theme.primary; visible: Qt.colorEqual(mk.ink, modelData) }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: mk.ink = modelData }
                    Accessible.role: Accessible.RadioButton; Accessible.name: "Colour " + modelData
                }
            }
            // Weight: three dots of growing size.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; radius: 22; color: wm.containsMouse ? Theme.alpha(Theme.text, .08) : "transparent"
                Rectangle { anchors.centerIn: parent; width: [6, 11, 17][mk.weight]; height: width; radius: width / 2; color: mk.ink; border.width: 1; border.color: Theme.alpha(Theme.text, .3) }
                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mk.weight = (mk.weight + 1) % 3 }
                Accessible.role: Accessible.Button; Accessible.name: "Stroke " + ["thin", "medium", "thick"][mk.weight]
            }
            Rectangle { width: 1; height: 28; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            MButton { icon: "undo"; compact: true; implicitWidth: 44; implicitHeight: 44; enabled: mk.shapes.length > 0; opacity: enabled ? 1 : .38; tooltip: "Undo · Ctrl Z"; anchors.verticalCenter: parent.verticalCenter; onClicked: mk.undo() }
            MButton { icon: "redo"; compact: true; implicitWidth: 44; implicitHeight: 44; enabled: mk.redo.length > 0; opacity: enabled ? 1 : .38; tooltip: "Redo · Ctrl Shift Z"; anchors.verticalCenter: parent.verticalCenter; onClicked: mk.again() }
            Rectangle { width: 1; height: 28; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            MButton { icon: "content_copy"; text: "Copy"; filled: true; compact: true; implicitHeight: 44; anchors.verticalCenter: parent.verticalCenter; onClicked: mk.exportTo(true) }
            MButton { icon: "download"; compact: true; implicitWidth: 44; implicitHeight: 44; tonal: true; tooltip: "Save · Ctrl S"; anchors.verticalCenter: parent.verticalCenter; onClicked: mk.exportTo(false) }
            MButton { icon: "close"; compact: true; implicitWidth: 44; implicitHeight: 44; tooltip: "Close · Esc"; anchors.verticalCenter: parent.verticalCenter; onClicked: mk.done() }
        }
    }
}
