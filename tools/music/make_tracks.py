"""Background songs for «От нуля до миллиардера», synthesized from scratch.

Writes four tracks with real melodies to assets/audio/music/track_*.ogg; the
game plays them one after another. Each has its own mood: lo-fi city, bright
morning pop, an evening bossa and a piano dream. Run from the repository root:
    python3 tools/music/make_tracks.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = "assets/audio/music"


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, cutoff):
    size = 1 << int(np.ceil(np.log2(len(x) + 1)))
    w = 2 * np.pi * np.fft.rfftfreq(size, 1 / RATE) / RATE
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    h = (a / (1 - (1 - a) * np.exp(-1j * w))) ** 2
    return np.fft.irfft(np.fft.rfft(x, size) * h, size)[:len(x)]


# --- Instruments --------------------------------------------------------------------

def epiano(midi, length, vel=1.0):
    """A Rhodes-like electric piano: FM with a bell that fades into a warm tone."""
    t = t_axis(length + 0.6)
    f = hz(midi)
    index = 1.8 * np.exp(-t * 3.0) + 0.25
    s = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    s += 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 4)
    env = np.minimum(1, t * 200) * np.exp(-t * 1.1)
    env *= np.clip((length + 0.6 - t) / 0.6, 0, 1)
    return s * env * vel * 0.32


def piano(midi, length, vel=1.0, seed=0):
    t = t_axis(length + 1.2)
    f = hz(midi)
    s = np.zeros_like(t)
    for k in range(1, 8):
        fk = f * k * np.sqrt(1 + 0.0004 * k * k)
        if fk > RATE / 2.2:
            break
        s += np.sin(2 * np.pi * fk * t) * (0.85 ** k) / k * np.exp(-t * (0.7 + 0.6 * k))
    env = np.minimum(1, t * 400) * np.clip((length + 1.2 - t) / 1.0, 0, 1)
    return s * env * vel * 0.5


def bell(midi, length, vel=1.0):
    """A vibraphone: pure partials with a slow tremolo."""
    t = t_axis(length + 1.5)
    f = hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 4.0 * f * t) * np.exp(-t * 6)
    trem = 1 + 0.25 * np.sin(2 * np.pi * 5.0 * t)
    env = np.minimum(1, t * 300) * np.exp(-t * 1.6) * np.clip((length + 1.5 - t) / 0.5, 0, 1)
    return s * trem * env * vel * 0.35


def lead(midi, length, vel=1.0):
    """A soft flute-like lead with a little vibrato coming in late."""
    t = t_axis(length + 0.25)
    f = hz(midi)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t * 2)
    ph = 2 * np.pi * f * np.cumsum(vib) / RATE
    s = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    env = np.minimum(1, t * 25) * np.clip((length + 0.25 - t) / 0.25, 0, 1) * (0.85 + 0.15 * np.exp(-t * 3))
    return s * env * vel * 0.3


def pluck(midi, length, vel=1.0):
    t = t_axis(min(length, 0.6) + 0.3)
    f = hz(midi)
    s = np.zeros_like(t)
    for k in range(1, 6):
        s += np.sin(2 * np.pi * f * k * t) / k * np.exp(-t * (5 + 4 * k))
    return s * np.minimum(1, t * 600) * vel * 0.4


def bass(midi, length, vel=1.0):
    t = t_axis(length + 0.1)
    f = hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 5)
    env = np.minimum(1, t * 300) * np.exp(-t * 1.2) * np.clip((length + 0.1 - t) / 0.1, 0, 1)
    return s * env * vel * 0.55


def pad(midis, length, bright=1200.0):
    t = t_axis(length)
    s = np.zeros_like(t)
    for m in midis:
        for d in (-0.08, 0.0, 0.08):
            f = hz(m + d)
            ph = (f * t) % 1.0
            s += (2 * ph - 1) * 0.5
    s = lowpass(s / (len(midis) * 3), bright)
    env = np.minimum(1, t / 0.8) * np.clip((length - t) / 0.8, 0, 1)
    return s * env * 0.35


def kick(seed=0):
    t = t_axis(0.35)
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 9) * 0.9


def snare(rng):
    t = t_axis(0.25)
    noise = lowpass(rng.standard_normal(len(t)), 5000) * np.exp(-t * 16)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return (noise * 0.5 + tone * 0.4) * 0.6


def hat(rng, open_=False):
    t = t_axis(0.25 if open_ else 0.06)
    n = rng.standard_normal(len(t))
    n = n - lowpass(n, 7000)
    return n * np.exp(-t * (12 if open_ else 60)) * 0.22


def rim(rng):
    t = t_axis(0.05)
    return np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 120) * 0.35


def shaker(rng):
    t = t_axis(0.08)
    n = rng.standard_normal(len(t))
    n = n - lowpass(n, 5000)
    return n * np.minimum(1, t * 200) * np.exp(-t * 45) * 0.12


def reverb(x, seconds=2.2, mix=0.25, seed=3):
    rng = np.random.default_rng(seed)
    t = t_axis(seconds)
    ir = rng.standard_normal(len(t)) * np.exp(-t * 6.9 / seconds)
    ir = lowpass(ir, 4500)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x)]
    return x * (1 - mix) + wet * mix * 1.5


# --- Composition --------------------------------------------------------------------

# Melodic shapes for one bar, in steps of the scale from the bar's first note.
CONTOURS = [[0, 1, 2, 4], [0, 2, 1, -1], [0, -1, -2, 2], [0, 2, 4, 2], [0, 4, 3, 1], [0, -2, -1, 1], [0, 1, -1, -3]]


def melody(rng, chords, scale, bars, low, high, rhythms):
    """Two four-bar phrases: a call that climbs and an answer that comes home.
    Each bar starts on a chord tone near the phrase's arc and follows one of
    two motifs (shape + rhythm); every phrase ends on a long chord tone."""
    steps = [m for m in range(low - 5, high + 6) if m % 12 in scale]
    motifs = [(rhythms[rng.integers(len(rhythms))], CONTOURS[rng.integers(len(CONTOURS))]) for _ in range(2)]
    notes = []
    half = bars // 2
    span = high - low
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        tones = [c % 12 for c in chord]
        pos = bar % half
        phrase = bar // half
        # The arc: the call peaks late, the answer peaks early and falls.
        k = (pos + 1) / half
        lift = np.sin(np.pi * k * 0.9) if phrase == 0 else np.sin(np.pi * (0.35 + 0.65 * k))
        target = low + span * (0.25 + 0.55 * lift) + (2 if phrase == 1 and pos == 1 else 0)
        starts = [m for m in range(low, high + 1) if m % 12 in tones]
        start = min(starts, key=lambda m: abs(m - target) + rng.random() * 2)
        if pos == half - 1:
            end_tones = [m for m in range(low, high + 1) if m % 12 in (tones[0], tones[1]) or (phrase == 0 and m % 12 == tones[2])]
            land = min(end_tones, key=lambda m: abs(m - (low + span * (0.3 if phrase else 0.5))))
            if rng.random() < 0.5:
                notes.append((bar * 4, 1.0, start))
                notes.append((bar * 4 + 1.0, 3.0, land))
            else:
                notes.append((bar * 4, 4.0, land))
            continue
        rhythm, contour = motifs[pos % 2]
        if phrase == 1 and pos % 2 == 1:
            contour = [-c for c in contour]
        idx = steps.index(start)
        for n, (beat, dur) in enumerate(rhythm):
            m = steps[max(0, min(len(steps) - 1, idx + contour[n % len(contour)]))]
            notes.append((bar * 4 + beat, dur, m))
    return notes


def render(spec):
    rng = np.random.default_rng(spec["seed"])
    beat = 60.0 / spec["bpm"]
    form = spec["form"]
    bars = sum(n for _, n, _ in form)
    total = bars * 4 * beat + 4.0
    n = int(total * RATE)
    L = np.zeros(n)
    R = np.zeros(n)

    def add(sig, at, pan=0.0, gain=1.0):
        i = int(at * RATE)
        if i >= n:
            return
        sig = sig[: n - i] * gain
        L[i:i + len(sig)] += sig * (1 - pan) * 0.5 * 2 ** 0.5
        R[i:i + len(sig)] += sig * (1 + pan) * 0.5 * 2 ** 0.5

    drums = {"kick": kick(), "snare": snare(rng), "hat": hat(rng), "ohat": hat(rng, True), "rim": rim(rng), "shaker": shaker(rng)}
    bar0 = 0
    for section, count, layers in form:
        prog = spec["progs"][section]
        mel = []
        if "mel" in layers:
            mel = melody(rng, prog, spec["scale"], count, spec["mel_low"], spec["mel_high"], spec["rhythms"])
        for b in range(count):
            chord = prog[b % len(prog)]
            t0 = (bar0 + b) * 4 * beat
            # Chords.
            if "chords" in layers:
                spec["comp"](add, chord, t0, beat, rng)
            if "pad" in layers:
                add(pad(chord, 4 * beat + 0.8, spec.get("pad_bright", 1100)), t0, 0.0, spec.get("pad_gain", 1.0))
            # Bass.
            if "bass" in layers:
                for bt, dur, off in spec["bassline"]:
                    m = 36 + (chord[0] - 36) % 12 + off
                    add(bass(m, dur * beat * 0.95), t0 + bt * beat, 0.0, spec.get("bass_gain", 1.0))
            # Drums, with a little swing on the off-beats.
            if "drums" in layers:
                for name, hits in spec["groove"].items():
                    for h in hits:
                        sw = spec.get("swing", 0.0) * beat if (h * 2) % 2 == 1 else 0.0
                        vel = 0.8 + 0.2 * rng.random()
                        add(drums[name], t0 + h * beat + sw, {"hat": 0.3, "ohat": 0.3, "shaker": -0.3, "rim": -0.2}.get(name, 0.0),
                            vel * spec.get("drum_gain", 1.0))
        for at, dur, m in mel:
            add(spec["voice"](m, dur * beat * 0.95, 0.9 + 0.1 * rng.random()), bar0 * 4 * beat + at * beat, 0.1, spec.get("mel_gain", 1.0))
        bar0 += count
    L = reverb(L, mix=spec.get("verb", 0.25), seed=1)
    R = reverb(R, mix=spec.get("verb", 0.25), seed=2)
    if spec.get("crackle"):
        c = (rng.random(n) < 0.0004) * rng.standard_normal(n) * 0.08
        L += lowpass(c, 3000)
        R += lowpass(c, 3000)
    t = np.arange(n) / RATE
    fade = np.minimum(1, t / 1.5) * np.clip((total - t) / 3.5, 0, 1)
    out = np.stack([L * fade, R * fade], axis=1)
    out /= np.max(np.abs(out)) / 0.85
    return out


def comp_epiano(add, chord, t0, beat, rng):
    # Laid-back chords: on 1, a push before 3.
    for bt, dur in [(0.0, 1.8), (1.5, 0.4), (2.5, 1.5)]:
        for j, m in enumerate(chord[1:]):
            add(epiano(m, dur * beat, 0.7), t0 + bt * beat + j * 0.012, -0.25 + 0.15 * j)


def comp_pluck(add, chord, t0, beat, rng):
    tones = chord[1:] + [chord[1] + 12]
    for i in range(8):
        add(pluck(tones[i % len(tones)] + 12, 0.5 * beat, 0.6), t0 + i * 0.5 * beat, -0.4 + 0.8 * (i % 2))


def comp_bossa(add, chord, t0, beat, rng):
    for bt in [0.0, 1.5, 2.5, 3.0]:
        for j, m in enumerate(chord[1:]):
            add(epiano(m, 0.45 * beat, 0.55), t0 + bt * beat + j * 0.01, -0.3)


def comp_piano(add, chord, t0, beat, rng):
    tones = [chord[0] + 12] + chord[1:] + [chord[1] + 12]
    for i, bt in enumerate([0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]):
        add(piano(tones[[0, 2, 3, 4, 1, 2, 3, 2][i] % len(tones)], 1.6 * beat, 0.45), t0 + bt * beat, -0.2)


# Chords: [bass root, voicing...].
LOFI = {
    "a": [[41, 64, 67, 69, 72], [40, 62, 67, 71, 74], [38, 60, 65, 69, 72], [43, 62, 65, 69, 71]],
    "b": [[46, 62, 65, 69, 72], [45, 60, 64, 67, 71], [38, 60, 65, 69, 72], [43, 62, 65, 67, 71]],
}
POP = {
    "a": [[48, 64, 67, 72], [43, 62, 67, 71], [45, 64, 69, 72], [41, 65, 69, 72]],
    "b": [[41, 65, 69, 72], [43, 62, 67, 71], [40, 64, 67, 71], [45, 64, 69, 72]],
}
BOSSA = {
    "a": [[38, 60, 65, 69, 72], [43, 59, 65, 69, 71], [36, 59, 64, 67, 71], [45, 61, 64, 67, 70]],
    "b": [[41, 64, 67, 69, 72], [40, 62, 67, 71, 74], [45, 60, 64, 67, 71], [43, 59, 62, 65, 69]],
}
DREAM = {
    "a": [[45, 60, 64, 69], [41, 60, 65, 69], [48, 60, 64, 67], [43, 59, 62, 67]],
    "b": [[41, 60, 65, 69], [43, 62, 67, 71], [45, 60, 64, 69], [40, 59, 64, 68]],
}

# A minor shares its notes with C major.
C_MAJOR = [0, 2, 4, 5, 7, 9, 11]
A_MINOR = C_MAJOR

SONGS = [
    {"name": "track_city", "seed": 11, "bpm": 82, "scale": C_MAJOR, "progs": LOFI, "voice": bell,
     "mel_low": 72, "mel_high": 86, "comp": comp_epiano, "swing": 0.16, "crackle": True, "verb": 0.3,
     "rhythms": [[(0.0, 1.5), (1.5, 0.5), (2.0, 1.0), (3.0, 1.0)], [(0.5, 0.5), (1.0, 1.0), (2.5, 1.5)],
                 [(0.0, 0.5), (0.5, 0.5), (1.0, 2.0), (3.0, 0.5), (3.5, 0.5)]],
     "bassline": [(0.0, 1.5, 0), (1.5, 0.5, 7), (2.5, 1.5, 0)],
     "groove": {"kick": [0.0, 1.5, 2.5], "snare": [1.0, 3.0], "hat": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]},
     "drum_gain": 0.8,
     "form": [("a", 4, ["chords", "bass", "drums"]), ("a", 8, ["chords", "bass", "drums", "mel"]),
              ("b", 8, ["chords", "bass", "drums", "mel"]), ("a", 8, ["chords", "bass", "drums", "mel"]),
              ("a", 4, ["chords", "bass"])]},
    {"name": "track_morning", "seed": 23, "bpm": 104, "scale": C_MAJOR, "progs": POP, "voice": lead,
     "mel_low": 69, "mel_high": 84, "comp": comp_pluck, "verb": 0.22,
     "rhythms": [[(0.0, 1.0), (1.0, 0.5), (1.5, 0.5), (2.0, 2.0)], [(0.0, 0.5), (0.5, 1.0), (1.5, 0.5), (2.0, 1.0), (3.0, 1.0)],
                 [(0.0, 2.0), (2.0, 0.5), (2.5, 0.5), (3.0, 1.0)]],
     "bassline": [(0.0, 0.5, 0), (0.5, 0.5, 0), (1.5, 0.5, 12), (2.0, 0.5, 0), (2.5, 0.5, 0), (3.0, 0.5, 7), (3.5, 0.5, 12)],
     "groove": {"kick": [0.0, 2.0, 2.5], "snare": [1.0, 3.0], "hat": [0.5, 1.5, 2.5, 3.5], "shaker": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]},
     "pad_gain": 0.6, "drum_gain": 0.85,
     "form": [("a", 4, ["chords", "pad"]), ("a", 8, ["chords", "pad", "bass", "drums", "mel"]),
              ("b", 8, ["chords", "bass", "drums", "mel"]), ("a", 8, ["chords", "pad", "bass", "drums", "mel"]),
              ("a", 4, ["chords", "pad"])]},
    {"name": "track_evening", "seed": 37, "bpm": 92, "scale": C_MAJOR, "progs": BOSSA, "voice": bell,
     "mel_low": 69, "mel_high": 83, "comp": comp_bossa, "verb": 0.28, "swing": 0.0,
     "rhythms": [[(0.0, 1.5), (1.5, 1.0), (2.5, 1.5)], [(0.5, 1.0), (1.5, 0.5), (2.0, 2.0)],
                 [(0.0, 0.5), (0.5, 1.0), (1.5, 1.5), (3.0, 1.0)]],
     "bassline": [(0.0, 1.5, 0), (1.5, 0.5, 7), (2.0, 1.5, 7), (3.5, 0.5, 0)],
     "groove": {"rim": [0.0, 0.75, 1.5, 2.5, 3.25], "shaker": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], "kick": [0.0, 1.5, 2.0, 3.5]},
     "drum_gain": 0.7,
     "form": [("a", 4, ["chords", "bass", "drums"]), ("a", 8, ["chords", "bass", "drums", "mel"]),
              ("b", 8, ["chords", "bass", "drums", "mel"]), ("a", 8, ["chords", "bass", "drums", "mel"]),
              ("b", 4, ["chords", "bass"])]},
    {"name": "track_dream", "seed": 41, "bpm": 76, "scale": A_MINOR, "progs": DREAM, "voice": piano,
     "mel_low": 72, "mel_high": 88, "comp": comp_piano, "verb": 0.35, "pad_bright": 900, "pad_gain": 0.8, "mel_gain": 1.1,
     "rhythms": [[(0.0, 1.0), (1.0, 1.0), (2.0, 2.0)], [(0.0, 1.5), (1.5, 0.5), (2.0, 1.0), (3.0, 1.0)],
                 [(0.0, 2.0), (2.0, 1.0), (3.0, 1.0)]],
     "bassline": [(0.0, 4.0, 0)], "bass_gain": 0.6,
     "groove": {"kick": [0.0, 2.5], "snare": [2.0], "hat": [1.0, 3.0]}, "drum_gain": 0.45,
     "form": [("a", 4, ["chords"]), ("a", 8, ["chords", "mel", "pad"]),
              ("b", 8, ["chords", "mel", "pad", "bass", "drums"]), ("a", 8, ["chords", "mel", "pad", "bass"]),
              ("a", 4, ["chords", "pad"])]},
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for song in SONGS:
        data = render(song)
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "x.wav")
            with wave.open(wav, "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes((data * 32767).astype(np.int16).tobytes())
            out = os.path.join(OUT, song["name"] + ".ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", out], check=True)
        print(out, "%.0f s" % (len(data) / RATE), os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
