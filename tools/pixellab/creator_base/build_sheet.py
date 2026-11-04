"""Baut Sheet und Vorschau aus den erzeugten Einzelbildern.

Aufruf: python3 build_sheet.py <ordner mit frames> <sheet.png> <vorschau.png> [--anchors] [anchors.json]
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

frames = [f for g in json.load(open(Path(__file__).with_name("frames.json"))) for f in g["frames"]]
src = Path(sys.argv[1])
COLS = 10
rows = (len(frames) + COLS - 1) // COLS
sheet = Image.new("RGBA", (COLS * 64, rows * 64), (0, 0, 0, 0))
for i, f in enumerate(frames):
    im = Image.open(src / f"{f['name']}.png").convert("RGBA")
    sheet.alpha_composite(im, ((i % COLS) * 64, (i // COLS) * 64))
sheet.save(sys.argv[2])

S = 4
prev = Image.new("RGBA", (COLS * 64 * S, rows * (64 * S + 16)), (34, 38, 52, 255))
d = ImageDraw.Draw(prev)
show = "--anchors" in sys.argv
measured = {}
for a in sys.argv[4:]:
    if a.endswith(".json"):
        measured = {f["name"]: f for f in json.load(open(a))["frames"]}
for i, f in enumerate(frames):
    x, y = (i % COLS) * 64 * S, (i // COLS) * (64 * S + 16)
    cell = Image.new("RGBA", (64, 64), (52, 58, 78, 255))
    cell.alpha_composite(Image.open(src / f"{f['name']}.png").convert("RGBA"))
    cell = cell.resize((64 * S, 64 * S), Image.NEAREST)
    prev.alpha_composite(cell, (x, y + 16))
    d.text((x + 4, y + 2), f["name"], fill=(230, 230, 230))
    if show:
        for key, col in (("head", (255, 220, 60)), ("hand_front", (255, 70, 70)), ("hand_back", (70, 160, 255)), ("back", (80, 230, 120))):
            px, py = (measured.get(f["name"]) or f["anchors"])[key]["pos"]
            ang = (measured.get(f["name"]) or f["anchors"])[key]["angle"]
            cx, cy = x + px * S, y + 16 + py * S
            d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], outline=col, width=2)
            if key.startswith("hand"):
                import math
                r = math.radians(ang)
                d.line([cx, cy, cx + math.sin(r) * 40, cy + math.cos(r) * 40], fill=col, width=2)
prev.save(sys.argv[3])
print(len(frames), "Frames")
