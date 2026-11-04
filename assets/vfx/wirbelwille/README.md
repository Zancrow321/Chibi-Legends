# Wirbelwille-Effekte

Effekte für den Kampfstil Wirbelwille (`docs/stil-wirbelwille.md`), erzeugt mit
PixelLab `/vfx` (Effektkünstler „lite“, je Effekt ca. 1 Generierung).

- `<name>.png`: Frames nebeneinander, Größe und Dauer je Frame in `effects.json`.
- `raw/<name>/`: Original-Download (GIF, Sheet, Game-Pack-ZIP, Ergebnis-JSON mit `effect_id`
  zum Nachbearbeiten auf pixellab.ai).
- Neu erzeugen: `tools/wirbelwille/gen_vfx.py`, Streifen bauen: `tools/wirbelwille/finish.py`.

Im Spiel additiv zeichnen und mit Bloom (`scripts/fx/bloom.gd`) hochziehen; Rauch
(`poff`, `strohpuppe`) normal mischen, sonst wird er weiß.

| Effekt | Zug |
|---|---|
| kreiselfaust (Schleife) / kreiselfaust_treffer | Zug 2 Kreiselfaust |
| poff | Windschatten vergeht |
| windschatten_entstehen | Windschatten erscheint |
| strohpuppe | Zug 4 Wechselhülle |
| fadenwehr | Zug 4 Alternative Fadenwehr |
| windstoss | Wirbelsturz-Windstoß, Kombi Wind + Feuerfläche |
| wirbelsturz_aufprall | Zug 6 Wirbelsturz |
| sturmrad (Schleife) / sturmrad_abschluss | Meisterzug A |
| orkanmantel (Schleife) / orkanmantel_ausbruch | Meisterzug C |
