.pragma library

// Pure activity model. No Quickshell, Hub or DBus access, so Node can test it.
// An activity is a plain object: {id, kind, title, subtitle, icon, progress, priority, since, until, controls, nid}.

var MAX_ACTIVITIES = 6;
var CHARGE_SHOW_MS = 10000;
var LINK_SHOW_MS = 8000;
var DONE_SHOW_MS = 4000;
var LOW_BATTERY = 20;
var DEVICE_SHOW_MS = 8000;
var DEVICE_LOW = 15;
var MAX_EXTERNAL = 12;

// Higher priority wins the compact slot. Calls and recordings stay above everything.
var PRIORITY = {call: 90, urgent: 88, recording: 85, privacy: 80, transfer: 70, system: 65, focus: 60, agent: 55, media: 50, neutral: 45, device: 40, charging: 30, connectivity: 20};
// Kinds that an outside program can push through the activity API.
var EXTERNAL_KINDS = {agent: 1, system: 1, transfer: 1, focus: 1, device: 1, recording: 1, neutral: 1};

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function text(value) { return value === undefined || value === null ? "" : String(value); }

// Progress is 0 to 1, or -1 when the value is unknown.
function progressFromValue(value) {
    var number = typeof value === "string" && value.trim() !== "" ? Number(value) : value;
    if (typeof number !== "number" || !isFinite(number)) return -1;
    return clamp(number, 0, 100) / 100;
}

function categoryOf(note) {
    var hints = note.hints || {};
    return text(note.category || hints.category).toLowerCase();
}

// Turn one notification description into an activity, or null when it is a plain message.
function fromNotification(note, now) {
    if (!note || note.id === undefined || note.id === null) return null;
    var hints = note.hints || {};
    var category = categoryOf(note);
    var progress = progressFromValue(hints.value !== undefined ? hints.value : note.value);
    var name = text(note.appName);
    var isCall = /^(call|x-.*call)/.test(category) || /\.call(\.|$)/.test(category);
    var isRecording = /record|screencast/.test(category) || (/(record|screencast|obs|kooha)/i.test(name) && !!note.resident);
    var isTransfer = /^(transfer|network\.transfer|x-.*(progress|transfer))/.test(category) || category === "progress" || progress >= 0;
    // A finished transfer is a normal message. Only an unfinished one stays here.
    if (/complete|error|done|finished/.test(category)) return null;
    var kind = isCall ? "call" : isRecording ? "recording" : isTransfer ? "transfer" : "";
    if (kind === "") return null;
    // A transient message without progress is not an ongoing activity.
    if (note.transient && progress < 0 && kind === "transfer") return null;
    var done = kind === "transfer" && progress >= 1;
    var icon = kind === "call" ? "call" : kind === "recording" ? "fiber_manual_record" : done ? "download_done" : "download";
    var actions = (note.actions || []).filter(function (a) { return a.identifier !== "default"; }).slice(0, 2);
    var subtitle = text(note.body).split("\n")[0].slice(0, 80);
    if (!subtitle) subtitle = name;
    var received = typeof note.received === "number" ? note.received : now;
    return {
        id: "n:" + note.id, nid: note.id, kind: kind, icon: icon,
        title: text(note.summary) || name || "Activity",
        subtitle: subtitle, app: name, progress: kind === "transfer" ? progress : -1,
        short: kind === "transfer" && progress >= 0 ? Math.round(progress * 100) + "%" : kind === "call" ? "Call" : kind === "recording" ? "REC" : "",
        priority: PRIORITY[kind], since: received, until: done ? received + DONE_SHOW_MS : 0,
        controls: actions.map(function (a, i) { return {id: "note-action", index: i, label: text(a.text)}; })
    };
}

function formatClock(seconds) {
    var s = Math.max(0, Math.floor(seconds));
    var m = Math.floor(s / 60);
    return m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
}

