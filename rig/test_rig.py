"""Tests for the lunaOS rig. They run without QEMU, swtpm, OVMF, hostapd or FreeRADIUS."""

import importlib.util
import itertools
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True  # Keep __pycache__ out of the repository.

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rig  # noqa: E402

DEVICES = HERE / "devices"
CONF = DEVICES / "conf"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


uinput = load_module("luna_uinput", DEVICES / "luna_uinput.py")


class MatrixTests(unittest.TestCase):
    def setUp(self):
        self.matrix = rig.load_matrix()

    def test_every_axis_has_values(self):
        for axis in rig.AXES:
            self.assertTrue(self.matrix[axis], axis)

    def test_smoke_is_small(self):
        chosen, _, _ = rig.expand(self.matrix, "smoke")
        self.assertGreater(len(chosen), 0)
        self.assertLessEqual(len(chosen), 16)

    def test_nightly_is_far_below_full_product(self):
        chosen, valid, raw = rig.expand(self.matrix, "nightly")
        self.assertLessEqual(len(chosen), 80)
        self.assertLess(len(chosen), raw // 10)
        self.assertLessEqual(len(chosen), valid)

    def test_no_planned_vm_breaks_an_exclusion(self):
        for name in self.matrix["profiles"]:
            chosen, _, _ = rig.expand(self.matrix, name)
            for combo in chosen:
                self.assertIsNone(rig.exclusion(self.matrix, combo), rig.vm_id(combo))

    def test_pairwise_covers_every_valid_pair(self):
        profile = self.matrix["profiles"]["nightly"]
        valid = list(rig.valid_combos(self.matrix, profile))
        needed = set().union(*(rig.pair_set(c) for c in valid))
        chosen, _, _ = rig.expand(self.matrix, "nightly")
        covered = set().union(*(rig.pair_set(c) for c in chosen))
        self.assertEqual(needed - covered, set())

    def test_smoke_covers_every_firmware_and_disk(self):
        chosen, _, _ = rig.expand(self.matrix, "smoke")
        self.assertEqual({c["firmware"] for c in chosen}, set(self.matrix["firmware"]))
        self.assertEqual({c["disk"] for c in chosen}, set(self.matrix["disk"]))

    def test_vm_ids_are_unique_and_round_trip(self):
        for name in self.matrix["profiles"]:
            chosen, _, _ = rig.expand(self.matrix, name)
            ids = [rig.vm_id(c) for c in chosen]
            self.assertEqual(len(ids), len(set(ids)))
            for vm, combo in zip(ids, chosen):
                self.assertEqual(rig.parse_vm(self.matrix, vm), combo)

    def test_full_cover_stops_at_max_vms(self):
        matrix = {**self.matrix, "profiles": {"big": {"cover": "full", "max_vms": 5}}}
        with self.assertRaises(rig.RigError):
            rig.expand(matrix, "big")

    def test_parse_vm_rejects_excluded_and_unknown(self):
        with self.assertRaises(rig.RigError):
            rig.parse_vm(self.matrix, "opal-iso.bios.none.nvme.virtio-gpu.one-1080p.std")
        with self.assertRaises(rig.RigError):
            rig.parse_vm(self.matrix, "nope.uefi.none.nvme.virtio-gpu.one-1080p.std")
        with self.assertRaises(rig.RigError):
            rig.parse_vm(self.matrix, "opal-iso.uefi")

    def test_bad_matrix_is_rejected(self):
        bad = {**self.matrix, "exclude": [{"when": {"firmware": "nope"}, "reason": "x"}]}
        with self.assertRaises(rig.RigError):
            rig.check_matrix(bad)


class QemuArgvTests(unittest.TestCase):
    def setUp(self):
        self.matrix = rig.load_matrix()
        self.root = Path("/nonexistent-rig-root")

    def argv(self, vm, port=2222):
        combo = rig.parse_vm(self.matrix, vm)
        paths = rig.vm_paths(self.root, vm)
        return rig.qemu_argv(self.matrix, combo, vm, paths, port), paths

    def test_uefi_nvme_virtio_gpu_one_head(self):
        argv, paths = self.argv("ubuntu.uefi.none.nvme.virtio-gpu.one-1080p.std")
        self.assertEqual(argv[0], "qemu-system-x86_64")
        self.assertIn("q35,accel=kvm", argv)
        self.assertIn("-cpu", argv)
        self.assertEqual(argv[argv.index("-smp") + 1], "4")
        self.assertEqual(argv[argv.index("-m") + 1], "4096M")
        self.assertIn("if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd", argv)
        self.assertIn("nvme,drive=sys,serial=luna-sys", argv)
        self.assertIn("virtio-vga,max_outputs=1,xres=1920,yres=1080", argv)
        self.assertIn("-vga", argv)
        self.assertEqual(argv[argv.index("-vga") + 1], "none")
        self.assertNotIn("-tpmdev", argv)
        self.assertNotIn("smm=on", " ".join(argv))

    def test_bios_has_no_pflash_and_no_nvme(self):
        argv, _ = self.argv("ubuntu.bios.none.sata.virtio-gpu.one-1080p.std")
        self.assertFalse(any("pflash" in a for a in argv))
        self.assertIn("ahci,id=ahci0", argv)
        self.assertIn("ide-hd,drive=sys,bus=ahci0.0", argv)

    def test_secure_boot_sets_smm_and_secure_vars(self):
        argv, _ = self.argv("ubuntu.uefi-sb.swtpm2.nvme.std-vga.one-1080p.std")
        self.assertIn("q35,accel=kvm,smm=on", argv)
        self.assertIn("driver=cfi.pflash01,property=secure,value=on", argv)
        self.assertIn("file=/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd", " ".join(argv))

    def test_swtpm_wiring_present_only_when_enabled(self):
        argv, paths = self.argv("ubuntu.uefi.swtpm2.virtio.virtio-gpu.one-1080p.std")
        self.assertIn("tpm-tis,tpmdev=tpm0", argv)
        self.assertIn("emulator,id=tpm0,chardev=chrtpm", argv)
        self.assertIn(f"socket,id=chrtpm,path={paths['swtpm_sock']}", argv)

    def test_std_vga_one_head_uses_std_vga(self):
        argv, _ = self.argv("ubuntu.uefi.none.virtio.std-vga.one-1080p.std")
        self.assertEqual(argv[argv.index("-vga") + 1], "std")
        self.assertFalse(any(a.startswith("virtio-vga") for a in argv))

    def test_gl_gpu_uses_egl_headless_and_two_heads(self):
        argv, _ = self.argv("ubuntu.uefi.none.sata.virtio-gpu-gl.two-mixed.std")
        self.assertIn("virtio-vga-gl,max_outputs=2,xres=1920,yres=1080", argv)
        self.assertEqual(argv[argv.index("-display") + 1], "egl-headless")

    def test_iso_guest_attaches_image_as_cdrom(self):
        argv, paths = self.argv("opal-iso.uefi.none.nvme.virtio-gpu.one-1080p.std")
        self.assertIn(f"file={paths['images'] / 'opal.iso'},media=cdrom,readonly=on", argv)

    def test_hostfwd_and_control_sockets(self):
        argv, paths = self.argv("ubuntu.uefi.none.nvme.virtio-gpu.one-1080p.std", port=2345)
        self.assertIn("user,id=net0,hostfwd=tcp:127.0.0.1:2345-:22", argv)
        self.assertIn(f"unix:{paths['qmp']},server=on,wait=off", argv)
        self.assertIn(f"unix:{paths['serial']},server=on,wait=off", argv)
        self.assertIn("pcie-root-port,id=rp-hot,bus=pcie.0,chassis=1,slot=1,hotplug=on", argv)

    def test_argv_items_are_strings(self):
        argv, _ = self.argv("debian.uefi-sb.swtpm2.virtio.virtio-gpu-gl.two-same.large")
        self.assertTrue(all(isinstance(a, str) for a in argv))

    def test_socket_paths_stay_under_unix_limit(self):
        long_root = Path("/home/" + "x" * 40 + "/.cache/luna-rig")
        paths = rig.vm_paths(long_root, "opal-iso.uefi-sb.swtpm2.nvme.virtio-gpu-gl.two-mixed.std")
        for key in ("qmp", "serial", "swtpm_sock"):
            self.assertLess(len(str(paths[key]).encode()), 108, key)

    def test_run_refuses_socket_paths_over_the_limit(self):
        with self.assertRaises(rig.RigError):
            rig.cmd_run(mock.Mock(vm="opal-iso.uefi.none.nvme.virtio-gpu.one-1080p.std", dry_run=True),
                        self.matrix, Path("/" + "y" * 90))

    def test_ssh_port_is_in_range_and_stable(self):
        vm = "debian.uefi.none.virtio.virtio-gpu.one-1080p.std"
        port = rig.ssh_port(self.matrix, vm)
        host = self.matrix["host"]
        self.assertGreaterEqual(port, host["ssh_port_base"])
        self.assertLess(port, host["ssh_port_base"] + host["ssh_port_span"])
        self.assertEqual(port, rig.ssh_port(self.matrix, vm))

    def test_qopt_doubles_commas(self):
        self.assertEqual(rig.qopt("a,b"), "a,,b")


class SeedTests(unittest.TestCase):
    def test_cloud_seed_has_user_and_key(self):
        files = rig.seed_files("qcow2", "abc123", "ssh-ed25519 AAAA rig@test")
        self.assertIn("ssh_authorized_keys:", files["user-data"])
        self.assertIn("ssh-ed25519 AAAA rig@test", files["user-data"])
        self.assertEqual(rig.seed_label("qcow2"), "cidata")

    def test_iso_seed_uses_luna_label(self):
        files = rig.seed_files("iso", "abc123", "ssh-ed25519 AAAA rig@test")
        self.assertEqual(files["authorized_keys"].strip(), "ssh-ed25519 AAAA rig@test")
        self.assertEqual(rig.seed_label("iso"), "LUNARIG")


class RootGuardTests(unittest.TestCase):
    def test_require_user_refuses_root(self):
        with mock.patch.object(rig.os, "geteuid", return_value=0):
            with self.assertRaises(rig.RigError):
                rig.require_user()


class CliDryRunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="rig-test-")
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.state = Path(self.tmp) / "state"
        self.vm = "ubuntu.uefi.none.nvme.virtio-gpu.one-1080p.std"

    def run_rig(self, *args):
        return subprocess.run(
            [sys.executable, "-I", str(HERE / "rig.py"), "--state-dir", str(self.state), *args],
            capture_output=True, text=True, timeout=120,
        )

    def test_run_dry_run_prints_qemu_and_writes_nothing(self):
        result = self.run_rig("run", self.vm, "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        qemu_lines = [line for line in result.stdout.splitlines() if line.startswith("qemu-system-x86_64 ")]
        self.assertEqual(len(qemu_lines), 1)
        self.assertIn("-qmp unix:", qemu_lines[0])
        self.assertFalse(self.state.exists())

    def test_plan_smoke_lists_vms(self):
        result = self.run_rig("plan", "smoke")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("profile smoke: 11 VMs", result.stdout)

    def test_hotplug_dry_run_emits_device_add(self):
        result = self.run_rig("hotplug", self.vm, "add", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"execute": "device_add"', result.stdout)
        self.assertIn('"bus": "rp-hot"', result.stdout)

    def test_soak_dry_run_writes_nothing(self):
        result = self.run_rig("hotplug-soak", self.vm, "--cycles", "1000", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("998 more cycles", result.stdout)
        self.assertFalse(self.state.exists())

    def test_ssh_dry_run_keeps_guest_command_after_separator(self):
        result = self.run_rig("ssh", self.vm, "--dry-run", "--", "luna-test", "windows", "count")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("'luna-test windows count'", result.stdout)

    def test_unknown_profile_fails(self):
        result = self.run_rig("plan", "nope")
        self.assertNotEqual(result.returncode, 0)

    def test_run_refuses_excluded_vm(self):
        result = self.run_rig("run", "opal-iso.bios.none.nvme.virtio-gpu.one-1080p.std", "--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("excluded", result.stderr)


class DeviceScriptTests(unittest.TestCase):
    def script(self, name):
        return str(DEVICES / name)

    def test_shell_syntax(self):
        for path in sorted(DEVICES.glob("*.sh")):
            result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, f"{path.name}: {result.stderr}")

    def test_up_refuses_without_root(self):
        if os.geteuid() == 0:
            self.skipTest("run as a normal user")
        for name in ("wifi-hwsim.sh", "bt-virt.sh", "printer.sh", "media.sh", "input.sh"):
            with tempfile.TemporaryDirectory() as run_dir:
                result = subprocess.run(["bash", self.script(name), "up"], capture_output=True, text=True,
                                        env={**os.environ, "RIG_RUN_DIR": run_dir})
                self.assertNotEqual(result.returncode, 0, name)
                self.assertIn("needs root", result.stderr, name)

    def test_dry_run_up_and_down_change_nothing(self):
        for name in ("wifi-hwsim.sh", "bt-virt.sh", "printer.sh", "media.sh", "input.sh"):
            with tempfile.TemporaryDirectory() as run_dir:
                for cmd in ("up", "down"):
                    result = subprocess.run(["bash", self.script(name), cmd, "--dry-run"],
                                            capture_output=True, text=True,
                                            env={**os.environ, "RIG_RUN_DIR": run_dir})
                    self.assertEqual(result.returncode, 0, f"{name} {cmd}: {result.stderr}")
                self.assertEqual(os.listdir(run_dir), [], name)

    def test_wifi_dry_up_shows_radio_load_and_hostapd(self):
        with tempfile.TemporaryDirectory() as run_dir:
            result = subprocess.run(["bash", self.script("wifi-hwsim.sh"), "up", "--dry-run"],
                                    capture_output=True, text=True,
                                    env={**os.environ, "RIG_RUN_DIR": run_dir})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("modprobe mac80211_hwsim radios=4", result.stdout)
        self.assertIn("hostapd -B", result.stdout)
        self.assertIn("radiusd -d", result.stdout)

    def test_status_needs_no_root(self):
        with tempfile.TemporaryDirectory() as run_dir:
            result = subprocess.run(["bash", self.script("printer.sh"), "status"], capture_output=True,
                                    text=True, env={**os.environ, "RIG_RUN_DIR": run_dir})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ippeveprinter: stopped", result.stdout)

    @unittest.skipUnless(shutil.which("openssl"), "needs openssl")
    def test_wifi_check_renders_and_validates_configs(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(["bash", self.script("wifi-hwsim.sh"), "check"], capture_output=True,
                                    text=True, env={**os.environ, "TMPDIR": tmp, "RIG_RUN_DIR": tmp})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("configs OK", result.stdout)


class HostapdAndRadiusTests(unittest.TestCase):
    @staticmethod
    def parse_conf(path):
        values = {}
        for line in Path(path).read_text().splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            key, _, value = line.partition("=")
            values[key] = value
        return values

    def test_psk_ssid_and_passphrase_limits(self):
        conf = self.parse_conf(CONF / "hostapd-psk.conf")
        self.assertEqual(conf["wpa_key_mgmt"], "WPA-PSK")
        self.assertLessEqual(len(conf["ssid"].encode()), 32)
        self.assertTrue(8 <= len(conf["wpa_passphrase"]) <= 63)

    def test_hidden_ssid_is_hidden(self):
        conf = self.parse_conf(CONF / "hostapd-hidden.conf")
        self.assertEqual(conf["ignore_broadcast_ssid"], "1")
        self.assertLessEqual(len(conf["ssid"].encode()), 32)
        self.assertTrue(8 <= len(conf["wpa_passphrase"]) <= 63)

    def test_enterprise_points_at_radius_with_matching_secret(self):
        conf = self.parse_conf(CONF / "hostapd-enterprise.conf")
        radius = (CONF / "radius" / "radiusd.conf").read_text()
        self.assertEqual(conf["wpa_key_mgmt"], "WPA-EAP")
        self.assertEqual(conf["ieee8021x"], "1")
        self.assertEqual(conf["auth_server_port"], "11812")
        self.assertIn("port = 11812", radius)
        secret = conf["auth_server_shared_secret"]
        self.assertIn(f"secret = {secret}", radius)
        self.assertLessEqual(len(conf["ssid"].encode()), 32)

    def test_radius_references_generated_certs_and_users(self):
        radius = (CONF / "radius" / "radiusd.conf").read_text()
        self.assertIn("${confdir}/certs/server.pem", radius)
        self.assertIn("${confdir}/certs/server.key", radius)
        self.assertIn("${confdir}/users", radius)
        self.assertIn("default_eap_type = mschapv2", radius)

    def test_test_user_matches_connectivity_limits(self):
        users = (CONF / "radius" / "users").read_text()
        match = re.search(r'^(\S+)\s+Cleartext-Password := "([^"]+)"', users, re.M)
        self.assertIsNotNone(match)
        identity, password = match.groups()
        # connectivity.py: identity 1..256 bytes, password up to 256 bytes.
        self.assertTrue(0 < len(identity.encode()) <= 256)
        self.assertLessEqual(len(password.encode()), 256)
        self.assertEqual(identity, "rig.user")


class UinputTests(unittest.TestCase):
    @staticmethod
    def iow(kind, number, size):
        return (1 << 30) | (size << 16) | (ord(kind) << 8) | number

    def test_struct_sizes_match_kernel_headers(self):
        self.assertEqual(len(uinput.setup_struct("Luna", 1)), 92)
        self.assertEqual(len(uinput.abs_struct(0, 0, 10)), 28)

    def test_ioctl_numbers_match_macros(self):
        self.assertEqual(uinput.UI_SET_EVBIT, self.iow("U", 100, 4))
        self.assertEqual(uinput.UI_SET_KEYBIT, self.iow("U", 101, 4))
        self.assertEqual(uinput.UI_SET_ABSBIT, self.iow("U", 103, 4))
        self.assertEqual(uinput.UI_DEV_SETUP, self.iow("U", 3, 92))
        self.assertEqual(uinput.UI_ABS_SETUP, self.iow("U", 4, 28))
        self.assertEqual(uinput.UI_DEV_CREATE, (0 << 30) | (0 << 16) | (ord("U") << 8) | 1)

    def test_every_kind_has_a_plan(self):
        for kind in uinput.KINDS:
            steps = uinput.describe(kind, "Luna Rig", 1)
            self.assertEqual(steps[-1][0], "UI_DEV_CREATE")
            self.assertEqual(steps[0], ("UI_SET_EVBIT", uinput.EV_KEY))

    def test_describe_cli_prints_steps(self):
        result = subprocess.run([sys.executable, "-I", str(DEVICES / "luna_uinput.py"), "describe",
                                 "--kind", "pen"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("UI_DEV_CREATE", result.stdout)


if __name__ == "__main__":
    unittest.main()
