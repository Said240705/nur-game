"""Temporary score for БЫЛА В СЕТИ, synthesized from scratch (no samples).

Writes seamless OGG loops to assets/audio/music/:
  theme    - title and the city: a slow piano motif in D minor over a pad
  lonely   - Lev's phone: a sustained pad and the odd far-away note
  tension  - Mira's phone: a heartbeat pulse under a dissonant swell
  dread    - one-shot swell for the moment «Н.» starts typing

Run from the repository root:  python3 tools/music/make_music.py
These are placeholders until real tracks are licensed or recorded.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = "assets/audio/music"
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def piano(midi, length=4.0, vel=1.0):
    """Additive piano-like note: slightly sharp upper partials that die faster."""
    t = t_axis(length)
    f = hz(midi)
    s = np.zeros_like(t)
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + 0.0004 * k * k)
        if fk > RATE / 2.2:
            break
        s += np.sin(2 * np.pi * fk * t) * (0.9 ** k) / k * np.exp(-t * (0.9 + 0.7 * k))
    hammer = rng.standard_normal(len(t)) * np.exp(-t * 90) * 0.02
    env = np.minimum(1, t * 300) * np.minimum(1, (length - t) * 8)
    return (s + hammer) * env * vel * 0.5


def lowpass(x, cutoff):
    """Two-pole low-pass at a fixed cutoff, applied in the frequency domain."""
    size = 1 << int(np.ceil(np.log2(len(x) + RATE)))
    w = 2 * np.pi * np.fft.rfftfreq(size, 1 / RATE) / RATE
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    h = (a / (1 - (1 - a) * np.exp(-1j * w))) ** 2
    return np.fft.irfft(np.fft.rfft(x, size) * h, size)[:len(x)]


def sweep(x, low, high, period):
    """A filter that breathes: crossfade a dark and a bright version."""
    t = np.arange(len(x)) / RATE
    k = 0.5 + 0.5 * np.sin(2 * np.pi * t / period)
    return lowpass(x, low) * (1 - k) + lowpass(x, high) * k


def pad(midis, length, attack=2.5, release=3.0, bright=900.0, gain=0.12):
    """Detuned saw-like voices, softened by a slowly breathing filter."""
    t = t_axis(length)
    s = np.zeros_like(t)
    for m in midis:
        for d in (-0.08, 0.0, 0.07):
            f = hz(m + d)
            for k in range(1, 7):
                s += np.sin(2 * np.pi * f * k * t + rng.random() * 6.28) / k
    s = sweep(s / (len(midis) * 3), bright * 0.5, bright, 7.0)
    env = np.minimum(1, t / attack) * np.minimum(1, (length - t) / release)
    return s * env * gain


def place(buf, sound, at, pan=0.0):
    i = int(at * RATE)
    n = min(len(sound), buf.shape[0] - i)
    buf[i:i + n, 0] += sound[:n] * (1 - max(0, pan))
    buf[i:i + n, 1] += sound[:n] * (1 + min(0, pan))


def reverb(buf, seconds=3.5, wet=0.35):
    n = int(seconds * RATE)
    out = buf.copy() * (1 - wet * 0.5)
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-np.arange(n) / RATE * 6.9 / seconds)
        ir = lowpass(ir, 4000.0)
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(len(buf) + n)))
        y = np.fft.irfft(np.fft.rfft(buf[:, ch], size) * np.fft.rfft(ir, size), size)
        out[:, ch] += y[:len(buf)] * wet
    return out


def loop(render, length, tail=6.0):
    """Render with room for the reverb tail, then fold the tail onto the start."""
    buf = np.zeros((int((length + tail) * RATE), 2))
    render(buf)
    buf = reverb(buf)
    n = int(length * RATE)
    out = buf[:n].copy()
    out[:len(buf) - n] += buf[n:]
    return out


def save(name, buf, peak=0.7):
    buf = buf / np.max(np.abs(buf)) * peak
    pcm = (buf * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "4",
                    f"{OUT}/{name}.ogg"], check=True)
    os.remove(path)
    print("wrote", name, f"{len(buf) / RATE:.1f}s")


# D minor. Chords as MIDI notes.
Dm, Bb, F, A, Gm, C = [50, 57, 62, 65], [46, 53, 58, 62], [41, 53, 57, 60], [45, 52, 57, 61], [43, 55, 58, 62], [48, 55, 60, 64]


def theme(buf):
    beat = 60 / 62
    bar = beat * 4
    chords = [Dm, Bb, F, A, Dm, Gm, Bb, A]
    # Melody: (midi, beat in the 32-beat phrase, length in beats); played twice, second time an octave lower.
    melody = [(74, 0, 2), (77, 2, 1), (76, 3, 1), (74, 4, 3), (69, 7, 1), (70, 8, 2), (74, 10, 1), (72, 11, 1),
              (70, 12, 3), (69, 15, 1), (72, 16, 2), (69, 18, 2), (65, 20, 4), (67, 24, 2), (70, 26, 1),
              (69, 27, 1), (64, 28, 3), (61, 31, 1)]
    for rep in range(2):
        off = rep * 8 * bar
        for i, c in enumerate(chords):
            place(buf, pad(c, bar + 2.5, attack=1.5, release=2.5), off + i * bar)
            place(buf, piano(c[0] - 12, 4.5, 0.55), off + i * bar, -0.3)
            for j, n in enumerate(c[1:]):
                place(buf, piano(n, 3.5, 0.25), off + i * bar + beat * (1 + j), 0.2 * (j - 1))
        for m, at, ln in melody:
            place(buf, piano(m - 12 * rep, beat * ln + 2.0, 0.8), off + at * beat, 0.15)


def lonely(buf):
    seg = 8.0
    chords = [[50, 57, 64, 65, 69], [46, 53, 57, 62, 69], [43, 50, 58, 62, 65], [45, 52, 57, 61, 64]]
    for i in range(8):
        place(buf, pad(chords[i % 4], seg + 4, attack=3.5, release=4.0, bright=650, gain=0.14), i * seg)
    notes = [81, 77, 74, 76, 69, 72, 74, 70]
    for i, m in enumerate(notes):
        place(buf, piano(m, 6.0, 0.45), i * seg + 2.5 + rng.random() * 3, rng.uniform(-0.6, 0.6))


def tension(buf):
    length = 48.0
    # Heartbeat: two low thumps a second apart.
    beat = 60 / 56
    k = 0.0
    while k < length:
        for dt, v in ((0.0, 1.0), (0.26, 0.6)):
            tt = t_axis(0.5)
            thump = np.sin(2 * np.pi * (48 + 30 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 9) * v * 0.6
            place(buf, thump, k + dt)
        k += beat
    # A cluster that slowly swells and falls back, plus a thin high whine.
    place(buf, pad([38, 50, 51, 57], length + 4, attack=10, release=8, bright=500, gain=0.18), 0)
    place(buf, pad([86, 87], length, attack=14, release=10, bright=3000, gain=0.02), 2)
    for i, m in enumerate([62, 63, 62, 58, 62, 63]):
        place(buf, piano(m, 5.0, 0.3), 4 + i * 7.5, rng.uniform(-0.5, 0.5))


def dread(buf):
    length = 9.0
    t = t_axis(length)
    k = (t / length) ** 2
    raw = rng.standard_normal(len(t))
    noise = lowpass(raw, 200) * (1 - k) + lowpass(raw, 3000) * k
    swell = noise * (t / length) ** 2 * 0.25
    place(buf, swell, 0)
    place(buf, pad([38, 39, 45], length, attack=6, release=0.4, bright=900, gain=0.2), 0)


save("theme", loop(theme, 16 * 4 * 60 / 62))
save("lonely", loop(lonely, 64.0))
save("tension", loop(tension, 48.0))
dread_buf = np.zeros((int(13 * RATE), 2))
dread(dread_buf)
save("dread", reverb(dread_buf), 0.8)
