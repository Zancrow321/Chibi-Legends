#!/usr/bin/env python3
"""Baut aus den Stil-Definitionen (defs_a/b/c.py) die Spieldaten der 30
Baukasten-Kampfstile:
  - assets/combat/styles/<id>.json       (Züge, Alternativen, Meisterzug, Kern)
  - assets/creator/catalog.json          (styles + neue Waffen, falls Bild da)
  - assets/gacha/banners.json            (ein Banner je Stil)
  - assets/combat/formen/prompts.json    (PixelLab-Beschreibungen für gen_fx.py)
  - docs/formen-liste.md                 (ausgearbeitete Liste)

    python3 -I tools/formen/build.py
"""
import json, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from defs_a import STYLES as A  # noqa: E402
from defs_b import STYLES as B  # noqa: E402
from defs_c import STYLES as C  # noqa: E402

ROOT = HERE.parents[1]
STYLES = A + B + C
DIRS = ["neutral", "forward", "up", "down"]
KIND_FRAMES = {
    "hieb": [8, 12, 14], "geschoss": [10, 6, 16], "sturm": [5, 12, 12], "saeule": [9, 14, 16],
    "sturz": [8, 8, 18], "konter": [4, 24, 14], "aura": [12, 6, 12], "feld": [10, 8, 16],
    "strahl": [12, 30, 16], "schritt": [4, 6, 12], "regen": [12, 10, 16], "wirbel": [6, 30, 12],
}
KIND_CD = {"hieb": 0.7, "geschoss": 1.0, "sturm": 1.0, "saeule": 1.1, "sturz": 1.2, "konter": 1.2, "aura": 6.0,
           "feld": 2.0, "strahl": 1.6, "schritt": 1.1, "regen": 1.6, "wirbel": 1.3}
KIND_NAMES = {"hieb": "Nahkampf-Hiebe", "geschoss": "Geschoss", "sturm": "Ansturm", "saeule": "Säule aus dem Boden",
              "sturz": "Sturz von oben", "konter": "Konter-Haltung", "aura": "Stärkung", "feld": "Feld am Boden",
              "strahl": "Strahl", "schritt": "Teleport-Schritt", "regen": "Regen von oben", "wirbel": "Wirbel"}
SUPER_NAMES = {"strahl": "Riesenstrahl", "regen": "Bildschirm-Regen", "nova": "Explosion um dich",
               "ansturm": "Schnitt-Ansturm", "feld": "Bildschirm-Feld", "saeulen": "Säulenreihe"}
KERN_NAMES = {"rhythmus": "Rhythmus (verschiedene Züge)", "ladung": "Ladung (Überladung bei 5)",
              "marken": "Marken (Zünder sprengt sie)", "echo": "Echo (Nachschlag 40 %)",
              "blutzoll": "Blutzoll (LP gegen Schaden)", "fokus": "Fokus (Ruhe sammeln)"}
# Waffe -> Prompt für PixelLab (horizontal, Griff links, Spitze rechts)
WEAPONS = {
    "wellenschneide": ("Wellenschneide", "a slim katana with a wave patterned blue steel blade and a white wrapped handle"),
    "eisfaecher": ("Eisfächer", "a large open folding war fan made of pale blue ice crystal ribs with pink tassel"),
    "nahtdolch": ("Nahtdolch", "a thin black needle like dagger with a violet glowing edge and thread wrapped grip"),
    "sonnenspeer": ("Sonnenspeer", "a long golden spear with a sun shaped spearhead and white shaft"),
    "sturmfaecher": ("Sturmfächer", "a big green feather fan on a short wooden handle with white feathers"),
    "schwurklinge": ("Schwurklinge", "a dark crimson longsword with a black hilt and red glowing runes on the blade"),
    "kettensichel": ("Kettensichel", "a curved steel sickle on a short wooden handle with an iron chain wrapped around it"),
    "wirbelklinge": ("Wirbelklinge", "a double bladed staff weapon with two curved cyan steel blades at both ends"),
    "lavahammer": ("Lavahammer", "a heavy black obsidian war hammer with glowing orange lava cracks on the head"),
    "nordlichtstab": ("Nordlichtstab", "a long slender mage staff with a glowing green aurora crystal at the tip"),
    "sandsaebel": ("Sandsäbel", "a curved golden scimitar with a sand colored hilt and red gem"),
    "geisterlaterne": ("Geisterlaterne", "a long wooden pole with a hanging paper lantern glowing green at the end"),
    "donnerhammer": ("Donnerhammer", "a large steel war hammer with a blue lightning bolt engraving and yellow glow"),
    "bluetenklinge": ("Blütenklinge", "a katana with a pale pink blade and cherry blossom engravings, pink handle"),
    "runenhammer": ("Runenhammer", "a stone headed hammer with glowing cyan runes carved into it, wooden handle"),
    "leerenklinge": ("Leerenklinge", "a black sword with a purple void blade full of tiny stars and a magenta edge"),
}


