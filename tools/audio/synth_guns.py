"""Eigene Sounds für den Kampfstil Bollwerk (Schüsse, Nachladen, Explosion,
Schild, Ladestrahl, Haken). Rauschen, Sinus und Hüllkurven, keine fremden Samples.
Aufruf: python3 tools/audio/synth_guns.py  -> assets/audio/sfx/bw_*.wav"""
import pathlib, wave
import numpy as np

SR = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/audio/sfx"
rng = np.random.default_rng(117)


def t(d):
    return np.arange(int(SR * d)) / SR


def lowpass(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack, decay_k):
    tt = np.arange(n) / SR
    e = np.minimum(1.0, tt / max(attack, 1e-4)) * np.exp(-tt * decay_k)
    return e


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())


def shot(seed, pitch):
    n = int(SR * 0.22)
    noise = np.random.default_rng(seed).standard_normal(n)
    crack = noise * env(n, 0.0005, 60)
    body = lowpass(noise, 900 * pitch) * env(n, 0.001, 22) * 2.5
    tt = t(0.22)
    thump = np.sin(2 * np.pi * (120 * pitch) * tt * (1 - tt * 1.5)) * env(n, 0.001, 30) * 0.8
    return crack * 0.6 + body + thump


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("bw_shot_1", shot(1, 1.0), 0.8)
    save("bw_shot_2", shot(2, 1.12), 0.8)
    save("bw_shot_heavy", shot(3, 0.7) * 1.2 + np.pad(shot(4, 0.55), (0, 0)) * 0.6, 0.9)
    # Nachladen: zwei metallische Klicks
    n = int(SR * 0.5)
    x = np.zeros(n)
    for start, f in ((0.02, 2400), (0.30, 1800)):
        s = int(SR * start); m = int(SR * 0.08)
        tt = t(0.08)
        click = (np.sin(2 * np.pi * f * tt) + 0.6 * np.sin(2 * np.pi * f * 1.51 * tt)) * env(m, 0.0003, 70)
        click += rng.standard_normal(m) * env(m, 0.0002, 140) * 0.7
        x[s:s + m] += click
    save("bw_reload", x, 0.6)
    # Explosion
    n = int(SR * 1.2)
    noise = rng.standard_normal(n)
    boom = lowpass(noise, 400) * env(n, 0.003, 3.5) * 4
    crackle = noise * env(n, 0.001, 12) * 0.5
    tt = t(1.2)
    sub = np.sin(2 * np.pi * 55 * tt * (1 - tt * 0.3)) * env(n, 0.002, 4) * 1.4
    save("bw_explosion", boom + crackle + sub, 0.95)
    # Schild fängt ab: kurzes elektrisches Zirpen
    n = int(SR * 0.25)
    tt = t(0.25)
    zap = np.sign(np.sin(2 * np.pi * (900 - 2000 * tt) * tt)) * env(n, 0.001, 18) * 0.4
    zap += np.sin(2 * np.pi * 1400 * tt) * env(n, 0.001, 25) * 0.5
    save("bw_shield_hit", zap, 0.55)
    # Schildbruch: glasig, absteigend
    n = int(SR * 0.7)
    tt = t(0.7)
    br = sum(np.sin(2 * np.pi * f * tt * (1 - tt * 0.6)) * env(n, 0.001, 6 + i * 2) for i, f in enumerate((1800, 2700, 3900)))
    br += rng.standard_normal(n) * env(n, 0.001, 20) * 0.6
    save("bw_shield_break", br, 0.8)
    # Ladestrahl: ansteigender Ton
    n = int(SR * 1.0)
    tt = t(1.0)
    f = 200 + 1600 * tt ** 2
    ch = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, tt * 3) * 0.6
    ch += np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR) * 0.2 * tt
    save("bw_charge", ch, 0.5)
    # Strahl: tiefes Brummen mit Rauschen
    n = int(SR * 0.9)
    tt = t(0.9)
    beam = (np.sin(2 * np.pi * 70 * tt) + 0.5 * np.sign(np.sin(2 * np.pi * 140 * tt))) * env(n, 0.005, 3)
    beam += lowpass(rng.standard_normal(n), 2500) * env(n, 0.002, 4) * 2
    save("bw_beam", beam, 0.9)
    # Haken: kurzes metallisches Sirren
    n = int(SR * 0.35)
    tt = t(0.35)
    hk = np.sin(2 * np.pi * np.cumsum(3000 - 5000 * tt) / SR) * env(n, 0.001, 9) * 0.5
    hk += rng.standard_normal(n) * env(n, 0.001, 30) * 0.3
    save("bw_hook", hk, 0.55)
    # leer: trockenes Klicken
    n = int(SR * 0.08)
    save("bw_empty", rng.standard_normal(n) * env(n, 0.0002, 120), 0.4)


if __name__ == "__main__":
    main()
