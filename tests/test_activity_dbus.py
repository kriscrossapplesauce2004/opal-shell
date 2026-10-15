import json, pathlib, sys, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
try:
    import activity_dbus
except (ImportError, ValueError):
    activity_dbus = None


class FakeInvocation:
    def __init__(self): self.value = None; self.error = None
    def return_value(self, value): self.value = value
    def return_dbus_error(self, name, text): self.error = (name, text)


class FakeParams:
    def __init__(self, *values): self.values = values
    def unpack(self): return self.values


@unittest.skipIf(activity_dbus is None, 'PyGObject is required')
class ActivityBridgeTests(unittest.TestCase):
    def setUp(self):
        self.lines = []
        self.bridge = activity_dbus.Bridge(write=self.lines.append)

    def test_start_waits_for_the_shell_reply(self):
        call = FakeInvocation()
        self.bridge.call(None, ':1.5', activity_dbus.PATH, activity_dbus.NAME, 'Start', FakeParams('{"id":"build","title":"Build"}'), call)
        sent = json.loads(self.lines[-1])
        self.assertEqual((sent['op'], sent['data']['title']), ('start', 'Build'))
        self.assertIsNone(call.value)
        self.bridge.line(json.dumps({'event': 'reply', 'serial': sent['serial'], 'id': 'build'}))
        self.assertEqual(call.value.unpack(), ('build',))
        self.assertEqual(self.bridge.owners[':1.5'], {'build'})

    def test_rejected_start_and_bad_json(self):
        call = FakeInvocation()
        self.bridge.call(None, ':1.5', '', '', 'Start', FakeParams('{"title":"no id"}'), call)
        self.bridge.line(json.dumps({'event': 'reply', 'serial': json.loads(self.lines[-1])['serial'], 'id': ''}))
        self.assertIsNotNone(call.error)
        bad = FakeInvocation()
        self.bridge.call(None, ':1.5', '', '', 'Start', FakeParams('[1,2]'), bad)
        self.assertIsNotNone(bad.error)
        huge = FakeInvocation()
        self.bridge.call(None, ':1.5', '', '', 'Update', FakeParams('x', '{"a":"' + 'x' * 9000 + '"}'), huge)
        self.assertIsNotNone(huge.error)

    def test_update_end_and_vanished_sender(self):
        call = FakeInvocation()
        self.bridge.call(None, ':1.9', '', '', 'Update', FakeParams('job', '{"progress":0.5}'), call)
        self.assertEqual(json.loads(self.lines[-1])['op'], 'update')
        self.bridge.owners[':1.9'] = {'job', 'other'}
        self.bridge.vanished(None, ':1.9')
        ended = [json.loads(l)['id'] for l in self.lines if json.loads(l)['op'] == 'end']
        self.assertEqual(ended, ['job', 'other'])


if __name__ == '__main__':
    unittest.main()
