#!/usr/bin/env python3
"""Effekt-Sprites für den Kampfstil Spannkraft mit PixelLab (pixflux, 128x128,
transparent, 1 Generierung je Bild). Key nur aus PIXELLAB_API_KEY.
Die Bewegung (Wachsen, Ausblenden, additive Überlagerung, Bloom) entsteht im Code.
Ergebnis: assets/combat/vfx/spannkraft/<id>.png

    python3 -I tools/spannkraft/gen_fx.py [id ...]
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "vfx" / "spannkraft"
STYLE = ("game visual effect sprite, anime fighting game impact effect, glowing, vivid bright colors, "
         "thick bold shapes, strong contrast, transparent background, no character, no person, no text, no letters")
FX = {
    # Grundzüge
    "stossring": "a big circular shockwave ring of a punch impact seen from the side, coral red and sun yellow, white hot center flash, radiating speed lines",
    "schnappfaust": "a long stretched elastic punch trail, a horizontal motion streak tapering to a bright fist-shaped impact burst on the right, coral red and yellow",
    "prasselfaust": "many overlapping fist-shaped afterimage bursts in a cluster, dozens of small yellow and coral impact stars, rapid punch barrage effect",
    "fegebein": "a wide horizontal crescent sweep arc of wind and dust, bright sky blue and white with yellow edge, motion lines",
    "katapult": "an upward diagonal launch trail with a burst of air at the bottom and a bright star flash at the top, sky blue and yellow",
    "prallbauch": "a round bouncy pressure shockwave bubble bursting outward, translucent sky blue ring with white rim and yellow sparkles",
    "spannzug": "a springy coiled spring shaped motion trail with a puff of dust at the start, coral and yellow, cartoon speed lines",
    "fallbeil": "a ground slam shockwave seen from the side, a flat wide dome of light hitting the floor, rocks and dust flying up to the left and right, a vertical bright yellow streak coming down from above into the center, no fire, no flames",
    # Meisterzüge
    "dampfhagel": "rising pale grey steam clouds with orange heat shimmer and glowing embers, intense hot aura",
    "federkanone": "a huge horizontal cone shaped air cannon blast flying to the right, wide expanding shockwave cone with several concentric pressure rings, steel blue edges, white and yellow hot core on the left, speed lines",
    "eisenwille": "a steel blue metallic shimmering energy aura with sharp sparkles, hardened willpower glow",
    "grenzenlos": "a colorful cartoon comic explosion burst, star shape, sun yellow, sky blue and coral red with thick black outline, confetti like sparks",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [k for k in FX if not (OUT / f"{k}.png").exists()]
    before = pl2.balance()
    for name in want:
        p = {"description": FX[name] + ", " + STYLE, "image_size": {"width": 128, "height": 128},
             "outline": "lineless", "shading": "medium shading", "detail": "medium detail",
             "no_background": True, "text_guidance_scale": 8, "seed": {"fallbeil": 57, "federkanone": 63}.get(name, 41)}
        if name == "grenzenlos":
            p["outline"] = "single color black outline"
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        print(name, r.get("usage"), flush=True)
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
