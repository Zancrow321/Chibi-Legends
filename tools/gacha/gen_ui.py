#!/usr/bin/env python3
"""PixelLab art for the Sternschrein (gacha): banner key art, style emblems,
cards, icons, button and the summon circle. pixflux, 1 generation each
(26 in total). Key only from PIXELLAB_API_KEY. Output: assets/gacha/<name>.png,
prompts and usage in assets/gacha/raw/log.json. GachaScreen draws stand-ins
for every file that is missing.

    python3 -I tools/gacha/gen_ui.py [name ...]     (default: all missing)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "gacha"
LOG = OUT / "raw" / "log.json"

UI = ("game UI element, pixel art, bold black ink outline, manga panel style, high contrast, "
      "clean readable shapes, no text, no letters")
ICON = "game item icon, pixel art, centered, bold dark outline, high contrast, glowing highlights, no text, no letters"
ART = ("anime gacha banner key art, pixel art, dramatic diagonal composition, glowing light rays, "
       "starry night sky, epic heroic mood, no text, no letters, no logo")

# name: (description, width, height, transparent background)
ASSETS = {
    # banner key art (one per banner style, no copyrighted characters: original silhouettes)
    "banner_schwarzmond": ("a lone swordsman silhouette with a huge black cleaver sword under a giant black crescent moon, "
                           "cyan and deep blue night, crimson sparks, " + ART, 320, 256, False),
    "banner_gleichklang": ("a dancer silhouette with a long scythe, glowing pale blue soul waves and bronze bells, "
                           "violet night sky, " + ART, 320, 256, False),
    "banner_bollwerk": ("an armored super soldier with a glowing amber visor and a blue energy shield, "
                        "orbital laser beam from the sky, steel and amber colors, " + ART, 320, 256, False),
    "banner_wirbelwille": ("a dark-haired young woman in a teal coat spinning a swirling turquoise wind sphere in one palm, "
                           "many translucent shadow clones behind, gold and turquoise, " + ART, 320, 256, False),
    "banner_grenzbrecher": ("a martial artist in a powerful stance with a huge blue ki aura bursting up, "
                            "golden sparks, a mountain peak behind, " + ART, 320, 256, False),
    "banner_spannkraft": ("a cheerful brawler stretching a rubber-like arm into a giant punch, ocean waves and a sun, "
                          "coral red and yellow, " + ART, 320, 256, False),
    "banner_lauffeuer": ("a fighter whose body turns into roaring flames, fire fists, a wildfire spreading behind, "
                         "orange red and gold, " + ART, 320, 256, False),
    # emblems (cards, banner list, cut-in)
    "emblem_glutatem": ("emblem of a white-hot katana crossed over an anvil with a burst of orange sparks, " + ICON, 64, 64, True),
    "emblem_schwarzmond": ("emblem of a black crescent moon pierced by a huge black sword, cyan glow, " + ICON, 64, 64, True),
    "emblem_gleichklang": ("emblem of a scythe blade inside a ring of pale blue sound waves with a small bronze bell, " + ICON, 64, 64, True),
    "emblem_bollwerk": ("emblem of a futuristic armored helmet with a glowing amber visor in front of a blue hex shield, " + ICON, 64, 64, True),
    "emblem_wirbelwille": ("emblem of a swirling turquoise wind sphere with a golden spiral, " + ICON, 64, 64, True),
    "emblem_grenzbrecher": ("emblem of a clenched fist surrounded by a blazing blue ki aura and golden sparks, " + ICON, 64, 64, True),
    "emblem_spannkraft": ("emblem of a stretching rubber fist with motion rings, coral red and yellow, " + ICON, 64, 64, True),
    "emblem_lauffeuer": ("emblem of a burning fist made of fire with flame trails, orange and gold, " + ICON, 64, 64, True),
    # cards (portrait frames, centre left empty for the prize)
    "card_back": ("back of a collectible card, deep indigo with a golden eight-pointed star in the centre and "
                  "ornate gold corners, " + UI, 96, 136, True),
    "card_selten": ("empty collectible card frame, thick blue metallic border, plain light blue empty inside, "
                    "small star at the top, " + UI, 96, 136, True),
    "card_episch": ("empty collectible card frame, thick purple crystal border with small gems, plain pale violet empty inside, "
                    + UI, 96, 136, True),
    "card_legendaer": ("empty collectible card frame, thick ornate golden border with glowing gems and rays, "
                       "plain pale gold empty inside, " + UI, 96, 136, True),
    # icons
    "crystal": ("a glowing blue star crystal gem with a small star inside, " + ICON, 32, 32, True),
    "gift": ("a small gift box wrapped in red with a gold star ribbon, " + ICON, 32, 32, True),
    "icon_splitter": ("a small pile of glowing cyan crystal shards, " + ICON, 32, 32, True),
    "icon_dye": ("a small glass bottle of dye with a white liquid and a cork, " + ICON, 32, 32, True),
    "icon_outfit": ("a folded martial arts jacket with a red belt on top, " + ICON, 32, 32, True),
    # summon
    "summon_circle": ("a magic summoning circle seen from the front, golden rings with star constellation lines and runes, "
                      "glowing, transparent background, " + UI, 128, 128, True),
    "button_summon": ("a wide slanted red button with a thick black outline and a small gold star on the left, "
                      "empty, no text, " + UI, 192, 48, True),
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
             "no_background": transparent, "text_guidance_scale": 8, "seed": 77}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        log[name] = {"prompt": desc, "size": [w, h], "seed": 77, "usage": r.get("usage")}
        print(name, r.get("usage"), flush=True)
    LOG.write_text(json.dumps(log, indent=1, ensure_ascii=False))
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
