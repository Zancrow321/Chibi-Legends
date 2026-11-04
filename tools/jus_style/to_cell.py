"""Setzt 64er-Frames in 96er Zellen (Fußpunkt x 44, y 88) und baut einen Streifen. Aufruf: to_cell.py out.png f0.png f1.png ..."""
import sys
from PIL import Image
out, *files = sys.argv[1:]
fr = [Image.open(f).convert("RGBA") for f in files]
foot = max(f.getbbox()[3] for f in fr)  # unterste Zeile ueber alle Frames
strip = Image.new("RGBA", (96 * len(fr), 96), (0, 0, 0, 0))
for i, f in enumerate(fr):
    a = f.getchannel("A").point(lambda v: 255 if v >= 128 else 0); f.putalpha(a)
    strip.alpha_composite(f, (96 * i + 44 - f.width // 2, 88 - foot))
strip.save(out)
