"""Collect every item folder under assets/characters/items into catalog.json.

An item folder holds item.json plus one PNG per layer. Run after adding,
importing or generating parts:

    python3 tools/sprites/build_catalog.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig  # noqa: E402
import validate  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CHAR_DIR = ROOT / "assets" / "characters"


def main() -> int:
    palettes = json.loads((CHAR_DIR / "palettes.json").read_text(encoding="utf-8"))
    items = {}
    errors = []
    for meta_path in sorted((CHAR_DIR / "items").glob("*/item.json")):
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        problems = validate.check_item(meta_path.parent, meta, palettes)
        if problems:
            errors += [f"{meta['id']}: {p}" for p in problems]
            continue
        rel = meta_path.parent.relative_to(ROOT).as_posix()
        meta["layers"] = {k: f"res://{rel}/{v}" for k, v in meta["layers"].items()}
        items[meta["id"]] = meta
    if errors:
        print("Fehler, catalog.json NICHT geschrieben:")
        for e in errors:
            print("  -", e)
        return 1
    catalog = {
        "_info": "Automatisch erzeugt von tools/sprites/build_catalog.py. Nicht von Hand bearbeiten.",
        "version": 1,
        "cell": rig.CELL,
        "columns": rig.COLUMNS,
        "origin": list(rig.ORIGIN),
        "fixed_colors": rig.FIXED_COLORS,
        "layers": rig.LAYERS,
        "slots": rig.SLOTS,
        "anims": rig.anim_table(),
        "items": items,
    }
    (CHAR_DIR / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"catalog.json: {len(items)} Teile")
    return 0


if __name__ == "__main__":
    sys.exit(main())
