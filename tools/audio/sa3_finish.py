"""Pick the best Stable Audio 3 takes and convert them for the game.

    <python mit av+numpy> tools/audio/sa3_finish.py G:/Comfy-Desktop/ComfyUI-Shared/output/chibi-sfx

Per event from sa3_prompts.json: decode every raw take in <raw>/<event>/,
trim silence, cut to max_len with a short fade, bring to the target loudness
(gated RMS, peak limit -1 dBFS), score it and keep the best `keep` takes as
mono 44.1 kHz WAV (Godot: QOA) in assets/audio/sfx/sa3/. Writes assets/audio/sfx/sa3/picks.json
(event -> files, prompt, seed, score) for SOURCES.md and sfx_map.json.

Score = clear transient + energy in the front part + little dead air
- penalty for clipping and for flat hiss. It only weeds out weak takes;
listen before shipping. Needs PyAV and numpy (both in ComfyUI's venv).
"""

from __future__ import annotations

import json
import re
import wave
import sys
from pathlib import Path

import av
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SR = 44100
OUT = ROOT / "assets/audio/sfx/sa3"


def decode(path: Path) -> np.ndarray:
    with av.open(str(path)) as f:
        rs = av.AudioResampler(format="flt", layout="mono", rate=SR)
        chunks = []
        for frame in f.decode(audio=0):
            for r in rs.resample(frame):
                chunks.append(r.to_ndarray().reshape(-1))
        for r in rs.resample(None):
            chunks.append(r.to_ndarray().reshape(-1))
    return np.concatenate(chunks).astype(np.float32)


def envelope_db(x: np.ndarray, win: int = 441) -> np.ndarray:
    n = len(x) // win
    if n == 0:
        return np.array([-120.0])
    rms = np.sqrt(np.mean(x[: n * win].reshape(n, win) ** 2, axis=1) + 1e-12)
    return 20 * np.log10(rms)


def process(x: np.ndarray, max_len: float, lufs: float) -> tuple[np.ndarray, float]:
    x = x - np.mean(x)
    env = envelope_db(x)
    peak_db = env.max()
    active = np.where(env > peak_db - 40)[0]
    if len(active) == 0 or peak_db < -60:
        return x[:0], -1e9
    win = 441
    start = max(0, active[0] * win - 64)  # keep a tiny pre-roll so the attack is intact
    end = min(len(x), (active[-1] + 1) * win)
    y = x[start:end].copy()
    if max_len > 0 and len(y) > int(max_len * SR):
        y = y[: int(max_len * SR)]
    fade = min(len(y) // 4, int(0.06 * SR))
    if fade > 0:
        y[-fade:] *= np.linspace(1, 0, fade) ** 2
    y[:32] *= np.linspace(0, 1, 32)

    # loudness: gated RMS of the louder blocks (close to LUFS for short SFX)
    e = envelope_db(y)
    gated = e[e > e.max() - 20]
    level = 10 * np.log10(np.mean(10 ** (gated / 10)) + 1e-12)
    y *= 10 ** ((lufs + 3.0 - level) / 20)  # +3: short sounds read quieter than LUFS
    pk = np.max(np.abs(y)) + 1e-9
    if pk > 0.89:  # -1 dBFS soft limit
        y = np.tanh(y / pk * 1.6) / np.tanh(1.6) * 0.89

    # score
    e = envelope_db(y)
    n = len(e)
    attack = e[: max(1, n // 5)].max() - np.median(e)  # transient strength
    front = np.mean(e[: max(1, n // 2)]) - np.mean(e[max(1, n // 2):]) if n > 3 else 0
    dead = np.mean(e < e.max() - 35)
    spec = np.abs(np.fft.rfft(y[: min(len(y), SR)] * np.hanning(min(len(y), SR)))) + 1e-9
    flat = np.exp(np.mean(np.log(spec))) / np.mean(spec)  # 1 = white noise
    clip = np.mean(np.abs(x) > 0.99)
    score = attack * 0.6 + front * 0.3 - dead * 20 - flat * 25 - clip * 200
    return y, float(score)


def encode(y: np.ndarray, dst: Path) -> None:
    """16-bit mono WAV. Godot compresses it to QOA on import (compress/mode=2),
    which decodes without the start-up gap that MP3/OGG can add to short hits."""
    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(dst), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> int:
    raw = Path(sys.argv[1])
    only = set(sys.argv[2:])
    cfg = json.loads((ROOT / "tools/audio/sa3_prompts.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    picks_path = OUT / "picks.json"
    picks = json.loads(picks_path.read_text(encoding="utf-8")) if picks_path.exists() else {}
    for name, ev in cfg["events"].items():
        if only and name not in only:
            continue
        takes = []
        for f in sorted((raw / name).glob("*.flac")):
            y, s = process(decode(f), ev["max_len"], ev["lufs"])
            if len(y):
                seed = re.search(r"_s(\d+)_", f.name)
                takes.append((s, f, y, int(seed.group(1)) if seed else 0))
        takes.sort(key=lambda t: -t[0])
        for old in OUT.glob(f"{name}_*.wav"):
            old.unlink()
        chosen = []
        for i, (s, f, y, seed) in enumerate(takes[: ev["keep"]], 1):
            dst = OUT / f"{name}_{i}.wav"
            encode(y, dst)
            chosen.append({"file": f"assets/audio/sfx/sa3/{dst.name}", "seed": seed, "score": round(s, 1),
                           "len": round(len(y) / SR, 2)})
        picks[name] = {"prompt": f"{ev['prompt']}, {cfg['style']}. Length: {ev['seconds']:g} seconds",
                       "takes": len(takes), "files": chosen}
        print(f"{name:16s} {len(takes)} Takes -> " + ", ".join(f"{c['score']}" for c in chosen))
    picks_path.write_text(json.dumps(picks, indent=1, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
