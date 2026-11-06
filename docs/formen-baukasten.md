# Kampfstil-Baukasten (30 Stile)

Die 30 Kampfstile aus `docs/formen-liste.md` haben keinen eigenen Code. Sie sind
reine Daten (`assets/combat/styles/<id>.json` mit `"caster": "form"`), die ein
gemeinsamer Caster und ein gemeinsamer Meisterzug ausführen. Ein neuer Stil
braucht also nur einen Eintrag in `tools/formen/defs_*.py`.

## Ablauf

1. Stil in `tools/formen/defs_a.py`, `defs_b.py` oder `defs_c.py` eintragen. Die
   Helfer stehen in `defs_common.py`.
2. `python3 tools/formen/build.py` ausführen. Das schreibt die Stil-JSONs,
   `assets/combat/formen/prompts.json`, die Einträge im Creator-Katalog und
   im Sternschrein (`form_<id>`) sowie `docs/formen-liste.md`. Es prüft dabei 6
   Züge, je 3 Alternativen, 3 Meisterzug-Varianten und genau 50 SP.
3. `python3 -I tools/formen/gen_fx.py <stil> ...` erzeugt mit PixelLab je Stil 9
   Effekt-Sprites (128 px, `assets/combat/vfx/<stil>/`) und 10 Icons (48 px,
   `assets/combat/icons/<stil>/`). Vorhandene Dateien werden übersprungen. Ein
   Lauf mit 100 oder mehr Bildern bricht ab. `--weapons` erzeugt die Waffen.
4. `godot --headless --fixed-fps 60 -s res://tools/formen/test_formen.gd`
   wirkt jeden Zug mit jeder Alternative und jeden Meisterzug.

## Code (`scripts/formen`)

| Datei | Aufgabe |
| --- | --- |
| `form_caster.gd` | `FormCaster`: alle Zug-Arten, die sechs Kern-Mechaniken, Posen, HUD-Werte |
| `form_hazard.gd` | `FormHazard`: Geschosse, Säulen, Wellen, Felder und Regentropfen in der Welt |
| `form_super.gd` | `FormSuper`: Meisterzug mit Einblendung und sechs Arten |
| `form_fx.gd` | `FormFx`: Strahlen, Säulen und Flächen zusätzlich zu `FederFx` (additiv, Bloom) |
| `form_icons.gd` | `FormIcons`: Skill-Icons auf einer Platte in den Stilfarben |

## Zug-Arten (`kind`)

| Art | Was passiert | wichtige Werte |
| --- | --- | --- |
| hieb | Nahkampf-Kette | damage, hits, lunge, launch |
| geschoss | Projektil, gerade, ballistisch, zielsuchend oder Bumerang | damage, speed, count, spread, homing, grav, pierce, burst |
| sturm | Ansturm nach vorn | damage, dist, speed, trail, nova |
| saeule | Säulen aus dem Boden | damage, count, step, width, h, launch |
| sturz | Sprung und Einschlag | damage, hop, radius, crater, aftershock |
| konter | Haltung, kontert den nächsten Treffer | stance, counter_damage, reflect |
| aura | Stärkung für einige Sekunden | buff, life, armor, heal |
| feld | Feld am Boden mit Ticks | damage, width, tick, life, pull |
| strahl | Strahl nach vorn | damage, len, width, angle, tick |
| schritt | Teleport-Schritt mit Schnitt | damage, dist, behind, back |
| regen | Regen von oben | damage, count, width, delay |
| wirbel | Drehwirbel | damage, radius, hits, pull, drift, ride |

Eine Alternative überschreibt einzelne Werte. `enhanced` (L halten, eine Stufe
Legendenleiste) addiert `<wert>_add` oder multipliziert `<wert>_mul`.

## Kern-Mechaniken (`kern.type`)

| Kern | Regel |
| --- | --- |
| rhythmus | Verschiedene Züge hintereinander bauen Stufen auf. Ab Stufe 3 bekommt der nächste Zug einen Bonus. |
| ladung | Treffer laden auf. Bei 5 Ladungen kommt die Überladung für 6 Sekunden. |
| marken | Treffer setzen Marken (6 s). Der Zünder-Zug sprengt alle Marken. |
| echo | Jeder Zug schlägt nach 0,4 s mit 40 % Schaden noch einmal zu. |
| blutzoll | Jeder Zug kostet 3 % LP und macht dafür bis zu 60 % mehr Schaden. |
| fokus | 1,5 s ohne Angriff sammelt Ruhe. Der nächste Zug macht bis zu 60 % mehr Schaden. |

## Meisterzug-Arten

strahl (Riesenstrahl), regen (Bildschirm-Regen), nova (Explosion um dich),
ansturm (Schnitt-Ansturm), feld (Bildschirm-Feld), saeulen (Säulenreihe).
