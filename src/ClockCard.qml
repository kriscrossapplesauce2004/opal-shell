import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Clock and calendar card from the Shelf's clock pill: the time, world clocks, the timer, the month and the chosen day's events.
Item {
    id: card
    property date picked: new Date(Hub.now.getFullYear(), Hub.now.getMonth(), Hub.now.getDate())
    property date shown: new Date(Hub.now.getFullYear(), Hub.now.getMonth(), 1)
    property bool addingZone: false
    readonly property real fitHeight: col.implicitHeight + 32
    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()
    readonly property int lead: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property int cells: Math.ceil((lead + days) / 7) * 7
    readonly property var dayEvents: HomeData.eventsOn(picked)
    readonly property bool pickedToday: sameDay(picked, Hub.now)
    readonly property var zones: ["Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Moscow", "Asia/Dubai", "Asia/Kolkata", "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo", "Asia/Seoul",
        "Australia/Sydney", "Pacific/Auckland", "America/Sao_Paulo", "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu", "Africa/Lagos", "Africa/Johannesburg"]
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function zoneTime(offset) {
        const t = new Date(Hub.now.getTime() + Hub.now.getTimezoneOffset() * 60000 + offset * 60000);
        return pad(t.getHours()) + ":" + pad(t.getMinutes());
    }
    function span(e) {
        if (e.allDay) return "All day";
        const s = new Date(e.start), f = new Date(e.end);
        const mins = Math.round((e.start - Hub.now.getTime()) / 60000);
        const when = Hub.now.getTime() >= e.start && Hub.now.getTime() < e.end ? " · now" : mins > 0 && mins <= 60 ? " · in " + mins + " min" : "";
        return pad(s.getHours()) + ":" + pad(s.getMinutes()) + " – " + pad(f.getHours()) + ":" + pad(f.getMinutes()) + when;
    }
    function hasEvents(day) {
        const d = new Date(year, month, day).getTime(), n = d + 86400000;
        return HomeData.events.some(e => e.start < n && e.end > d);
    }
    function addZone(z) { const list = (Hub.prefs.worldClocks || []).filter(x => x !== z); list.push(z); Hub.set("worldClocks", list.slice(-4)); addingZone = false; }
    function removeZone(z) { Hub.set("worldClocks", (Hub.prefs.worldClocks || []).filter(x => x !== z)); }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18; spacing: 12
        Row {
            spacing: 6
            MText { text: Qt.formatDateTime(Hub.now, "HH:mm"); font.pixelSize: 64; font.weight: Font.Black; font.variableAxes: {"wdth": 125, "ROND": 100}; font.features: {"tnum": 1}; color: Theme.primary }
            MText { text: Qt.formatDateTime(Hub.now, "ss"); role: "title"; color: Theme.subtext; font.features: {"tnum": 1}; anchors.bottom: parent.bottom; anchors.bottomMargin: 12 }
        }
        MText { text: Qt.formatDateTime(Hub.now, "dddd d MMMM"); role: "titleS"; color: Theme.subtext; Layout.topMargin: -12 }
        // World clocks. The add chip offers common zones.
        Flow {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: HomeData.clocks
                Chip { required property var modelData; icon: "public"; text: modelData.label + " " + card.zoneTime(modelData.offset); onClicked: card.removeZone(modelData.zone)
                    Accessible.description: "Click to remove" }
            }
            Chip { icon: card.addingZone ? "close" : "add"; text: (HomeData.clocks || []).length ? "" : "World clock"; onClicked: card.addingZone = !card.addingZone }
        }
        Flow {
            visible: card.addingZone; Layout.fillWidth: true; spacing: 6
            Repeater {
                model: card.zones.filter(z => (Hub.prefs.worldClocks || []).indexOf(z) < 0)
                Chip { required property string modelData; text: modelData.split("/").pop().replace("_", " "); onClicked: card.addZone(modelData) }
            }
        }
        // The timer: running with its time, else quick starts.
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 64; radius: 20
            color: Hub.focusRunning ? Theme.tertiaryContainer : Theme.level(3)
            readonly property color ink: Hub.focusRunning ? Theme.onTertiaryContainer : Theme.text
            Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "timer"; font.pixelSize: 22; color: parent.ink }
            Column {
                x: 52; anchors.verticalCenter: parent.verticalCenter
                MText { text: Hub.focusRunning ? "Timer" : "Timer"; role: "labelS"; color: parent.parent.ink }
                MText { text: Math.floor(Hub.focusSeconds / 60) + ":" + card.pad(Hub.focusSeconds % 60); role: "title"; font.features: {"tnum": 1}; color: parent.parent.ink }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                MButton { visible: !Hub.focusRunning; text: "5 min"; compact: true; implicitHeight: 34; contained: true; onClicked: { Hub.focusSeconds = 300; Hub.timerToggle(); } }
                MButton { visible: !Hub.focusRunning; text: "25 min"; compact: true; implicitHeight: 34; contained: true; onClicked: { Hub.focusSeconds = 1500; Hub.timerToggle(); } }
                MButton { visible: Hub.focusRunning; text: "+1 min"; compact: true; implicitHeight: 34; contained: true; onClicked: Hub.focusSeconds += 60 }
                MButton { visible: Hub.focusRunning; icon: "pause"; compact: true; implicitWidth: 40; implicitHeight: 40; tonal: true; tooltip: "Pause"; onClicked: Hub.timerToggle() }
            }
        }
        // Month.
        RowLayout {
            Layout.fillWidth: true
            MText { text: Qt.formatDate(card.shown, "MMMM yyyy"); role: "titleS"; Layout.fillWidth: true }
            MButton { icon: "chevron_left"; compact: true; implicitWidth: 34; implicitHeight: 34; tooltip: "Previous month"; onClicked: card.shown = new Date(card.year, card.month - 1, 1) }
            MButton { icon: "chevron_right"; compact: true; implicitWidth: 34; implicitHeight: 34; tooltip: "Next month"; onClicked: card.shown = new Date(card.year, card.month + 1, 1) }
        }
        Grid {
            id: monthGrid
            Layout.preferredWidth: col.width; columns: 7
            readonly property real cell: col.width / 7
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                MText { required property string modelData; width: monthGrid.cell; horizontalAlignment: Text.AlignHCenter; text: modelData; role: "labelS"; color: Theme.subtext }
            }
            Repeater {
                model: card.cells
                Item {
                    required property int index
                    readonly property int day: index - card.lead + 1
                    readonly property bool inMonth: day >= 1 && day <= card.days
                    readonly property bool today: inMonth && card.sameDay(new Date(card.year, card.month, day), Hub.now)
                    readonly property bool chosen: inMonth && card.sameDay(new Date(card.year, card.month, day), card.picked)
                    width: monthGrid.cell; height: 36
                    Rectangle { anchors.centerIn: parent; width: 32; height: 32; radius: 16; visible: parent.today || parent.chosen
                        color: parent.today ? Theme.primary : "transparent"; border.width: parent.chosen && !parent.today ? 2 : 0; border.color: Theme.primary }
                    MText { anchors.centerIn: parent; text: parent.inMonth ? parent.day : ""; role: "label"; font.features: {"tnum": 1}; color: parent.today ? Theme.onPrimary : Theme.text }
                    Rectangle { visible: parent.inMonth && card.hasEvents(parent.day); anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 4; height: 4; radius: 2
                        color: parent.today ? Theme.primary : Theme.tertiary }
                    MouseArea { anchors.fill: parent; enabled: parent.inMonth; cursorShape: Qt.PointingHandCursor; onClicked: card.picked = new Date(card.year, card.month, parent.day) }
                }
            }
        }
        // The chosen day's events.
        MText { text: card.pickedToday ? "Today" : Qt.formatDate(card.picked, "dddd d MMMM"); role: "labelS"; color: Theme.subtext }
        Repeater {
            model: card.dayEvents.slice(0, 5)
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool hot: HomeData.attention !== null && HomeData.attention.start === modelData.start && HomeData.attention.title === modelData.title
                Layout.fillWidth: true; implicitHeight: 56
                topLeftRadius: index === 0 ? 20 : 6; topRightRadius: topLeftRadius
                bottomLeftRadius: index === Math.min(4, card.dayEvents.length - 1) ? 20 : 6; bottomRightRadius: bottomLeftRadius
                color: hot ? Theme.tertiaryContainer : Theme.level(3)
                Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 4; height: 32; radius: 2; color: parent.hot ? Theme.tertiary : Theme.primary }
                Column {
                    x: 26; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 26 - (join.visible ? join.width + 20 : 12)
                    MText { width: parent.width; text: modelData.title; role: "titleS"; elide: Text.ElideRight; color: parent.parent.hot ? Theme.onTertiaryContainer : Theme.text }
                    MText { width: parent.width; text: card.span(modelData) + (modelData.location ? " · " + modelData.location : ""); role: "labelS"; elide: Text.ElideRight
                        color: parent.parent.hot ? Theme.onTertiaryContainer : Theme.subtext }
                }
                MButton { id: join; visible: !!modelData.join; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    icon: "videocam"; text: "Join"; compact: true; implicitHeight: 36; filled: parent.hot; tonal: !parent.hot; onClicked: { Qt.openUrlExternally(modelData.join); Hub.close(); } }
            }
        }
        MText {
            visible: card.dayEvents.length === 0; Layout.fillWidth: true; wrapMode: Text.Wrap; role: "bodyS"; color: Theme.subtext
            text: HomeData.events.length ? "Nothing planned." : "No calendars yet. Sync one with vdirsyncer, or drop .ics files into ~/.local/share/opal/calendar."
        }
    }
    ControllerFocus { anchors.fill: parent; root: card; priority: 5; onBack: Hub.close() }
}
