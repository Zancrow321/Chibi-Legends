"""Checks that a character part fits the shared paper-doll format.

    python3 tools/sprites/validate.py            # all items
    python3 tools/sprites/validate.py haar_lang  # one item
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CHAR_DIR = ROOT / "assets" / "characters"


def check_item(folder: Path, meta: dict, palettes: dict) -> list:
    problems = []
    for key in ("id", "name", "slot", "channels", "layers"):
        if key not in meta:
            problems.append(f"Feld '{key}' fehlt in item.json")
    if problems:
        return problems
    if meta["id"] != folder.name:
        problems.append(f"id '{meta['id']}' passt nicht zum Ordnernamen '{folder.name}'")
    slot = meta["slot"]
    if slot not in rig.SLOTS:
        return problems + [f"unbekannter Slot '{slot}'"]
    if len(meta["channels"]) > 3:
        problems.append("höchstens 3 Farbkanäle pro Teil")
    for ch in meta["channels"]:
        group = ch.get("group")
        if group not in palettes:
            problems.append(f"Farbgruppe '{group}' gibt es nicht")
        elif not ch.get("appearance") and ch.get("default") not in {p["id"] for p in palettes[group]}:
            problems.append(f"Standardfarbe '{ch.get('default')}' fehlt in Gruppe '{group}'")
    used_slots = set()
    for layer, file in meta["layers"].items():
        if layer not in rig.SLOTS[slot]:
            problems.append(f"Ebene '{layer}' gehört nicht zum Slot '{slot}'")
            continue
        path = folder / file
        if not path.exists():
            problems.append(f"{file} fehlt")
            continue
        img = Image.open(path).convert("RGBA")
        if img.size != rig.SHEET_SIZE:
            problems.append(f"{file}: Größe {img.size}, erwartet {rig.SHEET_SIZE}")
            continue
        bad = 0
        px = img.load()
        for row, anim in enumerate(rig.ANIMS):
            for col in range(rig.COLUMNS):
                cx, cy = col * rig.CELL, row * rig.CELL
                filled = False
                for y in range(cy, cy + rig.CELL):
                    for x in range(cx, cx + rig.CELL):
                        p = px[x, y]
                        if p[3] == 0:
                            continue
                        filled = True
                        if not rig.is_encoded(p):
                            bad += 1
                        else:
                            used_slots.add(rig.decode(p)[0])
                if col >= len(anim.frames) and filled:
                    problems.append(f"{file}: Pixel in ungenutzter Zelle {anim.name}/{col}")
        if bad:
            problems.append(f"{file}: {bad} Pixel sind nicht palettenkodiert (erst tools/pixellab/import_sheet.py laufen lassen)")
    for s in used_slots - {rig.FIXED}:
        if s >= len(meta["channels"]):
            problems.append(f"Pixel nutzen Farbkanal {s}, item.json hat nur {len(meta['channels'])}")
    return problems


def main(argv: list) -> int:
    palettes = json.loads((CHAR_DIR / "palettes.json").read_text(encoding="utf-8"))
    folders = [CHAR_DIR / "items" / a for a in argv] if argv else sorted(p.parent for p in (CHAR_DIR / "items").glob("*/item.json"))
    failed = 0
    for folder in folders:
        meta = json.loads((folder / "item.json").read_text(encoding="utf-8"))
        problems = check_item(folder, meta, palettes)
        print(("OK   " if not problems else "FEHLER ") + folder.name)
        for p in problems:
            print("     -", p)
        failed += bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
