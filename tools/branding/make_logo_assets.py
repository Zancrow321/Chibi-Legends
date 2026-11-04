"""Builds the branding assets from Kaiser's animated logo GIF (960x640, 80 frames, 50 ms).

    python3 tools/branding/make_logo_assets.py path/to/logo-neu.gif

Writes into assets/branding/:
  logo.png             frame 0 in full size (still logo, also the base of the title screen)
  logo_anim_sheet.png  all 80 frames at half size (480x320), 10 columns x 8 rows
  splash.png           boot splash (frame 0, full size)
  icon_32/48/64/128.png  head of the fighter (favicon, app icon)
The title screen draws logo.png sharp and adds (frame - frame 0) from the half-size
sheet on top, so only the moving shine and glow come from the smaller frames.
"""
import sys
from pathlib import Path
from PIL import Image, ImageSequence

OUT = Path(__file__).resolve().parents[2] / "assets" / "branding"
COLS, ROWS = 10, 8
FW, FH = 480, 320


def main(src: str) -> None:
    gif = Image.open(src)
    frames = [f.convert("RGB") for f in ImageSequence.Iterator(gif)]
    assert len(frames) == COLS * ROWS, len(frames)
    base = frames[0]
    base.save(OUT / "logo.png", optimize=True)
    base.save(OUT / "splash.png", optimize=True)
    sheet = Image.new("RGB", (FW * COLS, FH * ROWS))
    for i, f in enumerate(frames):
        sheet.paste(f.resize((FW, FH), Image.LANCZOS), ((i % COLS) * FW, (i // COLS) * FH))
    sheet.save(OUT / "logo_anim_sheet.png", optimize=True)
    # icon: the fighter's head (square crop around face and hair)
    head = base.crop((392, 40, 584, 232))
    for s in (32, 48, 64, 128):
        head.resize((s, s), Image.LANCZOS).save(OUT / f"icon_{s}.png", optimize=True)


if __name__ == "__main__":
    main(sys.argv[1])
