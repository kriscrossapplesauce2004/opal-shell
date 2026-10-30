import QtQuick

// Test client for the compositor: one window with a moving dot, so frames keep flowing.
Window {
    id: win

    readonly property string tag: Qt.application.arguments.length > 1
        ? Qt.application.arguments[Qt.application.arguments.length - 1] : "client"

    width: 480
    height: 300
    visible: true
    title: "luna " + tag
    color: "#1d2630"

    Rectangle {
        id: dot
        width: 56
        height: 56
        radius: 28
        y: (win.height - height) / 2
        color: Qt.hsla((tag.length * 0.17) % 1, 0.65, 0.6, 1)

        NumberAnimation on x {
            from: 16
            to: win.width - dot.width - 16
            duration: 2400
            loops: Animation.Infinite
            easing.type: Easing.InOutQuad
        }
    }
}
