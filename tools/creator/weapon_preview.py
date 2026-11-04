"""Vorschau: Waffe an den Handanker hängen, Verband per Seil-Physik animieren.

Nur ein Test-Werkzeug für den Creator. Die Waffe wird pro Frame an
`hand_front` gesetzt und auf den Unterarm-Winkel gedreht. Der Verband ist ein
Seil (Verlet), das am Knauf hängt und der Handbewegung nachschwingt, so wie es
später im Spiel per Code laufen soll (keine eigenen Zeichnungen pro Frame).

Aufruf: python3 weapon_preview.py <waffe.png> <frames-ordner> <anchors.json> <ausgabe-ordner>
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PAD = 56                    # Rand um die 64er-Zelle, damit die Klinge Platz hat
SCALE = 4                   # Vergrößerung für die Vorschau
WEAPON_SCALE = 2            # Zweihänder: doppelt so groß wie das 32er-Bild
GRIP = (9.5, 22.5)          # Griffpunkt im 32er-Schwertbild (unteres Ende, wo der Verband sitzt)
TIP = (29.0, 2.0)           # Klingenspitze
POMMEL_BACK = 4.0           # Knauf liegt so weit hinter dem Griff
FIST = 2.0                  # Faustmitte liegt so weit vor dem Handgelenk-Anker
RIBBON_LIGHT = (224, 224, 224, 255)
RIBBON_SHADE = (196, 196, 196, 255)
RIBBON_LINE = (61, 61, 61, 255)

BLADE_ANGLE = math.degrees(math.atan2(TIP[0] - GRIP[0], TIP[1] - GRIP[1]))


def load_blade(path):
    """Schwert ohne den gezeichneten Verband (nur Pixel nahe der Klingenachse)."""
    im = Image.open(path).convert("RGBA")
    if im.width > 64:  # hochskaliertes Pixelbild auf echte Größe bringen
        f = im.width // 32
        small = Image.new("RGBA", (im.width // f, im.height // f))
        p, q = im.load(), small.load()
        for y in range(small.height):
            for x in range(small.width):
                c = p[x * f + f // 2, y * f + f // 2]
                q[x, y] = (0, 0, 0, 0) if abs(c[1] - 148) < 10 and abs(c[2] - 111) < 10 else c
        im = small
    im = _cut(im)
    return im.resize((im.width * WEAPON_SCALE, im.height * WEAPON_SCALE), Image.NEAREST)


def _cut(im):
    ax, ay = TIP[0] - GRIP[0], TIP[1] - GRIP[1]
    L = math.hypot(ax, ay)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] == 0:
                continue
            t = ((x - GRIP[0]) * ax + (y - GRIP[1]) * ay) / L
            d = abs((x - GRIP[0]) * ay - (y - GRIP[1]) * ax) / L
            if d > 5.0 or t < -2.0:
                px[x, y] = (0, 0, 0, 0)
    return im


def rotate_about(im, pivot, deg, k=8):
    """Pixelfreundliches Drehen: groß skalieren, nächster Nachbar, zurück."""
    big = im.resize((im.width * k, im.height * k), Image.NEAREST)
    big = big.rotate(deg, resample=Image.NEAREST, center=(pivot[0] * k, pivot[1] * k), expand=False)
    out = Image.new("RGBA", im.size)
    bp, op = big.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            op[x, y] = bp[x * k + k // 2, y * k + k // 2]
    return out


def place_blade(blade, hand, hand_angle, size):
    """Schwert so setzen, dass der Griff auf der Hand liegt und die Klinge dem Unterarm folgt."""
    canvas = Image.new("RGBA", (size, size))
    big = Image.new("RGBA", (160, 160))
    g = (GRIP[0] * WEAPON_SCALE, GRIP[1] * WEAPON_SCALE)
    off = (80 - g[0], 80 - g[1])
    big.alpha_composite(blade, (int(off[0]), int(off[1])))
    # PIL dreht gegen den Uhrzeigersinn; unser Winkel wächst im Uhrzeigersinn-Sinn der Bildschirmachsen
    rot = rotate_about(big, (80, 80), hand_angle - BLADE_ANGLE, k=4)
    canvas.alpha_composite(rot, (int(round(hand[0] - 80)), int(round(hand[1] - 80))))
    return canvas


class Ribbon:
    def __init__(self, n=11, seg=2.4):
        self.n, self.seg = n, seg
        self.p = None
        self.o = None

    def step(self, anchor, gravity=0.16, damp=0.92, wind=0.015, t=0):
        if self.p is None:
            self.p = [(anchor[0] - 0.3 * i, anchor[1] + self.seg * i) for i in range(self.n)]
            self.o = list(self.p)
        newp = [anchor]
        for i in range(1, self.n):
            x, y = self.p[i]; ox, oy = self.o[i]
            w = wind * math.sin(t * 0.07 + i * 0.6)
            newp.append((x + (x - ox) * damp - w, y + (y - oy) * damp + gravity))
        self.o, self.p = self.p, newp
        for _ in range(6):
            self.p[0] = anchor
            for i in range(1, self.n):
                ax, ay = self.p[i - 1]; bx, by = self.p[i]
                dx, dy = bx - ax, by - ay
                d = math.hypot(dx, dy) or 1e-6
                k = (d - self.seg) / d
                if i == 1:
                    self.p[i] = (bx - dx * k, by - dy * k)
                else:
                    self.p[i - 1] = (ax + dx * k * 0.5, ay + dy * k * 0.5)
                    self.p[i] = (bx - dx * k * 0.5, by - dy * k * 0.5)

    def draw(self, size):
        img = Image.new("RGBA", (size, size))
        d = ImageDraw.Draw(img)
        pts = [(round(x), round(y)) for x, y in self.p]
        d.line([(x, y + 1) for x, y in pts], fill=RIBBON_SHADE, width=2)
        d.line(pts, fill=RIBBON_LIGHT, width=2)
        # dunkler Umriss wie beim Rest der Figur
        a = img.load()
        out = Image.new("RGBA", (size, size)); o = out.load()
        for y in range(size):
            for x in range(size):
                if a[x, y][3] == 0 and any(0 <= x + dx < size and 0 <= y + dy < size and a[x + dx, y + dy][3]
                                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    o[x, y] = RIBBON_LINE
        out.alpha_composite(img)
        return out


SEQUENCES = [
    ("idle", ["idle_0", "idle_1", "idle_2", "idle_3"] * 3, 8),
    ("walk", ["walk_0", "walk_1", "walk_2", "walk_3", "walk_4", "walk_5"] * 2, 6),
    ("run", ["run_0", "run_1", "run_2", "run_3"] * 3, 5),
    ("combo", ["idle_0", "slash_wind", "slash_hit", "slash_hit", "slash_side", "slash_side", "upper_wind", "upper_hit",
               "upper_hit", "thrust_hit", "thrust_hit", "idle_0", "idle_1", "idle_2"], 6),
    ("air", ["jump_0", "jump_1", "fall_0", "fall_1", "land_0", "idle_0"], 8),
]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def lerp_angle(a, b, t):
    d = (b - a + 180) % 360 - 180
    return a + d * t


def main():
    blade = load_blade(sys.argv[1])
    fdir = Path(sys.argv[2])
    anchors = {f["name"]: f for f in json.load(open(sys.argv[3]))["frames"]}
    out = Path(sys.argv[4]); out.mkdir(parents=True, exist_ok=True)
    size = 64 + 2 * PAD
    bg = (40, 46, 64, 255)
    all_frames = []
    for name, seq, hold in SEQUENCES:
        rib = Ribbon()
        frames = []
        tick = 0
        for i, fname in enumerate(seq):
            a = anchors[fname]["hand_front"]
            nxt = anchors[seq[(i + 1) % len(seq)]]["hand_front"]
            body = Image.open(fdir / f"{fname}.png").convert("RGBA")
            for h in range(hold):
                # Hand springt mit dem Bild, das Seil bekommt die Bewegung fein verteilt (Physik läuft mit 60 Hz)
                t = h / hold
                ang = a["angle"]
                r = math.radians(ang)
                hand = (a["pos"][0] + PAD + math.sin(r) * FIST, a["pos"][1] + PAD + math.cos(r) * FIST)
                pommel = (hand[0] - math.sin(r) * POMMEL_BACK, hand[1] - math.cos(r) * POMMEL_BACK)
                rib.step(pommel, t=tick)
                tick += 1
                if h % 2:  # Vorschau mit 30 Bildern pro Sekunde
                    continue
                cell = Image.new("RGBA", (size, size), bg)
                cell.alpha_composite(rib.draw(size))
                cell.alpha_composite(body, (PAD, PAD))
                cell.alpha_composite(place_blade(blade, hand, ang, size))
                frames.append(cell.resize((size * SCALE, size * SCALE), Image.NEAREST))
        frames[0].save(out / f"schwert_{name}.gif", save_all=True, append_images=frames[1:], duration=33, loop=0, disposal=2)
        all_frames += frames
    all_frames[0].save(out / "schwert_alles.gif", save_all=True, append_images=all_frames[1:], duration=33, loop=0)
    print("fertig", len(all_frames), "Bilder")


if __name__ == "__main__":
    main()
