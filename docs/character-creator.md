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
