# Raids (Schritt 1: Boss-System offline)

Erster Raid: **Glutschmiede** (Tor rechts im Akademie-Hof, im Web direkt mit `?modus=raid`).
Boss: **Essenwächter**, ein Schmiede-Golem aus Eisen und Glut (PixelLab, `tools/raid/gen_boss.py`).
Plan und Hintergrund: Design-Dokument „Kampf-Endgame“ (Abschnitt Raids und Bosse).

## Regeln

| Baustein | Wie es funktioniert |
| --- | --- |
| Wucht-Leiste | Treffer lassen den Boss nicht zucken, sie ziehen Wucht ab (schwere Treffer mehr, Druckbruch doppelt, Perfekt-Block 45). Leer = **Bruch**: 4 s taumeln, +50 % Schaden, jonglierbar. Jeder weitere Bruch braucht 12 % mehr Wucht. |
| Gesperrt | Während Glutregen, Ansturm und Essensturm ist die Leiste gesperrt (roter Rand), nur Ausweichen hilft. |
| Schild-Phasen | Bei 70 % und 35 % HP: Glutschild, Boss unverwundbar, Kristalle erscheinen auf den Plattformen. Alle zerstört = sofort Bruch. Zeit um = **Essensturm** (Feuer auf dem ganzen Boden, rauf auf eine Plattform). |
| Angriffe | Hammerschlag (vorne + zwei Schockwellen am Boden, drüberspringen), Glutschwung (weiter Schwung), Glutregen (markierte Stellen), Ansturm (ab Phase 2, quer durch die Arena). |
| K.o. | Neuer Versuch: Boss steht wieder voll da, Spieler am Eingang. |
| Sieg | Normale Elite-Beute plus 2 Teile ab Episch und ein Edelstein. Auswahl-Truhe und Tageschance kommen mit Schritt 5. |

## Skalierung (`scripts/raid/raid_scaling.gd`)

| Spieler | Boss-HP | Wucht | Kristalle | Schildzeit |
| --- | --- | --- | --- | --- |
| 1 | 2600 | 260 | 2 | 20 s |
| 2 | ×1,8 | ×1,5 | 3 | 20 s |
| 3 | ×2,5 | ×1,9 | 4 | 24 s |
| 4 | ×3,2 | ×2,3 | 4 | 20 s |

Offline spielt man allein; `?spieler=2..4` im Web-Link testet die größeren Stufen.

## Dateien

- `scripts/raid/boss.gd` (Boss, erbt von Enemy), `shield_crystal.gd`, `boss_hazard.gd` (Schockwelle, Glutregen-Marker, Essensturm), `raid_director.gd`, `raid_boss_bar.gd`, `raid_scaling.gd`
- Sprites: `assets/enemies/essenwaechter/` (Eintrag in `frames.json`, drittes Feld = Treffer-Bild), `assets/raid/kristall.png`, Rohdaten in `assets/raid/raw/`
- Test: `tools/raid/probe.gd` (CI-Schritt „Raid-Logiktest“)
