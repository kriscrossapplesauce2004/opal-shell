import QtQuick
import QtQuick.Shapes
Item {
    id:f
    property color fill: Theme.primary
    property int lobes: 10
    property real depth: 0.08
    property real phase: 0
    clip: true
    // Flower outline: 360 samples around the centre, lobes set by depth and phase.
    function outline(w, h) {
        const angleStep=Math.PI/180;
        const centerX=w*.5; const centerY=h*.5;
        const radiusBase=Math.min(w,h)*Math.min(1,.5/(.46+depth*.5));
        const offset=phase*Math.PI/180;
        const pts=[];
        for(let i=0;i<=360;i++) {
            const a=i*angleStep;
            const r=radiusBase*(.46+depth*.5*Math.cos(lobes*(a-offset)));
            pts.push(Qt.point(centerX+Math.cos(a)*r, centerY+Math.sin(a)*r));
        }
        return pts;
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer; antialiasing: true
        ShapePath {
            fillColor: f.fill; strokeColor: "transparent"; strokeWidth: 0; fillRule: ShapePath.WindingFill
            PathPolyline { path: f.outline(f.width, f.height) }
        }
    }
}
