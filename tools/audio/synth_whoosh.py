"""Erzeugt eigene Schwung-/Dash-Sounds (gefiltertes Rauschen mit Frequenz-Sweep),
damit es fuer Angriffe Platzhalter ohne fremde Lizenz gibt.
Aufruf: python3 tools/audio/synth_whoosh.py  -> assets/audio/sfx/*.wav"""
import math, wave, pathlib
import numpy as np

SR = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/audio/sfx"


def bandpass_sweep(noise, f0, f1, q):
    """Biquad-Bandpass, dessen Mittenfrequenz von f0 nach f1 laeuft."""
    out = np.zeros_like(noise)
    x1 = x2 = y1 = y2 = 0.0
    n = len(noise)
    for i in range(n):
        t = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** t
        w = 2 * math.pi * f / SR
        alpha = math.sin(w) / (2 * q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
        x = noise[i]
        y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        out[i] = y
    return out


def whoosh(name, dur, f0, f1, q, peak=0.35, attack=0.35, seed=1, sub=0.0):
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.linspace(0, 1, n)
    sig = bandpass_sweep(rng.standard_normal(n), f0, f1, q)
    # swell up, fall off (the blade passes by)
    env = np.where(t < attack, (t / attack) ** 1.5, ((1 - t) / (1 - attack)) ** 2.2)
    sig = sig * env
    if sub > 0:  # low body for heavy swings
        sig += sub * np.sin(2 * math.pi * np.cumsum(np.linspace(140, 60, n)) / SR) * env
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * peak
    fade = min(200, n // 10)
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f"{dur:.2f}s")


if __name__ == "__main__":
    whoosh("swing_light_1", 0.16, 1800, 5200, 2.2, 0.32, 0.4, seed=1)
    whoosh("swing_light_2", 0.15, 2200, 6000, 2.4, 0.32, 0.35, seed=2)
    whoosh("swing_light_3", 0.17, 1600, 4600, 2.0, 0.32, 0.45, seed=3)
    whoosh("swing_heavy_1", 0.32, 500, 2600, 1.6, 0.5, 0.5, seed=4, sub=0.25)
    whoosh("swing_heavy_2", 0.30, 600, 3000, 1.5, 0.5, 0.45, seed=5, sub=0.25)
    whoosh("dash_1", 0.24, 3000, 900, 1.2, 0.36, 0.15, seed=6)
    whoosh("dash_2", 0.22, 3400, 1000, 1.2, 0.36, 0.12, seed=7)
