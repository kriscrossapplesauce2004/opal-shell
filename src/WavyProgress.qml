import QtQuick
import QtQuick.Shapes
// M3 Expressive wavy linear progress: the done part waves, a gap, then the flat track and a stop dot. Progress below 0 runs the indeterminate sweep.
Item {
    id: wp
    property real progress: -1
    property color ink: Theme.primary
    property color track: Theme.alpha(Theme.primary, .22)
    property real amplitude: 3
    property real wavelength: 26
    property real thickness: 4
    property bool running: visible
    readonly property bool indeterminate: progress < 0
    implicitHeight: 14; implicitWidth: 240
    property real shown: Math.max(0, Math.min(1, progress))
    Behavior on shown { enabled: !wp.indeterminate; NumberAnimation { duration: Theme.motion(320); easing.type: Easing.OutCubic } }
    property real phase: 0
    property real sweep: 0
    NumberAnimation on phase { running: wp.running && !Theme.reduceMotion; from: 0; to: 1; duration: 1100; loops: Animation.Infinite }
    NumberAnimation on sweep { running: wp.running && wp.indeterminate; from: 0; to: 1; duration: 1600; loops: Animation.Infinite; easing.type: Easing.InOutCubic }
    // Track and wave spans in x: [track0, track1, wave0, wave1, track2, track3].
    readonly property var spans: geometry(indeterminate, shown, sweep, width, thickness)
    function geometry(indet, s, sw, w, t) {
        const r = t / 2, gap = 6;
        if (indet) {
            const span = w * .42, head = -span + (w + span) * sw;
            const a = Math.max(r, head), b = Math.min(w - r, head + span);
            return [r, a - gap, a, b, b + gap, w - r];
        }
        const end = r + (w - 2 * r) * s;
        return [0, 0, r, end, Math.min(w - r, end + (s > 0 ? gap : 0)), w - r];
    }
    // Wave points between x0 and x1; the wave settles flat at both ends so the caps meet the track.
    function wavePoints(x0, x1) {
        const mid = height / 2, pts = [];
        if (x1 - x0 < 1) return pts;
        for (let x = x0; x <= x1; x += 1.5) {
            const edge = Math.min(1, (x - x0) / 10, (x1 - x) / 10);
            pts.push(Qt.point(x, mid + Math.sin((x / wavelength - phase) * Math.PI * 2) * amplitude * Math.max(0, edge)));
        }
        return pts;
    }
    // Flat track points between x0 and x1.
    function flatPoints(x0, x1) {
        const mid = height / 2;
        return x1 - x0 < 1 ? [] : [Qt.point(x0, mid), Qt.point(x1, mid)];
    }
    Shape {
        anchors.fill: parent
        clip: true
        preferredRendererType: Shape.CurveRenderer; antialiasing: true
        ShapePath {
            strokeColor: wp.track; strokeWidth: wp.thickness; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            PathPolyline { path: wp.flatPoints(wp.spans[0], wp.spans[1]) }
        }
        ShapePath {
            strokeColor: wp.ink; strokeWidth: wp.thickness; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            PathPolyline { path: wp.wavePoints(wp.spans[2], wp.spans[3]) }
        }
        ShapePath {
            strokeColor: wp.track; strokeWidth: wp.thickness; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            PathPolyline { path: wp.flatPoints(wp.spans[4], wp.spans[5]) }
        }
    }
    // Stop indicator at the end of the track.
    Rectangle {
        visible: !wp.indeterminate && wp.shown < 1
        width: wp.thickness; height: width; radius: width / 2; color: wp.ink
        x: wp.width - width; anchors.verticalCenter: parent.verticalCenter
    }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: indeterminate ? "Working" : Math.round(shown * 100) + "%"
}
