"""Erzeugt Glockenklänge für den Kampfstil Gleichklang (additive Synthese).

Eine Glocke = Summe aus Teiltönen mit typischen Glocken-Verhältnissen
(Hum, Grundton, Terz, Quinte, Oberton), jeder mit eigener Abklingzeit, plus
ein kurzer Anschlag-Klick. Keine fremden Samples, keine Lizenz nötig.

Aufruf: python3 tools/audio/synth_bell.py assets/audio/sfx
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100
PARTIALS = [(0.5, 0.35, 2.4), (1.0, 1.0, 1.6), (1.19, 0.45, 1.0), (1.5, 0.35, 0.8), (2.0, 0.4, 0.6), (2.74, 0.18, 0.35), (4.07, 0.08, 0.2)]


def bell(freq, length, gain, click=0.25, seed=1):
    random.seed(seed)
    n = int(RATE * length)
    out = []
    for i in range(n):
        t = i / RATE
        v = 0.0
        for ratio, amp, decay in PARTIALS:
            v += amp * math.exp(-t / (decay * length / 2.0)) * math.sin(2 * math.pi * freq * ratio * t + ratio)
        if t < 0.012:
            v += click * (random.random() * 2 - 1) * (1 - t / 0.012)
        attack = min(1.0, t / 0.002)
        out.append(v * attack * gain)
    peak = max(abs(x) for x in out) or 1.0
    return [x / peak * gain for x in out]


def save(path, samples):
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def main(out_dir):
    d = Path(out_dir)
    save(d / "bell_tick.wav", bell(1320.0, 0.35, 0.35, 0.1, 1))     # Taktpuls (leise)
    save(d / "bell_hit_1.wav", bell(988.0, 0.8, 0.8, 0.3, 2))       # Treffer im Takt
    save(d / "bell_hit_2.wav", bell(1046.5, 0.8, 0.8, 0.3, 3))
    save(d / "bell_big.wav", bell(196.0, 2.6, 0.95, 0.4, 4))        # Totengeläut / Meisterzug
    save(d / "bell_clear.wav", bell(1568.0, 1.6, 0.85, 0.15, 5))    # Reiner Klang


if __name__ == "__main__":
    main(sys.argv[1])
