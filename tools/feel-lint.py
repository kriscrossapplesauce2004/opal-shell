#!/usr/bin/env python3
"""Count QML jitter causes per file and ratchet the bad ones against a baseline."""
import argparse
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA = 'opal-feel-lint-v1'
ANIMATORS = ('XAnimator', 'YAnimator', 'OpacityAnimator', 'ScaleAnimator', 'RotationAnimator', 'UniformAnimator')
# Each rule has a key, a column header, a label and a ratchet flag.
RULES = (
    ('canvas', 'canvas', 'Canvas items', True),
    ('loaders', 'loader', 'Loaders', False),
    ('sync_loader', 'sync_ldr', 'Loaders without asynchronous: true', True),
    ('repeaters', 'rep', 'Repeaters', False),
    ('dynamic_repeater', 'dyn_rep', 'Repeaters with a non-literal model', True),
    ('list_views', 'listv', 'ListView and GridView', False),
    ('list_models', 'lmodel', 'ListModel', False),
    ('json_parse', 'jparse', 'JSON.parse call sites', False),
    ('json_stringify', 'jstrfy', 'JSON.stringify call sites', False),
    ('behaviors', 'behav', 'Behaviors', False),
    ('number_animations', 'numanim', 'NumberAnimation', False),
    ('animators', 'animtr', 'Animators (Opacity, X, Y, Scale, Rotation, Uniform)', False),
    ('spring_animations', 'spring', 'SpringAnimation', False),
    ('timers', 'timer', 'Timer', False),
    ('multi_effects', 'mfx', 'MultiEffect', False),
)
RULE_KEYS = tuple(rule[0] for rule in RULES)
BAD_KEYS = tuple(rule[0] for rule in RULES if rule[3])
DEFAULT_ALLOWLIST = [
    {'file': 'src/CaptureMarkup.qml', 'rule': 'canvas', 'max': 1,
     'reason': 'Paint tool: the markup brush needs a CPU canvas.'},
]
OPENER = re.compile(r'([A-Za-z_][\w.]*)(\s+on\s+[\w.]+)?\s*$')
ASYNC_TRUE = re.compile(r'(?<![\w.])asynchronous\s*:\s*true\b')
MODEL_KEY = re.compile(r'(?<![\w.])model\s*:\s*')
JSON_CALL = re.compile(r'(?<![\w.])JSON\s*\.\s*(parse|stringify)\s*\(')
REGEX_AFTER = '(,=:[!&|?{};+-*%<>~^'


def blank(text):
    """Return text with every character except newlines replaced by a space."""
    return re.sub(r'[^\n]', ' ', text)


def string_end(text, start):
    """Return the index just past the string or template that starts at start."""
    quote, j, n = text[start], start + 1, len(text)
    while j < n:
        ch = text[j]
        if ch == '\\':
            j += 2
            continue
        if ch == quote:
            return j + 1
        if ch == '\n' and quote != '`':
            return j
        j += 1
    return n


def regex_end(text, start):
    """Return the index just past the regex literal that starts at start."""
    j, in_class = start + 1, False
    while j < len(text) and text[j] != '\n':
        ch = text[j]
        if ch == '\\':
            j += 2
            continue
        if ch == '[':
            in_class = True
        elif ch == ']':
            in_class = False
        elif ch == '/' and not in_class:
            j += 1
            while j < len(text) and text[j].isalpha():
                j += 1
            return min(j, len(text))
        j += 1
    return min(j, len(text))


def mask_qml(text):
    """Return the text with comments, strings and regex literals blanked."""
    out, i, last, n = [], 0, '', len(text)
    while i < n:
        ch, nxt = text[i], text[i + 1:i + 2]
        if ch == '/' and nxt == '/':
            end = text.find('\n', i)
            end = n if end < 0 else end
        elif ch == '/' and nxt == '*':
            end = text.find('*/', i + 2)
            end = n if end < 0 else end + 2
        elif ch in '"\'`':
            end = string_end(text, i)
            last = ch
        elif ch == '/' and (last == '' or last in REGEX_AFTER):
            end = regex_end(text, i)
            last = 'a'
        else:
            out.append(ch)
            if not ch.isspace():
                last = ch
            i += 1
            continue
        out.append(blank(text[i:end]))
        i = end
    return ''.join(out)


def block_kind(before):
    """Return the QML type that opens a brace after this text, or None."""
    found = OPENER.search(before)
    if not found:
        return None
    name = found.group(1).rsplit('.', 1)[-1]
    if found.group(2) or name[:1].isupper():
        return name
    return None


