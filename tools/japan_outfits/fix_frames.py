"""Einzelne schlechte Posen eines Outfits neu erzeugen: alle Frames unter der Grenze
(Abdeckung des Grundkörpers) kommen in ein eigenes 16er-Raster (1 Generierung),
pro Frame wird die bessere Fassung behalten.
  python3 tools/japan_outfits/fix_frames.py <seed> <outfit>[:frame,frame] ...
"""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gen_outfits as g  # noqa: E402
ol = g.ol
LIMIT = 0.9


Image = g.Image


def cov(oid, n, img=None):
    """Abdeckung des Grundkörpers minus Anteil fremder Pixel weit weg vom Körper
    (verrutschte Figur oder Nachbarzelle im Raster)."""
    from PIL import ImageFilter
    a = Image.open(ol.BODY / "frames" / f"{n}.png").getchannel("A").point(lambda v: 255 if v else 0)
    near = a.filter(ImageFilter.MaxFilter(11)).tobytes()
    a = a.tobytes()
    b = (img or Image.open(ol.PARTS / "_raw" / oid / f"{n}.png")).getchannel("A").tobytes()
    idx = [i for i, v in enumerate(a) if v]
    extra = sum(1 for i, v in enumerate(b) if v and not near[i])
    score = (sum(1 for i in idx if b[i]) - extra) / len(idx)
    if DRESS:  # angezogen? Anteil der Körperpixel, deren Farbe sich ändert
        bp = Image.open(ol.BODY / "frames" / f"{n}.png").convert("RGBA").tobytes()
        op = (img or Image.open(ol.PARTS / "_raw" / oid / f"{n}.png")).convert("RGBA").tobytes()
        ch = sum(1 for i in idx if sum(abs(bp[4 * i + j] - op[4 * i + j]) for j in range(3)) > 40)
        score += 0.5 * ch / len(idx)
    return score


DRESS = "--dress" in sys.argv


def fix(seed, oid, only=None):
    names = only or [f["name"] for f in ol.frame_list()]
    bad = sorted((cov(oid, n), n) for n in names)
    bad = [n for c, n in bad if only or c < LIMIT][:16]
    if not bad:
        print(oid, "nichts zu tun"); return
    grid = Image.new("RGBA", (256, 256))
    filled = bad + [bad[i % len(bad)] for i in range(16 - len(bad))]
    for i, n in enumerate(filled):
        grid.alpha_composite(Image.open(ol.BODY / "frames" / f"{n}.png").convert("RGBA"), ((i % 4) * 64, (i // 4) * 64))
    r = g.wait_job(g.request("POST", "/edit-image-pixen", {"image": g.b64(grid), "description": g.desc(oid),
                                                           "seed": seed, "no_background": True}))
    res = g.find_images(r)[-1]
    for i, n in enumerate(bad):
        new = res.crop(((i % 4) * 64, (i // 4) * 64, (i % 4) * 64 + 64, (i // 4) * 64 + 64))
        o, c = cov(oid, n), cov(oid, n, new)
        if c > o:
            new.save(ol.PARTS / "_raw" / oid / f"{n}.png")
        print(oid, n, f"{o:.2f} -> {c:.2f}", flush=True)


if __name__ == "__main__":
    from concurrent.futures import ThreadPoolExecutor
    seed = int(sys.argv[1])
    # <outfit> oder <outfit>:frame1,frame2 (nur diese Frames)
    jobs = [(a.split(":")[0], a.split(":")[1].split(",") if ":" in a else None) for a in sys.argv[2:] if a != "--dress"]
    with ThreadPoolExecutor(4) as ex:
        list(ex.map(lambda j: fix(seed, *j), jobs or [(o, None) for o in g.OUTFITS]))
