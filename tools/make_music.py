"""Temná hudba do hry – syntetizovaná v kódu (žádné nahrávky ani kredity).

Použití:  python3 tools/make_music.py
Výstup:   art/music/<název>.ogg  (smyčky, které na sebe plynule navazují)

Každé prostředí má vlastní tóninu a nástroje:
  swamp     – líný dron, vlhké kapky (zvonky), pomalé tlumené bubny
  graveyard – smuteční zvon, chór, pohřební buben
  jungle    – kmenové bubny, nízký dron
  mountain  – vítr, studené plochy, vzdálené rohy
  castle    – varhany, chór, těžké bubny
  boss      – rychlé bubny a údery žesťů
  title     – pomalé plochy a zvony
"""
import os
import subprocess

import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(7)


def note(n):
    """MIDI číslo -> frekvence."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


def lowpass(x, fc):
    b, a = butter(2, fc / (SR / 2), "low")
    return lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    return lfilter(b, a, x)


def env(n, att, rel):
    e = np.ones(n)
    a = min(int(att * SR), n)
    r = min(int(rel * SR), n - a)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[n - r:] = np.linspace(1, 0, r)
    return e


def saw(f, n, detune=0.0):
    t = np.arange(n) / SR
    return 2.0 * ((t * f * (1 + detune)) % 1.0) - 1.0


def pad(freqs, dur, cutoff=900.0, vol=0.12):
    n = int(dur * SR)
    out = np.zeros(n)
    for f in freqs:
        for d in (-0.004, 0.0, 0.005):
            out += saw(f, n, d)
    out = lowpass(out, cutoff) / (len(freqs) * 3)
    return out * env(n, dur * 0.35, dur * 0.4) * vol


def drone(f, dur, vol=0.18):
    n = int(dur * SR)
    t = np.arange(n) / SR
    lfo = 1.0 + 0.004 * np.sin(2 * np.pi * 0.11 * t)
    x = np.sin(2 * np.pi * f * t * lfo) + 0.5 * np.sin(2 * np.pi * f * 2 * t) + 0.3 * saw(f, n)
    return lowpass(x, 400.0) * vol


def drum(vol=0.6, f0=110.0, f1=42.0, dur=0.6, noise=0.25):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 14.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t * 6.0)
    x += lowpass(rng.standard_normal(n), 900.0) * np.exp(-t * 22.0) * noise
    return x * vol


def bell(f, vol=0.18, dur=3.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 1.2), (2.76, 0.5, 2.0), (5.4, 0.25, 3.5), (0.5, 0.4, 0.8)):
        x += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * dec)
    return x * vol


def choir(freqs, dur, vol=0.1):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.0 * t + rng.random() * 6)
        x = saw(1, n) * 0  # místo pro tvar
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        x = np.sign(np.sin(ph)) * 0.3 + np.sin(ph)
        out += bandpass(x, 500.0, 1100.0) + 0.5 * bandpass(x, 250.0, 400.0)
    return out / len(freqs) * env(n, dur * 0.4, dur * 0.4) * vol


def wind(dur, vol=0.12):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.standard_normal(n)
    x = bandpass(x, 300.0, 1400.0)
    mod = 0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t) * np.sin(2 * np.pi * 0.19 * t + 1.0)
    return x * mod * vol


def brass(f, dur, vol=0.16):
    n = int(dur * SR)
    x = saw(f, n) + saw(f * 1.5, n, 0.003) * 0.5
    x = lowpass(x, 1200.0)
    return x * env(n, 0.03, dur * 0.6) * vol


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


# ---------------------------------------------------------------- skladby

def song(name, root, prog, bpm, bars, layers):
    beat = 60.0 / bpm
    bar = beat * 4
    L = bar * bars
    tail = 4.0
    buf = np.zeros(int((L + tail) * SR))
    minor = [0, 3, 7]
    for b in range(bars):
        deg = prog[b % len(prog)]
        chord = [note(root + deg + i + 12) for i in minor]
        t0 = b * bar
        if "pad" in layers:
            place(buf, pad(chord, bar + 1.0, layers.get("cut", 900.0)), t0)
        if "choir" in layers:
            place(buf, choir([note(root + deg + i + 24) for i in minor], bar + 1.0), t0)
        if "organ" in layers:
            place(buf, pad([note(root + deg + i + 24) for i in (0, 7, 12)], bar + 0.6, 2200.0, 0.07), t0)
        for k, step in enumerate(layers.get("drums", [])):
            place(buf, drum(*step[1:]), t0 + step[0] * beat)
        if "bell" in layers and (b % layers["bell"] == 0):
            place(buf, bell(note(root + deg + 24 + int(rng.choice(minor)))), t0 + beat * rng.integers(0, 4))
        if "brass" in layers and b % 2 == 1:
            place(buf, brass(note(root + deg), beat * 1.5), t0)
            place(buf, brass(note(root + deg + 3), beat * 1.5), t0 + beat * 2)
    if "drone" in layers:
        place(buf, drone(note(root - 12), L + tail, layers["drone"]), 0.0)
    if "wind" in layers:
        place(buf, wind(L + tail, layers["wind"]), 0.0)
    if "drips" in layers:
        for i in range(int(L / 1.7)):
            place(buf, bell(note(root + 36 + int(rng.choice([0, 3, 7, 10]))), 0.05, 1.2), rng.random() * L)
    # smyčka: dozvuk z konce přičíst na začátek
    n = int(L * SR)
    out = buf[:n].copy()
    out[: len(buf) - n] += buf[n:]
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.7
    os.makedirs(f"{ROOT}/art/music", exist_ok=True)
    wav = f"/tmp/{name}.wav"
    import wave
    with wave.open(wav, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((out * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "2",
                    f"{ROOT}/art/music/{name}.ogg"], check=True)
    os.remove(wav)
    print(name, round(L, 1), "s")


def main():
    slow = [(0, 0.55), (2.5, 0.25, 90.0, 40.0)]
    song("swamp", 38, [0, 0, -4, -2], 64, 8,
         {"pad": 1, "cut": 600.0, "drone": 0.2, "drips": 1, "drums": [(0, 0.45), (2, 0.25, 90.0, 40.0)]})
    song("graveyard", 45, [0, -4, -7, -5], 60, 8,
         {"pad": 1, "choir": 1, "bell": 2, "drone": 0.15, "drums": [(0, 0.5, 80.0, 35.0, 0.6, 0.1)]})
    song("jungle", 40, [0, 0, 3, -2], 92, 8,
         {"pad": 1, "cut": 700.0, "drone": 0.2,
          "drums": [(0, 0.55), (1.5, 0.3, 160.0, 70.0, 0.3), (2, 0.45), (2.75, 0.25, 200.0, 90.0, 0.25),
                    (3.5, 0.3, 160.0, 70.0, 0.3)]})
    song("mountain", 36, [0, -4, -2, -7], 58, 8,
         {"pad": 1, "cut": 1100.0, "wind": 0.18, "drone": 0.12, "brass": 1, "drums": slow})
    song("castle", 47, [0, -1, -4, -5], 66, 8,
         {"organ": 1, "choir": 1, "drone": 0.18, "bell": 4, "drums": [(0, 0.6), (2, 0.6), (3.5, 0.3)]})
    song("boss", 38, [0, 1, 0, -2], 100, 8,
         {"pad": 1, "cut": 1300.0, "drone": 0.2, "brass": 1,
          "drums": [(0, 0.6), (0.5, 0.3), (1, 0.5), (1.5, 0.3), (2, 0.6), (2.5, 0.3), (3, 0.5), (3.5, 0.4, 150.0, 60.0)]})
    song("title", 43, [0, -4, -2, -5], 54, 8,
         {"pad": 1, "cut": 800.0, "bell": 2, "drone": 0.15, "choir": 1})


if __name__ == "__main__":
    main()
