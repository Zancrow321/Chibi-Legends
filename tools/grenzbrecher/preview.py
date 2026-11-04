#!/usr/bin/env python3
"""Vorschau der Grenzbrecher-Effekte mit Bloom (additiv, weich), wie im Spiel.
    python3 -I tools/spannkraft/preview.py <ausgabe-ordner>
"""
import pathlib, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "combat" / "vfx" / "grenzbrecher"
ORDER = [("kern", "Kern (Strahl-Mündung)"), ("strahl", "Kernstrahl"), ("schockring", "Ki-Erschütterung"),
         ("faust", "Steilpfad-Folge"), ("tritt", "Drehtritt"), ("aura", "Aura (Sammeln)"),
         ("fernschritt", "Fernschritt"), ("meteor", "Meteor-Abschluss"), ("grenzbruch", "Grenzbruch"),
         ("sonnenkern", "Sonnenkern"), ("einschlag", "Einschlag"), ("schockring", "Ki-Erschütterung")]
BG = (14, 12, 24)
CELL, S = 300, 2


def bloom(frame: Image.Image, strength=1.0) -> Image.Image:
    rgb = frame.convert("RGB")
    bright = rgb.point(lambda v: max(0, v - 150) * 2)
    out = rgb
    for r, k in ((5, 0.8), (14, 0.6), (32, 0.45)):
        g = bright.filter(ImageFilter.GaussianBlur(r)).point(lambda v, k=k: int(v * k * strength))
        out = ImageChops.add(out, g)
    return out


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def cell(name, label, t=1.0):
    c = Image.new("RGBA", (CELL, CELL), BG + (255,))
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    sc = 0.55 + 0.45 * min(1.0, t * 1.6)
    size = int(128 * S * sc)
    im = im.resize((size, size), Image.NEAREST)
    a = 1.0 if t < 0.7 else max(0.0, 1 - (t - 0.7) / 0.3)
    if a < 1:
        im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
    c.alpha_composite(im, ((CELL - size) // 2, (CELL - size) // 2 - 10))
    out = bloom(c, 0.6 + 0.6 * a)
    ImageDraw.Draw(out).text((CELL // 2, CELL - 16), label, fill=(240, 236, 220), font=font(15), anchor="mm")
    return out


def sheet(t=1.0):
    W = Image.new("RGB", (4 * CELL, 3 * CELL), BG)
    for i, (n, l) in enumerate(ORDER):
        W.paste(cell(n, l, t), ((i % 4) * CELL, (i // 4) * CELL))
    return W


def main():
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    sheet(0.62).save(out / "grenzbrecher-effekte.png")
    frames = [sheet(i / 13) for i in range(1, 14)] + [Image.new("RGB", (4 * CELL, 3 * CELL), BG)] * 2
    frames = [f.resize((f.width // 2, f.height // 2), Image.LANCZOS) for f in frames]
    frames[0].save(out / "grenzbrecher-effekte.gif", save_all=True, append_images=frames[1:], duration=70, loop=0)


if __name__ == "__main__":
    main()
