#!/usr/bin/env python3
"""PixelLab-Art der GOD-Stufe (Serie 1 „Heilig“, Serie 2 „Dämon“), alles eigene Entwürfe.

  python3 -I tools/god_items/gen_art.py outfits     # 2 Outfits x 5 Raster (Creator, 68 Posen)
  python3 -I tools/god_items/gen_art.py heads       # Sonnenkrone, Hörnerkrone (Frisur-Slot)
  python3 -I tools/god_items/gen_art.py fx          # Flügel, Heiligenschein, Feder, Glutfetzen
  python3 -I tools/god_items/gen_art.py weapons     # Waffen-Sprites der Stile mit Waffe (2 Seeds)
  python3 -I tools/god_items/gen_art.py icons       # 18 Item-Icons
Rohbilder: assets/god/raw/, Log: assets/god/raw/log.json. Key nur aus PIXELLAB_API_KEY.
"""
import json, pathlib, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/jus_style"))
sys.path.insert(0, str(ROOT / "tools/japan_outfits"))
import pl2  # noqa: E402

RAW = ROOT / "assets/god/raw"
LOG = RAW / "log.json"

OUTFITS = {  # kurz halten: PixelLab nimmt höchstens 500 Zeichen
    "god_seraph": "holy seraph knight: ornate white and gold breastplate with a glowing sun emblem, gold feather shoulder "
                  "plates, white silk tabard to the knees, white trousers with gold knee guards, white-gold winged boots",
    "god_abgrund": "demon lord armor: spiked black obsidian chest plate with glowing crimson cracks and a red eye emblem, "
                   "torn crimson loincloth, black chained trousers with red runes, black clawed boots",
}
HEADS = {
    "god_sonnenkrone": "long flowing platinum blonde hair with a tall radiant golden sun crown with sharp rays of light on top "
                       "of the head, the eyes and face stay fully visible",
    "god_hoernerkrone": "wild spiky jet black hair with two huge curved black demon horns growing from the head with glowing "
                        "crimson tips and a small black iron crown between them, the eyes and face stay fully visible",
}
FX = {  # name: (w, h, Beschreibung)
    "fx_fluegel_heilig": (128, 96, "a pair of huge majestic spread angel wings made of radiant white and golden glowing feathers, "
                          "symmetrical, seen from behind, wings only, no body, no person, glowing light, pixel art"),
    "fx_fluegel_daemon": (128, 96, "a pair of huge spread demonic bat wings, black leathery membrane torn at the edges with glowing "
                          "crimson veins and burning ember edges, sharp bone claws at the tips, symmetrical, wings only, no body, no person, pixel art"),
    "fx_heiligenschein": (48, 48, "a glowing golden halo ring with small rays of light, seen slightly from below, a single thin ring, pixel art"),
    "fx_feder": (32, 32, "a single small glowing white golden feather, pixel art"),
    "fx_altar": (80, 112, "a tall ornate altar pedestal, side view game prop, the left half white marble with golden angel feathers, "
                 "the right half black obsidian with crimson demon horns and glowing red cracks, a large glowing prismatic "
                 "rainbow crystal floating above the top, pixel art, full object fits inside the canvas"),
    "fx_glutfetzen": (32, 32, "a single small burning crimson ember flame wisp with black smoke edge, pixel art"),
}
WSTYLE = ("single weapon only, pixel art game item, side view, lying diagonal, blade or muzzle pointing to the upper right, grip "
          "lower left, bold dark outline, cel shading, clean readable silhouette, original design, no hands, no character, whole "
          "weapon fits inside the canvas")
