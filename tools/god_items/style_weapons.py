#!/usr/bin/env python3
"""GOD-Waffen für die 30 Baukasten-Kampfstile (#84): je Stil eine, 15 Heilig, 15 Dämon.
  - Stile mit Waffe: PixelLab edit-image-pixen auf die Stil-Waffe (64x64), Form und Griff
    bleiben, Material wird heilig/dämonisch. Das Bild dient auch als Icon. (16 Generierungen)
  - Stile ohne Waffe: Faust-Aura in Stilfarbe, Icon per pixflux. (14 Generierungen)
    python3 -I tools/god_items/style_weapons.py gen      # Generieren (fehlende)
    python3 -I tools/god_items/style_weapons.py install  # Sprites, Icons, catalog.json, god_items.gd-Block
"""
import json, pathlib, sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/jus_style"))
RAW = ROOT / "assets/god/raw/styles"
CAT = ROOT / "assets/creator/catalog.json"
H, D = "heilig", "daemon"
# stil: (id, Name, Serie, Spruch, Bild-Idee)
W = {
    "gezeitenklinge": ("god_flutseraph", "Flutseraph", H, "Das Meer verneigt sich, wenn sie gezogen wird.", "sea"),
    "donnerschritt": ("god_himmelsdonner", "Himmelsdonner", H, "Jeder Schritt ein Urteil vom Himmel.", "golden lightning gauntlets"),
    "frostlotus": ("god_engelsfrost", "Engelsfrost", H, "Ihr Eis schmilzt nur im Gebet.", "ice"),
    "sonnenlanze": ("god_sonnengericht", "Sonnengericht", H, "Die Sonne richtet. Die Lanze vollstreckt.", "sun"),
    "sturmfeder": ("god_cherubsfeder", "Cherubsfeder", H, "Ein Flügelschlag, und der Sturm gehorcht.", "wind"),
    "sternensang": ("god_sternenchor", "Sternenchor", H, "Tausend Sterne singen mit, wenn sie trifft.", "star constellation gauntlets"),
    "kristallherz": ("god_prisma", "Prisma der Gnade", H, "Bricht das Licht und jeden Panzer.", "radiant prism crystal gauntlets"),
    "papierkranich": ("god_tausendgebete", "Tausend Gebete", H, "Jedes Siegel ein Gebet, jedes Gebet ein Schlag.", "holy paper talisman wraps with golden seals"),
    "klingenwirbel": ("god_heiligenkreis", "Heiligenkreis", H, "Ein Kreis aus Licht, den niemand übertritt.", "light"),
    "polarlicht": ("god_himmelsschleier", "Himmelsschleier", H, "Gewebt aus dem Licht über dem Ende der Welt.", "aurora"),
    "gewitterhammer": ("god_richterhammer", "Richterhammer", H, "Er fällt nur einmal. Das reicht.", "thunder"),
    "kirschsturm": ("god_paradiesbluete", "Paradiesblüte", H, "Blüht nur im Garten hinter den Wolken.", "blossom"),
    "zeitriss": ("god_ewigestunde", "Ewige Stunde", H, "Für ihren Träger bleibt die Zeit stehen.", "golden clockwork gauntlets with glowing clock faces"),
    "spiegelseele": ("god_wahrheitsspiegel", "Spiegel der Wahrheit", H, "Zeigt jedem, was er verdient.", "silver-gold mirror gauntlets with radiant light"),
    "runenschmied": ("god_erzengelhammer", "Erzengelhammer", H, "Geschmiedet am ersten Tag, für den letzten.", "rune"),
    "erdenfaust": ("god_hoellenfels", "Höllenfels", D, "Ein Stück vom Boden der Hölle, an jeder Faust.", "black volcanic rock gauntlets with lava cracks"),
    "schattennaht": ("god_seelennaht", "Seelennaht", D, "Was sie vernäht, bleibt für immer vernäht.", "shadow"),
    "giftranke": ("god_verderbnisranke", "Verderbnisranke", D, "Wächst aus jedem Grab, das du hinterlässt.", "poison thorn vine gauntlets with purple toxic glow"),
    "rotschwur": ("god_blutpakt", "Blutpakt", D, "Sie nimmt dein Blut und gibt dir die Welt.", "blood"),
    "eisenkette": ("god_hoellenkette", "Höllenkette", D, "Jedes Glied hielt einmal einen Dämon.", "chain"),
    "trommelherz": ("god_hoellenpauke", "Höllenpauke", D, "Der Takt, zu dem die Unterwelt marschiert.", "demonic war drum gauntlets with skulls and red fire"),
    "nebelfuchs": ("god_daemonenfuchs", "Dämonenfuchs", D, "Neun Schwänze, neun gefressene Seelen.", "dark purple fox fire claws with nine flames"),
    "drachenzorn": ("god_hoellendrache", "Höllendrache", D, "Ein Drache, der nie geboren wurde, nur entfesselt.", "black dragon head gauntlets breathing crimson fire"),
    "puppenfaden": ("god_seelenfaden", "Seelenfaden", D, "Die Fäden enden nicht an der Puppe.", "puppeteer gloves with glowing crimson soul strings"),
    "vulkanherz": ("god_weltenbrand", "Weltenbrand", D, "Ein Schlag, und der Boden wird zum Feuer.", "lava"),
    "sandsturm": ("god_aschesturm", "Aschesturm", D, "Wo sie schneidet, bleibt nur Asche.", "ash"),
    "geisterlaterne": ("god_totenlicht", "Totenlicht", D, "Ihr Licht führt nur in eine Richtung.", "soul"),
    "abgrundtiefe": ("god_leviathan", "Leviathan", D, "Aus der Tiefe, in der kein Licht je war.", "black abyssal tentacle gauntlets with glowing teal eyes"),
    "bestienklaue": ("god_hoellenklaue", "Höllenklaue", D, "Die Bestie war zuerst da. Du bist nur ihr Griff.", "huge black demon beast claws with burning orange edges"),
    "leerenschnitt": ("god_nichtsklinge", "Nichtsklinge", D, "Sie schneidet nicht. Sie lässt verschwinden.", "void"),
}
HOLY = "Turn this weapon into a divine holy GOD-tier version: radiant white and polished gold, glowing golden light, small angel feather ornaments, a {m} motif"
DEMON = "Turn this weapon into a demonic GOD-tier version: black obsidian and crimson, glowing red lava veins, small horns and spikes, a dark {m} motif"
KEEP = ". Keep the exact same shape, size, angle and position, pixel art, bold dark outline, no hands, no background."
ICON = "RPG inventory item icon, pixel art, centered, single object, bold dark outline, high contrast, no text, no background"
TONE = {H: "radiant white and polished gold, glowing holy light, divine", D: "black obsidian and crimson, glowing red lava veins, demonic"}


