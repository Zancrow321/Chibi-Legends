#!/usr/bin/env python3
"""Skill-Effekte für den Kampfstil Schwarzmond mit PixelLab (REST POST /vfx,
artist lite, ohne Sprite: 1 Generierung je Effekt, höchstens 2x bei Überlauf).
Key nur aus PIXELLAB_API_KEY. Ergebnis je Effekt in assets/vfx/schwarzmond/<id>/
(sheet.png, sheet.json, effect.gif, response.json). Jede Antwort wird sofort
gespeichert; ein Effekt mit vorhandenem response.json wird nicht neu bestellt.

    python3 -I tools/schwarzmond/gen_vfx.py [id ...]
"""
import json, pathlib, sys, time, urllib.request
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "vfx" / "schwarzmond"
LOOK = ("anime fighting game special effect, side view, transparent background, bold readable shapes, "
        "jet black ink-like energy with a sharp glowing cold white and cyan rim, flame-like flickering edges, "
        "strong glow, high contrast, no characters, no text")
EFFECTS = {
    "mondsichel": "a black crescent moon shaped energy wave flying horizontally to the right, curved blade of dark energy "
                  "with glowing cyan white rim and black flame wisps trailing behind, 0.6 seconds loop",
    "mondsichel_treffer": "impact burst of a black crescent energy wave hitting: black ink splash with white cyan cracks and "
                          "sharp shards flying outward, 0.4 seconds one shot",
    "mondschnitt": "a wide horizontal sword slash arc of black energy with a bright white cyan edge, fast crescent smear, "
                   "0.3 seconds one shot",
    "aufsteigender_mond": "an upward rising crescent sword slash of black energy with white cyan rim sweeping from bottom to top, "
                          "0.35 seconds one shot",
    "fallender_mond": "ground impact shockwave of black energy spreading left and right along the floor, white cyan rim, "
                      "black ink debris thrown up, 0.5 seconds one shot",
    "schwarze_spur": "a horizontal dash streak of black afterimage smoke with thin white speed lines, 0.35 seconds one shot",
    "konter": "a sharp parry flash: white star burst with a black crescent sword arc around it and cyan sparks, "
              "0.3 seconds one shot",
    "schattenlarve": "a menacing aura of black ink smoke rising like flames with dark crimson red embers, loop 0.8 seconds",
    "blutmond": "a huge black crescent moon energy wave with a glowing blood red rim and black flames, very large and heavy, "
                "flying horizontally, 0.8 seconds loop",
    "mondfinsternis": "a total eclipse: black disc with a blazing white corona ring and thin cyan rays, then a single giant "
                      "horizontal white cut line slices across, 1.0 seconds one shot",
}


def _download(url: str, dest: pathlib.Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as r:
        dest.write_bytes(r.read())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or list(EFFECTS)
    used = 0
    for name in want:
        d = OUT / name
        d.mkdir(exist_ok=True)
        if (d / "response.json").exists():
            print("schon da:", name)
            continue
        desc = EFFECTS[name] + ", " + LOOK
        while True:
            try:
                sub = pl2.post("/vfx", {"description": desc, "artist": "lite"})
                break
            except RuntimeError as e:
                if "HTTP 503" in str(e):
                    time.sleep(5)
                    continue
                raise
        (d / "submit.json").write_text(json.dumps(sub, indent=1))
        job = sub.get("background_job_id")
        print(name, "angenommen, Angebot:", sub.get("quoted_generations"), "Job", job)
        res = pl2.wait_job(job, every=5, limit=900)
        (d / "response.json").write_text(json.dumps(res, indent=1))
        if res.get("status") != "completed":
            print(name, "FEHLGESCHLAGEN", json.dumps(res)[:400])
            continue
        lr = res.get("last_response", {})
        usage = lr.get("usage") or res.get("usage") or lr.get("billing_usage") or {}
        used += int(usage.get("generations", sub.get("quoted_generations", 1)) or 0)
        files = lr.get("files", {})
        items = files.items() if isinstance(files, dict) else enumerate(files)
        for key, f in items:
            url = f.get("url") if isinstance(f, dict) else f
            if not isinstance(url, str) or not url.startswith("http"):
                continue
            ext = url.split("?")[0].rsplit(".", 1)[-1][:5]
            _download(url, d / f"{key}.{ext}")
        print(name, "fertig:", sorted(p.name for p in d.iterdir()))
    print("Generierungen (laut Antworten):", used)


if __name__ == "__main__":
    main()
