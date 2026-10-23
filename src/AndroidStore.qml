import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
// Android app store: F-Droid search, category chips, featured cards, installs with live progress and an app detail pane.
Item {
    id: store
    objectName: "androidStore"
    signal openSetup()
    readonly property var s: Hub.androidStore
    readonly property bool ready: Hub.waydroid.installed
    readonly property bool wide: width > 820
    property string query: ""
    property string category: ""
    property var selected: null
    // Apps with a newer version in the catalogue, read over ADB while Android runs.
    readonly property var updates: s.updates || []
    readonly property var items: category === "Updates" ? updates : s.items || []
    readonly property var featured: !query && !category ? items.slice(0, 3) : []
    readonly property var listed: !query && !category ? items.slice(3) : items
    Component.onCompleted: { Hub.command({action: "android-store-load"}); Hub.androidSearch("", ""); Hub.command({action: "android-store-updates"}); }
    Timer { id: debounce; interval: 180; onTriggered: Hub.androidSearch(store.query, store.category) }
    onQueryChanged: debounce.restart()
    onCategoryChanged: if (category === "Updates") Hub.command({action: "android-store-updates"}); else Hub.androidSearch(query, category)
    // A finished catalogue load refreshes the current results.
    Connections { target: Hub; function onAndroidStoreChanged() { if (!Hub.androidStore.loading && Hub.androidStore.count > 0 && store.items.length === 0 && !store.query) debounce.restart(); } }
    Connections { target: Hub; function onAndroidStoreChanged() { if (store.selected && Hub.androidStore.detail && Hub.androidStore.detail.package === store.selected.package) store.selected = Hub.androidStore.detail; } }
    function size(b) { return b >= 1048576 ? (b / 1048576).toFixed(b > 104857600 ? 0 : 1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"; }
    function installed(pkg) { return (s.installed || []).indexOf(pkg) >= 0; }
    function hasUpdate(pkg) { return updates.some(u => u.package === pkg); }
    function job(pkg) { return (s.jobs || {})[pkg] || null; }
    function open(app) { selected = app; Hub.command({action: "android-store-detail", package: app.package}); }

    component AppIconImage: Item {
        property string source
        property real radius: width * .28
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.level(4)
            Glyph { anchors.centerIn: parent; name: "android"; color: Theme.subtext; font.pixelSize: parent.width * .45; visible: img.status !== Image.Ready } }
        Image {
            id: img; anchors.fill: parent; source: parent.source; asynchronous: true; cache: true; fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(parent.width * 2, parent.height * 2)
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect { maskEnabled: true; maskSource: iconMask; maskThresholdMin: .5; maskSpreadAtMin: 1 }
        }
        Rectangle { id: iconMask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
    }
    // Install control: Install, then a progress pill while it works, then Open.
    component InstallButton: Item {
        id: ib
        property var app
        readonly property var j: app ? store.job(app.package) : null
        readonly property bool busy: !!j && (j.state === "download" || j.state === "install")
        readonly property bool have: app ? store.installed(app.package) : false
        readonly property bool update: app ? store.hasUpdate(app.package) : false
        implicitWidth: busy ? 132 : btn.implicitWidth; implicitHeight: 38
        Behavior on implicitWidth { NumberAnimation { duration: Theme.motion(Theme.durMedium); easing.type: Easing.OutCubic } }
        MButton {
            id: btn; anchors.fill: parent; visible: !ib.busy; compact: true
            text: ib.update ? "Update" : ib.have ? "Open" : ib.j && ib.j.state === "failed" ? "Retry" : "Install"
            filled: !ib.have || ib.update; tonal: ib.have && !ib.update; enabled: store.ready
            onClicked: ib.have && !ib.update ? Hub.command({action: "waydroid-launch", package: ib.app.package, name: ib.app.name}) : Hub.command({action: "android-store-install", package: ib.app.package})
        }
        Rectangle {
            anchors.fill: parent; visible: ib.busy; radius: height / 2; color: Theme.primaryContainer
            RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                WavyProgress { Layout.fillWidth: true; Layout.preferredWidth: 60; Layout.preferredHeight: 12; amplitude: 2; wavelength: 16; thickness: 3; ink: Theme.onContainer; track: Theme.alpha(Theme.onContainer, .25)
                    progress: ib.j && ib.j.state === "download" ? ib.j.progress : -1 }
                MText { text: ib.j && ib.j.state === "download" ? Math.round((ib.j.progress || 0) * 100) + "%" : "…"; role: "labelS"; color: Theme.onContainer } }
        }
    }

    Loader { anchors.fill: parent; sourceComponent: store.ready ? storeView : needSetup }

    Component { id: needSetup; ColumnLayout {
        spacing: 12
        Item { Layout.fillHeight: true }
        MorphShape { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 140; Layout.preferredHeight: 140; shape: 5
            Glyph { anchors.centerIn: parent; name: "storefront"; font.pixelSize: 56; color: Theme.onContainer } }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Set up Android first"; role: "headline" }
        MText { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 420; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Apps install into Waydroid. Setup takes a few minutes and one password."; role: "body"; color: Theme.subtext }
        MButton { Layout.alignment: Qt.AlignHCenter; text: "Set up Android"; icon: "android"; filled: true; onClicked: store.openSetup() }
        Item { Layout.fillHeight: true }
    } }

    Component { id: storeView; RowLayout {
        spacing: 16
        ColumnLayout {
            visible: store.wide || !store.selected
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
            // Search pill.
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 26; color: Theme.level(3)
                border.width: field.activeFocus ? 2 : 0; border.color: Theme.primary
                RowLayout { anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 8; spacing: 10
                    Glyph { name: "search"; color: Theme.subtext }
                    TextField {
                        id: field; Layout.fillWidth: true; background: null; color: Theme.text; font.family: Theme.font; font.pixelSize: 15
                        placeholderText: store.s.count ? "Search " + store.s.count.toLocaleString(Qt.locale(), "f", 0) + " apps" : "Search apps"; placeholderTextColor: Theme.subtext
                        text: store.query; onTextEdited: store.query = text
                        Component.onCompleted: forceActiveFocus()
                    }
                    MButton { visible: store.query !== ""; icon: "close"; compact: true; implicitWidth: 38; onClicked: { store.query = ""; field.text = ""; } }
                    MButton { icon: "refresh"; compact: true; implicitWidth: 38; tooltip: "Refresh the catalogue"; enabled: !store.s.loading; onClicked: Hub.command({action: "android-store-load", force: true}) } }
            }
            // Category chips.
            ListView {
                Layout.fillWidth: true; Layout.preferredHeight: 36; orientation: ListView.Horizontal; spacing: 8; clip: true; boundsBehavior: Flickable.StopAtBounds
                model: [{name: "", label: "For you", icon: "auto_awesome"}, {name: "Installed", label: "Installed", icon: "download_done"}].concat(store.updates.length ? [{name: "Updates", label: store.updates.length + (store.updates.length === 1 ? " update" : " updates"), icon: "update"}] : []).concat((store.s.categories || []).slice(0, 14).map(c => ({name: c.name, label: c.name, icon: ""})))
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: store.category === modelData.name
                    height: 34; width: chipRow.implicitWidth + 24; radius: 10
                    color: on ? Theme.secondaryContainer : "transparent"; border.width: on ? 0 : 1; border.color: Theme.alpha(Theme.text, .2)
                    Row { id: chipRow; anchors.centerIn: parent; spacing: 6
                        Glyph { visible: parent.parent.on || modelData.icon !== ""; name: parent.parent.on ? "check" : modelData.icon; font.pixelSize: 17; color: parent.parent.on ? Theme.onSecondaryContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                        MText { text: modelData.label; role: "label"; color: parent.parent.on ? Theme.onSecondaryContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: store.category = parent.on && modelData.name !== "" ? "" : modelData.name }
                }
            }
            // Catalogue download.
            ColumnLayout { visible: store.s.loading && store.items.length === 0; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                Item { Layout.fillHeight: true }
                LoadingIndicator { Layout.alignment: Qt.AlignHCenter; contained: true; implicitWidth: 64; implicitHeight: 64 }
                MText { Layout.alignment: Qt.AlignHCenter; text: "Getting the app catalogue"; role: "title" }
                WavyProgress { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 260; progress: store.s.progress === undefined ? -1 : store.s.progress }
                Item { Layout.fillHeight: true } }
            ColumnLayout { visible: !!store.s.error && store.items.length === 0 && !store.s.loading; Layout.fillWidth: true; Layout.fillHeight: true
                Item { Layout.fillHeight: true }
                Glyph { Layout.alignment: Qt.AlignHCenter; name: "cloud_off"; font.pixelSize: 44; color: Theme.subtext }
                MText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: store.s.error || ""; role: "body"; color: Theme.subtext; wrapMode: Text.Wrap }
                MButton { Layout.alignment: Qt.AlignHCenter; text: "Try again"; tonal: true; onClicked: Hub.command({action: "android-store-load", force: true}) }
                Item { Layout.fillHeight: true } }
            GridView {
                id: grid
                visible: store.items.length > 0 || (!store.s.loading && !store.s.error)
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; boundsBehavior: Flickable.StopAtBounds
                readonly property int columns: Math.max(1, Math.floor(width / 300))
                cellWidth: width / columns; cellHeight: 92
                model: store.listed
                ScrollBar.vertical: ScrollBar {}
                header: Column {
                    width: grid.width; spacing: 12; bottomPadding: 12
                    // Updates: one calm card on the home of the store, and the Update all action on the Updates chip.
                    Rectangle {
                        visible: store.updates.length > 0 && !store.query && (store.category === "" || store.category === "Updates")
                        width: grid.width; height: visible ? 72 : 0; radius: Theme.shapeLg; color: Theme.secondaryContainer
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 12; spacing: 14
                            Glyph { name: "update"; font.pixelSize: 26; color: Theme.onSecondaryContainer }
                            ColumnLayout { Layout.fillWidth: true; spacing: 0
                                MText { text: store.updates.length === 1 ? "1 app can be updated" : store.updates.length + " apps can be updated"; role: "titleS"; color: Theme.onSecondaryContainer }
                                MText { Layout.fillWidth: true; text: store.updates.slice(0, 4).map(u => u.name).join(", ") + (store.updates.length > 4 ? "…" : ""); role: "bodyS"; color: Theme.alpha(Theme.onSecondaryContainer, .8); elide: Text.ElideRight } }
                            MButton { visible: store.category !== "Updates"; text: "View"; compact: true; onClicked: store.category = "Updates" }
                            MButton { text: "Update all"; icon: "download"; compact: true; filled: true; onClicked: Hub.command({action: "android-store-update-all"}) } }
                    }
                    // Featured: the first picks as large cards.
                    Row {
                        visible: store.featured.length > 0; spacing: 10
                        Repeater { model: store.featured
                            Rectangle {
                                id: feat
                                required property var modelData
                                required property int index
                                width: (grid.width - 20) / 3; height: 176; radius: Theme.shapeXl
                                color: [Theme.primaryContainer, Theme.tertiaryContainer, Theme.secondaryContainer][index % 3]
                                readonly property color ink: [Theme.onContainer, Theme.onTertiaryContainer, Theme.onSecondaryContainer][index % 3]
                                Rectangle { anchors.fill: parent; radius: parent.radius; color: feat.ink; opacity: featMouse.pressed ? .12 : featMouse.containsMouse ? .06 : 0 }
                                MorphShape { width: 150; height: 150; x: parent.width - 110; y: -30; shape: [2, 5, 7][feat.index % 3]; fill: Theme.alpha(feat.ink, .1); spinMs: 50000 }
                                ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 6
                                    AppIconImage { Layout.preferredWidth: 52; Layout.preferredHeight: 52; source: feat.modelData.icon }
                                    Item { Layout.fillHeight: true }
                                    MText { Layout.fillWidth: true; text: feat.modelData.name; role: "title"; color: feat.ink }
                                    MText { Layout.fillWidth: true; text: feat.modelData.summary; role: "bodyS"; color: Theme.alpha(feat.ink, .78); maximumLineCount: 2; wrapMode: Text.Wrap } }
                                InstallButton { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; app: feat.modelData; z: 2 }
                                MouseArea { id: featMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: store.open(feat.modelData) }
                            }
                        }
                    }
                    MText { text: store.query ? (store.items.length ? "Results" : "Nothing found for “" + store.query + "”") : store.category === "Installed" ? (store.items.length ? "Installed from the store" : "Nothing installed from the store yet") : store.category === "Updates" ? (store.items.length ? "Ready to update" : "Everything is up to date") : store.category || "New and updated"; role: "titleS"; color: Theme.primary; topPadding: 4 }
                }
                delegate: Item {
                    id: cell
                    required property var modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4; radius: Theme.shapeLg
                        color: store.selected && store.selected.package === cell.modelData.package ? Theme.level(3) : rowMouse.containsMouse ? Theme.level(2) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motion(Theme.durShort) } }
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 12
                            AppIconImage { Layout.preferredWidth: 52; Layout.preferredHeight: 52; source: cell.modelData.icon }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                MText { Layout.fillWidth: true; text: cell.modelData.name; role: "titleS" }
                                MText { Layout.fillWidth: true; text: cell.modelData.summary; role: "bodyS"; color: Theme.subtext; maximumLineCount: 1 }
                                MText { Layout.fillWidth: true; text: store.size(cell.modelData.size) + (cell.modelData.arm ? " · ARM" : "") + (store.hasUpdate(cell.modelData.package) ? (cell.modelData.version ? " · New version " + cell.modelData.version : " · Update ready") : store.installed(cell.modelData.package) ? " · Installed" : ""); role: "labelS"; color: Theme.muted } }
                            InstallButton { app: cell.modelData; z: 2 } }
                        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: store.open(cell.modelData) }
                    }
                }
                footer: MText { width: grid.width; topPadding: 16; bottomPadding: 8; horizontalAlignment: Text.AlignHCenter; text: "Apps come from F-Droid and are checked against the catalogue checksum. Open any .apk in Files to install it."; role: "labelS"; color: Theme.muted; wrapMode: Text.Wrap }
            }
        }
        // Detail pane.
        Rectangle {
            visible: !!store.selected
            Layout.preferredWidth: store.wide ? 360 : -1; Layout.fillWidth: !store.wide; Layout.fillHeight: true
            radius: Theme.shapeXl; color: Theme.level(2)
            Flickable {
                anchors.fill: parent; anchors.margins: 18; contentHeight: detailCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                ColumnLayout { id: detailCol; width: parent.width; spacing: 12
                    readonly property var app: store.selected || ({})
                    RowLayout { Layout.fillWidth: true
                        AppIconImage { Layout.preferredWidth: 72; Layout.preferredHeight: 72; source: detailCol.app.icon || "" }
                        Item { Layout.fillWidth: true }
                        MButton { icon: "close"; compact: true; implicitWidth: 38; onClicked: store.selected = null } }
                    MText { Layout.fillWidth: true; text: detailCol.app.name || ""; role: "headline"; wrapMode: Text.Wrap }
                    MText { Layout.fillWidth: true; text: [detailCol.app.version ? "Version " + detailCol.app.version : "", detailCol.app.license || "", detailCol.app.size ? store.size(detailCol.app.size) : ""].filter(x => x).join(" · "); role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap }
                    RowLayout { spacing: 8
                        InstallButton { app: store.selected }
                        MButton { visible: !!store.selected && store.installed(store.selected.package); text: "Uninstall"; compact: true; ink: Theme.error; onClicked: Hub.command({action: "android-store-uninstall", package: store.selected.package}) }
                        MButton { visible: !!detailCol.app.web; icon: "open_in_new"; compact: true; implicitWidth: 38; tooltip: "Website"; onClicked: Qt.openUrlExternally(detailCol.app.web) } }
                    ListView {
                        visible: (detailCol.app.screenshots || []).length > 0
                        Layout.fillWidth: true; Layout.preferredHeight: 260; orientation: ListView.Horizontal; spacing: 8; clip: true
                        model: detailCol.app.screenshots || []
                        delegate: Rectangle { required property string modelData; width: 130; height: 260; radius: Theme.shapeMd; color: Theme.level(4)
                            Image { anchors.fill: parent; source: modelData; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.height: 520 } }
                    }
                    MText { Layout.fillWidth: true; text: detailCol.app.summary || ""; role: "titleS"; wrapMode: Text.Wrap }
                    MText { Layout.fillWidth: true; text: detailCol.app.description || ""; role: "bodyS"; color: Theme.subtext; wrapMode: Text.Wrap; maximumLineCount: 40 }
                    Flow { Layout.fillWidth: true; spacing: 6
                        Repeater { model: detailCol.app.categories || []
                            Rectangle { required property string modelData; height: 28; width: catText.implicitWidth + 20; radius: 8; color: Theme.level(4)
                                MText { id: catText; anchors.centerIn: parent; text: modelData; role: "labelS" } } } }
                }
            }
        }
    } }
}
