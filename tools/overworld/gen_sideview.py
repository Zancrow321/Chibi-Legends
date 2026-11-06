#!/usr/bin/env python3
"""Re-generates the overworld props that came out in top-down / three-quarter
view, now pinned to a straight side view: the flat elevation sketches from
sideview_sketch.py go in as init_image. 3 candidates per prop (1 generation
each) land in assets/overworld/raw/sideview/<name>_<n>.png; the chosen one is
copied to assets/overworld/raw/<name>.png and finish.py cleans it.
Key only from PIXELLAB_API_KEY.
    python3 tools/overworld/gen_sideview.py [name ...]
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "overworld" / "raw"
SKETCH = RAW / "sketch"
OUT = RAW / "sideview"
VIEW = ("2D side-scroller platformer background prop, flat side view elevation seen straight from the front at eye level, "
        "orthographic, no top surfaces visible, no perspective, horizontal bottom edge standing on the ground line")
STYLE = ("pixel art game asset, bright saturated colors, cel shading with hard edges, bold dark outline, "
         "original fantasy magic academy design, clean readable silhouette, whole object fits inside the canvas")

PROPS = {
    "fountain": "white marble two tier fountain seen from the side, lower basin as a straight carved stone wall, "
                "thin strip of blue water at the rim, central stem holding a smaller bowl, water falling down in two thin "
                "streams, a small golden star ornament on top",
    "forge_stall": "small blacksmith market stall seen from the front, red cloth awning with scalloped edge on two wooden posts, "
                   "dark wooden back wall with swords and a hammer hanging, stone forge with glowing orange coals in its mouth, "
                   "iron anvil on a wooden stump in front",
    "gate_wald": "tall pale stone archway gate of a magic academy, carved pillars with green moss and small vines, "
                 "glowing teal rune portal filling the arch, two stone steps at the base seen from the front, small golden star on the keystone",
    "gate_glut": "tall dark basalt archway gate, sealed with heavy crossed iron chains and a big glowing orange padlock seal, "
                 "orange glowing cracks and embers, hot forge theme, two stone steps at the base seen from the front",
    "shrine": "small elegant star shrine seen from the front, white stone walls with a dark blue doorway holding a floating glowing "
              "blue star crystal, dark blue tiled roof with upturned golden eaves, two small blue lanterns on posts at both sides, "
              "stone plinth steps",
}
# (seed, init_image_strength): low keeps only the layout, high keeps the sketch closer
RUNS = [(7, 40), (21, 60), (33, 85)]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or list(PROPS)
    log_path = OUT / "log.json"
    log = json.loads(log_path.read_text()) if log_path.exists() else {}
    before = pl2.balance()
    for name in want:
        init = pl2.b64(__import__("PIL.Image").Image.open(SKETCH / f"{name}.png").convert("RGBA"))
        for i, (seed, strength) in enumerate(RUNS):
            p = {"description": PROPS[name] + ", " + VIEW + ", " + STYLE,
                 "negative_description": "top-down view, isometric, bird's eye view, three-quarter view, ellipse, visible floor",
                 "image_size": {"width": 128, "height": 128},
                 "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
                 "view": "side", "no_background": True, "text_guidance_scale": 8, "seed": seed,
                 "init_image": init, "init_image_strength": strength}
            r = pl2.post("/create-image-pixflux", p)
            pl2.to_img(r["image"]).save(OUT / f"{name}_{i}.png")
            log[f"{name}_{i}"] = {"prompt": p["description"], "seed": seed, "init_image_strength": strength,
                                  "init_image": f"raw/sketch/{name}.png", "usage": r.get("usage")}
            print(name, i, r.get("usage"), flush=True)
    print("Generierungen verbraucht:", round(before - pl2.balance(), 2))
    log_path.write_text(json.dumps(log, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
