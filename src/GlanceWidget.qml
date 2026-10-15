import QtQuick
import QtQuick.Effects

// At a glance: the date, the weather and one live line. It sits on the wallpaper, so the text has a soft shadow.
Item {
    id: glance
    property real big: 26
    property bool shadow: true
    readonly property var w: HomeData.weather
    readonly property var live: Activities.list.find(a => a.kind !== "media") || null
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    Column {
        id: column
        spacing: 6
        layer.enabled: glance.shadow
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.alpha("#000000", Theme.light ? .25 : .55); shadowBlur: .6; shadowVerticalOffset: 1 }
        Row {
            spacing: 10
            MText { text: Qt.formatDateTime(Hub.now, "ddd, MMM d"); font.pixelSize: glance.big; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            Glyph { visible: !!glance.w; name: glance.w ? glance.w.icon : ""; font.pixelSize: glance.big; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            MText { visible: !!glance.w; text: glance.w ? glance.w.temp + glance.w.unit : ""; font.pixelSize: glance.big; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            visible: !!glance.w || glance.live === null
            spacing: 8
            Glyph { name: glance.w ? "thermostat" : "location_on"; font.pixelSize: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            MText {
                anchors.verticalCenter: parent.verticalCenter; role: "bodyS"; color: Theme.subtext
                text: glance.w ? glance.w.text + (glance.w.high !== null ? " · " + glance.w.high + "° / " + glance.w.low + "°" : "") + (glance.w.place ? " · " + glance.w.place : "") : "Set your city for weather"
            }
            MouseArea { width: parent.width; height: parent.height; visible: !glance.w; cursorShape: Qt.PointingHandCursor; onClicked: Hub.openSettings("appearance") }
        }
        Row {
            visible: glance.live !== null
            spacing: 8
            Rectangle { width: 8; height: 8; radius: 4; color: glance.live ? ActivityStyle.accent(glance.live.kind) : "transparent"; anchors.verticalCenter: parent.verticalCenter }
            MText { anchors.verticalCenter: parent.verticalCenter; role: "bodyS"; color: Theme.subtext; text: glance.live ? glance.live.title + (glance.live.subtitle ? " · " + glance.live.subtitle : "") : ""; width: Math.min(implicitWidth, 420) }
        }
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatDateTime(Hub.now, "dddd d MMMM") + (w ? ", " + w.temp + " degrees, " + w.text : "")
}
