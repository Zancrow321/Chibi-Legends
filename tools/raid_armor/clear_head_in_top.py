"""Raid-Oberteile: Pixel im Kopfkreis jeder Pose entfernen (PixelLab malt manchmal
Kronen oder Kragen auf den Kopf; der Helm sitzt dort). Gleiche Geometrie wie LayeredBody."""
import json, math
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
anch = json.load(open(ROOT / "assets/creator/base/anchors.json"))["frames"]
hair = json.load(open(ROOT / "assets/creator/parts/hair/hair.json"))
HC, R = (0.0, -11.0), 10.0
for top in sorted((ROOT / "assets/creator/parts/top").glob("raid_*.png")):
    ref = hair[top.stem]["angle"]
    im = Image.open(top).convert("RGBA"); px = im.load(); n = 0
    for i, f in enumerate(anch):
        da = (f["head"]["angle"] - ref + 180) % 360 - 180
        if abs(da) < 12:
            da = 0
        rot = -math.radians(da)
        cx = f["head"]["pos"][0] + HC[0] * math.cos(rot) - HC[1] * math.sin(rot)
        cy = f["head"]["pos"][1] + HC[0] * math.sin(rot) + HC[1] * math.cos(rot)
        ox, oy = (i % 10) * 64, (i // 10) * 64
        for y in range(64):
            for x in range(64):
                if px[ox + x, oy + y][3] and math.dist((x + 0.5, y + 0.5), (cx, cy)) < R - 0.5:
                    px[ox + x, oy + y] = (0, 0, 0, 0); n += 1
    im.save(top); print(top.name, n)
