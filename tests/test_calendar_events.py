import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import calendar_events as ce

UTC = dt.timezone.utc
ICS = """BEGIN:VCALENDAR
BEGIN:VEVENT
UID:standup
SUMMARY:Standup
DTSTART:20261026T150000Z
DTEND:20261026T151500Z
RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR
EXDATE:20261030T150000Z
DESCRIPTION:Join at https://meet.google.com/abc-defg-hij
END:VEVENT
BEGIN:VEVENT
UID:prints
SUMMARY:Pick up
  prints
DTSTART;VALUE=DATE:20261028
END:VEVENT
BEGIN:VEVENT
UID:gone
SUMMARY:Cancelled thing
STATUS:CANCELLED
DTSTART:20261028T100000Z
END:VEVENT
END:VCALENDAR
"""


class CalendarTests(unittest.TestCase):
    def test_parse_reads_events_and_skips_cancelled(self):
        events = ce.parse(ICS, UTC)
        self.assertEqual([e['title'] for e in events], ['Standup', 'Pick up prints'])
        self.assertEqual(events[0]['join'], 'https://meet.google.com/abc-defg-hij')
        self.assertTrue(events[1]['allDay'])
        self.assertEqual(events[1]['end'] - events[1]['start'], dt.timedelta(days=1))

    def test_weekly_byday_with_exdate(self):
        ev = ce.parse(ICS, UTC)[0]
        got = ce.occurrences(ev, dt.datetime(2026, 10, 26, tzinfo=UTC), dt.datetime(2026, 11, 2, tzinfo=UTC))
        self.assertEqual([t.day for t in got], [26, 28])

    def test_count_and_until_stop(self):
        ev = {'start': dt.datetime(2026, 1, 1, 9, tzinfo=UTC), 'end': dt.datetime(2026, 1, 1, 10, tzinfo=UTC), 'rrule': {'FREQ': 'DAILY', 'COUNT': '3'}}
        self.assertEqual(len(ce.occurrences(ev, dt.datetime(2025, 1, 1, tzinfo=UTC), dt.datetime(2027, 1, 1, tzinfo=UTC))), 3)
        ev['rrule'] = {'FREQ': 'DAILY', 'UNTIL': '20260102T090000Z'}
        self.assertEqual(len(ce.occurrences(ev, dt.datetime(2025, 1, 1, tzinfo=UTC), dt.datetime(2027, 1, 1, tzinfo=UTC))), 2)

    def test_clocks_skip_unknown_zones(self):
        got = ce.clocks(['Asia/Tokyo', 'Not/AZone'], dt.datetime(2026, 10, 28, tzinfo=UTC))
        self.assertEqual(got, [{'zone': 'Asia/Tokyo', 'label': 'Tokyo', 'offset': 540}])


if __name__ == '__main__':
    unittest.main()
