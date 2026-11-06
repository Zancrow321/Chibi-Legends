#!/usr/bin/env python3
"""Weltenriss im Hof ohne Skizze (die Bogen-Skizze ergab nur Tore). 3 Kandidaten, 1 Generierung je Bild;
gewählt: gate_riss_3 -> raw/gate_riss.png, dann tools/overworld/finish.py. Key nur aus PIXELLAB_API_KEY."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2
out = pathlib.Path(__file__).resolve().parents[2] / "assets" / "overworld" / "raw" / "sideview"
desc = ("a tall jagged vertical tear in reality glowing electric blue, shaped like a lightning crack, crackling white and cyan "
        "lightning arcs around its edges, dark swirling storm clouds visible inside the tear, two broken leaning dark slate stone "
        "pillars on both sides with blue glowing runes, floating rock shards around it, cracked stone slab at the base, "
        "2D side-scroller game prop seen from the front, pixel art game asset, bright saturated colors, cel shading, bold dark outline, "
        "original design, whole object fits inside the canvas")
for i, seed in enumerate((11, 29, 47)):
    r = pl2.post("/create-image-pixflux", {"description": desc, "negative_description": "arch, doorway, door, top-down view, isometric",
        "image_size": {"width": 128, "height": 128}, "outline": "single color black outline", "shading": "medium shading",
        "detail": "highly detailed", "view": "side", "no_background": True, "text_guidance_scale": 8, "seed": seed})
    pl2.to_img(r["image"]).save(out / f"gate_riss_{i + 3}.png")
    print(i, r.get("usage"), flush=True)
