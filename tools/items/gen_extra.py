#!/usr/bin/env python3
"""PixelLab icons for sockets, sets and legendary mods (pixflux 32x32,
1 generation each, 50 in total):
  - gems:  assets/items/gems/<type>_<1-3>.png   6 types x 3 tiers = 18
  - sets:  assets/items/sets/<set>_<kind>.png   4 sets x 6 kinds  = 24
  - mods:  assets/items/mods/<style>.png        8 fighting styles = 8
Key only from PIXELLAB_API_KEY.

    python3 -I tools/items/gen_extra.py [name ...]     (default: all missing)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "items"
LOG = OUT / "raw" / "log_extra.json"
ICON = "RPG inventory item icon, pixel art, centered, single object, bold dark outline, high contrast, no text, no background"

GEMS = {
    "rubin": "red ruby",
    "smaragd": "green emerald",
    "topas": "yellow topaz",
    "saphir": "blue sapphire",
    "amethyst": "purple amethyst",
    "onyx": "black onyx with a white sheen",
}
TIERS = {
    1: "a small rough uncut {} gem stone, raw crystal chunk",
    2: "a faceted cut {} gem, clean polished facets",
    3: "a large radiant brilliant cut {} gem, glowing sparkles and light rays",
}

SETS = {
    "waldwaechter": "moss green and bark brown, leaf and vine ornaments",
    "glutschmied": "dark iron with glowing orange ember cracks, forge-heated metal",
    "sturmlaeufer": "white and sky blue, feather and wind swirl ornaments",
    "mondschatten": "dark violet and silver, crescent moon ornaments",
}
KINDS = {
    "waffe": "a sword",
    "oberteil": "a chest armor vest",
    "hose": "armored trousers",
    "schuhe": "a pair of boots",
    "accessoire": "a belt with a buckle",
    "talisman": "a pendant amulet",
}

MODS = {
    "glutatem": "a glowing orange fire rune stone with a breath flame swirl",
    "bollwerk": "a steel blue armor rune plate with a shield emblem",
    "gleichklang": "a crimson soul rune stone with a scythe crescent emblem",
    "grenzbrecher": "a golden energy rune orb with a bright fist emblem",
    "lauffeuer": "a red orange flame rune stone with a fist of fire emblem",
    "schwarzmond": "a black and crimson rune stone with a dark moon emblem",
    "spannkraft": "a rubbery tan rune stone with a coiled spring emblem",
    "wirbelwille": "an orange wind rune stone with a spiral swirl emblem",
}


def jobs() -> dict:
    out = {}
    for g, col in GEMS.items():
        for t, form in TIERS.items():
            out[f"gems/{g}_{t}"] = form.format(col)
    for s, look in SETS.items():
        for k, obj in KINDS.items():
            out[f"sets/{s}_{k}"] = f"{obj}, {look}, matching equipment set piece"
    for st, desc in MODS.items():
        out[f"mods/{st}"] = f"{desc}, legendary magic engraving, golden frame"
    return out


def main() -> None:
    for d in ("raw", "gems", "sets", "mods"):
        (OUT / d).mkdir(parents=True, exist_ok=True)
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    all_jobs = jobs()
    want = sys.argv[1:] or [n for n in all_jobs if not (OUT / f"{n}.png").exists()]
    before = pl2.balance()
    for name in want:
        desc = all_jobs[name] + ", " + ICON
        p = {"description": desc, "image_size": {"width": 32, "height": 32},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "no_background": True, "text_guidance_scale": 8, "seed": 83}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(OUT / f"{name}.png")
        log[name] = {"prompt": desc, "seed": 83, "usage": r.get("usage")}
        LOG.write_text(json.dumps(log, indent=1, ensure_ascii=False))
        print(name, r.get("usage"), flush=True)
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
