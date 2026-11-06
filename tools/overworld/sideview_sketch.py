#!/usr/bin/env python3
"""Draws flat side-view (front elevation) block sketches for the overworld
props whose first PixelLab versions came out in a top-down / three-quarter
view. They go into PixelLab pixflux as init_image, so the perspective of the
result is pinned to a straight side view like the figures and the ground:
no visible top surfaces, no ellipses, steps as stacked front faces only.
Writes assets/overworld/raw/sketch/<name>.png (128x128). Free, no API call.
    python3 tools/overworld/sideview_sketch.py
"""
import pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "overworld" / "raw" / "sketch"

OUTL = (26, 18, 30, 255)
STONE_L, STONE, STONE_D = (232, 226, 214, 255), (190, 182, 170, 255), (128, 118, 120, 255)
WATER_L, WATER = (150, 220, 250, 255), (70, 150, 220, 255)
GOLD, GOLD_D = (250, 205, 70, 255), (200, 130, 40, 255)
WOOD, WOOD_D = (150, 90, 55, 255), (96, 56, 40, 255)
RED, RED_D = (200, 50, 60, 255), (130, 30, 50, 255)
BASALT, BASALT_D, BASALT_L = (70, 60, 80, 255), (44, 36, 54, 255), (104, 92, 112, 255)
EMBER, EMBER_L = (250, 120, 40, 255), (255, 210, 100, 255)
TEAL, TEAL_L = (40, 180, 170, 255), (140, 240, 220, 255)
MOSS = (90, 160, 70, 255)
ROOF, ROOF_L = (40, 50, 110, 255), (70, 90, 160, 255)
STAR, STAR_L = (110, 190, 250, 255), (220, 245, 255, 255)
IRON = (90, 96, 110, 255)


def box(d, x0, y0, x1, y1, fill, light=None, dark=None):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=OUTL)
    if light:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=light)
        d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1], fill=light)
    if dark:
        d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=dark)
        d.line([x1 - 1, y0 + 2, x1 - 1, y1 - 1], fill=dark)


def star(d, cx, cy, r, fill, light):
    import math
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=fill, outline=OUTL)
    d.point([(cx - 1, cy - 2), (cx - 2, cy - 1)], fill=light)


def fountain(d):
    # lower basin: straight front wall, water only as a thin band at the rim
    box(d, 16, 92, 112, 125, STONE, STONE_L, STONE_D)
    box(d, 12, 86, 116, 92, STONE_L, None, STONE)          # rim lip
    for x in range(28, 112, 16):
        d.line([x, 93, x, 124], fill=STONE_D)              # carved panels
    d.line([17, 108, 111, 108], fill=STONE_D)
    d.rectangle([14, 82, 114, 85], fill=WATER_L)            # water surface seen edge-on
    # splash sheets falling from the upper basin into the lower one
    d.rectangle([40, 56, 43, 85], fill=WATER)
    d.rectangle([85, 56, 88, 85], fill=WATER)
    # stem
    box(d, 56, 54, 72, 86, STONE, STONE_L, STONE_D)
    # upper basin (bowl, front elevation = trapezoid)
    d.polygon([(36, 46), (92, 46), (82, 58), (46, 58)], fill=STONE, outline=OUTL)
    box(d, 34, 42, 94, 47, STONE_L, None, STONE)
    d.rectangle([36, 39, 92, 41], fill=WATER_L)
    # spout pillar + star
    box(d, 60, 20, 68, 42, STONE_L, None, STONE_D)
    star(d, 64, 14, 10, GOLD, (255, 240, 170, 255))
    d.rectangle([62, 16, 66, 22], fill=GOLD_D)


def forge_stall(d):
    # back wall with tools
    box(d, 14, 40, 114, 126, WOOD_D, WOOD, OUTL)
    for x in (30, 44):
        d.line([x, 50, x, 84], fill=IRON); d.line([x - 3, 82, x + 3, 82], fill=WOOD)
    d.rectangle([94, 52, 102, 58], fill=IRON); d.line([98, 58, 98, 76], fill=WOOD)
    # posts
    box(d, 10, 30, 16, 126, WOOD, None, WOOD_D)
    box(d, 112, 30, 118, 126, WOOD, None, WOOD_D)
    # awning: flat front valance, scalloped lower edge
    box(d, 4, 22, 124, 38, RED, (240, 100, 100, 255), RED_D)
    for x in range(4, 124, 12):
        d.pieslice([x, 32, x + 12, 44], 0, 180, fill=RED, outline=OUTL)
    d.line([4, 26, 124, 26], fill=RED_D)
    # stone forge with glowing mouth
    box(d, 58, 82, 108, 126, STONE_D, STONE, OUTL)
    d.rectangle([68, 92, 98, 108], fill=OUTL)
    d.rectangle([70, 98, 96, 107], fill=EMBER)
    d.rectangle([74, 102, 92, 106], fill=EMBER_L)
    box(d, 74, 60, 92, 82, STONE_D, STONE, OUTL)           # chimney hood
    # anvil in front, side elevation
    d.polygon([(20, 100), (54, 100), (50, 106), (24, 106)], fill=IRON, outline=OUTL)
    d.polygon([(14, 100), (20, 100), (20, 104)], fill=IRON, outline=OUTL)
    box(d, 31, 106, 43, 118, IRON)
    box(d, 26, 118, 48, 126, WOOD, None, WOOD_D)


