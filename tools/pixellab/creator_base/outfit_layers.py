"""Kleidung für alle Posen erzeugen und in Slot-Ebenen zerlegen.

Günstiger Weg (getestet 2026-11-04): 16 Frames als 4x4-Raster (256x256) in einem
Aufruf von PixelLab edit-image-pixen bearbeiten. Kostet 1 Generierung pro Raster,
also 5 Generierungen für alle 68 Posen. Posen und Positionen bleiben erhalten.

  python3 outfit_layers.py body  <beschreibung>                 # Haut-Grundkörper
  python3 outfit_layers.py outfit <id> <beschreibung>            # Outfit + Ebenen

Ebenen: Pixel, die sich gegenüber dem Haut-Grundkörper ändern, werden nach
Körperregion auf die Slots verteilt (Skelett aus frames.json):
  shoes = unterhalb der Knie in der Nähe der Knöchel, pants = unterhalb der Hüfte,
  top = alles darüber (inklusive Arme). Ergebnis: ein Sheet pro Slot, 10 Spalten,
  gleiche Reihenfolge wie das Grundkörper-Sheet.
"""
import json
import math
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from pixellab_v2 import Image, b64, find_images, request, wait_job  # noqa: E402

ROOT = HERE.parents[2]
BASE = ROOT / "assets/creator/base"
BODY = ROOT / "assets/creator/body"
PARTS = ROOT / "assets/creator/parts"
COLS = 10
SEED = 7
KEEP = ("Keep every pose, the bald heads, faces, positions and sizes exactly the same. "
        "Do not add weapons, hair or effects.")


def frame_list():
    return [f for g in json.load(open(HERE / "frames.json")) for f in g["frames"]]


