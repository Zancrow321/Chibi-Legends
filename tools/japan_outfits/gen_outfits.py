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
    "chonmage": "a samurai topknot: dark hair pulled back tight with a small folded top knot",
    "kitsune": "long white hair with a red and white fox mask worn tilted on the side of the head, "
               "the face stays visible",
    "kasa": "short black hair under a wide conical straw kasa hat, the face stays visible",
}

RAW = Path("/tmp/japan_outfits")


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
