#!/usr/bin/env python3
"""Opal's xdg-desktop-portal FileChooser backend.

Apps' Open and Save dialogs are drawn by the Opal shell when the shell wants them (phone and tablet layouts by default).
Otherwise each call is forwarded unchanged to the previous FileChooser backend, such as GTK or KDE.
The shell answers over a private socket in $XDG_RUNTIME_DIR; no paths reach a command line.
"""
import base64
import json
import os
import pathlib
import socket
import subprocess
import sys
import threading
import urllib.parse
import warnings

import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

BUS_NAME = 'org.freedesktop.impl.portal.desktop.opal'
OBJECT = '/org/freedesktop/portal/desktop'
STATE = pathlib.Path(os.environ.get('XDG_STATE_HOME', pathlib.Path.home()/'.local/state'))/'opal/portal.json'
CONFIG = pathlib.Path(os.environ.get('OPAL_CONFIG_DIR') or pathlib.Path(os.environ.get('XDG_CONFIG_HOME', pathlib.Path.home()/'.config'))/'quickshell/opal')
from file_browse import SOCKET

# PyGObject marks register_object deprecated; its replacement only exists in newer releases.
warnings.filterwarnings('ignore', category=DeprecationWarning)
# Seconds the shell has to show the picker before the call goes to the fallback.
SHOW_TIMEOUT = 4

XML = '''<node>
  <interface name="org.freedesktop.impl.portal.FileChooser">
    <method name="OpenFile"><arg type="o" name="handle" direction="in"/><arg type="s" name="app_id" direction="in"/><arg type="s" name="parent_window" direction="in"/><arg type="s" name="title" direction="in"/><arg type="a{sv}" name="options" direction="in"/><arg type="u" name="response" direction="out"/><arg type="a{sv}" name="results" direction="out"/></method>
    <method name="SaveFile"><arg type="o" name="handle" direction="in"/><arg type="s" name="app_id" direction="in"/><arg type="s" name="parent_window" direction="in"/><arg type="s" name="title" direction="in"/><arg type="a{sv}" name="options" direction="in"/><arg type="u" name="response" direction="out"/><arg type="a{sv}" name="results" direction="out"/></method>
    <method name="SaveFiles"><arg type="o" name="handle" direction="in"/><arg type="s" name="app_id" direction="in"/><arg type="s" name="parent_window" direction="in"/><arg type="s" name="title" direction="in"/><arg type="a{sv}" name="options" direction="in"/><arg type="u" name="response" direction="out"/><arg type="a{sv}" name="results" direction="out"/></method>
    <property name="version" type="u" access="read"/>
  </interface>
</node>'''
REQUEST_XML = '''<node><interface name="org.freedesktop.impl.portal.Request"><method name="Close"/></interface></node>'''


def fallback_backend():
    """The FileChooser backend Opal replaced, recorded by the installer."""
    try:
        name = json.loads(STATE.read_text()).get('fallback') or 'gtk'
    except (OSError, ValueError):
        name = 'gtk'
    return name if name.replace('-', '').isalnum() and name != 'opal' else 'gtk'


def bytes_path(value):
    """Portal paths are NUL-terminated byte arrays."""
    if not value:
        return ''
    raw = bytes(value).split(b'\0', 1)[0]
    return raw.decode('utf-8', 'surrogateescape')


def describe(kind, app_id, title, options):
    """The request as the shell sees it: plain JSON, no GVariant types."""
    filters = []
    for name, rules in options.get('filters', []) or []:
        filters.append({'name': name, 'globs': [p for t, p in rules if t == 0], 'mimes': [p for t, p in rules if t == 1]})
    current = options.get('current_filter')
    return dict(kind=kind, app=app_id, title=title or ('Save' if kind != 'open' else 'Open'),
                accept=options.get('accept_label') or '', multiple=bool(options.get('multiple')),
                directory=bool(options.get('directory')), modal=bool(options.get('modal', True)),
                filters=filters, filter=filters.index(next((f for f in filters if current and f['name'] == current[0]), filters[0])) if filters else -1,
                folder=bytes_path(options.get('current_folder')), name=options.get('current_name') or '',
                file=bytes_path(options.get('current_file')),
                files=[bytes_path(f) for f in options.get('files', [])] if kind == 'savefiles' else [])


