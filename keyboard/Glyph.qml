import QtQuick

// Material Symbols Rounded glyph by ligature name. Set fill to 1 for the filled style.
Text {
    property string name: ""
    property real fill: 0
    text: name
    font.family: "Material Symbols Rounded"
    font.pixelSize: 22
    font.variableAxes: ({"FILL": fill, "wght": 400, "opsz": Math.max(20, Math.min(48, font.pixelSize))})
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
}
