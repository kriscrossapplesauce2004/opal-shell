"""Capture Studio & Screen Recorder for Opal: region/window/screen screenshots, local OCR, and PipeWire screen recording with Live Activities."""
import os, pathlib, re, shutil, signal, subprocess, time
import hypr_actions

GEOM_RE = re.compile(r'^-?\d+,-?\d+ \d+x\d+$')
OUTPUT_RE = re.compile(r'^[A-Za-z0-9._-]{1,64}$')


def window_geometry(address='', actions=None):
    """Return 'x,y wxh' for the given or focused Hyprland window."""
    act = actions or hypr_actions.HyprActions()
    clients = act.clients()
    target = None
    if address:
        target = next((c for c in clients if c.get('address') == address), None)
    if not target:
        focused = [c for c in clients if c.get('focusHistoryID') == 0]
        target = focused[0] if focused else (clients[0] if clients else None)
    if not target:
        raise ValueError('No window available to capture')
    at, size = target.get('at') or [0, 0], target.get('size') or [0, 0]
    w, h = int(size[0]), int(size[1])
    if w <= 0 or h <= 0:
        raise ValueError('Window has empty geometry')
    return '%d,%d %dx%d' % (int(at[0]), int(at[1]), w, h)


class CaptureService:
    def __init__(self, emit, run=subprocess.run, popen=subprocess.Popen, which=shutil.which, home=None, actions=None, sleep=time.sleep):
        self.emit = emit
        self.run = run
        self.popen = popen
        self.which = which
        self.home = pathlib.Path(home or pathlib.Path.home())
        self.actions = actions
        self.sleep = sleep
        self.rec_process = None
        self.rec_path = None
        self.rec_started = 0

    def screenshot(self, mode='screen', geometry='', output='', address='', copy=True, ocr=False, delay=0.18):
        if not self.which('grim'):
            self.emit({'event': 'message', 'text': 'grim is not installed'})
            return None
        if delay > 0:
            self.sleep(delay)
        folder = self.home / 'Pictures/Screenshots'
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / time.strftime('Opal-%Y%m%d-%H%M%S.png')
        cmd = ['grim']
        geom = str(geometry or '').strip()
        out = str(output or '').strip()
        if mode == 'window':
            try:
                geom = window_geometry(address, self.actions)
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                self.emit({'event': 'message', 'text': str(error)})
                return None
        if mode in ('region', 'window') and geom:
            if not GEOM_RE.fullmatch(geom):
                self.emit({'event': 'message', 'text': 'Invalid capture region'})
                return None
            cmd += ['-g', geom]
        elif out:
            if not OUTPUT_RE.fullmatch(out):
                self.emit({'event': 'message', 'text': 'Invalid display output'})
                return None
            cmd += ['-o', out]
        cmd.append(str(dest))
        try:
            res = self.run(cmd, capture_output=True, text=True, timeout=5)
            if getattr(res, 'returncode', 0) != 0:
                raise RuntimeError((getattr(res, 'stderr', '') or 'Capture failed').strip())
        except (OSError, RuntimeError, subprocess.SubprocessError):
            self.emit({'event': 'message', 'text': 'Screenshot failed'})
            return None

        ocr_text = ''
        if ocr and self.which('tesseract'):
            try:
                tres = self.run(['tesseract', str(dest), 'stdout'], capture_output=True, text=True, timeout=8)
                ocr_text = (tres.stdout or '').strip()
                if ocr_text and self.which('wl-copy'):
                    self.run(['wl-copy', '--', ocr_text], input='', capture_output=True, text=True, timeout=2)
            except (OSError, subprocess.SubprocessError):
                pass
        elif copy and self.which('wl-copy'):
            try:
                with open(dest, 'rb') as f:
                    self.run(['wl-copy', '--type', 'image/png'], input=f.read(), capture_output=True, timeout=2)
            except (OSError, subprocess.SubprocessError):
                pass

        self.emit({
            'event': 'captureDone',
            'path': str(dest),
            'mode': mode,
            'copied': bool(copy),
            'ocr': ocr_text[:1000],
        })
        if ocr and ocr_text:
            self.emit({'event': 'message', 'text': 'Text extracted from screen and copied'})
        return str(dest)

    def recording_active(self):
        return self.rec_process is not None and self.rec_process.poll() is None

    def start_recording(self, output='', geometry='', audio=False):
        if self.recording_active():
            return self.stop_recording()
        recorder = 'wf-recorder' if self.which('wf-recorder') else ('gpu-screen-recorder' if self.which('gpu-screen-recorder') else '')
        if not recorder:
            self.emit({'event': 'message', 'text': 'Install wf-recorder to record the screen'})
            return False
        folder = self.home / 'Videos/Recordings'
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / time.strftime('Opal-%Y%m%d-%H%M%S.mp4')
        out = str(output or '').strip()
        geom = str(geometry or '').strip()
        if recorder == 'wf-recorder':
            cmd = ['wf-recorder', '-f', str(dest)]
            if geom and GEOM_RE.fullmatch(geom):
                cmd += ['-g', geom]
            elif out and OUTPUT_RE.fullmatch(out):
                cmd += ['-o', out]
            if audio:
                cmd.append('--audio')
        else:
            cmd = ['gpu-screen-recorder', '-w', out if (out and OUTPUT_RE.fullmatch(out)) else 'screen', '-f', '60', '-o', str(dest)]
            if audio:
                cmd += ['-a', 'default_output']
        try:
            self.rec_process = self.popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as error:
            self.emit({'event': 'message', 'text': f'Could not start recording: {error}'})
            return False
        self.rec_path = dest
        self.rec_started = int(time.time())
        self.emit({'event': 'recordingState', 'active': True, 'path': str(dest), 'startedAt': self.rec_started})
        self.emit({'event': 'activity', 'op': 'start', 'data': {
            'id': 'screen-recording', 'kind': 'recording', 'icon': 'fiber_manual_record',
            'title': 'Recording screen', 'subtitle': dest.name, 'short': 'REC',
            'progress': -2, 'urgent': True,
        }})
        return True

    def stop_recording(self):
        proc = self.rec_process
        path = self.rec_path
        self.rec_process = None
        self.rec_started = 0
        if proc and proc.poll() is None:
            try:
                proc.send_signal(signal.SIGINT)
                proc.wait(timeout=3)
            except (OSError, subprocess.SubprocessError):
                try:
                    proc.terminate()
                except OSError:
                    pass
        saved = str(path) if path else ''
        self.emit({'event': 'recordingState', 'active': False, 'path': saved, 'startedAt': 0})
        if path:
            self.emit({'event': 'activity', 'op': 'start', 'data': {
                'id': 'screen-recording', 'kind': 'recording', 'icon': 'videocam',
                'title': 'Recording saved', 'subtitle': path.name, 'progress': 1, 'ttl': 5,
            }})
            self.emit({'event': 'message', 'text': f'Recording saved · {path.name}'})
        else:
            self.emit({'event': 'activity', 'op': 'end', 'id': 'screen-recording'})
        return True

    def delete_capture(self, raw_path):
        try:
            path = pathlib.Path(str(raw_path or '')).expanduser().resolve()
            allowed = (self.home / 'Pictures/Screenshots').resolve()
            if str(path).startswith(str(allowed) + os.sep) and path.is_file():
                path.unlink()
                self.emit({'event': 'message', 'text': 'Screenshot deleted'})
                return True
        except OSError:
            pass
        return False

    def handle(self, c):
        action = c.get('action', '')
        if action == 'capture-take':
            self.screenshot(
                mode=str(c.get('mode') or 'screen'),
                geometry=str(c.get('geometry') or ''),
                output=str(c.get('output') or ''),
                address=str(c.get('address') or ''),
                copy=c.get('copy') is not False,
                ocr=c.get('ocr') is True,
            )
            return True
        if action == 'capture-record-start':
            self.start_recording(
                output=str(c.get('output') or ''),
                geometry=str(c.get('geometry') or ''),
                audio=c.get('audio') is True,
            )
            return True
        if action == 'capture-record-stop':
            self.stop_recording()
            return True
        if action == 'capture-delete':
            self.delete_capture(c.get('path'))
            return True
        return False
