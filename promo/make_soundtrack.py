"""The promo's original soundtrack, synthesized: 120 BPM, 44 bars (88 s), arranged to the edit.

Bars (2 s each): 1-4 intro, 5-12 drop one (desktop), 13-16 lead (style), 17-18 breakdown, 19-26 drop two
(every screen), 27-32 drive (games), 33-35 light (Claude), 36-39 montage, 40-44 outro.
Writes soundtrack.wav (48 kHz stereo) and soundtrack.json (section and hit times) to the artifacts folder.
"""
import json, pathlib, wave
import numpy as np

SR = 48000
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 44
N = int(BARS * BAR * SR) + SR * 6
OUT = pathlib.Path.home() / '.local/state/opal/artifacts/promo'
rng = np.random.default_rng(7)

SECTIONS = [('intro', 1, 4), ('drop1', 5, 12), ('lead', 13, 16), ('breakdown', 17, 18), ('drop2', 19, 26),
            ('drive', 27, 32), ('light', 33, 35), ('montage', 36, 39), ('outro', 40, 44)]


def section(bar):
    return next(name for name, a, b in SECTIONS if a <= bar <= b)


def t_of(bar, beat=0.0):
    return ((bar - 1) * 4 + beat) * BEAT


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# A minor: Am F C G, one chord a bar; the outro lands on F then a held Am add9.
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
BASS = [45, 41, 48, 43]


class Mix:
    def __init__(self):
        self.L = np.zeros(N); self.R = np.zeros(N)
        self.send = np.zeros(N)

    def add(self, sig, at, gain=1.0, pan=0.0, verb=0.0):
        i = int(at * SR)
        if i >= N:
            return
        sig = sig[:N - i] * gain
        l, r = np.sqrt(.5 * (1 - pan)), np.sqrt(.5 * (1 + pan))
        self.L[i:i + len(sig)] += sig * l
        self.R[i:i + len(sig)] += sig * r
        self.send[i:i + len(sig)] += sig * verb


def env(n, a=.005, d=.1, s=.6, r=.2, hold=None):
    t = np.arange(n) / SR
    hold = hold if hold is not None else n / SR - r
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip(1 - (t - hold) / r, 0, 1)
    return e * np.where(t > hold, rel, 1)


