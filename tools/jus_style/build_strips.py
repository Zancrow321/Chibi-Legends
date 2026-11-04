"""Baut Animationsstreifen (96er Zellen) aus Einzelframes. Aufruf: build_strips.py out.png frame0.png frame1.png ..."""
import sys
from PIL import Image
out, *files = sys.argv[1:]
fr = [Image.open(f).convert("RGBA") for f in files]
strip = Image.new("RGBA", (96 * len(fr), 96), (0, 0, 0, 0))
for i, f in enumerate(fr):
    strip.alpha_composite(f, (96 * i, 0))
strip.save(out)
