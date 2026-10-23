"""Android app store for Opal: F-Droid catalogue search, verified APK download and install into Waydroid, installed app list."""
import hashlib, json, os, pathlib, platform, re, subprocess, threading, time, urllib.request, zipfile

REPO = 'https://f-droid.org/repo'
INDEX_URL = REPO + '/index-v1.jar'
MAX_AGE = 24 * 3600
CATALOG_VERSION = 3
PACKAGE_RE = re.compile(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$')
# Shown first on an empty search. Aurora Store reaches Play Store apps without Google services.
FEATURED = ['com.aurora.store', 'org.fdroid.fdroid', 'org.mozilla.fennec_fdroid', 'org.schabi.newpipe', 'app.organicmaps', 'org.videolan.vlc',
            'im.vector.app', 'org.thoughtcrime.securesms', 'org.telegram.messenger', 'de.danoeh.antennapod', 'com.termux', 'org.kde.kdeconnect_tp',
            'com.github.libretube', 'org.joinmastodon.android', 'net.osmand.plus', 'com.nextcloud.client', 'org.localsend.localsend_app', 'com.simplemobiletools.gallery.pro']
ABI = {'x86_64': 'x86_64', 'amd64': 'x86_64', 'aarch64': 'arm64-v8a', 'arm64': 'arm64-v8a', 'armv7l': 'armeabi-v7a', 'i686': 'x86'}
ARM_ABIS = ('arm64-v8a', 'armeabi-v7a', 'armeabi')


def text_of(app, key, lang='en-US'):
    loc = app.get('localized') or {}
    for code in (lang, 'en-US', 'en', 'en-GB'):
        value = (loc.get(code) or {}).get(key)
        if value:
            return value
    if app.get(key):
        return app[key]
    for value in loc.values():
        if value.get(key):
            return value[key]
    return ''


def pick_apk(packages, suggested, abis):
    """Newest APK whose native code fits one of abis (pure Java APKs fit everything), preferring the suggested version or older."""
    fits = [p for p in packages if not p.get('nativecode') or any(a in abis for a in p['nativecode'])]
    if not fits:
        return None
    try:
        limit = int(suggested)
    except (TypeError, ValueError):
        limit = 0
    stable = [p for p in fits if not limit or int(p.get('versionCode') or 0) <= limit]
    return max(stable or fits, key=lambda p: int(p.get('versionCode') or 0))


def build_catalog(index, abis):
    """Compact catalogue from index-v1.json: one entry per app with a compatible APK."""
    out = []
    packages = index.get('packages') or {}
    for app in index.get('apps') or []:
        pkg = app.get('packageName', '')
        if not PACKAGE_RE.fullmatch(pkg):
            continue
        apk = pick_apk(packages.get(pkg) or [], app.get('suggestedVersionCode'), abis)
        if not apk or apk.get('hashType', 'sha256') != 'sha256':
            continue
        icon = app.get('icon') or ''
        out.append({
            'package': pkg,
            'name': str(text_of(app, 'name') or pkg)[:80],
            'summary': str(text_of(app, 'summary') or '')[:160],
            'icon': f'{REPO}/icons-640/{icon}' if icon else '',
            'categories': [str(c) for c in (app.get('categories') or [])][:6],
            'updated': int(app.get('lastUpdated') or 0),
            'license': str(app.get('license') or ''),
            'web': str(app.get('webSite') or app.get('sourceCode') or ''),
            'version': str(apk.get('versionName') or ''),
            'versionCode': int(apk.get('versionCode') or 0),
            'apk': str(apk.get('apkName') or ''),
            'hash': str(apk.get('hash') or ''),
            'size': int(apk.get('size') or 0),
            'arm': bool(apk.get('nativecode')) and not any(a in abis[:1] for a in apk['nativecode']),
        })
    return out


def score(entry, words):
    name, summary, pkg = entry['name'].lower(), entry['summary'].lower(), entry['package'].lower()
    total = 0
    for w in words:
        if name == w:
            total += 120
        elif name.startswith(w):
            total += 70
        elif w in name:
            total += 45
        elif w in pkg:
            total += 20
        elif w in summary:
            total += 12
        elif any(w in c.lower() for c in entry['categories']):
            total += 8
        else:
            return 0
    return total


def parse_app_list(text):
    """Package names from 'waydroid app list' output."""
    found = []
    for line in str(text or '').splitlines():
        m = re.match(r'\s*packageName:\s*(\S+)', line)
        if m and PACKAGE_RE.fullmatch(m.group(1)):
            found.append(m.group(1))
    return found


class Store:
    def __init__(self, emit, bridge, cache=None, fetch=urllib.request.urlopen, run=subprocess.run):
        self.emit = emit
        self.bridge = bridge
        self.cache = pathlib.Path(cache or pathlib.Path.home() / '.cache/opal/android-store')
        self.fetch = fetch
        self.run = run
        self.catalog = []
        self.by_package = {}
        self.installed = set()
        self.lock = threading.Lock()
        self.loading = False
        self.jobs = {}
        # Installed version codes, read over ADB. Empty when Android is stopped or adb is missing.
        self.versions = {}

    def abis(self):
        native = ABI.get(platform.machine(), 'x86_64')
        abis = [native]
        if native == 'x86_64':
            abis.append('x86')
            if self.arm_bridge():
                abis += list(ARM_ABIS)
        return abis

    def arm_bridge(self):
        for path in ('/var/lib/waydroid/waydroid_base.prop', '/var/lib/waydroid/waydroid.prop'):
            try:
                text = pathlib.Path(path).read_text()
            except OSError:
                continue
            m = re.search(r'ro\.dalvik\.vm\.native\.bridge=(\S+)', text)
            if m and m.group(1) not in ('0', ''):
                return True
        return False

    # ---------- catalogue ----------
    def catalog_path(self):
        return self.cache / 'catalog.json'

    def load(self, force=False):
        with self.lock:
            if self.loading:
                return
            self.loading = True
        try:
            self.emit({'event': 'androidStore', 'op': 'loading', 'loading': True})
            abis = self.abis()
            path = self.catalog_path()
            fresh = False
            try:
                data = json.loads(path.read_text())
                fresh = data.get('version') == CATALOG_VERSION and data.get('abis') == abis and time.time() - data.get('time', 0) < MAX_AGE
                if data.get('version') == CATALOG_VERSION and data.get('abis') == abis:
                    self.set_catalog(data.get('apps') or [])
            except (OSError, ValueError):
                pass
            # Offscreen tests never fetch the catalogue.
            if os.environ.get('OPAL_TEST_OUTPUT') and not self.catalog:
                raise ValueError('offline test run')
            if force or not fresh or not self.catalog:
                self.download_index(abis)
            self.refresh_installed()
            self.emit({'event': 'androidStore', 'op': 'ready', 'loading': False, 'count': len(self.catalog), 'categories': self.categories(),
                       'installed': sorted(self.installed)})
        except (OSError, ValueError, zipfile.BadZipFile) as error:
            self.emit({'event': 'androidStore', 'op': 'error', 'loading': False, 'error': f'Could not load the app catalogue: {error}'})
        finally:
            self.loading = False

    def download_index(self, abis):
        self.cache.mkdir(parents=True, exist_ok=True)
        jar = self.cache / 'index-v1.jar'
        tmp = self.cache / 'index-v1.jar.part'
        req = urllib.request.Request(INDEX_URL, headers={'User-Agent': 'Opal/1.0'})
        with self.fetch(req, timeout=30) as res, open(tmp, 'wb') as out:
            total = int(res.headers.get('Content-Length') or 0)
            done, last = 0, 0.0
            while True:
                chunk = res.read(256 * 1024)
                if not chunk:
                    break
                out.write(chunk)
                done += len(chunk)
                if total and time.monotonic() - last > .3:
                    last = time.monotonic()
                    self.emit({'event': 'androidStore', 'op': 'loading', 'loading': True, 'progress': done / total})
        os.replace(tmp, jar)
        with zipfile.ZipFile(jar) as z:
            index = json.loads(z.read('index-v1.json'))
        apps = build_catalog(index, abis)
        self.set_catalog(apps)
        tmp_cat = self.catalog_path().with_suffix('.part')
        tmp_cat.write_text(json.dumps({'version': CATALOG_VERSION, 'time': time.time(), 'abis': abis, 'apps': apps}))
        os.replace(tmp_cat, self.catalog_path())

    def set_catalog(self, apps):
        self.catalog = apps
        self.by_package = {a['package']: a for a in apps}

    def categories(self):
        counts = {}
        for a in self.catalog:
            for c in a['categories']:
                counts[c] = counts.get(c, 0) + 1
        return [{'name': k, 'count': v} for k, v in sorted(counts.items(), key=lambda kv: -kv[1])[:24]]

    def entry(self, a):
        return dict(a, installed=a['package'] in self.installed, job=self.jobs.get(a['package']))

    def search(self, query='', category='', limit=60):
        words = [w for w in str(query or '').lower().split() if w][:6]
        pool = [a for a in self.catalog if not category or category in a['categories']]
        if category == 'Installed':
            pool = [a for a in self.catalog if a['package'] in self.installed]
        if words:
            ranked = sorted(((score(a, words), a) for a in pool), key=lambda t: (-t[0], t[1]['name'].lower()))
            items = [a for s, a in ranked if s > 0][:limit]
        elif category:
            items = sorted(pool, key=lambda a: -a['updated'])[:limit]
        else:
            featured = [self.by_package[p] for p in FEATURED if p in self.by_package]
            recent = [a for a in sorted(self.catalog, key=lambda a: -a['updated']) if a['package'] not in FEATURED][:max(0, limit - len(featured))]
            items = featured + recent
        return [self.entry(a) for a in items]

    def publish_search(self, query, category, request=0):
        self.emit({'event': 'androidStore', 'op': 'results', 'query': query, 'category': category, 'request': request,
                   'items': self.search(query, category)})

    def detail(self, pkg):
        """Long description and screenshots from the cached index for one app."""
        a = self.by_package.get(pkg)
        if not a:
            return
        description, shots = '', []
        try:
            with zipfile.ZipFile(self.cache / 'index-v1.jar') as z:
                index = json.loads(z.read('index-v1.json'))
            app = next((x for x in index.get('apps') or [] if x.get('packageName') == pkg), {})
            description = re.sub(r'<[^>]+>', '', str(text_of(app, 'description') or ''))[:4000]
            loc = (app.get('localized') or {})
            lang = next((c for c in ('en-US', 'en', 'en-GB') if c in loc), next(iter(loc), ''))
            shots = [f'{REPO}/{pkg}/{lang}/phoneScreenshots/{s}' for s in (loc.get(lang, {}).get('phoneScreenshots') or [])][:8]
        except (OSError, ValueError, zipfile.BadZipFile, KeyError):
            pass
        self.emit({'event': 'androidStore', 'op': 'detail', 'item': dict(self.entry(a), description=description, screenshots=shots)})

    # ---------- installed ----------
    def refresh_installed(self):
        if not self.bridge.installed() or self.bridge.status().get('session') != 'running':
            # Without a session the launcher entries tell which apps exist.
            from waydroid_bridge import discover_android_apps
            self.installed = {a['package'] for a in discover_android_apps()}
            return
        try:
            res = self.run(['waydroid', 'app', 'list'], capture_output=True, text=True, timeout=10)
            self.installed = set(parse_app_list(res.stdout))
        except (OSError, subprocess.SubprocessError):
            pass

    # ---------- updates ----------
    def updates(self):
        """Catalogue apps whose installed version is older than the catalogue's."""
        out = []
        for pkg, code in sorted(self.versions.items()):
            a = self.by_package.get(pkg)
            if a and a.get('versionCode', 0) > code:
                out.append(dict(self.entry(a), installedCode=code))
        return out

    def check_updates(self):
        if not self.catalog:
            self.load()
        if self.bridge.installed() and self.bridge.status().get('session') == 'running':
            self.versions = self.bridge.adb.versions()
        items = self.updates()
        self.emit({'event': 'androidStore', 'op': 'updates', 'items': items, 'checked': bool(self.versions) or not items})
        return items

    def update_all(self, light=False):
        items = self.check_updates()
        done = 0
        for a in items:
            if self.install(a['package'], light):
                done += 1
                self.versions[a['package']] = a.get('versionCode', 0)
        if items:
            self.emit({'event': 'message', 'text': f'Updated {done} of {len(items)} Android apps'})
        self.emit({'event': 'androidStore', 'op': 'updates', 'items': self.updates(), 'checked': True})

    # ---------- install ----------
    def job(self, pkg, **fields):
        self.jobs[pkg] = dict(self.jobs.get(pkg) or {}, **fields)
        self.emit({'event': 'androidStore', 'op': 'job', 'package': pkg, 'job': self.jobs[pkg]})

    def install(self, pkg, light=False):
        a = self.by_package.get(pkg)
        if not a or not a['apk'] or not re.fullmatch(r'[0-9a-f]{64}', a['hash']):
            self.emit({'event': 'message', 'text': 'That app is not in the catalogue'})
            return False
        if (self.jobs.get(pkg) or {}).get('state') in ('download', 'install'):
            return False
        if not self.bridge.installed():
            self.emit({'event': 'message', 'text': 'Set up Android apps first'})
            return False
        self.job(pkg, state='download', progress=0)
        self.bridge.activity_start(f'store-{pkg}', a['name'], 'Downloading', kind='transfer', icon='download', progress=0)
        target = self.cache / 'apk' / a['apk']
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            if not (target.exists() and self.sha256(target) == a['hash']):
                self.download(f"{REPO}/{a['apk']}", target, a['size'], pkg, a['name'])
                if self.sha256(target) != a['hash']:
                    target.unlink(missing_ok=True)
                    raise ValueError('the download did not match the catalogue checksum')
        except (OSError, ValueError) as error:
            self.job(pkg, state='failed', error=str(error))
            self.bridge.activity_end(f'store-{pkg}')
            self.emit({'event': 'message', 'text': f"Could not download {a['name']}: {error}"})
            return False
        self.job(pkg, state='install', progress=-1)
        self.bridge.activity_start(f'store-{pkg}', a['name'], 'Installing', kind='transfer', icon='install_mobile', progress=-2)
        ok = self.bridge.ensure_session(label=a['name'], light=light)
        if ok:
            try:
                res = self.run(['waydroid', 'app', 'install', str(target)], capture_output=True, text=True, timeout=180)
                ok = res.returncode == 0
            except (OSError, subprocess.SubprocessError):
                ok = False
        if ok:
            self.installed.add(pkg)
            self.job(pkg, state='done', progress=1)
            self.bridge.activity_start(f'store-{pkg}', a['name'], 'Installed', kind='transfer', icon='check_circle', progress=1, ttl=5)
            self.bridge.publish_status()
            # The APK stays only until the next install of the same app.
            target.unlink(missing_ok=True)
        else:
            self.job(pkg, state='failed', error='Android refused the app')
            self.bridge.activity_end(f'store-{pkg}')
            self.emit({'event': 'message', 'text': f"Could not install {a['name']}"})
        return ok

    def download(self, url, target, size, pkg, name):
        tmp = target.with_suffix('.part')
        req = urllib.request.Request(url, headers={'User-Agent': 'Opal/1.0'})
        with self.fetch(req, timeout=30) as res, open(tmp, 'wb') as out:
            total = int(res.headers.get('Content-Length') or size or 0)
            done, last = 0, 0.0
            while True:
                chunk = res.read(256 * 1024)
                if not chunk:
                    break
                out.write(chunk)
                done += len(chunk)
                if total and time.monotonic() - last > .25:
                    last = time.monotonic()
                    self.job(pkg, state='download', progress=done / total)
                    self.bridge.activity_start(f'store-{pkg}', name, 'Downloading', kind='transfer', icon='download', progress=done / total)
        os.replace(tmp, target)

    @staticmethod
    def sha256(path):
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b''):
                h.update(chunk)
        return h.hexdigest()

    def uninstall(self, pkg):
        if self.bridge.uninstall_app(pkg):
            self.installed.discard(pkg)
            self.jobs.pop(pkg, None)
            self.emit({'event': 'androidStore', 'op': 'job', 'package': pkg, 'job': None})
            self.emit({'event': 'androidStore', 'op': 'installed', 'installed': sorted(self.installed)})

    def handle(self, c, prefs):
        action = c.get('action')
        pkg = c.get('package') if isinstance(c.get('package'), str) and PACKAGE_RE.fullmatch(c.get('package')) else ''
        if action == 'android-store-load':
            self.load(force=c.get('force') is True)
        elif action == 'android-store-search':
            if not self.catalog:
                self.load()
            self.publish_search(str(c.get('query') or '')[:80], str(c.get('category') or '')[:40], int(c.get('request') or 0))
        elif action == 'android-store-detail' and pkg:
            self.detail(pkg)
        elif action == 'android-store-install' and pkg:
            self.install(pkg, bool(prefs.get('light')))
            self.emit({'event': 'androidStore', 'op': 'installed', 'installed': sorted(self.installed)})
        elif action == 'android-store-uninstall' and pkg:
            self.uninstall(pkg)
        elif action == 'android-store-updates':
            self.check_updates()
        elif action == 'android-store-update-all':
            self.update_all(bool(prefs.get('light')))
        elif action == 'android-store-installed':
            self.refresh_installed()
            self.emit({'event': 'androidStore', 'op': 'installed', 'installed': sorted(self.installed)})
        else:
            return False
        return True
