#!/usr/bin/env python3
"""Gummi-Klänge für den Kampfstil Spannkraft, selbst synthetisiert (keine
fremden Samples): Boing (federnder Ton mit Vibrato), Dehnen (knarzendes
Gummi), Schnapp (kurzer Peitschenknall), Prall (dumpfer Aufprall mit Luft).

    python3 -I tools/audio/synth_rubber.py
"""
import math, pathlib, random, struct, wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "audio" / "sfx"


def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in samples))


def boing(seed, f0=150.0, f1=420.0, dur=0.42):
    random.seed(seed)
    out, ph = [], 0.0
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        k = t / dur
        # pitch springs up and wobbles back like a spring
        f = f0 + (f1 - f0) * (1 - math.exp(-t * 18)) + 60 * math.sin(t * 2 * math.pi * 11) * math.exp(-t * 6)
        ph += 2 * math.pi * f / RATE
        env = min(1.0, t * 300) * math.exp(-t * 7)
        out.append(env * (math.sin(ph) + 0.35 * math.sin(2 * ph) + 0.1 * math.sin(3 * ph)))
    return out


def stretch(seed, dur=0.5):
    random.seed(seed)
    out, ph, lp = [], 0.0, 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        f = 70 + 140 * (t / dur)
        ph += 2 * math.pi * f / RATE
        creak = 1.0 if (math.sin(t * 2 * math.pi * (30 + 40 * t / dur)) > 0.6) else 0.25
        lp += (random.uniform(-1, 1) - lp) * 0.08
        env = min(1.0, t * 20) * (1 - t / dur) ** 0.5
        out.append(env * creak * (0.6 * math.sin(ph) * (1 + 0.5 * math.sin(3 * ph)) + 0.5 * lp))
    return out


def snap(seed, dur=0.16):
    random.seed(seed)
    out, lp = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        lp += (random.uniform(-1, 1) - lp) * (0.9 if t < 0.01 else 0.3)
        env = math.exp(-t * 45)
        tone = math.sin(2 * math.pi * (900 - 3000 * t) * t) * math.exp(-t * 60)
        out.append(env * lp + 0.6 * tone)
    return out


def prall(seed, dur=0.35):
    random.seed(seed)
    out, lp, ph = [], 0.0, 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        ph += 2 * math.pi * (90 * math.exp(-t * 4) + 45) / RATE
        lp += (random.uniform(-1, 1) - lp) * 0.05
        env = math.exp(-t * 10)
        out.append(env * (math.sin(ph) + 0.8 * lp * math.exp(-t * 20)))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("rubber_boing_1.wav", boing(1))
    save("rubber_boing_2.wav", boing(2, 130.0, 380.0, 0.5))
    save("rubber_stretch_1.wav", stretch(3))
    save("rubber_snap_1.wav", snap(4))
    save("rubber_snap_2.wav", snap(5, 0.2))
    save("rubber_prall_1.wav", prall(6))
    print("ok")


if __name__ == "__main__":
    main()
