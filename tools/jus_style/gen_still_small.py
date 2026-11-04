"""Testfigur nach Referenz-Messwerten: 64x64-Leinwand, Figur ca. 28x56 stehend."""
import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import pl2
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
DESC = ("tiny chibi anime boy swordsman sprite, slim small body, big head with large spiky orange-red hair, "
        "white headband, short navy blue jacket, red scarf, black pants, brown boots, katana held low in his right hand, "
        "standing fighting stance, flat cel shading with few colors, black outline, side view facing right, "
        "full body, whole body fits inside the canvas with a small margin")
before = pl2.balance(); log = []
for model, seed in (("pixflux", 22), ("pixflux", 7), ("pixen", 13), ("pixen", 8)):
    p = {"description": DESC, "image_size": {"width": 64, "height": 64}, "outline": "single color black outline",
         "view": "side", "direction": "east", "no_background": True, "seed": seed}
    if model == "pixflux":
        p.update(shading="basic shading", detail="medium detail"); r = pl2.post("/create-image-pixflux", p)
    else:
        p.update(detail="medium detail"); r = pl2.post("/create-image-pixen", p)
    name = f"klein_{model}_{seed}.png"; pl2.to_img(r["image"]).save(OUT / name); log.append(name); print(name, flush=True)
print("verbraucht", before - pl2.balance())
