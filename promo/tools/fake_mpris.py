"""A silent MPRIS player for promo recordings: real track metadata and art, a moving position, no audio.

Usage: fake_mpris.py playlist.json   (a list of {title, artist, album, art, length, position})
"""
import json, sys, time
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

ROOT, PLAYER = 'org.mpris.MediaPlayer2', 'org.mpris.MediaPlayer2.Player'
PATH = '/org/mpris/MediaPlayer2'


class Player(dbus.service.Object):
    def __init__(self, bus, tracks):
        super().__init__(bus, PATH)
        self.tracks, self.index = tracks, 0
        self.playing = True
        self.base = tracks[0].get('position', 0)
        self.started = time.monotonic()

    def position(self):
        if not self.playing:
            return self.base
        return min(self.track['length'], self.base + time.monotonic() - self.started)

    @property
    def track(self):
        return self.tracks[self.index]

    def metadata(self):
        t = self.track
        return dbus.Dictionary({
            'mpris:trackid': dbus.ObjectPath(f'/dev/opal/promo/track{self.index}'),
            'mpris:length': dbus.Int64(int(t['length'] * 1e6)),
            'mpris:artUrl': 'file://' + t['art'],
            'xesam:title': t['title'],
            'xesam:artist': dbus.Array([t['artist']], signature='s'),
            'xesam:album': t['album'],
        }, signature='sv')

    def props(self, iface):
        if iface == ROOT:
            return {'CanQuit': False, 'CanRaise': False, 'HasTrackList': False, 'Identity': 'Media', 'DesktopEntry': 'dev.opal.Media',
                    'SupportedUriSchemes': dbus.Array([], signature='s'), 'SupportedMimeTypes': dbus.Array([], signature='s')}
        return {'PlaybackStatus': 'Playing' if self.playing else 'Paused', 'LoopStatus': 'None', 'Rate': 1.0, 'Shuffle': False,
                'Metadata': self.metadata(), 'Volume': 0.8, 'Position': dbus.Int64(int(self.position() * 1e6)),
                'MinimumRate': 1.0, 'MaximumRate': 1.0, 'CanGoNext': True, 'CanGoPrevious': True, 'CanPlay': True,
                'CanPause': True, 'CanSeek': True, 'CanControl': True}

    def changed(self, *names):
        all_props = self.props(PLAYER)
        self.PropertiesChanged(PLAYER, {n: all_props[n] for n in names}, [])

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature='ss', out_signature='v')
    def Get(self, iface, name):
        return self.props(iface)[name]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature='s', out_signature='a{sv}')
    def GetAll(self, iface):
        return self.props(iface)

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature='ssv')
    def Set(self, iface, name, value):
        pass

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature='sa{sv}as')
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    @dbus.service.signal(PLAYER, signature='x')
    def Seeked(self, position):
        pass

    @dbus.service.method(ROOT)
    def Raise(self):
        pass

    @dbus.service.method(ROOT)
    def Quit(self):
        pass

    def jump(self, step):
        self.index = (self.index + step) % len(self.tracks)
        self.base, self.started, self.playing = 0, time.monotonic(), True
        self.changed('Metadata', 'PlaybackStatus', 'Position')
        self.Seeked(dbus.Int64(0))

    @dbus.service.method(PLAYER)
    def Next(self):
        self.jump(1)

    @dbus.service.method(PLAYER)
    def Previous(self):
        self.jump(-1)

    @dbus.service.method(PLAYER)
    def PlayPause(self):
        self.base, self.started = self.position(), time.monotonic()
        self.playing = not self.playing
        self.changed('PlaybackStatus', 'Position')

    @dbus.service.method(PLAYER)
    def Play(self):
        if not self.playing:
            self.PlayPause()

    @dbus.service.method(PLAYER)
    def Pause(self):
        if self.playing:
            self.PlayPause()

    @dbus.service.method(PLAYER)
    def Stop(self):
        self.Pause()

    @dbus.service.method(PLAYER, in_signature='x')
    def Seek(self, offset):
        self.base, self.started = max(0, self.position() + offset / 1e6), time.monotonic()
        self.Seeked(dbus.Int64(int(self.position() * 1e6)))

    @dbus.service.method(PLAYER, in_signature='ox')
    def SetPosition(self, track, position):
        self.base, self.started = position / 1e6, time.monotonic()
        self.Seeked(dbus.Int64(position))


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName('org.mpris.MediaPlayer2.opalmedia', bus)
    Player(bus, json.load(open(sys.argv[1])))
    GLib.MainLoop().run()


if __name__ == '__main__':
    main()
