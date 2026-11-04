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

## Bewegungs- und Angriffs-Strips (Kampf flüssiger, 2026-11-04)

Aus `testfigur2_still.png` (64er Ausschnitt ab x 12, y 28) mit PixelLab
`animate-with-text-v3` animiert (je 8 Frames, Seed 11, je 1 Generierung),
auf die 15 Farben des Standbilds gerundet (`remap.py`) und in 96er Zellen gesetzt
(Fußpunkt x 44, y 88). `FighterSprite` nimmt sie automatisch, wenn die Datei da ist.

| Datei | Frames | Prompt (gekürzt) |
| --- | --- | --- |
| `testfigur2_run.png` | 8 (Loop) | strict side view, fast anime sprint run cycle |
| `testfigur2_jump.png` / `_fall.png` | 3 / 3 | crouch then leap, knees tucked, falling with legs extended |
| `testfigur2_dash.png` | 4 | explosive forward dash, body low |
| `testfigur2_heavy.png` | 8 | big wind-up, heavy downward strike (Schwerer Hieb / Breithieb) |
| `testfigur2_slash2.png` | 8 | quick backhand slash (zweiter leichter Schlag) |
| `testfigur2_hurt.png` | 4 | hit in the chest, recoiling backward |
