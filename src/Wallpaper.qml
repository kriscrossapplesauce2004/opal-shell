import QtQuick
Item {
    id:w
    property bool showWidgets:Hub.prefs.desktopWidgets!==false
    property string imagePath:Hub.prefs.wallpaperPath||""
    property string fit:Hub.prefs.wallpaperFit||"crop"
    property real dim:Hub.prefs.wallpaperDim||0
    readonly property bool custom:!!imagePath
    readonly property bool imageReady:!custom||photo.status===Image.Ready
    clip:true
    Rectangle {anchors.fill:parent;color:Theme.base}
    Image {id:photo;anchors.fill:parent;visible:w.custom;source:w.imagePath;fillMode:w.fit==="fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop;asynchronous:true;autoTransform:true;sourceSize.width:Math.max(1,w.width);sourceSize.height:Math.max(1,w.height)}
    Rectangle {anchors.fill:parent;visible:w.custom;color:Theme.alpha("#000000",w.dim)}
    MText {visible:w.custom&&photo.status===Image.Error;anchors.centerIn:parent;text:"Wallpaper unavailable · choose another image in Appearance";color:Theme.text}
    property string screenName:""
    // Desktop mode only: game mode keeps a clean wallpaper.
    property bool showHome:false
    // True while a window covers this screen's workspace: the icons and widgets fade out, so a see-through window shows only the wallpaper.
    property bool covered:false
    // Desktop home: icons, the widget canvas and the empty-workspace glance. Widgets follow the desktop widgets preference.
    DesktopHome {anchors.fill:parent;anchors.bottomMargin:72;screenName:w.screenName;visible:w.showHome&&opacity>0;widgets:w.showWidgets;opacity:w.covered ? 0 : 1;Behavior on opacity {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}}
}
