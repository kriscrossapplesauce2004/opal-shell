import QtQuick
import QtQuick.Effects

// Phone and tablet wallpaper. The home shows it sharp under a soft scrim; an open panel blurs it.
Item {
    id:backdrop
    // 0 is the sharp home wallpaper, 1 is the blurred panel backdrop.
    property real soft:Hub.page==="" ? 0 : 1
    Behavior on soft {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
    readonly property real tint:Math.min(.35,Hub.prefs.glass)
    Rectangle {anchors.fill:parent;color:Theme.base}
    Wallpaper {
        anchors.fill:parent
        showWidgets:false
        // The blur runs on a quarter-size copy of the wallpaper: it costs little per frame, and the upscale adds softness for free.
        layer.enabled:backdrop.soft>0&&GraphicsInfo.api!==GraphicsInfo.Software
        layer.textureSize:Qt.size(Math.max(1,Math.round(width/4)),Math.max(1,Math.round(height/4)))
        layer.smooth:true
        layer.effect:MultiEffect {
            blurEnabled:true
            blurMax:12
            blur:.5*backdrop.soft
            autoPaddingEnabled:false
        }
    }
    // Darker at the top and the bottom, so the status bar, the glance and the dock read on any wallpaper.
    Rectangle {
        anchors.fill:parent;opacity:1-backdrop.soft
        gradient:Gradient {
            GradientStop {position:0;color:Theme.alpha(Theme.base,Theme.light ? .55 : .32)}
            GradientStop {position:.3;color:Theme.alpha(Theme.base,.08)}
            GradientStop {position:.7;color:Theme.alpha(Theme.base,.12)}
            GradientStop {position:1;color:Theme.alpha(Theme.base,.5)}
        }
    }
    Rectangle {anchors.fill:parent;opacity:backdrop.soft;color:Theme.alpha(Theme.base,backdrop.tint)}
}
