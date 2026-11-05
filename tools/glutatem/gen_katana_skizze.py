"""Skizze für das Glutatem-Katana "Glutklinge" (40x40, kein KI-Bild).

Dient als Startbild (init_image) für PixelLab, damit Griff, Stichblatt und
Spitze genau an den Punkten in catalog.json bleiben ("grip" / "tip").
Schlanke, leicht gebogene Klinge aus dunklem Schmiedestahl mit glühender
Härtelinie, Stichblatt wie ein kleiner Amboss, rot umwickelter Griff.

    python3 -I tools/glutatem/gen_katana_skizze.py assets/creator/weapons/glutklinge_skizze.png
"""
import math
import sys

from PIL import Image

W = H = 40
BUTT = (5.0, 36.0)     # Knaufende
GRIP = (9.0, 31.5)     # Faust (catalog.json "grip")
GUARD = (12.5, 27.5)   # Stichblatt
TIP = (35.0, 4.0)      # Spitze (catalog.json "tip")

OUTL = (46, 34, 47, 255)
STEEL_D = (62, 53, 70, 255)
STEEL = (98, 85, 101, 255)
STEEL_L = (150, 141, 145, 255)
HAMON = (251, 107, 29, 255)
HAMON_L = (255, 200, 120, 255)
WRAP = (174, 35, 52, 255)
WRAP_D = (110, 39, 39, 255)
DIAMOND = (232, 59, 59, 255)
IRON = (66, 57, 52, 255)
IRON_L = (110, 100, 90, 255)
GOLD = (247, 150, 23, 255)


def main(path: str) -> None:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    ux, uy = TIP[0] - GUARD[0], TIP[1] - GUARD[1]
    L = math.hypot(ux, uy)
    ux, uy = ux / L, uy / L
    nx, ny = uy, -ux          # Normale zur Rückenseite (oben links)
    bend = 2.0                # Krümmung (sori) zur Rückenseite

    def center(s: float):
        b = bend * 4 * s * (1 - s)
        return GUARD[0] + ux * L * s + nx * b, GUARD[1] + uy * L * s + ny * b

    # Klinge
    for y in range(H):
        for x in range(W):
            cx, cy = x + 0.5, y + 0.5
            best = None
            for i in range(80):
                s = i / 79
                mx, my = center(s)
                d = math.hypot(cx - mx, cy - my)
                if best is None or d < best[0]:
                    best = (d, s, (cx - mx) * nx + (cy - my) * ny)
            d, s, side = best
            width = 1.9 if s < 0.88 else 1.9 * (1 - s) / 0.12 + 0.3
            if d > width or s <= 0.02:
                continue
            if d > width - 0.7:
                c = OUTL if side > 0 else HAMON_L
            elif side < -0.3:
                c = HAMON
            elif side > 0.5:
                c = STEEL_D
            else:
                c = STEEL_L if (x + y) % 5 == 0 else STEEL
            px[x, y] = c

    # Griff mit Wicklung (Rautenmuster)
    gx, gy = GUARD[0] - BUTT[0], GUARD[1] - BUTT[1]
    gl = math.hypot(gx, gy)
    for y in range(H):
        for x in range(W):
            cx, cy = x + 0.5, y + 0.5
            t = ((cx - BUTT[0]) * gx + (cy - BUTT[1]) * gy) / (gl * gl)
            if not -0.05 <= t <= 0.92:
                continue
            qx, qy = BUTT[0] + gx * t, BUTT[1] + gy * t
            d = math.hypot(cx - qx, cy - qy)
            if d > 1.7:
                continue
            if d > 1.1:
                px[x, y] = OUTL
            elif t < 0.08:
                px[x, y] = GOLD
            else:
                px[x, y] = DIAMOND if (x + y) % 3 == 0 else (WRAP if (x - y) % 2 else WRAP_D)

    # Stichblatt: kleiner Amboss quer zur Klinge
    for y in range(H):
        for x in range(W):
            cx, cy = x + 0.5, y + 0.5
            a = (cx - GUARD[0]) * ux + (cy - GUARD[1]) * uy
            b = (cx - GUARD[0]) * nx + (cy - GUARD[1]) * ny
            if -1.0 <= a <= 1.0 and -3.6 <= b <= 3.2:
                edge = a < -0.4 or a > 0.4 or b < -3.0 or b > 2.6
                px[x, y] = OUTL if edge else (IRON_L if b > 0 else IRON)
            elif 1.0 < a <= 2.0 and -1.4 <= b <= 1.4:
                px[x, y] = GOLD   # Habaki
    im.save(path)


if __name__ == "__main__":
    main(sys.argv[1])
