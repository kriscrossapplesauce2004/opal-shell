import QtQuick
import Quickshell
import Quickshell.Wayland

// While a window is dragged in floating mode, this shows where a drop snaps it. The frame morphs from zone to zone; input passes through.
Scope {
    id: preview
    // The latest snapPreview event from the backend: monitor, zone and the rectangle relative to the monitor.
    property var target: null
    readonly property bool shown: !!target && !!target.rect
    property var lastRect: [0, 0, 0, 0]
    property string lastZone: ""
    property real reveal: 0
    readonly property var labels: ({left: "Left half", right: "Right half", top: "Maximize", topleft: "Top left", topright: "Top right", bottomleft: "Bottom left", bottomright: "Bottom right"})
    readonly property var icons: ({left: "splitscreen_left", right: "splitscreen_right", top: "fullscreen", topleft: "grid_view", topright: "grid_view", bottomleft: "grid_view", bottomright: "grid_view"})
    // The handler can run before the shown binding updates, so it checks the event itself.
    onTargetChanged: if (target && target.rect) { lastRect = target.rect; lastZone = target.zone; }
    onShownChanged: { grow.to = shown ? 1 : 0; grow.restart(); }
    NumberAnimation { id: grow; target: preview; property: "reveal"; duration: Theme.motion(grow.to > 0 ? 220 : 160); easing.type: Easing.BezierSpline; easing.bezierCurve: grow.to > 0 ? Theme.emphasizedDecelerate : Theme.emphasizedAccelerate }
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => preview.target && s.name === preview.target.monitor) || Quickshell.screens[0]
        visible: preview.shown || preview.reveal > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "opal-snap-preview"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
        Rectangle {
            id: frame
            // The first zone grows in place; later zones morph the frame across.
            x: preview.lastRect[0]; y: preview.lastRect[1]; width: preview.lastRect[2]; height: preview.lastRect[3]
            Behavior on x { enabled: preview.reveal > .5; NumberAnimation { duration: Theme.motion(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
            Behavior on y { enabled: preview.reveal > .5; NumberAnimation { duration: Theme.motion(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
            Behavior on width { enabled: preview.reveal > .5; NumberAnimation { duration: Theme.motion(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
            Behavior on height { enabled: preview.reveal > .5; NumberAnimation { duration: Theme.motion(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
            opacity: preview.reveal
            scale: .94 + .06 * preview.reveal
            radius: Theme.shapeLg
            color: Theme.alpha(Theme.primaryContainer, .3)
            border.width: 2; border.color: Theme.alpha(Theme.primary, .85)
            // A soft inner edge so the frame reads over light and dark windows.
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: parent.radius - 2; color: "transparent"; border.width: 6; border.color: Theme.alpha(Theme.primary, .14) }
            Rectangle {
                id: chip
                anchors.centerIn: parent
                width: chipRow.implicitWidth + 32; height: 44; radius: 22
                color: Theme.primary
                Row {
                    id: chipRow
                    anchors.centerIn: parent; spacing: 8
                    Glyph { name: preview.icons[preview.lastZone] || "crop_square"; font.pixelSize: 20; color: Theme.onPrimary; anchors.verticalCenter: parent.verticalCenter }
                    MText { text: preview.labels[preview.lastZone] || ""; color: Theme.onPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
