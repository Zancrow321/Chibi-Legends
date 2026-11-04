#!/usr/bin/env python3
"""Baut aus den PixelLab-Rohbildern (assets/enemies/raw/<gegner>/<anim>_<i>.png)
Animations-Streifen für das Spiel: assets/enemies/<gegner>/<anim>.png (64x64 je
Bild, nebeneinander). Entfernt den grauen Bodenschatten, den PixelLab unter
die Figuren malt (das Spiel zeichnet einen eigenen), und verwirft Bilder mit
Artefakten (Liste PICK). Kostet keine Generierungen.

    python3 -I tools/enemies/finish.py
"""
import json, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "enemies" / "raw"
OUT = ROOT / "assets" / "enemies"

## Welche Rohbilder in welcher Reihenfolge in den Streifen kommen.
PICK = {
    "moosling": {
        "idle": list(range(9)),
        "attack": [0, 1, 2, 3, 4, 8],
        "hurt": [1, 2, 3, 4],
    },
    "rindenwicht": {
        "walk": list(range(1, 9)),
        "attack": list(range(9)),
        "hurt": [0, 1, 3, 4],  # Bild 2 hat einen Funken-Artefakt
        "death": list(range(9)),
    },
}


def _is_shadow(p) -> bool:
    r, g, b, a = p
    if a == 0:
        return False
    return max(r, g, b) - min(r, g, b) < 22 and 95 < r < 170


def clean(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(int(h * 0.72), h):
        for x in range(w):
            if _is_shadow(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    return im


## Bilder pro Sekunde je Animation (im Spiel)
FPS = {"idle": 8.0, "walk": 10.0, "attack": 12.0, "hurt": 14.0, "death": 11.0}


def main() -> None:
    meta_path = OUT / "frames.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    for name, anims in PICK.items():
        (OUT / name).mkdir(parents=True, exist_ok=True)
        meta[name] = {"source": "pixellab", "cell": [64, 64], "foot": 59, "anims": {}}
        for anim, idx in anims.items():
            frames = [clean(Image.open(RAW / name / f"{anim}_{i}.png")) for i in idx]
            strip = Image.new("RGBA", (64 * len(frames), 64))
            for i, f in enumerate(frames):
                strip.alpha_composite(f, (64 * i, 0))
            strip.save(OUT / name / f"{anim}.png")
            meta[name]["anims"][anim] = [len(frames), FPS[anim]]
        print(name, meta[name])
    meta_path.write_text(json.dumps(meta, indent=1))


if __name__ == "__main__":
    main()