// Build every local-signal activity. The signals object holds plain values only.
function fromSignals(sig, now) {
    var out = [];
    var media = sig.media || {};
    if (text(media.track) !== "") {
        out.push({
            id: "media", kind: "media", icon: "music", art: text(media.art),
            title: text(media.track), short: text(media.track).slice(0, 24), subtitle: text(media.artist) || (media.playing ? "Playing" : "Paused"),
            progress: -1, priority: PRIORITY.media - (media.playing ? 0 : 8), since: sig.mediaSince || now, until: 0,
            playing: !!media.playing,
            controls: [{id: "media-previous", icon: "previous"}, {id: media.playing ? "media-pause" : "media-play", icon: media.playing ? "pause" : "play"}, {id: "media-next", icon: "skip"}]
        });
    }
    var focus = sig.focus || {};
    if (focus.running) {
        var total = focus.total > 0 ? focus.total : 1500;
        var ends = new Date(now + focus.seconds * 1000);
        out.push({
            id: "focus", kind: "focus", icon: "timer", title: "Focus", short: formatClock(focus.seconds),
            subtitle: "Ends at " + ends.getHours() + ":" + (ends.getMinutes() < 10 ? "0" : "") + ends.getMinutes(),
            ring: true, ringText: formatClock(focus.seconds),
            progress: clamp(1 - focus.seconds / total, 0, 1), priority: PRIORITY.focus, since: sig.focusSince || now, until: 0,
            controls: [{id: "focus-stop", icon: "close"}, {id: "focus-add", label: "+5 min"}, {id: "focus-toggle", label: "Pause", primary: true}]
        });
    }
    var battery = sig.battery || {};
    if (battery.percent >= 0 && battery.charging) {
        var recent = battery.changedAt > 0 && now - battery.changedAt < CHARGE_SHOW_MS;
        if (recent || (battery.percent <= LOW_BATTERY && battery.percent < 100)) {
            out.push({
                id: "charging", kind: "charging", icon: "charging", title: "Charging " + Math.round(battery.percent) + "%", short: Math.round(battery.percent) + "%",
                subtitle: battery.percent >= 100 ? "Fully charged" : "Plugged in", progress: clamp(battery.percent / 100, 0, 1),
                priority: PRIORITY.charging, since: battery.changedAt || now, until: recent ? battery.changedAt + CHARGE_SHOW_MS : 0, controls: []
            });
        }
    }
    var net = sig.network || {};
    if (net.changedAt > 0 && now - net.changedAt < LINK_SHOW_MS) {
        out.push({
            id: "connectivity", kind: "connectivity", icon: net.wifi ? "wifi" : "wifiOff",
            title: net.wifi ? "Connected" : "Offline", subtitle: net.wifi ? text(net.name) : "No network",
            progress: -1, priority: PRIORITY.connectivity, since: net.changedAt, until: net.changedAt + LINK_SHOW_MS, controls: []
        });
    }
    (sig.notifications || []).forEach(function (note) {
        var activity = fromNotification(note, now);
        if (activity) out.push(activity);
    });
    deviceActivities(sig.devices, now).forEach(function (a) { out.push(a); });
    var privacy = privacyActivity(sig.privacy, now);
    if (privacy) out.push(privacy);
    var update = systemUpdate(sig.pacman, now);
    if (update) out.push(update);
    assistantActivities(sig.assistant, now).forEach(function (a) { out.push(a); });
    (sig.external || []).forEach(function (item) {
        var activity = fromExternal(item, now);
        if (activity) out.push(activity);
    });
    if (sig.recording && !out.some(function (a) { return a.kind === "recording"; })) {
        out.push({id: "recording", kind: "recording", icon: "fiber_manual_record", title: "Screen recording", short: "REC", subtitle: "Recording", progress: -1,
            priority: PRIORITY.recording, since: sig.recordingSince || now, until: 0, controls: []});
    }
    return out;
}

