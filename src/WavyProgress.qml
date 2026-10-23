import QtQuick
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
    onPhaseChanged: canvas.requestPaint()
    onShownChanged: canvas.requestPaint()
    onSweepChanged: if (indeterminate) canvas.requestPaint()
    onInkChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d"); c.reset();
            const w = width, mid = height / 2, t = wp.thickness, gap = 6;
            c.lineCap = "round"; c.lineWidth = t;
            function wave(x0, x1) {
                if (x1 - x0 < 1) return;
                c.beginPath();
                for (let x = x0; x <= x1; x += 1.5) {
                    // The wave settles flat at both ends, so the caps meet the track cleanly.
                    const edge = Math.min(1, (x - x0) / 10, (x1 - x) / 10);
                    const y = mid + Math.sin((x / wp.wavelength - wp.phase) * Math.PI * 2) * wp.amplitude * Math.max(0, edge);
                    if (x === x0) c.moveTo(x, y); else c.lineTo(x, y);
                }
                c.strokeStyle = wp.ink; c.stroke();
            }
            function flat(x0, x1) {
                if (x1 - x0 < 1) return;
                c.beginPath(); c.moveTo(x0, mid); c.lineTo(x1, mid); c.strokeStyle = wp.track; c.stroke();
            }
            const r = t / 2;
            if (wp.indeterminate) {
                const span = w * .42, head = -span + (w + span) * wp.sweep;
                const a = Math.max(r, head), b = Math.min(w - r, head + span);
                flat(r, a - gap); wave(a, b); flat(b + gap, w - r);
                return;
            }
            const end = r + (w - 2 * r) * wp.shown;
            wave(r, end);
            flat(Math.min(w - r, end + (wp.shown > 0 ? gap : 0)), w - r);
            // Stop indicator at the end of the track.
            if (wp.shown < 1) { c.beginPath(); c.arc(w - r, mid, r, 0, Math.PI * 2); c.fillStyle = wp.ink; c.fill(); }
        }
    }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: indeterminate ? "Working" : Math.round(shown * 100) + "%"
}
