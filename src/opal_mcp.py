#!/usr/bin/env python3
"""Opal MCP server: lets Claude read and change the running Opal shell over Quickshell IPC. stdio, JSON-RPC 2.0."""
import json, os, pathlib, subprocess, sys

CONFIG = os.environ.get('OPAL_CONFIG_DIR') or str(pathlib.Path(__file__).resolve().parent)
PANELS = ('launcher', 'controls', 'notifications', 'clipboard', 'appearance', 'settings', 'convergence', 'audio', 'close')
LAYOUTS = {'phone': 'phone', 'desktop': 'desktop', 'console': 'gaming', 'auto': 'adaptive'}

def ipc(function, *args):
    result = subprocess.run(['quickshell', 'ipc', '-p', CONFIG, 'call', 'opal', function, *map(str, args)], capture_output=True, text=True, timeout=10)
    if result.returncode: raise RuntimeError((result.stderr or result.stdout).strip() or 'Opal is not running')
    return result.stdout.strip()

def schema(properties=None, required=()):
    return {'type': 'object', 'properties': properties or {}, 'required': list(required)}

TOOLS = {
    'get_status': ('Read Opal status: page, layout mode, unread count, volume, battery, network, media.', schema(), lambda a: ipc('inspect')),
    'get_preferences': ('Read Opal preferences (theme, bar style, layout, tiles, sections and more).', schema(), lambda a: ipc('preferences')),
    'set_preference': ('Change one Opal preference. Value is JSON. Examples: light=true, barStyle="dock", iconStyle="themed", dnd=true, sheetSections=["sliders","tiles"]. Invalid values are ignored.',
                       schema({'key': {'type': 'string'}, 'value': {'description': 'JSON value'}}, ('key', 'value')),
                       lambda a: ipc('setPreference', a['key'], json.dumps(a['value']))),
    'open_panel': ('Open or close an Opal panel.', schema({'panel': {'type': 'string', 'enum': list(PANELS)}}, ('panel',)), lambda a: ipc(a['panel'])),
    'set_layout': ('Switch the shell layout.', schema({'layout': {'type': 'string', 'enum': list(LAYOUTS)}}, ('layout',)), lambda a: ipc(LAYOUTS[a['layout']])),
    'list_notifications': ('List notifications in the Opal inbox.', schema(), lambda a: ipc('listNotifications')),
    'list_windows': ('List open windows.', schema(), lambda a: ipc('windows')),
    'media': ('Control the active media player.', schema({'action': {'type': 'string', 'enum': ['play-pause', 'next', 'previous']}}, ('action',)), lambda a: ipc('media', a['action'])),
    'set_volume': ('Set output volume, 0 to 100.', schema({'value': {'type': 'integer', 'minimum': 0, 'maximum': 100}}, ('value',)), lambda a: ipc('volume', int(a['value']))),
    'search': ('Open Start with a search query.', schema({'text': {'type': 'string'}}, ('text',)), lambda a: ipc('search', a['text'])),
    'show_message': ('Show a short message in the shell.', schema({'text': {'type': 'string'}}, ('text',)), lambda a: ipc('toast', a['text']) or 'Shown'),
    'lock_screen': ('Lock the session.', schema(), lambda a: ipc('lock') or 'Locked'),
}

def handle(message):
    method, ident = message.get('method'), message.get('id')
    if method == 'initialize':
        result = {'protocolVersion': message.get('params', {}).get('protocolVersion', '2025-06-18'), 'capabilities': {'tools': {}},
                  'serverInfo': {'name': 'opal', 'version': '1.0'}, 'instructions': 'Tools for the Opal desktop shell. Read status or preferences before changing things.'}
    elif method == 'tools/list':
        result = {'tools': [{'name': n, 'description': d, 'inputSchema': s} for n, (d, s, _) in TOOLS.items()]}
    elif method == 'tools/call':
        params = message.get('params', {})
        tool = TOOLS.get(params.get('name'))
        if not tool: return {'jsonrpc': '2.0', 'id': ident, 'error': {'code': -32602, 'message': 'Unknown tool'}}
        try: text, error = tool[2](params.get('arguments') or {}) or 'Done', False
        except (RuntimeError, KeyError, ValueError, OSError, subprocess.SubprocessError) as problem: text, error = str(problem), True
        result = {'content': [{'type': 'text', 'text': text}], 'isError': error}
    elif method == 'ping':
        result = {}
    elif ident is None:
        return None
    else:
        return {'jsonrpc': '2.0', 'id': ident, 'error': {'code': -32601, 'message': 'Method not found'}}
    return {'jsonrpc': '2.0', 'id': ident, 'result': result}

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line: continue
        try: reply = handle(json.loads(line))
        except ValueError: reply = {'jsonrpc': '2.0', 'id': None, 'error': {'code': -32700, 'message': 'Parse error'}}
        if reply is not None:
            sys.stdout.write(json.dumps(reply) + '\n'); sys.stdout.flush()

if __name__ == '__main__':
    main()
