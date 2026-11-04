"""Erzeugt Kandidaten fuer die Testfigur im neuen Stil (96x96 Zelle, Figur ca. 48x64)."""
import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import pl2

OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
DESC = ("chibi anime boy swordsman, 2.5 heads tall, big head with large expressive anime eyes, "
        "spiky orange-red hair, white headband, short navy blue jacket, long red scarf, black pants, "
        "brown boots, katana held in his right hand, confident fighting stance, bright saturated colors, "
        "cel shading, bold dark outline, side view facing right, full body, whole body fits inside the canvas with a small margin")
log = []
before = pl2.balance()
jobs = [("pixflux", s) for s in (11, 22, 33)] + [("pixen", s) for s in (44, 55)]
for model, seed in jobs:
    p = {"description": DESC, "image_size": {"width": 96, "height": 96}, "outline": "single color black outline",
         "view": "side", "direction": "east", "no_background": True, "seed": seed}
    if model == "pixflux":
        p.update(shading="medium shading", detail="highly detailed", text_guidance_scale=8)
        r = pl2.post("/create-image-pixflux", p)
    else:
        p.update(detail="highly detailed")
        r = pl2.post("/create-image-pixen", p)
    img = pl2.to_img(r["image"])
    name = f"kandidat_{model}_{seed}.png"; img.save(OUT / name)
    log.append({"file": name, "usage": r.get("usage")}); print(name, r.get("usage"), flush=True)
after = pl2.balance()
print("Generierungen verbraucht:", before - after)
json.dump({"desc": DESC, "runs": log, "spent": before - after}, open(OUT / "log.json", "w"), indent=1)
