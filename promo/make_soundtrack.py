"""Synthesizes a beat-synced electronic soundtrack for the Opal promo video.
128 BPM, modern punchy kick, snappy clap/snare, 16th hats, sidechained bass,
supersaw chords, and melodic arpeggiator.
"""
import math, wave, struct
import numpy as np
import pathlib

SR = 48000
BPM = 128
BEAT = 60.0 / BPM # ~0.46875s
SIXTEENTH = BEAT / 4.0
TOTAL_BARS = 16 # ~30 seconds
TOTAL_DURATION = TOTAL_BARS * 4 * BEAT # 30.0s
NUM_SAMPLES = int(TOTAL_DURATION * SR)

def synth_kick(length_s=0.35):
    n = int(length_s * SR)
    t = np.linspace(0, length_s, n, endpoint=False)
    # Exponential pitch drop from 180Hz down to 45Hz
    freq = 45.0 + 135.0 * np.exp(-t * 28.0)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase)
    # Click/transient
    click = (np.random.rand(n) * 2 - 1) * np.exp(-t * 200.0) * 0.4
    env = np.exp(-t * 9.0)
    return (body + click) * env

def synth_snare(length_s=0.25):
    n = int(length_s * SR)
    t = np.linspace(0, length_s, n, endpoint=False)
    noise = (np.random.rand(n) * 2 - 1) * np.exp(-t * 18.0)
    body = np.sin(2 * np.pi * 180.0 * np.exp(-t * 20.0) * t) * np.exp(-t * 25.0) * 0.6
    return (noise * 0.7 + body * 0.3)

def synth_hihat(length_s=0.08, open_hat=False):
    if open_hat: length_s = 0.22
    n = int(length_s * SR)
    t = np.linspace(0, length_s, n, endpoint=False)
    # High-passed metallic noise
    noise = (np.random.rand(n) * 2 - 1)
    diff = np.diff(noise, prepend=0)
    decay = 18.0 if open_hat else 65.0
    return diff * np.exp(-t * decay) * 0.3

def synth_saw(freq, length_s, detune=0.015):
    n = int(length_s * SR)
    t = np.linspace(0, length_s, n, endpoint=False)
    # Multi-oscillator supersaw
    out = np.zeros(n)
    for d in [-detune, -detune/2, 0, detune/2, detune]:
        f = freq * (1.0 + d)
        out += 2.0 * ((t * f) % 1.0) - 1.0
    return out / 5.0

def mtof(midi_note):
    return 440.0 * (2.0 ** ((midi_note - 69.0) / 12.0))

