"""Turn a normal colored PNG into a palette-indexed character part.

Use this for parts you made yourself (PixelLab web app, Aseprite, ...).

    # the part alone on a transparent sheet in the standard layout (512 x 704)
    python3 tools/pixellab/import_sheet.py ninja_weste top.png

    # or: the whole character wearing it, drawn over the base figure;
    # the base is subtracted automatically
    python3 tools/pixellab/import_sheet.py ninja_weste worn.png --on-base

The item folder assets/characters/items/<id>/ must contain item.json
(slot, channels with default colors). Colors are mapped to the nearest tone
of the item's channel colors or the fixed colors, so draw with (roughly)
those colors, or give PixelLab the color image from `palette_image()`.
For two-layer slots (hair, accessory) pixels behind the body go to the back layer.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS / "sprites"))
import preview  # noqa: E402
import rig  # noqa: E402

ROOT = TOOLS.parent
ITEMS_DIR = ROOT / "assets" / "characters" / "items"
BASE_LOOK = {"hair": "", "colors": preview.PRESETS[0]["colors"], "cosmetics": {s: "none" for s in preview.GEAR_SLOTS}}


def reference_colors(meta: dict, colors: dict) -> list:
    """[(rgb, slot, tone)] the quantizer may snap to."""
    refs = []
    for i, ch in enumerate(meta["channels"]):
        pid = ch.get("default")
        if ch.get("appearance"):
            pid = preview.PRESETS[0]["colors"].get(ch["key"])
        for t, rgb in enumerate(rig.ramp_colors(colors[pid])):
            if t > 0:
                refs.append((rgb, i, t))
    for t, h in enumerate(rig.FIXED_COLORS):
        refs.append((rig.hex_rgb(h), rig.FIXED, t))
    return refs


def palette_image(meta: dict, colors: dict) -> Image.Image:
    """Small image with every allowed color (for PixelLab's color_image)."""
    refs = reference_colors(meta, colors)
    img = Image.new("RGBA", (len(refs), 1))
    for x, (rgb, _s, _t) in enumerate(refs):
        img.putpixel((x, 0), (*rgb, 255))
    return img


def _nearest(rgb: tuple, refs: list) -> tuple:
    best, best_d = None, 1e9
    for ref, slot, tone in refs:
        d = (rgb[0] - ref[0]) ** 2 * 0.3 + (rgb[1] - ref[1]) ** 2 * 0.59 + (rgb[2] - ref[2]) ** 2 * 0.11
        if d < best_d:
            best, best_d = (slot, tone), d
    return best


def base_sheet(catalog: dict, colors: dict) -> Image.Image:
    """Colored sheet of the bare base figure (body + face)."""
    return preview.compose(catalog, colors, BASE_LOOK, {})


def body_mask(catalog: dict) -> Image.Image:
    body = Image.open(ROOT / catalog["items"]["koerper_basis"]["layers"]["body"].replace("res://", "")).convert("RGBA")
    return body.getchannel("A")


def encode_sheet(src: Image.Image, meta: dict, colors: dict, catalog: dict, on_base: bool) -> dict:
    """layer name -> encoded sheet."""
    if src.size != rig.SHEET_SIZE:
        raise SystemExit(f"Bild ist {src.size}, erwartet {rig.SHEET_SIZE} ({rig.COLUMNS} Spalten x {len(rig.ANIMS)} Zeilen à {rig.CELL} px)")
    refs = reference_colors(meta, colors)
    base = base_sheet(catalog, colors).load() if on_base else None
    bmask = body_mask(catalog).load()
    layers = rig.SLOTS[meta["slot"]]
    out = {name: Image.new("RGBA", rig.SHEET_SIZE, (0, 0, 0, 0)) for name in layers}
    sp = src.load()
    back, front = (layers[0], layers[-1]) if len(layers) > 1 else (layers[0], layers[0])
    for y in range(src.height):
        row = y // rig.CELL
        frames = len(rig.ANIMS[row].frames) if row < len(rig.ANIMS) else 0
        for x in range(src.width):
            if x // rig.CELL >= frames:
                continue
            p = sp[x, y]
            if p[3] < 128:
                continue
            if base is not None:
                b = base[x, y]
                if b[3] >= 128 and sum(abs(p[i] - b[i]) for i in range(3)) < 24:
                    continue  # unchanged base pixel
            enc = rig.encode(*_nearest(p[:3], refs))
            # behind the body (outside its silhouette, on the back side) -> back layer
            cx = x % rig.CELL
            target = back if (bmask[x, y] == 0 and cx < rig.ORIGIN[0] - 4) else front
            out[target].putpixel((x, y), enc)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("item_id")
    ap.add_argument("png")
    ap.add_argument("--on-base", action="store_true", help="Bild zeigt die ganze Figur; Basis wird abgezogen")
    args = ap.parse_args()
    folder = ITEMS_DIR / args.item_id
    meta = json.loads((folder / "item.json").read_text(encoding="utf-8"))
    catalog, colors = preview.load()
    sheets = encode_sheet(Image.open(args.png).convert("RGBA"), meta, colors, catalog, args.on_base)
    meta["layers"] = {}
    for name, img in sheets.items():
        if img.getbbox() is None:
            continue
        img.save(folder / f"{name}.png", optimize=True)
        meta["layers"][name] = f"{name}.png"
    meta.setdefault("source", "import")
    (folder / "item.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("importiert:", ", ".join(meta["layers"]), "-> jetzt: python3 tools/sprites/build_catalog.py")


if __name__ == "__main__":
    main()
