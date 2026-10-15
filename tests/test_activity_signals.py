import os, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import activity_signals


class ActivitySignalTests(unittest.TestCase):
    def test_pacman_log_counts_steps_after_the_last_start(self):
        log = '\n'.join([
            '[2026-10-15T10:00:00] [ALPM] transaction started',
            '[2026-10-15T10:00:01] [ALPM] upgraded old (1 -> 2)',
            '[2026-10-15T10:00:02] [ALPM] transaction completed',
            '[2026-10-15T11:00:00] [PACMAN] Running \'pacman -Syu\'',
            '[2026-10-15T11:00:05] [ALPM] transaction started',
            '[2026-10-15T11:00:06] [ALPM] upgraded mesa (1 -> 2)',
            '[2026-10-15T11:00:07] [ALPM] installed qt6-base (6.10)',
        ])
        self.assertEqual(activity_signals.parse_pacman_log(log), (2, 'qt6-base'))
        self.assertEqual(activity_signals.parse_pacman_log(''), (0, ''))

    def test_pacman_state_needs_the_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock, log = pathlib.Path(tmp, 'db.lck'), pathlib.Path(tmp, 'pacman.log')
            log.write_text('[x] [ALPM] transaction started\n[x] [ALPM] upgraded linux (1 -> 2)\n')
            self.assertEqual(activity_signals.pacman_state(lock, log), {})
            lock.write_text('')
            state = activity_signals.pacman_state(lock, log)
            self.assertTrue(state['running'])
            self.assertEqual((state['done'], state['current']), (1, 'linux'))
            log.unlink()
            self.assertEqual(activity_signals.pacman_state(lock, log)['done'], 0)

    def test_camera_users_reads_fd_links_and_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = pathlib.Path(tmp)
            for pid, target, name in (('10', '/dev/video0', 'firefox'), ('11', '/dev/null', 'kitty')):
                fd = proc / pid / 'fd'
                fd.mkdir(parents=True)
                os.symlink(target, fd / '3')
                (proc / pid / 'comm').write_text(name + '\n')
            activity_signals._camera_cache['at'] = -1e9
            self.assertEqual(activity_signals.camera_users(proc, now=0.0), ['firefox'])
            (proc / '10' / 'fd' / '3').unlink()
            self.assertEqual(activity_signals.camera_users(proc, now=1.0), ['firefox'])
            self.assertEqual(activity_signals.camera_users(proc, now=100.0), [])


if __name__ == '__main__':
    unittest.main()
