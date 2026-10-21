#!/usr/bin/env python3
"""Session-only clipboard history: text in memory, images in a private runtime folder. Never reads/writes a cliphist database."""
import hashlib
import json
import os
import re
import shutil
import signal
import struct
import subprocess
import sys
import threading
import time
import uuid

MAX_BYTES = 32768
MAX_ITEMS = 50
MAX_PINS = 25
MAX_IMAGES = 12
MAX_IMAGE_BYTES = 16 * 1024 * 1024
LINK_PATTERN = re.compile(r'https?://\S+\Z')
EMAIL_PATTERN = re.compile(r'(?:mailto:)?[\w.+-]+@[\w-]+(?:\.[\w-]+)+\Z')
COLOR_PATTERN = re.compile(r'#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\Z|'
                           r'(?:rgba?|hsla?)\(\s*[\d.]+%?\s*(?:,\s*|\s+)[\d.]+%?\s*(?:,\s*|\s+)[\d.]+%?\s*(?:(?:,|/)\s*[\d.]+%?\s*)?\)\Z')
PATH_PATTERN = re.compile(r'(?:~|/)[^\n\0]*\Z')
IMAGE_TYPES = ('image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/bmp')
TEXT_TYPES = ('text/plain;charset=utf-8', 'text/plain', 'utf8_string', 'string', 'text')
SENSITIVE_HINTS = ('passwordmanagerhint', 'keepass', 'sensitive', 'secret')


def _detach_with_parent():
    """Runs in the watcher child: a new session, and SIGTERM when the backend ends, so no watcher is orphaned."""
    os.setsid()
    try:
        import ctypes
        ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass


def store_dir():
    """Private image folder on the session tmpfs. It is not kept after logout."""
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    return os.path.join(runtime, 'opal-clipboard') if runtime else None


def kind_of(text):
    """Classify one clip for icons, filters and preview actions."""
    stripped = text.strip()
    if '\n' in stripped:
        return 'Snippet'
    if LINK_PATTERN.fullmatch(stripped):
        return 'Link'
    if EMAIL_PATTERN.fullmatch(stripped):
        return 'Email'
    if COLOR_PATTERN.fullmatch(stripped):
        return 'Color'
    if len(stripped) < 1024 and PATH_PATTERN.fullmatch(stripped) and (stripped.startswith('~/') or stripped.count('/') >= 2):
        return 'Path'
    return 'Text'


def image_size(raw):
    """Reads pixel size from a PNG, GIF, BMP, JPEG or WebP header. It returns (0, 0) when unknown."""
    try:
        if raw[:8] == b'\x89PNG\r\n\x1a\n':
            return struct.unpack('>II', raw[16:24])
        if raw[:6] in (b'GIF87a', b'GIF89a'):
            return struct.unpack('<HH', raw[6:10])
        if raw[:2] == b'BM':
            width, height = struct.unpack('<ii', raw[18:26])
            return abs(width), abs(height)
        if raw[:4] == b'RIFF' and raw[8:12] == b'WEBP':
            if raw[12:16] == b'VP8X':
                return (int.from_bytes(raw[24:27], 'little') + 1, int.from_bytes(raw[27:30], 'little') + 1)
            if raw[12:16] == b'VP8L':
                bits = int.from_bytes(raw[21:25], 'little')
                return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
            if raw[12:16] == b'VP8 ':
                width, height = struct.unpack('<HH', raw[26:30])
                return width & 0x3FFF, height & 0x3FFF
        if raw[:2] == b'\xff\xd8':
            index = 2
            while index + 9 < len(raw):
                if raw[index] != 0xFF:
                    index += 1
                    continue
                marker = raw[index + 1]
                length = struct.unpack('>H', raw[index + 2:index + 4])[0]
                if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    height, width = struct.unpack('>HH', raw[index + 5:index + 9])
                    return width, height
                index += 2 + length
    except struct.error:
        pass
    return 0, 0


