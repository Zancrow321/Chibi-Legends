"""Generate a character part with PixelLab, frame by frame, on the frozen base figure.

1. Create assets/characters/items/<id>/item.json (slot, name, channels) with a
   "pixellab" block, for example:

       "pixellab": {
         "prompt": "dark blue ninja vest with silver plates, chibi, side view",
         "negative": "hair, face, weapon",
         "seed": 4242,
         "mask_from": "oberteil_akademie",
         "grow": 3
       }

   mask_from = an existing item of the same slot whose silhouette (grown by
   `grow` px) is the area PixelLab may paint in. That keeps every frame aligned.

2. Try it cheaply first, then run all frames:

       python3 tools/pixellab/generate.py ninja_weste --dry-run       # only writes inputs, no API call
       python3 tools/pixellab/generate.py ninja_weste --only idle:0   # one frame
       python3 tools/pixellab/generate.py ninja_weste                 # every frame

3. Check _vorschau.png, then python3 tools/sprites/build_catalog.py

Needs PIXELLAB_API_KEY in the environment and network access to api.pixellab.ai.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "sprites"))
import import_sheet  # noqa: E402
import pixellab_api  # noqa: E402
import preview  # noqa: E402
import rig  # noqa: E402

ROOT = HERE.parents[1]
ITEMS_DIR = ROOT / "assets" / "characters" / "items"


def slot_mask(catalog: dict, item_id: str, grow: int) -> Image.Image:
    """White = PixelLab may paint here. Union of the reference item's layers, grown."""
    ref = catalog["items"][item_id]
    mask = Image.new("L", rig.SHEET_SIZE, 0)
    for path in ref["layers"].values():
        alpha = Image.open(ROOT / path.replace("res://", "")).convert("RGBA").getchannel("A")
        mask.paste(255, (0, 0), alpha)
    if grow > 0:
        mask = mask.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    return mask


def cells(only: str | None):
    for row, anim in enumerate(rig.ANIMS):
        for col in range(len(anim.frames)):
            if only:
                name, _, idx = only.partition(":")
                if name != anim.name or (idx and int(idx) != col):
                    continue
            yield anim.name, row, col


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("item_id")
    ap.add_argument("--dry-run", action="store_true", help="nur Eingaben schreiben, keine API-Aufrufe")
    ap.add_argument("--only", help="nur eine Animation oder ein Frame, z. B. idle oder idle:0")
    args = ap.parse_args()

    folder = ITEMS_DIR / args.item_id
    meta = json.loads((folder / "item.json").read_text(encoding="utf-8"))
    spec = meta.get("pixellab")
    if not spec:
        print("item.json braucht einen \"pixellab\"-Block (siehe Hilfe: --help)")
        return 1
    catalog, colors = preview.load()
    base = import_sheet.base_sheet(catalog, colors)
    mask = slot_mask(catalog, spec.get("mask_from", ""), int(spec.get("grow", 3)))
    palette = import_sheet.palette_image(meta, colors)
    todo = list(cells(args.only))

    if args.dry_run:
        base.save(folder / "_basis.png")
        mask.save(folder / "_maske.png")
        print(f"Trocken-Lauf: {len(todo)} Frames würden erzeugt. Eingaben: _basis.png, _maske.png")
        return 0

    raw_path = folder / "_pixellab_roh.png"
    raw = Image.open(raw_path).convert("RGBA") if raw_path.exists() else base.copy()
    usd = 0.0
    for n, (name, row, col) in enumerate(todo, 1):
        box = (col * rig.CELL, row * rig.CELL, (col + 1) * rig.CELL, (row + 1) * rig.CELL)
        cell_mask = mask.crop(box)
        if cell_mask.getbbox() is None:
            continue
        img, cost = pixellab_api.inpaint(
            spec["prompt"], base.crop(box), cell_mask.convert("RGB"),
            seed=int(spec.get("seed", 0)), negative=spec.get("negative", ""), color_image=palette,
        )
        usd += cost
        if img.size != (rig.CELL, rig.CELL):
            img = img.resize((rig.CELL, rig.CELL), Image.NEAREST)
        # keep only what was painted inside the mask; outside stays the base
        cell = base.crop(box)
        cell.paste(img, (0, 0), cell_mask)
        raw.paste(cell, box[:2])
        raw.save(raw_path)  # save progress after every frame
        print(f"[{n}/{len(todo)}] {name}:{col}  (bisher {usd:.3f} USD)")

    sheets = import_sheet.encode_sheet(raw, meta, colors, catalog, on_base=True)
    meta["layers"] = {}
    for layer, img in sheets.items():
        if img.getbbox() is not None:
            img.save(folder / f"{layer}.png", optimize=True)
            meta["layers"][layer] = f"{layer}.png"
    meta["source"] = "pixellab"
    (folder / "item.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    raw.resize((raw.width * 2, raw.height * 2), Image.NEAREST).save(folder / "_vorschau.png")
    print(f"Fertig, {usd:.3f} USD. Prüfen: _vorschau.png, dann tools/sprites/build_catalog.py")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except pixellab_api.PixelLabError as e:
        print("Fehler:", e)
        sys.exit(2)
