import pathlib, sys, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import smart_back


class FakeActions:
    def __init__(self, clients):
        self._clients = clients
        self.shortcuts = []
        self.focused = []

    def clients(self):
        return self._clients

    def send_shortcut(self, mods, key, address=''):
        self.shortcuts.append((mods, key, address))

    def focus(self, address):
        self.focused.append(address)


class FakeWaydroid:
    def __init__(self):
        self.back_calls = 0

    def send_back(self):
        self.back_calls += 1
        return True


class SmartBackTests(unittest.TestCase):
    def test_waydroid_window_routes_to_android_back(self):
        clients = [{'address': '0x10', 'class': 'waydroid.org.mozilla.fennec_fdroid', 'title': 'Fennec', 'focusHistoryID': 0, 'workspace': {'id': 1}}]
        act = FakeActions(clients)
        wd = FakeWaydroid()
        plan = smart_back.execute_back(actions=act, waydroid=wd)
        self.assertEqual(plan['op'], 'waydroid')
        self.assertEqual(wd.back_calls, 1)
        self.assertEqual(act.shortcuts, [])

    def test_transient_dialog_sends_escape(self):
        clients = [
            {'address': '0x20', 'class': 'firefox', 'title': 'Save File', 'floating': True, 'focusHistoryID': 0, 'workspace': {'id': 1}},
            {'address': '0x21', 'class': 'firefox', 'title': 'Mozilla Firefox', 'floating': False, 'focusHistoryID': 1, 'workspace': {'id': 1}},
        ]
        act = FakeActions(clients)
        wd = FakeWaydroid()
        plan = smart_back.execute_back(actions=act, waydroid=wd)
        self.assertEqual(plan, {'op': 'shortcut', 'mods': [], 'key': 'Escape', 'address': '0x20'})
        self.assertEqual(act.shortcuts, [([], 'Escape', '0x20')])

    def test_browser_or_file_manager_sends_alt_left(self):
        clients = [{'address': '0x30', 'class': 'org.kde.dolphin', 'title': 'Home — Dolphin', 'floating': False, 'focusHistoryID': 0, 'workspace': {'id': 1}}]
        act = FakeActions(clients)
        wd = FakeWaydroid()
        plan = smart_back.execute_back(actions=act, waydroid=wd)
        self.assertEqual(plan, {'op': 'shortcut', 'mods': ['ALT'], 'key': 'Left', 'address': '0x30'})
        self.assertEqual(act.shortcuts, [(['ALT'], 'Left', '0x30')])

    def test_fallback_focuses_previous_mru_window(self):
        clients = [
            {'address': '0x40', 'class': 'kitty', 'title': 'Terminal', 'floating': False, 'focusHistoryID': 0, 'workspace': {'id': 1}},
            {'address': '0x41', 'class': 'code', 'title': 'VS Code', 'floating': False, 'focusHistoryID': 1, 'workspace': {'id': 1}},
        ]
        act = FakeActions(clients)
        wd = FakeWaydroid()
        plan = smart_back.execute_back(actions=act, waydroid=wd)
        self.assertEqual(plan, {'op': 'focus', 'address': '0x41'})
        self.assertEqual(act.focused, ['0x41'])


if __name__ == '__main__':
    unittest.main()
