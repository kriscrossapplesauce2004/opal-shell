#!/usr/bin/env python3
"""Plan, boot and drive the lunaOS QEMU/KVM test matrix (moonshot section 26)."""

import argparse
import hashlib
import itertools
import json
import os
import select
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import time
import tomllib
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Axis order sets the VM id format: guest.firmware.tpm.disk.gpu.outputs.resources.
AXES = ("guest", "firmware", "tpm", "disk", "gpu", "outputs", "resources")
SSH_USER = "rig"
HOTPLUG_PREFIX = "hpgpu"
INSTALL_LINE = (
    "sudo pacman -S --needed qemu-desktop swtpm edk2-ovmf xorriso openssh openssl "
    "hostapd freeradius iw bluez bluez-utils cups sane v4l-utils v4l2loopback-dkms shellcheck"
)


class RigError(Exception):
    """A user-facing error. Printed without a traceback."""


def fail(message):
    raise RigError(message)


# Matrix ---------------------------------------------------------------------

def load_matrix(path=None):
    path = Path(path) if path else HERE / "matrix.toml"
    try:
        with path.open("rb") as handle:
            matrix = tomllib.load(handle)
    except OSError as error:
        fail(f"cannot read {path}: {error}")
    check_matrix(matrix)
    return matrix


def check_matrix(matrix):
    for axis in AXES:
        table = matrix.get(axis)
        if not isinstance(table, dict) or not table:
            fail(f"matrix.toml: table [{axis}] needs at least one value")
        for value in table:
            if "." in value:
                fail(f"matrix.toml: [{axis}.{value}] must not contain a dot")
    for rule in matrix.get("exclude", []):
        when = rule.get("when")
        if not when:
            fail("matrix.toml: every [[exclude]] needs a non-empty when table")
        for key, value in when.items():
            if key not in AXES or value not in matrix[key]:
                fail(f"matrix.toml: exclude rule has unknown {key} = {value!r}")
    for name, profile in matrix.get("profiles", {}).items():
        for axis in AXES:
            for value in profile.get(axis, []):
                if value not in matrix[axis]:
                    fail(f"matrix.toml: profile {name} has unknown {axis} = {value!r}")
        if profile.get("cover", "pairwise") not in ("pairwise", "full"):
            fail(f"matrix.toml: profile {name} cover must be pairwise or full")


def vm_id(combo):
    return ".".join(combo[axis] for axis in AXES)


def exclusion(matrix, combo):
    """Return the reason a combination is excluded, or None."""
    for rule in matrix.get("exclude", []):
        if all(combo[key] == value for key, value in rule["when"].items()):
            return rule.get("reason", "excluded by matrix.toml")
    return None


def allowed_values(matrix, profile, axis):
    keep = profile.get(axis)
    return [v for v in matrix[axis] if keep is None or v in keep]


def valid_combos(matrix, profile):
    axes = [allowed_values(matrix, profile, axis) for axis in AXES]
    for values in itertools.product(*axes):
        combo = dict(zip(AXES, values))
        if exclusion(matrix, combo) is None:
            yield combo


def pair_set(combo):
    return set(itertools.combinations([(axis, combo[axis]) for axis in AXES], 2))


def pairwise(combos):
    """Greedy pairwise cover. Deterministic: ties keep the earliest combination."""
    per_combo = [pair_set(combo) for combo in combos]
    uncovered = set().union(*per_combo) if per_combo else set()
    chosen, free = [], list(range(len(combos)))
    while uncovered:
        best, best_gain = None, 0
        for index in free:
            gain = len(per_combo[index] & uncovered)
            if gain > best_gain:
                best, best_gain = index, gain
        chosen.append(combos[best])
        uncovered -= per_combo[best]
        free.remove(best)
    return chosen


def expand(matrix, name):
    """Return (chosen VMs, valid combinations, raw product size) for a profile."""
    profile = matrix.get("profiles", {}).get(name)
    if profile is None:
        fail(f"no profile named {name!r}; run: rig.py list")
    combos = list(valid_combos(matrix, profile))
    raw = 1
    for axis in AXES:
        raw *= len(allowed_values(matrix, profile, axis))
    if profile.get("cover", "pairwise") == "pairwise":
        chosen = pairwise(combos)
    else:
        chosen = combos
    limit = profile.get("max_vms", 50)
    if len(chosen) > limit:
        fail(f"profile {name}: {len(chosen)} VMs is over max_vms = {limit}")
    chosen.sort(key=vm_id)
    return chosen, len(combos), raw


