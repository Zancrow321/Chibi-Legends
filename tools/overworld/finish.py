#!/usr/bin/env python3
"""Cleans the PixelLab results in assets/overworld/raw/: hard alpha, snapped
to Resurrect 64 (tools/palette/quantize.py), cropped to the drawing with the
foot line at the bottom. Writes assets/overworld/<name>.png and sizes.json
(width, height). Run from the repo root:
    python3 tools/overworld/finish.py
"""
import json, pathlib, sys
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "palette"))
import quantize  # noqa: E402
import palette  # noqa: E402

RAW = ROOT / "assets" / "overworld" / "raw"
OUT = ROOT / "assets" / "overworld"


def main() -> None:
    colors = palette.load()
    sizes = {}
    for f in sorted(RAW.glob("*.png")):
        img = Image.open(f).convert("RGBA")
        mc = 20 if f.stem.startswith("npc_") else 40
        img, _ = quantize.quantize(img, colors, max_colors=mc)
        box = img.getbbox()
        img = img.crop(box)
        img.save(OUT / f.name)
        sizes[f.stem] = [img.width, img.height]
        print(f.stem, img.size)
    (OUT / "sizes.json").write_text(json.dumps(sizes, indent=1))


if __name__ == "__main__":
    main()
