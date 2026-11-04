"""Erzeugt den Grundkörper in allen Posen aus frames.json (PixelLab Skeleton v3).

Aufruf: python3 generate_base.py <base.png> <base_keypoints.json> <ausgabeordner> [gruppe ...]
Kosten laut PixelLab: 2-4 Generierungen pro Gruppe.
"""
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pixellab_v2 import Image, b64, find_images, request, wait_job  # noqa: E402

DESC = ("bald mannequin base body in a plain light gray skin-tight bodysuit, peach skin head with simple anime face, "
        "gray hands and feet, slim anime fighter proportions, dark outline, pixel art, empty hands, no weapon, no visual effects")
SEED = 4711


def run(group, base, base_kp, out_dir):
    payload = {
        "description": DESC,
        "action": group["action"],
        "direction": "east",
        "view": "side",
        "first_frame": b64(base),
        "first_frame_keypoints": base_kp,
        "keypoints": [f["keypoints"] for f in group["frames"]],
        "seed": SEED,
        "no_background": True,
    }
    res = wait_job(request("POST", "/animate-with-skeleton-v3", payload))
    ims = find_images(res)
    names = [f["name"] for f in group["frames"]]
    if len(ims) != len(names):
        print(f"{group['group']}: {len(ims)} Bilder statt {len(names)}", file=sys.stderr)
    for name, im in zip(names, ims[-len(names):]):
        im.save(out_dir / f"{name}.png")
    return group["group"], (res.get("usage") or {}), len(ims)


def main():
    base = Image.open(sys.argv[1]).convert("RGBA")
    base_kp = json.load(open(sys.argv[2]))["keypoints"]
    for k in base_kp:
        k["z_index"] = int(k.get("z_index", 0))
    out_dir = Path(sys.argv[3]); out_dir.mkdir(parents=True, exist_ok=True)
    groups = json.load(open(Path(__file__).with_name("frames.json")))
    if len(sys.argv) > 4:
        groups = [g for g in groups if g["group"] in sys.argv[4:]]
    with ThreadPoolExecutor(4) as ex:
        for name, usage, n in ex.map(lambda g: run(g, base, base_kp, out_dir), groups):
            print(name, n, usage)


if __name__ == "__main__":
    main()
