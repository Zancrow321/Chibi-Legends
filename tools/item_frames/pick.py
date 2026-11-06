#!/usr/bin/env python3
"""Turns the chosen PixelLab frame candidates (raw/<rarity>_<seed>.png) into
assets/items/frames/<rarity>.png: the hollow frame (ItemFrame draws the slot
background itself and nine-slices the same PNG around item cards). The
inner edge is found from the centre outwards (first opaque / outline pixel
on each side) and everything inside it is cleared.

    python3 -I tools/item_frames/pick.py gewoehnlich=77 selten=311 ...
    python3 -I tools/item_frames/pick.py --sheet   (contact sheet of all candidates)
"""
import pathlib, sys
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
DIR = ROOT / "assets" / "items" / "frames"
RAW = DIR / "raw"
ORDER = ["gewoehnlich", "ungewoehnlich", "selten", "episch", "legendaer", "mythisch"]


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def inset(im: Image.Image) -> int:
    w, h = im.size
    px = im.load()
    c = px[w // 2, h // 2]
    found = []
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        x, y = w // 2, h // 2
        while 0 < x < w - 1 and 0 < y < h - 1:
            p = px[x, y]
            hit = p[3] > 0 if c[3] == 0 else (lum(p) < lum(c) * 0.55 or abs(lum(p) - lum(c)) > 70)
            if hit:
                break
            x += dx
            y += dy
        found.append(min(x, w - 1 - x) if dx else min(y, h - 1 - y))
    return max(4, min(found))


def sheet() -> None:
    files = sorted(RAW.glob("*_*.png"))
    cols = 4
    rows = (len(files) + cols - 1) // cols
    out = Image.new("RGBA", (cols * 200, rows * 220), (240, 230, 210, 255))
    d = ImageDraw.Draw(out)
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGBA").resize((192, 192), Image.NEAREST)
        x, y = (i % cols) * 200 + 4, (i // cols) * 220 + 4
        out.paste(im, (x, y), im)
        d.text((x, y + 196), f.stem, fill=(46, 34, 47, 255))
    out.save(DIR / "raw" / "kandidaten.png")
    print(DIR / "raw" / "kandidaten.png")


def main() -> None:
    if "--sheet" in sys.argv:
        sheet()
        return
    for arg in sys.argv[1:]:
        rid, seed = arg.split("=")
        im = Image.open(RAW / f"{rid}_{seed}.png").convert("RGBA")
        k = inset(im)
        ImageDraw.Draw(im).rectangle([k, k, im.width - 1 - k, im.height - 1 - k], fill=(0, 0, 0, 0))
        im.save(DIR / f"{rid}.png")
        print(rid, seed, "Innenkante", k)


if __name__ == "__main__":
    main()
