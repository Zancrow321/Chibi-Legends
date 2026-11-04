# Testfigur im Manga-Chibi-Stil

Stil-Test für den neuen Look (siehe `docs/artstyle-jus.md`). Noch nicht im Spiel eingebunden.

- `testfigur_still.png`: Standbild, 96 × 96 (PixelLab pixflux, Seed 22)
- `testfigur_idle.png`: idle, 5 Frames à 96 × 96
- `testfigur_slash.png`: Schwertangriff, 8 Frames à 96 × 96 (Treffer-Frame: 7)

Erzeugt mit `tools/jus_style/` (gen_still.py, gen_anim.py, build_strips.py), Vorschau mit `mockup.py`.

## Test 2 (nach Referenz-Messwerten)

- `testfigur2_still.png`, `testfigur2_idle.png` (5 Frames), `testfigur2_slash.png` (7 Frames), alle in 96er Zellen, Fußpunkt x 44, y 88.
- Figur ca. 34 × 55 px, 15 Farben (alle Frames auf die Palette des Standbilds gerundet).
- Erzeugt auf 64er Leinwand (`gen_still_small.py`, pixflux Seed 22), Farben mit `reduce.py`, Zellen mit `to_cell.py`, Palette mit `remap.py`.
