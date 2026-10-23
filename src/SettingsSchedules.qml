import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// Night light, dark mode and Do not disturb on a schedule. "Sun" follows sunset and sunrise for your time zone.
Flickable {
    id: page
    contentHeight: column.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    readonly property var all: Hub.prefs.schedules || {}
    readonly property var routines: Hub.prefs.routines || [
        {id: "work-focus", name: "Work & Code Focus", icon: "code", enabled: false, when: {kind: "app", value: "code"}, do: {dnd: true, profile: "balanced"}},
        {id: "battery-guardian", name: "Low Battery Guardian", icon: "battery_saver", enabled: true, when: {kind: "battery", value: 20}, do: {profile: "power-saver"}},
        {id: "docked-power", name: "Charging Performance", icon: "bolt", enabled: false, when: {kind: "charging", value: true}, do: {profile: "performance"}},
        {id: "reading-night", name: "Evening Reading Mode", icon: "menu_book", enabled: false, when: {kind: "manual", value: true}, do: {dnd: true, nightLight: true}}
    ]
    function update(key, change) { const next = JSON.parse(JSON.stringify(all)); next[key] = Object.assign({}, next[key] || {}, change); Hub.set("schedules", next); }
    function toggleRoutine(id, enabled) {
        const next = JSON.parse(JSON.stringify(routines)).map(r => r.id === id ? Object.assign({}, r, {enabled: enabled}) : r);
        Hub.set("routines", next);
    }
    function toggleModeNow(id) {
        const active = (Hub.prefs.activeModes || []).slice();
        const i = active.indexOf(id);
        if (i >= 0) active.splice(i, 1); else active.push(id);
        const list = JSON.parse(JSON.stringify(routines)).map(r => r.id === id && i < 0 ? Object.assign({}, r, {enabled: true}) : r);
        if (i < 0) Hub.set("routines", list);
        Hub.set("activeModes", active);
    }
    function describeRoutine(r) {
        const w = r.when || {}, d = r.do || {};
        const whenStr = w.kind === "app" ? "When " + w.value + " is focused" : w.kind === "battery" ? "When battery ≤ " + w.value + "%" : w.kind === "charging" ? (w.value ? "When charging" : "On battery") : w.kind === "wifi" ? "On Wi-Fi " + w.value : "Manual mode";
        const effects = [];
        if (d.dnd !== undefined) effects.push(d.dnd ? "Do not disturb" : "Allow alerts");
        if (d.profile) effects.push(d.profile === "power-saver" ? "Battery saver" : d.profile === "performance" ? "Performance" : "Balanced power");
        if (d.nightLight) effects.push("Night light");
        if (d.light !== undefined) effects.push(d.light ? "Light theme" : "Dark theme");
        return whenStr + " → " + effects.join(", ") + " (auto-reverts)";
    }
    component Schedule: ColumnLayout {
        id: block
        property string key
        property string title
        property string icon
        property string defaultFrom
        property string defaultTo
        readonly property var item: page.all[key] || {}
        Layout.fillWidth: true; spacing: 6
        SettingToggle { Layout.fillWidth: true; first: true; last: !block.item.enabled; icon: block.icon; title: block.title; checked: !!block.item.enabled; onToggled: page.update(block.key, {enabled: !checked}) }
        Rectangle {
            visible: !!block.item.enabled; Layout.fillWidth: true; implicitHeight: inner.implicitHeight + 28
            radius: Theme.shapeLg; color: Theme.level(3)
            ColumnLayout {
                id: inner; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; spacing: 10
                SegmentedButtons {
                    Layout.fillWidth: true; current: block.item.mode || "custom"
                    options: [{value: "sun", label: "Sunset to sunrise", icon: "wb_twilight"}, {value: "custom", label: "Custom", icon: "schedule"}]
                    onPicked: value => page.update(block.key, {mode: value})
                }
                MText { visible: (block.item.mode || "custom") === "sun"; text: "Today: " + Hub.sun.sunset + " to " + Hub.sun.sunrise + (Hub.sun.estimated ? " (estimated)" : ""); role: "bodyS"; color: Theme.subtext }
                RowLayout {
                    visible: (block.item.mode || "custom") === "custom"; spacing: 10
                    MText { text: "From"; role: "body" }
                    TimeField { value: block.item.from || block.defaultFrom; onPicked: value => page.update(block.key, {from: value}) }
                    MText { text: "to"; role: "body" }
                    TimeField { value: block.item.to || block.defaultTo; onPicked: value => page.update(block.key, {to: value}) }
                }
                ColumnLayout {
                    visible: block.key === "nightLight"; Layout.fillWidth: true; spacing: 4
                    MText { text: "Warmth · " + (block.item.temperature || 4000) + " K"; role: "label"; color: Theme.subtext }
                    ExpressiveSlider { Layout.fillWidth: true; from: 0; to: 100; icon: "sun"; value: (6500 - (block.item.temperature || 4000)) / 40; onMoved: page.update(block.key, {temperature: Math.round((6500 - value * 40) / 100) * 100}) }
                }
            }
        }
    }
    component TimeField: Rectangle {
        id: field
        property string value: "00:00"
        signal picked(string value)
        width: 96; height: 40; radius: 20; color: Theme.level(4)
        TextInput {
            anchors.centerIn: parent; text: field.value; color: Theme.text; font.family: Theme.font; font.pixelSize: 16
            inputMask: "99:99"; validator: RegularExpressionValidator { regularExpression: /([01]\d|2[0-3]):[0-5]\d/ }
            onEditingFinished: if (acceptableInput && text !== field.value) field.picked(text)
        }
    }
    ColumnLayout {
        id: column; width: parent.width; spacing: 14
        MText { text: "Reversible modes & When → Do routines"; role: "labelS"; font.letterSpacing: 1; color: Theme.primary; Layout.leftMargin: 6 }
        Repeater {
            model: page.routines
            Rectangle {
                id: rCard
                required property var modelData
                readonly property bool isRunning: (Hub.activeRoutines || []).indexOf(modelData.id) >= 0 || (Hub.prefs.activeModes || []).indexOf(modelData.id) >= 0
                Layout.fillWidth: true; implicitHeight: rRow.implicitHeight + 24; radius: Theme.shapeLg
                color: isRunning ? Theme.secondaryContainer : Theme.level(3)
                RowLayout {
                    id: rRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 14 }
                    spacing: 12
                    Glyph { name: rCard.modelData.icon || "bolt"; font.pixelSize: 22; color: rCard.isRunning ? Theme.onSecondaryContainer : Theme.primary }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        RowLayout {
                            spacing: 8
                            MText { text: rCard.modelData.name; role: "titleS"; color: rCard.isRunning ? Theme.onSecondaryContainer : Theme.text }
                            Rectangle {
                                visible: rCard.isRunning
                                height: 20; width: actLbl.implicitWidth + 14; radius: 10; color: Theme.primary
                                MText { id: actLbl; anchors.centerIn: parent; text: "Active"; role: "labelS"; color: Theme.onPrimary }
                            }
                        }
                        MText { Layout.fillWidth: true; text: page.describeRoutine(rCard.modelData); role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap }
                    }
                    MButton {
                        text: (Hub.prefs.activeModes || []).indexOf(rCard.modelData.id) >= 0 ? "Stop" : "Run now"
                        compact: true; tonal: true
                        onClicked: page.toggleModeNow(rCard.modelData.id)
                    }
                    MSwitch {
                        checked: !!rCard.modelData.enabled
                        onToggled: page.toggleRoutine(rCard.modelData.id, !rCard.modelData.enabled)
                    }
                }
            }
        }
        MText { text: "Time schedules"; role: "labelS"; font.letterSpacing: 1; color: Theme.primary; Layout.leftMargin: 6; Layout.topMargin: 4 }
        MText { text: "Change things automatically at set times."; role: "bodyS"; color: Theme.subtext; Layout.leftMargin: 6 }
        Schedule { key: "nightLight"; title: "Night light"; icon: "nightlight"; defaultFrom: "21:00"; defaultTo: "07:00" }
        Schedule { key: "darkMode"; title: "Dark theme"; icon: "dark_mode"; defaultFrom: "19:00"; defaultTo: "07:00" }
        Schedule { key: "dnd"; title: "Do not disturb"; icon: "do_not_disturb_on"; defaultFrom: "23:00"; defaultTo: "07:00" }
    }
}