def capture():
    """Invoked by wl-paste; copied data is stdin, never a shell argument."""
    if os.environ.get('CLIPBOARD_STATE', 'data') != 'data':
        return
    try:
        types = subprocess.check_output(['wl-paste', '--list-types'],
                                        stderr=subprocess.DEVNULL, timeout=1).decode().lower()
        if any(hint in types for hint in SENSITIVE_HINTS):
            return
        offered = [line.strip() for line in types.splitlines() if line.strip()]
        mime = next((t for t in IMAGE_TYPES if t in offered), None)
        # Plain text wins. An image wins over rich text only, for example a browser image copy.
        if any(t in TEXT_TYPES for t in offered) or mime is None and any(t.startswith('text/') for t in offered):
            raw = sys.stdin.buffer.read(MAX_BYTES + 1)
            if not raw or len(raw) > MAX_BYTES or b'\0' in raw:
                return
            text = raw.decode('utf-8')
            if text.strip():
                print(json.dumps({'text': text}), flush=True)
            return
        folder = os.environ.get('OPAL_CLIPBOARD_DIR', '')
        if mime is None or not folder or not os.path.isdir(folder):
            return
        # Read the exact image type. Stdin can hold a different type that wl-paste chose, so it is drained.
        while sys.stdin.buffer.read(65536):
            pass
        raw = subprocess.run(['wl-paste', '--type', mime], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, timeout=3).stdout
        if not raw or len(raw) > MAX_IMAGE_BYTES:
            return
        digest = hashlib.sha1(raw).hexdigest()
        path = os.path.join(folder, digest + '.' + mime.split('/')[1])
        if not os.path.exists(path):
            descriptor = os.open(path + '.part', os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descriptor, 'wb') as handle:
                handle.write(raw)
            os.replace(path + '.part', path)
        width, height = image_size(raw)
        print(json.dumps({'image': path, 'mime': mime, 'bytes': len(raw), 'hash': digest,
                          'width': width, 'height': height}), flush=True)
    except (OSError, UnicodeError, subprocess.SubprocessError):
        return


