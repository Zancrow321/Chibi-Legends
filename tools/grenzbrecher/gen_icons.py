#!/usr/bin/env python3
"""Skill-Icons für den Kampfstil Grenzbrecher mit PixelLab (pixflux, 48x48,
1 Generierung je Icon). Key nur aus PIXELLAB_API_KEY. Ergebnis:
assets/combat/icons/grenzbrecher/<id>.png (noch nicht im Spiel eingebaut).

    python3 -I tools/grenzbrecher/gen_icons.py [id ...]
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "icons" / "grenzbrecher"
STYLE = ("game skill icon, square composition filling the whole canvas, centered subject, dark navy blue background, "
         "martial arts and glowing ki energy theme, bright sky blue and white glow with small gold sparks, bold dark outline, "
         "high contrast, clean readable shapes, no text, no letters, no frame")
ICONS = {
    "steilpfad_folge": "a fast martial arts spinning kick with motion lines, a fist punch blur and blue impact sparks",
    "kernstrahl": "a single open palm thrusting forward firing a huge straight beam of white and sky blue energy, bright glowing core",
    "himmelsauftakt": "an uppercut fist rising upward with a vertical streak of blue energy and dust swirling below",
    "ruhiger_gegenschlag": "an open hand calmly deflecting a strike, a circular ring of blue energy and a counter fist behind it",
    "fernschritt": "a martial artist fading into blue afterimages, a fist pressed into an open palm salute, a glowing teleport ring",
    "meteor_abschluss": "two clasped fists hammering downward like a meteor, a blue comet trail and a crater impact",
    "meisterzug": "a huge flaming white and sky blue aura pillar rising into the sky with floating rocks and a cracked ground",
    "grenzbruch": "glowing blue energy lines on a clenched forearm, a white-blue flame aura exploding outward, shards of broken light",
    "fernstrahl": "a target mark on an enemy silhouette, a teleport ring and a point blank beam of white blue energy",
    "sonnenkern": "a raised fist holding up a giant glowing miniature sun with golden corona, floating dust and rocks rising toward it",
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
