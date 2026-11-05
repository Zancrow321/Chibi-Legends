#!/usr/bin/env python3
"""Skill-Icons für die Kampfstile ohne eigene Icons (Schwarzmond, Gleichklang,
Bollwerk, Spannkraft, Lauffeuer) mit PixelLab (pixflux, 48x48, 1 Generierung
je Icon), danach auf Resurrect 64 gesnappt (tools/palette/quantize.py).
Key nur aus PIXELLAB_API_KEY. Ergebnis: assets/combat/icons/<stil>/<id>.png
(die <Stil>Icons-Skripte nehmen sie über PixelSkillIcon).

    python3 -I tools/skill_icons/gen_icons.py                 # alle fehlenden
    python3 -I tools/skill_icons/gen_icons.py bollwerk        # ein Stil
    python3 -I tools/skill_icons/gen_icons.py bollwerk/salve  # ein Icon (neu)
"""
import pathlib, subprocess, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
ICON_ROOT = ROOT / "assets" / "combat" / "icons"
BASE = ("game skill icon, square composition filling the whole canvas, centered subject, bold dark outline, "
        "high contrast, clean readable shapes, no text, no letters, no frame")

STYLES = {
    "schwarzmond": {
        "look": "dark midnight blue background, black moon blade swordsman theme, black crescent energy with glowing cyan rim and white highlights",
        "icons": {
            "mondschnitt": "a black katana slashing in two wide crescent arcs with glowing cyan edges and white motion streaks",
            "mondsichel": "one big black crescent moon shape flying sideways like a boomerang, thick glowing cyan outer rim, white speed lines behind it, no sword",
            "aufsteigender_mond": "an upward sword slash leaving a rising black and cyan crescent arc, small debris flying up",
            "entschlossene_abwehr": "a black katana held horizontally across in a guard, a cyan spark burst where a strike is blocked",
            "schwarze_spur": "a swordsman dashing forward leaving a long black afterimage trail with cyan speed lines",
            "fallender_mond": "a sword plunging straight down with a black crescent trail and a cyan shockwave ring on the ground",
            "meisterzug": "a huge black full moon with a glowing cyan corona behind a raised black katana, dark energy swirling",
            "neumond": "a black katana wrapped in condensed swirling black energy with thin cyan cracks of light, speed lines",
            "blutmond": "a giant black and crimson red crescent moon wave rolling forward, red glowing rim and dark sparks",
            "mondfinsternis": "a total solar eclipse black disk with a thin white ring, one huge white diagonal slash cutting through darkness",
        },
    },
    "gleichklang": {
        "look": "dark indigo violet background, soul reaper theme, every scythe is a grim reaper scythe with a long staff and one big curved crescent blade at the top, pale ice blue and white glow with violet and bronze accents",
        "icons": {
            "sicheltakt": "a large curved scythe blade swinging in two pale blue arcs, small musical resonance rings",
            "seelensichel": "a grim reaper scythe with a big curved blade swept horizontally, a glowing pale blue ghostly blade extension along the curve",
            "himmelsreigen": "a tall rising vertical arc of pale blue light curving upward with a small scythe at its base, upward arrow motion, sparks lifting",
            "seelenlauschen": "a closed eye calm face silhouette with concentric pale blue sound wave rings around it",
            "sichelschritt": "a small figure silhouette pole vaulting forward over a scythe staff planted in the ground, pale blue motion arc",
            "fallende_sichel": "a scythe spinning like a wheel while plunging diagonally downward, violet spiral trail, impact flash at the bottom",
            "meisterzug": "two silhouettes back to back, a glowing white soul scythe raised between them, violet and blue resonance rings",
            "erntebogen": "a gigantic glowing white crescent slash arc filling the whole icon, a tiny scythe at the bottom corner, pale blue soul flames",
            "totengelaeut": "a large bronze bell ringing with three dark violet sound rings and a vertical white blade below it",
            "reiner_klang": "a bright white ring of light expanding from a small bronze bell, pale blue sparkles",
        },
    },
    "bollwerk": {
        "look": "dark graphite grey background, armored sci-fi soldier theme, amber gold and steel colors with cyan plasma accents",
        "icons": {
            "salve": "an assault rifle firing a burst of four amber tracer bullets with muzzle flash",
            "durchbruch": "an armored gauntlet bashing forward with a heavy rifle butt, orange impact burst and cracked plating",
            "splitterwurf": "a round frag grenade flying in an arc with a dotted trajectory and an orange explosion behind it",
            "schildprotokoll": "a glowing blue hexagonal energy shield wall deflecting incoming amber bullets",
            "kettenhaken": "a metal grappling hook on a taut steel chain flying forward, amber sparks",
            "orbitalsturz": "an armored soldier diving down from the sky like a meteor, a green target marker and a dust shockwave below",
            "meisterzug": "an amber gold armored helmet visor glowing, green targeting crosshair reflected on it",
            "zwillingsrohr": "a twin barrel rocket launcher firing two rockets with orange flame trails",
            "lanzenstrahl": "a long straight cyan plasma beam piercing through a line, crackling energy",
            "letzter_befehl": "a steel grappling chain hook and a pump shotgun crossed in an X, orange shotgun blast flash",
        },
    },
    "spannkraft": {
        "look": "dark plum purple background, rubbery stretching brawler comic theme, coral red, sunny yellow and white colors with sky blue accents",
        "icons": {
            "schnappfaust": "a stretched rubbery arm shooting a fist far forward, comic motion lines and yellow impact star",
            "fegebein": "a long stretched leg sweeping horizontally in a wide arc, dust cloud and motion lines",
            "katapult": "a figure slingshotting diagonally upward with stretched arms anchored to the ground, yellow speed lines",
            "prallbauch": "a round puffed up balloon belly bouncing back a fist, comic bounce rings",
            "spannzug": "two stretched arms grabbing a ledge and pulling the body forward like a rubber band",
            "fallbeilferse": "a stretched leg coming down from the top edge, its heel smashing onto cracked ground with a yellow comic impact star",
            "meisterzug": "a big grinning fist clenched with steam and yellow comic burst lines around it",
            "dampfhagel": "a rapid barrage of many blurry fists in a cloud of white steam, coral red heat shimmer",
            "federkanone": "a hugely inflated giant fist launching forward with a coral red shockwave ring",
            "grenzenlos": "a bouncy cartoon figure leaping with white steam ring and yellow comic star bursts, wild joyful energy",
        },
    },
    "lauffeuer": {
        "look": "dark charred brown red background, fire fist theme, blazing orange, gold and red flames with white hot core",
        "icons": {
            "flammenknoechel": "a fist punching with flames wrapping around the knuckles, orange embers",
            "flammenfaust": "a giant fist made of roaring orange fire flying forward, gold hot core",
            "steigflamme": "a tall pillar of flame bursting up from the ground, embers rising",
            "flammenleib": "a body silhouette dissolving into flickering flames, side step afterimage",
            "feuerstrom": "a stream of fire shaped like a dashing figure flowing forward, flame trail",
            "niederschlag": "a fireball blasting diagonally downward into the ground with a fiery explosion",
            "meisterzug": "a towering wall of fire with a fist silhouette raised in front, glowing from below",
            "grosser_brand": "a gigantic flaming fist rolling through a wide corridor of fire",
            "brandgestirn": "a huge glowing fireball sun held above a raised hand, swirling flames gathering",
            "leuchtfeuer": "eight small glowing ember flakes floating in a circle, igniting into small orange bursts",
        },
    },
}


