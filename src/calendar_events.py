"""Read local calendars (.ics files) for the clock pill and the clock card. No network and no third-party modules."""
import datetime as dt
import os
import re
from pathlib import Path

try:
    from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
except ImportError:  # pragma: no cover
    ZoneInfo = None
    ZoneInfoNotFoundError = Exception

HOME = Path.home()
MAX_FILES = 400
MAX_BYTES = 4 * 1024 * 1024
MAX_EVENTS = 200
MEETING = re.compile(r'https?://[^\s<>"\\]*(meet\.google\.com|zoom\.us|teams\.microsoft\.com|teams\.live\.com|meet\.jit\.si|whereby\.com|discord\.(gg|com))[^\s<>"\\]*', re.I)
WEEKDAYS = {'MO': 0, 'TU': 1, 'WE': 2, 'TH': 3, 'FR': 4, 'SA': 5, 'SU': 6}


def roots(extra=()):
    """Folders that commonly hold synced calendars, plus Opal's own folder and any the user added."""
    data = Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local/share')
    found = [data / 'opal/calendar', HOME / '.calendars', data / 'vdirsyncer', data / 'khal', data / 'evolution/calendar']
    found += [Path(os.path.expanduser(str(p))) for p in extra if isinstance(p, str) and p.strip()]
    return [p for p in found if p.is_dir()]


def files(extra=()):
    out = []
    for root in roots(extra):
        for path in sorted(root.rglob('*.ics')):
            try:
                if path.is_file() and path.stat().st_size <= MAX_BYTES: out.append(path)
            except OSError:
                continue
            if len(out) >= MAX_FILES: return out
    return out


def signature(extra=()):
    sig = []
    for path in files(extra):
        try:
            st = path.stat()
        except OSError:
            continue
        sig.append((str(path), st.st_mtime_ns, st.st_size))
    return tuple(sig)


def unfold(text):
    """Join folded lines (a line that starts with a space continues the previous one)."""
    lines = []
    for raw in text.replace('\r\n', '\n').replace('\r', '\n').split('\n'):
        if raw[:1] in (' ', '\t') and lines: lines[-1] += raw[1:]
        elif raw: lines.append(raw)
    return lines


def split_line(line):
    """'DTSTART;TZID=Europe/London:20261028T150000' -> ('DTSTART', {'TZID': 'Europe/London'}, '20261028T150000')."""
    head, _, value = line.partition(':')
    parts = head.split(';')
    params = {}
    for p in parts[1:]:
        k, _, v = p.partition('=')
        params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value


def unescape(value):
    return value.replace('\\n', '\n').replace('\\N', '\n').replace('\\,', ',').replace('\\;', ';').replace('\\\\', '\\')


def zone(name, local):
    if name and ZoneInfo:
        try:
            return ZoneInfo(name)
        except (ZoneInfoNotFoundError, ValueError, OSError):
            pass
    return local


def parse_time(value, params, local):
    """Return (aware datetime, all-day flag) or (None, False)."""
    value = value.strip()
    try:
        if params.get('VALUE') == 'DATE' or re.fullmatch(r'\d{8}', value):
            d = dt.datetime.strptime(value[:8], '%Y%m%d')
            return d.replace(tzinfo=local), True
        if value.endswith('Z'):
            return dt.datetime.strptime(value[:15], '%Y%m%dT%H%M%S').replace(tzinfo=dt.timezone.utc), False
        return dt.datetime.strptime(value[:15], '%Y%m%dT%H%M%S').replace(tzinfo=zone(params.get('TZID'), local)), False
    except ValueError:
        return None, False


def parse_duration(value):
    m = re.fullmatch(r'([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?', value.strip())
    if not m: return None
    sign = -1 if m.group(1) == '-' else 1
    w, d, h, mi, s = (int(x or 0) for x in m.groups()[1:])
    return sign * dt.timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)