def parse_vm(matrix, vm):
    parts = vm.split(".")
    if len(parts) != len(AXES):
        fail(f"VM id needs {len(AXES)} dot-separated values: {'.'.join(AXES)}")
    combo = dict(zip(AXES, parts))
    for axis, value in combo.items():
        if value not in matrix[axis]:
            fail(f"unknown {axis} value {value!r}")
    reason = exclusion(matrix, combo)
    if reason:
        fail(f"{vm} is excluded: {reason}")
    return combo


# Paths and ports -----------------------------------------------------------

def state_root(args):
    if args.state_dir:
        return Path(args.state_dir)
    if os.environ.get("LUNA_RIG_STATE"):
        return Path(os.environ["LUNA_RIG_STATE"])
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "luna-rig"


def vm_paths(root, vm):
    """Return the file layout for one VM. Pure: touches no files."""
    key = hashlib.sha256(vm.encode()).hexdigest()[:12]  # short key keeps unix socket paths under 108 bytes
    d = root / "vms" / key
    return {
        "key": key,
        "dir": d,
        "overlay": d / "disk.qcow2",
        "vars": d / "OVMF_VARS.fd",
        "seed": d / "seed.iso",
        "seed_src": d / "seed",
        "tpm": d / "tpm",
        "swtpm_sock": d / "tpm" / "swtpm-sock",
        "swtpm_pid": d / "tpm" / "swtpm.pid",
        "qmp": d / "qmp.sock",
        "serial": d / "serial.sock",
        "pidfile": d / "qemu.pid",
        "log": d / "qemu.log",
        "state": d / "state.json",
        "soak": d / "soak.json",
        "ssh_key": root / "ssh" / "id_ed25519",
        "images": root / "images",
    }


def ssh_port(matrix, vm):
    host = matrix["host"]
    return host["ssh_port_base"] + zlib.crc32(vm.encode()) % host["ssh_port_span"]