def zug_json(z, idx):
    kind = z["kind"]
    frames = z.get("frames") or KIND_FRAMES[kind]
    d = {"name": z["name"], "kind": kind, "dir": DIRS[idx] if idx < 4 else (z.get("dir") or "neutral"),
         "sp": 1, "cd": z.get("cd") or KIND_CD[kind], "frames": frames, "desc": z["desc"],
         "params": z["params"], "enhanced": z["enhanced"], "alts": z["alts"]}
    return d


def style_json(s):
    zuege = {}
    for i, z in enumerate(s["zuege"]):
        zuege[z["id"]] = zug_json(z, i)
    ids = [z["id"] for z in s["zuege"]]
    loadout = {DIRS[i]: ids[i] for i in range(4)}
    k = s["kern"]
    if k["type"] == "marken" and k["zuender"] not in loadout.values():
        loadout["down"] = k["zuender"]
    armed = not s.get("unarmed", False)
    variants = []
    for i, v in enumerate(s["meister"]):
        variants.append({"id": v["id"], "name": v["name"], "kind": v["kind"], "sp": 0 if i == 0 else 2,
                         "desc": v["desc"], "params": v["params"]})
    total = len(zuege) + sum(2 * len(z["alts"]) for z in zuege.values()) + 4 + 2 + 2
    return {
        "_doc": "Baukasten-Kampfstil %s (scripts/formen). Konzept und Liste: docs/formen-liste.md, Baukasten: docs/formen-baukasten.md. "
                "kind = Art des Zuges, params = Grundform, eine Alternative ueberschreibt einzelne Werte, enhanced = verstaerkt (L halten, 1 Stufe Legendenleiste): _add addiert, _mul multipliziert. "
                "Erzeugt von tools/formen/build.py, dort aendern." % s["name"],
        "id": s["id"], "name": s["name"], "element": s["element"], "caster": "form",
        "subtitle": s["subtitle"],
        "moveset": "res://assets/combat/movesets/%s.json" % ("glutatem" if armed else "lauffeuer"),
        "armed": armed, "colors": s["colors"], "kern": k, "loadout": loadout, "zuege": zuege,
        "meisterzug": {"name": "Meisterzug", "sp": 4, "cost": 300,
                       "desc": "Super für 3 Stufen der Legendenleiste. Die drei Varianten sind verschiedene Supers.",
                       "variants": variants},
        "_sp_total": total,
    }


