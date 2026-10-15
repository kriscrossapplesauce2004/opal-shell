pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "ActivityModel.js" as Model

// Live activities and suggestion chips. Plain data only: notification objects stay owned by Notifier.
Scope {
    id: root
    // Tests set these to show fixed data without services.
    property var fixture: null
    property var chipFixture: null
    property var list: []
    property var ids: []
    property var byId: ({})
    property var chips: []
    property var dismissed: []
    // Raw requests from the activity API, newest last.
    property var external: []
    // Control presses on pushed activities that wait for "opal activity wait".
    property var pending: ({})
    // When each chip appeared first, so the bars show a suggestion only while it is new.
    property var chipSeen: ({})
    // When each wireless device appeared first.
    property var deviceSeen: ({})
    // The activity that the shade or the Shelf card shows first. Empty means the top activity.
    property string focusId: ""
    // The Shelf card: open state and the output whose Shelf opened it.
    property bool cardOpen: false
    property var cardScreen: null
    function toggleCard(output) {
        if (cardOpen && cardScreen === output) { cardOpen = false; return; }
        cardScreen = output; cardOpen = list.length > 0 || freshChips.length > 0;
    }
    property double chargeChanged: 0
    property double netChanged: 0
    property double mediaSince: 0
    property double focusSince: 0
    property double assistantSince: 0
    property bool lastCharging: false
    property bool lastWifi: true
    property bool primed: false
    readonly property double startedAt: Date.now()
    readonly property int chipFreshMs: 30000
    readonly property var primary: list.length ? list[0] : null
    readonly property int count: list.length
    readonly property var summary: Model.summary(list)
    // Suggestion chips that are new enough to show next to the pills.
    readonly property var freshChips: chips.filter(c => nowMs() - (chipSeen[c.id] || 0) < chipFreshMs)
    readonly property var focused: byId[focusId] || primary

    function nowMs() { return Hub.now.getTime(); }
    function notes() {
        const rev = Notifier.revision;
        return Notifier.entries.filter(e => e.notification && !e.notification.lastGeneration).map(e => {
            const n = e.notification;
            return {id: n.id, appName: n.appName, summary: n.summary, body: n.body, resident: n.resident, transient: n.transient,
                hints: n.hints || {}, received: e.received,
                actions: n.actions.map(a => ({identifier: a.identifier, text: a.text}))};
        });
    }
    // Wireless devices with a battery, from UPower. The laptop battery and line power are not devices here.
    function devices(now) {
        const out = [];
        const seen = Object.assign({}, deviceSeen);
        let changed = false;
        for (const d of UPower.devices.values) {
            if (!d || d.isLaptopBattery || !d.ready) continue;
            const kind = UPowerDeviceType.toString(d.type);
            if (/LinePower|Battery|Ups|Unknown/.test(kind) && !/Headset|Headphones|Gaming|Phone|Mouse|Keyboard|Tablet|Bluetooth/.test(kind)) continue;
            const id = d.nativePath || d.model;
            if (!id) continue;
            if (seen[id] === undefined) { seen[id] = primed && now - startedAt > 6000 ? now : 0; changed = true; }
            const percent = d.percentage <= 1 ? d.percentage * 100 : d.percentage;
            out.push({id: id, name: d.model || kind, kind: kind + " " + (d.iconName || ""), percent: percent, connectedAt: seen[id]});
        }
        if (changed) deviceSeen = seen;
        return out;
    }
    // Apps that use the microphone or share the screen, from PipeWire, and camera users from the backend.
    function privacy() {
        const mic = [], screen = [];
        for (const n of Pipewire.nodes.values) {
            if (!n || !n.isStream) continue;
            const p = n.properties || {};
            const app = p["application.name"] || n.description || n.name || "";
            if (n.type === PwNodeType.AudioInStream && p["stream.monitor"] !== "true" && !/opal|quickshell|cava|pavucontrol/i.test(app) && mic.indexOf(app) < 0) mic.push(app);
        }
        for (const n of Pipewire.nodes.values) {
            if (!n || n.isStream) continue;
            if (n.type === PwNodeType.VideoSource && /xdp|screencast|screen|portal/i.test(n.name || "")) screen.push("Screen share");
        }
        return {mic: mic, camera: Hub.status.camera || [], screen: screen.slice(0, 1)};
    }
    function assistant() {
        const turns = AssistantState.turns || [];
        const last = turns.length ? turns[turns.length - 1] : null;
        const tools = last && last.tools ? last.tools : [];
        const tool = tools.length ? tools[tools.length - 1] : null;
        const step = tool ? (typeof tool === "string" ? tool : tool.title || tool.name || "") : "";
        return {busy: AssistantState.busy, since: assistantSince, step: step, request: AssistantState.lastText,
            approvals: (AssistantState.approvals || []).map(a => ({id: a.id, title: a.title || a.tool || a.name, detail: a.detail || a.summary || a.command || ""}))};
    }
    function signals(withNotes) {
        const s = Hub.status;
        const now = nowMs();
        return {
            media: {track: s.track, artist: s.artist, art: s.art, playing: s.playing}, mediaSince: mediaSince,
            focus: {running: Hub.focusRunning, seconds: Hub.focusSeconds, total: Math.max(1500, Hub.focusSeconds)}, focusSince: focusSince,
            battery: {percent: s.battery, charging: s.charging, changedAt: chargeChanged},
            network: {wifi: s.wifi, name: s.network, changedAt: netChanged},
            notifications: withNotes ? notes() : [],
            devices: devices(now), privacy: privacy(), pacman: s.pacman || {}, assistant: assistant(), external: external
        };
    }
    function privacyAllows() { const p = Hub.prefs.lockNotifications || "title"; return p !== "off" && p !== "count"; }
    function refresh() {
        const now = nowMs();
        const s = Hub.status;
        // The first seconds after start only settle the state. They are not changes.
        if (primed && now - startedAt > 6000) {
            if (!!s.charging !== lastCharging) chargeChanged = now;
            if (!!s.wifi !== lastWifi) netChanged = now;
        }
        lastCharging = !!s.charging; lastWifi = !!s.wifi; primed = true;
        if (s.track === "") mediaSince = 0; else if (mediaSince === 0) mediaSince = now;
        if (!Hub.focusRunning) focusSince = 0; else if (focusSince === 0) focusSince = now;
        if (!AssistantState.busy) assistantSince = 0; else if (assistantSince === 0) assistantSince = now;
        // Pushed activities with a lifetime leave the store when it ends.
        const alive = external.filter(x => !(x.ttl > 0 && x.updated + x.ttl * 1000 <= now));
        if (alive.length !== external.length) external = alive;
        const next = fixture !== null ? Model.merge([], fixture, now) : Model.merge(list, Model.fromSignals(signals(true), now), now);
        const nextIds = next.map(a => a.id);
        const map = {};
        next.forEach(a => { map[a.id] = a; });
        byId = map;
        if (JSON.stringify(nextIds) !== JSON.stringify(ids)) ids = nextIds;
        list = next;
        if (focusId !== "" && !map[focusId]) focusId = "";
        const nextChips = chipFixture !== null ? chipFixture : Model.suggestions(chipSignals(), dismissed);
        if (JSON.stringify(nextChips) !== JSON.stringify(chips)) {
            const seen = {};
            nextChips.forEach(c => { seen[c.id] = chipSeen[c.id] || now; });
            chipSeen = seen;
            chips = nextChips;
        }
    }
    function chipSignals() {
        const sessions = (Hub.linkDevices || []).filter(d => d.opal && d.reachable && d.session && d.session.app).map(d => {
            const app = Hub.appForClass(d.session.app);
            return app ? {device: d.id, deviceName: d.name, app: d.session.app, appName: app.name} : null;
        }).filter(x => x);
        const dock = Hub.dockScreen ? {name: Hub.dockScreen.name, handled: !!Hub.dockResult || !!Hub.sessionModes[Hub.dockScreen.name]} : null;
        const s = Hub.status;
        // Codes come from unread popups and the inbox. The text is read here and not kept.
        const codes = Notifier.inbox.filter(e => !e.read || e.popup).slice(0, 5).map(e => ({id: e.notification.id, app: e.notification.appName, body: e.notification.body + " " + e.notification.summary}));
        return {dnd: Hub.dnd, dock: dock, sessions: sessions, codes: codes,
            battery: {percent: s.battery, charging: s.charging, saver: s.profile === "power-saver", canSave: !!s.profile}};
    }
    function dismissChip(chip) { dismissed = dismissed.concat([chip.id]).slice(-30); refresh(); }
    function runChip(chip) {
        if (chip.kind === "dock" && typeof Hub.dockAs === "function") Hub.dockAs("desktop");
        else if (chip.kind === "continue") { const app = Hub.appForClass(chip.arg); if (app) Hub.launch(app); }
        else if (chip.kind === "code") { Hub.command({action: "clipboard", text: chip.arg}); Hub.message("Code copied"); }
        else if (chip.kind === "saver") Hub.command({action: "profile", value: "power-saver"});
        dismissChip(chip);
    }
    function entryFor(nid) { return Notifier.entries.find(e => e.notification && e.notification.id === nid) || null; }
    // Focus the window of a pushed activity: the first window whose process is in the activity's process chain.
    function focusPids(pids) {
        const w = (Hub.windows || []).find(x => x.pid && (pids || []).indexOf(x.pid) >= 0);
        if (w) { Hub.focusWindow(w); return true; }
        return false;
    }
    function control(activity, ctl) {
        if (!activity || !ctl) return;
        if (activity.external !== undefined && String(ctl.id).startsWith("x:")) {
            const next = Object.assign({}, pending);
            next[activity.external] = ctl.action;
            pending = next;
            bridge.send({event: "action", id: activity.external, action: ctl.action});
            if (ctl.action === "open") focusPids(activity.pids);
            refresh();
            return;
        }
        switch (ctl.id) {
        case "media-previous": Hub.media("previous"); break;
        case "media-next": Hub.media("next"); break;
        case "media-play": case "media-pause": Hub.media("play-pause"); break;
        case "focus-toggle": Hub.timerToggle(); break;
        case "focus-add": Hub.focusSeconds = Hub.focusSeconds + 5 * 60; break;
        case "focus-stop": Hub.focusRunning = false; Hub.focusSeconds = 25 * 60; break;
        case "assistant-stop": AssistantState.stop(); break;
        case "assistant-open": Hub.openAssistant(""); break;
        case "assistant-allow": AssistantState.approve(activity.approval, true); break;
        case "assistant-deny": AssistantState.approve(activity.approval, false); break;
        case "note-action": {
            const e = entryFor(activity.nid);
            const action = e ? e.notification.actions.filter(a => a.identifier !== "default")[ctl.index] : null;
            if (action) action.invoke();
            break;
        }
        }
        refresh();
    }
    function open(activity, output) {
        if (!activity) return;
        if (activity.kind === "media") Hub.toggleAudio(output);
        else if (activity.external !== undefined) { if (!focusPids(activity.pids)) { focusId = activity.id; Hub.targetScreen = output; Hub.toggle("controls"); } }
        else if (activity.kind === "agent" && String(activity.id).startsWith("assistant")) Hub.openAssistant("");
        else if (activity.nid !== undefined) {
            const e = entryFor(activity.nid);
            const action = e ? e.notification.actions.find(a => a.identifier === "default") : null;
            if (action) action.invoke(); else { Hub.targetScreen = output; Hub.toggle("notifications"); }
        } else { Hub.targetScreen = output; Hub.toggle("controls"); }
    }
    // Show one activity on top of the shade (phone) or in the Shelf card (desktop).
    function show(activity, output) {
        focusId = activity ? activity.id : "";
        Hub.targetScreen = output;
        if (Hub.page !== "controls") Hub.toggle("controls");
    }

    // The activity API. The same requests arrive from the CLI (IPC), the DBus bridge and the MCP server.
    function parse(json) { try { const v = JSON.parse(json); return v && typeof v === "object" && !Array.isArray(v) ? v : null; } catch (e) { return null; } }
    function upsert(item) {
        if (!item) return "";
        const probe = Model.fromExternal(item, nowMs());
        if (!probe) return "";
        external = Model.storeExternal(external, item, nowMs());
        refresh();
        return probe.external;
    }
    function startJson(json) { return upsert(parse(json)); }
    function updateJson(id, json) {
        const old = external.find(x => x.id === id);
        const patch = parse(json);
        if (!patch) return "";
        return upsert(Object.assign({}, old || {}, patch, {id: id}));
    }
    function end(id) {
        external = external.filter(x => x.id !== id);
        const next = Object.assign({}, pending); delete next[id]; pending = next;
        refresh();
    }
    function take(id) {
        const action = pending[id] || "";
        if (action) { const next = Object.assign({}, pending); delete next[id]; pending = next; }
        return action;
    }
    IpcHandler {
        target: "activity"
        function start(json: string): string { return root.startJson(json); }
        function update(id: string, json: string): string { return root.updateJson(id, json); }
        function end(id: string): void { root.end(id); }
        function take(id: string): string { return root.take(id); }
        function list(): string { return JSON.stringify(root.list.map(a => ({id: a.external || a.id, kind: a.kind, title: a.title, subtitle: a.subtitle, progress: a.progress}))); }
    }
    // DBus service dev.opal.Activities. A small bridge process owns the bus name and speaks JSON lines with the shell.
    Process {
        id: bridge
        property bool wanted: root.fixture === null && !Quickshell.env("OPAL_TEST_OUTPUT")
        function send(message) { if (running) write(JSON.stringify(message) + "\n"); }
        command: ["python3", Qt.resolvedUrl("activity_dbus.py").toString().replace("file://", "")]
        running: wanted
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                const m = root.parse(line);
                if (!m) return;
                let id = "";
                if (m.op === "start") id = root.upsert(m.data || null);
                else if (m.op === "update") id = root.updateJson(String(m.id || ""), JSON.stringify(m.data || {}));
                else if (m.op === "end") root.end(String(m.id || ""));
                if (m.serial !== undefined) bridge.send({event: "reply", serial: m.serial, id: id});
            }
        }
        onExited: if (wanted) restart.start()
    }
    Timer { id: restart; interval: 5000; onTriggered: bridge.running = bridge.wanted }
    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n && n.isStream) }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Connections { target: Notifier; function onRevisionChanged() { Qt.callLater(root.refresh); } }
    Connections { target: Hub; function onStatusChanged() { Qt.callLater(root.refresh); } function onPageChanged() { if (Hub.page !== "") root.cardOpen = false; } function onAudioOpenChanged() { if (Hub.audioOpen) root.cardOpen = false; } }
    onListChanged: if (cardOpen && list.length === 0 && freshChips.length === 0) cardOpen = false
    Connections { target: AssistantState; function onBusyChanged() { Qt.callLater(root.refresh); } function onApprovalsChanged() { Qt.callLater(root.refresh); } }
}