class Block:
    """One brace-delimited span with its QML type name, if any."""

    def __init__(self, kind, start):
        self.kind, self.start, self.end, self.children = kind, start, None, []


def parse_blocks(masked):
    """Return every brace block in document order, the file root first."""
    root = Block(None, 0)
    root.end = len(masked)
    stack, blocks = [root], [root]
    for index, ch in enumerate(masked):
        if ch == '{':
            block = Block(block_kind(masked[max(0, index - 400):index]), index)
            stack[-1].children.append(block)
            stack.append(block)
            blocks.append(block)
        elif ch == '}' and len(stack) > 1:
            stack.pop().end = index + 1
    for block in stack[1:]:
        block.end = len(masked)
    return blocks


def direct(block, text):
    """Return the block text with its nested blocks blanked out."""
    parts, pos = [], block.start
    for child in block.children:
        parts.append(text[pos:child.start])
        parts.append(blank(text[child.start:child.end]))
        pos = child.end
    parts.append(text[pos:block.end])
    return ''.join(parts)


def model_expression(text, pos):
    """Return the model expression that starts at pos, up to a top-level separator."""
    depth, j = 0, pos
    while j < len(text):
        ch = text[j]
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            if depth == 0:
                break
            depth -= 1
        elif ch in ';\n' and depth == 0:
            break
        j += 1
    return text[pos:j].strip()


def is_literal_model(value):
    """Return True for an integer or for one array literal."""
    if value.isdigit():
        return True
    if not value.startswith('['):
        return False
    depth = 0
    for index, ch in enumerate(value):
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
            if depth == 0:
                return index == len(value) - 1
    return False


MODEL_ID = re.compile(r'\bid\s*:\s*([A-Za-z_]\w*)')
# A model object keeps its rows across updates, so a Repeater over one does not re-create delegates.
STABLE_MODELS = ('ListModel', 'KeyedListModel')


def repeater_is_dynamic(text, stable_ids=()):
    """Return True when a Repeater model is set and is not a literal or a model object of this file."""
    found = MODEL_KEY.search(text)
    if not found:
        return False
    value = model_expression(text, found.end())
    return not is_literal_model(value) and value not in stable_ids


def count_file(text):
    """Return the rule counts for one QML file."""
    masked = mask_qml(text)
    blocks = parse_blocks(masked)
    kinds = collections.Counter(block.kind for block in blocks if block.kind)
    sync = dynamic = 0
    stable_ids = {m.group(1) for block in blocks if block.kind in STABLE_MODELS for m in [MODEL_ID.search(direct(block, masked))] if m}
    for block in blocks:
        if block.kind == 'Loader' and not ASYNC_TRUE.search(direct(block, masked)):
            sync += 1
        elif block.kind == 'Repeater' and repeater_is_dynamic(direct(block, masked), stable_ids):
            dynamic += 1
    json_calls = JSON_CALL.findall(masked)
    return {
        'canvas': kinds['Canvas'],
        'loaders': kinds['Loader'],
        'sync_loader': sync,
        'repeaters': kinds['Repeater'],
        'dynamic_repeater': dynamic,
        'list_views': kinds['ListView'] + kinds['GridView'],
        'list_models': kinds['ListModel'],
        'json_parse': json_calls.count('parse'),
        'json_stringify': json_calls.count('stringify'),
        'behaviors': kinds['Behavior'],
        'number_animations': kinds['NumberAnimation'],
        'animators': sum(kinds[name] for name in ANIMATORS),
        'spring_animations': kinds['SpringAnimation'],
        'timers': kinds['Timer'],
        'multi_effects': kinds['MultiEffect'],
    }


def scan(root):
    """Return per-file rule counts and rule totals for root/src."""
    files = {}
    for path in sorted((root / 'src').glob('*.qml')):
        text = path.read_text(encoding='utf-8', errors='replace')
        files[f'src/{path.name}'] = count_file(text)
    totals = {key: sum(counts[key] for counts in files.values()) for key in RULE_KEYS}
    return files, totals


def load_baseline(path):
    """Read a baseline file and check its schema."""
    data = json.loads(path.read_text(encoding='utf-8'))
    if data.get('schema') != SCHEMA:
        raise ValueError(f'{path}: unknown schema {data.get("schema")!r}')
    return data


