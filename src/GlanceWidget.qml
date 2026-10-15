import QtQuick
import QtQuick.Effects

// At a glance: the date, the weather and one live line. It sits on the wallpaper, so the text has a soft shadow.
Item {
    id: glance
    property real big: 26
    property bool shadow: true
    // Over light wallpaper the text is dark with a light glow.
    property bool onLight: false
    readonly property color ink: onLight ? "#1d1b1e" : Theme.text
    readonly property color softInk: onLight ? Theme.alpha("#1d1b1e", .78) : Theme.subtext
    readonly property var w: HomeData.weather
    readonly property var live: Activities.list.find(a => a.kind !== "media") || null
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    Column {
        id: column
        spacing: 6
        // The software renderer cannot draw the shadow effect, so the text stays plain there.
        layer.enabled: glance.shadow && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: glance.onLight ? Theme.alpha("#ffffff", .6) : Theme.alpha("#000000", Theme.light ? .25 : .55); shadowBlur: .6; shadowVerticalOffset: glance.onLight ? 0 : 1 }
        Row {
            spacing: 10
            MText { text: Qt.formatDateTime(Hub.now, "ddd, MMM d"); font.pixelSize: glance.big; font.weight: Font.DemiBold; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
            Glyph { visible: !!glance.w; name: glance.w ? glance.w.icon : ""; font.pixelSize: glance.big; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
            MText { visible: !!glance.w; text: glance.w ? glance.w.temp + glance.w.unit : ""; font.pixelSize: glance.big; font.weight: Font.DemiBold; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            visible: !!glance.w || glance.live === null
            spacing: 8
            Glyph { name: glance.w ? "thermostat" : "location_on"; font.pixelSize: 16; color: glance.softInk; anchors.verticalCenter: parent.verticalCenter }
            MText {
                anchors.verticalCenter: parent.verticalCenter; role: "bodyS"; color: glance.softInk
                text: glance.w ? glance.w.text + (glance.w.high !== null ? " · " + glance.w.high + "° / " + glance.w.low + "°" : "") + (glance.w.place ? " · " + glance.w.place : "") : "Set your city for weather"
            }
            TapHandler { enabled: !glance.w; onTapped: Hub.openSettings("appearance") }
        }
        Row {
            visible: glance.live !== null
            spacing: 8
            Rectangle { width: 8; height: 8; radius: 4; color: glance.live ? ActivityStyle.accent(glance.live.kind) : "transparent"; anchors.verticalCenter: parent.verticalCenter }
            MText { anchors.verticalCenter: parent.verticalCenter; role: "bodyS"; color: glance.softInk; text: glance.live ? glance.live.title + (glance.live.subtitle ? " · " + glance.live.subtitle : "") : ""; width: Math.min(implicitWidth, 420) }
        }
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatDateTime(Hub.now, "dddd d MMMM") + (w ? ", " + w.temp + " degrees, " + w.text : "")
}