function deviceIcon(kind) {
    var k = text(kind).toLowerCase();
    if (/head|ear|audio|speaker/.test(k)) return "headphones";
    if (/game|controller|joystick|pad/.test(k)) return "sports_esports";
    if (/phone/.test(k)) return "smartphone";
    if (/mouse/.test(k)) return "mouse";
    if (/keyboard/.test(k)) return "keyboard";
    if (/pen|stylus|tablet/.test(k)) return "stylus";
    return "bluetooth";
}

// Bluetooth and wireless devices: a brief pill when one connects, and a lasting one while its battery is low.
function deviceActivities(devices, now) {
    var out = [];
    (devices || []).forEach(function (d) {
        if (!d || !d.id) return;
        var percent = typeof d.percent === "number" && isFinite(d.percent) ? Math.round(d.percent) : -1;
        var recent = d.connectedAt > 0 && now - d.connectedAt < DEVICE_SHOW_MS;
        var low = percent >= 0 && percent <= DEVICE_LOW;
        if (!recent && !low) return;
        out.push({
            id: "dev:" + d.id, kind: "device", icon: deviceIcon(d.kind), title: text(d.name) || "Device",
            short: percent >= 0 ? percent + "%" : "", subtitle: low ? "Battery low · " + percent + "%" : "Connected" + (percent >= 0 ? " · " + percent + "%" : ""),
            progress: -1, priority: low ? PRIORITY.privacy - 5 : PRIORITY.device, since: d.connectedAt || now,
            until: low ? 0 : d.connectedAt + DEVICE_SHOW_MS, controls: []
        });
    });
    return out;
}

// Camera, microphone and screen capture in use. This stays while any app uses them.
function privacyActivity(p, now) {
    if (!p) return null;
    var mic = p.mic || [], camera = p.camera || [], screen = p.screen || [];
    if (!mic.length && !camera.length && !screen.length) return null;
    var parts = [];
    if (camera.length) parts.push("camera");
    if (mic.length) parts.push("mic");
    if (screen.length) parts.push("screen");
    var names = [];
    camera.concat(mic, screen).forEach(function (n) { n = text(n); if (n && names.indexOf(n) < 0) names.push(n); });
    var label = parts.length === 1 ? parts[0].charAt(0).toUpperCase() + parts[0].slice(1) : parts.slice(0, -1).join(", ").replace(/^./, function (c) { return c.toUpperCase(); }) + " and " + parts[parts.length - 1];
    return {
        id: "privacy", kind: "privacy", icon: camera.length ? "videocam" : screen.length ? "screen_share" : "mic", title: label + " in use",
        short: "", subtitle: names.slice(0, 3).join(", ") || "An app", progress: -1, priority: PRIORITY.privacy, since: p.since || now, until: 0, controls: []
    };
}

// A pacman transaction that runs now. The total is unknown, so progress is indeterminate unless the backend knows it.
function systemUpdate(pac, now) {
    if (!pac || !pac.running) return null;
    var done = Math.max(0, Math.floor(pac.done || 0)), total = Math.max(0, Math.floor(pac.total || 0));
    return {
        id: "pacman", kind: "system", icon: "system_update", title: total > 0 ? "Updating " + total + " packages" : "Updating packages",
        short: total > 0 ? String(total) : done > 0 ? String(done) : "", subtitle: "pacman" + (pac.current ? " · " + text(pac.current) : ""),
        progress: total > 0 ? clamp(done / total, 0, 1) : -2, progressText: total > 0 ? done + " of " + total : done > 0 ? done + " done" : "Starting",
        priority: PRIORITY.system, since: pac.since || now, until: 0, controls: []
    };
}

