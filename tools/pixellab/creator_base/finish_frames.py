"""Räumt die erzeugten Frames auf und misst die echten Ankerpunkte.

1. Streupixel entfernen: nur zusammenhängende Flächen ab 60 Pixeln bleiben
   (entfernt kleine Effekt-Reste, die das Modell manchmal dazumalt).
2. PixelLab estimate-skeleton auf jedem fertigen Frame (0,1 Generierung pro Frame),
   daraus Kopf-, Hand- und Rückenanker in Pixeln samt Winkel.

Aufruf: python3 finish_frames.py <rohordner> <zielordner> <anchors.json>
"""
import json
import math
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pixellab_v2 import Image, b64, request, wait_job  # noqa: E402

MIN_AREA = 60


def clean(im: Image.Image) -> Image.Image:
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0 and not seen[y][x]:
                stack, comp = [(x, y)], []
                seen[y][x] = True
                while stack:
                    cx, cy = stack.pop(); comp.append((cx, cy))
                    for nx in range(cx - 1, cx + 2):
                        for ny in range(cy - 1, cy + 2):
                            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                                seen[ny][nx] = True; stack.append((nx, ny))
                comps.append(comp)
    out = im.copy(); op = out.load()
    for comp in comps:
        if len(comp) < MIN_AREA:
            for x, y in comp:
                op[x, y] = (0, 0, 0, 0)
    return out


def angle(a, b):
    """Winkel wie in poses.py: 0 = nach unten, positiv = nach vorne."""
    return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))


def measure(im):
    kp = wait_job(request("POST", "/estimate-skeleton", {"image": b64(im)}))["keypoints"]
    P = {k["label"]: (k["x"] * im.width, k["y"] * im.height) for k in kp}
    sh = ((P["LEFT SHOULDER"][0] + P["RIGHT SHOULDER"][0]) / 2, (P["LEFT SHOULDER"][1] + P["RIGHT SHOULDER"][1]) / 2)
    hip = ((P["LEFT HIP"][0] + P["RIGHT HIP"][0]) / 2, (P["LEFT HIP"][1] + P["RIGHT HIP"][1]) / 2)
    r = lambda p: [round(p[0], 1), round(p[1], 1)]
    return {
        "head": {"pos": r(P["NECK"]), "angle": round(angle(P["NECK"], P["NOSE"]) - 139.6, 1)},
        "hand_front": {"pos": r(P["LEFT ARM"]), "angle": round(angle(P["LEFT ELBOW"], P["LEFT ARM"]), 1)},
        "hand_back": {"pos": r(P["RIGHT ARM"]), "angle": round(angle(P["RIGHT ELBOW"], P["RIGHT ARM"]), 1)},
        "back": {"pos": r(sh), "angle": round(180 - angle(hip, sh) if angle(hip, sh) > 0 else -180 - angle(hip, sh), 1)},
        "feet": {"front": r(P["LEFT LEG"]), "back": r(P["RIGHT LEG"])},
    }, kp


def main():
    src, dst, out_json = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    dst.mkdir(parents=True, exist_ok=True)
    groups = json.load(open(Path(__file__).with_name("frames.json")))
    names = [f["name"] for g in groups for f in g["frames"]]

    def one(name):
        im = clean(Image.open(src / f"{name}.png").convert("RGBA"))
        im.save(dst / f"{name}.png")
        a, kp = measure(im)
        return name, a

    with ThreadPoolExecutor(6) as ex:
        res = dict(ex.map(one, names))
    data = {"cell": [64, 64], "origin": [32, 58], "frames": [{"name": n, **res[n]} for n in names]}
    out_json.write_text(json.dumps(data, indent=1))
    print(len(names), "Frames gemessen")


if __name__ == "__main__":
    main()
