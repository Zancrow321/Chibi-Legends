"""Schneidet die quantisierten PixelLab-Teile (assets/ui/manga/roh_*.png) zu fertigen
9-Slice-Texturen (assets/ui/manga/*.png). Die Raender stehen in assets/ui/manga/slices.json
und werden von scripts/ui/ui_skin.gd gelesen.

    python3 tools/ui_style/build.py
"""
import json, pathlib
from PIL import Image

D = pathlib.Path(__file__).parents[2] / "assets/ui/manga"

def load(n):
    i = Image.open(D / f"roh_{n}.png").convert("RGBA")
    return i.crop(i.getbbox())

out = {}
# Panel: Sprechblasen-Spitze unten abschneiden (ab Zeile 90 nur noch Spitze)
p = load("panel").crop((0, 0, 112, 90))
p.save(D / "panel.png"); out["panel"] = [18, 18, 18, 18]  # links, oben, rechts, unten
# Lebensbalken: Herz links, Slot in der Mitte
load("hp_bar").save(D / "hp_bar.png"); out["hp_bar"] = [24, 6, 10, 6]
# Superbalken: die zwei Trennstriche entfernen (zeichnet der Code je nach Breite neu)
s = load("super_bar"); px = s.load()
for x0, x1 in ((60, 84), (106, 132)):
    for x in range(x0, x1):
        for y in range(s.height):
            px[x, y] = px[50, y]
s.save(D / "super_bar.png"); out["super_bar"] = [30, 7, 14, 7]
load("skill_slot").save(D / "skill_slot.png"); out["skill_slot"] = [14, 14, 14, 14]
load("button").save(D / "button.png"); out["button"] = [16, 12, 20, 12]
json.dump(out, open(D / "slices.json", "w"), indent=1)
print(json.dumps(out))
