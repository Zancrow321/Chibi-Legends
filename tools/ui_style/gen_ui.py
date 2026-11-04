"""Stilprobe Manga-Panel-UI: 5 Teile mit PixelLab Pixen (je 1 Generierung).

    python3 tools/ui_style/gen_ui.py <ausgabeordner>

Key nur aus PIXELLAB_API_KEY. Schreibt roh_<name>.png und log.json.
"""
import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "jus_style"))
import pl2

OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
STYLE = ("manga comic panel style game UI element, thick black ink border, white and cream paper fill, "
         "screentone halftone dot shading, slanted dynamic corners, flat colors, crisp pixel art, "
         "front view, centered, no text, no letters, plain empty background")
PARTS = [
    ("panel", 128, 128, "empty rectangular manga speech-panel window frame with slanted cut corners, "
                        "halftone dots in the lower corner, red accent stripe at the top"),
    ("button", 128, 64, "wide rectangular game menu button, slanted parallelogram shape, black ink border, "
                        "red fill with white highlight stripe and halftone dots"),
    ("hp_bar", 192, 48, "long horizontal health bar frame, slanted ends, black ink border, "
                        "empty dark inner slot, small heart emblem on the left end"),
    ("super_bar", 192, 48, "long horizontal energy gauge frame split into three segments, slanted ends, "
                           "black ink border, empty dark inner slots, small flame emblem on the left end"),
    ("skill_slot", 64, 64, "square ability slot frame tilted like a manga panel, thick black ink border, "
                           "empty dark center, halftone dots in one corner"),
]
log = []; before = pl2.balance()
for name, w, h, desc in PARTS:
    p = {"description": f"{desc}, {STYLE}", "image_size": {"width": w, "height": h},
         "outline": "single color black outline", "detail": "medium detail",
         "no_background": True, "seed": 7}
    r = pl2.post("/create-image-pixen", p)
    img = pl2.to_img(r["image"]); img.save(OUT / f"roh_{name}.png")
    log.append({"part": name, "size": [w, h], "usage": r.get("usage"), "description": p["description"]})
    print(name, r.get("usage"), flush=True)
after = pl2.balance()
print("Generierungen verbraucht:", before - after)
json.dump({"runs": log, "spent": before - after}, open(OUT / "log.json", "w"), indent=1)
