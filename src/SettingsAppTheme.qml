import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// Send Opal's colours to other apps. Each app gets its own small file and one include line.
Flickable {
    id: page
    contentHeight: column.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    readonly property var targets: Hub.prefs.themeExport || []
    function toggle(id) {
        const next = targets.slice(); const i = next.indexOf(id);
        if (i >= 0) { next.splice(i, 1); Hub.command({action: "theme-export-remove", targets: [id]}); } else next.push(id);
        Hub.set("themeExport", next);
    }
    ColumnLayout {
        id: column; width: parent.width; spacing: 4
        MText { text: "Apps follow your Opal colours and update when you change them."; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap; Layout.fillWidth: true; Layout.leftMargin: 6; Layout.bottomMargin: 10 }
        Repeater {
            model: [
                {id: "gtk", title: "GTK and GNOME apps", icon: "web_asset", detail: "Accent and surface colours"},
                {id: "kitty", title: "Kitty terminal", icon: "terminal", detail: "Terminal colours, reloaded live"},
                {id: "qt", title: "Qt apps", icon: "widgets", detail: "Pick the Opal scheme in qt6ct"},
                {id: "hyprland", title: "Window borders", icon: "select_window", detail: "Active and inactive borders"}
            ]
            SettingToggle {
                required property var modelData
                required property int index
                Layout.fillWidth: true; first: index === 0; last: index === 3
                icon: modelData.icon; title: modelData.title; description: modelData.detail
                checked: page.targets.indexOf(modelData.id) >= 0
                onToggled: page.toggle(modelData.id)
            }
        }
        MText { text: "Chrome has no theme file to write, so it isn't listed."; role: "labelS"; color: Theme.subtext; Layout.leftMargin: 6; Layout.topMargin: 10 }
    }
}
