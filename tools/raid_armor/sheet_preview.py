"""Alle 68 Posen einer Seltenheit: Körper + Hose + Schuhe + Oberteil (ohne Helm)."""
import sys
from PIL import Image
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
P = ROOT / "assets/creator/parts"
for r in sys.argv[2:]:
    im = Image.open(ROOT / "assets/creator/body/sheet.png").convert("RGBA")
    for s in ("pants", "shoes", "top"):
        im.alpha_composite(Image.open(P / s / f"raid_{r}.png").convert("RGBA"))
    bg = Image.new("RGBA", im.size, (40, 34, 48, 255)); bg.alpha_composite(im)
    bg.resize((im.width * 2, im.height * 2), Image.NEAREST).save(Path(sys.argv[1]) / f"posen_{r}.png")
