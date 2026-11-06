"""Anime- und japanische Kleidung für den Character Creator (PixelLab, eigene Entwürfe).

Ein Outfit über alle 68 Posen = 5 Raster = 5 Generierungen, ein Kopfteil = 1 Generierung.

  python3 tools/japan_outfits/gen_outfits.py draft             # nur Raster 1 aller Outfits
  python3 tools/japan_outfits/gen_outfits.py outfit <id> ...   # restliche Raster
  python3 tools/japan_outfits/gen_outfits.py head <id> ...     # Kopfteile (Frisur-Slot)
  python3 tools/japan_outfits/gen_outfits.py install <id> ...  # Rohbilder -> Ebenen (ohne Generierung)
"""
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/pixellab/creator_base"))
sys.path.insert(0, str(ROOT / "tools/pixellab"))
import outfit_layers as ol  # noqa: E402
from pixellab_v2 import Image, b64, find_images, request, wait_job  # noqa: E402

STYLE = "anime fighter clothing, clean outlines. Empty hands, no swords"

OUTFITS = {
    "hanabi": "a short festival kimono in deep crimson with a white plum blossom pattern, wide sleeves, "
              "a broad golden obi sash tied at the waist, the kimono ends above the knees over dark red "
              "leggings, white tabi socks with black lacquered geta sandals",
    "mondhakama": "a samurai outfit: crisp white kosode shirt with the collar crossed, wide black-indigo "
                  "pleated hakama trousers tied with a white cord, dark straw waraji sandals",
    "kranich": "a long teal haori coat with a white geometric wave pattern on the hem, worn open over a "
               "black kimono shirt, grey loose hakama trousers, black zori sandals",
    "gakuran": "a black high-collar japanese school uniform jacket with shiny gold buttons, worn open "
               "over a red t-shirt, black straight trousers, brown loafers",
    "matrose": "a japanese sailor school uniform: white blouse with a navy blue sailor collar with white "
               "stripes and a red neckerchief, navy pleated short skirt, long white knee socks, black loafers",
    "yukata": "a summer yukata in indigo blue with a white firework pattern, short sleeves, a bright "
              "yellow obi sash, the yukata reaches the shins, wooden geta sandals",
    "shinobi": "a dark charcoal ninja outfit: fitted wrap top with a long red scarf around the neck, "
               "dark cloth wraps on the forearms, a black sash belt, baggy charcoal trousers wrapped "
               "tight below the knees, split-toe black tabi boots",
    "miko": "a shrine maiden outfit: white kimono top with very wide white sleeves and red cords, bright "
            "red pleated hakama trousers, white tabi socks with straw zori sandals",
}

HEADS = {
    "hachimaki": "short spiky black hair with a white headband tied around the forehead with two long "
                 "trailing ends",
    "chonmage": "thick dark brown hair that fully covers the whole top and sides of the head with no bald skin "
                "visible, combed back into a samurai topknot on the crown",
    "kitsune": "long white hair with a red and white fox mask worn tilted on the side of the head, "
               "the face stays visible",
    "kasa": "short black hair under a wide conical straw kasa hat, the face stays visible",
}

RAW = Path("/tmp/japan_outfits")

