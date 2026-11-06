"""Raid-Rüstung "Essenwacht" in 6 Seltenheiten (PixelLab).

Ein Outfit pro Seltenheit über alle 68 Posen (5 Raster = 5 Generierungen)
plus ein Helm im Frisur-Slot (1 Generierung). Die Pracht steigt sichtbar:
Gewöhnlich = Eisen und Leder, Mythisch = Obsidian mit Sternenglut.
Glühen ab Episch und die Animation bei Mythisch macht das Spiel (Shader),
die Zeichnung liefert nur die hellen Glut-Adern.

  python3 tools/raid_armor/gen_armor.py draft            # nur Raster 1 (idle/walk/run), 6 Gens
  python3 tools/raid_armor/gen_armor.py outfit <rar>     # alle Raster einer Seltenheit, 5 Gens
  python3 tools/raid_armor/gen_armor.py helm <rar>       # Helm, 1 Gen
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/pixellab/creator_base"))
sys.path.insert(0, str(ROOT / "tools/pixellab"))
import outfit_layers as ol  # noqa: E402
from pixellab_v2 import Image, b64, find_images, request, wait_job  # noqa: E402

STYLE = "anime fighter armor, clean outlines"

ARMOR = {
    "gewoehnlich": ("Essenwacht-Rekrut",
        "a plain forge guard recruit armor: dull grey iron breastplate over a brown padded leather jerkin, "
        "one simple riveted iron shoulder plate, brown leather belt, grey cloth trousers with leather knee "
        "wraps, worn brown leather boots with iron toe caps"),
    "ungewoehnlich": ("Essenwacht-Posten",
        "a forge guard armor: blackened iron breastplate with green enamel trim, two rounded iron "
        "shoulder plates, short chainmail skirt over dark green trousers, iron knee guards, "
        "dark leather boots with green straps"),
    "selten": ("Essenwacht-Hüter",
        "a polished steel half-plate armor: bright steel breastplate with a deep blue cloth tabard and "
        "blue enamel edges, layered steel shoulder plates, steel gauntlets, blue trousers with steel "
        "greaves, steel-plated boots"),
    "episch": ("Essenwacht-Glutritter",
        "an ornate dark knight armor: black-violet plate armor with glowing purple ember rune lines, "
        "big layered spiked pauldrons, purple glowing core gem on the chest, violet cloth tassets, "
        "plated greaves with glowing purple seams, heavy armored boots"),
    "legendaer": ("Essenwacht-Schmiedekönig",
        "a legendary golden king armor: white and gold ornate plate armor with molten orange glowing "
        "cracks, huge crown-shaped golden pauldrons, a flowing red sash cape at the waist, "
        "golden greaves with glowing orange seams, golden armored boots"),
    "mythisch": ("Essenwacht-Sternenglut",
        "a mythic celestial armor: obsidian black plate armor with bright crimson and pink star-fire "
        "veins, flame-shaped crimson crystal pauldrons, a burning star core on the chest, long flowing "
        "crimson flame tassets, obsidian greaves with glowing crimson cracks, clawed obsidian boots"),
}

HELM = {
    "gewoehnlich": "a simple dull grey iron open-face helmet",
    "ungewoehnlich": "a blackened iron helmet with green enamel crest and cheek guards",
    "selten": "a polished steel knight helmet with a blue plume, face visible",
    "episch": "a black-violet horned helmet with glowing purple rune lines, face visible",
    "legendaer": "a golden crown helmet with molten orange glowing gems, face visible",
    "mythisch": "an obsidian helmet with a floating crimson star-fire crown and flame horns, face visible",
}

RAW = Path("/tmp/raid_armor")


def desc(rar):
    return "Dress all figures in the exact same outfit: " + ARMOR[rar][1] + ". " + STYLE + ". " + ol.KEEP


def grids(rar, only_first=False):
    names = [f["name"] for f in ol.frame_list()]
    chunks = [names[i:i + 16] for i in range(0, len(names), 16)]
    if only_first:
        chunks = chunks[:1]
    out = RAW / rar
    out.mkdir(parents=True, exist_ok=True)
    used = 0
    for chunk in chunks:
        if all((out / f"{n}.png").exists() for n in chunk):
            continue
        grid = Image.new("RGBA", (256, 256))
        filled = chunk + [chunk[i % len(chunk)] for i in range(16 - len(chunk))]
        for i, n in enumerate(filled):
            grid.alpha_composite(Image.open(ol.BODY / "frames" / f"{n}.png").convert("RGBA"), ((i % 4) * 64, (i // 4) * 64))
        r = wait_job(request("POST", "/edit-image-pixen", {"image": b64(grid), "description": desc(rar),
                                                           "seed": ol.SEED, "no_background": True}))
        res = find_images(r)[-1]
        for i, n in enumerate(chunk):
            res.crop(((i % 4) * 64, (i // 4) * 64, (i % 4) * 64 + 64, (i // 4) * 64 + 64)).save(out / f"{n}.png")
        used += (r.get("usage") or {}).get("generations") or 1
    print(rar, "Generierungen:", used)


def main():
    mode = sys.argv[1]
    if mode == "draft":
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(3) as ex:
            list(ex.map(lambda r: grids(r, True), ARMOR))
    elif mode == "outfit":
        grids(sys.argv[2])
    elif mode == "helm":
        import subprocess
        subprocess.run([sys.executable, str(ROOT / "tools/pixellab/creator_base/hair.py"), "raid_" + sys.argv[2],
                        HELM[sys.argv[2]] + " that covers all the hair"], check=True)


if __name__ == "__main__":
    main()
