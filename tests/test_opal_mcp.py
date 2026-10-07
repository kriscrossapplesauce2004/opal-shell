import json, pathlib, sys, unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import opal_mcp


class OpalMcpTests(unittest.TestCase):
    def test_initialize_and_list(self):
        reply = opal_mcp.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}})
        self.assertEqual(reply['result']['serverInfo']['name'], 'opal')
        tools = opal_mcp.handle({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'})['result']['tools']
        self.assertIn('set_preference', [t['name'] for t in tools])
        self.assertIsNone(opal_mcp.handle({'jsonrpc': '2.0', 'method': 'notifications/initialized'}))

    def test_set_preference_sends_json_through_ipc(self):
        with patch.object(opal_mcp, 'ipc', return_value='Sent light') as ipc:
            reply = opal_mcp.handle({'jsonrpc': '2.0', 'id': 3, 'method': 'tools/call', 'params': {'name': 'set_preference', 'arguments': {'key': 'light', 'value': True}}})
        ipc.assert_called_once_with('setPreferenceEncoded', 'light', 'dHJ1ZQ==')
        self.assertFalse(reply['result']['isError'])
        # Arrays carry commas, which the quickshell CLI would split; base64 keeps them one argument.
        with patch.object(opal_mcp, 'ipc', return_value='Sent themeExport') as ipc:
            opal_mcp.handle({'jsonrpc': '2.0', 'id': 4, 'method': 'tools/call', 'params': {'name': 'set_preference', 'arguments': {'key': 'themeExport', 'value': ['qt', 'kde']}}})
        self.assertNotIn(',', ipc.call_args.args[2])

    def test_layout_names_map_to_ipc_functions(self):
        with patch.object(opal_mcp, 'ipc', return_value='') as ipc:
            opal_mcp.handle({'jsonrpc': '2.0', 'id': 4, 'method': 'tools/call', 'params': {'name': 'set_layout', 'arguments': {'layout': 'console'}}})
        ipc.assert_called_once_with('gaming')

    def test_errors_are_reported_not_raised(self):
        with patch.object(opal_mcp, 'ipc', side_effect=RuntimeError('Opal is not running')):
            reply = opal_mcp.handle({'jsonrpc': '2.0', 'id': 5, 'method': 'tools/call', 'params': {'name': 'get_status', 'arguments': {}}})
        self.assertTrue(reply['result']['isError'])
        self.assertIn('not running', reply['result']['content'][0]['text'])
        unknown = opal_mcp.handle({'jsonrpc': '2.0', 'id': 6, 'method': 'tools/call', 'params': {'name': 'rm_rf', 'arguments': {}}})
        self.assertIn('error', unknown)


if __name__ == '__main__':
    unittest.main()
