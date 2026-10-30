# lunaOS test rig

This folder is the software half of the test rig in moonshot section 26 (task 14 of section 28).
It holds a QEMU/KVM matrix, a driver for it, and scripts that bring up the stand-ins for
Wi-Fi, Bluetooth, printers, media and input on a desktop.

Nothing here has run against real QEMU, OVMF, swtpm, hostapd, FreeRADIUS, BlueZ, CUPS, SANE,
v4l2loopback, vivid or uinput yet. The tests run without them. Items marked **unverified** below
need a real run on the rig desktop.

## Install

Run this line on the rig desktop (CachyOS or Arch). It is not run by this folder:

```sh
sudo pacman -S --needed qemu-desktop swtpm edk2-ovmf xorriso openssh openssl hostapd freeradius iw bluez bluez-utils cups sane v4l-utils v4l2loopback-dkms shellcheck
```

Notes:

- `v4l2loopback-dkms` builds against kernel headers. On a CachyOS kernel install the matching
  `linux-cachyos-headers` package too. The `vivid` module comes from the kernel. Check it with
  `modinfo vivid`.
- `ippeveprinter` is part of CUPS. Check it with `command -v ippeveprinter` after the install.
- `btvirt` is the BlueZ emulator. Some distributions do not ship it. Check it with
  `command -v btvirt`. If it is missing, build it from the BlueZ source tree.
- `ffmpeg` is optional. It feeds a test pattern into the camera loopback.
- `hci_vhci`, `mac80211_hwsim`, `v4l2loopback`, `vivid` and `uinput` are kernel modules. The
  scripts load them only when run with root, not as part of this folder.

## What covers what (moonshot section 26)

| §26 need | Stand-in | Where | Status |
|---|---|---|---|
| Many machines and installs | QEMU/KVM matrix, OVMF, swtpm, NVMe, SATA, virtio, virtio-gpu, std VGA, guests | `matrix.toml`, `rig.py` | Dry-run tested only |
| Monitors plugged and unplugged | Virtual outputs over QMP (`hotplug`, `hotplug-soak`) | `rig.py` | **Unverified**: see below |
| Wi-Fi, 802.1X and hidden networks | mac80211_hwsim radios, hostapd PSK, hidden and enterprise, FreeRADIUS PEAP and TTLS | `devices/wifi-hwsim.sh`, `devices/conf/` | Configs rendered and tested, not run |
| Bluetooth pairing with PIN and passkey | BlueZ virtual controllers (btvirt) | `devices/bt-virt.sh` | **Unverified** flags |
| Printers and scanners | ippeveprinter (IPP Everywhere), SANE test backend | `devices/printer.sh` | Not run |
| Cameras, touch, pens, controllers | v4l2loopback camera, uinput touch, pen and gamepad | `devices/media.sh`, `devices/input.sh`, `devices/luna_uinput.py` | Ioctl numbers and struct sizes tested |
| HDMI-CEC | vivid test driver | `devices/media.sh` | **Unverified** module options |
| Ordinary extras, Android, watches, XR, Cuttlefish | Not in this folder | - | Out of scope for task 14 |

The §26 items that are not software stand-ins (phones, carriers, batteries, cameras) are not
covered here.

## Matrix

`matrix.toml` has one table per axis:

- **guest**: `opal-iso`, `arch`, `fedora`, `ubuntu`, `debian`.
- **firmware**: `uefi`, `bios`, `uefi-sb` (UEFI with Secure Boot).
- **tpm**: `none`, `swtpm2`.
- **disk**: `nvme`, `sata`, `virtio`.
- **gpu**: `virtio-gpu`, `virtio-gpu-gl`, `std-vga`.
- **outputs**: `one-1080p`, `one-4k-x2`, `two-mixed` (1080p at scale 1 and 1440p at scale 1.5),
  `two-same`.
- **resources**: `small`, `std`, `large`.

`[[exclude]]` rules remove impossible combinations, with a reason for each. A profile lists the
values it keeps. `cover = "pairwise"` picks the fewest VMs that still give every pair of values.
This keeps the matrix far below the raw product.

| Profile | VMs | Valid combinations | Raw product |
|---|---|---|---|
| `smoke` | 11 | 110 | 216 |
| `nightly` | 22 | 1740 | 3240 |

Run `python3 rig.py list` to see the current numbers.

### The Opal ISO

No ISO builder exists in this repo. `integrity/image/build.sh` builds an aarch64 Arch Linux ARM
rootfs for phones, not an x86 ISO. Until an x86 ISO builder lands, put the image at
`$XDG_CACHE_HOME/luna-rig/images/opal.iso` by hand. The rig does not build it.

### The cloud images

Download each image and rename it to the file name in `matrix.toml`. The rig does not download
images. The Luna desktop session is not installed by the rig either. The provisioning step for
that does not exist yet.

The Opal ISO must start `sshd` and accept the `authorized_keys` file on the seed ISO for user
`rig`. The seed ISO has the label `LUNARIG`.

