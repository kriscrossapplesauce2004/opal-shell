import QtQuick

// Lock screen clock faces: Stacked (hours over minutes) and Thin (one light line). The colour comes from the lock preferences.
Item {
    id: face
    property string kind: ["stacked", "thin"].indexOf(Hub.prefs.lockFace) >= 0 ? Hub.prefs.lockFace : "stacked"
    property string tone: Hub.prefs.lockColor || "primary"
    property real size: 150
    readonly property color ink: tone === "white" ? "#ffffff" : tone === "tertiary" ? Theme.tertiary : tone === "primary" ? Theme.primary : tone
    readonly property color soft: Theme.mix(ink, "#ffffff", .55)
    implicitWidth: kind === "stacked" ? stacked.implicitWidth : thin.implicitWidth
    implicitHeight: kind === "stacked" ? stacked.implicitHeight : thin.implicitHeight
    Column {
        id: stacked
        visible: face.kind === "stacked"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: -face.size * .5
        MText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(Hub.now, "HH"); font.pixelSize: face.size; font.weight: Font.Black
            font.variableAxes: ({"wdth": 125, "ROND": 100}); font.features: {"tnum": 1}; color: face.ink }
        MText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(Hub.now, "mm"); font.pixelSize: face.size; font.weight: Font.Black
            font.variableAxes: ({"wdth": 125, "ROND": 100}); font.features: {"tnum": 1}; color: face.soft }
    }
    MText {
        id: thin
        visible: face.kind === "thin"
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(Hub.now, "HH:mm"); font.pixelSize: face.size * .85; font.weight: Font.Light
        font.variableAxes: ({"wdth": 100, "ROND": 0}); font.features: {"tnum": 1}; color: face.tone === "primary" ? "#ffffff" : face.ink
    }
}
