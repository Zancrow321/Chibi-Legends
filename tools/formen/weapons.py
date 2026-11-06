#!/usr/bin/env python3
"""Waffen der Baukasten-Stile nachbearbeiten.

PixelLab liefert 64x64 (<id>.roh.png, diagonal). Das Skript schnappt auf die
Palette und misst Griff und Spitze über die Hauptachse der Pixel. Der Griff
liegt unten links, außer bei den Waffen in GRIP_TOP (oben rechts).
Ergebnis: <id>.png (Maßstab 1) + anchors.json.

    python3 -I tools/formen/weapons.py && python3 tools/formen/build.py
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets/creator/weapons/formen"
# Stangen und Hämmer: weiter oben greifen, zweihändig
POLE = {"sonnenspeer": 0.3, "nordlichtstab": 0.3, "geisterlaterne": 0.3, "kettensichel": 0.22,
        "lavahammer": 0.22, "donnerhammer": 0.22, "runenhammer": 0.22}
GRIP_TOP = {"bluetenklinge", "wellenschneide"}
TWOHAND = {"sonnenspeer", "nordlichtstab", "lavahammer", "donnerhammer", "runenhammer"}


def anchors(im, grip_at, grip_top):
    px = im.load()
    pts = [(x + 0.5, y + 0.5) for y in range(im.height) for x in range(im.width) if px[x, y][3] > 0]
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts) / n
    syy = sum((p[1] - my) ** 2 for p in pts) / n
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts) / n
    import math
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    ax, ay = math.cos(ang), math.sin(ang)
    proj = [((p[0] - mx) * ax + (p[1] - my) * ay, p) for p in pts]
    lo = min(t for t, _ in proj)
    hi = max(t for t, _ in proj)
    span = hi - lo
    # Achse so drehen, dass sie vom Griff zur Spitze zeigt (Griff unten links: x wächst)
    if (ax > 0) == grip_top:
        ax, ay = -ax, -ay
        proj = [(-t, p) for t, p in proj]
        lo, hi = -hi, -lo

    def centre(t0, t1):
        sel = [p for t, p in proj if t0 <= t <= t1]
        return [round(sum(p[0] for p in sel) / len(sel), 1), round(sum(p[1] for p in sel) / len(sel), 1)]

    g = lo + span * grip_at
    return centre(g - 2.5, g + 2.5), centre(hi - 3.0, hi)


def main():
    res = {}
    for raw in sorted(Path(sys.argv[1] if len(sys.argv) > 1 else DIR).glob("*.roh.png")):
        wid = raw.name[:-len(".roh.png")]
        out = DIR / (wid + ".png")
        Image.open(raw).convert("RGBA").save(out)
        subprocess.run([sys.executable, str(ROOT / "tools/palette/quantize.py"), str(out), "--inplace",
                        "--max-colors", "24"], check=True, stdout=subprocess.DEVNULL)
        im = Image.open(out).convert("RGBA")
        g, t = anchors(im, POLE.get(wid, 0.12), wid in GRIP_TOP)
        res[wid] = {"scale": 1, "grip": g, "tip": t}
        if wid in TWOHAND:
            res[wid]["twohand"] = True
        print(wid, res[wid])
    (DIR / "anchors.json").write_text(json.dumps(res, indent=1) + "\n")


if __name__ == "__main__":
    main()
