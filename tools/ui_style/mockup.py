"""Vorschau (Mockup) des Manga-HUD: legt die echten 9-Slice-Teile ueber einen alten
Spiel-Screenshot an die Positionen aus scripts/ui/hud.gd. Kein echter Spiel-Screenshot.

    python3 tools/ui_style/mockup.py <screenshot.png> <ausgabe.png>
"""
import json, sys, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter

R = pathlib.Path(__file__).parents[2]
D = R / "assets/ui/manga"
SL = json.load(open(D / "slices.json"))
INK = (46, 34, 47, 255); PAPER = (255, 255, 255, 255); RED = (232, 59, 59, 255)
F = lambda s: ImageFont.truetype(str(R / "assets/fonts/PixelifySans-SemiBold.ttf"), s)

def nine(part, w, h, tint=None):
    t = Image.open(D / f"{part}.png").convert("RGBA"); l, tp, r, b = SL[part]
    W, H = t.size; out = Image.new("RGBA", (w, h))
    xs = [(0, l, 0, l), (l, W - r, l, w - r), (W - r, W, w - r, w)]
    ys = [(0, tp, 0, tp), (tp, H - b, tp, h - b), (H - b, H, h - b, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                out.paste(t.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out

def halftone(d, x0, y0, x1, y1, col, step=4):
    row = 0; y = y0 + 1
    while y < y1:
        x = x0 + (step // 2 if row % 2 else 0)
        while x < x1 - 1:
            d.rectangle([x, y, x + 1, y + 1], fill=col); x += step
        y += step // 2; row += 1

def text(d, xy, s, size, col=INK, anchor="la"):
    d.text(xy, s, font=F(size), fill=col, anchor=anchor, stroke_width=2, stroke_fill=PAPER)

img = Image.open(sys.argv[1]).convert("RGBA")
# alte HUD-Flaechen weich zudecken: Ausschnitte unscharf machen
blur = img.filter(ImageFilter.GaussianBlur(6))
for box in [(10, 10, 470, 150), (14, 140, 380, 282), (480, 14, 915, 44), (925, 14, 1268, 338),
            (686, 548, 1266, 650), (560, 644, 1268, 702), (12, 650, 340, 690)]:
    img.paste(blur.crop(box), box[:2])
d = ImageDraw.Draw(img)

def panel(x, y, w, h):
    if h >= 40:
        img.alpha_composite(nine("panel", w, h), (x, y))
    else:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=PAPER, outline=INK, width=2)
        hw = min(60, int(w * 0.3)); halftone(d, x + w - hw, y + 3, x + w - 3, y + h - 3, (46, 34, 47, 64))

# Status links oben
d.rectangle([16, 16, 139, 107], fill=(255, 122, 89, 255), outline=INK, width=2)
d.rectangle([16, 16, 139, 45], fill=(209, 100, 73, 255), outline=INK, width=2)
text(d, (78, 38), "Schüler", 18, anchor="ms"); d.text((26, 94), "Lv.", font=F(24), fill=(90, 29, 16, 255), anchor="ls")
text(d, (64, 98), "1", 46, anchor="ls")
panel(152, 16, 310, 26); text(d, (166, 35), "Akademie-Schüler", 17, anchor="ls"); text(d, (332, 35), "KK 780", 16, (197, 50, 50, 255), "ls")
fr = nine("hp_bar", 310, 32); img.alpha_composite(fr, (152, 49))
l, t, r, b = SL["hp_bar"]; d.rectangle([152 + l - 1, 49 + t, 152 + 310 - r, 49 + 32 - b - 1], fill=(232, 67, 58, 255))
d.rectangle([152 + l - 1, 49 + t, 152 + 310 - r, 49 + t + 2], fill=(246, 160, 155, 255))
halftone(d, 152 + l - 1, 49 + t + 11, 152 + 310 - r, 49 + 32 - b, (0, 0, 0, 56))
text(d, (152 + l + (310 - l - 10) / 2, 52 + 19), "1.200 / 1.200", 16, anchor="ms")
img.alpha_composite(nine("super_bar", 310, 34), (152, 85))
l, t, r, b = SL["super_bar"]; ix0, ix1 = 152 + l - 1, 152 + 310 - r + 1; seg = (ix1 - ix0) / 3
for i in range(3):
    d.rectangle([ix0 + i * seg + 1, 85 + t, ix0 + (i + 1) * seg - 2, 85 + 34 - b - 1], fill=(255, 122, 42, 255))
for i in (1, 2):
    bx = ix0 + i * seg; d.line([(bx + 4, 85 + t), (bx - 4, 85 + 34 - b)], fill=INK, width=3)
text(d, (ix0 + (ix1 - ix0) / 2, 92 + 16), "Legendenleiste  3 / 3", 14, anchor="ms")
panel(152, 128, 310, 26); text(d, (166, 147), "Glutatem", 16, (140, 80, 20, 255), "ls"); text(d, (328, 147), "Klinge: kalt", 15, anchor="ls")
for i in range(3):
    cx = 258 + i * 22; d.ellipse([cx - 7, 134, cx + 7, 148], fill=(13, 8, 15, 255))
# Hinweis oben Mitte
panel(480, 16, 430, 26); text(d, (494, 35), "Glutatem: L + Richtung, L halten = verstärkt", 15, anchor="ls")
# Training
panel(16, 160, 360, 124); text(d, (32, 186), "Training", 17, (197, 50, 50, 255), "ls")
for k, (a, v) in enumerate([("Schaden pro Sek.", "0"), ("Gesamtschaden", "0"), ("Letzte Reaktion", "-")]):
    text(d, (32, 212 + 22 * k), a, 15, anchor="ls"); text(d, (206, 212 + 22 * k), v, 15, anchor="ls")
# rechte Spalte
panel(930, 16, 334, 26); text(d, (944, 35), "Akademie · Trainingswald", 16, anchor="ls")
panel(930, 50, 334, 108); d.rectangle([948, 68, 1246, 140], fill=(74, 138, 62, 255), outline=INK, width=2)
panel(930, 166, 334, 168); text(d, (946, 189), "Hauptquest  |  Tagesquest", 16, (197, 50, 50, 255), "ls")
text(d, (946, 219), "Erste Lektion: Alle Reaktionen (0/4)", 15, anchor="ls")
for k, q in enumerate(["Dampfexplosion", "Überladung", "Kristallbruch", "Feuersturm"]):
    d.rectangle([948, 232 + 22 * k, 962, 246 + 22 * k], outline=INK, width=2); text(d, (972, 245 + 22 * k), q, 15, anchor="ls")
# Skill-Leiste
src = Image.open(sys.argv[1]).convert("RGBA")
panel(690, 552, 572, 96)
for i in range(8):
    x = 702 + i * 70; img.alpha_composite(nine("skill_slot", 74, 74), (x - 6, 558))
    ic = src.crop((x + 6, 570, x + 56, 620)); img.alpha_composite(ic, (x + 6, 570))
    d.rectangle([x - 4, 558, x + 22, 576], fill=PAPER, outline=INK, width=2)
# Menue
names = ["Charakter", "Fähigkeiten", "Inventar", "Gruppe", "Gilde", "Gacha", "Shop", "Optionen"]
for i, n in enumerate(names):
    x = 564 + i * 88; img.alpha_composite(nine("button", 88, 54), (x - 2, 646)); text(d, (x + 42, 692), n, 13, anchor="ms")
panel(16, 654, 170, 32); text(d, (56, 677), "0  Sternkristalle", 16, anchor="ls")
panel(194, 654, 140, 32); text(d, (230, 677), "0  Splitter", 16, anchor="ls")
img.save(sys.argv[2]); print("ok", sys.argv[2])
