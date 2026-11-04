#!/usr/bin/env python3
"""Generiert die Bollwerk-Waffen mit PixelLab Pixen (1 Generierung pro Bild).
Rohbilder nach assets/creator/weapons/raw/bollwerk/<name>_s<seed>.png.
Key nur aus PIXELLAB_API_KEY. Aufruf:
    python3 tools/bollwerk/gen_weapons.py SEED [name ...]
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "creator" / "weapons" / "raw" / "bollwerk"
STYLE = ("single weapon only, pixel art game item, side view, lying horizontal, muzzle pointing right, "
         "stock or grip on the left, bold dark outline, cel shading with hard edges, clean readable silhouette, "
         "original sci-fi military design, no hands, no character, whole weapon fits inside the canvas")
# name: (Breite, Höhe, Beschreibung)
WEAPONS = {
    "wachhund": (48, 48, "compact futuristic bullpup assault rifle, graphite gray metal body with orange stripe markings, "
                 "boxy magazine in front of the grip, short barrel, small amber holo sight on top"),
    "dreischlag": (48, 48, "long precise burst rifle, gunmetal gray, slim long barrel, small scope on top with amber lens, "
                   "angular stock, orange accent line"),
    "kurzwort": (32, 32, "compact heavy sidearm pistol, dark steel slide with orange grip panels, chunky boxy shape"),
    "fremdklinge": (48, 48, "alien energy blade weapon, short dark violet hilt with hexagon pattern, one straight glowing "
                    "cyan plasma blade with white core pointing right, single blade"),
    "zwillingsrohr": (64, 64, "long slim shoulder rocket launcher seen from the side, exactly two thin tubes stacked on top of each other, long and flat, length four times its height, olive drab and graphite, "
                      "orange warning stripes at the muzzle, chunky grip and sight"),
    "lanzenstrahl": (64, 64, "very long slim energy lance rifle seen from the side, flat profile, length five times its height, graphite body with glowing cyan coils along the barrel, "
                     "glowing cyan lens at the muzzle, shoulder stock"),
    "schrotflinte": (48, 48, "short pump action combat shotgun, graphite gray with orange pump grip, thick barrel, "
                     "sturdy stock"),
}


def main() -> None:
    seed = int(sys.argv[1])
    RAW.mkdir(parents=True, exist_ok=True)
    want = sys.argv[2:] or list(WEAPONS)
    log_path = RAW / "log.json"
    log = json.loads(log_path.read_text()) if log_path.exists() else {}
    before = pl2.balance()
    for name in want:
        w, h, desc = WEAPONS[name]
        p = {"description": desc + ", " + STYLE, "image_size": {"width": w, "height": h},
             "outline": "single color black outline", "view": "side", "no_background": True,
             "detail": "highly detailed", "seed": seed}
        r = pl2.post("/create-image-pixen", p)
        pl2.to_img(r["image"]).save(RAW / f"{name}_s{seed}.png")
        log[f"{name}_s{seed}"] = {"prompt": p["description"], "seed": seed, "usage": r.get("usage")}
        print(name, r.get("usage"), flush=True)
    print("Generierungen verbraucht:", round(before - pl2.balance(), 2))
    log_path.write_text(json.dumps(log, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
