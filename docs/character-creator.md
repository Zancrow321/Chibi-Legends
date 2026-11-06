# Character Creator

Stand 4. November 2026, Phase 2. Bauplan: https://claude.ai/artifact/H8CuS75tF2oALgy7kbGptL

## Aufbau einer Figur

| Ebene | Art | Daten |
| --- | --- | --- |
| Körper (Haut) | eine Zeichnung pro Pose | `assets/creator/body/sheet.png` |
| Hose, Schuhe, Oberteil | eine Zeichnung pro Pose, gleiche Reihenfolge | `assets/creator/parts/<slot>/<id>.png` |
| Frisur | einmal gezeichnet, sitzt am Kopfanker | `assets/creator/parts/hair/<id>.png` + `hair.json` |
| Waffe | einmal gezeichnet, sitzt an der vorderen Hand | `assets/creator/weapons/`, Griff/Spitze in `catalog.json` |
| Waffen-Band | Code (Verlet-Seil), keine Grafik | `ribbon` in `catalog.json` |

68 Posen: 60 gemeinsame plus 8 Zweihand-Varianten (`th_*`). Reihenfolge und Skelett:
`tools/pixellab/creator_base/frames.json`. Anker (gemessen auf dem Haut-Körper):
`assets/creator/base/anchors.json`. Winkel: 0° = nach unten, positiv = nach vorne.

Farben: `assets/shaders/creator_tint.gdshader`. Kleidung und Haare über eine
Verlaufs-Map auf eine Zielfarbe (Schattierung bleibt), Haut über eine HSV-Verschiebung
nur auf warmen Tönen. Die Farbfelder stehen in `catalog.json` unter `colors` und `skins`.

## Im Spiel

- `LayeredBody` (`scripts/creator/layered_body.gd`): `look = CreatorCatalog.load_look()`,
  `play("run")`, `set_pose("slash_hit")`, `facing = -1`, Signal `pose_changed`.
  Animationen in `catalog.json` unter `animations`.
- `CreatorScreen` (`scripts/creator/creator_screen.gd`): Taste **O**, beim ersten Start automatisch.
  Speichert nach `user://figur.json`.
- Die Kampffigur (`FighterSprite`/`player.gd`) nutzt `LayeredBody` noch nicht; das
  verdrahtet der Kampf-Thread.

## Neue Kleidung erzeugen (PixelLab)

```
cd tools/pixellab/creator_base
python3 outfit_layers.py outfit <id> "<Beschreibung auf Englisch>"   # 5 Generierungen pro Outfit
python3 hair.py <id> "<Frisur auf Englisch>"                          # 1 Generierung
```

Danach den Eintrag in `assets/creator/catalog.json` ergänzen. `outfit_layers.py split <id>`
zerlegt ein Outfit ohne neue Generierung erneut. Der günstige Weg: 16 Posen als 4x4-Raster
in einem `edit-image-pixen`-Aufruf (1 Generierung), statt 10 Generierungen pro Einzelbild.

## Entscheidungen

- 2026-11-04: Character Creator statt fester Gacha-Charaktere. Ein Grundkörper, schlank, ca. 28 × 56 px.
- 2026-11-04: Level pro Fighting Style. Etwa 7 Skills pro Style, jeder Skill hat Alternativen.
- 2026-11-04: Waffen sind eigene Ebenen am Handanker (austauschbar).
- 2026-11-04 (eigenständig entschieden, Kaiser war unterwegs): Mischform für Zweihänder,
  8 Zweihand-Posen für Stehen und schwere Angriffe, alles andere einhändig.
- 2026-11-04 (eigenständig): Haut-Körper mit dunklen Shorts als Unterlage, Kleidung wird über
  Hautpixel gelegt. Anker werden auf dem Haut-Körper gemessen.

## Bekannte Grenzen

- Die Ebenen werden nach Körperregion zerlegt. Bei weiten Teilen (Gi über der Hüfte)
  landet ein Stück im falschen Slot. Beim Mischen fällt das kaum auf.
- Die Frisur dreht sich nur bei deutlicher Kopfneigung mit. Bei liegenden Posen
  kann sie leicht verrutschen.
- Pixel-Art-Drehung der Waffe in Godot ist etwas kantig.

## Phase 3: mehr Teile und Freischalten (2026-11-04)

- Neu: Outfits **Schattenwickel** (schatten), **Schmiede-Schürze** (schmied), **Akademie-Jacke** (akademie),
  Frisuren **Kurzhaar, Zwillingszöpfe, Lange Mähne, Stachelkamm**. Kosten: je Outfit 5 Generierungen
  (pixen auf 16er-Raster), je Frisur 1. Zusammen 19.
