"""Vorschau-GIF der Lauffeuer-Effekte mit Bloom (nur Darstellung, kein Spielcode).

Szene: drei Brandherde, Flammenfaust zuendet sie als Kette (Ausbrueche),
dann Brandgestirn mit Einschlag. Bloom = weichgezeichnete helle Anteile additiv.
"""
import json, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
FX = os.path.join(ROOT, "assets", "vfx", "lauffeuer")
info = json.load(open(os.path.join(FX, "fx.json")))
def fr(name):
    s = Image.open(os.path.join(FX, name + ".png")).convert("RGBA"); i = info[name]
    return [s.crop((k * i["w"], 0, (k + 1) * i["w"], i["h"])) for k in range(i["frames"])]
F = {n: fr(n) for n in info}

W, H, GROUND = 320, 180, 150
def bg():
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(18 + 30 * t), int(14 + 10 * t), int(34 + 6 * t), 255))
    d.rectangle([0, GROUND, W, H], fill=(28, 22, 30, 255))
    d.line([(0, GROUND), (W, GROUND)], fill=(70, 50, 60, 255))
    return im

def put(canvas, img, cx, by, glow):
    x, y = int(cx - img.width / 2), int(by - img.height)
    canvas.alpha_composite(img, (x, y)); glow.alpha_composite(img, (x, y))

frames = []
HERDE = [130, 180, 230]
for t in range(64):
    c = bg(); g = Image.new("RGBA", (W, H)); dark = 1.0
    # Brandherde bis sie gezuendet werden
    fist_x = 40 + t * 16 if t < 14 else None
    for k, hx in enumerate(HERDE):
        lit = fist_x is not None and fist_x >= hx or t >= 14
        if not lit:
            put(c, F["brandherd"][t % 8], hx, GROUND + 2, g)
        else:
            t0 = (hx - 40) // 16
            a = t - t0
            if 0 <= a < 10:
                put(c, F["ausbruch"][a].resize((128, 192), Image.NEAREST), hx, GROUND + 4, g)
    if fist_x is not None and t < 14:
        f = F["flammenfaust"][min(t, 9)].resize((144, 96), Image.NEAREST)
        put(c, f, fist_x, GROUND - 10, g)
    # Brandgestirn
    if 24 <= t < 40:
        dark = 0.45
        ball = F["brandgestirn"][t % 8]
        s = int(64 + (t - 24) * 10); ball = ball.resize((min(s, 200), min(s, 200)), Image.NEAREST)
        put(c, ball, 160, 20 + ball.height + (t - 24) * 3 if t >= 34 else 20 + ball.height, g)
    if 40 <= t < 52:
        e = F["einschlag"][t - 40].resize((384, 288), Image.NEAREST)
        put(c, e, 160, GROUND + 60, g)
        for k in range(3):
            put(c, F["zunderflocke"][(t + k) % 8].resize((48, 48), Image.NEAREST), 90 + k * 70, GROUND - 40 - (t - 40) * 4, g)
    if t == 40:
        c = Image.blend(c, Image.new("RGBA", (W, H), (255, 250, 230, 255)), 0.8)
    if dark < 1.0:
        shade = Image.new("RGBA", (W, H), (0, 0, 0, int(255 * (1 - dark))))
        base = bg(); base.alpha_composite(shade); base.alpha_composite(Image.composite(c, Image.new("RGBA", (W, H)), g.split()[3]))
        c = base
    # Bloom
    glow = g.convert("RGB").filter(ImageFilter.GaussianBlur(10))
    glow2 = g.convert("RGB").filter(ImageFilter.GaussianBlur(3))
    out = ImageChops.add(c.convert("RGB"), glow, scale=1.1)
    out = ImageChops.add(out, glow2, scale=1.6)
    frames.append(out.resize((W * 3, H * 3), Image.NEAREST))

out = sys.argv[1]
frames[0].save(out, save_all=True, append_images=frames[1:], duration=70, loop=0, optimize=True)
frames[44].save(out.replace(".gif", "_einschlag.png")); frames[9].save(out.replace(".gif", "_kette.png"))
frames[30].save(out.replace(".gif", "_gestirn.png"))