class ClipboardHistory:
    def __init__(self, emit, source=None):
        self.emit = emit
        # Optional callable that names the focused app class when a clip arrives.
        self.source = source
        self.items = []
        self._by_text = {}
        self._by_id = {}
        self.paused = False
        self.available = False
        self.detail = 'Waiting for clipboard service'
        self.lock = threading.RLock()
        self.wake = threading.Event()
        self.stopped = threading.Event()
        self.process = None
        self.folder = None

    def publish(self):
        with self.lock:
            self.emit({'event': 'clipboard', 'items': [{k: v for k, v in i.items() if k != 'key'} for i in self.items],
                       'paused': self.paused, 'available': self.available,
                       'detail': self.detail, 'limit': MAX_ITEMS})

    def _source(self):
        if self.source is None:
            return ''
        try:
            return str(self.source() or '')[:80]
        except Exception:
            return ''

    def _drop(self, entry):
        self.items.remove(entry)
        self._by_text.pop(entry['key'], None)
        self._by_id.pop(entry['id'], None)
        if entry['kind'] == 'Image':
            try:
                os.unlink(entry['image'])
            except OSError:
                pass

    def _trim(self):
        # Pins are never evicted by new clips. Images have their own smaller limit.
        for kind, limit in (('Image', MAX_IMAGES), (None, MAX_ITEMS)):
            loose = [e for e in self.items if not e['pinned'] and (kind is None or e['kind'] == kind)]
            for entry in loose[limit:]:
                self._drop(entry)

    def _insert(self, key, fields, source):
        existing = self._by_text.get(key)
        if existing is not None:
            self.items.remove(existing)
            del self._by_id[existing['id']]
        entry = {'id': existing['id'] if existing else uuid.uuid4().hex, 'key': key,
                 'pinned': existing['pinned'] if existing else False,
                 'source': existing['source'] if existing and existing.get('source') else source,
                 'captured': int(time.time() * 1000)}
        entry.update(fields)
        self.items.insert(0, entry)
        self._by_text[key] = entry
        self._by_id[entry['id']] = entry
        self._trim()
        self.publish()

    def add(self, text, sensitive=False):
        if not isinstance(text, str) or sensitive or '\0' in text:
            return False
        stripped = text.strip()
        if not stripped:
            return False
        encoded = text.encode('utf-8')
        if len(encoded) > MAX_BYTES:
            return False
        source = self._source()
        with self.lock:
            if self.paused:
                return False
            kind = kind_of(text)
            fields = {'text': text, 'chars': len(text), 'lines': text.count('\n') + 1, 'kind': kind}
            if kind == 'Link':
                fields['host'] = re.sub(r'^https?://(?:www\.)?', '', stripped).split('/')[0][:120]
            self._insert(text, fields, source)
        return True

    def add_image(self, path, mime, size, digest, width=0, height=0):
        """Registers an image file that the capture helper wrote to the private folder."""
        if not isinstance(path, str) or mime not in IMAGE_TYPES or not isinstance(digest, str):
            return False
        with self.lock:
            folder = self.folder
        if not folder or os.path.dirname(os.path.realpath(path)) != os.path.realpath(folder) or not os.path.isfile(path):
            return False
        source = self._source()
        with self.lock:
            if self.paused:
                try:
                    os.unlink(path)
                except OSError:
                    pass
                return False
            fields = {'text': '', 'chars': 0, 'lines': 0, 'kind': 'Image', 'image': path,
                      'mime': mime, 'bytes': int(size), 'width': int(width or 0), 'height': int(height or 0)}
            self._insert('\0image:' + digest, fields, source)
        return True

    def entry(self, identity):
        with self.lock:
            entry = self._by_id.get(identity)
            return entry.copy() if entry else None

    def delete(self, identity):
        with self.lock:
            entry = self._by_id.get(identity)
            if entry is not None:
                self._drop(entry)
            self.publish()

    def pin(self, identity, value):
        with self.lock:
            entry = self._by_id.get(identity)
            if entry is not None:
                if value and not entry['pinned'] and sum(1 for e in self.items if e['pinned']) >= MAX_PINS:
                    return False
                entry['pinned'] = bool(value)
                self._trim()
            self.publish()
        return entry is not None

    def clear(self, pinned=False):
        # Only this process's history. Never clear the system clipboard or other managers.
        with self.lock:
            for entry in [e for e in self.items if pinned or not e['pinned']]:
                self._drop(entry)
            self.publish()

    def _wl_copy(self, data, mime):
        if not shutil.which('wl-copy'):
            return False
        try:
            subprocess.run(['wl-copy', '--type', mime], input=data, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
            return True
        except (OSError, subprocess.SubprocessError):
            return False

    def copy(self, identity):
        with self.lock:
            entry = self._by_id.get(identity)
            entry = entry.copy() if entry else None
        success = False
        if entry is not None and entry['kind'] == 'Image':
            try:
                with open(entry['image'], 'rb') as handle:
                    data = handle.read(MAX_IMAGE_BYTES + 1)
                success = len(data) <= MAX_IMAGE_BYTES and self._wl_copy(data, entry['mime'])
            except OSError:
                success = False
        elif entry is not None:
            success = self._wl_copy(entry['text'].encode('utf-8'), 'text/plain;charset=utf-8')
        self.emit({'event': 'clipboardCopied', 'id': identity, 'success': success})
        return success

    def copy_text(self, text, token='text'):
        """Copies a derived form of a clip, for example one line or another colour notation."""
        success = (isinstance(text, str) and text != '' and '\0' not in text
                   and len(text.encode('utf-8')) <= MAX_BYTES
                   and self._wl_copy(text.encode('utf-8'), 'text/plain;charset=utf-8'))
        self.emit({'event': 'clipboardCopied', 'id': token, 'success': bool(success)})
        return bool(success)

    def terminate_watcher(self):
        with self.lock:
            process = self.process
        if process is not None and process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def set_paused(self, value):
        with self.lock:
            self.paused = bool(value)
            self.publish()
        if value:
            self.terminate_watcher()
        self.wake.set()

    def stop(self):
        self.stopped.set()
        self.terminate_watcher()
        self.wake.set()
        self._wipe_folder()

    def _wipe_folder(self):
        folder = self.folder
        if not folder or not os.path.isdir(folder):
            return
        for name in os.listdir(folder):
            try:
                os.unlink(os.path.join(folder, name))
            except OSError:
                pass

    def _prepare_folder(self):
        folder = store_dir()
        if not folder:
            return None
        try:
            os.makedirs(folder, mode=0o700, exist_ok=True)
            os.chmod(folder, 0o700)
        except OSError:
            return None
        self.folder = folder
        # Images from an earlier backend have no history entry, so they are removed.
        self._wipe_folder()
        return folder

    def watch(self):
        if not os.environ.get('WAYLAND_DISPLAY') or not shutil.which('wl-paste'):
            self.detail = 'Requires Wayland data-control and wl-clipboard'
            self.publish()
            return
        folder = self._prepare_folder()
        env = dict(os.environ, OPAL_CLIPBOARD_DIR=folder or '')
        while not self.stopped.is_set():
            self.wake.clear()
            if self.paused:
                self.wake.wait()
                continue
            process = None
            try:
                with self.lock:
                    # Serialize spawn with pause, so a paused watcher cannot restart.
                    if self.paused or self.stopped.is_set():
                        continue
                    process = subprocess.Popen(
                        ['wl-paste', '--no-newline', '--watch', sys.executable,
                         os.path.abspath(__file__), '--capture'],
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env,
                        text=True, preexec_fn=_detach_with_parent)
                    self.process = process
                    self.available = True
                    self.detail = 'Text and images · session memory · %d entries' % MAX_ITEMS
                    self.publish()
                for line in process.stdout:
                    if self.stopped.is_set():
                        break
                    try:
                        data = json.loads(line)
                        if 'image' in data:
                            self.add_image(data.get('image'), data.get('mime'), data.get('bytes', 0), data.get('hash'),
                                           data.get('width', 0), data.get('height', 0))
                        else:
                            self.add(data.get('text'))
                    except (ValueError, TypeError, AttributeError):
                        continue
                process.wait(timeout=2)
            except (OSError, subprocess.SubprocessError):
                if process is not None:
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
            finally:
                if process is not None:
                    if process.stdout:
                        process.stdout.close()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                with self.lock:
                    self.process = None
                    if not self.paused and not self.stopped.is_set():
                        self.available = False
                        self.detail = 'Clipboard watching unavailable on this compositor'
                    self.publish()
            self.wake.wait(5)


if __name__ == '__main__' and '--capture' in sys.argv:
    capture()
