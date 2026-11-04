# Manga-Panel-UI (Stilprobe)

Stand 2026-11-04. Erste Stilprobe für das neue HUD im Manga-Panel-Look
(schwarzer Tuscherand, Papierweiß, Halbtonraster, schräge Kanten).

## Teile

| Teil | Datei | 9-Slice-Ränder (l, o, r, u) |
|---|---|---|
| Panel | `assets/ui/manga/panel.png` | 18, 18, 18, 18 |
| Lebensbalken | `assets/ui/manga/hp_bar.png` | 24, 6, 10, 6 |
| Superbalken | `assets/ui/manga/super_bar.png` | 30, 7, 14, 7 |
| Skill-Slot | `assets/ui/manga/skill_slot.png` | 14, 14, 14, 14 |
| Button | `assets/ui/manga/button.png` | 16, 12, 20, 12 |

Die Ränder stehen in `assets/ui/manga/slices.json` und werden von `scripts/ui/ui_skin.gd` gelesen.

## Pipeline

1. `python3 tools/ui_style/gen_ui.py assets/ui/manga/raw` erzeugt die 5 Teile mit PixelLab Pixen
   (1 Generierung je Teil, Key aus `PIXELLAB_API_KEY`, Prompts in `raw/log.json`).
2. `python3 tools/palette/quantize.py assets/ui/manga/raw -o assets/ui/manga --max-colors 24`
   bringt sie auf Resurrect 64 (`roh_*.png`).
3. `python3 tools/ui_style/build.py` schneidet zu (Sprechblasen-Spitze ab, Trennstriche aus dem
   Superbalken entfernt) und schreibt `slices.json`.
4. `python3 tools/ui_style/mockup.py <screenshot> <ausgabe>` legt eine Vorschau über einen Screenshot.

## Im Spiel

Das HUD (`scripts/ui/hud.gd`) nutzt den Skin standardmäßig. Taste **I** schaltet zwischen
Manga und altem UI, im Web lädt `?ui=alt` das alte UI. Große Panels bekommen die Textur,
schmale Leisten (unter 40 px) Papier mit Tuscherand, kleine Farbflächen einen schwarzen Rand,
Schrift wird Tusche mit weißem Rand.

## Offene Punkte

- Lebens- und Superbalken haben noch Gold-/Holz-Anteile statt reiner Tusche.
- Halbtonecke im Panel wird beim Strecken mitgezogen.
- Buttons sind sehr rot und lenken von den Icons ab.
