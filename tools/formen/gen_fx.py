#!/usr/bin/env python3
"""PixelLab-Bilder für die Baukasten-Kampfstile (Key nur aus PIXELLAB_API_KEY).

Je Stil 19 Generierungen (pixflux, 1 Generierung je Bild):
  - 9 Effekt-Sprites 128x128 transparent (6 Züge + 3 Meisterzug-Varianten)
    -> assets/combat/vfx/<stil>/<id>.png  (additiv mit Bloom gezeichnet)
  - 10 Skill-Icons 48x48 (6 Züge, Meisterzug, 3 Varianten), auf Resurrect 64
    gesnappt -> assets/combat/icons/<stil>/<id>.png
Waffen: 64x64 transparent, waagrecht, zugeschnitten, Griff/Spitze gemessen
    -> assets/creator/weapons/formen/<id>.png + anchors.json

    python3 -I tools/formen/gen_fx.py stil1 stil2 ...   # fehlende Bilder dieser Stile
    python3 -I tools/formen/gen_fx.py --weapons         # fehlende Waffen
Ein Lauf bricht ab, wenn er 100 oder mehr Bilder erzeugen würde.
"""
import json, pathlib, subprocess, sys, threading
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
P = json.loads((ROOT / "assets/combat/formen/prompts.json").read_text(encoding="utf-8"))
FX_STYLE = ("game visual effect sprite, anime fighting game skill effect, glowing, vivid bright colors, "
            "thick bold shapes, strong contrast, transparent background, no character, no person, no text, no letters")
ICON_BASE = ("game skill icon, square composition filling the whole canvas, centered subject, bold dark outline, "
             "high contrast, clean readable shapes, no text, no letters, no frame")
WEAPON_STYLE = ("single weapon item sprite, side view, lying perfectly horizontal, handle on the left, tip pointing to the right, "
                "pixel art, clean outline, transparent background, no hand, no person, no text")
LOCK = threading.Lock()
USED = [0.0]


def snap(path):
    subprocess.run([sys.executable, "-I", str(ROOT / "tools/palette/quantize.py"), str(path), "--inplace",
                    "--max-colors", "24"], check=True, stdout=subprocess.DEVNULL)


def _gen(desc, w, h, nobg, outline, seed):
    p = {"description": desc, "image_size": {"width": w, "height": h}, "outline": outline,
         "shading": "medium shading", "detail": "medium detail", "no_background": nobg,
         "text_guidance_scale": 8, "seed": seed}
    for attempt in range(3):
        try:
            r = pl2.post("/create-image-pixflux", p)
            with LOCK:
                USED[0] += float((r.get("usage") or {}).get("generations", 1) or 1)
            return pl2.to_img(r["image"])
        except Exception as e:  # noqa: BLE001
            if attempt == 2:
                raise
            print("retry", e, flush=True)


def job_fx(style, fid, desc, look):
    out = ROOT / "assets/combat/vfx" / style / (fid + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    img = _gen(desc + ", colors: " + look.split(",", 1)[-1].strip() + ", " + FX_STYLE, 128, 128, True, "lineless", 41)
    img.save(out)
    print("fx", style, fid, flush=True)


def job_icon(style, iid, desc, look):
    out = ROOT / "assets/combat/icons" / style / (iid + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    img = _gen("%s, %s, %s" % (desc, look, ICON_BASE), 48, 48, False, "single color black outline", 31)
    img.save(out)
    snap(out)
    print("icon", style, iid, flush=True)


def job_weapon(wid, desc):
    out = ROOT / "assets/creator/weapons/formen" / (wid + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    img = _gen(desc + ", " + WEAPON_STYLE, 64, 64, True, "single color black outline", 23)
    img.save(out.with_suffix(".roh.png"))
    print("weapon", wid, flush=True)


def jobs_for(style):
    s = P["styles"][style]
    look = s["look"]
    out = []
    for fid, desc in list(s["fx"].items()) + list(s["super"].items()):
        if not (ROOT / "assets/combat/vfx" / style / (fid + ".png")).exists():
            out.append((job_fx, (style, fid, desc, look)))
    icons = dict(s["fx"])
    icons["meisterzug"] = "a dramatic emblem of the ultimate technique: " + list(s["super"].values())[0]
    icons.update(s["super"])
    for iid, desc in icons.items():
        if not (ROOT / "assets/combat/icons" / style / (iid + ".png")).exists():
            out.append((job_icon, (style, iid, desc, look)))
    return out


def main():
    args = sys.argv[1:]
    todo = []
    if args == ["--weapons"]:
        for wid, desc in P["weapons"].items():
            if not (ROOT / "assets/creator/weapons/formen" / (wid + ".roh.png")).exists():
                todo.append((job_weapon, (wid, desc)))
    else:
        for st in args:
            todo += jobs_for(st)
    if len(todo) >= 100:
        sys.exit("%d Bilder in einem Lauf: über der Freigabegrenze (100), bitte aufteilen" % len(todo))
    print("Bilder:", len(todo), flush=True)
    before = pl2.balance()
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = [ex.submit(f, *a) for f, a in todo]
        errs = 0
        for fu in futs:
            try:
                fu.result()
            except Exception as e:  # noqa: BLE001
                errs += 1
                print("FEHLER", e, flush=True)
    print("Generierungen (Kontostand):", round(before - pl2.balance(), 2), "Fehler:", errs)


if __name__ == "__main__":
    main()
