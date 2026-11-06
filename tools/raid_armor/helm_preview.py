"""Alle Posen mit Helm wie im Spiel (LayeredBody): Helm am Hals-Anker gedreht,
Kopf des Körpers bei covers_head ausgeblendet.  python3 helm_preview.py <out.png> <seltenheit|hair-id> [outfit]"""
import json, math, sys
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
R = ROOT / "assets/creator/parts"
anch = json.load(open(ROOT / "assets/creator/base/anchors.json"))["frames"]
meta = json.load(open(R / "hair/hair.json"))
body = Image.open(ROOT / "assets/creator/body/sheet.png").convert("RGBA")
hid = sys.argv[2] if sys.argv[2] in meta else "raid_" + sys.argv[2]
outfit = sys.argv[3] if len(sys.argv) > 3 else hid
HC, HR = (0.0, -11.0), 10.0
cells = lambda s, i: s.crop(((i % 10) * 64, (i // 10) * 64, (i % 10) * 64 + 64, (i // 10) * 64 + 64))
layers = [Image.open(R / s / f"{outfit}.png").convert("RGBA") for s in ("pants", "shoes", "top") if (R / s / f"{outfit}.png").exists()]
helm = Image.open(R / f"hair/{hid}.png").convert("RGBA")
m = meta[hid]; cover = m.get("covers_head", False)
sheet = Image.new("RGBA", (640, 7 * 64), (40, 34, 48, 255))
for i, f in enumerate(anch):
    da = (f["head"]["angle"] - m["angle"] + 180) % 360 - 180
    if not cover:
        da = max(-40, min(40, da))
    if abs(da) < 12:
        da = 0
    rot = -math.radians(da)
    b = cells(body, i)
    if cover:
        cx = f["head"]["pos"][0] + HC[0] * math.cos(rot) - HC[1] * math.sin(rot)
        cy = f["head"]["pos"][1] + HC[0] * math.sin(rot) + HC[1] * math.cos(rot)
        p = b.load()
        for y in range(64):
            for x in range(64):
                if math.dist((x + 0.5, y + 0.5), (cx, cy)) < HR:
                    p[x, y] = (0, 0, 0, 0)
    for l in layers:
        b.alpha_composite(cells(l, i))
    big = Image.new("RGBA", (192, 192))
    nx, ny = m["neck"]
    big.alpha_composite(helm, (int(round(96 - nx)), int(round(96 - ny))))
    big = big.rotate(da, resample=Image.NEAREST, center=(96, 96))
    t = Image.new("RGBA", (256, 256)); t.alpha_composite(b, (96, 96))
    hx, hy = f["head"]["pos"]
    t.alpha_composite(big, (int(round(96 + hx - 96)), int(round(96 + hy - 96))))
    sheet.alpha_composite(t.crop((96, 96, 160, 160)), ((i % 10) * 64, (i // 10) * 64))
sheet.resize((1280, 7 * 128), Image.NEAREST).save(sys.argv[1])
