#!/usr/bin/env python3
"""Start one activity on dev.opal.Activities and keep the bus name alive until killed."""
import sys

import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib


def main(argv):
    payload = argv[0] if argv else '{}'
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    reply = bus.call_sync(
        'dev.opal.Activities', '/dev/opal/Activities', 'dev.opal.Activities', 'Start',
        GLib.Variant('(s)', (payload,)), GLib.VariantType('(s)'), Gio.DBusCallFlags.NONE, 5000, None)
    print(reply.unpack()[0], flush=True)
    GLib.MainLoop().run()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
