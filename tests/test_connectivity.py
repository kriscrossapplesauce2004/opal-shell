import pathlib
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from connectivity import Connectivity, fields


class ConnectivityTests(unittest.TestCase):
    def work(self, command, responses):
        events = []
        service = Connectivity(events.append)
        service.lock.acquire()
        with patch.object(service, 'run', side_effect=responses) as run:
            service.work(command)
        self.assertFalse(service.lock.locked())
        return events, run

    def test_escaped_ssid(self):
        self.assertEqual(fields(r'*:Cafe\: west:80:WPA2:wlan0'), ['*', 'Cafe: west', '80', 'WPA2', 'wlan0'])

    def test_wifi_list(self):
        events, _ = self.work({'kind': 'wifi'}, ['enabled', '*:Home:80:WPA2:wlan0\n:Home:50:WPA2:wlan0\n:Guest:90::wlan0'])
        self.assertEqual(len(events[-1]['items']), 2)
        self.assertTrue(events[-1]['items'][0]['active'])
        self.assertFalse(events[-1]['busy'])

    def test_password_not_emitted(self):
        events, run = self.work({'kind': 'wifi', 'verb': 'connect', 'ssid': 'Home', 'password': 'secret'}, ['', 'enabled', ''])
        self.assertNotIn('secret', str(events))
        self.assertEqual(run.call_args_list[0].args[-2:], ('password', 'secret'))

    def test_invalid_address(self):
        events, run = self.work({'kind': 'bluetooth', 'verb': 'pair', 'address': '--help'}, [])
        run.assert_not_called()
        self.assertIn('Invalid', events[-1]['error'])

    def test_failure_clears_busy(self):
        events, _ = self.work({'kind': 'wifi'}, [ValueError('Unavailable')])
        self.assertEqual(events[-1]['error'], 'Unavailable')
        self.assertFalse(events[-1]['busy'])

    def test_bluetooth_list(self):
        events, _ = self.work({'kind': 'bluetooth'}, ['Powered: yes', 'Device AA:BB:CC:DD:EE:FF Headphones', 'Connected: yes\nPaired: yes'])
        self.assertTrue(events[-1]['items'][0]['paired'])
        self.assertTrue(events[-1]['items'][0]['active'])


if __name__ == '__main__':
    unittest.main()
