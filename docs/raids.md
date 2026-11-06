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
| Sieg | Normale Elite-Beute plus ein Teil ab Episch, ein Teil der Raid-Rüstung **Essenwacht** (alle sechs Seltenheiten, siehe `docs/raid-ruestung.md`) und ein Edelstein. Auswahl-Truhe und Tageschance kommen mit Schritt 5. |

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

# Turm der Prüfungen (Endloser Turm, Schritt 2)

Solo-Modus hinter dem violetten Tor ganz rechts im Akademie-Hof (Web-Link `?modus=turm`). Etage um Etage, jede härter; ein K.o. beendet den Lauf.

| Regel | Wert |
| --- | --- |
| Start | Etage 1 beginnt, sobald man nach rechts in die Arena läuft. |
| Gegner pro Etage | 2 + Etage/2, höchstens 6. Neue Arten kommen dazu: Säbelzahn ab 4, Moosgolem ab 7. |
| Stärke | HP ×(1 + 0,18 je Etage), Schaden ×(1 + 0,07 je Etage). Etage 10: HP ×2,6, Schaden ×1,6. |
| Turmwache | Jede 5. Etage: kleiner Essenwächter (35 % HP × Etagen-Faktor, 60 % Wucht). Ab Etage 15 eine Schild-Phase bei 50 %. |
| Lohn | Jede Etage 5 × Etage Splitter. Jede Turmwache ein Teil ab Selten, Gegenstandsstufe = Spielerstufe + Etage/5. Normale Gegner-Beute läuft weiter. |
| Ende | K.o. = Lauf vorbei, nach 3 s wartet wieder Etage 1. |
| Rekord | `user://turm.json`: beste Etage gesamt und pro Woche (Wochenwechsel Montag). Die Wochen-Bestenliste kommt mit der Online-Basis (Schritt 3). |

Dateien: `scripts/raid/tower_director.gd` (erbt vom RaidDirector, nutzt Boss-Leiste, Kristalle und Gefahrenzonen mit), Tor-Sprites `assets/overworld/gate_turm.png` und die offene `gate_glut.png`, Test `tools/tower/probe.gd` (CI-Schritt „Turm-Logiktest“).

# Raid-Beute: Tageschance und Raid-Marken (Teil von Schritt 3, offline)

`scripts/raid/raid_loot.gd`, Test `tools/raid/test_loot.gd` (CI „Raid-Beute-Test“).

| Regel | Wert |
| --- | --- |
| Farmen | Unbegrenzt. Die Bonus-Beute des Essenwächters (2 Teile ab Episch + Edelstein) kommt mit 100 %, 60 %, 36 %, 22 %, dann 20 % je Sieg am selben Tag. Um Mitternacht wieder voll. Die normale Elite-Beute fällt immer. |
| Raid-Marken | Immer: Essenwächter 4, Turmwache 1. Anzeige oben rechts im Hof. |
| Tausch | Bei Schmiedin Hino („Raid-Marken tauschen“): Teil-Art frei wählbar, Werte zufällig, Gegenstandsstufe = Spielerstufe. Episch 20 Marken, Legendär 60 (mit Veränderung). |
| Online | Wenn die Online-Basis steht, zählt der Server dieselben Werte; offline liegen sie in `user://raid_loot.json` und im Profil. |

# Weltenriss: Weltboss Donnerhorn (Schritt 8, ohne Kampfserver)

Ganz rechts im Hof ist der Himmel aufgerissen. Drinnen tobt Donnerhorn, ein Sturm-Koloss
(PixelLab, `tools/raid/gen_boss.py`, `tools/raid/finish_boss.py donnerhorn`). Jeder kämpft in
seiner eigenen Arena, aber alle gegen dieselbe Lebensleiste (Supabase, siehe docs/online.md).

- Kein Schild, dafür Wucht-Leiste und Bruch wie beim Essenwächter. Phasen nach der gemeinsamen
  Leiste: unter 66 % und 33 % wird er schneller und stürmt los.
- Blitze statt Glut: Schockwellen, Blitzeinschläge und Sturmflut in Blau (`BossHazard.storm`).
- K.o. setzt nur dich zurück, der Boss behält seine Lebenspunkte. Dein Schaden zählt weiter.
- Rechts unter der Karte: wer gerade kämpft, dein Schaden und Anteil, die besten fünf.
- `scripts/raid/world_boss.gd`, `world_boss_director.gd`, `world_boss_panel.gd`;
  Probe `tools/worldboss/probe.gd`; im Web `?modus=weltboss`.
