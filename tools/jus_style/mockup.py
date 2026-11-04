"""Vorher/Nachher-Bild mit Probe der Manga-Effekte (Speedlines, Halbton, Stern-Treffer, Lautmalerei).
Aufruf: mockup.py alt_vorschau.png out.png"""
import math, random, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = "assets/characters/jus_test/"
OLD_PREVIEW, OUT = sys.argv[1:3]
S = 3
BG = (34, 38, 46, 255)
FONT_B = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"

def up(im, s=S):
    return im.resize((im.width * s, im.height * s), Image.NEAREST)

def frame(strip, i):
    return Image.open(ROOT + strip).convert("RGBA").crop((96 * i, 0, 96 * i + 96, 96))

# --- Effekt-Szene in nativer Aufloesung (180 x 100) ---
W, H = 180, 100
scene = Image.new("RGBA", (W, H), (250, 236, 200, 255))
d = ImageDraw.Draw(scene)
hx, hy = 118, 58  # Trefferpunkt
# Halbton-Raster: Punkte werden zum Treffer hin groesser
for y in range(0, H, 4):
    for x in range((y // 4) % 2 * 2, W, 4):
        dist = math.hypot(x - hx, y - hy)
        r = max(0, 1.6 - dist / 70)
        if r > 0.3:
            d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 120, 60, 255))
# radiale Speedlines
random.seed(4)
for k in range(70):
    a = random.uniform(0, 2 * math.pi)
    r0 = random.uniform(30, 55); r1 = 140
    w = random.choice((1, 1, 2))
    d.line((hx + math.cos(a) * r0, hy + math.sin(a) * r0, hx + math.cos(a) * r1, hy + math.sin(a) * r1),
           fill=(30, 24, 30, 255), width=w)
# Figur (Schlag-Frame)
fig = frame("testfigur_slash.png", 7)
scene.alpha_composite(fig, (30, H - 96))
# Stern-Treffer
def star(cx, cy, r_out, r_in, n, fill, outline=None):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi * i / n - math.pi / 2
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=fill, outline=outline)
star(hx + 8, hy + 2, 20, 7, 8, (255, 90, 50, 255), (30, 24, 30, 255))
star(hx + 8, hy + 2, 13, 5, 8, (255, 255, 255, 255))
# Lautmalerei mit dickem Umriss, schraeg
txt = Image.new("RGBA", (90, 40), (0, 0, 0, 0))
td = ImageDraw.Draw(txt)
f = ImageFont.truetype(FONT_B, 22)
for ox in range(-2, 3):
    for oy in range(-2, 3):
        td.text((6 + ox, 4 + oy), "ZACK!", font=f, fill=(30, 24, 30, 255))
td.text((6, 4), "ZACK!", font=f, fill=(255, 220, 40, 255))
txt = txt.rotate(14, resample=Image.NEAREST, expand=True)
scene.alpha_composite(txt, (100, 0))
# harte Pixel: Alpha binarisieren
px = scene.load()
for y in range(H):
    for x in range(W):
        r, g, b, a = px[x, y]
        px[x, y] = (r, g, b, 255)

# --- Gesamtbild ---
old = Image.open(OLD_PREVIEW).convert("RGBA").crop((0, 0, 192, 192))  # bereits 3x
new = up(Image.open(ROOT + "testfigur_still.png").convert("RGBA"))
eff = up(scene)
pad = 24; lab = 34
Wt = pad + old.width + pad + new.width + pad + eff.width + pad
Ht = lab + max(eff.height, new.height) + pad
out = Image.new("RGBA", (Wt, Ht), BG)
od = ImageDraw.Draw(out)
lf = ImageFont.truetype(FONT_B, 18)
x = pad
for im, label in ((old, "Vorher (32x48)"), (new, "Nachher (Test, 96er Zelle)"), (eff, "Treffer mit Manga-Effekten")):
    out.alpha_composite(im, (x, lab + (Ht - lab - pad - im.height) // 2 if im is not eff else lab))
    od.text((x, 8), label, font=lf, fill=(235, 235, 240, 255))
    x += im.width + pad
out.save(OUT)

# Animations-GIF (idle + slash), 4x
frames = [frame("testfigur_idle.png", i) for i in range(5)] * 2 + [frame("testfigur_slash.png", i) for i in range(8)]
gif = []
for fr in frames:
    c = Image.new("RGBA", (96, 96), BG); c.alpha_composite(fr); gif.append(up(c, 4).convert("P", palette=Image.ADAPTIVE))
durs = [160] * 10 + [90, 90, 70, 70, 60, 200, 120, 160]
gif[0].save(OUT.replace(".png", ".gif"), save_all=True, append_images=gif[1:], duration=durs, loop=0, disposal=2)
