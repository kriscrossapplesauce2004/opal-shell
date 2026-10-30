import QtQuick
import QtQuick.Layouts
// Lock screen: a live preview, then the clock face, what sits under it, the widget stack, the corner shortcuts and what works while locked.
SettingsPage {
    id: lockPage
    property bool phonePreview: false
    readonly property var widgetNames: ({media: "Now playing", timers: "Timer", calendar: "Today's calendar", devices: "Device batteries"})
    readonly property var widgets: Array.isArray(Hub.prefs.lockWidgets) ? Hub.prefs.lockWidgets : ["media", "timers", "calendar", "devices"]
    readonly property var shortcutOptions: [
        {id: "", name: "None", icon: "block"}, {id: "tile:torch", name: "Flashlight", icon: "flashlight_on"}, {id: "tile:dnd", name: "Do not disturb", icon: "do_not_disturb_on"},
        {id: "tile:awake", name: "Keep awake", icon: "coffee"}, {id: "tile:theme", name: "Dark theme", icon: "dark_mode"}, {id: "tile:mic", name: "Microphone", icon: "mic"},
        {id: "tile:saver", name: "Battery saver", icon: "battery_saver"}, {id: "tile:focus", name: "Timer", icon: "timer"}, {id: "tile:wifi", name: "Wi-Fi", icon: "wifi"}, {id: "tile:bluetooth", name: "Bluetooth", icon: "bluetooth"}]
    readonly property var shortcuts: Hub.prefs.lockShortcuts || ({})
    function setShortcut(side, value) { const next = Object.assign({}, shortcuts); next[side] = value; Hub.set("lockShortcuts", next); }
    function toggleWidget(id) { const list = widgets.slice(), i = list.indexOf(id); if (i >= 0) list.splice(i, 1); else list.push(id); Hub.set("lockWidgets", list); }
    function moveWidget(id, delta) { const list = widgets.slice(), i = list.indexOf(id), j = i + delta; if (i < 0 || j < 0 || j >= list.length) return; list.splice(i, 1); list.splice(j, 0, id); Hub.set("lockWidgets", list); }

    // Live preview: the real lock scene, scaled down and not interactive.
    ColumnLayout {
        Layout.fillWidth: true; spacing: 10
        Rectangle {
            id: frame
            readonly property real srcW: lockPage.phonePreview ? 412 : 1280
            readonly property real srcH: lockPage.phonePreview ? 915 : 800
            readonly property real k: Math.min(1, (lockPage.phonePreview ? 220 : Math.min(parent.width, 560)) / srcW)
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: srcW * k; Layout.preferredHeight: srcH * k
            radius: 24; clip: true; color: Theme.base
            LockScene {
                width: frame.srcW; height: frame.srcH; scale: frame.k; transformOrigin: Item.TopLeft
                mode: "lock"; preview: true; enabled: false; userName: ""
            }
        }
        SegmentedButtons {
            Layout.alignment: Qt.AlignHCenter
            options: [{label: "Desktop", value: false}, {label: "Phone", value: true}]
            current: lockPage.phonePreview; onPicked: value => lockPage.phonePreview = value
        }
    }
    SettingsGroup {
        title: "Clock"
        ChoiceGroup { Layout.fillWidth: true
            icon: "schedule"; title: "Clock face"
            options: [{id: "stacked", name: "Stacked", icon: "view_agenda"}, {id: "thin", name: "Thin", icon: "remove"}]
            current: Hub.prefs.lockFace || "stacked"; onPicked: id => Hub.set("lockFace", id)
        }
        ChoiceGroup { Layout.fillWidth: true
            icon: "palette"; title: "Clock colour"
            options: [{id: "primary", name: "Accent"}, {id: "tertiary", name: "Second accent"}, {id: "white", name: "White"}]
            current: Hub.prefs.lockColor || "primary"; onPicked: id => Hub.set("lockColor", id)
        }
    }
    SettingsGroup {
        title: "Under the clock"
        SettingToggle { icon: "wb_sunny"; title: "At a glance"; description: "Date, weather and your next event"; checked: Hub.prefs.lockGlance !== false; onToggled: Hub.set("lockGlance", !checked) }
        SettingToggle { icon: "timelapse"; title: "Live activities"; description: "Timers, downloads, music and more"; checked: Hub.prefs.lockActivities !== false; onToggled: Hub.set("lockActivities", !checked) }
    }
    SettingsGroup {
        title: "Widget stack"
        Repeater {
            model: lockPage.widgets.concat(Object.keys(lockPage.widgetNames).filter(k => lockPage.widgets.indexOf(k) < 0))
            SettingRow {
                id: widgetRow
                required property string modelData
                readonly property bool shown: lockPage.widgets.indexOf(modelData) >= 0
                icon: ({media: "music_note", timers: "timer", calendar: "calendar_month", devices: "devices"})[modelData]
                title: lockPage.widgetNames[modelData]; description: shown ? "Swipe the stack to reach it" : "Hidden"
                toggle: true; checked: shown; onActivated: lockPage.toggleWidget(modelData)
                MButton { visible: widgetRow.shown; icon: "arrow_upward"; compact: true; implicitWidth: 34; implicitHeight: 34; tooltip: "Earlier"; enabled: lockPage.widgets.indexOf(widgetRow.modelData) > 0; onClicked: lockPage.moveWidget(widgetRow.modelData, -1) }
                MButton { visible: widgetRow.shown; icon: "arrow_downward"; compact: true; implicitWidth: 34; implicitHeight: 34; tooltip: "Later"; enabled: lockPage.widgets.indexOf(widgetRow.modelData) < lockPage.widgets.length - 1; onClicked: lockPage.moveWidget(widgetRow.modelData, 1) }
            }
        }
    }
    SettingsGroup {
        title: "Corner shortcuts"
        ChoiceGroup { Layout.fillWidth: true; icon: "west"; title: "Left corner"; detail: "Hold it to fire"; options: lockPage.shortcutOptions; current: lockPage.shortcuts.left !== undefined ? lockPage.shortcuts.left : ""; onPicked: id => lockPage.setShortcut("left", id) }
        ChoiceGroup { Layout.fillWidth: true; icon: "east"; title: "Right corner"; detail: "Hold it to fire"; options: lockPage.shortcutOptions; current: lockPage.shortcuts.right !== undefined ? lockPage.shortcuts.right : ""; onPicked: id => lockPage.setShortcut("right", id) }
    }
    SettingsGroup {
        title: "While locked"
        ChoiceGroup { Layout.fillWidth: true
            icon: "notifications"; title: "Notifications"
            options: [{id: "off", name: "Hide"}, {id: "count", name: "Count only"}, {id: "title", name: "Titles"}, {id: "full", name: "Full text"}]
            current: Hub.prefs.lockNotifications || "title"; onPicked: id => Hub.set("lockNotifications", id)
        }
        SettingToggle { icon: "tune"; title: "Quick Settings"; description: "Tiles that show your data still ask you to unlock"; checked: Hub.prefs.lockQuickSettings !== false; onToggled: Hub.set("lockQuickSettings", !checked) }
        SettingToggle { icon: "reply"; title: "Reply from the lock screen"; description: "Replies and actions run once you unlock"; checked: Hub.prefs.lockReply !== false; onToggled: Hub.set("lockReply", !checked) }
        SettingToggle { icon: "dark_mode"; title: "Ambient clock"; description: "A dim clock after a while"; checked: Hub.prefs.ambientClock !== false; onToggled: Hub.set("ambientClock", !checked) }
        SettingToggle { icon: "dialpad"; title: "Shuffle the PIN pad"; checked: !!Hub.prefs.lockScramblePin; onToggled: Hub.set("lockScramblePin", !checked) }
    }
}
