#!/usr/bin/env python3
"""Socket helper for tests/integration.sh: record the stream, send commands, and match events."""
import json
import socket
import sys
import time


def connect(path):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(0.2)
    sock.connect(path)
    return sock


def read_for(sock, seconds):
    """Return the complete lines that arrive within the given time."""
    lines, buffer = [], b''
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        try:
            chunk = sock.recv(65536)
        except socket.timeout:
            continue
        if not chunk:
            break
        buffer += chunk
        while b'\n' in buffer:
            line, buffer = buffer.split(b'\n', 1)
            lines.append(line.decode())
    return lines


def matches(event, pattern):
    """Return true when every key of the pattern is present with the same value."""
    if isinstance(pattern, dict):
        return isinstance(event, dict) and all(key in event and matches(event[key], value) for key, value in pattern.items())
    if isinstance(pattern, list):
        return isinstance(event, list) and len(event) == len(pattern) and all(matches(e, p) for e, p in zip(event, pattern))
    return event == pattern


def read_events(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return [line for line in handle.read().splitlines() if line.strip()]
    except FileNotFoundError:
        return []


def cmd_tail(path, out, seconds):
    """Write every line from the socket to a file until the time runs out."""
    sock = connect(path)
    end = time.monotonic() + float(seconds)
    with open(out, 'ab', buffering=0) as handle:
        while time.monotonic() < end:
            try:
                chunk = sock.recv(65536)
            except socket.timeout:
                continue
            if not chunk:
                break
            handle.write(chunk)
    return 0


def cmd_send(path, payload):
    """Send one request, then print any reply that comes back within half a second."""
    sock = connect(path)
    lines = read_for(sock, 0.3)
    sock.sendall((payload + '\n').encode())
    for line in read_for(sock, 0.5):
        print(line)
    return 0


def cmd_snapshot(path):
    """Print the snapshot line that a new client receives."""
    sock = connect(path)
    lines = read_for(sock, 0.3)
    snapshots = [line for line in lines if json.loads(line).get('type') == 'snapshot']
    if not snapshots:
        print('no snapshot', file=sys.stderr)
        return 1
    print(snapshots[0])
    return 0


def cmd_wait(file, pattern, seconds):
    """Wait until a matching event appears in the recorded file."""
    wanted = json.loads(pattern)
    end = time.monotonic() + float(seconds)
    while True:
        for line in read_events(file):
            if matches(json.loads(line), wanted):
                print(line)
                return 0
        if time.monotonic() >= end:
            break
        time.sleep(0.1)
    print(f'no event matched {pattern}', file=sys.stderr)
    for line in read_events(file)[-15:]:
        print(f'  seen: {line}', file=sys.stderr)
    return 1


def cmd_refute(file, pattern, start, seconds):
    """Wait, then fail when a matching event appears after line start."""
    wanted = json.loads(pattern)
    time.sleep(float(seconds))
    for line in read_events(file)[int(start):]:
        if matches(json.loads(line), wanted):
            print(f'unexpected event: {line}', file=sys.stderr)
            return 1
    return 0


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    command, args = argv[0], argv[1:]
    if command == 'tail':
        return cmd_tail(*args)
    if command == 'send':
        return cmd_send(*args)
    if command == 'snapshot':
        return cmd_snapshot(*args)
    if command == 'wait':
        return cmd_wait(*args)
    if command == 'refute':
        return cmd_refute(*args)
    print(f'unknown command {command}', file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
