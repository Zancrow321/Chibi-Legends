#!/usr/bin/env python3
"""PixelLab-Icons der Raid-Rüstung Essenwacht: Oberteil, Hose, Schuhe je
Seltenheit = 18 Icons (pixflux 32x32, 1 Generierung je Icon).
Ausgabe: assets/items/raid/essenwacht_<slot>_<seltenheit>.png

    python3 -I tools/raid_armor/gen_icons.py [name ...]   (Standard: alle fehlenden)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "items" / "raid"
LOG = OUT / "log.json"
ICON = "RPG inventory item icon, pixel art, centered, single object, bold dark outline, high contrast, no text, no background"

LOOK = {
    "gewoehnlich": "dull grey iron and brown leather, plain",
    "ungewoehnlich": "blackened iron with green enamel trim",
    "selten": "polished bright steel with deep blue cloth and blue enamel",
    "episch": "black-violet plate with glowing purple rune lines",
    "legendaer": "ornate white and gold plate with molten orange glowing cracks",
    "mythisch": "obsidian black plate with bright crimson glowing star-fire veins",
}
PIECE = {
    "oberteil": "a chest armor breastplate with shoulder plates",
    "hose": "armored leg greaves with knee plates",
    "schuhe": "a pair of armored boots",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    names = [f"essenwacht_{p}_{r}" for r in LOOK for p in PIECE]
    want = sys.argv[1:] or [n for n in names if not (OUT / f"{n}.png").exists()]
    before = pl2.balance()
    for name in want:
        _, piece, rar = name.split("_")
        desc = f"{PIECE[piece]}, {LOOK[rar]}, {ICON}"
        p = {"description": desc, "image_size": {"width": 32, "height": 32},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "no_background": True, "text_guidance_scale": 8, "seed": 83}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        log[name] = {"prompt": desc, "seed": 83, "usage": r.get("usage")}
        print(name, r.get("usage"), flush=True)
    LOG.write_text(json.dumps(log, indent=1, ensure_ascii=False))
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