WEAPONS = {  # name: (w, h, Beschreibung)
    "god_hoellenschlund": (40, 40, "a demonic katana, black blade with a molten crimson glowing edge and lava cracks, black and red "
                           "wrapped hilt, guard shaped like a small horned skull"),
    "god_mondfresser": (48, 48, "a gigantic black cleaver greatsword with a glowing crimson crescent moon shaped cutting edge, "
                        "spikes on the back, chains wrapped around the long hilt"),
    "god_glockenschwinge": (48, 48, "a holy war scythe, long white and gold staff, curved blade made of radiant golden light, a "
                            "small golden bell and white feathers hanging below the blade"),
    "god_engelsruf": (48, 32, "a holy energy rifle, white ceramic and polished gold body, glowing golden light coils along the "
                      "barrel, small angel wing ornaments on both sides, golden halo ring sight, muzzle pointing right, horizontal"),
}
ICON = "RPG inventory item icon, pixel art, centered, single object, bold dark outline, high contrast, no text, no background"
HOLY = "radiant white and polished gold, glowing holy light, divine"
DEMON = "black obsidian and crimson, glowing red lava veins, demonic"
ICONS = {
    "god_sonnenkrone": f"a tall golden sun crown with sharp rays of light, {HOLY}",
    "god_gewand": f"an ornate holy chest armor with a glowing sun emblem and white silk tabard, {HOLY}",
    "god_beinkleid": f"ornate armored leg greaves with white silk, {HOLY}",
    "god_morgenschritte": f"a pair of armored boots with tiny golden wings at the ankles, {HOLY}",
    "god_seraphfluegel": f"a pair of glowing angel wings made of light feathers, {HOLY}",
    "god_hoernerkrone": f"a black iron crown with two huge curved demon horns, {DEMON}",
    "god_hoellenpanzer": f"a jagged spiked demon lord chest armor with a red demonic eye, {DEMON}",
    "god_kettenbeinkleid": f"black leg armor wrapped in iron chains with glowing red runes, {DEMON}",
    "god_aschewandler": f"a pair of heavy black clawed boots with glowing red seams, {DEMON}",
    "god_verdammnisschwingen": f"a pair of torn demonic bat wings with burning ember edges, {DEMON}",
    "god_glockenschwinge": f"a holy war scythe with a blade of golden light and a small bell, {HOLY}",
    "god_engelsruf": f"a holy energy rifle with angel wing ornaments, {HOLY}",
    "god_sonnenfaeuste": f"a pair of golden sun gauntlets with blazing light knuckles, {HOLY}",
    "god_himmelswirbel": f"white and gold fist wraps swirling with a small sky blue whirlwind, {HOLY}",
    "god_hoellenschlund": f"a demonic katana with a horned skull guard, {DEMON}",
    "god_mondfresser": f"a gigantic black cleaver greatsword with a crimson crescent moon edge, {DEMON}",
    "god_hoellenfaust": f"a pair of black demon claw gauntlets engulfed in crimson hellfire, {DEMON}",
    "god_teufelsfeder": f"a coiled black and red demonic spring gauntlet with devil horns on the knuckles, {DEMON}",
}


def log(name, prompt, r):
    d = json.loads(LOG.read_text()) if LOG.exists() else {}
    d[name] = {"prompt": prompt, "usage": r.get("usage") if isinstance(r, dict) else None}
    LOG.write_text(json.dumps(d, indent=1, ensure_ascii=False))


def pixflux(name, w, h, desc, seed=91):
    if (RAW / f"{name}.png").exists():
        return
    p = {"description": desc, "image_size": {"width": w, "height": h}, "outline": "single color black outline",
         "shading": "detailed shading", "detail": "highly detailed", "no_background": True, "text_guidance_scale": 8, "seed": seed}
    r = pl2.post("/create-image-pixflux", p)
    pl2.to_img(r["image"]).save(RAW / f"{name}.png")
    log(name, desc, r)
    print(name, r.get("usage"), flush=True)


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    mode = sys.argv[1]
    before = pl2.balance()
    if mode == "outfits":
        import gen_outfits as go  # Raster-Pipeline der Themen-Kollektionen
        go.OUTFITS.update(OUTFITS)
        go.STYLE = "epic anime boss clothing, clean outlines. Empty hands, no wings"
        with ThreadPoolExecutor(2) as ex:
            list(ex.map(go.grids, sys.argv[2:] or list(OUTFITS)))
    elif mode == "heads":
        for h in sys.argv[2:] or HEADS:
            subprocess.run([sys.executable, str(ROOT / "tools/pixellab/creator_base/hair.py"), h, HEADS[h]], check=True)
    elif mode == "fx":
        jobs = [(n, *FX[n]) for n in (sys.argv[2:] or FX)]
        with ThreadPoolExecutor(2) as ex:
            list(ex.map(lambda j: pixflux(*j), jobs))
    elif mode == "weapons":
        def one(job):
            n, seed = job
            if (RAW / f"{n}_s{seed}.png").exists():
                return
            w, h, desc = WEAPONS[n]
            p = {"description": desc + ", " + WSTYLE, "image_size": {"width": w, "height": h},
                 "outline": "single color black outline", "view": "side", "no_background": True,
                 "detail": "highly detailed", "seed": seed}
            r = pl2.post("/create-image-pixen", p)
            pl2.to_img(r["image"]).save(RAW / f"{n}_s{seed}.png")
            log(f"{n}_s{seed}", p["description"], r)
            print(n, seed, r.get("usage"), flush=True)
        jobs = [(n, s) for n in (sys.argv[2:] or WEAPONS) for s in (13, 29)]
        with ThreadPoolExecutor(2) as ex:
            list(ex.map(one, jobs))
    elif mode == "icons":
        jobs = [(f"icon_{n}", 32, 32, f"{ICONS[n]}, {ICON}") for n in (sys.argv[2:] or ICONS)]
        with ThreadPoolExecutor(2) as ex:
            list(ex.map(lambda j: pixflux(*j), jobs))
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
