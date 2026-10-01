"""Run the greeter controller against a fake greetd IPC socket: wrong password, then a launch."""
import json, os, shutil, socket, struct, subprocess, sys, tempfile, threading, unittest
from pathlib import Path


def serve(server, log):
    def read(conn):
        try: header = conn.recv(4)
        except ConnectionResetError: return None
        if len(header) < 4: return None
        size = struct.unpack('=I', header)[0]
        data = b''
        while len(data) < size: data += conn.recv(size - len(data))
        return json.loads(data)
    def send(conn, value):
        data = json.dumps(value).encode()
        conn.sendall(struct.pack('=I', len(data)) + data)
    conn, _ = server.accept()
    with conn:
        while True:
            message = read(conn)
            if message is None: return
            log.append(message)
            kind = message['type']
            if kind == 'create_session':
                send(conn, {'type': 'auth_message', 'auth_message_type': 'secret', 'auth_message': 'Password:'})
            elif kind == 'post_auth_message_response':
                if message.get('response') == 'right': send(conn, {'type': 'success'})
                else: send(conn, {'type': 'error', 'error_type': 'auth_error', 'description': 'authentication failed'})
            else:
                send(conn, {'type': 'success'})


@unittest.skipUnless(shutil.which('quickshell'), 'quickshell is not installed')
class GreeterFlowTest(unittest.TestCase):
    def test_wrong_then_right_password_launches_session(self):
        source = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            config = tmp / 'fixture'
            shutil.copytree(source / 'src', config / 'src', ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copy(source / 'tests' / 'greeter-test.qml', config / 'greeter-test.qml')
            info = tmp / 'info.py'
            info.write_text('import json,sys\nif "--remember" in sys.argv: sys.exit(0)\nprint(json.dumps({"users":[{"login":"melissa","name":"Melissa"}],"sessions":[{"id":"hyprland","name":"Hyprland","command":["start-hyprland"]}],"layout":"gb","last":{}}))\n')
            sock_path = str(tmp / 'greetd.sock')
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(sock_path); server.listen(1)
            log = []
            thread = threading.Thread(target=serve, args=(server, log), daemon=True); thread.start()
            runtime = tmp / 'runtime'; runtime.mkdir(mode=0o700)
            env = dict(os.environ, HOME=str(tmp), XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(tmp / 'config'),
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_LOGGING_RULES='qml.debug=true',
                       GREETD_SOCK=sock_path, OPAL_GREETER='1', OPAL_GREETER_THEME=str(tmp / 'none.json'), OPAL_TEST_INFO=str(info),
                       DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(tmp / 'no-bus'))
            for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE'): env.pop(key, None)
            result = subprocess.run(['quickshell', '-p', str(config / 'greeter-test.qml')], env=env, capture_output=True, text=True, timeout=40)
            output = result.stdout + result.stderr
            server.close()
            self.assertIn('GREETER_USERS 1 melissa hyprland', output, output[-2000:])
            self.assertIn("GREETER_ERROR That password didn't work", output, output[-2000:])
            self.assertIn('GREETER_LAUNCHED', output, output[-2000:])
            self.assertNotIn('GREETER_TIMEOUT', output)
            starts = [m for m in log if m['type'] == 'start_session']
            self.assertEqual(starts[0]['cmd'], ['start-hyprland'])
            self.assertNotIn('right', json.dumps([m for m in log if m['type'] != 'post_auth_message_response']))


if __name__ == '__main__':
    unittest.main()
