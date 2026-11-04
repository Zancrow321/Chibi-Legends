"""Rohdaten aus build/lauffeuer_fx/ in Streifen fuer Godot umwandeln.

Ergebnis: assets/vfx/lauffeuer/<name>.png (Frames nebeneinander) + fx.json
(Framegroesse, Anzahl, Dauer in ms). Kostenlos, keine Generierung.
"""
import glob, json, os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "build", "lauffeuer_fx")
DST = os.path.join(ROOT, "assets", "vfx", "lauffeuer")
USE = {  # Zielname: Rohordner
    "flammenfaust": "flammenfaust_v1", "flammenfaust_knoechel": "flammenfaust",
    "ausbruch": "ausbruch", "brandherd": "brandherd", "steigflamme": "steigflamme",
    "feuerstrom": "feuerstrom", "feuerschirm": "feuerschirm", "brandgestirn": "brandgestirn",
    "einschlag": "einschlag", "zunderflocke": "zunderflocke",
}
LOOP = {"brandherd", "feuerstrom", "brandgestirn", "zunderflocke"}

def no_blue(im):
    """Blue blobs (prompt artefact) -> hot white-yellow core."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and b > r + 20:
                v = (r + g + b) // 3
                px[x, y] = (255, min(255, 200 + v // 4), min(255, 120 + v // 3), a)
    return im


def frames(d):
    png = [p for p in glob.glob(os.path.join(SRC, d, "*.png"))][0]
    js = [p for p in glob.glob(os.path.join(SRC, d, "*.json")) if "response" not in p][0]
    sheet = Image.open(png).convert("RGBA"); meta = json.load(open(js))
    out = []
    for f in meta["frames"]:
        r = f["frame"]
        out.append((no_blue(sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))), f.get("duration", 83)))
    return out

if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True); info = {}
    for name, d in USE.items():
        fr = frames(d); w, h = fr[0][0].size
        strip = Image.new("RGBA", (w * len(fr), h))
        for i, (im, _) in enumerate(fr):
            strip.paste(im, (i * w, 0))
        strip.save(os.path.join(DST, name + ".png"))
        info[name] = {"w": w, "h": h, "frames": len(fr), "ms": [d for _, d in fr], "loop": name in LOOP}
    json.dump(info, open(os.path.join(DST, "fx.json"), "w"), indent=1)
    print(json.dumps({k: (v["w"], v["h"], v["frames"]) for k, v in info.items()}))
