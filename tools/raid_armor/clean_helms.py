"""Entfernt Streupixel (kleine Inseln) aus den Helm-Ebenen raid_*.png."""
from pathlib import Path
from PIL import Image
HAIR = Path(__file__).resolve().parents[2] / "assets/creator/parts/hair"
for p in sorted(HAIR.glob("raid_*.png")):
    im = Image.open(p).convert("RGBA"); px = im.load(); W, H = im.size
    seen = set()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and (x, y) not in seen:
                comp, stack = [], [(x, y)]
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop(); comp.append((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            q = (cx + dx, cy + dy)
                            if 0 <= q[0] < W and 0 <= q[1] < H and q not in seen and px[q][3]:
                                seen.add(q); stack.append(q)
                if len(comp) < 8:
                    for q in comp:
                        px[q] = (0, 0, 0, 0)
    im.save(p)
    print(p.name)
