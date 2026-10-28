"""External monitor brightness over DDC/CI through ddcutil. Monitors that do not answer are listed without a slider."""
import re
import shutil
import subprocess
import threading
import time

DETECT_TTL = 600


def parse_detect(text):
    """Blocks from `ddcutil detect --brief`: [{bus, connector, model, ddc}]."""
    out = []
    for block in re.split(r'\n(?=\S)', text.strip()):
        bus = re.search(r'I2C bus:\s*/dev/i2c-(\d+)', block)
        if not bus: continue
        conn = re.search(r'DRM[ _]connector:\s*card\d+-(\S+)', block)
        model = re.search(r'Monitor:\s*(.+)', block)
        name = model.group(1).strip().strip(':').split(':') if model else []
        out.append({'bus': int(bus.group(1)), 'connector': conn.group(1) if conn else '',
                    'model': ' '.join(p for p in name[1:] if p) or (name[0] if name else 'Display'),
                    'ddc': block.startswith('Display')})
    return out


def parse_vcp(text):
    """`ddcutil getvcp 10 --brief` -> (current, max) or None."""
    m = re.search(r'VCP\s+10\s+C\s+(\d+)\s+(\d+)', text)
    return (int(m.group(1)), int(m.group(2))) if m else None


class Ddc:
    def __init__(self, emit, runner=subprocess.run):
        self.emit, self.runner = emit, runner
        self.lock = threading.Lock()
        self.cache, self.at = [], 0

    def run(self, *args, timeout=20):
        try:
            return self.runner(['ddcutil', *args], capture_output=True, text=True, timeout=timeout).stdout
        except (OSError, subprocess.TimeoutExpired):
            return ''

    def request(self, c):
        threading.Thread(target=self.work, args=(c,), daemon=True).start()

    def work(self, c):
        if not shutil.which('ddcutil'):
            self.emit({'event': 'ddc', 'items': [], 'available': False}); return
        with self.lock:
            verb = c.get('verb', 'refresh')
            if verb == 'set':
                bus, value = c.get('bus'), c.get('value')
                if type(bus) is int and 0 <= bus < 256 and type(value) in (int, float) and 0 <= value <= 100:
                    self.run('setvcp', '10', str(int(value)), '--bus', str(bus), '--noverify')
                    for item in self.cache:
                        if item['bus'] == bus: item['value'] = int(value)
                self.emit({'event': 'ddc', 'items': self.cache, 'available': True}); return
            if not self.cache or time.time() - self.at > DETECT_TTL or verb == 'scan':
                self.cache = parse_detect(self.run('detect', '--brief', timeout=40)); self.at = time.time()
            for item in self.cache:
                vcp = parse_vcp(self.run('getvcp', '10', '--brief', '--bus', str(item['bus']))) if item['ddc'] else None
                item['value'], item['max'] = (vcp if vcp else (-1, 100))
            self.emit({'event': 'ddc', 'items': self.cache, 'available': True})
