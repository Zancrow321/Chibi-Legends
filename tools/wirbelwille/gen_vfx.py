#!/usr/bin/env python3
"""Wirbelwille-Effekte mit PixelLab REST /vfx (artist lite, Key nur aus PIXELLAB_API_KEY).

Lite = 1 Generierung je neuem Effekt ohne Sprite (bei Ueberlaenge hoechstens 2).
Rohdaten (GIF, Sheet, JSON) landen in assets/vfx/wirbelwille/raw/<name>/.

    python3 -I tools/wirbelwille/gen_vfx.py list
    python3 -I tools/wirbelwille/gen_vfx.py run kreiselfaust
    python3 -I tools/wirbelwille/gen_vfx.py run all
"""
import json, pathlib, sys, time, urllib.request
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "vfx" / "wirbelwille" / "raw"
STYLE = ("Side view game effect, big and spectacular, thick bright strokes with glowing white cores, high energy anime fighting game look, "
         "crisp readable shapes, transparent background, "
         "no characters, no text, no symbols, no spiral emblem.")

EFFECTS = {
    "kreiselfaust": "Three thin crossing wind rings spinning fast around one point like a gyroscope, pale turquoise and white "
                    "with gold sparks, building up for half a second then spinning very fast, looping.",
    "kreiselfaust_treffer": "Big wind impact burst: the three crossing wind rings snap open into a wide shockwave ring, "
                            "white flash in the center, turquoise wind streaks and gold sparks flying outward, 0.5 seconds.",
    "poff": "Comic smoke puff: a round grey smoke cloud bursts and dissolves in 0.4 seconds, a few small torn paper strips "
            "flutter outward and fall.",
    "windschatten_entstehen": "Summoning burst: tall vertical column of swirling pale blue and white wind streaks spirals inward "
                              "from all sides and gathers into a tall bright oval of light, glowing threads snap tight, then a "
                              "quick flash with a ring of wind lines bursting outward, 0.4 seconds. No figure, no outline of a body.",
    "strohpuppe": "A straw bundle bursts apart into flying straw pieces and a small grey smoke puff, 0.4 seconds.",
    "fadenwehr": "A glowing net of thin turquoise threads spreads open in front like a spider web shield, shimmers, "
                 "then frays away, 0.6 seconds.",
    "wirbelsturz_aufprall": "Ground impact: a heavy downward wind blast hits the floor, a flat white and turquoise "
                            "shockwave spreads to both sides with dust and gold sparks, 0.6 seconds.",
    "windstoss": "Horizontal gust of wind: long curved white and pale blue wind streaks rush to the right, 0.4 seconds.",
    "sturmrad": "A huge spinning pinwheel made of six thin curved blades of wind around a hub of glowing threads, "
                "turquoise white with gold edge glow, spinning fast, looping.",
    "sturmrad_abschluss": "The six wind blades of a giant pinwheel fold inward and then explode outward in a huge "
                          "white turquoise wind burst with gold sparks and a bright flash, 0.8 seconds.",
    "orkanmantel": "Swirling storm aura shaped like a cloak around an empty human sized space, grey turquoise storm "
                   "streams with little gold lightning sparks, wind ribbons fluttering upward, looping.",
    "orkanmantel_ausbruch": "Storm cloak erupts: a massive round wind explosion of grey turquoise storm streams, "
                            "gold lightning and white flash pushing outward, 0.8 seconds.",
}


def fetch(url: str, dest: pathlib.Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as r:
        dest.write_bytes(r.read())


def run(name: str) -> None:
    out = RAW / name
    out.mkdir(parents=True, exist_ok=True)
    for attempt in range(5):
        try:
            r = pl2.post("/vfx", {"description": EFFECTS[name] + " " + STYLE, "artist": "lite", "game_pack": True})
            break
        except RuntimeError as e:
            if "503" not in str(e):
                raise
            time.sleep(5)
    print(name, "Angebot:", r.get("quoted_generations"), flush=True)
    j = pl2.wait_job(r["background_job_id"], every=5, limit=600)
    if j.get("status") != "completed":
        raise SystemExit(json.dumps(j)[:800])
    res = j.get("last_response") or {}
    (out / "result.json").write_text(json.dumps({k: v for k, v in res.items() if k != "conversation"}, indent=1))
    files = res.get("files") or {}
    items = files.items() if isinstance(files, dict) else enumerate(files)
    for k, f in items:
        url = f if isinstance(f, str) else (f.get("url") or f.get("href"))
        if not url:
            continue
        fname = url.split("?")[0].rsplit("/", 1)[-1] or str(k)
        fetch(url, out / fname)
    print(name, "fertig, Generierungen:", (res.get("billing_usage") or {}).get("generations"), flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "list":
        print("\n".join(EFFECTS))
    else:
        for n in (EFFECTS if sys.argv[2] == "all" else sys.argv[2:]):
            if not (RAW / n / "result.json").exists():
                run(n)