def run_grids(src_dir: Path, desc: str, out_dir: Path):
    frames = frame_list()
    names = [f["name"] for f in frames]
    chunks = [names[i:i + 16] for i in range(0, len(names), 16)]
    out_dir.mkdir(parents=True, exist_ok=True)

    def one(chunk):
        grid = Image.new("RGBA", (256, 256))
        filled = chunk + [chunk[i % len(chunk)] for i in range(16 - len(chunk))]
        for i, n in enumerate(filled):
            grid.alpha_composite(Image.open(src_dir / f"{n}.png").convert("RGBA"), ((i % 4) * 64, (i // 4) * 64))
        r = wait_job(request("POST", "/edit-image-pixen", {"image": b64(grid), "description": desc, "seed": SEED,
                                                           "no_background": True}))
        res = find_images(r)[-1]
        for i, n in enumerate(chunk):
            res.crop(((i % 4) * 64, (i // 4) * 64, (i % 4) * 64 + 64, (i // 4) * 64 + 64)).save(out_dir / f"{n}.png")
        return (r.get("usage") or {}).get("generations")

    with ThreadPoolExecutor(3) as ex:
        used = list(ex.map(one, chunks))
    print("Generierungen:", sum(u or 0 for u in used))


def sheet(frames_dir: Path, path: Path):
    names = [f["name"] for f in frame_list()]
    rows = (len(names) + COLS - 1) // COLS
    s = Image.new("RGBA", (COLS * 64, rows * 64))
    for i, n in enumerate(names):
        s.alpha_composite(Image.open(frames_dir / f"{n}.png").convert("RGBA"), ((i % COLS) * 64, (i // COLS) * 64))
    path.parent.mkdir(parents=True, exist_ok=True)
    s.save(path)


def skin_palette():
    """Hautfarben des Grundkörpers (Kopf-Bereich aller Frames)."""
    cols = {}
    for f in frame_list():
        P = {k["label"]: (k["x"] * 64, k["y"] * 64) for k in f["keypoints"]}
        hc = head_center(P)
        im = Image.open(BODY / "frames" / f"{f['name']}.png").convert("RGBA").load()
        for y in range(64):
            for x in range(64):
                c = im[x, y]
                if c[3] and math.dist((x, y), hc) < 5 and c[0] > 120 and c[0] - c[2] > 40:
                    cols[c[:3]] = cols.get(c[:3], 0) + 1
    return [c for c, n in cols.items() if n > 20]


def head_center(P):
    pts = [P["NOSE"], P["LEFT EAR"], P["RIGHT EAR"], P["LEFT EYE"], P["RIGHT EYE"]]
    return (sum(p[0] for p in pts) / 5, sum(p[1] for p in pts) / 5 + 0.5)


def split_layers(outfit_dir: Path, outfit_id: str):
    """Kleidung = alle Pixel, die keine Haut sind und nicht zum Kopf gehören.

    Haut im angezogenen Bild (nackte Arme) zeigt der Körper darunter, deshalb
    gehört sie nicht in die Ebene. Dunkle Umrisspixel zählen nur, wenn sie an
    Kleidung grenzen.
    """
    skin = skin_palette()

    def is_skin(c):
        return min(sum(abs(c[j] - k[j]) for j in range(3)) for k in skin) < 28

    frames = frame_list()
    rows = (len(frames) + COLS - 1) // COLS
    slots = {k: Image.new("RGBA", (COLS * 64, rows * 64)) for k in ("top", "pants", "shoes")}
    out = {k: v.load() for k, v in slots.items()}
    for i, f in enumerate(frames):
        P = {k["label"]: (k["x"] * 64, k["y"] * 64) for k in f["keypoints"]}
        dp = Image.open(outfit_dir / f"{f['name']}.png").convert("RGBA").load()
        hip = ((P["LEFT HIP"][0] + P["RIGHT HIP"][0]) / 2, (P["LEFT HIP"][1] + P["RIGHT HIP"][1]) / 2)
        neck = P["NECK"]
        hc = head_center(P)
        ax, ay = hip[0] - neck[0], hip[1] - neck[1]
        L = math.hypot(ax, ay) or 1.0
        ax, ay = ax / L, ay / L
        knees = [P["LEFT KNEE"], P["RIGHT KNEE"]]
        ankles = [P["LEFT LEG"], P["RIGHT LEG"]]
        ox, oy = (i % COLS) * 64, (i // COLS) * 64
        cloth = [[False] * 64 for _ in range(64)]
        dark = [[False] * 64 for _ in range(64)]
        for y in range(64):
            for x in range(64):
                c = dp[x, y]
                if c[3] == 0 or is_skin(c):
                    continue
                # Kopf bleibt beim Körper (Gesicht, Glatze, Umriss des Kopfes)
                along_neck = (x - neck[0]) * ax + (y - neck[1]) * ay
                if math.dist((x, y), hc) < 7.5 and along_neck < -0.5:
                    continue
                if max(c[:3]) < 36:
                    dark[y][x] = True
                else:
                    cloth[y][x] = True
        for y in range(64):
            for x in range(64):
                if not cloth[y][x]:
                    if not dark[y][x]:
                        continue
                    if not any(0 <= x + dx < 64 and 0 <= y + dy < 64 and cloth[y + dy][x + dx]
                               for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                        continue
                near_shoe = any(math.dist((x, y), a) < 5.5 and math.dist((x, y), a) < math.dist((x, y), k)
                                for a, k in zip(ankles, knees))
                along = (x - hip[0]) * ax + (y - hip[1]) * ay
                slot = "shoes" if near_shoe else ("pants" if along > -1.0 else "top")
                out[slot][ox + x, oy + y] = dp[x, y]
    for k, v in slots.items():
        p = PARTS / k / f"{outfit_id}.png"
        p.parent.mkdir(parents=True, exist_ok=True)
        v.save(p)
    print("Ebenen gespeichert:", outfit_id)


def main():
    mode = sys.argv[1]
    if mode == "body":
        run_grids(BASE / "frames", sys.argv[2] + " " + KEEP, BODY / "frames")
        sheet(BODY / "frames", BODY / "sheet.png")
    elif mode == "outfit":
        oid, desc = sys.argv[2], sys.argv[3]
        raw = Path("/tmp") / "creator_outfits" / oid
        run_grids(BODY / "frames", "Dress all figures in the exact same outfit: " + desc + ". " + KEEP, raw)
        sheet(raw, PARTS / "_preview" / f"{oid}_komplett.png")
        for n in raw.iterdir():
            (PARTS / "_raw" / oid).mkdir(parents=True, exist_ok=True)
            (PARTS / "_raw" / oid / n.name).write_bytes(n.read_bytes())
        split_layers(raw, oid)
    elif mode == "split":  # nur neu zerlegen, ohne Generierung
        split_layers(PARTS / "_raw" / sys.argv[2], sys.argv[2])


if __name__ == "__main__":
    main()
