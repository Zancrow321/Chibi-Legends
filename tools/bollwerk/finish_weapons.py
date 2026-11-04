#!/usr/bin/env python3
"""Wählt die Bollwerk-Rohbilder aus, schneidet sie zu, misst Griff und Mündung
und schreibt assets/creator/weapons/bollwerk/<name>.png + weapons.json.
Dazu eine Vorschau: Grundkörper hält jede Waffe (idle_0, jab_hit).
Aufruf: python3 tools/bollwerk/finish_weapons.py <vorschau.png>
"""
import json, pathlib, sys
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "creator" / "weapons" / "raw" / "bollwerk"
OUT = ROOT / "assets" / "creator" / "weapons" / "bollwerk"
PICK = {"wachhund": 3, "dreischlag": 11, "kurzwort": 11, "fremdklinge": 11,
        "zwillingsrohr": 27, "lanzenstrahl": 21, "schrotflinte": 11}
LABEL = {"wachhund": "Sturmgewehr „Wachhund“", "dreischlag": "Salvengewehr „Dreischlag“",
         "kurzwort": "Dienstpistole „Kurzwort“", "fremdklinge": "Fremdklinge",
         "zwillingsrohr": "Zwillingsrohr", "lanzenstrahl": "Lanzenstrahl", "schrotflinte": "Schrotflinte"}


def measure(im, name):
    a = im.getchannel("A"); w, h = im.size; px = a.load()
    cols = [[y for y in range(h) if px[x, y] > 0] for x in range(w)]
    xs = [x for x in range(w) if cols[x]]
    x1 = xs[-1]
    tip = (x1 + 0.5, sum(cols[x1]) / len(cols[x1]) + 0.5)
    if name == "fremdklinge":  # Heft: dunkler linker Teil, Mitte davon
        gx = xs[0] + (x1 - xs[0]) * 0.15
        c = cols[int(gx)]
        return (round(gx, 1), round(sum(c) / len(c) + 0.5, 1)), tip
    # Pistolengriff: tiefste Spalte in der linken 65 %, Griffpunkt knapp unter dem Gehäuse
    left = [x for x in xs if x < xs[0] + (x1 - xs[0]) * 0.65]
    body_bottom = sorted(max(cols[x]) for x in xs)[len(xs) // 2]  # typische Unterkante
    gx = max(left, key=lambda x: (max(cols[x]), -abs(x - (xs[0] + x1) / 2)))
    run = [x for x in left if max(cols[x]) > body_bottom]
    if run:
        gx = sum(run[:max(1, len(run) // 2)]) / max(1, len(run[:max(1, len(run) // 2)]))
    return (round(gx + 0.5, 1), round(body_bottom + 1.5, 1)), tip


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    for n, s in PICK.items():
        im = Image.open(RAW / f"{n}_s{s}.png").convert("RGBA")
        bb = im.getbbox()
        im = im.crop((bb[0] - 1, bb[1] - 1, bb[2] + 1, bb[3] + 1))
        im.save(OUT / f"{n}.png")
        g, t = measure(im, n)
        meta[n] = {"label": LABEL[n], "texture": f"res://assets/creator/weapons/bollwerk/{n}.png",
                   "scale": 1, "grip": list(g), "tip": list(t), "kind": "blade" if n == "fremdklinge" else "gun",
                   "source": f"PixelLab create-image-pixen, seed {s}"}
    (OUT / "weapons.json").write_text(json.dumps(meta, indent=1, ensure_ascii=False))
    # Vorschau
    fr = {f["name"]: f for f in json.load(open(ROOT / "assets/creator/base/anchors.json"))["frames"]}
    S, CW, CH = 4, 130, 80
    sheet = Image.new("RGBA", (CW * 2 * S, CH * len(PICK) * S), (40, 44, 56, 255))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(PICK):
        w = Image.open(OUT / f"{n}.png"); g = meta[n]["grip"]
        for j, pose in enumerate(["idle_0", "jab_hit"]):
            cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
            body = Image.open(ROOT / f"assets/creator/base/frames/{pose}.png")
            ox, oy = 20, 8
            cell.alpha_composite(body, (ox, oy))
            hx, hy = fr[pose]["hand_front"]["pos"]
            cell.alpha_composite(w, (round(ox + hx - g[0]), round(oy + hy - g[1])))
            sheet.alpha_composite(cell.resize((CW * S, CH * S), Image.NEAREST), (j * CW * S, i * CH * S))
        d.text((8, i * CH * S + 6), LABEL[n].replace("„", "\"").replace("“", "\""), fill=(255, 220, 140, 255))
    sheet.save(sys.argv[1])
    print(json.dumps({k: (v["grip"], v["tip"]) for k, v in meta.items()}))


if __name__ == "__main__":
    main()
