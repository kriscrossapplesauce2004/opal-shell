import QtQuick

// At a glance: the date, the weather and the next event, in one line under the lock clock.
Row {
    id: glance
    property color ink: "#ffffff"
    property bool compact: false
    readonly property var weather: HomeData.weather
    readonly property var next: {
        const now = Hub.now.getTime(), end = now + 86400000;
        return HomeData.events.find(e => !e.allDay && e.end > now && e.start < end) || null;
    }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    spacing: compact ? 10 : 16
    MText { text: Qt.formatDateTime(Hub.now, glance.compact ? "ddd d MMM" : "dddd d MMMM"); role: "titleS"; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
    Row {
        visible: !!glance.weather && glance.weather.temp !== undefined; spacing: 6; anchors.verticalCenter: parent.verticalCenter
        Glyph { name: glance.weather && glance.weather.icon ? glance.weather.icon : "partly_cloudy_day"; font.pixelSize: 20; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
        MText { text: glance.weather ? Math.round(glance.weather.temp) + (glance.weather.unit || "°") : ""; role: "titleS"; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
        visible: glance.next !== null; spacing: 6; anchors.verticalCenter: parent.verticalCenter
        Glyph { name: "event"; font.pixelSize: 19; color: glance.ink; anchors.verticalCenter: parent.verticalCenter }
        MText {
            readonly property var s: glance.next ? new Date(glance.next.start) : null
            text: glance.next ? glance.next.title + " " + glance.pad(s.getHours()) + ":" + glance.pad(s.getMinutes()) : ""
            role: "titleS"; color: glance.ink; anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, glance.compact ? 140 : 260); elide: Text.ElideRight
        }
    }
}
