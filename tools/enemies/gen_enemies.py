#!/usr/bin/env python3
"""Erste Gegner mit PixelLab (Key nur aus PIXELLAB_API_KEY).

Schritt 1 (still): je Gegner 2 Kandidaten (pixflux, 1 Generierung je Bild).
Schritt 2 (anim):  gewählter Kandidat -> animate-with-text-v3, 1 Generierung je Animation.
Rohdaten landen in assets/enemies/raw/<gegner>/, finish.py baut daraus die Streifen.

    python3 -I tools/enemies/gen_enemies.py still moosling
    python3 -I tools/enemies/gen_enemies.py anim moosling idle
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "enemies" / "raw"
STYLE = ("pixel art game enemy sprite, side view facing left, full body, bright saturated colors, cel shading with hard edges, "
         "bold dark outline, original design, cute but dangerous, clean readable silhouette, whole body fits inside the canvas with a margin")

ENEMIES = {
    "moosling": (64, "small round forest slime monster made of glowing green moss, a little mushroom cap and two leaves on top, "
                 "big shiny black eyes, tiny angry eyebrows, soft squishy body"),
    "rindenwicht": (64, "small forest goblin imp with bark-like brown wooden skin, leaf hood, glowing yellow eyes, "
                    "holding a big knotted wooden club in both hands, short legs, standing ready to fight"),
}
ACTIONS = {
    "moosling": {
        "idle": (8, "squishy slime idle: body squashes down and stretches up softly in place, eyes blink"),
        "hop": (8, "slime hops forward: squashes down, jumps up and to the left, lands and squashes, in place on the canvas"),
        "attack": (8, "slime winds up by squashing very flat, then lunges forward to the left in a fast body slam and bounces back"),
        "hurt": (4, "slime is hit from the left: flinches back to the right, body squeezes, eyes shut"),
        "death": (8, "slime is defeated: collapses and melts into a flat puddle of moss, then breaks into small leaves"),
    },
    "rindenwicht": {
        "walk": (8, "goblin walks forward to the left in place, small steps, club held ready"),
        "attack": (8, "goblin raises the wooden club high above its head, then smashes it down hard in front of it to the left"),
        "hurt": (4, "goblin is hit from the left: staggers back to the right, head tilts back"),
        "death": (8, "goblin is defeated: falls backwards onto the ground and the club drops"),
    },
}


def still(name: str) -> None:
    size, desc = ENEMIES[name]
    out = RAW / name
    out.mkdir(parents=True, exist_ok=True)
    before = pl2.balance()
    for seed in (101, 202):
        p = {"description": desc + ", " + STYLE, "image_size": {"width": size, "height": size},
             "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
             "view": "side", "direction": "west", "no_background": True, "text_guidance_scale": 8, "seed": seed}
        r = pl2.post("/create-image-pixflux", p)
        pl2.to_img(r["image"]).save(out / f"still_{seed}.png")
        print(name, seed, r.get("usage"), flush=True)
    print("Generierungen:", round(before - pl2.balance(), 2))


def anim(name: str, action: str, seed: int = 0) -> None:
    frames, text = ACTIONS[name][action]
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
        still(sys.argv[2])
    else:
        anim(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 0)
