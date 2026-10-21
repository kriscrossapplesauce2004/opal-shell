.pragma library

// Pure clipboard helpers: kind styles, filters, relative time and colour notations.

const kinds = {
    Text: {icon: "notes", label: "Text", filter: "text"},
    Snippet: {icon: "code", label: "Code", filter: "code"},
    Link: {icon: "link", label: "Link", filter: "links"},
    Email: {icon: "mail", label: "Email", filter: "links"},
    Path: {icon: "folder", label: "Path", filter: "text"},
    Color: {icon: "palette", label: "Colour", filter: "colors"},
    Image: {icon: "image", label: "Image", filter: "images"}
};

// Filter chips in display order. "all" and "pinned" are always first.
const filters = [
    {id: "all", label: "All", icon: ""},
    {id: "pinned", label: "Pinned", icon: "keep"},
    {id: "links", label: "Links", icon: "link"},
    {id: "code", label: "Code", icon: "code"},
    {id: "images", label: "Images", icon: "image"},
    {id: "colors", label: "Colours", icon: "palette"},
    {id: "text", label: "Text", icon: "notes"}
];

function info(record) { return kinds[record && record.kind] || kinds.Text; }

function matchesFilter(record, filter) {
    if (!filter || filter === "all") return true;
    if (filter === "pinned") return !!record.pinned;
    return info(record).filter === filter;
}

function counts(items) {
    const out = {all: items.length, pinned: 0, links: 0, code: 0, images: 0, colors: 0, text: 0};
    for (const item of items) {
        if (item.pinned) out.pinned++;
        out[info(item).filter]++;
    }
    return out;
}

function appName(source, appForClass) {
    if (!source) return "";
    const app = appForClass ? appForClass(source) : null;
    if (app && app.name) return app.name;
    const tail = String(source).split(".").pop();
    return tail.charAt(0).toUpperCase() + tail.slice(1);
}

function matchesQuery(record, query, appForClass) {
    if (!query) return true;
    const hay = [record.text || "", record.host || "", info(record).label, appName(record.source, appForClass)].join("\n").toLowerCase();
    return query.split(/\s+/).every(word => hay.indexOf(word) >= 0);
}

function ago(ms, now) {
    if (!ms) return "";
    const s = Math.max(0, Math.round((now - ms) / 1000));
    if (s < 45) return "now";
    if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min";
    if (s < 86400) return Math.round(s / 3600) + " h";
    const days = Math.round(s / 86400);
    return days === 1 ? "yesterday" : days + " days";
}

function group(record, now) {
    if (record.pinned) return "Pinned";
    if (!record.captured) return "Recent";
    const start = new Date(now); start.setHours(0, 0, 0, 0);
    return record.captured >= start.getTime() ? "Today" : "Earlier";
}

function bytes(n) {
    if (!n) return "";
    if (n < 1024) return n + " B";
    if (n < 1048576) return Math.round(n / 1024) + " KB";
    return (n / 1048576).toFixed(1) + " MB";
}

// Short description under the text: kind, detail, age and source.
function meta(record, now, appForClass) {
    const k = info(record);
    const parts = [k.label];
    if (record.kind === "Link" && record.host) parts.push(record.host);
    else if (record.kind === "Image") parts.push(String(record.mime || "image/png").split("/")[1].toUpperCase(), bytes(record.bytes));
    else if (record.lines > 1) parts.push(record.lines + " lines");
    else if (record.kind === "Text" && record.chars > 40) parts.push(record.chars + " chars");
    const when = ago(record.captured, now);
    if (when) parts.push(when);
    const app = appName(record.source, appForClass);
    if (app) parts.push(app);
    return parts.filter(p => p).join("  ·  ");
}

function imageTitle(record) {
    return record.width && record.height ? record.width + " × " + record.height : String(record.mime || "image/png").split("/")[1].toUpperCase() + " image";
}

function oneLine(text) { return String(text || "").replace(/\s+/g, " ").trim(); }

// Colour parsing for the swatch and the notation chips. It returns null for text that is not a colour.
function parseColor(text) {
    const t = String(text || "").trim().toLowerCase();
    let m = t.match(/^#([0-9a-f]{3,8})$/);
    if (m) {
        let h = m[1];
        if (h.length === 3 || h.length === 4) h = h.split("").map(c => c + c).join("");
        if (h.length !== 6 && h.length !== 8) return null;
        return {r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16), a: h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1};
    }
    m = t.match(/^(rgba?|hsla?)\(\s*([\d.]+)(%?)\s*[,\s]\s*([\d.]+)(%?)\s*[,\s]\s*([\d.]+)(%?)\s*(?:[,/]\s*([\d.]+)(%?)\s*)?\)$/);
    if (!m) return null;
    const alpha = m[8] === undefined ? 1 : m[9] ? +m[8] / 100 : +m[8];
    if (m[1].startsWith("rgb")) {
        const ch = (v, pct) => Math.round(Math.max(0, Math.min(255, pct ? v * 2.55 : v)));
        return {r: ch(+m[2], m[3]), g: ch(+m[4], m[5]), b: ch(+m[6], m[7]), a: alpha};
    }
    const h = ((+m[2] % 360) + 360) % 360 / 360, s = Math.min(1, +m[4] / 100), l = Math.min(1, +m[6] / 100);
    const hue = (p, q, x) => { x = (x + 1) % 1; return x < 1/6 ? p + (q - p) * 6 * x : x < 1/2 ? q : x < 2/3 ? p + (q - p) * (2/3 - x) * 6 : p; };
    const q = l < .5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    return {r: Math.round(hue(p, q, h + 1/3) * 255), g: Math.round(hue(p, q, h) * 255), b: Math.round(hue(p, q, h - 1/3) * 255), a: alpha};
}

function hex(c) { const x = v => v.toString(16).padStart(2, "0"); return "#" + x(c.r) + x(c.g) + x(c.b) + (c.a < 1 ? x(Math.round(c.a * 255)) : ""); }

function notations(c) {
    const r = c.r / 255, g = c.g / 255, b = c.b / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, d = max - min;
    let h = 0, s = 0;
    if (d) {
        s = d / (1 - Math.abs(2 * l - 1));
        h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
        h = Math.round(h * 60 + 360) % 360;
    }
    const a = c.a < 1 ? " / " + (+c.a.toFixed(2)) : "";
    return [
        {label: "HEX", value: hex(c)},
        {label: "RGB", value: "rgb(" + c.r + " " + c.g + " " + c.b + a + ")"},
        {label: "HSL", value: "hsl(" + h + " " + Math.round(s * 100) + "% " + Math.round(l * 100) + "%" + a + ")"}
    ];
}
