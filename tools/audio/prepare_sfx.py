"""Prepare own sound effects (e.g. from Stable Audio 3) for the game.

    python3 tools/audio/prepare_sfx.py rohdaten/schlag_*.wav --out assets/audio/sfx/kampf
    python3 tools/audio/prepare_sfx.py rohdaten/ --out assets/audio/sfx --lufs -16 --max-len 1.5

Per file (needs ffmpeg):
1. cut silence at start and end (generators often add 0.2-1 s)
2. optional: cut to --max-len seconds with a short fade-out
3. loudness to a common level (EBU R128, default -18 LUFS for SFX)
4. mono, 44.1 kHz, OGG Vorbis (small for the web build)

Then add the file to assets/audio/sfx_map.json and note the source in
assets/audio/SOURCES.md (tool, prompt, date) so every sound stays traceable.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

AUDIO_EXT = {".wav", ".mp3", ".ogg", ".flac", ".m4a", ".aiff"}


def build_filter(lufs: float, max_len: float) -> str:
    trim = ("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.01,"
            "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.02,areverse")
    parts = [trim]
    if max_len > 0:
        parts.append(f"atrim=0:{max_len},afade=t=out:st={max(0.0, max_len - 0.08)}:d=0.08")
    parts.append(f"loudnorm=I={lufs}:TP=-1.5:LRA=11")
    return ",".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--out", required=True, help="Zielordner, z. B. assets/audio/sfx")
    ap.add_argument("--lufs", type=float, default=-18.0, help="Ziel-Lautheit (SFX -18, laute Treffer -16)")
    ap.add_argument("--max-len", type=float, default=0.0, help="maximale Länge in Sekunden (0 = aus)")
    ap.add_argument("--stereo", action="store_true", help="Stereo behalten (Standard: mono)")
    args = ap.parse_args()
    if not shutil.which("ffmpeg"):
        print("ffmpeg fehlt")
        return 1
    files = []
    for p in map(Path, args.paths):
        files += sorted(f for f in p.rglob("*") if f.suffix.lower() in AUDIO_EXT) if p.is_dir() else [p]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for f in files:
        dst = out / (f.stem.lower().replace(" ", "_") + ".ogg")
        cmd = ["ffmpeg", "-loglevel", "error", "-y", "-i", str(f), "-af", build_filter(args.lufs, args.max_len),
               "-ar", "44100", "-ac", "2" if args.stereo else "1", "-c:a", "libvorbis", "-q:a", "5", str(dst)]
        subprocess.run(cmd, check=True)
        print(f"{f} -> {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