## rig.py

Python 3 standard library only. It reads `matrix.toml` with `tomllib`.

```sh
python3 rig.py list                       # axes and profile sizes
python3 rig.py plan smoke                 # VM ids for a profile
python3 rig.py run <vm-id> --dry-run      # print the exact qemu command
python3 rig.py run <vm-id>                # boot it: overlay, OVMF vars copy, swtpm, QMP socket
python3 rig.py status [<vm-id>]
python3 rig.py ssh <vm-id> -- <command>   # run a test command in the guest
python3 rig.py console <vm-id>            # serial console, Ctrl+] then Enter to leave
python3 rig.py hotplug <vm-id> add|remove-output
python3 rig.py hotplug-soak <vm-id> --cycles 1000
python3 rig.py collect <vm-id> <remote-dir> <local-dir>
python3 rig.py stop <vm-id>
```

Run it as your own user. It refuses root for every command that changes state. Add `--dry-run`
to any command that changes state to see the steps without running them. A dry run creates no
files.

State is in `$LUNA_RIG_STATE`, or `$XDG_CACHE_HOME/luna-rig`, or `~/.cache/luna-rig`. Each VM gets
`vms/<12-hex key>/` with its overlay disk, OVMF vars copy, seed ISO, swtpm state, sockets and
`state.json`. The short key keeps unix socket paths under the 108-byte limit. `run` refuses to
start when a socket path would be too long, so keep the state root short.

SSH ports are stable per VM id, from `ssh_port_base` plus a CRC, in the range set by
`ssh_port_span`.

### Sample command

`python3 rig.py run ubuntu.uefi-sb.swtpm2.nvme.std-vga.one-1080p.std --dry-run` prints (line
breaks added here):

```sh
qemu-system-x86_64 -name luna-rig-<key> -machine q35,accel=kvm,smm=on -cpu host -smp 4 -m 4096M \
  -drive if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd \
  -drive if=pflash,format=raw,unit=1,file=<state>/vms/<key>/OVMF_VARS.fd \
  -global driver=cfi.pflash01,property=secure,value=on \
  -chardev socket,id=chrtpm,path=<state>/vms/<key>/tpm/swtpm-sock \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -drive if=none,id=sys,file=<state>/vms/<key>/disk.qcow2,format=qcow2 -device nvme,drive=sys,serial=luna-sys \
  -vga std -display none \
  -drive file=<state>/vms/<key>/seed.iso,media=cdrom,readonly=on \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:4028-:22 -device virtio-net-pci,netdev=net0 \
  -device pcie-root-port,id=rp-hot,bus=pcie.0,chassis=1,slot=1,hotplug=on \
  -qmp unix:<state>/vms/<key>/qmp.sock,server=on,wait=off \
  -serial unix:<state>/vms/<key>/serial.sock,server=on,wait=off \
  -pidfile <state>/vms/<key>/qemu.pid
```

Argument order is fixed. Tests in `test_rig.py` check the key flags.

### Hotplug

QEMU has no QMP command that removes one monitor from a virtio-GPU. The rig uses a stand-in:
a second virtio GPU card, added and removed with `device_add` and `device_del` on a hotplug root
port (`rp-hot`). The guest sees a card that gains and loses an output. `hotplug-soak` checks the
count of open windows before each cycle, after adding, and after removing. It reports the
windows lost. The window count comes from `hotplug.window_count_cmd` in `matrix.toml`. That
command depends on the compositor's test interface, which does not exist yet.

**Unverified:** the `hotplug=on` property of `pcie-root-port`, and whether a guest sees a new
output reliably on each cycle.

**Unverified:** the `xres` and `yres` properties on `virtio-vga` and `virtio-gpu-pci`. A head's
size is set with these only for head 0. Other head sizes need a guest EDID step. That step is not
built.

## devices/

Each script has `up`, `down` and `status`. `check` exists on the Wi-Fi script. `up` and `down`
refuse to run without root unless `--dry-run` is given. `status` needs no root. Each script
keeps its state under `/run/luna-rig/<name>` (override with `RIG_RUN_DIR`). `down` removes only
what `up` created.

```sh
sudo devices/wifi-hwsim.sh up        # or add --dry-run
devices/wifi-hwsim.sh status
devices/wifi-hwsim.sh check          # renders the configs and runs radiusd -C if installed
sudo devices/wifi-hwsim.sh down
```

### wifi-hwsim.sh

`up` loads `mac80211_hwsim` with four radios. It uses only the phys that appear after the load.
If the module is already loaded, it refuses. The radios play these roles:

| Radio | Role | SSID | Security |
|---|---|---|---|
| 0 | `psk` access point | `luna-rig-psk` | WPA2-PSK |
| 1 | `hidden` access point | `luna-rig-hidden` (hidden) | WPA2-PSK |
| 2 | `enterprise` access point | `luna-rig-ent` | WPA2-Enterprise (802.1X) |
| 3 | `client` | none, NetworkManager uses it | - |

