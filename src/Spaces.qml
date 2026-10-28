pragma Singleton
import QtQuick
import Quickshell

// Named spaces: a workspace can carry a name, a Material symbol and a colour. Unnamed ones take their main app's name. Saved spaces reopen their apps.
Singleton {
    id: root
    readonly property var named: Hub.prefs.spaces || ({})
    readonly property var saved: Array.isArray(Hub.prefs.savedSpaces) ? Hub.prefs.savedSpaces : []
    readonly property var colors: ["#ffb38a", "#c7a7ff", "#8bd5a0", "#9ecbff", "#f2b8b5", "#e6c87a", "#a6e3e9", "#d0c4b4"]
    readonly property var symbols: ["science", "code", "terminal", "sports_esports", "brush", "palette", "music_note", "movie", "school", "work", "print", "rocket_launch",
        "home", "travel_explore", "bolt", "favorite", "mail", "chat", "photo_camera", "edit_note", "calculate", "public", "build", "bug_report", "book", "shopping_cart",
        "fitness_center", "restaurant", "pets", "eco", "star", "flag", "lightbulb", "headphones", "videocam", "folder", "description", "monitoring", "dns", "cloud",
        "lock", "account_circle", "groups", "event", "schedule", "auto_awesome", "explore", "language", "memory", "developer_board", "smart_toy", "theaters", "draw", "piano"]
    // The windows of one workspace, largest first.
    function windowsOn(ws) {
        return Hub.windows.filter(w => Number(w.workspace) === Number(ws) && !String(w.workspaceName || "").startsWith("special:"))
            .slice().sort((a, b) => ((b.size || [0, 0])[0] * (b.size || [0, 0])[1]) - ((a.size || [0, 0])[0] * (a.size || [0, 0])[1]));
    }
    function autoName(ws) {
        const w = windowsOn(ws)[0];
        if (!w) return "";
        const app = Hub.appForWindow(w);
        return app ? app.name : String(w.className || w.title || "");
    }
    // {name, icon, color, auto}. auto is true when the name comes from the main app.
    function info(ws) {
        const n = named[String(ws)] || {};
        const name = n.name || "";
        return {name: name || autoName(ws), icon: n.icon || "", color: n.color || "", auto: name === "", ws: Number(ws)};
    }
    function update(ws, patch) {
        const next = Object.assign({}, named);
        const merged = Object.assign({}, next[String(ws)] || {}, patch);
        Object.keys(merged).forEach(k => { if (merged[k] === "") delete merged[k]; });
        if (Object.keys(merged).length) next[String(ws)] = merged; else delete next[String(ws)];
        Hub.set("spaces", next);
    }
    function forget(ws) { update(ws, {name: "", icon: "", color: ""}); }
    function closeAll(ws) { windowsOn(ws).forEach(w => Hub.closeWindow(w)); forget(ws); }
    // Save: the apps of the space, with their geometry, under its name.
    function save(ws) {
        const i = info(ws);
        const apps = [], seen = {};
        for (const w of windowsOn(ws)) {
            const app = Hub.appForWindow(w);
            const key = app ? app.id : String(w.className || "");
            if (!key || seen[key]) continue;
            seen[key] = true;
            const at = w.at || [0, 0], size = w.size || [0, 0];
            apps.push({app: app ? String(app.id) : "", cls: String(w.className || ""), title: String(w.title || "").slice(0, 300), x: at[0], y: at[1], w: size[0], h: size[1], floating: !!w.floating});
            if (apps.length >= 24) break;
        }
        const name = (i.name || ("Space " + ws)).slice(0, 40);
        const id = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || ("space-" + ws);
        const entry = {id: id, name: name, apps: apps, saved: Date.now()};
        if (i.icon) entry.icon = i.icon;
        if (i.color) entry.color = i.color;
        Hub.set("savedSpaces", saved.filter(s => s.id !== id).concat([entry]).slice(-24));
        Hub.message("Saved " + name);
    }
    function isSaved(ws) { const n = info(ws).name.toLowerCase(); return n !== "" && saved.some(s => s.name.toLowerCase() === n); }
    function unsave(id) { Hub.set("savedSpaces", saved.filter(s => s.id !== id)); }
    // Reopen: a fresh workspace after the last one, named like the saved space, with its apps launched there.
    function open(entry) {
        if (!entry) return;
        const list = (Hub.status.workspaces || []).filter(n => n > 0);
        const ws = (list.length ? Math.max.apply(null, list) : 0) + 1;
        update(ws, {name: entry.name, icon: entry.icon || "", color: entry.color || ""});
        Hub.workspace(ws);
        pending = (entry.apps || []).slice();
        launcher.restart();
    }
    property var pending: []
    // Apps start one after another, so each one opens on the new workspace while it has focus.
    Timer {
        id: launcher
        interval: 450
        onTriggered: {
            const next = root.pending.shift();
            if (!next) return;
            const key = String(next.app || next.cls || "").toLowerCase().replace(/\.desktop$/i, "");
            const app = Hub.apps.find(a => String(a.id).toLowerCase().replace(/\.desktop$/i, "") === key) || Hub.appIndex[String(next.cls || "").toLowerCase()];
            if (app) Hub.launchNew(app);
            if (root.pending.length) launcher.restart();
        }
    }
}
