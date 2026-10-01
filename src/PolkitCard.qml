import QtQuick
import QtQuick.Layouts
import Quickshell
// Card for an admin password request. Works with a polkit AuthFlow or test values.
Rectangle {
    id: card
    property var flow: null
    property string message: flow ? flow.message : ""
    property string identity: flow && flow.selectedIdentity ? String(flow.selectedIdentity) : (Quickshell.env("USER") || "")
    property bool failed: flow ? flow.failed : false
    property bool echo: flow ? flow.responseVisible : false
    function submit() { if (flow && input.text !== "") { flow.submit(input.text); input.text = ""; } }
    function cancel() { if (flow) flow.cancelAuthenticationRequest(); }
    width: 420; height: column.implicitHeight + 48
    radius: Theme.shapeXl
    color: Theme.level(2)
    ColumnLayout {
        id: column
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24
        spacing: 14
        Rectangle {
            Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: Theme.shapeLg
            color: Theme.primaryContainer
            Glyph { anchors.centerIn: parent; name: "admin_panel_settings"; font.pixelSize: 30; color: Theme.onContainer }
        }
        MText { text: "Admin password needed"; role: "headline"; Layout.fillWidth: true; wrapMode: Text.Wrap }
        MText { text: card.message; role: "body"; color: Theme.subtext; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 4 }
        RowLayout {
            spacing: 10
            Rectangle { width: 32; height: 32; radius: 16; color: Theme.secondaryContainer
                MText { anchors.centerIn: parent; text: card.identity.replace(/^unix-user:/, "").charAt(0).toUpperCase(); role: "label"; color: Theme.onSecondaryContainer } }
            MText { text: card.identity.replace(/^unix-user:/, ""); role: "titleS" }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 26
            color: Theme.level(3)
            border.width: input.activeFocus ? 2 : 0; border.color: card.failed ? Theme.error : Theme.primary
            TextInput {
                id: input
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter
                echoMode: card.echo ? TextInput.Normal : TextInput.Password; passwordCharacter: "●"
                color: Theme.text; font.family: Theme.font; font.pixelSize: 16
                focus: true
                Component.onCompleted: forceActiveFocus()
                onAccepted: card.submit()
                Keys.onEscapePressed: card.cancel()
                MText { anchors.verticalCenter: parent.verticalCenter; visible: input.text === ""; text: "Password"; role: "body"; color: Theme.subtext }
            }
        }
        MText { visible: card.failed; text: "That password didn't work. Try again."; role: "bodyS"; color: Theme.error }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            MButton { text: "Cancel"; onClicked: card.cancel() }
            MButton { text: "Allow"; filled: true; enabled: input.text !== ""; onClicked: card.submit() }
        }
    }
}
