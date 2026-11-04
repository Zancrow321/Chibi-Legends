#!/usr/bin/env python3
"""Effekt-Sprites für den Kampfstil Bollwerk mit PixelLab (pixflux, 128x128,
transparent, 1 Generierung je Bild). Sie dienen zugleich als Skill-Icons
(BollwerkIcons legt sie auf eine dunkle Platte). Key nur aus PIXELLAB_API_KEY.
Ergebnis: assets/combat/vfx/bollwerk/<id>.png

    python3 -I tools/bollwerk/gen_fx.py [id ...]
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "combat" / "vfx" / "bollwerk"
STYLE = ("game visual effect sprite, military sci-fi action effect, glowing, vivid bright colors, "
         "thick bold shapes, strong contrast, transparent background, no character, no person, no text, no letters")
FX = {
    "salve": "a rifle muzzle flash burst on the left with four bright amber bullet tracer streaks flying to the right, small brass shell casings, amber and gold",
    "durchbruch": "a heavy blunt impact burst from a rifle butt strike, a cracked star shaped shockwave with metal sparks flying, amber and steel grey",
    "explosion": "a round frag grenade explosion, orange and yellow fireball with dark grey smoke and flying shrapnel sparks, white hot core",
    "schildwand": "a vertical rectangular hexagon pattern energy shield barrier panel, translucent light blue glow with bright cyan edges",
    "kettenhaken": "a metal grappling hook with three claws flying to the right on a taut steel chain, amber sparks at the tip, motion lines",
    "staubstoss": "a meteor like orange streak crashing straight down from the top into a wide flat burst of dust clouds and shockwave rings at the bottom, debris flying sideways, floating in empty space, isolated effect",
    "zwillingsrohr": "two rockets flying side by side to the right with bright orange exhaust flames and white smoke trails behind them",
    "plasmatreffer": "an intense cyan plasma energy beam impact burst, electric arcs and a bright white core, round splash of energy",
    "schrotladung": "a wide shotgun blast cone opening to the right, many small bright pellet streaks and a big orange muzzle flash on the left",
    "schildbruch": "a shattering hexagonal energy shield bursting into many glowing light blue glass shards flying outward",
}
SEEDS = {"staubstoss": 71}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [k for k in FX if not (OUT / f"{k}.png").exists()]
    before = pl2.balance()
    for name in want:
        p = {"description": FX[name] + ", " + STYLE, "image_size": {"width": 128, "height": 128},
             "outline": "lineless", "shading": "medium shading", "detail": "medium detail",
             "no_background": True, "text_guidance_scale": 8, "seed": SEEDS.get(name, 47)}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        print(name, r.get("usage"), flush=True)
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
