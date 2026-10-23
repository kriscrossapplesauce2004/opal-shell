import QtQuick
// Gesture feedback: a live card follows the finger over a quiet wallpaper, neighbours appear when it rests, and the back bubble.
Item {
    id: stage
    readonly property string phase: PhoneState.phase
    readonly property bool settling: PhoneState.outcome !== ""
    readonly property bool cardPhase: phase === "home" || phase === "recents" || phase === "switch"
    // Settle: 0 follows the finger and 1 is the end pose of the outcome.
    property real settle: 0
    NumberAnimation on settle {
        id: settleAnim; from: 0; to: 1; running: false; duration: Theme.motion(240)
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate
        onFinished: PhoneState.finish()
    }
    Connections {
        target: PhoneState
        function onOutcomeChanged() { if (PhoneState.outcome !== "") { stage.settle = 0; settleAnim.restart(); } }
        function onPhaseChanged() { if (PhoneState.phase === "") { settleAnim.stop(); stage.settle = 0; } }
    }
    readonly property real p: PhoneState.progress
    readonly property var pose: cardPhase && phase !== "switch" ? PhoneState.cardPose() : ({k: 1, x: 0, y: 0, backdrop: 1})
    readonly property var slot: PhoneState.recentsSlot(PhoneState.gestureScreen)
    readonly property var inset: PhoneState.recentsInsets(PhoneState.gestureScreen)
    // The wallpaper backdrop fades in with the swipe. The status and navigation bars stay visible above and below it.
    Item {
        y: stage.inset.top; width: parent.width; height: parent.height - stage.inset.top - stage.inset.bottom
        opacity: stage.cardPhase ? (stage.settling && PhoneState.outcome === "cancel" ? (1 - stage.settle) * stage.pose.backdrop : stage.pose.backdrop) : 0
        visible: opacity > 0
        clip: true
        PhoneBackdrop { y: -stage.inset.top; width: stage.width; height: stage.height; soft: 1 }
        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.base, .35) }
    }
    // Neighbours fade in once the finger rests, at the places they take in recents.
    Repeater {
        model: [-1, 1]
        GestureCard {
            required property int modelData
            visible: opacity > 0 && stage.phase !== "switch"
            opacity: stage.phase === "recents" && !stage.settling ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasizedDecelerate } }
            // Older apps sit to the left, as in recents.
            entry: modelData < 0 ? PhoneState.previousWindow() : null
            width: stage.width; height: stage.height
            scale: current.scale; transformOrigin: Item.Center; radius: current.radius
            x: current.x + modelData * (stage.width * current.scale + stage.slot.gap * current.scale / stage.slot.k)
            y: current.y
        }
    }
    // The moving card follows the finger: its bottom edge stays under it while it shrinks. Home shrinks it away; switch slides it.
    GestureCard {
        id: current
        visible: stage.cardPhase
        entry: PhoneState.activeWindow()
        readonly property real endShrink: PhoneState.outcome === "home" ? .12 : 1
        readonly property real k: stage.settling ? stage.pose.k + (endShrink - stage.pose.k) * stage.settle : stage.pose.k
        width: stage.width; height: stage.height
        scale: stage.phase === "switch" ? .86 : k
        transformOrigin: Item.Center
        radius: 12 + 28 * (1 - Math.min(1, scale))
        x: stage.phase === "switch" ? PhoneState.dx * (stage.settling && PhoneState.outcome === "switch" ? 1 + stage.settle : 1) : stage.pose.x * (stage.settling ? 1 - stage.settle : 1)
        y: stage.phase === "switch" ? 0 : stage.pose.y * (stage.settling ? 1 - stage.settle : 1)
        opacity: stage.settling && PhoneState.outcome === "home" ? 1 - stage.settle : 1
    }
    // The next app slides in from the side opposite to the swipe.
    GestureCard {
        visible: stage.phase === "switch"
        entry: PhoneState.dx > 0 ? PhoneState.previousWindow() : PhoneState.neighbour(1)
        width: stage.width; height: stage.height; scale: .86; radius: 40
        x: PhoneState.dx > 0 ? PhoneState.dx - stage.width * 1.04 : PhoneState.dx + stage.width * 1.04
    }
    // Back: a bubble leans out of the edge and fills when the swipe is long enough.
    Rectangle {
        id: bubble
        visible: stage.phase === "back"
        property real pull: PhoneState.edgeHeld ? width + 12 : PhoneState.progress * 64
        Behavior on pull { enabled: PhoneState.edgeHeld; NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
        width: 44 + (PhoneState.progress >= 1 ? 6 : 0); height: 56; radius: width / 2
        // The bubble follows the finger up and down the edge.
        y: Math.max(16, Math.min(stage.height - height - 16, (PhoneState.dy || stage.height * .5) - height / 2))
        x: PhoneState.edge < 0 ? -width + pull + (stage.settling ? -stage.settle * width : 0) : stage.width - pull + (stage.settling ? stage.settle * width : 0)
        color: PhoneState.progress >= 1 ? Theme.primary : Theme.level(4)
        Behavior on color { ColorAnimation { duration: Theme.motion(120) } }
        Glyph { anchors.verticalCenter: parent.verticalCenter; x: PhoneState.edgeHeld ? 14 : (parent.width - width) / 2; name: PhoneState.pendingAction === "back" || PhoneState.pendingAction === "" ? "chevron_left" : PhoneState.actionInfo(PhoneState.pendingAction).icon; rotation: PhoneState.pendingAction === "back" && PhoneState.edge > 0 ? 180 : 0; font.pixelSize: 26; color: PhoneState.progress >= 1 ? Theme.onPrimary : Theme.text }
        // Holding switches to the second action; the bubble stretches into a pill with its name.
        states: State {
            when: PhoneState.edgeHeld
            PropertyChanges { bubble.width: heldLabel.implicitWidth + 64 }
        }
        Behavior on width { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphasized } }
        MText { id: heldLabel; visible: PhoneState.edgeHeld; anchors.verticalCenter: parent.verticalCenter; x: 46; text: PhoneState.actionInfo(PhoneState.pendingAction).label; role: "label"; color: Theme.onPrimary }
    }
}
