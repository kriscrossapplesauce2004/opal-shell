import QtQuick

// Top bar: task list on the left, clock on the right.
Rectangle {
    id: bar

    required property var shell

    property date now: new Date()

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: shell.barHeight
    color: "#e6141a22"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: bar.now = new Date()
    }

    Text {
        id: clock
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: "#e8ecf2"
        font.pixelSize: 14
        text: Qt.formatTime(bar.now, "HH:mm:ss")
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: bar.shell.clients

            // One task per client; click focuses and raises it, the cross asks it to close.
            Rectangle {
                id: task

                required property var modelData
                readonly property bool active: modelData.focused
                readonly property string label: modelData.toplevel.title || modelData.toplevel.appId || "window"

                height: 24
                width: Math.min(220, titleText.implicitWidth + closeText.implicitWidth + 30)
                radius: 6
                color: active ? "#3a5a8c" : "#263040"

                // Below the labels, so the cross keeps its own clicks.
                MouseArea {
                    anchors.fill: parent
                    onClicked: bar.shell.focusClient(task.modelData)
                }

                Text {
                    id: titleText
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, task.width - closeText.implicitWidth - 24)
                    elide: Text.ElideRight
                    color: "#e8ecf2"
                    font.pixelSize: 13
                    text: task.label
                }

                Text {
                    id: closeText
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeArea.containsMouse ? "#ffffff" : "#8a94a6"
                    font.pixelSize: 14
                    text: "×"

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: task.modelData.toplevel.sendClose()
                    }
                }
            }
        }
    }
}