def parse(text, local=None):
    """Events from one calendar file: dicts with title, start, end, allDay, location, join, rrule, exdates, uid."""
    local = local or dt.datetime.now().astimezone().tzinfo
    events, cur = [], None
    for line in unfold(text):
        name, params, value = split_line(line)
        if name == 'BEGIN' and value.upper() == 'VEVENT':
            cur = {'exdates': []}
        elif name == 'END' and value.upper() == 'VEVENT' and cur is not None:
            if cur.get('start') and cur.get('status') != 'CANCELLED':
                if not cur.get('end'):
                    cur['end'] = cur['start'] + (cur.pop('duration', None) or (dt.timedelta(days=1) if cur.get('allDay') else dt.timedelta(0)))
                cur.pop('duration', None)
                text_blob = ' '.join([cur.get('url', ''), cur.get('location', ''), cur.get('description', '')])
                found = MEETING.search(text_blob)
                cur['join'] = found.group(0) if found else ''
                cur.pop('description', None); cur.pop('url', None); cur.pop('status', None)
                events.append(cur)
            cur = None
        elif cur is None:
            continue
        elif name == 'SUMMARY': cur['title'] = unescape(value).strip()
        elif name == 'LOCATION': cur['location'] = unescape(value).strip()
        elif name == 'DESCRIPTION': cur['description'] = unescape(value)
        elif name == 'URL': cur['url'] = value.strip()
        elif name == 'UID': cur['uid'] = value.strip()
        elif name == 'STATUS': cur['status'] = value.strip().upper()
        elif name == 'RRULE': cur['rrule'] = dict(p.split('=', 1) for p in value.split(';') if '=' in p)
        elif name in ('DTSTART', 'DTEND'):
            t, all_day = parse_time(value, params, local)
            if t is None: continue
            if name == 'DTSTART': cur['start'], cur['allDay'] = t, all_day
            else: cur['end'] = t
        elif name == 'DURATION':
            d = parse_duration(value)
            if d is not None: cur['duration'] = d
        elif name == 'EXDATE':
            for v in value.split(','):
                t, _ = parse_time(v, params, local)
                if t: cur['exdates'].append(t)
    return events


def add_months(d, months):
    y, m = divmod(d.month - 1 + months, 12)
    try:
        return d.replace(year=d.year + y, month=m + 1)
    except ValueError:
        return None


def occurrences(event, start, end, limit=400):
    """Start times of an event inside [start, end). Supports DAILY, WEEKLY (with BYDAY), MONTHLY and YEARLY rules."""
    first = event['start']
    length = event['end'] - first
    rule = event.get('rrule')
    exdates = set(event.get('exdates') or [])
    if not rule:
        return [first] if first < end and first + length > start else []
    freq = rule.get('FREQ', '').upper()
    interval = max(1, int(rule.get('INTERVAL', '1') or 1)) if str(rule.get('INTERVAL', '1')).isdigit() else 1
    count = int(rule['COUNT']) if str(rule.get('COUNT', '')).isdigit() else None
    until = None
    if rule.get('UNTIL'):
        until, _ = parse_time(rule['UNTIL'], {}, first.tzinfo)
    days = [WEEKDAYS[d[-2:]] for d in rule.get('BYDAY', '').split(',') if d[-2:] in WEEKDAYS] if freq == 'WEEKLY' else []
    out, n, step = [], 0, 0
    while step < 5000 and len(out) < limit:
        if freq == 'DAILY': batch = [first + dt.timedelta(days=step * interval)]
        elif freq == 'WEEKLY':
            week = first + dt.timedelta(weeks=step * interval)
            monday = week - dt.timedelta(days=week.weekday())
            batch = sorted(monday + dt.timedelta(days=d) for d in days) if days else [week]
            batch = [b for b in batch if b >= first]
        elif freq == 'MONTHLY': batch = [add_months(first, step * interval)]
        elif freq == 'YEARLY': batch = [add_months(first, 12 * step * interval)]
        else: return [first] if first < end and first + length > start else []
        step += 1
        stop = False
        for t in batch:
            if t is None: continue
            if until and t > until or count is not None and n >= count: stop = True; break
            n += 1
            if t >= end: stop = True; break
            if t + length > start and t not in exdates: out.append(t)
        if stop: break
    return out


def upcoming(now=None, days=42, extra=(), local=None):
    """Occurrences from the start of this month for the given span, sorted, as plain JSON-able dicts (times in ms)."""
    now = now or dt.datetime.now().astimezone()
    local = local or now.tzinfo
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0) - dt.timedelta(days=7)
    end = now + dt.timedelta(days=days)
    out = []
    for path in files(extra):
        try:
            events = parse(path.read_text(errors='replace'), local)
        except OSError:
            continue
        for ev in events:
            for t in occurrences(ev, start, end):
                stop = t + (ev['end'] - ev['start'])
                out.append({'uid': ev.get('uid', ''), 'title': ev.get('title') or 'Event', 'location': ev.get('location', ''),
                            'join': ev.get('join', ''), 'allDay': bool(ev.get('allDay')),
                            'start': int(t.timestamp() * 1000), 'end': int(stop.timestamp() * 1000)})
    out.sort(key=lambda e: (e['start'], e['title']))
    return out[:MAX_EVENTS]


def clocks(names, now=None):
    """World clocks: each zone's label and current UTC offset in minutes. Unknown zones are skipped."""
    now = now or dt.datetime.now(dt.timezone.utc)
    out = []
    for name in names or []:
        if not isinstance(name, str) or not ZoneInfo: continue
        try:
            tz = ZoneInfo(name)
        except (ZoneInfoNotFoundError, ValueError, OSError):
            continue
        offset = now.astimezone(tz).utcoffset() or dt.timedelta(0)
        out.append({'zone': name, 'label': name.split('/')[-1].replace('_', ' '), 'offset': int(offset.total_seconds() // 60)})
    return out
