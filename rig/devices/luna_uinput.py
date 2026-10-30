#!/usr/bin/env python3
"""Create a virtual touch, pen or gamepad through /dev/uinput. Standard library only."""

import argparse
import fcntl
import os
import signal
import struct
import sys

# Event types and codes from linux/input-event-codes.h.
EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
ABS_X, ABS_Y, ABS_PRESSURE = 0x00, 0x01, 0x18
ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0x2F, 0x35, 0x36, 0x39
BTN_SOUTH, BTN_EAST, BTN_TOUCH, BTN_TOOL_PEN, BTN_STYLUS = 0x130, 0x131, 0x14A, 0x140, 0x14B
BUS_VIRTUAL = 0x06

# ioctl numbers from linux/uinput.h. Each matches the _IOW or _IO macro.
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY = 0x5502
UI_SET_EVBIT = 0x40045564
UI_SET_KEYBIT = 0x40045565
UI_SET_ABSBIT = 0x40045567
UI_DEV_SETUP = 0x405C5503
UI_ABS_SETUP = 0x401C5504

KINDS = {
    "touch": {
        "keys": [BTN_TOUCH],
        "abs": {
            ABS_X: (0, 4095),
            ABS_Y: (0, 2399),
            ABS_MT_SLOT: (0, 9),
            ABS_MT_TRACKING_ID: (0, 65535),
            ABS_MT_POSITION_X: (0, 4095),
            ABS_MT_POSITION_Y: (0, 2399),
        },
    },
    "pen": {
        "keys": [BTN_TOOL_PEN, BTN_TOUCH, BTN_STYLUS],
        "abs": {ABS_X: (0, 4095), ABS_Y: (0, 2399), ABS_PRESSURE: (0, 1023)},
    },
    "gamepad": {
        "keys": [BTN_SOUTH, BTN_EAST],
        "abs": {ABS_X: (-32768, 32767), ABS_Y: (-32768, 32767)},
    },
}


def setup_struct(name, product):
    """Pack struct uinput_setup: input_id, 80-byte name, ff_effects_max (92 bytes)."""
    raw = name.encode()[:79].ljust(80, b"\0")
    return struct.pack("<HHHH80sI", BUS_VIRTUAL, 0x4C55, product, 1, raw, 0)


def abs_struct(code, minimum, maximum):
    """Pack struct uinput_abs_setup: code, padding, input_absinfo (28 bytes)."""
    return struct.pack("<H2x6i", code, 0, minimum, maximum, 0, 0, 0)


def describe(kind, name, product):
    """Return the ioctl steps for a kind, without opening a device."""
    spec = KINDS[kind]
    steps = [("UI_SET_EVBIT", EV_KEY), ("UI_SET_EVBIT", EV_ABS)]
    steps += [("UI_SET_KEYBIT", key) for key in spec["keys"]]
    for code, (low, high) in spec["abs"].items():
        steps.append(("UI_SET_ABSBIT", code))
        steps.append(("UI_ABS_SETUP", (code, low, high)))
    steps.append(("UI_DEV_SETUP", name, product))
    steps.append(("UI_DEV_CREATE", None))
    return steps


def create(kind, name, product):
    spec = KINDS[kind]
    fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    try:
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
        for key in spec["keys"]:
            fcntl.ioctl(fd, UI_SET_KEYBIT, key)
        for code, (low, high) in spec["abs"].items():
            fcntl.ioctl(fd, UI_SET_ABSBIT, code)
            fcntl.ioctl(fd, UI_ABS_SETUP, abs_struct(code, low, high))
        fcntl.ioctl(fd, UI_DEV_SETUP, setup_struct(name, product))
        fcntl.ioctl(fd, UI_DEV_CREATE)
    except OSError:
        os.close(fd)
        raise
    return fd


def run_until_signal(fd):
    def stop(_signum, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        signal.pause()
    except SystemExit:
        pass
    finally:
        fcntl.ioctl(fd, UI_DEV_DESTROY)
        os.close(fd)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("create", "describe"):
        p = sub.add_parser(name)
        p.add_argument("--kind", choices=sorted(KINDS), required=True)
        p.add_argument("--name", default="Luna Rig test device")
        p.add_argument("--product", type=int, default=0x0001)
    args = parser.parse_args(argv)
    if args.command == "describe":
        for step in describe(args.kind, args.name, args.product):
            print(*step)
        return 0
    run_until_signal(create(args.kind, args.name, args.product))
    return 0


if __name__ == "__main__":
    sys.exit(main())