The three access points are set `managed no` in NetworkManager, and `down` restores them. The
client radio stays managed.

FreeRADIUS listens on `127.0.0.1:11812`. It has one test user, `rig.user` with password
`rig-user-pass-01`, which matches the identity and password limits in
`opal/src/connectivity.py`. The RADIUS certificate is self-signed. It is generated once under the
state directory.

Connecting from the UI, in `connectivity.py` terms:

- Hidden: verb `hidden`, SSID `luna-rig-hidden`, password `rig-hidden-test-2026`.
- Enterprise: `enterprise` verb, identity `rig.user`, password `rig-user-pass-01`, EAP `peap` or
  `ttls`.

**Known gaps in `connectivity.py`:** it passes no CA certificate, so NetworkManager accepts any
RADIUS certificate. `connect` also names no Wi-Fi device. With several Wi-Fi radios, NetworkManager
chooses one. The rig's access points are simulated radios, so the real card cannot see them.

**Unverified:** TTLS inner authentication with the FreeRADIUS config here. The config uses no
virtual server, so the inner MS-CHAP path has not been tested. Check it with `radiusd -C` and a
real connect before trusting it.

### bt-virt.sh

`up` starts `btvirt` with `BTVIRT_ARGS` (default `-L -l2`). It runs as root because it uses the
vhci driver. It requires `bluetooth.service` to be running. Pairing tests:

- PIN (legacy): `bluetoothctl agent NoInputNoOutput`, then pair. The peer uses PIN `0000`.
- Passkey (SSP): `bluetoothctl agent KeyboardDisplay`, then pair. The peer shows `123456`.

The Opal pairing agent does not exist yet (section 28, item 10). These tests cover BlueZ only.

**Unverified:** the `btvirt` flags, and whether the second controller can act as a pairing peer.

### printer.sh

`up` runs `ippeveprinter` on `ipp://127.0.0.1:8631/ipp/print` as the sudo user. It also writes a
SANE config that enables only the test backend. Add the printer with:

```sh
lpadmin -p luna-rig -E -v ipp://localhost:8631/ipp/print -m everywhere
```

Check the scanner with `SANE_CONFIG_DIR=/run/luna-rig/printer/sane scanimage -L`.

**Unverified:** the `ippeveprinter` options (`-p`, `-d`, the name argument).

### media.sh

`up` loads `v4l2loopback` (camera `/dev/video42`, label `Luna Rig Camera`) and `vivid`
(`VIVID_OPTS`, default `n_devs=1`). It records which modules it loaded and unloads only those.
If ffmpeg is installed it feeds a test pattern into the camera. Check CEC adapters with
`cec-ctl --list-devices`.

**Unverified:** `VIVID_OPTS`. Check the options with `modinfo vivid`. The CEC adapter
options differ between kernels.

### input.sh and luna_uinput.py

`luna_uinput.py` creates a uinput device with the standard library only. It uses no
python-evdev. `input.sh up` starts three devices: `Luna Rig touch`, `Luna Rig pen` and
`Luna Rig gamepad`. They run as root because the device node requires it.

`luna_uinput.py describe --kind pen` prints the ioctl steps without opening a device. The tests
check the struct sizes and the ioctl numbers against the `_IOW` macro. This writer covers
creation only. It has no event sender. Tests send events through the standard evdev path.

**Unverified:** the device on a real kernel. The ioctl numbers match the kernel headers as
written here, but no device was created.

## Nightly chain

This chain is not automated. The desktop suite (`opal/tests/desktop-suite/`) does not exist yet.
Set `[suite] command` in `matrix.toml` when it lands.

```sh
cd opal/rig
SUITE_CMD=$(python3 -c 'import tomllib;print(tomllib.load(open("matrix.toml","rb"))["suite"]["command"])')
python3 rig.py plan nightly > nightly.txt
while read -r vm; do
  python3 rig.py run "$vm"
  # Wait for ssh, then run the desktop suite inside the guest.
  until python3 rig.py ssh "$vm" -- true; do sleep 5; done
  python3 rig.py ssh "$vm" -- "$SUITE_CMD"
  python3 rig.py collect "$vm" /home/rig/suite-reports "reports/$vm"
  python3 rig.py stop "$vm"
done < <(grep -v '^profile' nightly.txt)
```

Read the suite command from `matrix.toml` once it is set. The desktop suite writes its reports to
`[suite] report_dir`. The hotplug soak runs as a separate job on the rig desktops, not in this
chain.

Tests:

```sh
cd opal/rig
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s . -p 'test_rig.py'
```

## Not done

- No command has run against real QEMU, swtpm, OVMF, hostapd, FreeRADIUS, BlueZ, CUPS, SANE,
  v4l2loopback, vivid or uinput.
- `shellcheck` is not installed here. The scripts pass `bash -n` only.
- The Opal ISO builder, the desktop suite, and the compositor test interface do not exist.
- The Secure Boot vars template name is a guess. Check it with `pacman -Ql edk2-ovmf`.
