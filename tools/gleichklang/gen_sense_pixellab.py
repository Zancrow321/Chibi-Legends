"""Sense Nachhall mit PixelLab (pixflux 40x40, 1 Generierung je Seed).

Startbild ist die Skizze aus gen_sense.py (assets/creator/weapons/sense_nachhall_skizze.png),
damit Haltung, Griff und Klangloch an derselben Stelle bleiben. Gewählt wurde
Seed 44 mit init_image_strength 120 (2026-11-04, 4 Generierungen für 4 Kandidaten).
Key nur aus PIXELLAB_API_KEY.

    python3 -I tools/gleichklang/gen_sense_pixellab.py <ausgabe-ordner> 44 120
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2
from PIL import Image
out = pathlib.Path(sys.argv[1]); seeds = [int(x) for x in sys.argv[2].split(",")]; strength = int(sys.argv[3])
init = Image.open(pathlib.Path(__file__).resolve().parents[2] / "assets/creator/weapons/sense_nachhall_skizze.png").convert("RGBA")
desc = ("a scythe weapon item sprite, long dark brown wooden shaft with three bronze bands running diagonally from the lower left corner "
        "to the upper right, at the top end a round bronze ring socket with a small glowing pale blue hole in its centre, "
        "from the socket a long curved blade of matte dark bell bronze metal sweeps to the upper left and hooks down at the tip, "
        "sharp pale blue-white edge on the inner curve, fine grooves on the blade like the rim of a bell, dark outline, "
        "side view, no character, no hands")
before = pl2.balance()
for s in seeds:
    p = {"description": desc, "image_size": {"width": 40, "height": 40}, "no_background": True,
         "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
         "text_guidance_scale": 8, "seed": s, "init_image": pl2.b64(init), "init_image_strength": strength}
    r = pl2.post("/create-image-pixflux", p)
    pl2.to_img(r["image"]).save(out / f"sense_{strength}_{s}.png")
    print(s, r.get("usage"), flush=True)
print("Generierungen:", round(before - pl2.balance(), 2))
