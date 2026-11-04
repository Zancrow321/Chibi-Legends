#!/usr/bin/env python3
"""PixelLab item icons: 6 kinds x 3 variants = 18 (pixflux 32x32, 1
generation each). ItemIcon uses assets/items/<kind>_<0-2>.png; rarity
stays visible through the frame colour. Key only from PIXELLAB_API_KEY.

    python3 -I tools/items/gen_icons.py [name ...]     (default: all missing)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "items"
LOG = OUT / "raw" / "log.json"
ICON = "RPG inventory item icon, pixel art, centered, single object, bold dark outline, high contrast, no text, no background"

KINDS = {
    "waffe": ["a slim katana with a red wrapped grip", "a broad two-handed greatsword", "a curved sabre with a golden guard"],
    "oberteil": ["a sleeveless martial arts vest", "a padded leather jacket", "a light armored chest plate"],
    "hose": ["loose martial arts trousers", "leather leg guards", "armored greaves with knee plates"],
    "schuhe": ["simple cloth sandals", "sturdy leather boots", "light running shoes with wing ornaments"],
    "accessoire": ["a red headband", "a scarf with a golden clasp", "a belt with a round buckle"],
    "talisman": ["a wooden amulet on a string", "a glowing round pearl pendant", "a fang necklace"],
}


def main() -> None:
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    names = [f"{k}_{i}" for k in KINDS for i in range(3)]
    want = sys.argv[1:] or [n for n in names if not (OUT / f"{n}.png").exists()]
    before = pl2.balance()
    for name in want:
        kind, i = name.rsplit("_", 1)
        desc = KINDS[kind][int(i)] + ", " + ICON
        p = {"description": desc, "image_size": {"width": 32, "height": 32},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "no_background": True, "text_guidance_scale": 8, "seed": 79}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        log[name] = {"prompt": desc, "seed": 79, "usage": r.get("usage")}
        print(name, r.get("usage"), flush=True)
    LOG.write_text(json.dumps(log, indent=1, ensure_ascii=False))
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
