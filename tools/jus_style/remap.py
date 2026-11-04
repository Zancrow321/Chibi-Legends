"""Rundet alle Pixel eines Bilds auf die Farben einer Vorlage (z. B. des Standbilds). Aufruf: remap.py bild.png vorlage.png"""
import sys
from PIL import Image
img, ref = sys.argv[1:3]
pal = sorted({p[:3] for p in Image.open(ref).convert("RGBA").get_flattened_data() if p[3]})
im = Image.open(img).convert("RGBA"); px = im.load(); cache = {}
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = px[x, y]
        if not a:
            continue
        k = (r, g, b)
        if k not in cache:
            cache[k] = min(pal, key=lambda c: (c[0]-r)**2 + (c[1]-g)**2 + (c[2]-b)**2)
        px[x, y] = cache[k] + (255,)
im.save(img); print(img, len(pal), "Farben")
