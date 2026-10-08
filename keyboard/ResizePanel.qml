import QtQuick
import QtQuick.Layouts

// Resize panel: a slider for the key height.
Item {
    id: panel
    required property var keyboard
    ColumnLayout {
        anchors.fill: parent; spacing: 4
        PanelTitle { keyboard: panel.keyboard; title: "Resize"; Layout.fillWidth: true; Layout.preferredHeight: 48 }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                anchors.centerIn: parent; width: parent.width - 40; spacing: 14
                Text { text: "Key height " + Math.round(panel.keyboard.heightScale * 100) + "%"; font.family: panel.keyboard.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: panel.keyboard.foreground; anchors.horizontalCenter: parent.horizontalCenter }
                Item {
                    id: slider
                    objectName: "resizeSlider"
                    width: parent.width; height: 44
                    Accessible.role: Accessible.Slider
                    Accessible.name: "Key height"
                    readonly property real position: (panel.keyboard.heightScale - 0.8) / 0.5
                    function setFrom(x) { panel.keyboard.heightScale = Math.round((0.8 + Math.max(0, Math.min(1, (x - 22) / (width - 44))) * 0.5) * 20) / 20; }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 16; radius: 8; color: panel.keyboard.keyColor }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 22 + slider.position * (parent.width - 44); height: 16; radius: 8; color: panel.keyboard.primary }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: slider.position * (parent.width - 44); width: 44; height: 44; radius: 22; color: panel.keyboard.primary; border.width: 4; border.color: panel.keyboard.specialColor }
                    MultiPointTouchArea {
                        anchors.fill: parent; minimumTouchPoints: 1; maximumTouchPoints: 1; mouseEnabled: true
                        onPressed: points => slider.setFrom(points[0].x)
                        onUpdated: points => slider.setFrom(points[0].x)
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                    Repeater {
                        model: [{t: "Smaller", v: 0.85}, {t: "Default", v: 1}, {t: "Larger", v: 1.2}]
                        Rectangle {
                            required property var modelData
                            width: 96; height: 40; radius: 20
                            color: Math.abs(panel.keyboard.heightScale - modelData.v) < 0.01 ? panel.keyboard.secondaryContainer : panel.keyboard.keyColor
                            Text { anchors.centerIn: parent; text: parent.modelData.t; font.family: panel.keyboard.fontFamily; font.pixelSize: 14; color: panel.keyboard.foreground }
                            TapHandler { onTapped: panel.keyboard.heightScale = parent.modelData.v }
                        }
                    }
                }
            }
        }
    }
}
