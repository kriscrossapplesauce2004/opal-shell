import QtQuick
import QtQuick.Layouts

// Rich card for one activity. The same card is the open pill, the shade card, the -1 card and the home widget. Media activities show the player.
Item {
    id: card
    // The activity map from ActivityModel.js.
    property var a: ({})
    property bool compactPlayer: false
    readonly property string kind: a.kind || "neutral"
    readonly property bool isMedia: kind === "media"
    readonly property color ink: ActivityStyle.ink(kind)
    readonly property real progress: a.progress === undefined ? -1 : a.progress
    readonly property var controls: (a.controls || []).filter(c => !!(c.label || c.icon))
    signal opened()
    implicitWidth: 380
    implicitHeight: isMedia ? player.implicitHeight : body.implicitHeight

    MediaPlayerCard { id: player; visible: card.isMedia; anchors.fill: parent; small: card.compactPlayer }

    Rectangle {
        id: body
        visible: !card.isMedia
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 32
        radius: 26
        color: ActivityStyle.fill(card.kind)
        Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.opened() }
        ColumnLayout {
            id: col
            x: 16; y: 16; width: body.width - 32; spacing: 12
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; Layout.alignment: Qt.AlignTop; radius: 20
                    color: card.a.appIcon ? Theme.alpha(card.ink, .13) : ActivityStyle.accent(card.kind)
                    Glyph { anchors.centerIn: parent; visible: !card.a.appIcon; name: card.a.icon || "spark"; font.pixelSize: 22; color: ActivityStyle.onAccent(card.kind) }
                    AppIcon { anchors.centerIn: parent; visible: !!card.a.appIcon; width: 26; height: 26; style: "raw"; name: card.a.appIcon || "" }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 10; spacing: 1
                    MText { Layout.fillWidth: true; text: card.a.title || ""; role: "titleS"; color: card.ink }
                    MText { Layout.fillWidth: true; visible: text !== ""; text: card.a.subtitle || ""; role: "bodyS"; color: Theme.alpha(card.ink, .74); maximumLineCount: 2; wrapMode: Text.Wrap }
                }
                MText { visible: !!card.a.meta; text: card.a.meta || ""; role: "labelS"; color: Theme.alpha(card.ink, .7); Layout.alignment: Qt.AlignTop }
                Item {
                    visible: !!card.a.ring; Layout.preferredWidth: 58; Layout.preferredHeight: 58
                    ProgressRing { anchors.fill: parent; value: Math.max(0, card.progress); ink: card.ink; lineWidth: 5 }
                    MText { anchors.centerIn: parent; text: card.a.ringText || ""; role: "label"; font.weight: Font.Bold; font.features: {"tnum": 1}; color: card.ink }
                }
            }
            Rectangle {
                visible: !!card.a.code; Layout.fillWidth: true; Layout.preferredHeight: codeText.implicitHeight + 20; radius: 14
                color: Theme.alpha(Theme.light ? "#ffffff" : "#000000", Theme.light ? .55 : .26)
                Text {
                    id: codeText; x: 12; y: 10; width: parent.width - 24; text: card.a.code || ""; color: card.ink
                    font.family: "monospace"; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; maximumLineCount: 4; elide: Text.ElideRight
                }
            }
            ColumnLayout {
                visible: (card.progress >= 0 || card.progress === -2) && !card.a.ring; Layout.fillWidth: true; spacing: 6
                LinearProgress { Layout.fillWidth: true; value: card.progress === -2 ? -1 : card.progress; ink: card.ink }
                MText { Layout.fillWidth: true; visible: text !== ""; text: card.a.progressText || ""; role: "labelS"; color: Theme.alpha(card.ink, .74) }
            }
            Flow {
                visible: card.controls.length > 0; Layout.alignment: Qt.AlignRight; spacing: 8; layoutDirection: Qt.RightToLeft
                Layout.preferredWidth: Math.min(col.width, implicitWidth)
                Repeater {
                    model: card.controls.slice().reverse()
                    Rectangle {
                        id: action
                        required property var modelData
                        readonly property bool primary: !!modelData.primary
                        readonly property bool danger: !!modelData.danger
                        implicitWidth: actionRow.implicitWidth + (modelData.label ? 30 : 18); implicitHeight: 38; radius: 19
                        color: primary ? card.ink : Theme.alpha(card.ink, .13)
                        opacity: actionMouse.pressed ? .8 : 1
                        Row {
                            id: actionRow; anchors.centerIn: parent; spacing: 6
                            Glyph { visible: !!action.modelData.icon; name: action.modelData.icon || ""; font.pixelSize: 18; color: action.primary ? body.color : action.danger ? Theme.error : card.ink; anchors.verticalCenter: parent.verticalCenter }
                            MText { visible: !!action.modelData.label; text: action.modelData.label || ""; role: "label"; font.pixelSize: 13; font.weight: Font.DemiBold; color: action.primary ? body.color : card.ink; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: actionMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Activities.control(card.a, action.modelData) }
                        Accessible.role: Accessible.Button
                        Accessible.name: action.modelData.label || action.modelData.id
                    }
                }
            }
        }
    }
}
