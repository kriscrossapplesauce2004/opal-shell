import QtQuick
import "ClipKind.js" as ClipKind

// Leading tile for one clip: image thumbnail, colour swatch or kind icon.
Rectangle {
    id:thumb
    required property var record
    property bool selected:false
    readonly property var swatch:record.kind==="Color" ? ClipKind.parseColor(record.text) : null
    readonly property color tint:record.kind==="Link"||record.kind==="Email" ? Theme.secondary : record.kind==="Snippet"||record.kind==="Path" ? Theme.tertiary : Theme.primary
    implicitWidth:40;implicitHeight:40
    radius:Math.min(12,width*.3)
    color:swatch ? Qt.rgba(swatch.r/255,swatch.g/255,swatch.b/255,swatch.a) : record.kind==="Image" ? Theme.level(3) : selected ? Theme.alpha(Theme.onContainer,.14) : Theme.alpha(tint,.18)
    border.width:swatch ? 1 : 0
    border.color:Theme.alpha(Theme.text,.18)
    clip:true
    Image {
        anchors.fill:parent
        visible:thumb.record.kind==="Image"
        source:visible&&thumb.record.image ? "file://"+thumb.record.image : ""
        sourceSize:Qt.size(thumb.width*2,thumb.height*2)
        fillMode:Image.PreserveAspectCrop
        asynchronous:true;cache:false;smooth:true
    }
    Glyph {
        anchors.centerIn:parent
        visible:!thumb.swatch&&thumb.record.kind!=="Image"
        name:ClipKind.info(thumb.record).icon
        color:thumb.selected ? Theme.onContainer : Qt.tint(thumb.tint,Theme.alpha(Theme.text,.15))
        font.pixelSize:Math.round(thumb.width*.5)
    }
}