def write_baseline(path, files, totals):
    """Write the baseline, keeping the allowlist of an existing file."""
    allowlist = load_baseline(path).get('allowlist', []) if path.exists() else DEFAULT_ALLOWLIST
    doc = {
        'schema': SCHEMA,
        'totals': totals,
        'files': {name: {key: counts[key] for key in BAD_KEYS} for name, counts in sorted(files.items())},
        'allowlist': allowlist,
    }
    path.write_text(json.dumps(doc, indent=2) + '\n', encoding='utf-8')


def check(files, baseline):
    """Return (violations, notes) for the bad-rule counts against the baseline."""
    base_files = baseline.get('files', {})
    allowed = {(item['file'], item['rule']): item for item in baseline.get('allowlist', [])}
    violations, notes = [], []
    for name in sorted(files):
        for key in BAD_KEYS:
            now = files[name][key]
            exception = allowed.get((name, key))
            if exception:
                limit, source = exception['max'], 'allowlist'
                if now == 0:
                    notes.append(f'{name} {key}: allowlist entry is unused')
            elif name in base_files:
                limit, source = base_files[name].get(key, 0), 'baseline'
            else:
                limit, source = 0, 'new file'
            if now > limit:
                violations.append(f'FAIL {name} {key}: {now} > {limit} ({source})')
            elif now < limit and not exception:
                notes.append(f'{name} {key}: {limit} -> {now}')
    for item in baseline.get('allowlist', []):
        if item['file'] not in files:
            notes.append(f'{item["file"]} {item["rule"]}: allowlist entry for a missing file')
    return violations, notes


def table(headers, rows):
    """Return aligned text lines; the first column is left-aligned."""
    all_rows = [tuple(str(cell) for cell in row) for row in [headers, *rows]]
    widths = [max(len(row[i]) for row in all_rows) for i in range(len(headers))]
    lines = []
    for row in all_rows:
        cells = [cell.ljust(width) if i == 0 else cell.rjust(width) for i, (cell, width) in enumerate(zip(row, widths))]
        lines.append('  '.join(cells).rstrip())
    return lines


def render(files, totals):
    """Return the human report: a totals table and a per-file table."""
    lines = ['Totals', '']
    lines += table(('rule', 'total', 'ratchet'),
                   [(label, totals[key], 'yes' if bad else '') for key, _, label, bad in RULES])
    lines += ['', 'Per file (files with any count). Columns follow the Totals order.', '']
    headers = ('file',) + tuple(short for _, short, _, _ in RULES)
    rows = [(name,) + tuple(counts[key] for key in RULE_KEYS)
            for name, counts in sorted(files.items()) if any(counts.values())]
    rows.append(('TOTAL',) + tuple(totals[key] for key in RULE_KEYS))
    lines += table(headers, rows)
    return '\n'.join(lines) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description='Count QML jitter causes in src/ and ratchet the bad ones.')
    parser.add_argument('--root', type=pathlib.Path, default=ROOT, help='Opal source root (default: this repo)')
    parser.add_argument('--baseline', type=pathlib.Path, help='baseline JSON (default: tests/feel-lint-baseline.json)')
    parser.add_argument('--json', action='store_true', dest='as_json', help='print machine-readable output')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true', help='fail if a bad count rose or a new file has one')
    mode.add_argument('--update-baseline', action='store_true', help='rewrite the baseline from src/')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    baseline_path = args.baseline or root / 'tests' / 'feel-lint-baseline.json'
    files, totals = scan(root)
    if args.update_baseline:
        write_baseline(baseline_path, files, totals)
        sys.stdout.write(f'wrote {baseline_path}\n')
        return 0
    if not args.check:
        if args.as_json:
            sys.stdout.write(json.dumps({'totals': totals, 'files': files}, indent=2) + '\n')
        else:
            sys.stdout.write(render(files, totals))
        return 0
    try:
        baseline = load_baseline(baseline_path)
    except (OSError, ValueError, KeyError) as error:
        parser.error(f'cannot read baseline: {error}')
    violations, notes = check(files, baseline)
    if args.as_json:
        payload = {'totals': totals, 'files': files, 'violations': violations, 'notes': notes}
        sys.stdout.write(json.dumps(payload, indent=2) + '\n')
    else:
        for line in violations:
            sys.stdout.write(line + '\n')
        for line in notes:
            sys.stdout.write(f'note: {line}\n')
        if not violations:
            sys.stdout.write('feel-lint: ok, no bad count rose\n')
    return 1 if violations else 0


if __name__ == '__main__':
    sys.exit(main())