def saw_additive(f, n, cutoff, detune_cents=(0,), phase_seed=0):
    """Band-limited saw(s) by additive synthesis; cutoff (Hz) may be an array for sweeps."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), (n,))
    for c in detune_cents:
        fc = f * 2 ** (c / 1200)
        ph = rng.random() * 2 * np.pi
        kmax = int(min(SR / 2 * .95, cut.max() * 1.5) // fc)
        for k in range(1, max(2, kmax + 1)):
            soft = 1 / (1 + np.exp((k * fc - cut) / (cut * .18 + 1)))
            out += soft * np.sin(2 * np.pi * k * fc * t + ph * k) / k
    return out / max(1, len(detune_cents)) * .6


def kick(n=int(.42 * SR)):
    t = np.arange(n) / SR
    f = 46 + 150 * np.exp(-t * 30)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    click = rng.standard_normal(n) * np.exp(-t * 400) * .25
    return np.tanh((body + click) * 1.6)


def clap(n=int(.32 * SR)):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = noise - np.convolve(noise, np.ones(6) / 6, 'same')  # brighter
    bursts = sum(np.exp(-np.clip(t - d, 0, None) * 140) * (t >= d) for d in (0, .011, .022))
    tail = np.exp(-t * 16)
    return noise * (bursts * .5 + tail * .5) * .7


def hat(open_=False):
    n = int((.24 if open_ else .05) * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = noise - np.convolve(noise, np.ones(3) / 3, 'same')
    return noise * np.exp(-t * (14 if open_ else 90)) * .35


def sub(f, n):
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + .35 * np.sin(2 * np.pi * 2 * f * t)
    return np.tanh(s * 1.3) * env(n, .004, .3, .8, .04)


def pluck(f, n, bright=3500):
    s = saw_additive(f, n, bright * np.exp(-np.arange(n) / SR * 7) + 400, (-6, 6))
    return s * env(n, .002, .12, .0, .05)


def lead(f, n):
    t = np.arange(n) / SR
    vib = 1 + .004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    sq = sum(np.sin(k * ph) / k for k in (1, 3, 5, 7, 9)) + .5 * np.sin(2 * ph)
    return sq * env(n, .01, .2, .7, .08) * .45


def riser(n, f0=300, f1=6000):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    cut = f0 * (f1 / f0) ** (t / t[-1])
    spec = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    # A time-varying filter, approximated in blocks.
    out = np.zeros(n)
    block = 2048
    for i in range(0, n, block):
        seg = noise[i:i + block]
        sp = np.fft.rfft(seg)
        fr = np.fft.rfftfreq(len(seg), 1 / SR)
        c = cut[min(i + block // 2, n - 1)]
        sp *= np.exp(-((fr - c) / (c * .5)) ** 2)
        out[i:i + len(seg)] = np.fft.irfft(sp, len(seg))
    return out / (np.abs(out).max() + 1e-9) * (t / t[-1]) ** 2


def impact(n=int(2.5 * SR)):
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * np.cumsum(38 + 60 * np.exp(-t * 6)) / SR) * np.exp(-t * 1.6)
    hiss = rng.standard_normal(n) * np.exp(-t * 3) * .25
    return np.tanh((boom + hiss) * 1.4)


def build():
    m = Mix()
    hits = []
    K, C, H, HO = kick(), clap(), hat(), hat(True)
    duck = np.ones(N)
    melody = [(0, 76, 1.5), (1.5, 74, .5), (2, 72, 1), (3, 69, 1), (4, 72, 1.5), (5.5, 74, .5), (6, 76, 2),
              (8, 79, 1.5), (9.5, 76, .5), (10, 74, 1), (11, 72, 1), (12, 74, 1), (13, 72, 1), (14, 71, 2)]
    for bar in range(1, BARS + 1):
        sec = section(bar)
        ci = (bar - 1) % 4
        t0 = t_of(bar)
        full = sec in ('drop1', 'lead', 'drop2', 'drive', 'montage')
        # Drums.
        if full or sec == 'light' or (sec == 'outro' and bar == 40):
            for b in range(4):
                m.add(K, t0 + b * BEAT, .95)
                d = int((t0 + b * BEAT) * SR)
                L = int(.33 * SR)
                duck[d:d + L] = np.minimum(duck[d:d + L], 1 - .75 * np.exp(-np.arange(min(L, N - d)) / SR * 9))
        if full:
            for b in (1, 3):
                m.add(C, t0 + b * BEAT, .55, verb=.25)
            for s16 in range(16):
                if s16 % 4 == 2:
                    m.add(HO, t0 + s16 * BEAT / 4, .32, pan=.2)
                else:
                    m.add(H, t0 + s16 * BEAT / 4, .25 + .1 * (s16 % 2 == 0), pan=-.25)
            if sec == 'drive':
                for s16 in (14, 15):
                    m.add(C, t0 + s16 * BEAT / 4, .25, verb=.2)
        # Bass: off-beat eighths over a held sub in the drops.
        if full or sec == 'light':
            f = midi(BASS[ci] - 12)
            for e in range(8):
                n = int(BEAT / 2 * SR * .9)
                m.add(sub(f, n), t0 + e * BEAT / 2, .55 if e % 2 else .4)
        # Pads: every section, filtered down in the intro and breakdown.
        n = int(BAR * SR * 1.05)
        if sec in ('intro', 'breakdown'):
            span = (bar - 1) % 4 if sec == 'intro' else (bar - 17)
            lo, hi = (500 + 500 * span, 1000 + 900 * span) if sec == 'intro' else (2200 - 800 * span, 1400 - 600 * span)
            cut = np.linspace(lo, hi, n)
        else:
            cut = 2600.0
        for note in CHORDS[ci]:
            pad = saw_additive(midi(note), n, cut, (-14, -5, 0, 6, 15))
            m.add(pad * env(n, .08, .5, .85, .25), t0, .16 if full else .22, pan=rng.uniform(-.5, .5), verb=.4)
        # Chord stabs and an arpeggio in the drops.
        if full:
            for s8 in (0, 3, 6):
                for note in CHORDS[ci]:
                    m.add(pluck(midi(note + 12), int(.22 * SR)), t0 + s8 * BEAT / 2, .2, pan=.3, verb=.3)
        if full or sec == 'intro' and bar >= 3:
            arp = [CHORDS[ci][i % 3] + 24 + 12 * (i // 3 % 2) for i in range(16)]
            for i, note in enumerate(arp):
                m.add(pluck(midi(note), int(.12 * SR), 5000), t0 + i * BEAT / 4, .07 if sec != 'drive' else .1, pan=(-.6, .6)[i % 2], verb=.35)
        # Lead melody over two-bar phrases.
        if sec in ('lead', 'drop2', 'montage'):
            phrase_bar = (bar - 1) % 4
            for start, note, length in melody:
                if int(start // 4) == phrase_bar:
                    m.add(lead(midi(note), int(length * BEAT * SR)), t0 + (start % 4) * BEAT, .22, verb=.35)
        # Transitions.
        if bar in (4, 18, 39):
            m.add(riser(int(BAR * SR)), t0, .35, verb=.2)
            for s16 in range(8 if bar != 18 else 16):
                at = t0 + (BAR - (8 if bar != 18 else 16) * BEAT / 4) + s16 * BEAT / 4
                m.add(C, at, .12 + .03 * s16, verb=.2)
        if bar in (5, 19, 40):
            m.add(impact(), t0, .8, verb=.5)
            hits.append(round(t0, 3))
    # Final hit and ring-out.
    end = t_of(44, 2)
    for note in (57, 60, 64, 71, 76):
        n = int(5 * SR)
        m.add(saw_additive(midi(note), n, 2400, (-9, 0, 9)) * env(n, .01, 1.5, .4, 2.5), end, .2, verb=.6)
    m.add(impact(), end, .7, verb=.5)
    hits.append(round(end, 3))
    # Sidechain the pads, bass and stabs by the kick envelope (applied to everything but the drums would be ideal;
    # the whole bus ducking reads as pumping, which suits the style).
    L, R = m.L * duck, m.R * duck
    # Reverb: convolve the send with a 2.2 s decaying stereo noise impulse.
    ir_n = int(2.2 * SR)
    t = np.arange(ir_n) / SR
    irL = rng.standard_normal(ir_n) * np.exp(-t * 3.1)
    irR = rng.standard_normal(ir_n) * np.exp(-t * 3.1)
    size = 1 << int(np.ceil(np.log2(N + ir_n)))
    S = np.fft.rfft(m.send * duck, size)
    wetL = np.fft.irfft(S * np.fft.rfft(irL, size), size)[:N]
    wetR = np.fft.irfft(S * np.fft.rfft(irR, size), size)[:N]
    wet = .035
    L = L + wetL * wet; R = R + wetR * wet
    # Master: gentle glue, then a limiter-ish soft clip and normalise.
    peak = max(np.abs(L).max(), np.abs(R).max())
    L, R = np.tanh(L / peak * 1.6) / np.tanh(1.6), np.tanh(R / peak * 1.6) / np.tanh(1.6)
    total = int((t_of(44, 2) + 4.5) * SR)
    fade = np.ones(total); fade[-int(1.5 * SR):] = np.linspace(1, 0, int(1.5 * SR))
    L, R = L[:total] * fade * .89, R[:total] * fade * .89
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.stack([L, R], 1) * 32767).astype('<i2')
    with wave.open(str(OUT / 'soundtrack.wav'), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    meta = {'bpm': BPM, 'bar': BAR, 'duration': total / SR, 'hits': hits,
            'sections': [{'name': n, 'start': t_of(a), 'end': t_of(b + 1)} for n, a, b in SECTIONS]}
    (OUT / 'soundtrack.json').write_text(json.dumps(meta, indent=1))
    print(json.dumps(meta))


if __name__ == '__main__':
    build()
