"""Find where UI appears in a promo clip: the bounding box of pixels that change between two moments.

Usage: regions.py CLIP T_BEFORE T_AFTER [CLIP T0 T1 ...]   (times in seconds; boxes in the clip's own pixels)
"""
import json, subprocess, sys
import numpy as np

W = 640


def frame(path, t):
    probe = json.loads(subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v', '-show_entries', 'stream=width,height', '-of', 'json', path],
                                      capture_output=True, text=True).stdout)['streams'][0]
    h = round(W * probe['height'] / probe['width'])
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(t), '-i', path, '-frames:v', '1', '-vf', f'scale={W}:{h}', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(h, W, 3).astype(int), probe['width'] / W


def bbox(path, t0, t1, threshold=28):
    a, k = frame(path, t0)
    b, _ = frame(path, t1)
    mask = np.abs(a - b).sum(2) > threshold
    # Ignore isolated specks (cursor, clock seconds): keep rows/columns with a run of changed pixels.
    rows = np.where(mask.sum(1) > 4)[0]
    cols = np.where(mask.sum(0) > 4)[0]
    if not len(rows) or not len(cols):
        return None
    return [round(cols[0] * k), round(rows[0] * k), round((cols[-1] - cols[0] + 1) * k), round((rows[-1] - rows[0] + 1) * k)]


if __name__ == '__main__':
    args = sys.argv[1:]
    for i in range(0, len(args), 3):
        print(args[i], args[i + 1], args[i + 2], bbox(args[i], float(args[i + 1]), float(args[i + 2])))
