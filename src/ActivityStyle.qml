pragma Singleton
import QtQuick
import Quickshell

// Colours per activity kind. Cards stay calm; the icon circle carries the accent of the kind.
Singleton {
    // Map each activity kind to one of five tone groups.
    function tone(kind) {
        switch (kind) {
        case "agent": case "claude": case "assistant": return "agent";
        case "recording": case "call": return "rec";
        case "focus": case "timer": return "focus";
        case "device": case "charging": case "privacy": case "bluetooth": return "device";
        case "media": return "media";
        default: return "neutral";
        }
    }
    function fill(kind) {
        const t = tone(kind);
        return t === "agent" ? Theme.tertiaryContainer : t === "rec" ? Theme.mix(Theme.base, Theme.error, Theme.light ? .2 : .22)
             : t === "device" ? Theme.secondaryContainer : t === "focus" ? Theme.mix(Theme.base, Theme.primary, Theme.light ? .26 : .2)
             : t === "media" ? Theme.level(3) : Theme.level(2);
    }
    function ink(kind) {
        const t = tone(kind);
        return t === "agent" ? Theme.onTertiaryContainer : t === "rec" ? Theme.mix(Theme.error, Theme.light ? "#000000" : "#ffffff", .3)
             : t === "device" ? Theme.onSecondaryContainer : t === "focus" ? Theme.mix(Theme.primary, Theme.light ? "#000000" : "#ffffff", .35) : Theme.text;
    }
    function accent(kind) {
        const t = tone(kind);
        return t === "agent" ? Theme.tertiary : t === "rec" ? Theme.error : t === "focus" ? Theme.primary : t === "device" ? Theme.secondary : Theme.alpha(Theme.text, .13);
    }
    // Ink for a glyph that sits on the accent circle.
    function onAccent(kind) {
        const t = tone(kind);
        return t === "neutral" || t === "media" ? Theme.text : Theme.base;
    }
}