class Portal:
    def __init__(self, connection):
        self.connection = connection
        self.pending = {}
        self.next_token = 1
        info = Gio.DBusNodeInfo.new_for_xml(XML)
        self.request_info = Gio.DBusNodeInfo.new_for_xml(REQUEST_XML).interfaces[0]
        connection.register_object(OBJECT, info.interfaces[0], self.method, self.get_property, None)
        threading.Thread(target=self.listen, daemon=True).start()

    def get_property(self, connection, sender, path, interface, name):
        return GLib.Variant('u', 3) if name == 'version' else None

    def method(self, connection, sender, path, interface, method, params, invocation):
        handle, app_id, parent, title, options = params.unpack()
        kind = {'OpenFile': 'open', 'SaveFile': 'save', 'SaveFiles': 'savefiles'}[method]
        token = '%d-%d' % (os.getpid(), self.next_token)
        self.next_token += 1
        request = dict(invocation=invocation, method=method, params=params, handle=handle, options=options, kind=kind)
        self.pending[token] = request
        request['registration'] = connection.register_object(handle, self.request_info, lambda *a: self.close(token, a[-1]), None, None)
        payload = describe(kind, app_id, title, options)
        payload['token'] = token
        threading.Thread(target=self.ask_shell, args=(token, payload), daemon=True).start()

    def ask_shell(self, token, payload):
        """The shell says "shown" when it draws the picker; anything else goes to the fallback."""
        try:
            encoded = base64.b64encode(json.dumps(payload).encode()).decode()
            answer = subprocess.run(['quickshell', 'ipc', '-p', str(CONFIG), 'call', 'opal', 'portalPick', encoded],
                                    capture_output=True, text=True, timeout=SHOW_TIMEOUT).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            answer = ''
        if answer != 'shown':
            GLib.idle_add(self.forward, token)

    def forward(self, token):
        request = self.pending.get(token)
        if not request:
            return False
        request['forwarded'] = True
        self.unregister(request)
        name = 'org.freedesktop.impl.portal.desktop.' + fallback_backend()

        def done(connection, result):
            current = self.pending.pop(token, None)
            if not current:
                return
            try:
                reply = connection.call_finish(result)
                current['invocation'].return_value(reply)
            except GLib.Error:
                current['invocation'].return_value(GLib.Variant('(ua{sv})', (2, {})))
        self.connection.call(name, OBJECT, 'org.freedesktop.impl.portal.FileChooser', request['method'], request['params'],
                             GLib.VariantType('(ua{sv})'), Gio.DBusCallFlags.NONE, 2**31-1, None, done)
        return False

    def unregister(self, request):
        if request.get('registration'):
            self.connection.unregister_object(request.pop('registration'))

    def close(self, token, invocation):
        request = self.pending.get(token)
        if request and request.get('forwarded'):
            name = 'org.freedesktop.impl.portal.desktop.' + fallback_backend()
            self.connection.call(name, request['handle'], 'org.freedesktop.impl.portal.Request', 'Close', None, None, Gio.DBusCallFlags.NONE, -1, None, None)
        elif request:
            self.finish(token, 2, {})
            self.notify_shell_closed(token)
        invocation.return_value(None)

    def notify_shell_closed(self, token):
        try:
            subprocess.Popen(['quickshell', 'ipc', '-p', str(CONFIG), 'call', 'opal', 'portalCancel', token],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass

    def finish(self, token, response, results):
        request = self.pending.pop(token, None)
        if not request:
            return False
        self.unregister(request)
        request['invocation'].return_value(GLib.Variant('(ua{sv})', (response, results)))
        return False

    def answer(self, data):
        """One answer from the shell: {token, uris[], filter?} or {token, cancel:true}."""
        token = data.get('token')
        if token not in self.pending or self.pending[token].get('forwarded'):
            return
        if data.get('decline'):
            GLib.idle_add(self.forward, token)
            return
        uris = [u for u in data.get('uris') or [] if isinstance(u, str) and u.startswith('file://')]
        if data.get('cancel') or not uris:
            GLib.idle_add(self.finish, token, 1, {})
            return
        results = {'uris': GLib.Variant('as', uris)}
        request = self.pending[token]
        filters = request['options'].get('filters') or []
        index = data.get('filter')
        if type(index) is int and 0 <= index < len(filters):
            results['current_filter'] = GLib.Variant('(sa(us))', filters[index])
        GLib.idle_add(self.finish, token, 0, results)

    def listen(self):
        """Answers come from the shell's backend, which runs as the same user."""
        try:
            SOCKET.unlink()
        except FileNotFoundError:
            pass
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(SOCKET))
        os.chmod(SOCKET, 0o600)
        server.listen(4)
        while True:
            client, _ = server.accept()
            with client:
                try:
                    creds = client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
                    if int.from_bytes(creds[4:8], sys.byteorder) != os.getuid():
                        continue
                    client.settimeout(2)
                    data = b''
                    while len(data) < 1 << 20:
                        chunk = client.recv(65536)
                        if not chunk:
                            break
                        data += chunk
                    self.answer(json.loads(data.decode()))
                except (OSError, ValueError, UnicodeDecodeError):
                    continue


def main():
    loop = GLib.MainLoop()
    holder = {}

    def acquired(connection, name):
        holder['portal'] = Portal(connection)

    def lost(connection, name):
        loop.quit()
    Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE, acquired, None, lost)
    loop.run()


if __name__ == '__main__':
    main()
