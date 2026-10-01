import QtQuick
import QtQuick.Layouts

// Trackpad for the docked screen: one finger moves, tap clicks, two-finger tap right-clicks,
// two fingers scroll, press and hold then drag selects.
Item {
    id: pad
    property real speed: 1.8
    property bool holding: false
    function send(data) { Hub.command(Object.assign({action: "pointer"}, data)); }
    ColumnLayout {
        anchors.fill: parent; spacing: 10
        Rectangle {
            id: surface
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: Theme.shapeXl; color: Theme.level(2)
            border.width: pad.holding ? 3 : 0; border.color: Theme.primary
            MText { anchors.centerIn: parent; text: pad.holding ? "Dragging" : "Trackpad"; role: "headline"; color: Theme.alpha(Theme.text, .18) }
            MultiPointTouchArea {
                id: touch
                anchors.fill: parent
                maximumTouchPoints: 2
                property var last: ({})
                property real travel: 0
                property int fingers: 0
                property double began: 0
                Timer { id: hold; interval: 450; onTriggered: if (touch.fingers === 1 && touch.travel < 8) { pad.holding = true; pad.send({op: "down", button: "left"}); } }
                onPressed: points => {
                    fingers = Math.max(fingers, touchPoints.filter(p => p.pressed).length);
                    if (began === 0) { began = Date.now(); travel = 0; hold.restart(); }
                    points.forEach(p => last[p.pointId] = Qt.point(p.x, p.y));
                }
                onUpdated: points => {
                    let dx = 0, dy = 0, n = 0;
                    points.forEach(p => { const before = last[p.pointId]; if (before) { dx += p.x - before.x; dy += p.y - before.y; n++; } last[p.pointId] = Qt.point(p.x, p.y); });
                    if (!n) return;
                    dx /= n; dy /= n;
                    travel += Math.abs(dx) + Math.abs(dy);
                    const live = touchPoints.filter(p => p.pressed).length;
                    // Faster finger movement moves the cursor further.
                    const gain = pad.speed * (1 + Math.min(2, Math.hypot(dx, dy) / 12));
                    if (live >= 2) pad.send({op: "scroll", dx: -dx * .6, dy: -dy * .6});
                    else pad.send({op: "move", dx: dx * gain, dy: dy * gain});
                }
                onReleased: points => {
                    points.forEach(p => delete last[p.pointId]);
                    if (touchPoints.some(p => p.pressed)) return;
                    hold.stop();
                    const quick = Date.now() - began < 250 && travel < 10;
                    if (pad.holding) { pad.send({op: "up", button: "left"}); pad.holding = false; }
                    else if (quick) pad.send({op: "click", button: fingers >= 2 ? "right" : "left"});
                    fingers = 0; began = 0;
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: false; Layout.preferredHeight: 64; Layout.maximumHeight: 64; spacing: 10
            Repeater {
                model: [{b: "left", label: "Left"}, {b: "right", label: "Right"}]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.shapeLg
                    color: buttonArea.pressed ? Theme.primaryContainer : Theme.level(3)
                    MText { anchors.centerIn: parent; text: parent.modelData.label; role: "titleS"; color: buttonArea.pressed ? Theme.onContainer : Theme.text }
                    MouseArea { id: buttonArea; anchors.fill: parent
                        onPressed: pad.send({op: "down", button: parent.modelData.b})
                        onReleased: pad.send({op: "up", button: parent.modelData.b})
                        onCanceled: pad.send({op: "up", button: parent.modelData.b}) }
                }
            }
            MButton { Layout.fillHeight: true; implicitWidth: 64; icon: "keyboard"; contained: true; tooltip: "Keyboard"; onClicked: Hub.systemOsk("show") }
        }
    }
}
