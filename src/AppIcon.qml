import QtQuick
import QtQuick.Effects
import Quickshell
// App icon in the chosen style: raw theme icon, squircle backplate, or themed monochrome.
Item {
    id: icon
    property var app: null
    property string name: app ? app.icon || "" : ""
    property string style: ["raw","squircle","themed"].indexOf(Hub.prefs.iconStyle) >= 0 ? Hub.prefs.iconStyle : "raw"
    readonly property bool plated: style !== "raw"
    implicitWidth: 48; implicitHeight: 48
    Rectangle {
        anchors.fill: parent
        visible: icon.plated
        radius: width * .3
        color: icon.style === "themed" ? Theme.primaryContainer : Theme.level(4)
    }
    Image {
        id: image
        anchors.centerIn: parent
        width: icon.plated ? parent.width * .66 : parent.width; height: width
        source: icon.name ? Quickshell.iconPath(icon.name, true) : ""
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true; cache: true; smooth: true
        visible: status === Image.Ready && icon.style !== "themed"
    }
    MultiEffect {
        anchors.fill: image
        source: image
        visible: icon.style === "themed" && image.status === Image.Ready
        colorization: 1
        colorizationColor: Theme.onContainer
        brightness: Theme.light ? -.15 : .1
    }
    Glyph {
        visible: image.status !== Image.Ready
        anchors.centerIn: parent
        name: Hub.glyphForApp(icon.app)
        color: icon.style === "themed" ? Theme.onContainer : Theme.primary
        font.pixelSize: parent.width * .55
    }
    Rectangle {
        visible: Hub.isAndroidApp(icon.app) && Hub.prefs.waydroidBadge !== false && icon.width >= 32
        anchors.right: parent.right; anchors.bottom: parent.bottom
        width: Math.max(14, Math.round(icon.width * .32)); height: width; radius: width / 2
        color: Theme.tertiaryContainer; border.width: 1.5; border.color: Theme.base
        Glyph { anchors.centerIn: parent; name: "smartphone"; font.pixelSize: Math.round(parent.width * .65); color: Theme.onTertiaryContainer }
    }
}