def render():
    left = np.zeros(NUM_SAMPLES, dtype=np.float32)
    right = np.zeros(NUM_SAMPLES, dtype=np.float32)

    kick = synth_kick()
    snare = synth_snare()
    hat_closed = synth_hihat(open_hat=False)
    hat_open = synth_hihat(open_hat=True)

    # Chords progression in D minor: Dm - Bb - F - C (4 bars, repeats 4 times)
    chord_prog = [
        [50, 57, 62, 65, 69], # Dm9
        [46, 53, 58, 62, 65], # Bbmaj7
        [41, 48, 53, 57, 60], # Fmaj7
        [48, 55, 60, 64, 67], # Cadd9
    ]
    arp_scale = [62, 65, 69, 72, 74, 77] # Dm pentatonic/hexatonic

    # Sidechain envelope for bass & chords
    beat_samples = int(BEAT * SR)
    sidechain = np.ones(beat_samples, dtype=np.float32)
    sc_t = np.linspace(0, 1, beat_samples)
    sidechain[:int(beat_samples * 0.45)] = 1.0 - np.exp(-sc_t[:int(beat_samples * 0.45)] * 14.0)

    # 1. Drums & Bass
    total_beats = TOTAL_BARS * 4
    for b in range(total_beats):
        pos = int(b * BEAT * SR)
        bar = b // 4
        beat_in_bar = b % 4

        # Kick on every beat except intro bar 0
        if bar >= 1:
            end = min(NUM_SAMPLES, pos + len(kick))
            left[pos:end] += kick[:end-pos] * 0.95
            right[pos:end] += kick[:end-pos] * 0.95

        # Snare on beats 2 and 4 (indices 1 and 3)
        if bar >= 1 and beat_in_bar in (1, 3):
            end = min(NUM_SAMPLES, pos + len(snare))
            left[pos:end] += snare[:end-pos] * 0.75
            right[pos:end] += snare[:end-pos] * 0.75

        # Hihats on 16th notes
        if bar >= 2:
            for s in range(4):
                hpos = pos + int(s * SIXTEENTH * SR)
                if hpos < NUM_SAMPLES:
                    h = hat_open if (s == 2 and bar >= 4) else hat_closed
                    vol = 0.55 if s in (0, 2) else 0.35
                    end = min(NUM_SAMPLES, hpos + len(h))
                    left[hpos:end] += h[:end-hpos] * vol * 0.8
                    right[hpos:end] += h[:end-hpos] * vol * 1.1

    # 2. Bass (Rolling 16th-note sub bass with filter)
    bass_notes = [38, 38, 38, 38,  34, 34, 34, 34,  29, 29, 29, 29,  36, 36, 36, 36]
    for bar in range(TOTAL_BARS):
        root_note = bass_notes[bar % len(bass_notes)]
        freq = mtof(root_note)
        for s in range(16):
            bpos = int((bar * 4 * BEAT + s * SIXTEENTH) * SR)
            if bpos >= NUM_SAMPLES or bar < 2:
                continue
            # Note variation
            cur_freq = freq
            if s in (6, 14): cur_freq = mtof(root_note + 12)
            elif s in (7, 15): cur_freq = mtof(root_note + 7)
            slen = SIXTEENTH * 0.85
            n = int(slen * SR)
            t = np.linspace(0, slen, n, endpoint=False)
            # Filtered saw + sub sine
            bass_wav = np.sin(2 * np.pi * cur_freq * t) * 0.7 + (2 * ((t * cur_freq) % 1.0) - 1.0) * 0.3
            bass_wav *= np.exp(-t * 6.0)
            # Sidechain ducking
            sc_factor = sidechain[int((s % 4) * (beat_samples / 4)):int((s % 4) * (beat_samples / 4)) + n] if n <= len(sidechain) else 0.8
            if isinstance(sc_factor, np.ndarray) and len(sc_factor) == n:
                bass_wav *= sc_factor
            end = min(NUM_SAMPLES, bpos + n)
            left[bpos:end] += bass_wav[:end-bpos] * 0.55
            right[bpos:end] += bass_wav[:end-bpos] * 0.55

    # 3. Chords (Warm stereo pads)
    for bar in range(TOTAL_BARS):
        chord = chord_prog[bar % len(chord_prog)]
        bar_pos = int(bar * 4 * BEAT * SR)
        bar_len = int(4 * BEAT * SR)
        t = np.linspace(0, 4 * BEAT, bar_len, endpoint=False)
        chord_l = np.zeros(bar_len)
        chord_r = np.zeros(bar_len)
        for note in chord:
            f = mtof(note)
            s_l = synth_saw(f, 4 * BEAT, detune=0.012)
            s_r = synth_saw(f * 1.002, 4 * BEAT, detune=0.012)
            chord_l += s_l
            chord_r += s_r
        # Envelope: swell then sustain
        env = np.ones(bar_len)
        attack = int(0.15 * SR)
        env[:attack] = np.linspace(0, 1, attack)
        chord_l *= env * 0.12
        chord_r *= env * 0.12
        end = min(NUM_SAMPLES, bar_pos + bar_len)
        left[bar_pos:end] += chord_l[:end-bar_pos]
        right[bar_pos:end] += chord_r[:end-bar_pos]

    # 4. Arpeggiator (Bright melodic sparkle)
    pattern = [0, 2, 4, 1, 3, 5, 2, 4, 1, 3, 5, 3, 4, 2, 1, 0]
    for bar in range(TOTAL_BARS):
        chord_root = [0, -2, -5, -3][bar % 4]
        for step in range(16):
            apos = int((bar * 4 * BEAT + step * SIXTEENTH) * SR)
            if apos >= NUM_SAMPLES or bar < 1:
                continue
            idx = (pattern[step] + (bar % 3)) % len(arp_scale)
            note = arp_scale[idx] + chord_root
            f = mtof(note)
            alen = SIXTEENTH * 0.65
            n = int(alen * SR)
            t = np.linspace(0, alen, n, endpoint=False)
            arp_tone = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)
            arp_tone *= np.exp(-t * 22.0) * 0.28
            # Pan alternating
            pan = 0.3 + 0.4 * ((step % 2) == 0)
            end = min(NUM_SAMPLES, apos + n)
            left[apos:end] += arp_tone[:end-apos] * (1.0 - pan)
            right[apos:end] += arp_tone[:end-apos] * pan

    # Master limiter & normalization
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)), 1e-4)
    left = np.clip(left / peak * 0.92, -0.98, 0.98)
    right = np.clip(right / peak * 0.92, -0.98, 0.98)

    # Convert to 16-bit PCM
    out_path = pathlib.Path('/home/melissa/.local/state/opal/artifacts/promo/soundtrack.wav')
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out_path), 'w') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        samples = np.empty((NUM_SAMPLES, 2), dtype=np.int16)
        samples[:, 0] = (left * 32767).astype(np.int16)
        samples[:, 1] = (right * 32767).astype(np.int16)
        wf.writeframes(samples.tobytes())
    print(f"Soundtrack synthesized to {out_path} ({TOTAL_DURATION:.1f}s, {SR}Hz stereo)")
    return out_path

if __name__ == '__main__':
    render()
