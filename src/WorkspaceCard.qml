import QtQuick

// Workspace overview card: one mini map per workspace with its real window layout over the wallpaper, and a tile for a new workspace.
Item {
    id: card
    property var screenObj: null
    signal picked()
    readonly property var spaces: (Hub.status.workspaces || []).slice().sort((a, b) => a - b)
    readonly property int current: Number(Hub.status.workspace)
    // The monitor in layout coordinates, so window positions map onto the tiles.
    readonly property var monitor: {
        const name = screenObj ? screenObj.name : "";
        const list = Hub.status.monitors || [];
        const m = list.find(x => x.name === name) || list[0] || {x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0};
        const turned = (m.transform || 0) % 2 === 1, scale = m.scale || 1;
        return {name: m.name || "", x: m.x || 0, y: m.y || 0, w: (turned ? m.height : m.width) / scale || 1920, h: (turned ? m.width : m.height) / scale || 1080};
    }
    readonly property real tileW: 216
    readonly property real tileH: Math.max(96, Math.min(170, tileW * monitor.h / monitor.w))
    readonly property real maxW: screenObj ? screenObj.width - 24 : 1200
    implicitWidth: Math.min(maxW, strip.contentWidth + 32)
    implicitHeight: header.height + tileH + 70

    Rectangle {
        anchors.fill: parent; radius: 32
        color: Theme.light ? Theme.surfaceLowest : Theme.level(3)
        border.width: 1; border.color: Theme.glassEdge
    }
    Row {
        id: header
        x: 20; y: 16; spacing: 10; height: 28
        Glyph { name: "space_dashboard"; font.pixelSize: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        MText { text: "Workspaces"; role: "titleS"; anchors.verticalCenter: parent.verticalCenter }
        MText { text: card.spaces.length + " open"; role: "labelS"; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
    }
    Flickable {
        id: strip
        x: 16; y: header.y + header.height + 14
        width: parent.width - 32; height: card.tileH + 34
        contentWidth: row.implicitWidth; contentHeight: height
        flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds; clip: true
        Row {
            id: row
            spacing: 12
            Repeater {
                model: card.spaces
                Column {
                    id: space
                    required property var modelData
                    readonly property int ws: Number(modelData)
                    readonly property bool here: ws === card.current
                    readonly property var wins: Hub.windows.filter(w => Number(w.workspace) === ws && (!card.monitor.name || !w.monitor || w.monitor === card.monitor.name))
                    spacing: 8
                    Item {
                        width: card.tileW; height: card.tileH
                        Rectangle { anchors.fill: parent; radius: 18; color: Theme.level(4) }
                        RoundedImage {
                            anchors.fill: parent; radius: 18; opacity: .55
                            visible: !!Hub.prefs.wallpaperPath
                            source: Hub.prefs.wallpaperPath || ""
                            decodeSize: Qt.size(card.tileW * 2, card.tileH * 2)
                        }
                        // The real window layout, scaled down. Each window shows its app icon.
                        Repeater {
                            model: space.wins
                            Rectangle {
                                required property var modelData
                                readonly property var at: modelData.at || [0, 0]
                                readonly property var size: modelData.size || [0, 0]
                                readonly property bool full: !!modelData.fullscreen || size[0] <= 0
                                x: full ? 4 : Math.max(4, (at[0] - card.monitor.x) / card.monitor.w * card.tileW)
                                y: full ? 4 : Math.max(4, (at[1] - card.monitor.y) / card.monitor.h * card.tileH)
                                width: full ? card.tileW - 8 : Math.max(18, Math.min(card.tileW - 4 - x, size[0] / card.monitor.w * card.tileW))
                                height: full ? card.tileH - 8 : Math.max(18, Math.min(card.tileH - 4 - y, size[1] / card.monitor.h * card.tileH))
                                radius: 8
                                color: Theme.alpha(Theme.surfaceHighest, .94)
                                border.width: 1; border.color: Theme.alpha(Theme.text, .14)
                                AppIcon { anchors.centerIn: parent; width: Math.min(30, parent.width * .55, parent.height * .55); height: width; app: Hub.appForWindow(parent.modelData) }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent; visible: space.wins.length === 0
                            width: emptyText.implicitWidth + 20; height: 26; radius: 13; color: Theme.alpha(Theme.base, .78)
                            MText { id: emptyText; anchors.centerIn: parent; text: "Empty"; role: "labelS"; color: Theme.subtext }
                        }
                        Rectangle { anchors.fill: parent; radius: 18; color: "transparent"; border.width: space.here ? 3 : 0; border.color: Theme.primary }
                        Rectangle { anchors.fill: parent; radius: 18; color: Theme.stateLayer; opacity: tileTap.pressed ? .16 : tileHover.hovered ? .08 : 0 }
                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: tileTap; onTapped: { card.picked(); Hub.workspace(space.ws); } }
                        Accessible.role: Accessible.Button
                        Accessible.name: "Workspace " + space.ws + (space.wins.length ? ", " + space.wins.length + " windows" : ", empty")
                    }
                    Row {
                        x: 2; spacing: 8
                        Rectangle {
                            width: 24; height: 24; radius: 12; color: space.here ? Theme.primary : Theme.alpha(Theme.text, .1)
                            MText { anchors.centerIn: parent; text: String(space.ws); role: "labelS"; font.weight: Font.Bold; color: space.here ? Theme.onPrimary : Theme.text }
                        }
                        MText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: space.here ? "Current" : space.wins.length ? space.wins.length + (space.wins.length === 1 ? " window" : " windows") : "Empty"
                            role: "labelS"; color: space.here ? Theme.primary : Theme.subtext
                        }
                    }
                }
            }
            Column {
                spacing: 8
                Item {
                    width: card.tileH * .8; height: card.tileH
                    Rectangle { anchors.fill: parent; radius: 18; color: Theme.alpha(Theme.primary, newHover.hovered ? .16 : .1); border.width: 1; border.color: Theme.alpha(Theme.primary, .4) }
                    Glyph { anchors.centerIn: parent; name: "add"; font.pixelSize: 30; color: Theme.primary }
                    HoverHandler { id: newHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { card.picked(); Hub.command({action: "workspace-empty"}); } }
                    Accessible.role: Accessible.Button; Accessible.name: "New workspace"
                }
                MText { x: 2; height: 24; verticalAlignment: Text.AlignVCenter; text: "New"; role: "labelS"; color: Theme.subtext }
            }
        }
    }
}
