#!/usr/bin/env python3
"""Erzeugt einzelne 16er-Raster eines Outfits neu, wenn PixelLab die Posen verändert hat.
Prüft je Raster, wie viel vom Grundkörper die Kleidung abdeckt (Pose gehalten = fast 100 %).
Aufruf: python3 tools/bollwerk/fix_outfit_grids.py <outfit-id> <seed> <beschreibung> [raster ...]
Danach: python3 tools/pixellab/creator_base/outfit_layers.py split <outfit-id>
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pixellab" / "creator_base"))
import outfit_layers as ol  # noqa: E402
from outfit_layers import Image, b64, find_images, request, wait_job  # noqa: E402

LIMIT = 0.93


def coverage(oid, names):
    worst = 1.0
    for n in names:
        a = Image.open(ol.BODY / "frames" / f"{n}.png").getchannel("A").tobytes()
        b = Image.open(ol.PARTS / "_raw" / oid / f"{n}.png").getchannel("A").tobytes()
        idx = [i for i, v in enumerate(a) if v]
        worst = min(worst, sum(1 for i in idx if b[i]) / len(idx))
    return worst


def main():
    oid, seed, desc = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    names = [f["name"] for f in ol.frame_list()]
    chunks = [names[i:i + 16] for i in range(0, len(names), 16)]
    want = [int(x) for x in sys.argv[4:] if x != "--force"] or [i for i, c in enumerate(chunks) if coverage(oid, c) < LIMIT]
    full = "Dress all figures in the exact same outfit: " + desc + ". " + ol.KEEP
    for ci in want:
        chunk = chunks[ci]
        grid = Image.new("RGBA", (256, 256))
        filled = chunk + [chunk[i % len(chunk)] for i in range(16 - len(chunk))]
        for i, n in enumerate(filled):
            grid.alpha_composite(Image.open(ol.BODY / "frames" / f"{n}.png").convert("RGBA"), ((i % 4) * 64, (i // 4) * 64))
        r = wait_job(request("POST", "/edit-image-pixen", {"image": b64(grid), "description": full, "seed": seed,
                                                           "no_background": True}))
        res = find_images(r)[-1]
        tmp = Path("/tmp/creator_fix") / oid / str(ci)
        tmp.mkdir(parents=True, exist_ok=True)
        for i, n in enumerate(chunk):
            res.crop(((i % 4) * 64, (i // 4) * 64, (i % 4) * 64 + 64, (i // 4) * 64 + 64)).save(tmp / f"{n}.png")
        old = coverage(oid, chunk)
        # neue Fassung probeweise einsetzen, nur behalten wenn besser
        backup = {n: (ol.PARTS / "_raw" / oid / f"{n}.png").read_bytes() for n in chunk}
        for n in chunk:
            (ol.PARTS / "_raw" / oid / f"{n}.png").write_bytes((tmp / f"{n}.png").read_bytes())
        new = coverage(oid, chunk)
        if new < old and "--force" not in sys.argv:
            for n, data in backup.items():
                (ol.PARTS / "_raw" / oid / f"{n}.png").write_bytes(data)
        print(f"Raster {ci}: {old:.2f} -> {new:.2f}", "behalten" if new >= old else "verworfen",
              (r.get("usage") or {}).get("generations"), flush=True)


if __name__ == "__main__":
    main()
