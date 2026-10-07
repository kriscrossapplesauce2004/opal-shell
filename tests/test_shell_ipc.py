"""The live entry point is not loaded by offscreen tests, so check its IPC handler statically."""
import pathlib, re, unittest

SHELL = pathlib.Path(__file__).resolve().parents[1] / 'src' / 'shell.qml'


class ShellIpcTests(unittest.TestCase):
    def test_ipc_function_names_are_unique(self):
        text = SHELL.read_text()
        block = text[text.index('IpcHandler {'):]
        block = block[:block.index('\n    }\n')]
        names = re.findall(r'^\s*function (\w+)\(', block, re.M)
        duplicates = sorted({n for n in names if names.count(n) > 1})
        self.assertEqual(duplicates, [], 'Duplicate IPC functions break shell.qml: %s' % duplicates)

    def test_quick_access_ipc_and_window_exist(self):
        text = SHELL.read_text()
        self.assertIn('function quickaccess():void {GameState.toggleQuickAccess();}', text)
        self.assertIn('opal-quick-access', text)

    def test_mcp_server_calls_existing_ipc_functions(self):
        text = SHELL.read_text()
        names = set(re.findall(r'^\s*function (\w+)\(', text[text.index('IpcHandler {'):], re.M))
        mcp = (SHELL.parent / 'opal_mcp.py').read_text()
        called = set(re.findall(r"ipc\('(\w+)'", mcp)) | set(re.findall(r"ipc\(a\['panel'\]\)", mcp) and [])
        panels = set(re.search(r"PANELS = \(([^)]*)\)", mcp).group(1).replace("'", '').replace(' ', '').split(','))
        layouts = set(re.findall(r"': '(\w+)'", re.search(r'LAYOUTS = \{[^}]*\}', mcp).group(0)))
        missing = sorted((called | panels | layouts) - names)
        self.assertEqual(missing, [], 'MCP tools call missing IPC functions: %s' % missing)


if __name__ == '__main__':
    unittest.main()
