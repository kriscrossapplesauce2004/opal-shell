import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import display_ddc as d

DETECT = """Display 1
   I2C bus:          /dev/i2c-4
   DRM connector:    card1-DP-1
   Monitor:          DEL:DELL U2723QE:ABC123

Invalid display
   I2C bus:          /dev/i2c-5
   DRM connector:    card1-HDMI-A-1
   Monitor:          SAM:SAMSUNG:
"""


class DdcTests(unittest.TestCase):
    def test_detect(self):
        got = d.parse_detect(DETECT)
        self.assertEqual(got[0], {'bus': 4, 'connector': 'DP-1', 'model': 'DELL U2723QE ABC123', 'ddc': True})
        self.assertEqual(got[1]['connector'], 'HDMI-A-1')
        self.assertFalse(got[1]['ddc'])
        self.assertEqual(got[1]['model'], 'SAMSUNG')

    def test_vcp(self):
        self.assertEqual(d.parse_vcp('VCP 10 C 72 100'), (72, 100))
        self.assertIsNone(d.parse_vcp('VCP 10 ERR'))


if __name__ == '__main__':
    unittest.main()
