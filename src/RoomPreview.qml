import QtQuick

// Live window picture for a room tile. It stays invisible until the first frame, so the icon tile shows instead of a waiting label.
HyprWindowPreview {
    opacity:hasContent ? 1 : 0
    Behavior on opacity {NumberAnimation {duration:Theme.motion(180)}}
}
