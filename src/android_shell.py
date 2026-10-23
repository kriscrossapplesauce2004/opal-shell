"""Shell commands inside Waydroid without root: ADB over the container's network address. "waydroid shell" needs root, so it is only a fallback for root."""
import os, re, shutil, subprocess, threading

PORT = 5555
IP_RE = re.compile(r'^\d{1,3}(\.\d{1,3}){3}$')


def parse_versions(text):
    """Map package name to versionCode from 'pm list packages --show-versioncode' output."""
    out = {}
    for line in str(text or '').splitlines():
        m = re.match(r'\s*package:(\S+)\s+versionCode:(\d+)', line)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


class AndroidShell:
    def __init__(self, address, run=subprocess.run, which=shutil.which, euid=os.geteuid):
        # address returns the container IP from "waydroid status", or '' when the session is not running.
        self.address = address
        self.run = run
        self.which = which
        self.euid = euid
        self.lock = threading.Lock()
        self.connected = ''

    def available(self):
        return bool(self.which('adb')) or self.euid() == 0

    def serial(self):
        ip = str(self.address() or '').strip()
        return f'{ip}:{PORT}' if IP_RE.fullmatch(ip) else ''

    def connect(self, serial):
        """Connect ADB to the container once. The container accepts the host key without a prompt."""
        with self.lock:
            if self.connected == serial:
                return True
            try:
                res = self.run(['adb', 'connect', serial], capture_output=True, text=True, timeout=6)
            except (OSError, subprocess.SubprocessError):
                return False
            out = (res.stdout or '').lower()
            if res.returncode == 0 and ('connected to' in out or 'already connected' in out):
                self.connected = serial
                return True
            return False

    def shell(self, args, timeout=6):
        """Run args in the Android shell. Return the completed process, or None when no channel is available."""
        args = [str(a) for a in args]
        if self.which('adb'):
            serial = self.serial()
            if serial and self.connect(serial):
                try:
                    res = self.run(['adb', '-s', serial, 'shell', *args], capture_output=True, text=True, timeout=timeout)
                except (OSError, subprocess.SubprocessError):
                    return None
                # A restarted container drops the connection. Connect again once.
                if res.returncode != 0 and 'not found' in (res.stderr or '') + (res.stdout or ''):
                    self.connected = ''
                    if not self.connect(serial):
                        return None
                    try:
                        res = self.run(['adb', '-s', serial, 'shell', *args], capture_output=True, text=True, timeout=timeout)
                    except (OSError, subprocess.SubprocessError):
                        return None
                return res
        if self.euid() == 0 and self.which('waydroid'):
            try:
                return self.run(['waydroid', 'shell', '--', *args], capture_output=True, text=True, timeout=timeout)
            except (OSError, subprocess.SubprocessError):
                return None
        return None

    def ok(self, args, timeout=6):
        res = self.shell(args, timeout)
        return res is not None and res.returncode == 0

    def versions(self):
        """Version codes of the apps the user installed (not system apps)."""
        res = self.shell(['pm', 'list', 'packages', '--show-versioncode', '-3'], timeout=12)
        return parse_versions(res.stdout) if res is not None and res.returncode == 0 else {}
