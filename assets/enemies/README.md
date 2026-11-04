# Gegner

Die ersten Gegner des Trainingswalds. Jede Figur hat einen Ordner mit
Animations-Streifen (`idle`, `walk`, `attack`, `hurt`, `death`; Bilder
nebeneinander). `frames.json` hält pro Figur Zellgröße, Fußlinie und
`[Bilder, Bilder pro Sekunde]` je Animation. Werte, KI-Art und Größe stehen in
`scripts/enemies/enemy.gd` (`TYPES`), die Wellen in `scripts/enemies/enemy_waves.gd`.

| Gegner | Art | Herkunft |
| --- | --- | --- |
| Moosling | hüpft heran, Bauchklatscher | eigen, PixelLab (`tools/enemies/gen_enemies.py`, `finish.py`) |
| Rindenwicht | Keule von oben | eigen, PixelLab |
| Moosgolem (Elite) | schwerer Schlag, Super-Rüstung | Duelyst `neutral_golemnature` |
| Sumpfdorn | duckt sich, Sprungangriff | Duelyst `neutral_beastswamp` |
| Säbeltiger | weiter Sprungangriff | Duelyst `neutral_beastsaberspinetiger` |
| Glutigel | Feueratem auf kurze Distanz | Duelyst `neutral_gro` |

`raw/` enthält die unbearbeiteten PixelLab-Ergebnisse (bezahlt, deshalb im Repo).

## Lizenz der Duelyst-Figuren

Quelle: Godot-Asset-Library-Eintrag 1653 „Duelyst Animated Sprites“ von Jordyfel
(https://github.com/Jordyfel/duelyst-animated-sprites-godot, Commit d129aeef5678),
Grafiken aus Open Duelyst (https://github.com/open-duelyst/duelyst).
Lizenz: **CC0 1.0** (Public Domain), Text in `LICENSE-duelyst-CC0.txt`.
Namensnennung ist nicht nötig; wir nennen Duelyst / Counterplay Games und
Jordyfel trotzdem im Abspann.

Wir übernehmen nur die vier Figuren oben (das ganze Addon hat 123 MB), umgewandelt
mit `tools/enemies/import_duelyst.py`. Weitere Figuren: Namen dort in `UNITS`
eintragen und das Skript erneut laufen lassen.
