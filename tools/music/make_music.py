"""Background music for СИЯНИЕ, synthesized from scratch (no samples).

Writes a seamless, calm loop to assets/audio/music/ambient.ogg: warm
major-seventh pads, a soft piano that wanders in gentle arpeggios and a
glassy bell now and then. Run from the repository root:
    python3 tools/music/make_music.py
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



def bell(midi, length=5.0, vel=0.5):
    """A glassy celesta-like note."""
    t = t_axis(length)
    f = hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 3)
    return s * np.exp(-t * 1.6) * np.minimum(1, t * 500) * vel * 0.35


# Fmaj7 – Em7 – Dm9 – Cmaj7(add9), 70 bpm, eight bars of four beats, twice.
CHORDS = [[41, 53, 57, 60, 64], [40, 52, 55, 59, 62], [38, 50, 53, 57, 64], [36, 52, 55, 59, 62]]


def ambient(buf):
    beat = 60 / 70
    bar = beat * 4
    for rep in range(4):
        for i, c in enumerate(CHORDS):
            at = (rep * 4 + i) * bar
            place(buf, pad(c[1:], bar + 3.0, attack=1.8, release=2.8, bright=700, gain=0.10), at)
            place(buf, piano(c[0], 5.0, 0.35), at, -0.2)
            # A lazy arpeggio up through the chord, a little different each time.
            notes = [c[2] + 12, c[3] + 12, c[4] + 12, c[3] + 24 if rep % 2 else c[4] + 12]
            for j, m in enumerate(notes):
                if (rep + j + i) % 5 == 4:
                    continue
                place(buf, piano(m, 3.5, 0.22 + 0.05 * (j == 0)), at + beat * j + beat * 0.5 * (rep % 2), 0.35 - 0.2 * j)
        place(buf, bell(84 + (rep % 2) * 3, 5.0, 0.35), rep * 4 * bar + bar * 2.5, 0.5)


save("ambient", loop(ambient, 16 * 4 * 60 / 70))
