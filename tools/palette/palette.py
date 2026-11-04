"""Shared palette helpers: load Lospec .hex palettes, OKLab distance, exports.

The game's master palette is named in assets/palettes/config.json. Every
sprite (PixelLab output, Aseprite drawing, imported placeholder) is snapped to
it with quantize.py, so the whole game shares one color language and the
palette-remap shader can recolor anything by palette index.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PALETTE_DIR = ROOT / "assets" / "palettes"

RGB = tuple[int, int, int]


def pixels(img: Image.Image) -> list:
    """Pixel tuples (Pillow 12+ renamed getdata)."""
    f = getattr(img, "get_flattened_data", None)
    return list(f() if f else img.getdata())


def master_name() -> str:
    cfg = json.loads((PALETTE_DIR / "config.json").read_text(encoding="utf-8"))
    return cfg["master"]


def parse_hex(text: str) -> RGB:
    t = text.strip().lstrip("#")
    if len(t) != 6:
        raise ValueError(f"keine Hex-Farbe: {text!r}")
    return int(t[0:2], 16), int(t[2:4], 16), int(t[4:6], 16)


def to_hex(c: RGB) -> str:
    return "%02x%02x%02x" % c


def load(name: str | None = None) -> list[RGB]:
    """Colors of a palette in assets/palettes/<name>.hex (default: master)."""
    name = name or master_name()
    path = Path(name)
    if not path.suffix:
        path = PALETTE_DIR / f"{name}.hex"
    colors = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split(";")[0].strip()
        if line:
            colors.append(parse_hex(line))
    if not colors:
        raise ValueError(f"leere Palette: {path}")
    return colors


# --- OKLab (perceptual distance, better than RGB for skin and dark tones) ---

def _lin(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def oklab(c: RGB) -> tuple[float, float, float]:
    r, g, b = (_lin(v) for v in c)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s))
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def dist(a: tuple, b: tuple) -> float:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


class Matcher:
    """Nearest palette color with a cache (sprites reuse few colors)."""

    def __init__(self, colors: list[RGB]):
        self.colors = colors
        self.labs = [oklab(c) for c in colors]
        self._cache: dict[RGB, int] = {}

    def index(self, c: RGB) -> int:
        i = self._cache.get(c)
        if i is None:
            lab = oklab(c)
            i = min(range(len(self.colors)), key=lambda k: dist(lab, self.labs[k]))
            self._cache[c] = i
        return i


def darkest(colors: list[RGB]) -> RGB:
    return min(colors, key=lambda c: oklab(c)[0])


# --- exports for Aseprite, Godot and PixelLab ---

def write_gpl(colors: list[RGB], name: str, path: Path) -> None:
    lines = ["GIMP Palette", f"Name: {name}", "Columns: 8", "#"]
    lines += ["%3d %3d %3d\t%s" % (*c, to_hex(c)) for c in colors]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def strip_image(colors: list[RGB]) -> Image.Image:
    """N x 1 texture, one pixel per color (Godot shader uniform)."""
    img = Image.new("RGBA", (len(colors), 1))
    img.putdata([(*c, 255) for c in colors])
    return img


def swatch_image(colors: list[RGB], cell: int = 8, columns: int = 8) -> Image.Image:
    """Swatch grid; also usable as PixelLab `color_image` (forced palette)."""
    rows = math.ceil(len(colors) / columns)
    img = Image.new("RGBA", (columns * cell, rows * cell), (0, 0, 0, 0))
    for i, c in enumerate(colors):
        x, y = (i % columns) * cell, (i // columns) * cell
        img.paste((*c, 255), (x, y, x + cell, y + cell))
    return img


def pixellab_color_image(colors: list[RGB] | None = None) -> Image.Image:
    return swatch_image(colors or load(), cell=4)
