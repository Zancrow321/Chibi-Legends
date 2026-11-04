"""Build palette files for Aseprite, Godot and PixelLab from assets/palettes/*.hex.

    python3 tools/palette/build.py

Writes per palette <name>.gpl (Aseprite/GIMP: Palette > Load), <name>.png
(N x 1 strip for shaders) and <name>_swatches.png (8 px swatches; also the
PixelLab color image). For the master palette it also bakes the recolor
table from assets/palettes/swaps.json into swaps_lut.png:

    width = palette size, one row per variant, row 0 = original colors.
    In a variant, "from": "to" replaces one palette color with another
    (or any hex color, e.g. for rare unlockable colors).

The order of the variants is written to swaps_lut.json so the game can look
up a row by name (PaletteRemap.row("feuer")).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette as pal  # noqa: E402


def build_swaps(colors: list, swaps: dict) -> tuple[Image.Image, list]:
    names = ["original"] + [n for n in swaps if not n.startswith("_") and n != "original"]
    img = Image.new("RGBA", (len(colors), len(names)))
    for row, name in enumerate(names):
        mapping = {pal.parse_hex(k): pal.parse_hex(v) for k, v in swaps.get(name, {}).items()}
        for k in mapping:
            if k not in colors:
                raise ValueError(f"Variante {name}: #{pal.to_hex(k)} ist keine Farbe der Master-Palette")
        for x, c in enumerate(colors):
            img.putpixel((x, row), (*mapping.get(c, c), 255))
    return img, names


def main() -> int:
    master = pal.master_name()
    for hex_file in sorted(pal.PALETTE_DIR.glob("*.hex")):
        name = hex_file.stem
        colors = pal.load(name)
        pal.write_gpl(colors, name, pal.PALETTE_DIR / f"{name}.gpl")
        pal.strip_image(colors).save(pal.PALETTE_DIR / f"{name}.png")
        pal.swatch_image(colors).save(pal.PALETTE_DIR / f"{name}_swatches.png")
        print(f"{name}: {len(colors)} Farben" + (" (Master)" if name == master else ""))

    swaps_path = pal.PALETTE_DIR / "swaps.json"
    if swaps_path.exists():
        colors = pal.load(master)
        swaps = json.loads(swaps_path.read_text(encoding="utf-8"))
        lut, names = build_swaps(colors, swaps)
        lut.save(pal.PALETTE_DIR / "swaps_lut.png")
        (pal.PALETTE_DIR / "swaps_lut.json").write_text(
            json.dumps({"palette": master, "rows": names}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"swaps_lut.png: {len(names)} Varianten ({', '.join(names)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
