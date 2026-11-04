#!/usr/bin/env python3
"""PixelLab art for Herausforderungen + Saison-Pass: season header, chest,
lock, done stamp and one icon per challenge event. pixflux, 1 generation
each (14). Shared icons (crystal, splitter, dye, outfit) come from
tools/gacha/gen_ui.py. Key only from PIXELLAB_API_KEY. Output assets/pass/.

    python3 -I tools/pass/gen_ui.py [name ...]     (default: all missing)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "pass"
LOG = OUT / "raw" / "log.json"
ICON = "game UI icon, pixel art, centered, bold black outline, manga style, high contrast, glowing highlights, no text, no letters"

ASSETS = {
    "season_header": ("wide banner of a night sky full of flying fire sparks and embers over a blacksmith academy rooftop, "
                      "orange red and deep purple, dramatic, pixel art, no text, no letters", 384, 96, False),
    "icon_chest": ("a small treasure chest with gold trim, glowing light leaking out, " + ICON, 32, 32, True),
    "icon_lock": ("a heavy golden padlock, " + ICON, 32, 32, True),
    "stamp_done": ("a round red ink stamp with a big check mark, slightly rotated, manga style, " + ICON, 48, 48, True),
    "ch_kill": ("two crossed swords, " + ICON, 32, 32, True),
    "ch_elite": ("a horned golem skull with a crown, " + ICON, 32, 32, True),
    "ch_combo": ("a fist with many impact stars and speed lines, " + ICON, 32, 32, True),
    "ch_meisterzug": ("a huge burst of golden light with a star in the centre, super move, " + ICON, 32, 32, True),
    "ch_wave": ("a red banner flag with a wave symbol, " + ICON, 32, 32, True),
    "ch_loot": ("a small leather bag with a sword hilt sticking out, " + ICON, 32, 32, True),
    "ch_loot_epic": ("a glowing purple gem with sparkles, " + ICON, 32, 32, True),
    "ch_reaction": ("fire and ice orbs colliding into an explosion, " + ICON, 32, 32, True),
    "ch_gacha": ("a falling shooting star with a blue trail, " + ICON, 32, 32, True),
    "ch_level": ("a green arrow pointing up with a star, level up, " + ICON, 32, 32, True),
}


def main() -> None:
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    want = sys.argv[1:] or [k for k in ASSETS if not (OUT / f"{k}.png").exists()]
    before = pl2.balance()
    for name in want:
        desc, w, h, transparent = ASSETS[name]
        p = {"description": desc, "image_size": {"width": w, "height": h},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "no_background": transparent, "text_guidance_scale": 8, "seed": 78}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        log[name] = {"prompt": desc, "size": [w, h], "seed": 78, "usage": r.get("usage")}
        print(name, r.get("usage"), flush=True)
    LOG.write_text(json.dumps(log, indent=1, ensure_ascii=False))
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
