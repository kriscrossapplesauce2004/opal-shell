#!/usr/bin/env python3
"""DBus bridge for live activities. It owns dev.opal.Activities on the session bus and speaks JSON lines with the shell on stdin and stdout."""
import json, sys

import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

NAME = 'dev.opal.Activities'
PATH = '/dev/opal/Activities'
XML = '''
<node>
  <interface name="dev.opal.Activities">
    <method name="Start"><arg type="s" name="json" direction="in"/><arg type="s" name="id" direction="out"/></method>
    <method name="Update"><arg type="s" name="id" direction="in"/><arg type="s" name="json" direction="in"/></method>
    <method name="End"><arg type="s" name="id" direction="in"/></method>
    <signal name="ActionInvoked"><arg type="s" name="id"/><arg type="s" name="action"/></signal>
  </interface>
</node>
'''
MAX_JSON = 8192


class Bridge:
    def __init__(self, write=None):
        self.write = write or (lambda line: (sys.stdout.write(line + '\n'), sys.stdout.flush()))
        self.serial = 0
        self.waiting = {}
        self.owners = {}
        self.watches = {}
        self.connection = None

    def send(self, message):
        self.write(json.dumps(message, separators=(',', ':')))

    def request(self, op, data=None, ident=None, invocation=None):
        self.serial += 1
        if invocation is not None: self.waiting[self.serial] = invocation
        message = {'op': op, 'serial': self.serial}
        if data is not None: message['data'] = data
        if ident is not None: message['id'] = ident
        self.send(message)
        return self.serial

    @staticmethod
    def decode(text):
        if not isinstance(text, str) or len(text) > MAX_JSON: raise ValueError('The activity is too large')
        value = json.loads(text)
        if not isinstance(value, dict): raise ValueError('The activity must be a JSON object')
        return value

    def remember(self, sender, ident):
        if not sender or not ident: return
        self.owners.setdefault(sender, set()).add(ident)
        if sender not in self.watches and self.connection is not None:
            self.watches[sender] = Gio.bus_watch_name_on_connection(self.connection, sender, Gio.BusNameWatcherFlags.NONE, None, self.vanished)

    def vanished(self, connection, sender):
        # An app that leaves the bus takes its activities with it.
        for ident in sorted(self.owners.pop(sender, set())): self.request('end', ident=ident)
        watch = self.watches.pop(sender, None)
        if watch is not None: Gio.bus_unwatch_name(watch)

    def call(self, connection, sender, path, interface, method, parameters, invocation):
        try:
            if method == 'Start':
                data = self.decode(parameters.unpack()[0])
                serial = self.request('start', data=data)
                self.waiting[serial] = (invocation, sender)
            elif method == 'Update':
                ident, text = parameters.unpack()
                self.request('update', data=self.decode(text), ident=str(ident)[:64])
                invocation.return_value(None)
            elif method == 'End':
                ident = str(parameters.unpack()[0])[:64]
                self.request('end', ident=ident)
                for owned in self.owners.values(): owned.discard(ident)
                invocation.return_value(None)
        except (ValueError, TypeError) as error:
            invocation.return_dbus_error('dev.opal.Activities.Error.Invalid', str(error))

    def line(self, text):
        try: message = json.loads(text)
        except ValueError: return
        if message.get('event') == 'reply':
            entry = self.waiting.pop(message.get('serial'), None)
            if entry is None: return
            invocation, sender = entry if isinstance(entry, tuple) else (entry, None)
            ident = str(message.get('id') or '')
            if ident:
                self.remember(sender, ident)
                invocation.return_value(GLib.Variant('(s)', (ident,)))
            else:
                invocation.return_dbus_error('dev.opal.Activities.Error.Invalid', 'The activity was not accepted')
        elif message.get('event') == 'action' and self.connection is not None:
            self.connection.emit_signal(None, PATH, NAME, 'ActionInvoked', GLib.Variant('(ss)', (str(message.get('id', '')), str(message.get('action', '')))))


def main():
    bridge = Bridge()
    loop = GLib.MainLoop()
    info = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]

    def acquired(connection, name):
        bridge.connection = connection
        connection.register_object(PATH, info, bridge.call, None, None)

    def lost(connection, name):
        print('dev.opal.Activities is owned by another process', file=sys.stderr)
        loop.quit()

    def readable(source, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR): loop.quit(); return False
        text = sys.stdin.readline()
        if not text: loop.quit(); return False
        bridge.line(text.strip())
        return True

    Gio.bus_own_name(Gio.BusType.SESSION, NAME, Gio.BusNameOwnerFlags.NONE, acquired, None, lost)
    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, readable)
    loop.run()


if __name__ == '__main__':
    main()
