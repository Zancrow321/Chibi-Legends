#!/usr/bin/env python3
"""Baut aus den PixelLab-/vfx-Rohdaten Streifen fuer Godot und eine Bloom-Vorschau.

assets/vfx/wirbelwille/<name>.png  : Frames nebeneinander
assets/vfx/wirbelwille/effects.json: Framegroesse, Anzahl, Dauer je Frame, Schleife
Vorschau (nur Ansicht, nicht im Spiel): Pfad als Argument, z. B. /mnt/project-files/.../
    python3 -I tools/wirbelwille/finish.py [vorschau_ordner]
"""
import json, pathlib, sys
from PIL import Image, ImageChops, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
VFX = ROOT / "assets" / "vfx" / "wirbelwille"
RAW = VFX / "raw"


def load(name):
    d = RAW / name
    meta = json.loads((d / "result.json").read_text())
    sheet_json = next(p for p in d.glob("*.json") if p.name != "result.json")
    sj = json.loads(sheet_json.read_text())
    sheet = Image.open(sheet_json.with_suffix(".png")).convert("RGBA")
    frames, durs = [], []
    for f in sj["frames"]:
        r = f["frame"]
        frames.append(sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])))
        durs.append(f.get("duration", 63))
    return frames, durs, bool(meta.get("loop")), meta


def bloom(img, bg=(14, 16, 32)):
    """Additiver Glow wie im Spiel (WorldEnvironment glow): weich + breit ueber das Bild addieren."""
    base = Image.new("RGB", img.size, bg)
    base.paste(img, (0, 0), img)
    lit = Image.new("RGB", img.size, (0, 0, 0))
    lit.paste(img, (0, 0), img)
    out = base
    for rad, k in ((2, 0.9), (6, 0.7), (14, 0.5)):
        g = lit.filter(ImageFilter.GaussianBlur(rad)).point(lambda v, k=k: int(v * k))
        out = ImageChops.add(out, g)
    return out


def main():
    preview = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    index = {}
    names = sorted(p.name for p in RAW.iterdir() if (p / "result.json").exists())
    all_frames = {}
    for n in names:
        frames, durs, loop, meta = load(n)
        w, h = frames[0].size
        strip = Image.new("RGBA", (w * len(frames), h))
        for i, f in enumerate(frames):
            strip.paste(f, (i * w, 0))
        strip.save(VFX / f"{n}.png")
        index[n] = {"texture": f"res://assets/vfx/wirbelwille/{n}.png", "frame_w": w, "frame_h": h,
                    "frames": len(frames), "durations_ms": durs, "loop": loop,
                    "source": "PixelLab /vfx lite, effect " + meta.get("effect_id", "")}
        all_frames[n] = (frames, durs)
        print(n, w, h, len(frames), "loop" if loop else "")
    (VFX / "effects.json").write_text(json.dumps(index, indent=1, ensure_ascii=False))
    if not preview:
        return
    preview.mkdir(parents=True, exist_ok=True)
    # Uebersicht: je Effekt eine Zelle, 3x vergroessert, mit Bloom, als GIF
    S, CELL = 3, 300
    cols = 4
    rows = (len(names) + cols - 1) // cols
    steps = 36
    gif = []
    for t in range(steps):
        canvas = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
        for k, n in enumerate(names):
            frames, _ = all_frames[n]
            f = frames[t % len(frames)]
            f = f.resize((f.width * S, f.height * S), Image.NEAREST)
            if f.width > CELL or f.height > CELL:
                f.thumbnail((CELL, CELL), Image.NEAREST)
            x = (k % cols) * CELL + (CELL - f.width) // 2
            y = (k // cols) * CELL + (CELL - f.height) // 2
            canvas.alpha_composite(f, (x, y))
        gif.append(bloom(canvas))
    gif[0].save(preview / "wirbelwille_effekte.gif", save_all=True, append_images=gif[1:], duration=63, loop=0)
    gif[len(gif) // 2].save(preview / "wirbelwille_effekte.png")
    print("Vorschau:", preview)


if __name__ == "__main__":
    main()
