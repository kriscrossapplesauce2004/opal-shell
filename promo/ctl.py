"""Drive a session that `session.py serve` keeps running. Usage: ctl.py NAME COMMAND [ARGS...]

Commands: ipc FN [ARGS] | shot NAME | move X Y | glide X Y [S] | click X Y | drag X0 Y0 X1 Y1 | combo KEY... |
          tap KEY... | type TEXT | spawn CMD... | lua CODE | clients | notify APP SUMMARY [BODY] | pref KEY JSON
"""
import json, sys
from session import Attached

s = Attached(sys.argv[1])
cmd, args = sys.argv[2], sys.argv[3:]
f = lambda v: float(v)
if cmd == 'ipc': print(s.ipc(*args))
elif cmd == 'shot': print(s.shot(args[0]))
elif cmd == 'move': s.move(f(args[0]), f(args[1]))
elif cmd == 'glide': s.glide(f(args[0]), f(args[1]), f(args[2]) if len(args) > 2 else .6)
elif cmd == 'click': s.click(f(args[0]), f(args[1]))
elif cmd == 'drag': s.drag(*map(f, args[:4]))
elif cmd == 'scroll': s.scroll(f(args[0]), int(args[1]) if len(args) > 1 else 1)
elif cmd == 'combo': s.combo(*args)
elif cmd == 'tap': s.tap(*args)
elif cmd == 'type': s.type(' '.join(args))
elif cmd == 'spawn': s.spawn(args)
elif cmd == 'lua': print(s.lua(args[0]))
elif cmd == 'clients': print(json.dumps([(c['class'], c['title'], c['at'], c['size'], c['workspace']['id'], c['floating']) for c in s.hypr_json('clients')], indent=0))
elif cmd == 'close': s.actions().close(s.window(args[0])['address'])
elif cmd == 'notify': s.notify(*args)
elif cmd == 'pref': print(s.pref(args[0], json.loads(args[1])))
else: sys.exit(__doc__)
s.save_cursor()
