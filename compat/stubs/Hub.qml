pragma Singleton
import QtQuick
// Test stand-in for opal Hub: holds only the fields that Theme and leaf components read.
QtObject {
    property var prefs: ({ light: false, palette: 0, dynamicColors: false, look: "glass",
        lookBlur: false, lookEdges: true, lookShadows: false, lookAppTransparency: true,
        lookSurfaces: ({}), reduceMotion: true, mode: "desktop" })
    property string settingsFound: ""
    property var dynamicPalette: null
}
