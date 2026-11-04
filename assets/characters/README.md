# Charaktere und Sprites

Chibi Legends hat viele feste Charaktere, die man über Gacha bekommt. Jeder Charakter hat einen festen Look und optionale Skins.

## Dateien

```
assets/characters/
  characters.json    alle Charaktere: Name, Welt, Seltenheit, Beschreibung, Look, Skins
  palettes.json      kuratierte Farben (Haut, Haar, Augen, Stoff)
  catalog.json       automatisch erzeugt, nicht von Hand ändern
  items/<id>/
    item.json        Name, Slot, Farbkanäle, Ebenen
    <ebene>.png      ein Blatt pro Ebene
```

## Charakter und Skins

Ein Look besteht aus Teilen pro Slot (`parts`), den Grundfarben (`colors`) und den Farben pro Teil (`item_colors`). Ein Skin überschreibt nur das, was er ändert:

```json
"kaito": {
  "name": "Kaito Hayabusa", "world": "ninja", "rarity": 4, "unlock": "start",
  "desc": "…",
  "look": {
    "parts": {"body": "koerper_basis", "hair": "haar_stachelig", "top": "oberteil_akademie", …},
    "colors": {"skin": "haut_1", "hair": "haar_rot", "eyes": "augen_braun"},
    "item_colors": {"oberteil_akademie": ["weiss", "rot"]}
  },
  "skins": [
    {"id": "kaito_legende", "name": "Goldene Legende", "unlock": "pass",
     "look": {"colors": {"hair": "haar_gold"}, "item_colors": {"oberteil_akademie": ["schwarz", "gold"]}}}
  ]
}
```

- `rarity`: 3 selten, 4 episch, 5 legendär. `unlock`: start, gacha, pass, shop, challenge.
- Ein Farb-Skin kostet keine neue Grafik: Der Shader färbt dieselben Sprites um.
- Ein Skin kann auch Teile tauschen (`"parts": {"top": "…"}`), z. B. ein Saison-Outfit.

Zwei Wege, einen Charakter zu bauen:
1. **Aus Teilen** (wie die 5 Platzhalter-Charaktere): Teile mehrerer Charaktere lassen sich wiederverwenden, Skins können einzelne Teile tauschen.
2. **Als ein Sprite**: PixelLab malt die ganze Figur in einem Stück (siehe unten, `"mode": "full"`). Das Teil hat Slot `body`, und der Look enthält nur `"parts": {"body": "<id>"}`.

## Format

- Blatt 512 × 704 px: 8 Spalten × 11 Zeilen, jede Zelle 64 × 64 px.
- Eine Zeile pro Animation: idle 4, run 8, jump 2, fall 2, dash 2, attack_1–3 je 4, cast 4, hit 2, ko 3 Frames.
- Fußpunkt in jeder Zelle bei x 28, y 56. Seitenansicht nach rechts, links wird gespiegelt.
- Ebenen von hinten nach vorn: `acc_back, hair_back, body, face, pants, shoes, top, hair_front, acc_front, headgear, weapon`.
- Pixel sind palettenkodiert: Rot = Ton × 32 + 16 (0 = Umriss, 4 = Grundfarbe), Grün = Farbkanal × 64 + 32 (0–2 = Farben des Teils, 3 = feste Farben wie Gold, Stahl, Weiß). Der Shader `assets/shaders/palette_swap.gdshader` färbt das im Spiel ein.

Die genaue Definition steht in `tools/sprites/rig.py`.

## Neues Teil oder neuen Charakter erzeugen

1. Ordner `items/<id>/` mit `item.json` anlegen, zum Beispiel ein Teil:

   ```json
   {
     "id": "oberteil_ninja_weste", "name": "Ninja-Weste", "slot": "top",
     "channels": [
       {"key": "c0", "label": "Weste", "group": "stoff", "default": "marine"},
       {"key": "c1", "label": "Platten", "group": "stoff", "default": "grau"}
     ],
     "layers": {},
     "pixellab": {
       "prompt": "dark ninja vest with metal plates, chibi pixel art, side view",
       "negative": "hair, face, weapon", "seed": 4242,
       "mask_from": "oberteil_akademie", "grow": 3
     }
   }
   ```

   Für eine ganze Figur: `"slot": "body"`, Kanäle z. B. Haut, Haar, Kleidung (ohne `appearance`), und im `pixellab`-Block `"mode": "full"` mit `"mask_from": ["koerper_basis", "haar_stachelig", "oberteil_akademie", "accessoire_schal", "waffe_katana"]`.

2. Bilder erzeugen, auf einem von zwei Wegen:
   - **Mit PixelLab per Skript:** `python3 tools/pixellab/generate.py <id> --dry-run` (nur Eingaben, ohne Kosten), dann `--only idle:0` (ein Frame), dann ohne `--only` für alle 39 Frames. Jedes Frame wird nur innerhalb der Maske gemalt, deshalb bleibt alles ausgerichtet.
   - **Selbst gemacht** (PixelLab-Weboberfläche, Aseprite …): ein Blatt im Format oben als PNG speichern und `python3 tools/pixellab/import_sheet.py <id> bild.png` aufrufen. Mit `--on-base` darf das Bild die ganze Figur zeigen, die Basis wird dann abgezogen.
3. `python3 tools/sprites/build_catalog.py` prüft alle Teile und schreibt `catalog.json`.
4. Charakter in `characters.json` eintragen und mit `python3 tools/sprites/preview.py vorschau.png` ansehen.

## PixelLab einrichten

Das Skript braucht Netzzugriff auf `api.pixellab.ai` und den Key in der Umgebungsvariable `PIXELLAB_API_KEY`. Beides wird in den Einstellungen der Cloud-Umgebung eingetragen, der Key kommt nie ins Repo.

## Platzhalter

Die jetzigen Teile sind die Pixel-Figur aus Phase 1, aufgeteilt in Ebenen (`tools/sprites/bake_placeholders.py`). Daraus sind die 5 Start-Charaktere zusammengesetzt. Sie werden nach und nach durch PixelLab-Grafik ersetzt, ohne dass sich am Spielcode etwas ändert.
