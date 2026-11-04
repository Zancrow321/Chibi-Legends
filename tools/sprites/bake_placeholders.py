"""Bake the placeholder character parts into palette-indexed sprite sheets.

The art is the pixel chibi from phase 1 (formerly drawn in code by
chibi_visual.gd), split into paper-doll layers. Real PixelLab art replaces
these sheets item by item later; the format stays the same.

    python3 tools/sprites/bake_placeholders.py
    python3 tools/sprites/build_catalog.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig  # noqa: E402
from rig import FIXED, Pose  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ITEMS_DIR = ROOT / "assets" / "characters" / "items"

# tones
T_SHADE2, T_SHADE, T_DARK, T_BASE, T_LIGHT = 1, 2, 3, 4, 5
# fixed tones
F_OUTLINE, F_WHITE, F_BLUSH, F_MOUTH, F_GOLD, F_STEEL, F_BELT, F_LEATHER = range(8)


class Canvas:
    """Collects rects for one layer of one frame, then rasterises them with
    a 1 px outline around outlined parts (outline pass first, then fills)."""

    def __init__(self) -> None:
        self.parts: list = []

    def r(self, x, y, w, h, slot, tone, outlined=True) -> None:
        self.parts.append((int(x), int(y), int(w), int(h), slot, tone, outlined))

    def paint(self, img: Image.Image, cx: int, cy: int) -> None:
        ox, oy = cx + rig.ORIGIN[0], cy + rig.ORIGIN[1]
        px = img.load()

        def fill(x, y, w, h, col):
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    if cx <= ox + xx < cx + rig.CELL and cy <= oy + yy < cy + rig.CELL:
                        px[ox + xx, oy + yy] = col

        for x, y, w, h, _s, _t, outlined in self.parts:
            if outlined:
                fill(x - 1, y - 1, w + 2, h + 2, rig.encode(FIXED, F_OUTLINE))
        for x, y, w, h, s, t, _o in self.parts:
            fill(x, y, w, h, rig.encode(s, t))


# --- shared geometry -------------------------------------------------------

def head_y(p: Pose) -> int:
    return -45 + p.bob


def front_arm(p: Pose) -> tuple:
    """(sleeve rect, hand rect) of the front arm for a pose, relative to origin."""
    b, u = p.bob, p.lean
    if p.arm == "swing":
        return (5 + u, -21 + b, 7 + p.reach, 3), (12 + p.reach + u, -21 + b, 3, 3)
    if p.arm == "windup":
        return (8 + u, -27 + b, 3, 7), (10 + u, -30 + b, 3, 3)
    if p.arm == "cast":
        return (5 + u, -24 + b, 3, 8), (6 + u, -27 + b, 3, 3)
    return (6 + u, -21 + b, 3, 8), (6 + u, -13 + b, 3, 3)


BACK_SLEEVE = (-10, -21, 3, 8)
BACK_HAND = (-10, -13, 3, 3)


# --- layers ----------------------------------------------------------------

def draw_body(c: Canvas, p: Pose, _v) -> None:
    b, u = p.bob, p.lean
    s = 0  # skin
    c.r(BACK_SLEEVE[0] + u, BACK_SLEEVE[1] + b, 3, 11, s, T_DARK)
    bl, fl = p.back_leg, p.front_leg
    c.r(-6 + bl[0], -11 + bl[1], 4, 11, s, T_DARK)
    c.r(1 + fl[0], -11 + fl[1], 4, 11, s, T_BASE)
    c.r(-7 + u, -22 + b, 14, 11, s, T_BASE)
    c.r(-7 + u, -22 + b, 3, 11, s, T_DARK, False)
    hy = head_y(p)
    c.r(-11 + u, hy + 1, 22, 22, s, T_BASE)
    c.r(-12 + u, hy + 4, 24, 16, s, T_BASE)
    c.r(-9 + u, hy + 23, 18, 1, s, T_BASE)
    c.r(-12 + u, hy + 14, 3, 8, s, T_DARK, False)
    sleeve, hand = front_arm(p)
    sx, sy, sw, sh = sleeve
    c.r(sx, sy, sw, sh, s, T_BASE)
    c.r(*hand, s, T_BASE)


def draw_face(c: Canvas, p: Pose, variant: str) -> None:
    u = p.lean
    ey = head_y(p) + 11
    e = 0  # eye color channel
    for ex in (-4 + u, 4 + u):
        if p.eyes == "closed":
            c.r(ex - 1, ey + 4, 6, 1, FIXED, F_OUTLINE, False)
            continue
        if p.eyes == "squint":
            c.r(ex - 1, ey + 3, 6, 1, FIXED, F_OUTLINE, False)
            c.r(ex, ey + 4, 4, 2, e, T_SHADE2, False)
            continue
        top = 2 if variant == "entschlossen" else 0
        c.r(ex - 1, ey + top, 6, 1, FIXED, F_OUTLINE, False)
        c.r(ex, ey + 1 + top, 4, 6 - top, e, T_BASE, False)
        c.r(ex, ey + 1 + top, 4, 2, e, T_SHADE, False)
        c.r(ex + 1, ey + 4, 2, 3, e, T_SHADE2, False)
        c.r(ex, ey + 2 + top, 1, 2, FIXED, F_WHITE, False)
        c.r(ex + 3, ey + 5, 1, 1, FIXED, F_WHITE, False)
        if variant == "entschlossen":  # angled brows
            c.r(ex - 1, ey - 1, 3, 1, FIXED, F_OUTLINE, False)
            c.r(ex + 2, ey, 3, 1, FIXED, F_OUTLINE, False)
    c.r(-5 + u, ey + 8, 3, 1, FIXED, F_BLUSH, False)
    c.r(7 + u, ey + 8, 3, 1, FIXED, F_BLUSH, False)
    if p.mouth == "open":
        c.r(4 + u, ey + 10, 3, 2, FIXED, F_MOUTH, False)
    else:
        c.r(4 + u, ey + 10, 2, 1, FIXED, F_MOUTH, False)


def draw_hair_back(c: Canvas, p: Pose, style: str) -> None:
    b, u = p.bob, p.lean
    h = 0
    if style == "lang":
        c.r(-14 + u, -38 + b, 9, 27, h, T_SHADE)
    elif style == "zopf":
        w = p.wave
        c.r(-19 + u, -44 + b, 6, 5, h, T_SHADE)
        c.r(-22 + u - w, -40 + b, 6, 12, h, T_SHADE)
        c.r(-21 + u - w, -28 + b, 4, 6, h, T_SHADE)


def draw_hair_front(c: Canvas, p: Pose, style: str) -> None:
    u = p.lean
    hy = head_y(p)
    h, acc = 0, 1

    def r(x, y, w, hh, tone=T_BASE, outlined=True, slot=h):
        c.r(x + u, hy + y, w, hh, slot, tone, outlined)

    if style == "stachelig":
        r(-12, -2, 24, 10); r(-13, 1, 26, 6); r(-11, -6, 4, 5); r(-6, -8, 5, 7)
        r(0, -7, 5, 6); r(6, -5, 5, 4); r(-16, 1, 4, 6); r(-17, 7, 4, 6)
        r(-13, 6, 7, 12); r(2, 8, 3, 4); r(6, 8, 3, 3); r(10, 6, 3, 9)
        r(-4, -1, 6, 2, T_LIGHT, False)
    elif style == "lang":
        r(-12, -2, 24, 10); r(-13, 1, 26, 6); r(-13, 6, 8, 16); r(1, 8, 4, 3)
        r(5, 8, 3, 4); r(9, 6, 4, 14); r(-3, 0, 7, 2, T_LIGHT, False)
    elif style == "zopf":
        r(-12, -2, 24, 10); r(-13, 1, 26, 6); r(-13, 6, 6, 9); r(3, 8, 4, 3)
        r(9, 6, 3, 8); r(-16, -1, 4, 4, slot=acc); r(-3, 0, 7, 2, T_LIGHT, False)
    elif style == "kurz":
        r(-12, -1, 24, 8); r(-13, 2, 26, 4); r(-13, 5, 5, 7); r(4, 7, 5, 2)
        r(-3, 1, 6, 2, T_LIGHT, False)
    else:  # wuschel
        r(-14, -4, 28, 12); r(-15, 0, 30, 7); r(-4, -7, 8, 4); r(-16, 5, 5, 10)
        r(11, 5, 4, 7); r(1, 7, 4, 4); r(6, 7, 3, 3); r(-6, -2, 8, 2, T_LIGHT, False)


def draw_top(c: Canvas, p: Pose, variant: str) -> None:
    b, u = p.bob, p.lean
    m, sec = 0, 1
    short = variant == "shirt"
    c.r(BACK_SLEEVE[0] + u, BACK_SLEEVE[1] + b, 3, 3 if short else 8, m, T_SHADE)
    c.r(-7 + u, -22 + b, 14, 11, m, T_BASE)
    c.r(-7 + u, -22 + b, 3, 11, m, T_SHADE, False)
    if variant == "jacke":
        c.r(0 + u, -22 + b, 3, 4, sec, T_BASE, False)  # collar (shirt beneath)
        c.r(-7 + u, -13 + b, 14, 2, FIXED, F_BELT, False)
        c.r(1 + u, -13 + b, 2, 2, FIXED, F_GOLD, False)
        c.r(3 + u, -19 + b, 1, 6, FIXED, F_GOLD, False)
    else:
        c.r(-1 + u, -22 + b, 5, 1, sec, T_BASE, False)  # neckline
        c.r(-7 + u, -12 + b, 14, 1, m, T_DARK, False)  # hem
    sleeve, _hand = front_arm(p)
    sx, sy, sw, sh = sleeve
    if short:
        if p.arm == "swing":
            sw = 3
        else:
            sh = 3
    c.r(sx, sy, sw, sh, m, T_BASE)


def draw_pants(c: Canvas, p: Pose, variant: str) -> None:
    m = 0
    hgt = 4 if variant == "kurz" else 7
    bl, fl = p.back_leg, p.front_leg
    c.r(-6 + bl[0], -11 + bl[1], 4, hgt, m, T_DARK)
    c.r(1 + fl[0], -11 + fl[1], 4, hgt, m, T_BASE)


def draw_shoes(c: Canvas, p: Pose, _v) -> None:
    m = 0
    bl, fl = p.back_leg, p.front_leg
    c.r(-7 + bl[0], -4 + bl[1], 5, 4, m, T_DARK)
    c.r(1 + fl[0], -4 + fl[1], 6, 4, m, T_BASE)
    c.r(1 + fl[0], -4 + fl[1], 6, 1, m, T_LIGHT, False)


def draw_scarf_back(c: Canvas, p: Pose, _v) -> None:
    b, u, w = p.bob, p.lean, p.wave
    c.r(-13 + u, -22 + b + w, 6, 3, 0, T_BASE)
    c.r(-17 + u, -21 + b + round(w * 1.5), 4, 3, 0, T_BASE)


def draw_scarf_front(c: Canvas, p: Pose, _v) -> None:
    b, u = p.bob, p.lean
    c.r(-8 + u, -22 + b, 16, 3, 0, T_BASE)
    c.r(-8 + u, -20 + b, 16, 1, 0, T_SHADE, False)


def draw_headband(c: Canvas, p: Pose, _v) -> None:
    u, w = p.lean, p.wave
    hy = head_y(p)
    c.r(-13 + u, hy + 3, 26, 2, 0, T_BASE)
    c.r(2 + u, hy + 2, 6, 4, FIXED, F_STEEL)
    c.r(3 + u, hy + 3, 1, 1, FIXED, F_WHITE, False)
    c.r(-17 + u, hy + 4 + w, 4, 2, 0, T_SHADE)
    c.r(-20 + u, hy + 6 + w, 4, 2, 0, T_SHADE)


def draw_katana(c: Canvas, p: Pose, _v) -> None:
    b, u = p.bob, p.lean
    sheath = 0
    _sleeve, hand = front_arm(p)
    if p.arm == "swing":
        x = hand[0] + 3
        c.r(x, -23 + b, 1, 7, FIXED, F_GOLD)
        c.r(x + 1, -21 + b, 17, 2, FIXED, F_STEEL)
        c.r(x + 1, -21 + b, 17, 1, FIXED, F_WHITE, False)
        return
    if p.arm == "windup":
        x, y = hand[0], hand[1]
        c.r(x - 2, y - 1, 7, 1, FIXED, F_GOLD)
        c.r(x, y - 18, 2, 17, FIXED, F_STEEL)
        c.r(x, y - 18, 1, 17, FIXED, F_WHITE, False)
        return
    for i in range(6):
        c.r(-12 + i * 3 + u, -9 + b - i, 3, 2, sheath, T_SHADE)
    c.r(6 + u, -16 + b, 4, 2, FIXED, F_GOLD)


# --- items -----------------------------------------------------------------
# channels: per item color channel -> palette group and default palette id.
# Body/face/hair channels marked "appearance" read the character's own
# colors (skin, eyes, hair) instead of per-item colors.

ITEMS = [
    {"id": "koerper_basis", "name": "Basis-Körper", "slot": "body",
     "channels": [{"key": "skin", "label": "Haut", "group": "haut", "appearance": True}],
     "layers": {"body": (draw_body, None)}},
    {"id": "gesicht_standard", "name": "Freundlich", "slot": "face",
     "channels": [{"key": "eyes", "label": "Augen", "group": "augen", "appearance": True}],
     "layers": {"face": (draw_face, "standard")}},
    {"id": "gesicht_entschlossen", "name": "Entschlossen", "slot": "face",
     "channels": [{"key": "eyes", "label": "Augen", "group": "augen", "appearance": True}],
     "layers": {"face": (draw_face, "entschlossen")}},
]

for hid, hname in [("stachelig", "Stachelig"), ("lang", "Lang"), ("zopf", "Zopf"), ("kurz", "Kurz"), ("wuschel", "Wuschel")]:
    item = {"id": "haar_" + hid, "name": hname, "slot": "hair",
            "channels": [{"key": "hair", "label": "Haar", "group": "haar", "appearance": True}],
            "layers": {"hair_front": (draw_hair_front, hid)}}
    if hid in ("lang", "zopf"):
        item["layers"]["hair_back"] = (draw_hair_back, hid)
    if hid == "zopf":
        item["channels"].append({"key": "c1", "label": "Haarband", "group": "stoff", "default": "rot"})
    ITEMS.append(item)

ITEMS += [
    {"id": "oberteil_akademie", "name": "Akademie-Jacke", "slot": "top",
     "channels": [{"key": "c0", "label": "Jacke", "group": "stoff", "default": "weiss"},
                  {"key": "c1", "label": "Kragen", "group": "stoff", "default": "rot"}],
     "layers": {"top": (draw_top, "jacke")}},
    {"id": "oberteil_shirt", "name": "Trainingsshirt", "slot": "top",
     "channels": [{"key": "c0", "label": "Shirt", "group": "stoff", "default": "blau"},
                  {"key": "c1", "label": "Saum", "group": "stoff", "default": "weiss"}],
     "layers": {"top": (draw_top, "shirt")}},
    {"id": "hose_lang", "name": "Lange Hose", "slot": "pants",
     "channels": [{"key": "c0", "label": "Hose", "group": "stoff", "default": "braun"}],
     "layers": {"pants": (draw_pants, "lang")}},
    {"id": "hose_kurz", "name": "Kurze Hose", "slot": "pants",
     "channels": [{"key": "c0", "label": "Hose", "group": "stoff", "default": "marine"}],
     "layers": {"pants": (draw_pants, "kurz")}},
    {"id": "schuhe_stiefel", "name": "Stiefel", "slot": "shoes",
     "channels": [{"key": "c0", "label": "Leder", "group": "stoff", "default": "dunkelbraun"}],
     "layers": {"shoes": (draw_shoes, None)}},
    {"id": "accessoire_schal", "name": "Kampfschal", "slot": "accessory",
     "channels": [{"key": "c0", "label": "Schal", "group": "stoff", "default": "rot"}],
     "layers": {"acc_back": (draw_scarf_back, None), "acc_front": (draw_scarf_front, None)}},
    {"id": "kopf_stirnband", "name": "Stirnband", "slot": "headgear",
     "channels": [{"key": "c0", "label": "Band", "group": "stoff", "default": "marine"}],
     "layers": {"headgear": (draw_headband, None)}},
    {"id": "waffe_katana", "name": "Übungs-Katana", "slot": "weapon",
     "channels": [{"key": "c0", "label": "Scheide", "group": "stoff", "default": "violett"}],
     "layers": {"weapon": (draw_katana, None)}},
]


def bake_layer(fn, variant) -> Image.Image:
    img = Image.new("RGBA", rig.SHEET_SIZE, (0, 0, 0, 0))
    for row, anim in enumerate(rig.ANIMS):
        for col, pose in enumerate(anim.frames):
            c = Canvas()
            fn(c, pose, variant)
            c.paint(img, col * rig.CELL, row * rig.CELL)
    return img


def main() -> None:
    for item in ITEMS:
        folder = ITEMS_DIR / item["id"]
        folder.mkdir(parents=True, exist_ok=True)
        layers = {}
        for layer, (fn, variant) in item["layers"].items():
            assert layer in rig.SLOTS[item["slot"]], (item["id"], layer)
            bake_layer(fn, variant).save(folder / f"{layer}.png", optimize=True)
            layers[layer] = f"{layer}.png"
        meta = {k: v for k, v in item.items() if k != "layers"}
        meta["layers"] = layers
        meta["source"] = "platzhalter"
        (folder / "item.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("gebacken:", item["id"])


if __name__ == "__main__":
    main()
