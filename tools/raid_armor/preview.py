"""Vorschau: alle Seltenheiten nebeneinander (idle_0 groß + Lauf-Frames)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RAW = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/raid_armor")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/raid_armor/vorschau.png")
RARS = [("gewoehnlich", "Gewöhnlich", "c7cfcc"), ("ungewoehnlich", "Ungewöhnlich", "1ebc73"),
        ("selten", "Selten", "4d9be6"), ("episch", "Episch", "a884f3"),
        ("legendaer", "Legendär", "f9c22b"), ("mythisch", "Mythisch", "e83b3b")]
POSES = sys.argv[3].split(",") if len(sys.argv) > 3 else ["idle_0", "walk_1", "run_1", "jump_0"]
S = 5
W = 64 * S
img = Image.new("RGBA", (W * 6, 64 * S + 64 * 2 + 70), (24, 20, 30, 255))
d = ImageDraw.Draw(img)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
except OSError:
    font = ImageFont.load_default()
for i, (rid, name, col) in enumerate(RARS):
    x = i * W
    c = tuple(int(col[j:j + 2], 16) for j in (0, 2, 4))
    d.rectangle([x + 4, 4, x + W - 4, img.height - 4], outline=c, width=3)
    d.text((x + W // 2, 34), name, fill=c, font=font, anchor="mm")
    f = RAW / rid / f"{POSES[0]}.png"
    if f.exists():
        img.alpha_composite(Image.open(f).convert("RGBA").resize((64 * S, 64 * S), Image.NEAREST), (x, 60))
    for k, p in enumerate(POSES[1:]):
        f = RAW / rid / f"{p}.png"
        if f.exists():
            img.alpha_composite(Image.open(f).convert("RGBA").resize((128 - 20, 128 - 20), Image.NEAREST),
                                (x + 2 + k * 106, 60 + 64 * S))
img.save(OUT)
print(OUT)
