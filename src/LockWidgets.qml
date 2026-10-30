import QtQuick

// The lock screen's widget stack: swipe between Now playing, the timer, today's calendar and device batteries. Only widgets with something to show take a page.
Item {
    id: stack
    property bool preview: false
    readonly property var order: Array.isArray(Hub.prefs.lockWidgets) ? Hub.prefs.lockWidgets : ["media", "timers", "calendar", "devices"]
    readonly property var media: Activities.byId["media"] || null
    readonly property var today: {
        const now = Hub.now.getTime(), end = new Date(Hub.now.getFullYear(), Hub.now.getMonth(), Hub.now.getDate() + 1).getTime();
        return HomeData.events.filter(e => e.end > now && e.start < end).slice(0, 2);
    }
    readonly property var pages: order.filter(k => k === "media" ? media !== null : k === "timers" ? Hub.focusRunning : k === "calendar" ? today.length > 0 : k === "devices" ? HomeData.devices.length > 0 : false)
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    implicitHeight: pages.length ? 140 : 0
    height: implicitHeight
    // The next page peeks out above the current one.
    Rectangle {
        visible: stack.pages.length > 1
        x: 20; y: 0; width: parent.width - 40; height: 120; radius: 28
        color: Theme.alpha(Theme.level(3), .4); border.width: 1; border.color: Theme.alpha("#ffffff", .08)
    }
    ListView {
        id: pager
        y: 12; width: parent.width; height: 128
        orientation: ListView.Horizontal; snapMode: ListView.SnapOneItem; highlightRangeMode: ListView.StrictlyEnforceRange
        boundsBehavior: Flickable.StopAtBounds; clip: true; interactive: !stack.preview
        model: stack.pages
        delegate: Rectangle {
            required property string modelData
            width: pager.width; height: pager.height; radius: 28
            color: Theme.alpha(Theme.level(3), .62); border.width: 1; border.color: Theme.alpha("#ffffff", .10)
            // Now playing.
            Item {
                visible: parent.modelData === "media"; anchors.fill: parent; anchors.margins: 16
                Rectangle {
                    id: cover; width: 96; height: 96; radius: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.secondaryContainer; clip: true
                    RoundedImage { anchors.fill: parent; radius: 20; visible: !!stack.media && !!stack.media.art; source: stack.media ? stack.media.art || "" : ""; decodeSize: Qt.size(192, 192) }
                    Glyph { anchors.centerIn: parent; visible: !stack.media || !stack.media.art; name: "music_note"; font.pixelSize: 36; color: Theme.onSecondaryContainer }
                }
                Column {
                    x: cover.width + 16; y: 4; width: parent.width - x - 24; spacing: 2
                    MText { width: parent.width; text: stack.media ? stack.media.title : ""; role: "title"; color: "#ffffff"; elide: Text.ElideRight }
                    MText { width: parent.width; text: stack.media ? stack.media.subtitle || "" : ""; role: "labelS"; color: Theme.subtext; elide: Text.ElideRight }
                }
                Row {
                    x: cover.width + 16; anchors.bottom: parent.bottom; spacing: 10
                    MButton { icon: "previous"; compact: true; implicitWidth: 36; implicitHeight: 36; tooltip: "Previous"; onClicked: Hub.media("previous") }
                    MButton { icon: stack.media && stack.media.playing ? "pause" : "play"; compact: true; filled: true; implicitWidth: 60; implicitHeight: 36; tooltip: "Play or pause"; onClicked: Hub.media("play-pause") }
                    MButton { icon: "skip"; compact: true; implicitWidth: 36; implicitHeight: 36; tooltip: "Next"; onClicked: Hub.media("next") }
                }
            }
            // The timer.
            Item {
                visible: parent.modelData === "timers"; anchors.fill: parent; anchors.margins: 20
                Glyph { id: timerGlyph; name: "timer"; font.pixelSize: 40; color: Theme.tertiary; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    x: timerGlyph.width + 16; anchors.verticalCenter: parent.verticalCenter
                    MText { text: "Timer"; role: "labelS"; color: Theme.subtext }
                    MText { text: Math.floor(Hub.focusSeconds / 60) + ":" + stack.pad(Hub.focusSeconds % 60); font.pixelSize: 40; font.weight: Font.Bold; font.features: {"tnum": 1}; color: "#ffffff" }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    MButton { text: "+1 min"; compact: true; implicitHeight: 36; contained: true; onClicked: Hub.focusSeconds += 60 }
                    MButton { icon: Hub.focusRunning ? "pause" : "play"; compact: true; implicitWidth: 44; implicitHeight: 44; filled: true; tooltip: "Pause"; onClicked: Hub.timerToggle() }
                }
            }
            // Today's next events.
            Column {
                visible: parent.modelData === "calendar"; anchors.fill: parent; anchors.margins: 18; spacing: 8
                MText { text: "Today"; role: "labelS"; color: Theme.subtext }
                Repeater {
                    model: stack.today
                    Row {
                        required property var modelData
                        spacing: 10
                        Rectangle { width: 4; height: 34; radius: 2; color: Theme.tertiary }
                        Column {
                            MText { text: modelData.title; role: "titleS"; color: "#ffffff" }
                            MText { readonly property date s: new Date(modelData.start); text: modelData.allDay ? "All day" : stack.pad(s.getHours()) + ":" + stack.pad(s.getMinutes()) + (modelData.location ? " · " + modelData.location : ""); role: "labelS"; color: Theme.subtext }
                        }
                    }
                }
            }
            // Device batteries.
            Column {
                visible: parent.modelData === "devices"; anchors.fill: parent; anchors.margins: 18; spacing: 10
                MText { text: "Devices"; role: "labelS"; color: Theme.subtext }
                Repeater {
                    model: HomeData.devices.slice(0, 3)
                    Row {
                        required property var modelData
                        spacing: 10
                        Glyph { name: modelData.icon; font.pixelSize: 18; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: pager.width - 120; height: 6; radius: 3; color: Theme.alpha("#ffffff", .2); anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: parent.width * modelData.percent / 100; height: 6; radius: 3; color: modelData.percent < 20 ? Theme.error : Theme.primary } }
                        MText { text: modelData.percent + "%"; role: "labelS"; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
    // Dots: which page is showing.
    Column {
        visible: stack.pages.length > 1
        anchors.right: parent.right; anchors.rightMargin: 14; y: 12 + (128 - height) / 2; spacing: 5
        Repeater { model: stack.pages.length; Rectangle { required property int index; width: 6; height: index === pager.currentIndex ? 16 : 6; radius: 3; color: Theme.alpha("#ffffff", index === pager.currentIndex ? .9 : .35) } }
    }
}
