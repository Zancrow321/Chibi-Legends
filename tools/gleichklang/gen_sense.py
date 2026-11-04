"""Zeichnet die Sense "Nachhall" (Kampfstil Gleichklang) als 40x40-Pixelbild.

Kein KI-Bild: Schaft, Blatt und Klangloch werden hier per Geometrie gerastert,
damit die Waffe ohne PixelLab-Generierung im Spiel ist. Später kann ein
PixelLab-Bild sie ersetzen (gleiche Datei, Griff/Spitze in catalog.json).

Aufruf: python3 tools/gleichklang/gen_sense.py assets/creator/weapons/sense_nachhall_skizze.png
"""
import math
import sys

from PIL import Image

W = H = 40
GRIP = (11.0, 31.0)      # Faust (catalog.json "grip")
HEAD = (29.0, 13.0)      # Schaftende mit Klangloch (catalog.json "tip")
BUTT = (5.0, 37.0)       # Schaftende hinter dem Griff

OUT = (34, 28, 40, 255)        # Umriss
WOOD_D = (62, 46, 52, 255)     # Schaft dunkel
WOOD = (92, 70, 70, 255)       # Schaft
BRONZE_D = (128, 80, 50, 255)
BRONZE = (196, 132, 74, 255)
BRONZE_L = (240, 192, 120, 255)
METAL_D = (64, 66, 92, 255)    # Blatt Rücken (mattes Glockenmetall)
METAL = (120, 124, 150, 255)
METAL_L = (178, 186, 206, 255)
EDGE = (226, 240, 255, 255)    # Schneide, blass blau-weiß
SOUL = (143, 211, 255, 255)    # Klangloch-Kern


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    qx, qy = ax + dx * t, ay + dy * t
    return math.hypot(px - qx, py - qy), t


def main(path):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()

    # Blatt: Mittellinie vom Kopf nach oben-links, Spitze hängt nach unten
    u = (-0.6, -0.8)
    d = (-0.8, 0.6)
    pts = []
    n = 60
    for i in range(n + 1):
        s = i / n
        L = 22.0 * s
        bend = 16.0 * s ** 1.8
        pts.append((HEAD[0] + u[0] * L + d[0] * bend + 0.5, HEAD[1] - 1.5 + u[1] * L + d[1] * bend))
    blade = {}
    for y in range(H):
        for x in range(W):
            c = (x + 0.5, y + 0.5)
            best = None
            for i in range(n):
                dist, t = seg_dist(c, pts[i], pts[i + 1])
                s = (i + t) / n
                width = 3.6 * (1.0 - s) ** 0.8 + 0.5
                if dist <= width:
                    # Seite: + = Schneide (Innenseite, Richtung d)
                    sx = pts[i + 1][0] - pts[i][0]
                    sy = pts[i + 1][1] - pts[i][1]
                    side = (c[0] - pts[i][0]) * (-sy) - (c[1] - pts[i][1]) * (-sx)
                    k = dist / width
                    if best is None or k < best[0]:
                        best = (k, side, s)
            if best:
                blade[(x, y)] = best
    for (x, y), (k, side, s) in blade.items():
        inner = side < 0
        if k > 0.78:
            col = EDGE if inner else OUT
        elif inner and k > 0.45:
            col = METAL_L
        elif inner:
            col = METAL
        else:
            col = METAL_D if k > 0.35 else METAL
        px[x, y] = col
    # feine Rillen wie am Glockenrand
    for i in range(6, n - 10, 9):
        x, y = pts[i]
        xi, yi = int(x + d[0] * 1.2), int(y + d[1] * 1.2)
        if (xi, yi) in blade:
            px[xi, yi] = METAL_D

    # Schaft
    for y in range(H):
        for x in range(W):
            c = (x + 0.5, y + 0.5)
            dist, t = seg_dist(c, BUTT, HEAD)
            if dist <= 1.55:
                px[x, y] = WOOD if dist < 0.8 else WOOD_D
    # Bronzebänder
    for t in (0.14, 0.55, 0.86):
        bx = BUTT[0] + (HEAD[0] - BUTT[0]) * t
        by = BUTT[1] + (HEAD[1] - BUTT[1]) * t
        for y in range(H):
            for x in range(W):
                if math.hypot(x + 0.5 - bx, y + 0.5 - by) <= 1.6:
                    px[x, y] = BRONZE if (x + y) % 2 else BRONZE_L
    # Klangloch: Bronzefassung, dunkles Loch, schwebender Klöppel
    hx, hy = HEAD
    for y in range(H):
        for x in range(W):
            r = math.hypot(x + 0.5 - hx, y + 0.5 - hy)
            if r <= 3.9:
                px[x, y] = BRONZE_D if r > 3.1 else (BRONZE if r > 2.2 else OUT)
            if 2.2 < r <= 3.1 and (x + 0.5 - hx) + (y + 0.5 - hy) < -1.5:
                px[x, y] = BRONZE_L
    px[int(hx), int(hy)] = SOUL
    px[int(hx), int(hy) + 1] = METAL_L

    # Umriss um alles
    solid = {(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 0}
    for (x, y) in list(solid):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if 0 <= q[0] < W and 0 <= q[1] < H and q not in solid:
                px[q[0], q[1]] = OUT
    im.save(path)


if __name__ == "__main__":
    main(sys.argv[1])
