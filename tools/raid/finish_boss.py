#!/usr/bin/env python3
"""Baut aus den PixelLab-Rohbildern (assets/raid/raw/<name>/<anim>_<i>.png) die
Streifen für das Spiel: den Boss nach assets/enemies/essenwaechter/ (gleiches
Format wie die anderen Gegner, Eintrag in assets/enemies/frames.json, dort
[Bilder, Bilder pro Sekunde, Treffer-Bild]) und den Schild-Kristall nach
assets/raid/kristall.png. Kostet keine Generierungen.

    python3 -I tools/raid/finish_boss.py              (Essenwächter + Kristall)
    python3 -I tools/raid/finish_boss.py donnerhorn   (nur dieser Boss, z. B. der Weltboss)
"""
import json, pathlib, sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "raid" / "raw"
ENEMIES = ROOT / "assets" / "enemies"

## Rohbild-Auswahl, Bilder pro Sekunde, Treffer-Bild (Index im Streifen)
PICK = {
    "idle": (list(range(9)), 8.0, 0),
    "walk": (list(range(1, 9)), 9.0, 0),
    "slam": (list(range(1, 9)), 12.0, 6),
    "swipe": (list(range(1, 9)), 13.0, 5),
    "roar": (list(range(1, 9)), 10.0, 6),
    "hurt": ([1, 3, 4], 12.0, 0),
    "death": (list(range(1, 9)), 9.0, 0),
}


def strip(name: str, anim: str, idx: list, cell: int) -> Image.Image:
    frames = [Image.open(RAW / name / f"{anim}_{i}.png").convert("RGBA") for i in idx]
    out = Image.new("RGBA", (cell * len(frames), cell))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (cell * i, 0))
    return out


def boss(name: str) -> None:
    still = Image.open(RAW / name / "still.png").convert("RGBA")
    box = still.getbbox()
    (ENEMIES / name).mkdir(parents=True, exist_ok=True)
    meta_path = ENEMIES / "frames.json"
    meta = json.loads(meta_path.read_text())
    entry = {"source": "pixellab", "cell": [128, 128], "foot": box[3] - 1, "anims": {}}
    for anim, (idx, fps, hit) in PICK.items():
        strip(name, anim, idx, 128).save(ENEMIES / name / f"{anim}.png")
        entry["anims"][anim] = [len(idx), fps, hit]
    meta[name] = entry
    meta_path.write_text(json.dumps(meta, indent=1))
    print(name, entry, "bbox", box)


def main() -> None:
    if len(sys.argv) > 1:
        boss(sys.argv[1])
        return
    boss("essenwaechter")
    strip("kristall", "idle", list(range(9)), 64).save(ROOT / "assets" / "raid" / "kristall.png")
    print("kristall", Image.open(RAW / "kristall" / "still.png").getbbox())


if __name__ == "__main__":
    main()
