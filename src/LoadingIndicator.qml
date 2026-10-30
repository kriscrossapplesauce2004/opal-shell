import QtQuick
import QtQuick.Shapes
// M3 Expressive loading indicator: one shape that morphs through the expressive set and turns, for waits of a few seconds.
Item {
    id: li
    property bool contained: false
    property bool running: visible
    property color ink: contained ? Theme.onContainer : Theme.primary
    property color container: Theme.primaryContainer
    implicitWidth: 48; implicitHeight: 48
    // Polar shapes as lobes and depth: soft burst, cookie 9, pentagon, pill, sunny, cookie 4, oval.
    readonly property var shapes: [[10,.10],[9,.16],[5,.14],[2,.22],[8,.12],[4,.2],[2,.08]]
    property real t: 0
    property real turn: 0
    NumberAnimation on t { running: li.running && !Theme.reduceMotion; from: 0; to: li.shapes.length; duration: li.shapes.length * 650; loops: Animation.Infinite }
    NumberAnimation on turn { running: li.running && !Theme.reduceMotion; from: 0; to: 360; duration: 4550; loops: Animation.Infinite }
    Rectangle { visible: li.contained; anchors.fill: parent; radius: width / 2; color: li.container }
    // Outline of the shape at the current step and turn, 180 samples around.
    function outline(w, h) {
        const n = shapes.length, i = Math.floor(t) % n, j = (i + 1) % n;
        // Each step holds the shape briefly, then eases into the next one.
        const raw = t - Math.floor(t), k = raw < .35 ? 0 : (1 - Math.cos((raw - .35) / .65 * Math.PI)) / 2;
        const a = shapes[i], b = shapes[j], cx = w / 2, cy = h / 2, base = w * .5 / 1.18;
        const off = turn * Math.PI / 180, pts = [];
        for (let s = 0; s <= 180; s++) {
            const ang = s / 180 * Math.PI * 2;
            const ra = 1 + a[1] * Math.cos(a[0] * (ang - off)), rb = 1 + b[1] * Math.cos(b[0] * (ang - off));
            // The two-lobe shapes stretch into a pill instead of a peanut.
            const r = base * (ra + (rb - ra) * k);
            pts.push(Qt.point(cx + Math.cos(ang) * r, cy + Math.sin(ang) * r));
        }
        return pts;
    }
    Shape {
        id: shape
        anchors.centerIn: parent
        width: parent.width * (li.contained ? .66 : 1); height: width
        clip: true
        preferredRendererType: Shape.CurveRenderer; antialiasing: true
        ShapePath {
            fillColor: li.ink; strokeColor: "transparent"; strokeWidth: 0; fillRule: ShapePath.WindingFill
            PathPolyline { path: li.outline(shape.width, shape.height) }
        }
    }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: "Loading"
}
