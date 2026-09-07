#!/usr/bin/env python3
"""Opal's optional Linux adapters. JSON-lines only; no shell-evaluated user input."""
import sys, os, json, subprocess, threading, time, pathlib, shutil, glob, select, struct, math, ast, operator
from wallpaper_service import DEFAULTS as WALLPAPER_DEFAULTS, local_image, generate, valid_preference, image_library
HOME = pathlib.Path.home()
STORE = HOME / '.local/state/opal/preferences.json'
lock = threading.Lock()
prefs_lock = threading.Lock()
def emit(data):
    with lock:
        print(json.dumps(data), flush=True)
def run(*args, timeout=1.4):
    if not shutil.which(args[0]): return ''
    try: return subprocess.check_output(args, stderr=subprocess.DEVNULL, timeout=timeout).decode().strip()
    except (OSError, subprocess.SubprocessError): return ''
def spawn(args):
    try: subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError: emit({'event':'message', 'text':f'{args[0]} is not installed'})
def load():
    base = {'mode':'auto', 'palette':0, 'light':False, 'dnd':False, 'glass':0.78, 'favorites':[], 'recent':[], 'wallpaper':0, 'pinsConfigured':False, 'taskbarAutoHide':False, 'taskbarLabels':True, 'phoneButtons':False, 'controllerLayout':'standard'}
    base['displayModes'] = {}
    base['phoneDisplay'] = ''
    base['taskbarOrder'] = []
    base['reduceMotion'] = False
    base.update(WALLPAPER_DEFAULTS)
    try: base.update(json.loads(STORE.read_text()))
    except (OSError, ValueError): pass
    return base
prefs = load()
def save():
    STORE.parent.mkdir(parents=True, exist_ok=True)
    temp = STORE.with_suffix('.tmp')
    temp.write_text(json.dumps(prefs, indent=2))
    temp.replace(STORE)
    emit({'event':'preferences', 'data':prefs.copy()})

def settings(which):
    choices = {
        'network': [['nm-connection-editor'], ['systemsettings','kcm_networkmanagement'], ['kitty','-e','nmtui']],
        'bluetooth': [['blueman-manager'], ['systemsettings','kcm_bluetooth']],
        'audio': [['pavucontrol'], ['systemsettings','kcm_pulseaudio']],
        'display': [['systemsettings','kcm_kscreen']],
        'files': [['xdg-open',str(HOME)]],
        'terminal': [['kitty'], ['foot'], ['alacritty']],
        'browser': [['xdg-open','https://www.google.com']],
        'steam': [['steam','-gamepadui']],
        'lock': [['hyprlock'], ['loginctl','lock-session']],
    }
    for cmd in choices.get(which, []):
        if shutil.which(cmd[0]): spawn(cmd); return
    emit({'event':'message','text':'No compatible application installed'})

def calculate(expr):
    # Deliberately tiny calculator, never Python eval or shell execution.
    ops = {ast.Add:operator.add, ast.Sub:operator.sub, ast.Mult:operator.mul, ast.Div:operator.truediv, ast.Mod:operator.mod, ast.Pow:operator.pow}
    def visit(n):
        if isinstance(n,ast.Constant) and type(n.value) in (int,float): return n.value
        if isinstance(n,ast.UnaryOp) and isinstance(n.op,(ast.UAdd,ast.USub)): return visit(n.operand) * (-1 if isinstance(n.op,ast.USub) else 1)
        if isinstance(n,ast.BinOp) and type(n.op) in ops:
            a,b=visit(n.left),visit(n.right)
            if abs(a)>1e15 or abs(b)>1e15 or isinstance(n.op,ast.Pow) and abs(b)>12: raise ValueError()
            return ops[type(n.op)](a,b)
        raise ValueError()
    try:
        if len(expr)>100: raise ValueError()
        value=visit(ast.parse(expr,mode='eval').body)
        if isinstance(value,complex) or not math.isfinite(value) or abs(value)>1e18: raise ValueError()
        return format(value,'.12g')
    except Exception: return ''

from clipboard_service import ClipboardHistory
clipboard = ClipboardHistory(emit)
from connectivity import Connectivity
connectivity = Connectivity(emit)
from hypr_actions import HyprActions
hypr_actions = HyprActions()


def publish_wallpapers(c):
    try:
        items=image_library(c.get('folder',''), prefs.get('wallpaperPath',''))
        emit({'event':'wallpapers','request':c.get('request'), 'items':items, 'error':''})
    except (ValueError, OSError) as error:
        emit({'event':'wallpapers','request':c.get('request'), 'items':[], 'error':str(error)})


