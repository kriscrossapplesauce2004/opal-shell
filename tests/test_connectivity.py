import pathlib
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
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

    def test_wifi_list_keeps_first_of_many_duplicate_ssids(self):
        rows = ['*:Office\\: floor:80:WPA2:wlan0']
        rows.extend(':Office\\: floor:20:WPA2:wlan0' for _ in range(500))
        events, _ = self.work({'kind': 'wifi'}, ['enabled', '\n'.join(rows)])
        self.assertEqual(events[-1]['items'], [{
            'active': True, 'ssid': 'Office: floor', 'signal': '80',
            'security': 'WPA2', 'device': 'wlan0',
        }])

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
        devices = [
            'Device AA:BB:CC:DD:%02X:%02X Headphones %d' % (index // 256, index, index)
            for index in range(40)
        ]
        connected = [devices[index] for index in range(0, 40, 2)]
        paired = [devices[index] for index in range(0, 40, 3)]
        events, run = self.work({'kind': 'bluetooth'}, [
            'Powered: yes',
            '\n'.join(devices),
            '\n'.join(connected),
            '\n'.join(paired),
        ])
        items = events[-1]['items']
        self.assertEqual(len(items), len(devices))
        self.assertEqual(sum(item['active'] for item in items), len(connected))
        self.assertEqual(sum(item['paired'] for item in items), len(paired))
        self.assertTrue(items[0]['paired'])
        self.assertTrue(items[0]['active'])
        self.assertEqual(run.call_count, 4)
        self.assertNotIn('info', [call.args[1] for call in run.call_args_list])

    def test_bluetooth_list_ignores_bad_filtered_device_rows(self):
        events, _ = self.work({'kind': 'bluetooth'}, [
            'Powered: yes',
            'Device AA:BB:CC:DD:EE:FF Headphones',
            'Device not-an-address Invalid',
            'Device GG:BB:CC:DD:EE:FF Invalid',
        ])
        self.assertFalse(events[-1]['items'][0]['active'])
        self.assertFalse(events[-1]['items'][0]['paired'])


if __name__ == '__main__':
    unittest.main()
