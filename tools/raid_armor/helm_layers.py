"""Helm-Ebenen neu aus dem PixelLab-Bild (_<id>_komplett.png) schneiden, ohne Generierung.

Helme mit covers_head (hair.json) blenden im Spiel den Kopf des Körpers aus. Die Ebene
braucht deshalb den ganzen Kopf inklusive Gesicht: alle Pixel im Kopfkreis plus alles,
was PixelLab gegenüber dem Körper verändert hat (Helmrand, Federbusch, Hörner).
  python3 tools/raid_armor/helm_layers.py raid_episch bollwerk_helm ...
"""
import json, math, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HAIR = ROOT / "assets/creator/parts/hair"
BODY = ROOT / "assets/creator/body/frames/idle_0.png"
HEAD_CENTER = (0.0, -11.0)  # wie LayeredBody.HEAD_CENTER
HEAD_R = 10.0                # wie head_r im Shader
meta = json.loads((HAIR / "hair.json").read_text())
body = Image.open(BODY).convert("RGBA")
for hid in sys.argv[1:]:
    full = Image.open(HAIR / f"_{hid}_komplett.png").convert("RGBA")
    nx, ny = meta[hid]["neck"]
    cx, cy = nx + HEAD_CENTER[0], ny + HEAD_CENTER[1]
    bp, fp = body.load(), full.load()
    out = Image.new("RGBA", (64, 64)); op = out.load()
    chg = [[fp[x, y][3] > 0 and (bp[x, y][3] == 0 or sum(abs(fp[x, y][j] - bp[x, y][j]) for j in range(3)) > 40)
            for y in range(64)] for x in range(64)]
    for y in range(64):
        for x in range(64):
            c = fp[x, y]
            if c[3] == 0:
                continue
            inside = math.dist((x + 0.5, y + 0.5), (cx, cy)) < HEAD_R + 1.5
            # unveränderte Kopfpixel (Gesicht) nur, wenn der Helm sie umschließt:
            # Helm darüber und links und rechts davon; so bleibt die Glatze draußen
            enclosed = (any(chg[x][k] for k in range(y)) and any(chg[k][y] for k in range(x))
                        and any(chg[k][y] for k in range(x + 1, 64)))
            if chg[x][y]:
                if y < ny + 1 or math.dist((x, y), (nx, ny)) < 14:
                    op[x, y] = c
            elif inside and enclosed:
                op[x, y] = c
    out.save(HAIR / f"{hid}.png")
    print(hid)