- Freischalten: `scripts/creator/creator_unlocks.gd` (CreatorUnlocks). Ein Teil ist frei, wenn es in
  `catalog.json` unter `slots.<slot>.unlock` keinen Eintrag hat; der Eintrag ist der Hinweistext.
  Farben 5 bis 8 haben `unlock` in `colors`. Hauttöne sind immer frei.
  Spielcode schaltet frei mit `CreatorUnlocks.unlock("top", "ronin")` bzw. `unlock_color(6)`;
  gespeichert in `user://freigeschaltet.json`.
- Im Creator: gesperrte Teile/Farben sind sichtbar (rot mit "x", Farbfeld abgedunkelt), lassen sich
  ansehen, aber "Fertig" ist gesperrt, solange etwas Gesperrtes gewählt ist; unter der Bühne steht,
  wie man es bekommt. Zufall nimmt nur Freies. F9 schaltet zum Testen alles frei.
- Kampfstil-Zeile: `look.style` (Liste in `catalog.json` unter `styles`), der Spieler lädt
  `FightingStyle.load_style(look.style)`. Bisher nur Glutatem.
- Offen: Freischalt-Aufrufe an echte Ereignisse hängen (NPC-Dialoge, Trainingswald-Abschluss, Truhen).

## Bollwerk-Teile (2026-11-04)

- Outfit **bollwerk** (Panzer, Beinpanzer, Stiefel) und Kopfteil **bollwerk_helm** im Frisur-Slot
  (deckt den ganzen Kopf ab). Gesperrt: „Gacha-Banner „Die letzte Linie““.
- Lehre: Bei sperrigen Outfits verändert PixelLab manchmal die Posen eines Rasters.
  `tools/bollwerk/fix_outfit_grids.py` misst je Raster, wie viel vom Grundkörper bedeckt ist,
  und erzeugt schlechte Raster neu (1 Generierung pro Raster). Eine Referenzfigur in Zelle 16
  hat nicht funktioniert (Modell zog die Figuren kaum an).

## Anime- und japanische Kleidung (2026-11-06)

Eigene Entwürfe, keine Kostüme aus bestimmten Serien. PixelLab: 78 Generierungen
(8 Entwürfe, 32 Raster, 4 Kopfteile, 34 Nachbesserungen verrutschter oder nicht angezogener Posen).

| Outfit (id) | Freischalten |
| --- | --- |
| Sommer-Yukata (`yukata`) | Saisonpass gratis, Stufe 7 |
| Gakuran (`gakuran`) | Saisonpass Premium, Stufe 6 |
| Hanabi-Kimono (`hanabi`) | Saisonpass Premium, Stufe 12 |
| Matrosen-Uniform (`matrose`) | Saisonpass Premium, Stufe 16 |
| Kranich-Haori (`kranich`) | Saisonpass Premium, Stufe 22 |
| Mond-Hakama (`mondhakama`) + Strohhut `kasa` | Gacha-Banner „Der schwarze Mond“ |
| Shinobi-Anzug (`shinobi`) + Stirnband `hachimaki` | Gacha-Banner „Ein Versprechen wird Stärke“ |
| Schreingewand (`miko`) + Fuchsmaske `kitsune` | Gacha-Banner „Ein Takt, zwei Seelen“ |
| Samurai-Knoten (`chonmage`) | frei |

- Saisonpass: Belohnung `{"kind": "part", "slot": "outfit", "id": ...}` schaltet Oberteil, Hose und Schuhe zusammen frei.
- Werkzeuge in `tools/japan_outfits/`: `gen_outfits.py` (draft/outfit/head/install), `fix_frames.py`
  (schlechte Einzelposen in ein eigenes Raster, `--dress` auch für Posen, in denen PixelLab die Figur
  nackt gelassen hat), `check_dressed.py` (findet solche Posen), `preview.py`, `probe.gd` (Bild im Spiel),
  `test_outfits.gd` (CI).
- Lehre: Liegende Posen (`lie_0`, `getup_*`) und Siegesposen (`win_*`, `taunt_*`, im letzten Raster nur
  4 Figuren) lässt PixelLab öfter unbekleidet oder verschiebt sie. Ein Raster nur aus den schlechten
  Posen klappt deutlich besser als das ganze Raster neu.

## Themen-Kollektion Cyberpunk (2026-11-06)

Sechs Outfits und zwei Kopfteile, frei über neue Bestmarken im Turm der Prüfungen
(`scripts/game/theme_outfits.gd`, `ThemeOutfits.TOWER`). PixelLab: 47 Generierungen.