def commands():
    for line in sys.stdin:
        try:
            c=json.loads(line); action=c.get('action')
            if action=='preference':
                key=c.get('key'); value=c.get('value')
                valid = key=='controllerLayout' and value in ('standard','nintendo') or key=='mode' and value in ('auto','desktop','phone','console') or key in ('palette','wallpaper') and type(value)==int and 0<=value<=3 or key in ('light','dnd','taskbarAutoHide','taskbarLabels','phoneButtons','reduceMotion') and type(value)==bool or key=='glass' and type(value) in (int,float) and .45<=value<=1
                valid = valid or valid_preference(key, value)
                valid = valid or key=='taskbarOrder' and isinstance(value,list) and len(value)<=128 and all(isinstance(v,str) and 0<len(v)<300 for v in value) and len(set(value))==len(value)
                valid = valid or key=='phoneDisplay' and isinstance(value,str) and 0<len(value)<=128 and all(ch.isalnum() or ch in '_.:-' for ch in value)
                valid = valid or key=='displayModes' and isinstance(value,dict) and len(value)<=32 and all(isinstance(k,str) and 0<len(k)<=200 and v in ('desktop','phone') for k,v in value.items())
                if valid:
                    with prefs_lock: prefs[key]=value; save()
            elif action=='display-layouts':
                from display_layouts import publish
                runtime=os.environ.get('XDG_RUNTIME_DIR')
                if runtime and publish(runtime,c.get('mode'),c.get('displays')) and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') and shutil.which('hyprctl'):
                    subprocess.run(['hyprctl','reload','config-only'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
            elif action=='wallpaper-list':
                threading.Thread(target=publish_wallpapers,args=(c,),daemon=True).start()
            elif action=='wallpaper':
                try:
                    path = local_image(c.get('path')) if c.get('path') else None
                    extra={}
                    for key in ('wallpaperFit','wallpaperDim','wallpaper'):
                        if key not in c: continue
                        value=c[key]
                        if not (type(value) is int and 0<=value<=3 if key=='wallpaper' else valid_preference(key,value)):
                            raise ValueError('Invalid wallpaper preview settings.')
                        extra[key]=value
                    with prefs_lock:
                        prefs.update(extra)
                        prefs['wallpaperPath'] = path.as_uri() if path else ''
                        save()
                    emit({'event':'message','text':'Wallpaper updated' if path else 'Built-in wallpaper restored'})
                except (ValueError, OSError) as error:
                    emit({'event':'message','text':str(error)})
            elif action=='matugen':
                emit({'event':'themeBusy','busy':True})
                try:
                    path = local_image(prefs.get('wallpaperPath'))
                    palette = generate(path, prefs.get('colorScheme','scheme-tonal-spot'))
                    with prefs_lock:
                        prefs['dynamicPalette'] = palette
                        prefs['dynamicColors'] = True
                        save()
                    emit({'event':'message','text':'Wallpaper colors applied · light and dark palettes ready'})
                except Exception as error:
                    emit({'event':'message','text':str(error) if isinstance(error, ValueError) else 'Matugen could not read this image or generate colors. Previous colors kept.'})
                finally:
                    emit({'event':'themeBusy','busy':False})
            elif action in ('pin','recent'):
                app=c.get('id','')
                if isinstance(app,str) and 0<len(app)<300:
                    with prefs_lock:
                        key='favorites' if action=='pin' else 'recent'
                        items=list(prefs[key])
                        if action=='pin' and not prefs.get('pinsConfigured'):
                            defaults=c.get('initial',[])
                            if isinstance(defaults,list): items=[i for i in defaults[:24] if isinstance(i,str) and len(i)<300]
                            prefs['pinsConfigured']=True
                        if app in items: items.remove(app)
                        elif action=='pin': items.append(app)
                        if action=='recent': items.insert(0,app)
                        prefs[key]=items[:24]; save()
            elif action in ('focus-window','workspace'):
                try:
                    if action=='focus-window':hypr_actions.focus(c.get('address'))
                    else:hypr_actions.workspace(c.get('number'))
                except (ValueError,OSError,subprocess.SubprocessError) as error:
                    emit({'event':'message','text':str(error)})
            elif action=='connectivity': connectivity.request(c)
            elif action=='settings': settings(c.get('which'))
            elif action=='volume': run('wpctl','set-volume','-l','1','@DEFAULT_AUDIO_SINK@',str(max(0,min(100,int(c['value']))))+'%')
            elif action=='mute': run('wpctl','set-mute','@DEFAULT_AUDIO_SINK@','toggle')
            elif action=='mic': run('wpctl','set-mute','@DEFAULT_AUDIO_SOURCE@','toggle')
            elif action=='brightness': run('brightnessctl','set',str(max(1,min(100,int(c['value']))))+'%')
            elif action=='wifi': run('nmcli','radio','wifi','off' if c.get('enabled') else 'on')
            elif action=='bluetooth': run('bluetoothctl','power','off' if c.get('enabled') else 'on')
            elif action=='media' and c.get('verb') in ('play-pause','next','previous'): run('playerctl',c['verb'])
            elif action=='profile' and c.get('value') in ('power-saver','balanced','performance'): run('powerprofilesctl','set',c['value'])
            elif action=='screenshot':
                time.sleep(.5)
                folder=HOME/'Pictures/Screenshots'; folder.mkdir(parents=True,exist_ok=True)
                dest=str(folder/time.strftime('Opal-%Y%m%d-%H%M%S.png'))
                if shutil.which('grim'):
                    try:
                        subprocess.run(['grim',dest],check=True,timeout=5)
                        emit({'event':'message','text':'Screenshot saved to Pictures/Screenshots'})
                    except Exception: emit({'event':'message','text':'Screenshot failed'})
            elif action=='power' and c.get('verb') in ('suspend','reboot','poweroff'): spawn(['systemctl',c['verb']])
            elif action=='power' and c.get('verb')=='logout':
                if shutil.which('hyprctl'): spawn(['hyprctl','dispatch','exit'])
                else:
                    sid=os.environ.get('XDG_SESSION_ID','')
                    spawn(['loginctl','terminate-session',sid] if sid else ['loginctl','terminate-user',os.environ.get('USER','')])
            elif action=='calculate': emit({'event':'calculation','query':c.get('text',''),'result':calculate(c.get('text',''))})
            elif action=='clipboard':
                if shutil.which('wl-copy'): subprocess.run(['wl-copy'],input=str(c.get('text','')).encode('utf-8'),timeout=2)
            elif action=='clipboard-list': clipboard.publish()
            elif action=='clipboard-copy': clipboard.copy(c.get('id',''))
            elif action=='clipboard-delete': clipboard.delete(c.get('id',''))
            elif action=='clipboard-clear': clipboard.clear()
            elif action=='clipboard-pause' and type(c.get('paused')) is bool: clipboard.set_paused(c['paused'])
            elif action=='web': spawn(['xdg-open','https://www.google.com/search?q='+__import__('urllib.parse',fromlist=['quote']).quote(str(c.get('text','')))])
        except Exception as e: emit({'event':'message','text':'That action could not be completed'})

last_cpu=None

def status():
    global last_cpu
    # Compositor fields arrive independently from hypr_events, never from this poll.
    s={'volume':0,'muted':False,'network':'Offline','wifi':False,'bluetooth':False,'track':'','artist':'','art':'','playing':False,'battery':-1,'charging':False,'brightness':-1,'cpu':0,'memory':0,'profile':'','uptime':''}
    v=run('wpctl','get-volume','@DEFAULT_AUDIO_SINK@')
    try: s['volume']=round(float(v.split()[1])*100)
    except (ValueError,IndexError): pass
    s['muted']='MUTED' in v
    s['micMuted']='MUTED' in run('wpctl','get-volume','@DEFAULT_AUDIO_SOURCE@')
    n=run('nmcli','-t','-f','NAME,TYPE','connection','show','--active')
    s['network']=next((l.rsplit(':',1)[0] for l in n.splitlines() if not l.endswith(':loopback')),'Offline')
    s['wifi']=run('nmcli','radio','wifi')=='enabled'
    s['bluetooth']='Powered: yes' in run('bluetoothctl','show')
    meta=run('playerctl','metadata','--format','{{title}}\n{{artist}}\n{{mpris:artUrl}}\n{{status}}').splitlines()
    if meta:
        for i,k in enumerate(('track','artist','art')):
            if len(meta)>i: s[k]=meta[i]
        s['playing']=len(meta)>3 and meta[3]=='Playing'
    for b in glob.glob('/sys/class/power_supply/BAT*/capacity'):
        try:
            s['battery']=int(pathlib.Path(b).read_text()); s['charging']=pathlib.Path(b).with_name('status').read_text().strip()=='Charging'
        except (OSError,ValueError): pass
    for b in glob.glob('/sys/class/backlight/*'):
        try: s['brightness']=round(int(pathlib.Path(b,'brightness').read_text())/int(pathlib.Path(b,'max_brightness').read_text())*100)
        except (OSError,ValueError,ZeroDivisionError): pass
    try:
        cpu=list(map(int,pathlib.Path('/proc/stat').read_text().splitlines()[0].split()[1:8])); total=sum(cpu); idle=cpu[3]+cpu[4]
        if last_cpu and total>last_cpu[0]: s['cpu']=round(100*(1-(idle-last_cpu[1])/(total-last_cpu[0])))
        last_cpu=(total,idle)
        mem={l.split(':')[0]:int(l.split()[1]) for l in pathlib.Path('/proc/meminfo').read_text().splitlines()}
        s['memory']=round(100*(1-mem['MemAvailable']/mem['MemTotal']))
        hrs=int(float(pathlib.Path('/proc/uptime').read_text().split()[0]))//3600
        s['uptime']=str(hrs)+'h'
    except (OSError,ValueError,KeyError): pass
    s['profile']=run('powerprofilesctl','get')
    return s

def library_art():
    """Index Steam's existing local artwork; never download library assets."""
    result={}
    bases=[HOME/'.local/share/Steam/appcache/librarycache', HOME/'.steam/steam/appcache/librarycache']
    seen=set()
    for base in bases:
        try:
            resolved=base.resolve()
            if resolved in seen or not base.is_dir(): continue
            seen.add(resolved)
            for pattern in ('*/*','*/*/*','*'):
                for path in base.glob(pattern):
                    if not path.is_file(): continue
                    relative=path.relative_to(base)
                    appid=relative.parts[0] if len(relative.parts)>1 else path.name.split('_',1)[0]
                    if not appid.isdigit(): continue
                    name=path.stem.lower()
                    kind='cover' if '600x900' in name or 'library_capsule' in name else 'hero' if 'library_hero' in name and 'blur' not in name else 'header' if 'library_header' in name else None
                    if kind: result.setdefault(appid,{})[kind]=path.resolve().as_uri()
        except OSError: continue
    return result

def controllers():
    # Linux joystick API, read-only. Never grabs devices or injects global input.
    while True:
        paths=glob.glob('/dev/input/js*')
        f=None
        name=''
        for p in paths:
            candidate=None
            try:
                import fcntl
                candidate=open(p,'rb',buffering=0)
                buf=bytearray(128)
                fcntl.ioctl(candidate.fileno(), 0x80000000 | (128<<16) | (ord('j')<<8) | 0x13, buf)
                candidate_name=bytes(buf).split(b'\0',1)[0].decode(errors='replace')
                buttons=bytearray(1)
                fcntl.ioctl(candidate.fileno(), 0x80016a12, buttons)
                # Absolute pointer devices can expose js nodes too; they are not gamepads.
                if buttons[0]<6 or any(word in candidate_name.lower() for word in ('pointer','mouse','keyboard')):
                    candidate.close(); continue
                f=candidate; name=candidate_name; break
            except OSError:
                if candidate: candidate.close()
        emit({'event':'controller','connected':f is not None,'name':name})
        if f is None: time.sleep(5); continue
        try:
            previous={}
            held={}
            while True:
                now=time.monotonic()
                wait=max(0,min((due-now for _,due in held.values()),default=2))
                if not select.select([f],[],[],wait)[0]:
                    now=time.monotonic()
                    for axis,(key,due) in list(held.items()):
                        if now>=due:
                            emit({'event':'navigation','key':key})
                            held[axis]=(key,now+.13)
                    continue
                data=f.read(8)
                if len(data)!=8: break
                _,value,kind,number=struct.unpack('IhBB',data)
                if kind & 0x80: continue
                nav=None
                if kind==1 and value==1:
                    mapping={0:'accept',1:'back',2:'pin',3:'search',4:'previousTab',5:'nextTab',6:'menu',7:'home'}
                    if prefs.get('controllerLayout')=='nintendo': mapping.update({0:'back',1:'accept',2:'search',3:'pin'})
                    nav=mapping.get(number)
                if kind==2 and number in (0,1,6,7):
                    direction=0 if abs(value)<16000 else (1 if value>0 else -1)
                    if direction and previous.get(number)!=direction:
                        nav=('right' if direction>0 else 'left') if number in (0,6) else ('down' if direction>0 else 'up')
                        held[number]=(nav,time.monotonic()+.38)
                    elif not direction: held.pop(number,None)
                    previous[number]=direction
                if nav: emit({'event':'navigation','key':nav})
        except OSError: pass
        finally: f.close()
        time.sleep(2)

def main():
    import atexit, signal
    atexit.register(clipboard.stop)
    def shutdown(signum, frame):
        clipboard.stop()
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    threading.Thread(target=clipboard.watch,daemon=True).start()
    emit({'event':'preferences','data':prefs})
    threading.Thread(target=commands,daemon=True).start()
    threading.Thread(target=controllers,daemon=True).start()
    threading.Thread(target=lambda:emit({'event':'libraryArt','data':library_art()}),daemon=True).start()
    from hypr_events import listen as listen_hyprland
    threading.Thread(target=listen_hyprland, args=(emit,), daemon=True).start()
    while True:
        try: emit({'event':'status','data':status()})
        except Exception: pass
        time.sleep(2)

if __name__ == '__main__':
    main()
