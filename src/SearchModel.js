.pragma library
.import "StartSearch.js" as Rank

// Pure search helpers: question detection, unit conversion, settings ranking and the merge of every source into sections.

var QUESTION_START = /^(how|what|whats|what's|why|when|where|who|which|can|could|should|would|is|are|does|do|did|explain|write|summari[sz]e|tell me|help me|make me|give me|translate|compare)\b/i;

// True when the text reads like a question for Claude, not a name to look up.
function isQuestion(text) {
    var q = String(text || "").trim();
    if (q.length < 6) return false;
    var words = q.split(/\s+/).length;
    if (/\?$/.test(q) && words >= 2) return true;
    return QUESTION_START.test(q) && words >= 3;
}

// Units in groups. Each factor converts to the base unit of its group.
var UNITS = {
    length: {mm: .001, cm: .01, m: 1, km: 1000, in: .0254, inch: .0254, inches: .0254, ft: .3048, foot: .3048, feet: .3048, yd: .9144, mi: 1609.344, mile: 1609.344, miles: 1609.344},
    mass: {mg: .001, g: 1, kg: 1000, t: 1e6, oz: 28.349523125, lb: 453.59237, lbs: 453.59237, st: 6350.29318},
    data: {b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776},
    time: {ms: .001, s: 1, sec: 1, min: 60, h: 3600, hr: 3600, hour: 3600, hours: 3600, d: 86400, day: 86400, days: 86400, week: 604800, weeks: 604800},
    volume: {ml: .001, l: 1, cl: .01, gal: 3.785411784, qt: .946352946, pt: .473176473, cup: .2365882365, floz: .0295735295625},
    speed: {"m/s": 1, mps: 1, "km/h": 1 / 3.6, kmh: 1 / 3.6, kph: 1 / 3.6, mph: .44704, kn: .514444, knots: .514444},
    area: {m2: 1, km2: 1e6, ha: 1e4, acre: 4046.8564224, acres: 4046.8564224, ft2: .09290304, sqft: .09290304}
};
var TEMPS = {c: "C", "°c": "C", celsius: "C", f: "F", "°f": "F", fahrenheit: "F", k: "K", kelvin: "K"};

function unitGroup(unit) {
    for (var g in UNITS) if (UNITS[g][unit] !== undefined) return g;
    return "";
}
function tidy(value) {
    var abs = Math.abs(value);
    var text = abs !== 0 && (abs >= 1e9 || abs < 1e-3) ? value.toExponential(3) : String(Math.round(value * 1000) / 1000);
    return text.replace(/(\.\d*?)0+(e|$)/, "$1$2").replace(/\.(e|$)/, "$1");
}
function toKelvin(v, u) { return u === "K" ? v : u === "C" ? v + 273.15 : (v - 32) * 5 / 9 + 273.15; }
function fromKelvin(v, u) { return u === "K" ? v : u === "C" ? v - 273.15 : (v - 273.15) * 9 / 5 + 32; }

// Convert "5 km to mi", "100 f in c" or "2 gib as mb". Return {from, to, value, text} or null.
function convert(text) {
    var m = /^\s*(-?\d+(?:[.,]\d+)?)\s*([a-zA-Z°/0-9]+?)\s+(?:to|in|as|into)\s+([a-zA-Z°/0-9]+)\s*$/.exec(String(text || ""));
    if (!m) return null;
    var value = parseFloat(m[1].replace(",", ".")), from = m[2].toLowerCase(), to = m[3].toLowerCase();
    if (TEMPS[from] && TEMPS[to]) {
        var out = fromKelvin(toKelvin(value, TEMPS[from]), TEMPS[to]);
        return {from: tidy(value) + " °" + TEMPS[from], to: "°" + TEMPS[to], value: out, text: tidy(out) + " °" + TEMPS[to]};
    }
    var group = unitGroup(from);
    if (!group || unitGroup(to) !== group) return null;
    var result = value * UNITS[group][from] / UNITS[group][to];
    return {from: tidy(value) + " " + m[2], to: m[3], value: result, text: tidy(result) + " " + m[3]};
}

// Rank settings entries: {id, title, path, keywords}. A strong word match puts them near the top.
function settings(query, index) {
    var out = [];
    (index || []).forEach(function (s) {
        var rank = Rank.score(s.title, (s.path || "") + " " + (s.keywords || ""), query);
        if (rank >= 0) out.push(Object.assign({}, s, {score: rank}));
    });
    out.sort(function (a, b) { return b.score - a.score || a.title.localeCompare(b.title); });
    return out;
}

// Generic ranker for files, games and other simple rows: {title, detail, keywords}.
function rank(query, rows, boost) {
    var out = [];
    (rows || []).forEach(function (r) {
        var s = Rank.score(r.title, (r.detail || "") + " " + (r.keywords || ""), query);
        if (s >= 0) out.push(Object.assign({}, r, {score: s + (boost || 0)}));
    });
    out.sort(function (a, b) { return b.score - a.score || String(a.title).localeCompare(String(b.title)); });
    return out;
}

// The order of the sections under the answer cards.
var SECTIONS = [["app", "Apps"], ["window", "Windows"], ["setting", "Settings"], ["action", "Actions"], ["file", "Files"], ["media", "Media"], ["game", "Games"], ["device", "On your devices"]];

// Build sections from per-source result lists. The best result of all leads, then each source keeps at most "per" rows.
function sections(lists, per) {
    var limit = per || 4, all = [];
    SECTIONS.forEach(function (s) { (lists[s[0]] || []).forEach(function (r) { all.push(Object.assign({}, r, {kind: r.kind || s[0]})); }); });
    all.sort(function (a, b) { return b.score - a.score; });
    var best = all.length && all[0].score >= 500 ? all[0] : null;
    var out = [];
    SECTIONS.forEach(function (s) {
        var items = (lists[s[0]] || []).map(function (r) { return Object.assign({}, r, {kind: r.kind || s[0]}); })
            .filter(function (r) { return !best || r.key !== best.key; }).slice(0, limit);
        if (items.length) out.push({id: s[0], title: s[1], items: items});
    });
    return {best: best, sections: out};
}