| Etage | Teil |
| --- | --- |
| 5 | Daten-Hoodie (`datenhoodie`) |
| 10 | Neonläufer (`neonlaeufer`) |
| 15 | Neon-Irokese (`neonkamm`, Kopfteil) |
| 20 | Synth-Idol (`synthidol`) |
| 25 | Chrom-Söldner (`chromsoeldner`) |
| 30 | Neon-Visier (`neonvisier`, Kopfteil) |
| 40 | Straßenklinge (`strassenklinge`) |
| 50 | Konzern-Agent (`konzern`) |

- Neon-Leuchten: `catalog.json` → `neon` (id → Farbe). `LayeredBody` setzt dann den Glüh-Shader
  der Raid-Rüstung auf die Leuchtstreifen in dieser Farbe (Bloom).
- Weitere Themen: Beschreibungen in `tools/japan_outfits/gen_outfits.py` ergänzen, dann
  `draft`, `outfit`, `head`, `install`, `fix_frames.py`, `check_dressed.py` wie oben.

## Themen-Kollektion Frostnorden (2026-11-06)

Fünf Outfits und zwei Kopfteile, frei über Spielerstufen (`ThemeOutfits.LEVEL`, beim Stufenaufstieg
werden auch verpasste Stufen nachgeholt). PixelLab: 38 Generierungen.

| Stufe | Teil |
| --- | --- |
| 3 | Nordwanderer (`nordwanderer`) |
| 6 | Runenschild (`runenschild`) |
| 9 | Nordzöpfe (`flechtbart`, Kopfteil) |
| 12 | Eisjäger (`eisjaeger`) |
| 15 | Frostseherin (`frostseherin`, Runen leuchten) |
| 18 | Hörnerhelm (`hoernerhelm`, Kopfteil) |
| 22 | Bärenhaut (`baerenhaut`) |

- Lehre: Kapuzen nicht beschreiben ("no hood, head uncovered"). Der Kopf gehört zum Grundkörper,
  eine Kapuze wird abgeschnitten. Lange Zöpfe am Helm hängen vor das Gesicht.

## Themen-Kollektion Wuxia-Hof (2026-11-06)

Fünf Outfits und zwei Kopfteile. PixelLab: 37 Generierungen.

| Teil | Freischalten |
| --- | --- |
| Jade-Gelehrter (`jadegelehrter`) | Wochen-Herausforderung Elite-Gegner (`w_elite`) |
| Schattenmeister (`schattenmeister`) | Wochen-Herausforderung Meisterzüge (`w_super`) |
| Pflaumentänzerin (`pflaumentaenzerin`) | Wochen-Herausforderung Wellen (`w_wave`) |
| Jade-Haarknoten (`gelehrtenknoten`) | Wochen-Herausforderung Gegner (`w_kill`) |
| Lotusfaust (`lotusfaust`) + Drachenkrone | Gacha-Banner „Über jedes Limit“ |
| Drachenwache (`drachenwache`) | Gacha-Banner „Wer am Feuer sitzt“ |

- Herausforderungen können jetzt `"part": ["outfit", id]` geben (alle drei Teile, `ThemeOutfits.give`).

## Themen-Kollektion Vampirhof (2026-11-06)

Fünf Outfits und zwei Kopfteile. PixelLab: 34 Generierungen.

| Teil | Freischalten |
| --- | --- |
| Blutgraf, Mondgräfin, Zylinder | Gacha-Banner „Der schwarze Mond“ |
| Jägerorden, Kirchhofwächter, Silberlocken | Gacha-Banner „Ein Takt, zwei Seelen“ |
| Rosendiener (Butler) | Saisonpass Premium, Stufe 27 |

- Schrift-Fix: Pixelify zeigte die Ligaturen „fi“/„fl“ als Müll (z. B. „Schaffe“, „Lauffeuer“). Im Import
  der Schrift ist `liga` jetzt aus (`opentype_features` in `PixelifySans-SemiBold.ttf.import`).

## Themen-Kollektion Steampunk (2026-11-06)

Fünf Outfits und zwei Kopfteile. PixelLab: 32 Generierungen.

| Teil | Freischalten |
| --- | --- |
| Messingfaust, Kesselflicker, Fliegerbrille | Gacha-Banner „Die letzte Linie“ |
| Luftkapitän, Melone mit Zahnrad | Gacha-Banner „Kein Meer zu weit“ |
| Zahnrad-Techniker / Dampf-Erfinderin | Spielerstufe 26 / 30 (`ThemeOutfits.LEVEL`) |
