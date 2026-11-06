#!/usr/bin/env python3
"""PixelLab-Effekte für den Kampfstil Gleichklang (Sense Nachhall): 3 Sensen-
Schnittbögen für J/K, 6 Züge, Meisterzug und seine 3 Varianten (pixflux
128x128, transparent, 1 Generierung je Bild). KlangFx.burst() zeichnet sie
additiv, damit der Bloom sie aufgreift. Key nur aus PIXELLAB_API_KEY.

    python3 -I tools/gleichklang/gen_fx.py [id ...]     (Standard: alle fehlenden)
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "vfx" / "gleichklang"
STYLE = ("game visual effect sprite, glowing spectral soul and sound effect, pale ice blue, white and soft violet colors, "
         "thin sharp elegant shapes, strong glow, transparent background, isolated effect, no character, no person, "
         "no weapon, no text, no letters")
FX = {
    "schnitt_quer": "a very wide thin curved scythe slash arc like a crescent moon sweeping from left to right, bright white inner edge fading to pale blue, tiny glowing soul motes trailing",
    "schnitt_hoch": "a tall thin curved scythe slash arc rising from bottom to top like a crescent, bright white edge fading to pale blue and violet, small sparkles",
    "schnitt_wirbel": "a full circular spinning scythe slash ring, thin bright white blade trail with pale blue glow, motion blur",
    "sicheltakt": "two crossing thin crescent scythe slashes forming an X with a bright white flash in the middle and small ringing sound wave circles",
    "seelensichel": "a flying crescent shaped wave of pale blue soul energy moving to the right, white hot edge, wispy ghostly trail behind it",
    "himmelsreigen": "a tall vertical spiral of crescent slashes rising upward, pale blue and white, swirling soul wisps",
    "seelenlauschen": "concentric thin glowing sound wave rings around a small bright bell shaped light in the middle, pale blue and violet, calm",
    "sichelschritt": "a horizontal dash streak to the right made of pale blue ghostly afterimage light and a thin crescent slash at the front",
    "fallende_sichel": "a crescent scythe slash crashing straight down into a wide flat burst of pale blue sound wave rings and white light on the ground",
    "meisterzug": "a big glowing ghostly bronze bell silhouette made of pale blue light with white sound wave rings bursting out around it",
    "erntebogen": "a giant enormous crescent shaped soul blade slash of white and pale blue light sweeping in a huge arc, violet glow at its edges",
    "totengelaeut": "a tall vertical beam like slash of white light cutting from top to bottom with three heavy dark violet bell sound rings around it",
    "reiner_klang": "a big expanding ring of pure white and pale gold light like a church bell ring, soft rays and sparkles, holy cleansing glow",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [k for k in FX if not (OUT / f"{k}.png").exists()]
    before = pl2.balance()
    for name in want:
        p = {"description": FX[name] + ", " + STYLE, "image_size": {"width": 128, "height": 128},
             "outline": "lineless", "shading": "medium shading", "detail": "medium detail",
             "no_background": True, "text_guidance_scale": 8, "seed": 61}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        print(name, r.get("usage"), flush=True)
    print("Generierungen (Kontostand-Differenz):", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