def port_free(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        try:
            probe.bind(("127.0.0.1", port))
        except OSError:
            return False
    return True


def qopt(value):
    """Escape a path for a QEMU option string (commas are doubled)."""
    return str(value).replace(",", ",,")


# QEMU command line ----------------------------------------------------------

def disk_args(bus, image):
    drive = ["-drive", f"if=none,id=sys,file={qopt(image)},format=qcow2"]
    if bus == "nvme":
        return drive + ["-device", "nvme,drive=sys,serial=luna-sys"]
    if bus == "ahci":
        return ["-device", "ahci,id=ahci0"] + drive + ["-device", "ide-hd,drive=sys,bus=ahci0.0"]
    if bus == "virtio":
        return drive + ["-device", "virtio-blk-pci,drive=sys"]
    fail(f"unknown disk bus {bus!r}")


def qemu_argv(matrix, combo, vm, paths, port):
    """Build the qemu-system-x86_64 argument list. Pure: touches no files."""
    host = matrix["host"]
    firmware = matrix["firmware"][combo["firmware"]]
    tpm = matrix["tpm"][combo["tpm"]]
    disk = matrix["disk"][combo["disk"]]
    gpu = matrix["gpu"][combo["gpu"]]
    guest = matrix["guest"][combo["guest"]]
    heads = matrix["outputs"][combo["outputs"]]["heads"]
    res = matrix["resources"][combo["resources"]]
    width, height = (int(n) for n in heads[0]["size"].split("x"))
    secure = firmware["secure_boot"]

    machine = "q35,accel=kvm" + (",smm=on" if secure else "")
    argv = [
        host["qemu"], "-name", f"luna-rig-{paths['key']}",
        "-machine", machine, "-cpu", "host",
        "-smp", str(res["cpus"]), "-m", f"{res['ram_mb']}M",
    ]
    if firmware["kind"] == "uefi":
        code = host["ovmf_secboot_code"] if secure else host["ovmf_code"]
        argv += [
            "-drive", f"if=pflash,format=raw,unit=0,readonly=on,file={qopt(code)}",
            "-drive", f"if=pflash,format=raw,unit=1,file={qopt(paths['vars'])}",
        ]
    if secure:
        argv += ["-global", "driver=cfi.pflash01,property=secure,value=on"]
    if tpm["enabled"]:
        argv += [
            "-chardev", f"socket,id=chrtpm,path={qopt(paths['swtpm_sock'])}",
            "-tpmdev", "emulator,id=tpm0,chardev=chrtpm",
            "-device", "tpm-tis,tpmdev=tpm0",
        ]
    argv += disk_args(disk["bus"], paths["overlay"])
    argv += ["-vga", gpu["vga"]]
    if gpu["device"]:
        argv += ["-device", f"{gpu['device']},max_outputs={len(heads)},xres={width},yres={height}"]
    argv += ["-display", gpu["display"]]
    if guest["kind"] == "iso":
        argv += ["-drive", f"file={qopt(paths['images'] / guest['file'])},media=cdrom,readonly=on"]
    argv += ["-drive", f"file={qopt(paths['seed'])},media=cdrom,readonly=on"]
    argv += [
        "-netdev", f"user,id=net0,hostfwd=tcp:127.0.0.1:{port}-:22",
        "-device", "virtio-net-pci,netdev=net0",
        # Hotplug root port for virtual monitors. See cmd_hotplug.
        "-device", f"pcie-root-port,id={matrix['hotplug']['root_port']},bus=pcie.0,chassis=1,slot=1,hotplug=on",
        "-qmp", f"unix:{qopt(paths['qmp'])},server=on,wait=off",
        "-serial", f"unix:{qopt(paths['serial'])},server=on,wait=off",
        "-pidfile", qopt(paths["pidfile"]),
    ]
    return argv


def seed_files(guest_kind, key, pubkey):
    """Return the seed ISO files for a guest. The ISO label differs by kind."""
    if guest_kind == "iso":
        return {
            "authorized_keys": pubkey + "\n",
            "README.txt": "lunaOS rig seed. Start sshd and accept authorized_keys for user rig.\n",
        }
    user_data = (
        "#cloud-config\n"
        f"hostname: luna-rig-{key}\n"
        "users:\n"
        f"  - name: {SSH_USER}\n"
        "    sudo: ALL=(ALL) NOPASSWD:ALL\n"
        "    shell: /bin/bash\n"
        "    lock_passwd: true\n"
        "    ssh_authorized_keys:\n"
        f"      - {pubkey}\n"
    )
    meta_data = f"instance-id: luna-rig-{key}\nlocal-hostname: luna-rig-{key}\n"
    return {"user-data": user_data, "meta-data": meta_data}


def seed_label(guest_kind):
    return "LUNARIG" if guest_kind == "iso" else "cidata"


def pid_is(pid, needle):
    try:
        cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().decode(errors="replace")
    except OSError:
        return False
    return needle in cmdline


# Side effects ---------------------------------------------------------------

class Doer:
    """Runs steps, or prints them when dry."""

    def __init__(self, dry):
        self.dry = dry

    def mkdir(self, path):
        if self.dry:
            print(f"mkdir -p {shlex.quote(str(path))}")
        else:
            path.mkdir(parents=True, exist_ok=True)

    def write(self, path, text):
        if self.dry:
            print(f"# write {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)

    def copy(self, src, dst):
        if self.dry:
            print(f"cp {shlex.quote(str(src))} {shlex.quote(str(dst))}")
            return
        try:
            shutil.copyfile(src, dst)
        except OSError as error:
            fail(f"cannot copy {src}: {error}")

    def run(self, argv):
        if self.dry:
            print(shlex.join(argv))
            return
        try:
            subprocess.run(argv, check=True)
        except subprocess.CalledProcessError as error:
            fail(f"command failed with {error.returncode}: {shlex.join(argv)}")


class Qmp:
    """Minimal QMP client over a unix socket."""

    def __init__(self, path, timeout=10.0):
        self.timeout = timeout
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        try:
            self.sock.connect(str(path))
        except OSError as error:
            self.sock.close()
            fail(f"cannot reach QMP socket {path}: {error}")
        self.buffer = b""
        self.events = []
        self._read()  # Greeting.
        self.execute("qmp_capabilities")

    def close(self):
        self.sock.close()

    def _read(self):
        while b"\n" not in self.buffer:
            chunk = self.sock.recv(65536)
            if not chunk:
                fail("QMP socket closed")
            self.buffer += chunk
        line, _, self.buffer = self.buffer.partition(b"\n")
        return json.loads(line)

    def execute(self, command, **arguments):
        message = {"execute": command}
        if arguments:
            message["arguments"] = arguments
        self.sock.settimeout(self.timeout)
        self.sock.sendall(json.dumps(message).encode() + b"\n")
        while True:
            reply = self._read()
            if "event" in reply:
                self.events.append(reply)
                continue
            if "error" in reply:
                fail(f"QMP {command} failed: {reply['error'].get('desc', reply['error'])}")
            return reply.get("return", {})

    def wait_event(self, name, timeout, match=lambda event: True):
        for event in self.events:
            if event["event"] == name and match(event):
                self.events.remove(event)
                return event
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            self.sock.settimeout(remaining)
            try:
                reply = self._read()
            except socket.timeout:
                return None
            if reply.get("event") == name and match(reply):
                return reply
            if "event" in reply:
                self.events.append(reply)


def load_state(paths, vm):
    if not paths["state"].exists():
        fail(f"{vm} is not running; start it with: rig.py run {vm}")
    return json.loads(paths["state"].read_text())


def is_running(state):
    return pid_is(state["pid"], "qemu-system")


def require_user():
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        fail("run rig.py as your own user, not as root")


def check_tools(matrix, combo, dry):
    host = matrix["host"]
    names = [host["qemu"], host["qemu_img"], host["ssh"], host["ssh_keygen"], host["scp"], host["xorriso"]]
    if matrix["tpm"][combo["tpm"]]["enabled"]:
        names.append(host["swtpm"])
    missing = [name for name in names if shutil.which(name) is None]
    if missing and not dry:
        fail(f"missing: {', '.join(missing)}. Install with: {INSTALL_LINE}")
    if missing:
        print(f"# note: missing on this machine: {', '.join(missing)}")


def wait_for_path(path, proc, timeout):
    deadline = time.monotonic() + timeout
    while not path.exists():
        if proc.poll() is not None:
            fail(f"qemu exited early with {proc.returncode}; see the log for this VM")
        if time.monotonic() > deadline:
            fail(f"timed out waiting for {path}")
        time.sleep(0.2)


# Commands -------------------------------------------------------------------

def cmd_list(args, matrix, root):
    for axis in AXES:
        print(f"{axis}: {', '.join(matrix[axis])}")
    print()
    for name in matrix.get("profiles", {}):
        chosen, valid, raw = expand(matrix, name)
        desc = matrix["profiles"][name].get("description", "")
        print(f"{name}: {len(chosen)} VMs (valid {valid} of raw {raw}). {desc}")
    return 0


def cmd_plan(args, matrix, root):
    chosen, valid, raw = expand(matrix, args.profile)
    if args.json:
        print(json.dumps([{"vm": vm_id(c), **c} for c in chosen], indent=2))
        return 0
    print(f"profile {args.profile}: {len(chosen)} VMs (valid {valid} of raw {raw})")
    for combo in chosen:
        print(vm_id(combo))
    return 0


def cmd_run(args, matrix, root):
    vm, dry = args.vm, args.dry_run
    combo = parse_vm(matrix, vm)
    host = matrix["host"]
    guest = matrix["guest"][combo["guest"]]
    firmware = matrix["firmware"][combo["firmware"]]
    tpm = matrix["tpm"][combo["tpm"]]
    paths = vm_paths(root, vm)
    port = ssh_port(matrix, vm)
    for key in ("qmp", "serial", "swtpm_sock"):
        if len(str(paths[key]).encode()) >= 108:
            fail(f"socket path is too long for unix sockets: {paths[key]}. Use a shorter LUNA_RIG_STATE.")
    if not dry:
        require_user()
        if paths["state"].exists() and is_running(json.loads(paths["state"].read_text())):
            fail(f"{vm} is already running; stop it first")
        check_tools(matrix, combo, dry=False)
        if not port_free(port):
            fail(f"ssh port {port} is busy; another VM or service uses it")
    check_tools(matrix, combo, dry=True) if dry else None

    doer = Doer(dry)
    base = paths["images"] / guest["file"]
    doer.mkdir(paths["dir"])
    if tpm["enabled"]:
        doer.mkdir(paths["tpm"])
    if not paths["ssh_key"].exists():
        doer.mkdir(paths["ssh_key"].parent)
        doer.run([host["ssh_keygen"], "-q", "-t", "ed25519", "-N", "", "-f", str(paths["ssh_key"])])

    if not paths["overlay"].exists():
        if guest["kind"] == "iso":
            doer.run([host["qemu_img"], "create", "-f", "qcow2", str(paths["overlay"]), host["disk_size"]])
        else:
            if not base.exists():
                if not dry:
                    fail(f"missing guest image: {base}")
                print(f"# missing guest image (needed before a real run): {base}")
            doer.run([host["qemu_img"], "create", "-f", "qcow2", "-F", guest["format"],
                      "-b", str(base), str(paths["overlay"])])

    if firmware["kind"] == "uefi" and not paths["vars"].exists():
        template = host["ovmf_secboot_vars"] if firmware["secure_boot"] else host["ovmf_vars"]
        doer.copy(Path(template), paths["vars"])

    pubkey_file = paths["ssh_key"].with_suffix(".pub")
    pubkey = pubkey_file.read_text().strip() if pubkey_file.exists() else "<ssh public key>"
    for name, text in seed_files(guest["kind"], paths["key"], pubkey).items():
        doer.write(paths["seed_src"] / name, text)
    doer.run([host["xorriso"], "-as", "mkisofs", "-quiet", "-V", seed_label(guest["kind"]),
              "-J", "-R", "-o", str(paths["seed"]), str(paths["seed_src"])])

    if tpm["enabled"]:
        doer.run([
            host["swtpm"], "socket", "--tpm2",
            "--tpmstate", f"dir={paths['tpm']}",
            "--ctrl", f"type=unixio,path={paths['swtpm_sock']}",
            "--log", f"file={paths['tpm']}/swtpm.log,level=20",
            "--pid", f"file={paths['swtpm_pid']}",
            "--daemon",
        ])

    argv = qemu_argv(matrix, combo, vm, paths, port)
    if dry:
        print(shlex.join(argv))
        print(f"# ssh: rig.py ssh {vm} -- <command>   (port {port})")
        return 0

    paths["dir"].mkdir(parents=True, exist_ok=True)
    with paths["log"].open("ab") as log:
        proc = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log,
                                stderr=subprocess.STDOUT, start_new_session=True)
    try:
        wait_for_path(paths["qmp"], proc, 20)
    except RigError:
        proc.kill()
        raise
    state = {
        "vm": vm,
        "key": paths["key"],
        "pid": proc.pid,
        "port": port,
        "swtpm_pid_file": str(paths["swtpm_pid"]) if tpm["enabled"] else None,
        "hotplug_seq": 0,
        "hotplugged": [],
        "started": time.time(),
        "argv": argv,
    }
    paths["state"].write_text(json.dumps(state, indent=2))
    print(f"started {vm} (pid {proc.pid}); ssh: rig.py ssh {vm} -- true")
    return 0


def cmd_status(args, matrix, root):
    if args.vm:
        state = load_state(vm_paths(root, args.vm), args.vm)
        print(json.dumps({**state, "running": is_running(state)}, indent=2))
        return 0
    vms_dir = root / "vms"
    if not vms_dir.exists():
        print("no VMs have been started")
        return 0
    for state_file in sorted(vms_dir.glob("*/state.json")):
        state = json.loads(state_file.read_text())
        print(f"{state['vm']}: {'running' if is_running(state) else 'stopped'} (port {state['port']})")
    return 0


def cmd_stop(args, matrix, root):
    paths = vm_paths(root, args.vm)
    if args.dry_run:
        print(f"# QMP quit on {paths['qmp']}")
        print("kill <qemu pid>  # only if its command line names qemu-system")
        print("kill <swtpm pid>  # only if its command line names swtpm, when TPM is enabled")
        return 0
    state = load_state(paths, args.vm)
    require_user()
    if is_running(state):
        try:
            qmp = Qmp(paths["qmp"], timeout=5)
            qmp.execute("quit")
            qmp.close()
        except RigError:
            pass
        deadline = time.monotonic() + 20
        while is_running(state) and time.monotonic() < deadline:
            time.sleep(0.5)
        if is_running(state):
            os.kill(state["pid"], signal.SIGTERM)
    pidfile = state.get("swtpm_pid_file")
    if pidfile and Path(pidfile).exists():
        swtpm_pid = int(Path(pidfile).read_text().strip())
        if pid_is(swtpm_pid, "swtpm"):
            os.kill(swtpm_pid, signal.SIGTERM)
    state["stopped"] = time.time()
    paths["state"].write_text(json.dumps(state, indent=2))
    print(f"stopped {args.vm}")
    return 0


def hotplug_device(matrix, dev_id):
    width, height = matrix["hotplug"]["size"].split("x")
    return {
        "driver": "virtio-gpu-pci",
        "id": dev_id,
        "bus": matrix["hotplug"]["root_port"],
        "max_outputs": 1,
        "xres": int(width),
        "yres": int(height),
    }


def cmd_hotplug(args, matrix, root):
    paths = vm_paths(root, args.vm)
    if args.dry_run:
        dev_id = f"{HOTPLUG_PREFIX}1"
        if args.action == "add":
            print(json.dumps({"execute": "device_add", "arguments": hotplug_device(matrix, dev_id)}))
        else:
            print(json.dumps({"execute": "device_del", "arguments": {"id": dev_id}}))
            print(json.dumps({"event": "DEVICE_DELETED", "note": "wait for this event"}))
        return 0
    require_user()
    state = load_state(paths, args.vm)
    qmp = Qmp(paths["qmp"])
    try:
        if args.action == "add":
            seq = state["hotplug_seq"] + 1
            dev_id = f"{HOTPLUG_PREFIX}{seq}"
            qmp.execute("device_add", **hotplug_device(matrix, dev_id))
            state["hotplug_seq"] = seq
            state["hotplugged"].append(dev_id)
            print(f"added virtual output {dev_id}")
        else:
            if not state["hotplugged"]:
                fail(f"{args.vm} has no hotplugged outputs to remove")
            dev_id = state["hotplugged"].pop()
            qmp.execute("device_del", id=dev_id)
            event = qmp.wait_event("DEVICE_DELETED", matrix["hotplug"]["event_timeout_seconds"],
                                   match=lambda e: e.get("data", {}).get("device") == dev_id)
            if event is None:
                fail(f"no DEVICE_DELETED event for {dev_id}")
            print(f"removed virtual output {dev_id}")
    finally:
        qmp.close()
    paths["state"].write_text(json.dumps(state, indent=2))
    return 0


def guest_window_count(matrix, paths, port):
    out = subprocess.run(ssh_argv(matrix, paths, port, [matrix["hotplug"]["window_count_cmd"]]),
                         capture_output=True, text=True, timeout=60)
    if out.returncode != 0 or not out.stdout.strip().isdigit():
        raise RigError(f"window count failed: {out.stderr.strip() or out.stdout.strip()}")
    return int(out.stdout.strip())


def cmd_hotplug_soak(args, matrix, root):
    paths = vm_paths(root, args.vm)
    settle = matrix["hotplug"]["settle_seconds"]
    timeout = matrix["hotplug"]["event_timeout_seconds"]
    if args.dry_run:
        for cycle in range(1, min(args.cycles, 2) + 1):
            dev = f"{HOTPLUG_PREFIX}{cycle}"
            print(f"# cycle {cycle}: count windows, sleep {settle}s")
            print(json.dumps({"execute": "device_add", "arguments": hotplug_device(matrix, dev)}))
            print(f"# sleep {settle}s, then count windows")
            print(json.dumps({"execute": "device_del", "arguments": {"id": dev}}))
            print(f"# wait for DEVICE_DELETED ({timeout}s), sleep {settle}s, count windows")
        if args.cycles > 2:
            print(f"# ... {args.cycles - 2} more cycles, same steps")
        print(f"# summary written to {paths['soak']}")
        return 0
    require_user()
    state = load_state(paths, args.vm)
    lost, errors = 0, []
    qmp = Qmp(paths["qmp"])
    try:
        for cycle in range(1, args.cycles + 1):
            dev = f"{HOTPLUG_PREFIX}soak{cycle}"
            try:
                before = guest_window_count(matrix, paths, state["port"])
                qmp.execute("device_add", **hotplug_device(matrix, dev))
                time.sleep(settle)
                qmp.execute("device_del", id=dev)
                if qmp.wait_event("DEVICE_DELETED", timeout,
                                  match=lambda e, d=dev: e.get("data", {}).get("device") == d) is None:
                    raise RigError("no DEVICE_DELETED event")
                time.sleep(settle)
                after = guest_window_count(matrix, paths, state["port"])
                lost += max(0, before - after)
            except RigError as error:
                errors.append({"cycle": cycle, "error": str(error)})
                try:
                    qmp.execute("device_del", id=dev)
                except RigError:
                    pass
    finally:
        qmp.close()
    summary = {"vm": args.vm, "cycles": args.cycles, "windows_lost": lost, "cycle_errors": errors}
    paths["soak"].write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    return 0 if lost == 0 and not errors else 1


def ssh_argv(matrix, paths, port, command):
    return [
        matrix["host"]["ssh"], "-i", str(paths["ssh_key"]), "-p", str(port),
        "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR",
        "-o", "ConnectTimeout=5", f"{SSH_USER}@127.0.0.1",
    ] + ([shlex.join(command)] if command else [])


def cmd_ssh(args, matrix, root):
    paths = vm_paths(root, args.vm)
    command = args.guest_command
    if args.dry_run:
        print(shlex.join(ssh_argv(matrix, paths, ssh_port(matrix, args.vm), command)))
        return 0
    state = load_state(paths, args.vm)
    return subprocess.call(ssh_argv(matrix, paths, state["port"], command))


def cmd_collect(args, matrix, root):
    paths = vm_paths(root, args.vm)
    port = ssh_port(matrix, args.vm)
    argv = [matrix["host"]["scp"], "-r", "-P", str(port), "-i", str(paths["ssh_key"]),
            "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR",
            f"{SSH_USER}@127.0.0.1:{args.remote}", args.dest]
    if args.dry_run:
        print(shlex.join(argv))
        return 0
    state = load_state(paths, args.vm)
    argv[argv.index("-P") + 1] = str(state["port"])
    return subprocess.call(argv)


def cmd_console(args, matrix, root):
    paths = vm_paths(root, args.vm)
    load_state(paths, args.vm)
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(str(paths["serial"]))
    except OSError as error:
        fail(f"cannot open serial socket: {error}")
    print("serial console. Press Ctrl+] then Enter to leave.", file=sys.stderr)
    try:
        while True:
            ready, _, _ = select.select([sock, sys.stdin], [], [])
            if sock in ready:
                data = sock.recv(4096)
                if not data:
                    break
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
            if sys.stdin in ready:
                line = os.read(sys.stdin.fileno(), 1024)
                if not line or b"\x1d" in line:
                    break
                sock.sendall(line)
    finally:
        sock.close()
    return 0


# CLI ------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(prog="rig.py", description="lunaOS QEMU/KVM test matrix (moonshot section 26).")
    parser.add_argument("--matrix", help="matrix file (default: matrix.toml next to rig.py)")
    parser.add_argument("--state-dir", help="state root (default: $LUNA_RIG_STATE or $XDG_CACHE_HOME/luna-rig)")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="show axes and profile sizes")

    p = sub.add_parser("plan", help="expand a profile into VMs")
    p.add_argument("profile")
    p.add_argument("--json", action="store_true")

    p = sub.add_parser("run", help="boot one VM (VM id from plan)")
    p.add_argument("vm")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("status", help="show VM state")
    p.add_argument("vm", nargs="?")

    p = sub.add_parser("stop", help="stop one VM")
    p.add_argument("vm")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("hotplug", help="add or remove one virtual output over QMP")
    p.add_argument("vm")
    p.add_argument("action", choices=["add", "remove-output"])
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("hotplug-soak", help="run N add/remove cycles and count lost windows")
    p.add_argument("vm")
    p.add_argument("--cycles", type=int, default=1000)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("ssh", help="run a command in the guest")
    p.add_argument("vm")
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("console", help="attach to the serial console")
    p.add_argument("vm")

    p = sub.add_parser("collect", help="copy a guest directory to the host")
    p.add_argument("vm")
    p.add_argument("remote")
    p.add_argument("dest")
    p.add_argument("--dry-run", action="store_true")
    return parser


COMMANDS = {
    "list": cmd_list, "plan": cmd_plan, "run": cmd_run, "status": cmd_status,
    "stop": cmd_stop, "hotplug": cmd_hotplug, "hotplug-soak": cmd_hotplug_soak,
    "ssh": cmd_ssh, "console": cmd_console, "collect": cmd_collect,
}


def main(argv=None):
    raw = list(sys.argv[1:] if argv is None else argv)
    guest_command = []
    if "--" in raw:
        cut = raw.index("--")
        raw, guest_command = raw[:cut], raw[cut + 1:]
    args = build_parser().parse_args(raw)
    args.guest_command = guest_command
    try:
        matrix = load_matrix(args.matrix)
        return COMMANDS[args.command](args, matrix, state_root(args))
    except RigError as error:
        print(f"rig: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
