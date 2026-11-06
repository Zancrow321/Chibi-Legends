#!/usr/bin/env python3
"""Erster Raid-Boss "Essenwächter" und Schild-Kristall mit PixelLab (Key nur aus PIXELLAB_API_KEY).

Schritt 1 (still): Kandidaten (pixflux 128 px, 1 Generierung je Bild).
Schritt 2 (anim):  gewählter Kandidat (raw/<name>/still.png) -> animate-with-text-v3
                   (128x128x8 Bilder = 2 Generierungen je Animation).
Rohdaten landen in assets/raid/raw/<name>/, finish_boss.py baut daraus die Streifen.

    python3 -I tools/raid/gen_boss.py still essenwaechter
    python3 -I tools/raid/gen_boss.py anim essenwaechter slam
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "raid" / "raw"
STYLE = ("pixel art game boss sprite, strict side view facing left, full body, bright saturated colors, cel shading with hard edges, "
         "bold dark outline, original design, imposing and powerful, clean readable silhouette, whole body fits inside the canvas with a margin")

SUBJECTS = {
    "essenwaechter": (128, "huge hulking forge golem guardian made of dark iron plates and riveted armor, glowing molten orange cracks "
                      "in its chest, a small chimney-like head with two burning ember eyes and smoke, massive arms, "
                      "holding a giant blacksmith hammer with a glowing anvil-shaped head, short heavy legs", (11, 22, 33)),
    "donnerhorn": (128, "colossal ancient storm titan beast, hunched gorilla-like body covered in slate grey stone armor plates with "
                   "glowing electric blue rune cracks, a huge bull-like head with two long curved ivory horns crackling with lightning, "
                   "shaggy dark storm-cloud mane on its shoulders, enormous stone fists, glowing cyan eyes", (41, 52, 63)),
    "kristall": (64, "floating magic shield crystal, tall orange-gold gem with glowing core, small iron ring bracket around it, "
                 "sparkles, game object, centered", (5, 6)),
}
ACTIONS = {
    "essenwaechter": {
        "idle": (8, "heavy golem breathing idle: chest glow pulses, shoulders rise and fall slightly, smoke puffs from the head"),
        "walk": (8, "heavy golem stomps forward to the left in place, slow heavy steps, hammer held at its side"),
        "slam": (8, "golem lifts the giant hammer high over its head with both arms, then smashes it down hard onto the ground in front to the left"),
        "swipe": (8, "golem swings the giant hammer in a wide horizontal arc from behind to the front left"),
        "roar": (8, "golem throws its arms wide and roars upward, chest cracks glow brighter, sparks burst from its body"),
        "hurt": (4, "golem is hit from the left: staggers back to the right, head tilts back, arms flail"),
        "death": (8, "golem is defeated: falls to its knees, the glow fades and the iron body collapses forward onto the ground"),
    },
    "donnerhorn": {
        "idle": (8, "giant storm beast breathing idle: shoulders rise and fall, lightning flickers along its horns, mane drifts"),
        "walk": (8, "giant storm beast lumbers forward to the left in place on its knuckles and legs, heavy slow steps"),
        "slam": (8, "storm beast rears up and raises both stone fists high above its head, then smashes them down hard onto the ground in front to the left"),
        "swipe": (8, "storm beast lowers its head and swings its huge horns in a wide sweeping arc to the front left"),
        "roar": (8, "storm beast throws its head back and roars at the sky, lightning bursts from its horns and rune cracks"),
        "hurt": (4, "storm beast is hit from the left: staggers back to the right, head jerks back"),
        "death": (8, "storm beast is defeated: collapses to its knees, the blue glow fades and it falls forward onto the ground"),
    },
    "kristall": {
        "idle": (8, "crystal floats up and down slowly, glow pulses, small sparkles"),
    },
}


def still(name: str) -> None:
    size, desc, seeds = SUBJECTS[name]
    out = RAW / name
    out.mkdir(parents=True, exist_ok=True)
    before = pl2.balance()
    style = STYLE if name != "kristall" else "pixel art game object, side view, bright saturated colors, bold dark outline, original design"
    for seed in seeds:
        p = {"description": desc + ", " + style, "image_size": {"width": size, "height": size},
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
    (out / f"{action}_job.txt").write_text(str(job))
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
