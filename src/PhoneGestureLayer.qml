import QtQuick
import Quickshell
import Quickshell.Wayland
// Gesture feedback and edge zones for phone outputs. The feedback surface never takes input.
Scope {
    SplitDivider {}
    // One feedback surface on the output where the finger is.
    PanelWindow {
        id: feedback
        screen: PhoneState.gestureScreen || Quickshell.screens[0]
        visible: PhoneState.phase !== "" && PhoneState.phase !== "drawer" && PhoneState.gestureScreen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "opal-gesture"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
        GestureStage { anchors.fill: parent }
    }
    // Edge zones: thin input strips on both sides of phone outputs.
    Variants {
        model: Quickshell.screens.filter(sc => Hub.layoutFor(sc.width, sc.height, sc.name) === "phone" && !Hub.prefs.phoneButtons && Hub.prefs.phoneEdgeBack !== false && PhoneState.edgeZones.some(z => PhoneState.gestureAction(z, false) !== "none" || PhoneState.gestureAction(z, true) !== "none"))
        delegate: Scope {
            id: zone
            required property var modelData
            Repeater {
                model: [-1, 1]
                PanelWindow {
                    id: strip
                    required property int modelData
                    screen: zone.modelData
                    anchors { top: true; bottom: true; left: modelData < 0; right: modelData > 0 }
                    margins.top: PhoneState.barHeight + 56
                    margins.bottom: PhoneState.navHeight + 56
                    implicitWidth: 18
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.namespace: "opal-edge"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    color: "transparent"
                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        property real startX: 0
                        // The press height picks the upper or lower half of the edge; it is a fraction of the whole screen.
                        onPressed: e => { startX = e.x; PhoneState.beginEdge(zone.modelData, strip.modelData, (strip.margins.top + e.y) / zone.modelData.height); }
                        // Pull direction is inward: positive for the left edge, negative for the right.
                        onPositionChanged: e => PhoneState.moveEdge(strip.modelData < 0 ? e.x - startX : startX - e.x, strip.margins.top + e.y)
                        onReleased: PhoneState.endEdge()
                        onCanceled: PhoneState.cancel()
                    }
                }
            }
        }
    }
}
