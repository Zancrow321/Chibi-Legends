#!/usr/bin/env python3
"""Baut aus den PixelLab-Rohbildern (assets/dummies/raw/<puppe>/) die Spiel-Streifen
assets/dummies/<puppe>.png: Bild 0 = Ruhe, danach die Treffer-Wackel-Bilder.
Farben werden auf die Resurrect-64-Palette gezogen. Kostet keine Generierungen.

    python3 -I tools/dummies/finish.py
"""
import pathlib, subprocess, sys, tempfile
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "dummies" / "raw"
OUT = ROOT / "assets" / "dummies"
## Puppe -> (Zellgröße, Rohbilder des Treffers in Reihenfolge, max. Farben)
PICK = {"klein": (64, [1, 2, 3, 4, 5, 6], 16), "gross": (96, [1, 2, 3, 4, 5, 6], 20)}


def main() -> None:
    for name, (cell, idx, colors) in PICK.items():
        frames = [Image.open(RAW / name / "still.png").convert("RGBA")]
        frames += [Image.open(RAW / name / f"hit_{i}.png").convert("RGBA") for i in idx]
        strip = Image.new("RGBA", (cell * len(frames), cell))
        for i, f in enumerate(frames):
            strip.alpha_composite(f, (cell * i, 0))
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / f"{name}.png"
            strip.save(src)
            subprocess.run([sys.executable, "-I", str(ROOT / "tools/palette/quantize.py"), str(src), "-o", str(OUT),
                            "--max-colors", str(colors), "--outline"], check=True)
        out = OUT / f"{name}.png"
        if not out.exists():
            q = OUT / f"{name}.q.png"
            q.rename(out)
        print(name, len(frames), "Bilder")


if __name__ == "__main__":
    main()