def snap(path: pathlib.Path) -> None:
    subprocess.run([sys.executable, "-I", str(ROOT / "tools/palette/quantize.py"), str(path), "--inplace",
                    "--max-colors", "24"], check=True, stdout=subprocess.DEVNULL)


def jobs(args: list[str]) -> list[tuple[str, str]]:
    out = []
    for style, cfg in STYLES.items():
        for sid in cfg["icons"]:
            exists = (ICON_ROOT / style / f"{sid}.png").exists()
            if not args and not exists:
                out.append((style, sid))
            elif style in args and not exists or f"{style}/{sid}" in args:
                out.append((style, sid))
    return out


def main() -> None:
    total = 0.0
    for style, sid in jobs(sys.argv[1:]):
        cfg = STYLES[style]
        out = ICON_ROOT / style / f"{sid}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        p = {"description": f"{cfg['icons'][sid]}, {cfg['look']}, {BASE}", "image_size": {"width": 48, "height": 48},
             "outline": "single color black outline", "shading": "medium shading", "detail": "medium detail",
             "no_background": False, "text_guidance_scale": 8, "seed": 31}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(out)
        snap(out)
        total += float((r.get("usage") or {}).get("generations", 0))
        print(style, sid, r.get("usage"), flush=True)
    print("Generierungen:", round(total, 2))


if __name__ == "__main__":
    main()
