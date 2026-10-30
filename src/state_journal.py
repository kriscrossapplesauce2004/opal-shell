"""Shell state journal. Journal kinds: panel (open panel), space (focused space), layout (layout mode), toasts (pending toasts)."""
import json
import os
import pathlib
import tempfile

MAX_BYTES = 64 * 1024


def default_path():
    runtime = os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}'
    return pathlib.Path(runtime) / 'opal' / 'journal.jsonl'


def encode(kind, data):
    return json.dumps({'kind': kind, 'data': data}, separators=(',', ':')) + '\n'


class Journal:
    def __init__(self, path=None, max_bytes=MAX_BYTES):
        self.path = pathlib.Path(path) if path is not None else default_path()
        self.max_bytes = max_bytes
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        # Compact on open, so a restart starts with one line per kind.
        self.compact()

    def record(self, kind, data):
        if not isinstance(kind, str) or not kind:
            raise ValueError('kind must be a non-empty string')
        line = encode(kind, data)
        if len(line) > self.max_bytes // 4:
            raise ValueError('record is too large for the journal')
        # Append only. A torn last line is skipped on replay.
        with open(self.path, 'a', encoding='utf-8') as handle:
            handle.write(line)
        if self.path.stat().st_size > self.max_bytes:
            self.compact()

    def replay(self):
        latest = {}
        try:
            text = self.path.read_text(encoding='utf-8')
        except FileNotFoundError:
            return latest
        for line in text.splitlines():
            try:
                entry = json.loads(line)
                latest[entry['kind']] = entry['data']
            except (ValueError, TypeError, KeyError):
                continue
        return latest

    def compact(self):
        latest = self.replay()
        text = ''.join(encode(kind, data) for kind, data in latest.items())
        fd, temp = tempfile.mkstemp(dir=self.path.parent, prefix='.journal.')
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            handle.write(text)
        os.replace(temp, self.path)