def gate(d, dark: bool):
    s, sl, sd = (BASALT, BASALT_L, BASALT_D) if dark else (STONE, STONE_L, STONE_D)
    # steps: stacked front faces, each one narrower, no tread surface shown
    box(d, 8, 118, 120, 126, s, sl, sd)
    box(d, 16, 111, 112, 118, s, sl, sd)
    # pillars
    box(d, 18, 34, 38, 111, s, sl, sd)
    box(d, 90, 34, 110, 111, s, sl, sd)
    for y in range(44, 111, 12):
        d.line([19, y, 37, y], fill=sd); d.line([91, y, 109, y], fill=sd)
    # arch front face
    d.pieslice([18, 6, 110, 98], 180, 360, fill=s, outline=OUTL)
    d.pieslice([38, 26, 90, 78], 180, 360, fill=OUTL)
    d.rectangle([38, 52, 90, 111], fill=OUTL)
    if dark:
        d.rectangle([40, 52, 88, 110], fill=(60, 30, 30, 255))
        d.pieslice([40, 28, 88, 76], 180, 360, fill=(60, 30, 30, 255))
        for y in (62, 80, 98):
            d.line([40, y, 88, y + 6], fill=IRON, width=3)
            d.line([40, y + 6, 88, y], fill=IRON, width=3)
        d.rectangle([56, 70, 72, 88], fill=EMBER, outline=OUTL)
        d.rectangle([60, 76, 68, 82], fill=EMBER_L)
        d.line([24, 60, 30, 72], fill=EMBER); d.line([102, 50, 98, 66], fill=EMBER)
    else:
        d.rectangle([42, 52, 86, 110], fill=TEAL)
        d.pieslice([42, 30, 86, 74], 180, 360, fill=TEAL)
        d.ellipse([52, 56, 76, 80], outline=TEAL_L)
        for x, y in ((20, 40), (34, 70), (94, 52), (106, 88), (40, 10)):
            d.rectangle([x, y, x + 4, y + 3], fill=MOSS)
    star(d, 64, 12, 6, GOLD if not dark else EMBER, EMBER_L)


def shrine(d):
    # base plinth: two stacked front faces
    box(d, 14, 116, 114, 126, STONE, STONE_L, STONE_D)
    box(d, 24, 108, 104, 116, STONE, STONE_L, STONE_D)
    # walls
    box(d, 30, 50, 98, 108, STONE_L, None, STONE)
    d.rectangle([46, 62, 82, 106], fill=OUTL)
    d.rectangle([48, 64, 80, 106], fill=(30, 50, 100, 255))
    star(d, 64, 82, 12, STAR, STAR_L)
    # roof: flat front elevation with upturned eaves
    d.polygon([(10, 50), (118, 50), (104, 34), (24, 34)], fill=ROOF, outline=OUTL)
    d.line([24, 36, 104, 36], fill=ROOF_L)
    d.polygon([(4, 44), (12, 50), (10, 52)], fill=GOLD, outline=OUTL)
    d.polygon([(124, 44), (116, 50), (118, 52)], fill=GOLD, outline=OUTL)
    d.line([10, 50, 118, 50], fill=GOLD, width=2)
    d.polygon([(34, 34), (94, 34), (80, 20), (48, 20)], fill=ROOF, outline=OUTL)
    star(d, 64, 12, 7, GOLD, EMBER_L)
    # lanterns on both sides
    for x in (14, 106):
        box(d, x, 84, x + 8, 98, STAR, STAR_L, OUTL)
        d.line([x + 4, 98, x + 4, 116], fill=OUTL, width=2)


SKETCHES = {"fountain": fountain, "forge_stall": forge_stall, "gate_wald": lambda d: gate(d, False),
            "gate_glut": lambda d: gate(d, True), "shrine": shrine}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SKETCHES.items():
        img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        fn(ImageDraw.Draw(img))
        img.save(OUT / f"{name}.png")
        print(name)


if __name__ == "__main__":
    main()
