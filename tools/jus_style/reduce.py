"""Reduziert die Farben einer Figur auf N (Alpha hart), behält fast-schwarzen Umriss. Aufruf: reduce.py in.png out.png N"""
import sys
from PIL import Image
src, dst, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGBA")
a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
rgb = Image.new("RGB", im.size, (0, 0, 0)); rgb.paste(im.convert("RGB"), mask=a)
q = rgb.quantize(colors=n + 1, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
out = q.convert("RGBA"); out.putalpha(a); out.save(dst)
print(len({p for p in out.getdata() if p[3]}), "Farben")
