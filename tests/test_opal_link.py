"""Two Opal Link services on loopback: discovery, pinned TLS, pairing, packets and reconnect with trust."""
import pathlib, shutil, sys, tempfile, threading, time, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import opal_link


def wait(check, timeout=8):
    end = time.time() + timeout
    while time.time() < end:
        if check(): return True
        time.sleep(.05)
    return False


@unittest.skipUnless(shutil.which('openssl'), 'openssl is required for certificates')
class OpalLinkLoopbackTest(unittest.TestCase):
    def make(self, root, name, port, reply):
        events = []
        service = opal_link.LinkService(events.append, pathlib.Path(root) / name, name=name, discovery_port=port, kde_dir=pathlib.Path(root) / 'none')
        service.reply_port = reply
        return service, events

    def test_discover_pair_exchange_and_reconnect(self):
        with tempfile.TemporaryDirectory() as root:
            a, a_events = self.make(root, 'Alpha', 27716, 27717)
            b, b_events = self.make(root, 'Beta', 27717, 27716)
            self.assertTrue(b.start(import_kde=False)); self.assertTrue(a.start(import_kde=False))
            try:
                a.announce('127.0.0.1')
                self.assertTrue(wait(lambda: a.devices.get(b.device_id) and a.devices[b.device_id].link and b.devices.get(a.device_id) and b.devices[a.device_id].link), 'no link')
                # Unpaired devices may not exchange data.
                got = []
                b.handlers['kdeconnect.ping'] = lambda device, body: got.append(body)
                self.assertFalse(a.send(b.device_id, 'kdeconnect.ping', {}))
                # Pairing: A asks, B sees a request with the same verification code, B accepts.
                self.assertTrue(a.pair(b.device_id))
                self.assertTrue(wait(lambda: b.devices[a.device_id].pair_requested))
                self.assertEqual(a.verification_key(b.device_id), b.verification_key(a.device_id))
                self.assertTrue(b.accept(a.device_id))
                self.assertTrue(wait(lambda: a.devices[b.device_id].paired and b.devices[a.device_id].paired))
                self.assertTrue(a.send(b.device_id, 'kdeconnect.ping', {'message': 'hi'}))
                self.assertTrue(wait(lambda: got == [{'message': 'hi'}]))
                a.send(b.device_id, 'kdeconnect.battery', {'currentCharge': 61, 'isCharging': True})
                self.assertTrue(wait(lambda: b.devices[a.device_id].battery == 61 and b.devices[a.device_id].charging))
                self.assertIn(b.device_id, a.load_trust())
            finally:
                a.stop(); b.stop()
            # Restart with stored trust: the link comes back with pinned certificates.
            a2, _ = self.make(root, 'Alpha', 27716, 27717)
            b2, _ = self.make(root, 'Beta', 27717, 27716)
            self.assertTrue(b2.start(import_kde=False)); self.assertTrue(a2.start(import_kde=False))
            try:
                self.assertTrue(b2.devices[a2.device_id].paired)
                a2.announce('127.0.0.1'); b2.announce('127.0.0.1')
                self.assertTrue(wait(lambda: a2.devices[b2.device_id].link is not None), 'trusted reconnect failed')
                self.assertTrue(a2.send(b2.device_id, 'kdeconnect.ping', {}))
            finally:
                a2.stop(); b2.stop()

    def test_unpair_removes_trust(self):
        with tempfile.TemporaryDirectory() as root:
            a, _ = self.make(root, 'Alpha', 27718, 27719)
            b, _ = self.make(root, 'Beta', 27719, 27718)
            b.start(import_kde=False); a.start(import_kde=False)
            try:
                a.announce('127.0.0.1')
                self.assertTrue(wait(lambda: a.devices.get(b.device_id) and a.devices[b.device_id].link and b.devices.get(a.device_id) and b.devices[a.device_id].link))
                a.pair(b.device_id); wait(lambda: b.devices[a.device_id].pair_requested); b.accept(a.device_id)
                self.assertTrue(wait(lambda: b.devices[a.device_id].paired))
                a.unpair(b.device_id)
                self.assertTrue(wait(lambda: not b.devices[a.device_id].paired))
                self.assertNotIn(a.device_id, b.load_trust())
            finally:
                a.stop(); b.stop()

    def test_certificate_cn_and_kde_import(self):
        with tempfile.TemporaryDirectory() as root:
            root = pathlib.Path(root)
            source, _ = self.make(root, 'Source', 27720, 27720)
            source.ensure_identity(import_kde=False)
            kde = root / 'kde'; kde.mkdir()
            shutil.copy(source.cert_path, kde / 'certificate.pem'); shutil.copy(source.key_path, kde / 'privateKey.pem')
            pem = source.cert_path.read_text().replace('\n', '\\n')
            (kde / 'trusted_devices').write_text('[%s]\ncertificate=%s\nname=OnePlus 7\ntype=phone\n' % ('a' * 32, pem))
            imported = opal_link.LinkService(lambda e: None, root / 'opal', kde_dir=kde)
            imported.ensure_identity(import_kde=True)
            self.assertEqual(imported.device_id, source.device_id)
            self.assertEqual(imported.trusted['a' * 32]['name'], 'OnePlus 7')
            self.assertEqual((kde / 'trusted_devices').read_text().count('OnePlus'), 1)


if __name__ == '__main__':
    unittest.main()
