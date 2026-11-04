#!/usr/bin/env python3
"""Skill-Icons für den Kampfstil Glutatem mit PixelLab (pixflux, 48x48,
1 Generierung je Icon). Key nur aus PIXELLAB_API_KEY. Ergebnis:
assets/combat/icons/glutatem/<id>.png (GlutIcons nimmt sie, wenn vorhanden).

    python3 -I tools/glutatem/gen_icons.py [id ...]
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "icons" / "glutatem"
STYLE = ("game skill icon, square composition filling the whole canvas, centered subject, dark red-black background, "
         "fire and blacksmith forge theme, glowing orange and white-hot colors, bold dark outline, high contrast, "
         "clean readable shapes, no text, no letters, no frame")
ICONS = {
    "funkenschlag": "a katana blade striking an iron anvil, a big cone of bright orange sparks bursting forward",
    "schlackeregen": "an upward sword slash arc throwing three glowing molten slag rocks into the air",
    "weissglut": "a katana blade glowing white hot from the hilt to the tip, heat shimmer and small flames around it",
    "ambosshaltung": "a dark iron anvil with a katana held horizontally in front as a guard, a ring of sparks around it",
    "funkenflug": "a fast dash slash, a horizontal streak of fire with flying sparks and a blade at the front",
    "essensturz": "a sword plunging straight down into the ground like a hammer, a wave of fire spreading to both sides",
    "meisterzug": "a roaring blacksmith forge furnace mouth with a giant white-hot flame and a katana silhouette in front",
    "letzte_esse": "a giant glowing smith hammer hitting the ground, a huge wave of fire rolling forward",
    "schmelzofen": "a dome of molten fire like a furnace with a glowing white core about to burst",
    "funkensturm": "a storm of falling fiery sparks and meteors raining down from a dark sky",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [k for k in ICONS if not (OUT / f"{k}.png").exists()]
    before = pl2.balance()
    log = {}
    for name in want:
        p = {"description": ICONS[name] + ", " + STYLE, "image_size": {"width": 48, "height": 48},
             "outline": "single color black outline", "shading": "medium shading", "detail": "medium detail",
             "no_background": False, "text_guidance_scale": 8, "seed": 31}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        log[name] = r.get("usage")
        print(name, r.get("usage"), flush=True)
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
