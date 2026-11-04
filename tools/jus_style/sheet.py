"""Kontaktbogen: Bilder nebeneinander, nearest-neighbour vergroessert, mit Nummern."""
import sys
from PIL import Image, ImageDraw
out, scale, *files = sys.argv[1:]
scale = int(scale)
imgs = [Image.open(f).convert("RGBA") for f in files]
w = max(i.width for i in imgs) * scale; h = max(i.height for i in imgs) * scale
sheet = Image.new("RGBA", ((w + 8) * len(imgs) + 8, h + 30), (40, 44, 52, 255))
d = ImageDraw.Draw(sheet)
for n, im in enumerate(imgs):
    x = 8 + n * (w + 8)
    sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, 22))
    d.text((x + 2, 4), str(n + 1), fill=(255, 255, 255, 255))
sheet.save(out)
