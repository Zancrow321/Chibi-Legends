#!/usr/bin/env python3
"""Rohbilder der GOD-Stufe (assets/god/raw, gen_art.py) ins Spiel bringen,
ohne neue Generierung:
  - Icons -> assets/god/icons/<id>.png
  - Flügel, Heiligenschein, Feder, Glutfetzen -> assets/god/fx/
  - Altar -> assets/overworld/god_altar.png (+ sizes.json)
  - Waffen (gewählter Seed) -> assets/creator/weapons/god/<id>.png, Griff/Spitze gemessen
  - Outfits -> Creator-Ebenen top/pants/shoes (Pipeline der Themen-Kollektionen)
  - catalog.json: Teile, Waffen und Freischalt-Hinweise
    python3 -I tools/god_items/install.py [icons fx weapons outfits catalog]
"""
import json, pathlib, sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets/god/raw"
CAT = ROOT / "assets/creator/catalog.json"
sys.path.insert(0, str(ROOT / "tools/jus_style"))
sys.path.insert(0, str(ROOT / "tools/japan_outfits"))
sys.path.insert(0, str(ROOT / "tools/pixellab/creator_base"))
sys.path.insert(0, str(ROOT / "tools/pixellab"))
sys.path.insert(0, str(ROOT / "tools/god_items"))

WEAPONS = {  # id: (seed, Maßstab, Halteart, Name, zweihändig)
    "god_hoellenschlund": (29, 1.7, "", "GOD · Höllenschlund", False),
    "god_mondfresser": (29, 1.6, "", "GOD · Mondfresser", True),
    "god_glockenschwinge": (29, 1.6, "", "GOD · Glockenschwinge", True),
    "god_engelsruf": (29, 1, "gun", "GOD · Engelsruf", False),
}
PARTS = {  # Creator-Teil: (Slots, Name, GOD-Teile)
    "god_seraph": (["top", "pants", "shoes"], "GOD · Seraph", "Gewand des Ersten Lichts / Beinkleid der Gnade / Schritte des Morgens"),
    "god_abgrund": (["top", "pants", "shoes"], "GOD · Abgrund", "Panzer des Höllenfürsten / Kettenbeinkleid / Aschewandler"),
    "god_sonnenkrone": (["hair"], "GOD · Sonnenkrone", "Sonnenkrone des Seraphen"),
    "god_hoernerkrone": (["hair"], "GOD · Hörnerkrone", "Hörnerkrone des Abgrunds"),
}
SLOT_PIECE = {"top": 0, "pants": 1, "shoes": 2}
HINT = "GOD-Teil: weltweit nur einmal (%s)"


def crop(im):
    bb = im.getbbox()
    return im.crop((max(0, bb[0] - 1), max(0, bb[1] - 1), min(im.width, bb[2] + 1), min(im.height, bb[3] + 1)))


def icons():
    out = ROOT / "assets/god/icons"
    out.mkdir(parents=True, exist_ok=True)
    for p in RAW.glob("icon_god_*.png"):
        Image.open(p).convert("RGBA").save(out / (p.stem[5:] + ".png"))


def fx():
    out = ROOT / "assets/god/fx"
    out.mkdir(parents=True, exist_ok=True)
    for n in ["fluegel_heilig", "fluegel_daemon"]:
        im = Image.open(RAW / f"fx_{n}.png").convert("RGBA")
        bb = im.getbbox()
        # symmetrisch um die Bildmitte schneiden, damit die Hälften am Rücken treffen
        half = max(im.width // 2 - bb[0], bb[2] - im.width // 2) + 1
        im.crop((im.width // 2 - half, max(0, bb[1] - 1), im.width // 2 + half, min(im.height, bb[3] + 1))).save(out / f"{n}.png")
    for n in ["heiligenschein", "feder", "glutfetzen"]:
        p = RAW / f"fx_{n}.png"
        if p.exists():
            crop(Image.open(p).convert("RGBA")).save(out / f"{n}.png")
    p = RAW / "fx_altar.png"
    if p.exists():
        im = crop(Image.open(p).convert("RGBA"))
        im.save(ROOT / "assets/overworld/god_altar.png")
        sz = ROOT / "assets/overworld/sizes.json"
        d = json.loads(sz.read_text())
        d["god_altar"] = list(im.size)
        sz.write_text(json.dumps(d, indent=1))


def measure(im, gun):
    a = im.getchannel("A").load()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if a[x, y] > 0]
    if gun:
        xs = [p[0] for p in pts]
        x1 = max(xs)
        col = [p[1] for p in pts if p[0] == x1]
        tip = (x1 + 0.5, sum(col) / len(col) + 0.5)
        gx = min(xs) + (x1 - min(xs)) * 0.3
        col = [p[1] for p in pts if abs(p[0] - gx) < 1]
        return (round(gx, 1), round(max(col) - 2.5, 1)), tip
    # diagonale Klinge: Griff unten links, Spitze oben rechts (entlang x - y)
    tip = max(pts, key=lambda p: p[0] - p[1])
    end = min(pts, key=lambda p: p[0] - p[1])
    # Griffpunkt: ein Stück vom Knauf Richtung Spitze
    g = (end[0] + (tip[0] - end[0]) * 0.14, end[1] + (tip[1] - end[1]) * 0.14)
    return (round(g[0] + 0.5, 1), round(g[1] + 0.5, 1)), (tip[0] + 0.5, tip[1] + 0.5)


def weapons():
    out = ROOT / "assets/creator/weapons/god"
    out.mkdir(parents=True, exist_ok=True)
    meta = {}
    for wid, (seed, scale, hold, name, two) in WEAPONS.items():
        im = crop(Image.open(RAW / f"{wid}_s{seed}.png").convert("RGBA"))
        im.save(out / f"{wid}.png")
        g, t = measure(im, hold == "gun")
        e = {"texture": f"res://assets/creator/weapons/god/{wid}.png", "scale": scale, "grip": list(g), "tip": list(t)}
        if hold:
            e["hold"] = hold
        if two:
            e["twohand"] = True
        meta[wid] = (e, name)
    return meta


def outfits():
    import gen_outfits as go
    import gen_art
    go.OUTFITS.update(gen_art.OUTFITS)
    for oid in gen_art.OUTFITS:
        go.install(oid)


def catalog(wmeta=None):
    c = json.loads(CAT.read_text())
    for pid, (slots, name, pieces) in PARTS.items():
        for s in slots:
            if not (ROOT / f"assets/creator/parts/{s}/{pid}.png").exists():
                continue
            c["slots"][s]["items"][pid] = name
            c["slots"][s].setdefault("unlock", {})[pid] = HINT % (pieces.split(" / ")[SLOT_PIECE[s]] if s in SLOT_PIECE else pieces)
    for wid, (e, name) in (wmeta or {}).items():
        c["weapons"][wid] = e
        c["slots"]["weapon"]["items"][wid] = name
        c["slots"]["weapon"].setdefault("unlock", {})[wid] = HINT % name.replace("GOD · ", "")
    CAT.write_text(json.dumps(c, indent=1, ensure_ascii=False) + "\n")


def main():
    want = sys.argv[1:] or ["icons", "fx", "weapons", "outfits", "catalog"]
    wm = None
    if "icons" in want:
        icons()
    if "fx" in want:
        fx()
    if "weapons" in want:
        wm = weapons()
    if "outfits" in want:
        outfits()
    if "catalog" in want:
        catalog(wm if wm is not None else weapons())
    print("installiert:", want)


if __name__ == "__main__":
    main()
