"""Render colored previews of a look (same compositing as the game).

    python3 tools/sprites/preview.py out.png                 # all presets, idle/run/attack
    python3 tools/sprites/preview.py out.png --item haar_lang # every frame with one item swapped in
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CHAR_DIR = ROOT / "assets" / "characters"

GEAR_SLOTS = ["top", "pants", "shoes", "accessory", "headgear", "weapon"]
START_EQUIPMENT = {"weapon": "waffe_katana", "top": "oberteil_akademie", "pants": "hose_lang", "shoes": "schuhe_stiefel", "accessory": "accessoire_schal"}

PRESETS = [
    {"hair": "haar_stachelig", "colors": {"skin": "haut_1", "hair": "haar_rot", "eyes": "augen_braun"}},
    {"hair": "haar_lang", "face": "gesicht_entschlossen", "colors": {"skin": "haut_2", "hair": "haar_schwarz", "eyes": "augen_rot"},
     "cosmetics": {"top": "oberteil_shirt"}, "item_colors": {"oberteil_shirt": ["schwarz", "rot"]}},
    {"hair": "haar_zopf", "colors": {"skin": "haut_1", "hair": "haar_rosa", "eyes": "augen_blau"},
     "cosmetics": {"headgear": "kopf_stirnband"}, "item_colors": {"oberteil_akademie": ["blau", "weiss"], "haar_zopf": [None, "gelb"]}},
    {"hair": "haar_wuschel", "colors": {"skin": "haut_3", "hair": "haar_blond", "eyes": "augen_gruen"},
     "cosmetics": {"pants": "hose_kurz", "accessory": "none"}, "item_colors": {"oberteil_akademie": ["gruen", "weiss"]}},
    {"hair": "haar_kurz", "face": "gesicht_entschlossen", "colors": {"skin": "haut_5", "hair": "haar_weiss", "eyes": "augen_violett"},
     "item_colors": {"oberteil_akademie": ["violett", "gelb"], "accessoire_schal": ["schwarz"]}},
]


def load():
    catalog = json.loads((CHAR_DIR / "catalog.json").read_text(encoding="utf-8"))
    palettes = json.loads((CHAR_DIR / "palettes.json").read_text(encoding="utf-8"))
    colors = {p["id"]: p["color"] for g, lst in palettes.items() if not g.startswith("_") for p in lst}
    return catalog, colors


def resolve(look: dict, equipment: dict) -> dict:
    """slot -> item id (empty slots left out). Cosmetic beats equipment; 'none' hides."""
    out = {k: look.get(k, d) for k, d in (("body", "koerper_basis"), ("face", "gesicht_standard"), ("hair", "haar_stachelig"))}
    out = {k: v for k, v in out.items() if v}
    cos = look.get("cosmetics", {})
    for slot in GEAR_SLOTS:
        c = cos.get(slot, "")
        if c == "none":
            continue
        item = c or equipment.get(slot, "")
        if item:
            out[slot] = item
    return out


def item_palette(item: dict, look: dict, colors: dict, fixed: list) -> dict:
    """(slot, tone) -> rgb for one item."""
    table = {}
    overrides = look.get("item_colors", {}).get(item["id"], [])
    for i, ch in enumerate(item["channels"]):
        if ch.get("appearance"):
            pid = look.get("colors", {}).get(ch["key"])
        else:
            pid = overrides[i] if i < len(overrides) and overrides[i] else ch["default"]
        for t, rgb in enumerate(rig.ramp_colors(colors[pid])):
            table[(i, t)] = rgb
    for t, h in enumerate(fixed):
        table[(rig.FIXED, t)] = rig.hex_rgb(h)
    return table


def compose(catalog: dict, colors: dict, look: dict, equipment: dict) -> Image.Image:
    """Full colored sheet for a look."""
    out = Image.new("RGBA", rig.SHEET_SIZE, (0, 0, 0, 0))
    slots = resolve(look, equipment)
    by_layer = {}
    for slot, item_id in slots.items():
        item = catalog["items"][item_id]
        for layer, path in item["layers"].items():
            by_layer[layer] = (item, ROOT / path.replace("res://", ""))
    for layer in catalog["layers"]:
        if layer not in by_layer:
            continue
        item, path = by_layer[layer]
        pal = item_palette(item, look, colors, catalog["fixed_colors"])
        src = Image.open(path).convert("RGBA")
        sp, op = src.load(), out.load()
        for y in range(src.height):
            for x in range(src.width):
                d = rig.decode(sp[x, y])
                if d is not None:
                    op[x, y] = (*pal.get(d, (255, 0, 255)), 255)
    return out


def frame(sheet: Image.Image, anim: str, i: int, catalog: dict) -> Image.Image:
    row = catalog["anims"][anim]["row"]
    c = rig.CELL
    return sheet.crop((i * c, row * c, i * c + c, row * c + c))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--scale", type=int, default=4)
    ap.add_argument("--bg", default="1d2a24")
    args = ap.parse_args()
    catalog, colors = load()
    picks = [("idle", 0), ("run", 1), ("run", 5), ("jump", 0), ("attack_1", 0), ("attack_2", 1), ("attack_3", 1), ("cast", 1), ("hit", 1)]
    c = rig.CELL
    img = Image.new("RGBA", (len(picks) * c, len(PRESETS) * c), (*rig.hex_rgb(args.bg), 255))
    for r, look in enumerate(PRESETS):
        sheet = compose(catalog, colors, look, START_EQUIPMENT)
        for k, (anim, i) in enumerate(picks):
            f = frame(sheet, anim, i, catalog)
            img.alpha_composite(f, (k * c, r * c))
    img = img.resize((img.width * args.scale, img.height * args.scale), Image.NEAREST)
    img.save(args.out)
    print("Vorschau:", args.out)


if __name__ == "__main__":
    main()
