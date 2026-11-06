"""Vorschau: alle Outfits nebeneinander (idle_0 groß + einige Posen)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, str(Path(__file__).resolve().parent))
RAW = Path(sys.argv[1]); OUT = Path(sys.argv[2])
NAMES = {"hanabi": "Hanabi-Kimono", "mondhakama": "Mond-Hakama", "kranich": "Kranich-Haori", "gakuran": "Gakuran",
         "matrose": "Matrosen-Uniform", "yukata": "Sommer-Yukata", "shinobi": "Shinobi-Anzug", "miko": "Schreingewand",
         "neonlaeufer": "Neonläufer", "chromsoeldner": "Chrom-Söldner", "datenhoodie": "Daten-Hoodie",
         "synthidol": "Synth-Idol", "konzern": "Konzern-Agent", "strassenklinge": "Straßenklinge",
         "eisjaeger": "Eisjäger", "runenschild": "Runenschild", "frostseherin": "Frostseherin",
         "baerenhaut": "Bärenhaut", "nordwanderer": "Nordwanderer"}
if len(sys.argv) > 4:
    NAMES = {k: v for k, v in NAMES.items() if k in sys.argv[4].split(",")}
POSES = sys.argv[3].split(",") if len(sys.argv) > 3 else ["idle_0", "walk_1", "run_1", "run_3"]
ids = [i for i in NAMES if (RAW / i / f"{POSES[0]}.png").exists()]
S = 4; W = 64 * S
img = Image.new("RGBA", (W * 4, (64 * S + 64 * 2 + 50) * ((len(ids) + 3) // 4)), (24, 20, 30, 255))
d = ImageDraw.Draw(img)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
except OSError:
    font = ImageFont.load_default()
H = 64 * S + 64 * 2 + 50
for k, oid in enumerate(ids):
    x, y = (k % 4) * W, (k // 4) * H
    d.text((x + W // 2, y + 20), NAMES[oid], fill=(240, 220, 200), font=font, anchor="mm")
    img.alpha_composite(Image.open(RAW / oid / f"{POSES[0]}.png").convert("RGBA").resize((W, W), Image.NEAREST), (x, y + 40))
    for j, p in enumerate(POSES[1:]):
        f = RAW / oid / f"{p}.png"
        if f.exists():
            img.alpha_composite(Image.open(f).convert("RGBA").resize((128, 128), Image.NEAREST), (x + j * 85 - 20, y + 40 + W - 30))
img.save(OUT)
