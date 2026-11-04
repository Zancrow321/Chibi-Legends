#!/usr/bin/env python3
"""Übernimmt einzelne Gegner aus dem Godot-Asset "Duelyst Animated Sprites"
(Asset-Library 1653, github.com/Jordyfel/duelyst-animated-sprites-godot,
Grafiken aus Open Duelyst, Lizenz CC0 1.0) in unser Streifen-Format.

Das ganze Addon ist 123 MB groß (über 600 Figuren); fürs Web-Spiel kopieren
wir nur die Figuren, die wir brauchen. Pro Animation entsteht ein Streifen
assets/enemies/<id>/<anim>.png (Zellen wie im Original, 80x80 oder 100x100);
frames.json bekommt Zellgröße, Fußlinie und Bilder pro Sekunde.

    git clone --depth 1 https://github.com/Jordyfel/duelyst-animated-sprites-godot /tmp/duelyst
    python3 -I tools/enemies/import_duelyst.py /tmp/duelyst/addons/duelyst_animated_sprites
"""
import json, pathlib, re, sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "enemies"

## unsere ID -> Duelyst-Figur
UNITS = {
    "moosgolem": "neutral_golemnature",
    "sumpfdorn": "neutral_beastswamp",
    "saebeltiger": "neutral_beastsaberspinetiger",
    "glutigel": "neutral_gro",
}
ANIMS = {"idle": "idle", "walk": "run", "attack": "attack", "hurt": "hit", "death": "death"}


def parse(base: pathlib.Path, name: str) -> dict:
    t = (base / "spriteframes/units" / f"{name}.tres").read_text()
    regions = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("[^"]+"\)\s*region = Rect2\(([^)]*)\)', t):
        regions[m.group(1)] = tuple(int(float(v)) for v in m.group(2).split(","))
    anims = {}
    body = t[t.index("animations = ["):]
    for b in re.finditer(r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"(\w+)",\s*"speed": ([\d.]+)', body, re.S):
        ids = re.findall(r'SubResource\("([^"]+)"\)', b.group(1))
        anims[b.group(3)] = {"fps": float(b.group(4)), "frames": [regions[i] for i in ids]}
    return anims


def main() -> None:
    base = pathlib.Path(sys.argv[1])
    meta_path = OUT / "frames.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    for our, unit in UNITS.items():
        anims = parse(base, unit)
        sheet = Image.open(base / "spritesheets/units" / f"{unit}.png").convert("RGBA")
        (OUT / our).mkdir(parents=True, exist_ok=True)
        info = {"source": "duelyst:" + unit, "anims": {}}
        foot = 0
        for ours, theirs in ANIMS.items():
            fr = anims[theirs]["frames"]
            w, h = fr[0][2], fr[0][3]
            strip = Image.new("RGBA", (w * len(fr), h))
            for i, (x, y, fw, fh) in enumerate(fr):
                cell = sheet.crop((x, y, x + fw, y + fh))
                strip.alpha_composite(cell, (i * w, 0))
                if ours == "idle":
                    bb = cell.getbbox()
                    if bb:
                        foot = max(foot, bb[3])
            strip.save(OUT / our / f"{ours}.png")
            info["anims"][ours] = [len(fr), anims[theirs]["fps"]]
            info["cell"] = [w, h]
        info["foot"] = foot
        meta[our] = info
        print(our, info)
    meta_path.write_text(json.dumps(meta, indent=1))


if __name__ == "__main__":
    main()
