pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Data for the homes and their widgets. The backend sends the desktop folder, weather, a photo memory and waiting updates.
Singleton {
    id: data
    property string desktopFolder: ""
    property var desktopItems: []
    property var weather: null
    property var photo: null
    property int updates: -1
    // The output whose desktop is in widget edit mode. Empty means none.
    property string editingScreen: ""
    // Wireless devices with a battery, for the Devices widget.
    readonly property var devices: UPower.devices.values.filter(d => d && d.ready && !d.isLaptopBattery && d.percentage > 0
        && !/LinePower|Ups/.test(UPowerDeviceType.toString(d.type))).map(d => ({
            name: d.model || UPowerDeviceType.toString(d.type), percent: Math.round(d.percentage <= 1 ? d.percentage * 100 : d.percentage),
            icon: deviceIcon(UPowerDeviceType.toString(d.type) + " " + (d.iconName || ""))}))
    function deviceIcon(text) {
        return /Head|Ear|audio/i.test(text) ? "headphones" : /Gaming|joystick|controller/i.test(text) ? "sports_esports" : /Phone/i.test(text) ? "smartphone"
             : /Mouse/i.test(text) ? "mouse" : /Keyboard/i.test(text) ? "keyboard" : /Tablet|Pen/i.test(text) ? "stylus" : "bluetooth";
    }
    function ingest(e) {
        if (e.event === "desktopFiles") { desktopFolder = e.folder || ""; desktopItems = e.items || []; }
        else if (e.event === "weather") weather = e.data || null;
        else if (e.event === "photoMemory") photo = e.data || null;
        else if (e.event === "updates") updates = typeof e.count === "number" ? e.count : -1;
    }
    function refresh() { Hub.command({action: "home-refresh"}); }
}