# Weitere Themen-Kollektionen: OUTFITS/HEADS werden erweitert, RAW bleibt gemeinsam.
OUTFITS.update({
    "neonlaeufer": "a cyberpunk runner outfit: black cropped techwear jacket with glowing cyan seams and a high "
                   "collar, black cargo pants with hanging straps and cyan stripes, chunky white sneakers with "
                   "glowing cyan soles",
    "chromsoeldner": "a cyberpunk mercenary outfit: dark olive armored tactical vest over a black shirt, chrome "
                     "metal cybernetic plating on both forearms, dark grey cargo pants with knee pads, heavy black "
                     "combat boots with yellow warning stripes",
    "datenhoodie": "a cyberpunk hacker outfit: oversized purple hoodie with a glowing magenta circuit pattern, "
                   "black jogger pants with a magenta stripe, black high-top sneakers with glowing magenta LED strips",
    "synthidol": "a cyberpunk pop idol outfit: glossy white and pink short jacket with holographic iridescent "
                 "panels, neon pink pleated short skirt over black tights, white platform boots with pink glowing soles",
    "konzern": "a cyberpunk corporate agent outfit: sleek black long trench coat with thin glowing red trim, "
               "white shirt with a slim black tie, black slacks, polished black shoes",
    "strassenklinge": "a cyberpunk street samurai outfit: red and black armored bomber jacket with one angular "
                      "shoulder plate and glowing orange seams, black wide cargo hakama pants, black tech boots "
                      "with glowing orange soles",
})
OUTFITS.update({
    "eisjaeger": "a nordic frost hunter outfit: thick grey wolf fur mantle over a dark blue leather tunic with "
                 "silver clasps, brown leather trousers with fur-lined leg wraps, heavy brown fur boots",
    "runenschild": "a nordic shield warrior outfit: steel scale mail shirt over a deep red wool tunic, a wide "
                   "leather belt with a silver knot buckle, dark grey trousers with criss-cross leather bindings, "
                   "iron-capped leather boots",
    "frostseherin": "a nordic frost seer outfit: long pale blue robe (no hood, head uncovered) with glowing light blue rune "
                    "embroidery and white fur trim, a belt of bone charms, white wool leggings, soft white fur boots",
    "baerenhaut": "a nordic berserker outfit: a huge brown bear pelt over the bare shoulders and back, "
                  "bare chest with blue war paint lines, wide brown leather kilt-like trousers, fur-wrapped boots",
    "nordwanderer": "a nordic traveler outfit: dark green wool cloak without hood (head uncovered) with a bronze brooch, cream linen "
                    "shirt, brown wool trousers, worn leather turnshoes with wraps",
})
OUTFITS.update({
    "jadegelehrter": "a wuxia scholar outfit: flowing jade green hanfu robe with wide sleeves and white inner collar, "
                     "a black sash belt with a jade pendant, loose white trousers, black cloth shoes",
    "drachenwache": "a wuxia imperial guard outfit: red lacquered lamellar armor vest with gold trim over a black "
                    "robe, red cloth arm guards, black wide trousers, black boots with red trim",
    "lotusfaust": "a wuxia martial artist outfit: sleeveless white mandarin collar top with frog buttons, red "
                  "silk sash, black loose kung fu trousers tied at the ankles, black slippers",
    "pflaumentaenzerin": "a wuxia dancer outfit: pink and white layered silk ruqun dress with long flowing "
                         "ribbon sleeves and a plum blossom pattern, pale pink skirt to the ankles, white embroidered shoes",
    "schattenmeister": "a wuxia assassin outfit: dark navy fitted robe with silver cloud embroidery, black arm "
                       "wraps, a dark grey sash, black trousers tucked into black wrapped boots",
})
OUTFITS.update({
    "blutgraf": "a gothic vampire noble outfit: black velvet tailcoat with crimson lining and silver buttons, "
                "a white ruffled jabot at the collar, dark red waistcoat, black slim trousers, polished black "
                "buckle shoes",
    "mondgraefin": "a gothic lady outfit: black and deep purple corset dress with lace trim and puffed sleeves, "
                   "a short layered black lace skirt over purple striped stockings, black platform heels",
    "jaegerorden": "a gothic monster hunter outfit: long dark brown leather coat with silver buckles and a "
                   "high collar, a bandolier of silver vials across the chest, dark grey trousers, tall black boots",
    "kirchhofwaechter": "a gothic gravekeeper outfit: tattered dark grey shoulder cape over a black shirt, no hood, head uncovered, "
                        "a rope belt with a small lantern charm, patched black trousers, muddy worn boots",
    "rosendiener": "a gothic butler outfit: black waistcoat with a red rose pinned on the chest, white shirt "
                   "with rolled sleeves and black arm garters, black trousers, black oxford shoes",
})
HEADS.update({
    "zylinder": "slicked back black hair with a small tall black top hat with a thin crimson band sitting on top of the head above the forehead, the eyes and face stay fully visible",
    "gothlocken": "long wavy silver white hair with a black lace headband and a small red rose",
})
HEADS.update({
    "gelehrtenknoten": "long black hair with a neat top bun held by a small jade crown and hairpin",
    "drachenkrone": "black hair in a high ponytail with a golden dragon headpiece, the face stays visible",
})
HEADS.update({
    "hoernerhelm": "short blonde hair under an open iron helmet with two short curved horns, nothing hangs over the face or chest, the face "
                   "stays visible",
    "flechtbart": "wild red hair shaved on the sides with thick braids falling down the back",
})
HEADS.update({
    "neonvisier": "short white undercut hair with a sleek glowing cyan visor band over the eyes, the rest of the "
                  "face stays visible",
    "neonkamm": "a tall neon pink mohawk with glowing light strips along the shaved sides, the face stays visible",
})


def desc(oid):
    return "Dress all figures in the exact same outfit: " + OUTFITS[oid] + ". " + STYLE + ". " + ol.KEEP


def grids(oid, only_first=False):
    names = [f["name"] for f in ol.frame_list()]
    chunks = [names[i:i + 16] for i in range(0, len(names), 16)]
    if only_first:
        chunks = chunks[:1]
    out = RAW / oid
    out.mkdir(parents=True, exist_ok=True)
    used = 0
    for chunk in chunks:
        if all((out / f"{n}.png").exists() for n in chunk):
            continue
        grid = Image.new("RGBA", (256, 256))
        filled = chunk + [chunk[i % len(chunk)] for i in range(16 - len(chunk))]
        for i, n in enumerate(filled):
            grid.alpha_composite(Image.open(ol.BODY / "frames" / f"{n}.png").convert("RGBA"), ((i % 4) * 64, (i // 4) * 64))
        r = wait_job(request("POST", "/edit-image-pixen", {"image": b64(grid), "description": desc(oid),
                                                           "seed": ol.SEED, "no_background": True}))
        res = find_images(r)[-1]
        for i, n in enumerate(chunk):
            res.crop(((i % 4) * 64, (i // 4) * 64, (i % 4) * 64 + 64, (i // 4) * 64 + 64)).save(out / f"{n}.png")
        used += (r.get("usage") or {}).get("generations") or 1
    print(oid, "Generierungen:", used, flush=True)


def install(oid):
    raw = ol.PARTS / "_raw" / oid
    raw.mkdir(parents=True, exist_ok=True)
    for n in (RAW / oid).iterdir():
        (raw / n.name).write_bytes(n.read_bytes())
    ol.sheet(raw, ol.PARTS / "_preview" / f"{oid}_komplett.png")
    ol.split_layers(raw, oid)


def main():
    mode, ids = sys.argv[1], sys.argv[2:]
    if mode == "draft":
        with ThreadPoolExecutor(3) as ex:
            list(ex.map(lambda o: grids(o, True), ids or OUTFITS))
    elif mode == "outfit":
        with ThreadPoolExecutor(3) as ex:
            list(ex.map(grids, ids or OUTFITS))
    elif mode == "head":
        for h in ids or HEADS:
            subprocess.run([sys.executable, str(ROOT / "tools/pixellab/creator_base/hair.py"), h, HEADS[h]], check=True)
    elif mode == "install":
        for o in ids or OUTFITS:
            install(o)


if __name__ == "__main__":
    main()