def main():
    assert len(STYLES) == 30, len(STYLES)
    seen = set()
    prompts = {}
    for s in STYLES:
        assert s["id"] not in seen, s["id"]
        seen.add(s["id"])
        assert len(s["zuege"]) == 6, s["id"]
        assert len(s["meister"]) == 3, s["id"]
        for z in s["zuege"]:
            assert len(z["alts"]) == 3, (s["id"], z["id"])
            assert z["kind"] in KIND_FRAMES, (s["id"], z["id"], z["kind"])
        for v in s["meister"]:
            assert v["kind"] in SUPER_NAMES, (s["id"], v["id"])
        if s["kern"]["type"] == "marken":
            assert s["kern"]["zuender"] in [z["id"] for z in s["zuege"]], s["id"]
        js = style_json(s)
        assert js["_sp_total"] == 50, (s["id"], js["_sp_total"])
        out = ROOT / "assets" / "combat" / "styles" / ("%s.json" % s["id"])
        out.write_text(json.dumps(js, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
        prompts[s["id"]] = {"look": s["look"], "fx": {z["id"]: z["fx"] for z in s["zuege"]},
                            "super": {v["id"]: v["fx"] for v in s["meister"]},
                            "names": {**{z["id"]: z["name"] for z in s["zuege"]}, **{v["id"]: v["name"] for v in s["meister"]}}}
    pdir = ROOT / "assets" / "combat" / "formen"
    pdir.mkdir(parents=True, exist_ok=True)
    (pdir / "prompts.json").write_text(json.dumps({"styles": prompts, "weapons": {k: v[1] for k, v in WEAPONS.items()}},
                                                  ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (pdir / "styles.json").write_text(json.dumps({"_doc": "Liste der Baukasten-Kampfstile (tools/formen/build.py).",
                                                  "styles": [s["id"] for s in STYLES]}, indent=1) + "\n", encoding="utf-8")
    _catalog()
    _banners()
    _doc()
    print("30 Stile gebaut")


def _catalog():
    p = ROOT / "assets" / "creator" / "catalog.json"
    cat = json.loads(p.read_text(encoding="utf-8"))
    wpath = ROOT / "assets" / "creator" / "weapons" / "formen" / "anchors.json"
    anchors = json.loads(wpath.read_text()) if wpath.exists() else {}
    for wid, (wname, _) in WEAPONS.items():
        if wid in anchors:
            a = anchors[wid]
            cat["weapons"][wid] = {"texture": "res://assets/creator/weapons/formen/%s.png" % wid, "scale": a.get("scale", 1),
                                   "grip": a["grip"], "tip": a["tip"]}
            if a.get("twohand"):
                cat["weapons"][wid]["twohand"] = True
            cat["slots"]["weapon"]["items"][wid] = wname
    for s in STYLES:
        w = s.get("weapon", "")
        entry = {"name": s["name"], "text": s["text"], "unlock": ""}
        if s.get("unarmed"):
            entry["weapon"] = ""
            entry["unarmed"] = True
        else:
            entry["weapon"] = w if w in anchors else "schwert_kaiser"
        cat["styles"][s["id"]] = entry
        if w in anchors:
            cat["slots"]["weapon"].setdefault("unlock", {})[w] = "Gacha-Banner „%s“ (Kampfstil %s)" % (s["banner"][0], s["name"])
    p.write_text(json.dumps(cat, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def _banners():
    p = ROOT / "assets" / "gacha" / "banners.json"
    b = json.loads(p.read_text(encoding="utf-8"))
    ids = {x["style"] for x in b["banners"]}
    for s in STYLES:
        if s["id"] in ids:
            continue
        b["banners"].append({"id": "form_" + s["id"], "title": s["banner"][0], "style": s["id"], "tagline": s["banner"][1]})
    p.write_text(json.dumps(b, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


EL = {"": "Physisch", "feuer": "Feuer", "frost": "Frost", "blitz": "Blitz", "wind": "Wind", "seele": "Seele",
      "wasser": "Wasser", "erde": "Erde", "schatten": "Schatten", "licht": "Licht", "gift": "Gift"}


def _doc():
    lines = ["# Die 30 Baukasten-Kampfstile", "",
             "Erzeugt von `tools/formen/build.py` aus `tools/formen/defs_*.py`. Alle Stile sind Legendär "
             "(Sternschrein, eigenes Banner), haben 6 Züge mit je 3 Alternativen und einen Meisterzug mit "
             "3 Varianten (zusammen genau 50 SP). Wie die Arten funktionieren: `docs/formen-baukasten.md`.", ""]
    for n, s in enumerate(STYLES, 1):
        wname = WEAPONS.get(s.get("weapon", ""), ("waffenlos",))[0] if not s.get("unarmed") else "waffenlos"
        lines += ["## %d. %s" % (n, s["name"]), "",
                  "*%s*  " % s["subtitle"],
                  "Element: **%s** · Waffe: **%s** · Banner: „%s“ (%s)" % (EL[s["element"]], wname, s["banner"][0], s["banner"][1]), "",
                  "**Kern: %s** (%s). %s" % (s["kern"]["name"], KERN_NAMES[s["kern"]["type"]], s["kern"]["desc"]), "",
                  "| Zug | Art | Grundform | Alternativen |", "|---|---|---|---|"]
        for z in s["zuege"]:
            alts = "; ".join("**%s**: %s" % (a["name"], a["desc"]) for a in z["alts"])
            lines.append("| %s | %s | %s | %s |" % (z["name"], KIND_NAMES[z["kind"]], z["desc"], alts))
        lines += ["", "**Meisterzug:** " + "; ".join("**%s** (%s): %s" % (v["name"], SUPER_NAMES[v["kind"]], v["desc"]) for v in s["meister"]), ""]
    (ROOT / "docs" / "formen-liste.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
