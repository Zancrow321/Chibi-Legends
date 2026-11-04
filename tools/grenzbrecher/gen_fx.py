#!/usr/bin/env python3
"""Effekt-Sprites für den Kampfstil Grenzbrecher mit PixelLab (pixflux, 128x128,
transparent, 1 Generierung je Bild). Key nur aus PIXELLAB_API_KEY.
Die Bewegung (Wachsen, Ausblenden, additive Überlagerung, Bloom) entsteht im Code
(GrenzFx). Ergebnis: assets/combat/vfx/grenzbrecher/<id>.png

    python3 -I tools/grenzbrecher/gen_fx.py [id ...]
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "vfx" / "grenzbrecher"
STYLE = ("game visual effect sprite, anime fighting game ki energy effect, glowing, vivid bright colors, "
         "thick bold shapes, strong contrast, transparent background, no character, no person, no text, no letters")
FX = {
    "kern": "a bright round burst of ki energy, white hot core, sky blue glow, short radiating spikes, muzzle flash",
    "strahl": "a straight horizontal energy beam segment crossing the whole image from left to right, white core, sky blue edges, small swirling ripples",
    "schockring": "a big circular shockwave ring of ki energy seen from the front, sky blue and white, crackling edge, radiating speed lines",
    "faust": "a punch impact star burst, white center, sky blue and small gold sparks, sharp spikes pointing outward",
    "tritt": "a wide crescent kick arc trail of wind and light, sky blue and white with a thin gold edge, motion lines",
    "aura": "a rising flame aura of blue and white ki energy, tall flickering flame tongues pointing upward, hollow center, bright base",
    "fernschritt": "a teleport flash, a thin vertical white light slit with a sky blue distortion ring and small sparkles around it",
    "meteor": "a downward comet impact trail, bright white blue streak coming from the top left into a burst at the bottom right, dust",
    "grenzbruch": "a tall vertical pillar of white and sky blue light shooting upward, cracked ground at the bottom, sparks flying up",
    "sonnenkern": "a small glowing sun with a golden corona and flaring rays, white yellow core, orange edges, round",
    "einschlag": "a huge round explosion dome of golden and white light hitting the ground, shockwave ring, rocks flying up",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [k for k in FX if not (OUT / f"{k}.png").exists()]
    used = 0.0
    for name in want:
        p = {"description": FX[name] + ", " + STYLE, "image_size": {"width": 128, "height": 128},
             "outline": "lineless", "shading": "medium shading", "detail": "medium detail",
             "no_background": True, "text_guidance_scale": 8, "seed": 41}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        u = (r.get("usage") or {}).get("generations") or 0
        used += float(u)
        print(name, r.get("usage"), flush=True)
    print("Generierungen:", used)


if __name__ == "__main__":
    main()
