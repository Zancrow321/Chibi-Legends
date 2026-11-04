"""Snap sprites to the master palette (PixelLab outputs, imports, placeholders).

    # one file or whole folders, results next to the input as <name>.q.png
    python3 tools/palette/quantize.py raw/raiga_idle.png

    # PixelLab downloads -> clean sprites, max. 16 colors per sprite, dark outline
    python3 tools/palette/quantize.py pixellab_raw/ -o assets/characters/raw --max-colors 16 --outline

    # only check (CI / before commit): exit code 1 on off-palette pixels or too many colors
    python3 tools/palette/quantize.py assets/characters/raw --check --max-colors 16

Steps per image:
1. alpha is made hard (>= 128 opaque, rest fully transparent; no soft edges)
2. every color goes to the nearest master palette color (OKLab distance)
3. with --max-colors N: the rarest colors are merged into their closest
   used neighbor until at most N remain (the outline color is kept)
4. with --outline: edge pixels touching transparency that are already dark
   become the palette's outline color (darkest color, or --outline-color)

A sheet (several frames in one PNG) counts as one sprite, so all frames share
the same colors. Use --indexed to write palette PNGs that Aseprite opens with
the master palette already loaded.
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette as pal  # noqa: E402

ALPHA_CUT = 128


def hard_alpha(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = [(r, g, b, 255) if a >= ALPHA_CUT else (0, 0, 0, 0) for r, g, b, a in pal.pixels(img)]
    out = Image.new("RGBA", img.size)
    out.putdata(px)
    return out


def edge_mask(img: Image.Image) -> list[bool]:
    w, h = img.size
    a = [p[3] > 0 for p in pal.pixels(img)]
    edge = [False] * (w * h)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not a[i]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not a[ny * w + nx]:
                    edge[i] = True
                    break
    return edge


def quantize(img: Image.Image, colors: list, *, max_colors: int = 0, outline: bool = False,
             outline_color: tuple | None = None, outline_l: float = 0.42) -> tuple[Image.Image, dict]:
    m = pal.Matcher(colors)
    img = hard_alpha(img)
    data = pal.pixels(img)
    idx = [m.index(p[:3]) if p[3] else -1 for p in data]

    line_i = colors.index(outline_color) if outline_color else colors.index(pal.darkest(colors))
    if outline:
        edge = edge_mask(img)
        for i, e in enumerate(edge):
            if e and idx[i] >= 0 and m.labs[idx[i]][0] < outline_l:
                idx[i] = line_i

    merged = 0
    if max_colors:
        counts = Counter(i for i in idx if i >= 0)
        remap = {i: i for i in counts}
        while len(counts) > max_colors:
            victim = min((i for i in counts if i != line_i), key=lambda i: counts[i])
            target = min((i for i in counts if i != victim), key=lambda i: pal.dist(m.labs[victim], m.labs[i]))
            counts[target] += counts.pop(victim)
            for k, v in remap.items():
                if v == victim:
                    remap[k] = target
            merged += 1
        idx = [remap[i] if i >= 0 else -1 for i in idx]

    out = Image.new("RGBA", img.size)
    out.putdata([(*colors[i], 255) if i >= 0 else (0, 0, 0, 0) for i in idx])
    used = Counter(i for i in idx if i >= 0)
    edge = edge_mask(out)
    n_edge = sum(edge)
    n_line = sum(1 for i, e in enumerate(edge) if e and idx[i] == line_i)
    stats = {
        "colors": len(used),
        "merged": merged,
        "outline_share": (n_line / n_edge) if n_edge else 0.0,
        "used": [pal.to_hex(colors[i]) for i, _ in used.most_common()],
    }
    return out, stats


def to_indexed(img: Image.Image, colors: list) -> Image.Image:
    """P-mode PNG with the full master palette; index 0 = transparent."""
    lut = {c: i + 1 for i, c in enumerate(colors)}
    p = Image.new("P", img.size, 0)
    p.putdata([lut[px[:3]] if px[3] else 0 for px in pal.pixels(img)])
    flat = [0, 0, 0] + [v for c in colors for v in c]
    p.putpalette(flat + [0] * (768 - len(flat)))
    p.info["transparency"] = 0
    return p


def check(img: Image.Image, colors: list, max_colors: int) -> list[str]:
    allowed = set(colors)
    problems = []
    rgba = img.convert("RGBA")
    soft = sum(1 for p in pal.pixels(rgba) if 0 < p[3] < 255)
    off = {p[:3] for p in pal.pixels(rgba) if p[3] and p[:3] not in allowed}
    used = {p[:3] for p in pal.pixels(rgba) if p[3]}
    if soft:
        problems.append(f"{soft} halbtransparente Pixel")
    if off:
        problems.append(f"{len(off)} Farben außerhalb der Palette, z. B. #{pal.to_hex(next(iter(off)))}")
    if max_colors and len(used) > max_colors:
        problems.append(f"{len(used)} Farben (erlaubt: {max_colors})")
    return problems


def inputs(paths: list[str]) -> list[Path]:
    files = []
    for p in map(Path, paths):
        if p.is_dir():
            files += sorted(f for f in p.rglob("*.png") if not f.name.endswith(".q.png"))
        else:
            files.append(p)
    return files


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="PNG-Dateien oder Ordner")
    ap.add_argument("-o", "--out", help="Zielordner (Standard: neben der Datei als .q.png)")
    ap.add_argument("--inplace", action="store_true", help="Eingabedatei überschreiben")
    ap.add_argument("--palette", help="Palettenname in assets/palettes (Standard: config.json)")
    ap.add_argument("--max-colors", type=int, default=0, help="höchstens N Farben pro Sprite (Stil: 13-16)")
    ap.add_argument("--outline", action="store_true", help="dunkle Randpixel auf die Umrissfarbe setzen")
    ap.add_argument("--outline-color", help="Hex-Farbe des Umrisses (Standard: dunkelste Palettenfarbe)")
    ap.add_argument("--indexed", action="store_true", help="als indizierte PNG speichern (Aseprite)")
    ap.add_argument("--check", action="store_true", help="nur prüfen, nichts schreiben")
    args = ap.parse_args()

    colors = pal.load(args.palette)
    line = pal.parse_hex(args.outline_color) if args.outline_color else None
    if line and line not in colors:
        ap.error("--outline-color muss eine Palettenfarbe sein")
    files = inputs(args.paths)
    if not files:
        ap.error("keine PNG-Dateien gefunden")

    bad = 0
    for f in files:
        img = Image.open(f)
        if args.check:
            problems = check(img, colors, args.max_colors)
            if problems:
                bad += 1
                print(f"FEHLER {f}: " + "; ".join(problems))
            continue
        out, st = quantize(img, colors, max_colors=args.max_colors, outline=args.outline, outline_color=line)
        if args.inplace:
            dst = f
        elif args.out:
            base = Path(args.paths[0]) if Path(args.paths[0]).is_dir() else f.parent
            rel = f.relative_to(base) if f.is_relative_to(base) else Path(f.name)
            dst = Path(args.out) / rel
        else:
            dst = f.with_suffix(".q.png")
        dst.parent.mkdir(parents=True, exist_ok=True)
        (to_indexed(out, colors) if args.indexed else out).save(dst)
        print(f"{f} -> {dst}: {st['colors']} Farben"
              + (f", {st['merged']} zusammengelegt" if st["merged"] else "")
              + f", Umriss {st['outline_share']:.0%} des Rands")
    if args.check:
        print(f"{len(files) - bad}/{len(files)} in Ordnung")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
