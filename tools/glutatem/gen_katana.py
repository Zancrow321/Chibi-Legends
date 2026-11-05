#!/usr/bin/env python3
"""PixelLab-Grafiken für das Glutatem-Katana "Glutklinge" (1 Generierung je Bild).

    katana   Waffen-Sprite 40x40 (pixflux, Startbild = gen_katana_skizze.py),
             ein Kandidat je Seed nach assets/creator/weapons/raw/glutatem/
    icon     Item-Icon 32x32 (pixflux), je Seed nach assets/items/raw/
    fx       Skill-Effekte 128x128 (pixflux, transparent) nach assets/combat/vfx/glutatem/
             (3 Katana-Schnittbögen + 6 Züge + Meisterzug + 3 Varianten)

Key nur aus PIXELLAB_API_KEY.

    python3 -I tools/glutatem/gen_katana.py katana 11,23,37,52 [stärke]
    python3 -I tools/glutatem/gen_katana.py icon 79,83
    python3 -I tools/glutatem/gen_katana.py fx [id ...]        (Standard: alle fehlenden)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "creator" / "weapons" / "raw" / "glutatem"
ICON_RAW = ROOT / "assets" / "items" / "raw"
FX_OUT = ROOT / "assets" / "combat" / "vfx" / "glutatem"
SKIZZE = ROOT / "assets" / "creator" / "weapons" / "glutklinge_skizze.png"

KATANA = ("a katana weapon item sprite, slim slightly curved single edged blade of dark forged blackened steel "
          "running diagonally from the lower left to the tip at the upper right, a glowing orange ember hardening line "
          "along the cutting edge on the lower side, small dark iron hand guard shaped like a tiny anvil, small gold collar, "
          "grip wrapped in red cord with a diamond pattern, gold pommel cap, dark outline, side view, no character, no hands")
ICON = ("a katana with a dark forged steel blade with a glowing orange ember edge, red cord wrapped grip and small iron "
        "anvil shaped guard, lying diagonally, small orange sparks around it, RPG inventory item icon, pixel art, centered, "
        "single object, bold dark outline, high contrast, no text, no background")
FX_STYLE = ("game visual effect sprite, glowing fire forge effect, molten orange, gold and white hot colors with deep red edges, "
            "thick bold shapes, strong contrast, transparent background, isolated effect, no character, no person, no sword, "
            "no text, no letters")
FX = {
    # Katana-Schnittbögen für J/K-Hiebe (werden auf die Klinge gelegt und gedreht)
    "schnitt_quer": "a wide thin crescent shaped sword slash trail arc sweeping from left to right, bright white hot inner edge fading to orange and red, small sparks flying off the arc",
    "schnitt_hoch": "a tall thin crescent shaped sword slash trail arc rising from bottom to top, bright white hot inner edge fading to orange and red, small embers trailing",
    "schnitt_stich": "a long straight horizontal thrust streak pointing right with a sharp glowing white tip, orange fire trail behind it and a small ring of sparks at the tip",
    # die sechs Züge
    "funkenschlag": "a burst of bright orange and gold forge sparks spraying outward from a white hot impact point, like a hammer hitting glowing metal on an anvil",
    "schlackeregen": "several glowing molten slag droplets and lava blobs falling down, orange and red with dark crust, trails of smoke",
    "weissglut": "a white hot glowing horizontal blade slash with an intense white core and yellow orange halo, heat shimmer, bright flash",
    "ambosshaltung": "a round glowing orange shield like ring of fire with an anvil shaped silhouette of heat in the middle, sparks deflecting outward",
    "funkenflug": "a long horizontal dash streak to the right made of fire and many tiny sparks, motion lines, orange and gold",
    "essensturz": "a fiery streak crashing straight down from the top into a wide burst of flames and molten splashes and shockwave ring at the bottom",
    # Meisterzug und seine drei Varianten
    "meisterzug": "a big vertical pillar of white hot forge fire erupting upward with an orange ring of sparks around its base, bright flash",
    "letzte_esse": "a huge wave of fire rolling to the right, curling flames, white hot front edge and orange and red body, embers",
    "schmelzofen": "a dome of glowing molten fire like the inside of a furnace, orange walls with white hot cracks, heat haze",
    "funkensturm": "a storm of hundreds of falling fiery sparks and small meteors raining down diagonally, orange and gold streaks",
}
SEEDS = {}


def katana(seeds, strength):
    RAW.mkdir(parents=True, exist_ok=True)
    init = Image.open(SKIZZE).convert("RGBA")
    for s in seeds:
        p = {"description": KATANA, "image_size": {"width": 40, "height": 40}, "no_background": True,
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "text_guidance_scale": 8, "seed": s, "init_image": pl2.b64(init), "init_image_strength": strength}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(RAW / f"glutklinge_{strength}_{s}.png")
        print("katana", s, r.get("usage"), flush=True)


def icon(seeds):
    ICON_RAW.mkdir(parents=True, exist_ok=True)
    for s in seeds:
        p = {"description": ICON, "image_size": {"width": 32, "height": 32},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "no_background": True, "text_guidance_scale": 8, "seed": s}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(ICON_RAW / f"glutklinge_{s}.png")
        print("icon", s, r.get("usage"), flush=True)


def fx(names):
    FX_OUT.mkdir(parents=True, exist_ok=True)
    want = names or [k for k in FX if not (FX_OUT / f"{k}.png").exists()]
    for name in want:
        p = {"description": FX[name] + ", " + FX_STYLE, "image_size": {"width": 128, "height": 128},
             "outline": "lineless", "shading": "medium shading", "detail": "medium detail",
             "no_background": True, "text_guidance_scale": 8, "seed": SEEDS.get(name, 53)}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(FX_OUT / f"{name}.png")
        print("fx", name, r.get("usage"), flush=True)


def main() -> None:
    what = sys.argv[1]
    before = pl2.balance()
    if what == "katana":
        katana([int(x) for x in sys.argv[2].split(",")], int(sys.argv[3]) if len(sys.argv) > 3 else 120)
    elif what == "icon":
        icon([int(x) for x in sys.argv[2].split(",")])
    else:
        fx(sys.argv[2:])
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
