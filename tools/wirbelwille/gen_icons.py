#!/usr/bin/env python3
"""Skill-Icons für den Kampfstil Wirbelwille mit PixelLab (pixflux, 48x48,
1 Generierung je Icon). Key nur aus PIXELLAB_API_KEY. Ergebnis:
assets/combat/icons/wirbelwille/<id>.png (WirbelIcons nimmt sie).

    python3 -I tools/wirbelwille/gen_icons.py [id ...]
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "icons" / "wirbelwille"
STYLE = ("game skill icon, square composition filling the whole canvas, centered subject, dark navy blue background, "
         "wind and ninja theme, glowing turquoise, white and gold colors, bold dark outline, high contrast, "
         "clean readable shapes, no text, no letters, no frame, no spiral symbol")
ICONS = {
    "wirbelansturm": "a fast fist punch followed by a spinning kick, white wind streaks and motion arcs around it",
    "kreiselfaust": "a clenched fist surrounded by three thin crossing glowing turquoise wind rings like a gyroscope",
    "klon_aufsteiger": "a pale blue translucent ghost copy of a ninja kicking upward, wind lines rising, small smoke puff",
    "wechselhuelle": "a straw training dummy wearing a jacket bursting into straw and grey smoke",
    "klonschleuder": "a pale blue ghost silhouette throwing a ninja forward in a flying kick, speed lines",
    "wirbelsturz": "a glowing fist with wind rings diving diagonally down onto the ground, shockwave ring on the floor",
    "meisterzug": "two pale blue ghost ninja silhouettes and one solid ninja silhouette back to back, wind swirling around them",
    "sturmrad": "a giant spinning pinwheel made of six curved turquoise wind blades with a glowing gold hub",
    "hundert_schatten": "many pale blue ghost ninja silhouettes in a circle attacking the center, motion lines",
    "orkanmantel": "a figure wrapped in a cloak of grey-turquoise storm wind with two huge wind arms and gold lightning sparks",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [k for k in ICONS if not (OUT / f"{k}.png").exists()]
    total = 0.0
    for name in want:
        p = {"description": ICONS[name] + ", " + STYLE, "image_size": {"width": 48, "height": 48},
             "outline": "single color black outline", "shading": "medium shading", "detail": "medium detail",
             "no_background": False, "text_guidance_scale": 8, "seed": 31}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        total += float((r.get("usage") or {}).get("generations", 0))
        print(name, r.get("usage"), flush=True)
    print("Generierungen:", round(total, 2))


if __name__ == "__main__":
    main()
