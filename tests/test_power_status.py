import pathlib
import sys
import unittest


sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import power_status


class PowerStatusTests(unittest.TestCase):
    def test_internal_batteries_take_priority(self):
        batteries = [
            {'percent': 80, 'charging': False, 'internal': True, 'source': 'system'},
            {'percent': 60, 'charging': False, 'internal': False, 'source': 'bluetooth'},
        ]
        self.assertEqual(power_status.primary_battery(batteries), (80, False))

    def test_connected_bluetooth_battery_is_used_without_system_battery(self):
        batteries = [
            {'percent': 0, 'charging': False, 'internal': False, 'source': 'upower'},
            {'percent': 60, 'charging': False, 'internal': False, 'source': 'bluetooth'},
        ]
        self.assertEqual(power_status.primary_battery(batteries), (60, False))

    def test_virtual_display_battery_is_not_a_device(self):
        text = '''Device: /org/freedesktop/UPower/devices/DisplayDevice
  percentage: 0%
Device: /org/freedesktop/UPower/devices/mouse_test
  model: Wireless mouse
  percentage: 58%
'''
        batteries = power_status.parse_upower_batteries(text)
        self.assertEqual(len(batteries), 1)
        self.assertEqual(batteries[0]['name'], 'Wireless mouse')
        self.assertEqual(batteries[0]['percent'], 58)

    def test_missing_battery_data_stays_unknown(self):
        self.assertEqual(power_status.primary_battery([]), (-1, False))


if __name__ == '__main__':
    unittest.main()
