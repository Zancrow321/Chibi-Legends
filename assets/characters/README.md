# Charakter-Teile (Paper-Doll)

Jede Figur besteht aus Ebenen, die alle dasselbe Raster benutzen. Deshalb passt jede Frisur zu jeder Rüstung, in jeder Animation.

## Format

- Blatt 512 × 704 px: 8 Spalten × 11 Zeilen, jede Zelle 64 × 64 px.
- Eine Zeile pro Animation: idle 4, run 8, jump 2, fall 2, dash 2, attack_1–3 je 4, cast 4, hit 2, ko 3 Frames.
- Fußpunkt in jeder Zelle bei x 28, y 56. Seitenansicht nach rechts, links wird gespiegelt.
- Ebenen von hinten nach vorn: `acc_back, hair_back, body, face, pants, shoes, top, hair_front, acc_front, headgear, weapon`.
- Pixel sind palettenkodiert: Rot = Ton × 32 + 16 (0 = Umriss, 4 = Grundfarbe), Grün = Farbkanal × 64 + 32 (0–2 = Farben des Teils, 3 = feste Farben wie Gold, Stahl, Weiß). Der Shader `assets/shaders/palette_swap.gdshader` färbt das im Spiel ein. Ein Teil gibt es dadurch sofort in allen Farben.

Die genaue Definition steht in `tools/sprites/rig.py`.

## Ordner

```
assets/characters/
  palettes.json      kuratierte Farben pro Gruppe; "unlock" = seltene Farbe (pass, challenge, shop, gacha)
  catalog.json       automatisch erzeugt, nicht von Hand ändern
  items/<id>/
    item.json        Name, Slot, Farbkanäle, Ebenen
    <ebene>.png      ein Blatt pro Ebene
```

## Neue Rüstung hinzufügen

1. Ordner `items/<id>/` mit `item.json` anlegen, zum Beispiel:

   ```json
   {
     "id": "oberteil_ninja_weste",
     "name": "Ninja-Weste",
     "slot": "top",
     "channels": [
       {"key": "c0", "label": "Weste", "group": "stoff", "default": "marine"},
       {"key": "c1", "label": "Platten", "group": "stoff", "default": "grau"}
     ],
     "layers": {},
     "pixellab": {
       "prompt": "dark ninja vest with metal plates, chibi pixel art, side view",
       "negative": "hair, face, weapon",
       "seed": 4242,
       "mask_from": "oberteil_akademie",
       "grow": 3
     }
   }
   ```

2. Bilder erzeugen, auf einem von zwei Wegen:
   - **Mit PixelLab per Skript:** `python3 tools/pixellab/generate.py oberteil_ninja_weste --only idle:0` zum Testen, danach ohne `--only` für alle 39 Frames. PixelLab malt jedes Frame auf die eingefrorene Basis-Figur, nur innerhalb der Maske (`mask_from` + `grow` Pixel Rand). Mit `--dry-run` werden nur Basis und Maske geschrieben, ohne Kosten.
   - **Selbst gemacht** (PixelLab-Weboberfläche, Aseprite …): ein Blatt im Format oben als PNG speichern und `python3 tools/pixellab/import_sheet.py oberteil_ninja_weste bild.png` aufrufen. Mit `--on-base` darf das Bild die ganze Figur zeigen; die Basis wird dann abgezogen. Farben werden auf die nächsten Töne der Kanalfarben gerundet, also am besten mit diesen Farben malen.
3. `python3 tools/sprites/build_catalog.py` prüft alle Teile (Größe, Kodierung, leere Zellen, Farbkanäle) und schreibt `catalog.json`.
4. `python3 tools/sprites/preview.py vorschau.png` zeigt die Vorschau-Looks in mehreren Animationen.

## PixelLab einrichten

Das Skript braucht Netzzugriff auf `api.pixellab.ai` und den Key in der Umgebungsvariable `PIXELLAB_API_KEY`. Beides wird in den Einstellungen der Cloud-Umgebung eingetragen, der Key kommt nie ins Repo.

## Platzhalter

Die jetzigen Teile sind die Pixel-Figur aus Phase 1, aufgeteilt in Ebenen (`tools/sprites/bake_placeholders.py`). Sie werden nach und nach durch PixelLab-Grafik ersetzt, ohne dass sich am Spielcode etwas ändert.