def styles():
    return json.loads(CAT.read_text())["styles"]


def base_weapon(st):
    w = str(styles()[st].get("weapon", ""))
    return "" if w in ("", "none") or styles()[st].get("unarmed") else w


def gen():
    import pl2
    sys.path.insert(0, str(ROOT / "tools/pixellab"))
    import pixellab_v2 as v2
    from concurrent.futures import ThreadPoolExecutor
    RAW.mkdir(parents=True, exist_ok=True)
    cat = json.loads(CAT.read_text())

    def one(st):
        gid, name, ser, line, motif = W[st]
        out = RAW / f"{gid}.png"
        if out.exists():
            return
        bw = base_weapon(st)
        if bw:
            img = Image.open(ROOT / cat["weapons"][bw]["texture"].replace("res://", "")).convert("RGBA")
            desc = (HOLY if ser == H else DEMON).format(m=motif) + KEEP
            r = v2.wait_job(v2.request("POST", "/edit-image-pixen", {"image": v2.b64(img), "description": desc,
                                                                      "seed": 5, "no_background": True}))
            v2.find_images(r)[-1].convert("RGBA").save(out)
        else:
            desc = f"a pair of {motif}, {TONE[ser]}, {ICON}"
            r = pl2.post("/create-image-pixflux", {"description": desc, "image_size": {"width": 32, "height": 32},
                                                   "outline": "single color black outline", "shading": "detailed shading",
                                                   "detail": "highly detailed", "no_background": True, "text_guidance_scale": 8, "seed": 91})
            pl2.to_img(r["image"]).save(out)
        print(st, gid, r.get("usage"), flush=True)
    with ThreadPoolExecutor(2) as ex:
        list(ex.map(one, W))


def install():
    cat = json.loads(CAT.read_text())
    wdir = ROOT / "assets/creator/weapons/god"
    idir = ROOT / "assets/god/icons"
    wdir.mkdir(parents=True, exist_ok=True)
    gd = []
    for st, (gid, name, ser, line, motif) in W.items():
        im = Image.open(RAW / f"{gid}.png").convert("RGBA")
        bw = base_weapon(st)
        col = json.loads((ROOT / f"assets/combat/styles/{st}.json").read_text())["colors"]
        entry = f'\t"{gid}": {{"name": "{name}", "series": {"HOLY" if ser == H else "DEMON"}, "slot": "waffe", "style": "{st}", '
        if bw:
            im.save(wdir / f"{gid}.png")
            e = dict(cat["weapons"][bw])
            e["texture"] = f"res://assets/creator/weapons/god/{gid}.png"
            cat["weapons"][gid] = e
            cat["slots"]["weapon"]["items"][gid] = "GOD · " + name
            cat["slots"]["weapon"].setdefault("unlock", {})[gid] = f"GOD-Teil: weltweit nur einmal ({name})"
            # Icon: Waffe zentriert auf 32x32
            bb = im.getbbox()
            c = im.crop(bb)
            c.thumbnail((30, 30), Image.NEAREST)
            icon = Image.new("RGBA", (32, 32))
            icon.alpha_composite(c, ((32 - c.width) // 2, (32 - c.height) // 2))
            icon.save(idir / f"{gid}.png")
            entry += f'"weapon": "{gid}", '
        else:
            im.save(idir / f"{gid}.png")
            entry += f'"fx": "fists", "aura": ["{col["main"]}", "{col["accent"]}"], '
        entry += f'\n\t\t"line": "{line}"}},'
        gd.append(entry)
    CAT.write_text(json.dumps(cat, indent=1, ensure_ascii=False) + "\n")
    (ROOT / "assets/god/raw/styles/god_items_block.txt").write_text("\n".join(gd) + "\n")
    print("ORDER:", ", ".join(f'"{W[s][0]}"' for s in W))


if __name__ == "__main__":
    {"gen": gen, "install": install}[sys.argv[1]]()
