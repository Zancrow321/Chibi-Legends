"""Findet Posen, in denen PixelLab die Figur nicht angezogen hat
(Kleidungsebenen deutlich kleiner als im Median des Outfits)."""
import json
import sys
from pathlib import Path
from statistics import median
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
names = [f["name"] for g in json.load(open(ROOT / "tools/pixellab/creator_base/frames.json")) for f in g["frames"]]
body = Image.open(ROOT / "assets/creator/body/sheet.png").getchannel("A")
for o in sys.argv[1:]:
    L = [Image.open(ROOT / f"assets/creator/parts/{s}/{o}.png").getchannel("A") for s in ("top", "pants", "shoes")]
    r = {}
    for i, n in enumerate(names):
        box = ((i % 10) * 64, (i // 10) * 64, (i % 10) * 64 + 64, (i // 10) * 64 + 64)
        b = sum(1 for v in body.crop(box).tobytes() if v)
        r[n] = sum(sum(1 for v in l.crop(box).tobytes() if v) for l in L) / b
    m = median(r.values())
    print(o, ",".join(n for n in names if r[n] < 0.6 * m))
