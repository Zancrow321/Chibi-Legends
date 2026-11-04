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

def recolor(img, mapping):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            k = "%02x%02x%02x" % c[:3]
            if c[3] and k in mapping:
                v = mapping[k]
                px[x, y] = (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), 255)
    return img

# Manga-Tusche: Gold/Holz der Balken wird Papierweiss/Grau, Schlitz bleibt Tusche,
# Herz und Flamme behalten ihre Farben (alles Resurrect-64-Toene).
BAR = {k: "ffffff" for k in ("fbb954", "fbff86", "fdcbb0", "fca790", "f9c22b", "cddf6c", "4c3e24", "676633", "753c54", "45293f")}
BAR.update({k: "c7dcd0" for k in ("b2ba90", "ab947a", "966c6c")})
BAR.update({k: "2e222f" for k in ("313638", "374e4a", "9e4539", "6e2727")})
# Button: Papier mit Tuscherand statt Rot, die Hover-Farbe kommt aus dem Code
BTN = {k: "ffffff" for k in ("e83b3b", "f68181", "fca790")}
BTN.update({k: "c7dcd0" for k in ("ae2334", "b33831", "ea4f36")})
BTN.update({k: "9babb2" for k in ("6e2727", "7a3045")})

out = {}
# Panel: Sprechblasen-Spitze unten abschneiden (ab Zeile 90 nur noch Spitze)
p = load("panel").crop((0, 0, 112, 90))
# Innenflaeche glatt machen, das Raster zeichnet der Code in die Ecke (streckt sonst mit)
pp = p.load()
for y in range(18, 90 - 18):
    for x in range(18, 112 - 18):
        if pp[x, y][3]:
            pp[x, y] = (255, 255, 255, 255)
for y in range(90 - 18, 90):
    for x in range(18, 112 - 18):
        if pp[x, y][3] and pp[x, y][:3] in ((199, 220, 208), (49, 54, 56)):
            pp[x, y] = (255, 255, 255, 255)
p.save(D / "panel.png"); out["panel"] = [18, 18, 18, 18]  # links, oben, rechts, unten
# Lebensbalken: Herz links, Slot in der Mitte
recolor(load("hp_bar"), BAR).save(D / "hp_bar.png"); out["hp_bar"] = [24, 6, 10, 6]
# Superbalken: die zwei Trennstriche entfernen (zeichnet der Code je nach Breite neu)
s = load("super_bar"); px = s.load()
for x0, x1 in ((60, 84), (106, 132)):
    for x in range(x0, x1):
        for y in range(s.height):
            px[x, y] = px[50, y]
recolor(s, BAR).save(D / "super_bar.png"); out["super_bar"] = [30, 7, 14, 7]
load("skill_slot").save(D / "skill_slot.png"); out["skill_slot"] = [14, 14, 14, 14]
recolor(load("button"), BTN).save(D / "button.png"); out["button"] = [16, 12, 20, 12]
json.dump(out, open(D / "slices.json", "w"), indent=1)
print(json.dumps(out))
