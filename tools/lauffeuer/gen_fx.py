"""Lauffeuer-Effekte mit PixelLab REST /vfx (artist lite, ca. 1 Generierung je Effekt).

Aufruf: python3 tools/lauffeuer/gen_fx.py <name> [<name> ...]
Ergebnis: build/lauffeuer_fx/<name>/ (Rohdateien) und Log in build/lauffeuer_fx/log.json.
Key nur aus PIXELLAB_API_KEY.
"""
from __future__ import annotations
import json, os, sys, time, urllib.request
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "jus_style"))
import pl2

STYLE = ("Side view 2D fighting game effect, transparent background, soft flowing hand-drawn flames, "
         "bright white-yellow core, orange and gold body, deep ember-red edges, rising ash flakes. "
         "No characters, no text, no blue.")

FX = {
    "flammenfaust": "A giant punching fist shaped from fire, clearly readable as a clenched hand with four knuckles and thumb, "
                    "facing right and flying right, growing from small to big, long flame tail streaming behind the wrist, "
                    "ends in a bright burst. 10 frames, 96x64.",
    "ausbruch": "A column of fire erupts upward from a small spot on the ground, tall and narrow, flares bright white at peak, "
                "then breaks into embers and smoke. 10 frames, 64x96.",
    "brandherd": "Small low campfire-like patch of flickering flame on the ground, calm looping flicker with a few rising sparks, "
                 "seamless loop. 8 frames, 48x32.",
    "steigflamme": "A tall spiraling pillar of flame bursts up out of the ground, twisting like a fire tornado, "
                   "fills the whole height of the frame at its peak, sparks fly up, then it thins out and fades. 10 frames, 64x96.",
    "feuerstrom": "A horizontal stream of rushing fire moving right, like a comet-shaped body of flame with a long tapering trail, "
                  "looping. 8 frames, 96x48.",
    "feuerschirm": "A short vertical wall of fire flares up, holds and flickers, then collapses into embers. 10 frames, 48x96.",
    "brandgestirn": "A giant ball of fire with a dark cracked crust and a blazing white core, surface churning with flame, "
                    "small solar prominences curling off it, looping. 8 frames, 128x128.",
    "einschlag": "A massive fire explosion impact on the ground: white flash, expanding orange fireball dome, "
                 "shockwave ring along the ground, then rising smoke and falling ash. 12 frames, 128x96.",
    "zunderflocke": "A tiny glowing white-gold ember flake floating and slowly turning like ash in an updraft, pulsing glow, "
                    "seamless loop. 8 frames, 24x24.",
}

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "build", "lauffeuer_fx")

def run(name: str) -> dict:
    d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
    desc = FX[name] + " " + STYLE
    r = pl2.post("/vfx", {"description": desc, "artist": "lite", "game_pack": True})
    print(name, "quote", r.get("quoted_generations"), flush=True)
    j = pl2.wait_job(r["background_job_id"])
    if j.get("status") != "completed":
        raise RuntimeError(f"{name}: {json.dumps(j)[:500]}")
    lr = j.get("last_response", j)
    json.dump(lr, open(os.path.join(d, "response.json"), "w"), indent=1)
    files = lr.get("files") or {}
    items = files.items() if isinstance(files, dict) else enumerate(files)
    for k, v in items:
        url = v if isinstance(v, str) else (v.get("url") or v.get("href"))
        if not url:
            continue
        fn = os.path.basename(url.split("?")[0]) or f"{k}"
        urllib.request.urlretrieve(url, os.path.join(d, f"{k}_{fn}"))
    return {"name": name, "quote": r.get("quoted_generations"), "usage": j.get("usage") or lr.get("usage")}

if __name__ == "__main__":
    log_p = os.path.join(OUT, "log.json"); os.makedirs(OUT, exist_ok=True)
    log = json.load(open(log_p)) if os.path.exists(log_p) else []
    for n in sys.argv[1:]:
        before = pl2.balance()
        e = run(n); e["balance_delta"] = round(before - pl2.balance(), 2)
        print(e, flush=True); log.append(e)
        json.dump(log, open(log_p, "w"), indent=1)