// The Opal assistant: one card while it works, and one urgent card for each action that waits for approval.
function assistantActivities(a, now) {
    var out = [];
    if (!a) return out;
    (a.approvals || []).slice(0, 2).forEach(function (ap) {
        out.push({
            id: "assistant:approve:" + ap.id, kind: "agent", icon: "auto_awesome", title: "Assistant needs you", short: "Approve",
            subtitle: text(ap.title || ap.tool || ap.name || "Wants to run an action"), code: text(ap.detail || ap.summary || "").slice(0, 400),
            progress: -1, priority: PRIORITY.urgent, since: now, until: 0, approval: ap.id,
            controls: [{id: "assistant-deny", label: "Deny"}, {id: "assistant-allow", label: "Allow", primary: true}]
        });
    });
    if (a.busy) {
        out.push({
            id: "assistant", kind: "agent", icon: "auto_awesome", title: "Assistant", short: "Working",
            subtitle: text(a.step) || "Working on it", progress: -2, progressText: text(a.request).slice(0, 80),
            priority: PRIORITY.agent, since: a.since || now, until: 0,
            controls: [{id: "assistant-open", icon: "open_in_new"}, {id: "assistant-stop", icon: "stop", label: "Stop"}]
        });
    }
    return out;
}

function clip(value, max) { return text(value).replace(/[\u0000-\u0008\u000b-\u001f]/g, "").slice(0, max); }
function safeName(value, max) { var s = text(value); return /^[A-Za-z0-9._:-]+$/.test(s) ? s.slice(0, max) : ""; }

// Validate one activity that an app, script or agent pushed. Unknown fields are dropped and long text is cut.
function fromExternal(item, now) {
    if (!item || typeof item !== "object") return null;
    var id = safeName(item.id, 64);
    if (!id) return null;
    var kind = EXTERNAL_KINDS[item.kind] ? item.kind : "neutral";
    var progress = typeof item.progress === "number" && isFinite(item.progress) ? (item.progress === -2 ? -2 : item.progress < 0 ? -1 : clamp(item.progress, 0, 1)) : -1;
    var controls = (Array.isArray(item.controls) ? item.controls : []).slice(0, 3).map(function (c) {
        var cid = c && /^[a-z0-9_-]{1,24}$/.test(text(c.id)) ? text(c.id) : "";
        if (!cid) return null;
        var icon = /^[a-z0-9_]{1,40}$/.test(text(c.icon)) ? text(c.icon) : "";
        var label = clip(c.label, 20);
        if (!icon && !label) return null;
        return {id: "x:" + cid, action: cid, label: label, icon: icon, primary: !!c.primary, danger: !!c.danger};
    }).filter(function (c) { return c; });
    var ttl = typeof item.ttl === "number" && item.ttl > 0 ? Math.min(item.ttl, 86400) * 1000 : 0;
    var since = typeof item.since === "number" ? item.since : now;
    return {
        id: "x:" + id, external: id, kind: kind, icon: /^[a-z0-9_]{1,40}$/.test(text(item.icon)) ? text(item.icon) : "spark",
        title: clip(item.title, 80) || "Activity", subtitle: clip(item.subtitle, 160), short: clip(item.short, 24), meta: clip(item.meta, 16),
        code: clip(item.code, 400), progress: progress, progressText: clip(item.progressText, 80), ring: !!item.ring, ringText: clip(item.ringText, 8),
        appIcon: safeName(item.appIcon, 64),
        pids: (Array.isArray(item.pids) ? item.pids : [item.pid]).filter(function (n) { return typeof n === "number" && n > 1; }).slice(0, 16).map(Math.floor),
        priority: item.urgent ? PRIORITY.urgent : PRIORITY[kind], since: since, until: ttl ? (item.updated || since) + ttl : 0, controls: controls
    };
}

// Keep the newest pushed activities only. Each entry is the raw request plus its update time.
function storeExternal(store, item, now) {
    var next = (store || []).filter(function (x) { return x.id !== item.id; });
    next.push(Object.assign({}, item, {updated: now, since: (store || []).filter(function (x) { return x.id === item.id; }).map(function (x) { return x.since; })[0] || now}));
    return next.slice(-MAX_EXTERNAL);
}

