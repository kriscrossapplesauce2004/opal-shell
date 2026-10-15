import QtQuick

// The snap layouts card: six layouts, Maximize and Center. Picking a cell sends it to the window.
Rectangle {
                id: card
                signal picked(var cell)
                // The same layouts as floating_mode.LAYOUTS.
                readonly property var layouts: [
                    [[0, 0, .5, 1], [.5, 0, .5, 1]],
                    [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
                    [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
                    [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]],
                    [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]],
                    [[0, 0, .25, 1], [.25, 0, .5, 1], [.75, 0, .25, 1]]
                ]
                width: grid.implicitWidth + 32; height: column.implicitHeight + 32; radius: 28
                color: Theme.level(3); border.width: 1; border.color: Theme.outline
                MouseArea { anchors.fill: parent }
                Column {
                    id: column
                    anchors.centerIn: parent; spacing: 12
                    MText { text: "Snap the window"; role: "titleS"; leftPadding: 4 }
                    Grid {
                        id: grid
                        columns: 3; spacing: 12
                        Repeater {
                            model: card.layouts
                            Rectangle {
                                id: layout
                                required property var modelData
                                width: 112; height: 72; radius: 14; color: Theme.alpha(Theme.text, .05)
                                Repeater {
                                    model: layout.modelData
                                    Rectangle {
                                        id: cellRect
                                        required property var modelData
                                        x: 6 + modelData[0] * (layout.width - 12) + 2; y: 6 + modelData[1] * (layout.height - 12) + 2
                                        width: modelData[2] * (layout.width - 12) - 4; height: modelData[3] * (layout.height - 12) - 4
                                        radius: 7
                                        color: cellMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.text, .18)
                                        Behavior on color { ColorAnimation { duration: Theme.motion(100) } }
                                        MouseArea { id: cellMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked(cellRect.modelData) }
                                        Accessible.role: Accessible.Button
                                        Accessible.name: "Snap to " + Math.round(cellRect.modelData[2] * 100) + "% by " + Math.round(cellRect.modelData[3] * 100) + "%"
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        spacing: 8
                        MButton { text: "Maximize"; icon: "fullscreen"; compact: true; tonal: true; onClicked: card.picked([0, 0, 1, 1]) }
                        MButton { text: "Center"; icon: "center_focus_strong"; compact: true; onClicked: card.picked([.15, .1, .7, .8]) }
                    }
                }
            }
