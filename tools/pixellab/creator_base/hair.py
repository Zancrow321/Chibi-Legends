"""Frisuren auf dem Kopf des Haut-Grundkörpers erzeugen (1 Generierung pro Frisur).

Die Frisur wird nur einmal gezeichnet (auf idle_0) und im Spiel am Kopfanker
mitbewegt und gedreht. Gespeichert wird ein 64x64-Bild plus der Hals-Anker von
idle_0, damit das Spiel den Versatz kennt.

  python3 hair.py <id> <beschreibung>
"""
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from pixellab_v2 import Image, b64, find_images, request, wait_job  # noqa: E402

ROOT = HERE.parents[2]
BODY = ROOT / "assets/creator/body/frames/idle_0.png"
OUT = ROOT / "assets/creator/parts/hair"


def main():
    hid, desc = sys.argv[1], sys.argv[2]
    body = Image.open(BODY).convert("RGBA")
    r = wait_job(request("POST", "/edit-image-pixen", {
        "image": b64(body), "seed": 11, "no_background": True,
        "description": f"Give the bald character {desc}. Change only the hair on the head; keep the face, body, pose and size exactly the same."}))
    res = find_images(r)[-1].convert("RGBA")
    res.save(OUT / f"_{hid}_komplett.png")
    # Haar = Pixel, die sich gegenüber dem Körper ändern und oberhalb der Schultern liegen
    anchors = {f["name"]: f for f in json.load(open(ROOT / "assets/creator/base/anchors.json"))["frames"]}
    neck = anchors["idle_0"]["head"]["pos"]
    bp, rp = body.load(), res.load()
    hair = Image.new("RGBA", (64, 64)); hp = hair.load()
    for y in range(64):
        for x in range(64):
            c, b = rp[x, y], bp[x, y]
            if c[3] == 0:
                continue
            changed = b[3] == 0 or sum(abs(c[j] - b[j]) for j in range(3)) > 40
            if changed and (y < neck[1] + 1 or math.dist((x, y), neck) < 14):
                hp[x, y] = c
    hair.save(OUT / f"{hid}.png")
    meta_p = OUT / "hair.json"
    meta = json.loads(meta_p.read_text()) if meta_p.exists() else {}
    meta[hid] = {"neck": neck, "angle": anchors["idle_0"]["head"]["angle"]}
    meta_p.write_text(json.dumps(meta, indent=1))
    print(hid, r.get("usage"))


if __name__ == "__main__":
    main()