function rank(list) {
    return list.slice().sort(function (a, b) {
        if (b.priority !== a.priority) return b.priority - a.priority;
        if (b.since !== a.since) return b.since - a.since;
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
}

// Merge new activities into the previous list. Same id replaces in place and keeps its first-seen time.
function merge(previous, incoming, now) {
    var seen = {};
    (previous || []).forEach(function (a) { seen[a.id] = a; });
    var byId = {};
    incoming.forEach(function (a) {
        if (a.until > 0 && a.until <= now) return;
        var old = seen[a.id];
        byId[a.id] = Object.assign({}, a, {since: old ? old.since : a.since});
    });
    var merged = Object.keys(byId).map(function (id) { return byId[id]; });
    return rank(merged).slice(0, MAX_ACTIVITIES);
}

// Short text for the compact pill: primary activity and how many more wait behind it.
function summary(list) {
    if (!list.length) return {primary: null, extra: 0, label: ""};
    var primary = list[0];
    var extra = list.length - 1;
    var label = primary.title + (extra > 0 ? ", plus " + extra + " more" : "");
    return {primary: primary, extra: extra, label: label};
}

// Find 4 to 8 digit codes. Years, times, decimals and long numbers are not codes.
var CONTEXT = /(code|otp|pin|passcode|password|verification|verify|token|security|one[- ]?time|2fa|login|sign[- ]?in|kode|c[oó]digo)/i;
function findCodes(body) {
    var s = text(body);
    if (s.length > 2000) s = s.slice(0, 2000);
    var re = /(^|[^\d.,:\/])(\d{3}[ -]\d{3}|\d{4,8})(?![\d]|[.,:\/-]\d)/g;
    var hasContext = CONTEXT.test(s);
    var found = [];
    var m;
    while ((m = re.exec(s)) !== null) {
        var raw = m[2];
        var digits = raw.replace(/[ -]/g, "");
        if (digits.length < 4 || digits.length > 8) continue;
        var isYear = digits.length === 4 && /^(19|20)\d\d$/.test(digits);
        if (isYear && !hasContext) continue;
        // Without a context word, only accept a code that stands alone in a short message.
        if (!hasContext && s.length > 60) continue;
        if (found.indexOf(digits) < 0) found.push(digits);
    }
    // A year next to a real code is not the code.
    var plain = found.filter(function (d) { return !/^(19|20)\d\d$/.test(d); });
    return plain.length ? plain : found;
}

// Suggestion chips. Local signals only, hidden during DND, never more than three.
function suggestions(sig, dismissed) {
    if (!sig || sig.dnd) return [];
    var skip = {};
    (dismissed || []).forEach(function (id) { skip[id] = true; });
    var out = [];
    if (sig.dock && sig.dock.name && !sig.dock.handled) {
        out.push({id: "dock:" + sig.dock.name, kind: "dock", label: "Use as desktop", detail: sig.dock.name, icon: "desktop", arg: sig.dock.name, priority: 80});
    }
    (sig.codes || []).forEach(function (c) {
        var codes = findCodes(c.body);
        if (codes.length) out.push({id: "code:" + c.id + ":" + codes[0], kind: "code", label: "Copy code " + codes[0], detail: text(c.app), icon: "copy", arg: codes[0], priority: 90});
    });
    (sig.sessions || []).forEach(function (s) {
        if (!s || !s.app) return;
        out.push({id: "continue:" + s.device + ":" + s.app, kind: "continue", label: "Continue " + (s.appName || s.app), detail: text(s.deviceName), icon: "link", arg: s.app, priority: 60});
    });
    var b = sig.battery || {};
    if (b.percent >= 0 && b.percent <= LOW_BATTERY && !b.charging && !b.saver && b.canSave) {
        out.push({id: "saver", kind: "saver", label: "Battery saver", detail: Math.round(b.percent) + "%", icon: "battery", arg: "", priority: 70});
    }
    out = out.filter(function (s) { return !skip[s.id]; });
    out.sort(function (a, b2) { return b2.priority - a.priority || (a.id < b2.id ? -1 : 1); });
    return out.slice(0, 3);
}
