#!/usr/bin/env python3
"""Trainingspuppen mit PixelLab (Key nur aus PIXELLAB_API_KEY).

Schritt 1 (still): je Puppe Kandidaten (pixflux, 1 Generierung je Bild).
Schritt 2 (anim):  gewählter Kandidat -> animate-with-text-v3 (bis 7 Bilder = 1 Generierung).
Rohdaten landen in assets/dummies/raw/<puppe>/, finish.py baut daraus die Streifen.

    python3 -I tools/dummies/gen_dummies.py still klein 101 202
    python3 -I tools/dummies/gen_dummies.py anim klein hit
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "dummies" / "raw"
STYLE = ("pixel art game sprite, side view, full body, standing upright, cel shading with hard edges, bold dark outline, "
         "original design, clean readable silhouette, warm dusk lighting from the left, whole object fits inside the canvas "
         "with a small margin, bottom of the wooden post touches the bottom of the canvas")

DUMMIES = {
    "klein": (64, "wooden martial arts training dummy: a burlap straw sack body tied with rope onto a thick wooden post, "
              "round burlap head with a stitched x-eye face and straw sticking out, two short wooden arm pegs, "
              "a red and white target painted on the chest, small wooden cross foot stand"),
    "gross": (96, "big heavy training dummy: a large iron-plated sandbag body bound with chains on a thick dark wooden post, "
              "riveted steel helmet head with a glowing slit visor, broad wooden arm beam with leather pads, "
              "a large red and white target painted on the chest plate, heavy stone base"),
}
ACTIONS = {
    "hit": (6, "training dummy is hit hard from the left: it tilts back to the right on its springy post, "
               "wobbles back to the left, then settles upright again; the post foot stays fixed in place"),
}


def still(name: str, seeds: list[int]) -> None:
    size, desc = DUMMIES[name]
    out = RAW / name
    out.mkdir(parents=True, exist_ok=True)
    before = pl2.balance()
    for seed in seeds:
        p = {"description": desc + ", " + STYLE, "image_size": {"width": size, "height": size},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "view": "side", "direction": "east", "no_background": True, "text_guidance_scale": 8, "seed": seed}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(out / f"still_{seed}.png")
        print(name, seed, flush=True)
    print("Generierungen:", round(before - pl2.balance(), 2))


def anim(name: str, action: str, seed: int = 0) -> None:
    frames, text = ACTIONS[action]
    out = RAW / name
    first = Image.open(out / "still.png").convert("RGBA")
    before = pl2.balance()
    r = pl2.post("/animate-with-text-v3", {"first_frame": pl2.b64(first), "action": text,
                                          "frame_count": frames, "seed": seed, "no_background": True})
    job = r.get("background_job_id") or r.get("job_id")
    j = pl2.wait_job(job) if job else r
    if j.get("status") == "failed":
        raise SystemExit(json.dumps(j)[:800])
    res = j.get("last_response") or j.get("result") or j
    imgs = res.get("images") or res.get("frames") or []
    for i, im in enumerate(imgs):
        pl2.to_img(im).save(out / f"{action}_{i}.png")
    print(name, action, len(imgs), "Bilder, Generierungen:", round(before - pl2.balance(), 2), flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "still":
        still(sys.argv[2], [int(s) for s in sys.argv[3:]] or [101, 202])
    else:
        anim(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 0)
