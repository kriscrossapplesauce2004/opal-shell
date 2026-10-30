import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Safe mode: a minimal bar. It does not use Theme, Hub or the backend.
ShellRoot {
    id: root
    readonly property string reportPath: Quickshell.env("OPAL_CRASH_REPORT")
    readonly property string retryPath: Quickshell.env("OPAL_WATCHDOG_RETRY")
    readonly property var terminals: [Quickshell.env("TERMINAL"), "foot", "kitty", "alacritty"].filter(name => name && name.length > 0)
    property date now: new Date()
    property string note: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Process {
        id: opener
        command: ["xdg-open", root.reportPath]
        onExited: code => root.note = code === 0 ? "Report folder opened" : "Could not open the report folder"
    }

    Process {
        id: retry
        command: ["touch", root.retryPath]
        onExited: code => root.note = code === 0 ? "Retry requested. Opal restarts the shell." : "Could not write the retry request"
    }

    // Exit status 127 means that no candidate terminal exists.
    Process {
        id: terminal
        command: ["sh", "-c", "for name in \"$@\"; do command -v \"$name\" >/dev/null 2>&1 && exec \"$name\"; done; exit 127", "sh"].concat(root.terminals)
        onExited: code => { if (code === 127) root.note = "No terminal found. Set TERMINAL." }
    }

    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 40
        exclusiveZone: implicitHeight

        Rectangle {
            id: frame
            anchors.fill: parent
            color: "#111111"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Opal had a problem and started in safe mode"
                    color: "#f0f0f0"
                    font.family: "monospace"
                    font.pixelSize: 14
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110; height: 26; radius: 4
                    color: root.reportPath ? "#2b2b2b" : "#1a1a1a"
                    border.color: root.reportPath ? "#f0f0f0" : "#444444"
                    Text {
                        anchors.centerIn: parent
                        text: "Send report"
                        color: root.reportPath ? "#f0f0f0" : "#666666"
                        font.family: "monospace"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.reportPath.length > 0
                        onClicked: opener.running = true
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 184; height: 26; radius: 4
                    color: root.retryPath ? "#2b2b2b" : "#1a1a1a"
                    border.color: root.retryPath ? "#f0f0f0" : "#444444"
                    Text {
                        anchors.centerIn: parent
                        text: "Try normal shell again"
                        color: root.retryPath ? "#f0f0f0" : "#666666"
                        font.family: "monospace"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.retryPath.length > 0
                        onClicked: retry.running = true
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96; height: 26; radius: 4
                    color: "#2b2b2b"
                    border.color: "#f0f0f0"
                    Text {
                        anchors.centerIn: parent
                        text: "Terminal"
                        color: "#f0f0f0"
                        font.family: "monospace"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: terminal.running = true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.note
                    color: "#b8b8b8"
                    font.family: "monospace"
                    font.pixelSize: 12
                }

                Text {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.now, "HH:mm:ss")
                    color: "#f0f0f0"
                    font.family: "monospace"
                    font.pixelSize: 14
                }
            }
        }
    }
}
