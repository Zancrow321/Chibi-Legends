# Raid-Rüstung „Essenwacht“ und sechs Seltenheiten

Stand 6. November 2026. Erste Raid-Rüstung, Beute vom Essenwächter in der Glutschmiede.

## Seltenheiten (Loot)

| Index | Seltenheit | Farbe | Werte | Stärke | Sockel | Extra |
| --- | --- | --- | --- | --- | --- | --- |
| 0 `COMMON` | Gewöhnlich | `c7cfcc` | 1 | ×1,0 | 0 | |
| 1 `UNCOMMON` | Ungewöhnlich (neu) | `1ebc73` | 2 | ×1,1 | 0 | |
| 2 `RARE` | Selten | `4d9be6` | 2 | ×1,25 | 0–1 | |
| 3 `EPIC` | Episch | `a884f3` | 3 | ×1,55 | 1 | Set-Teile, Glühen |
| 4 `LEGENDARY` | Legendär | `f9c22b` | 4 | ×2,0 | 1–2 | Mod, Spruch, Glühen |
| 5 `MYTHIC` | Mythisch (neu) | `e83b3b` | 5 | ×2,5 | 2 | Mod, Spruch, Glühen + Animation |

- Immer die Konstanten `Loot.COMMON` … `Loot.MYTHIC` benutzen, keine Zahlen.
- Alte Spielstände (4 Stufen) rechnet `Profile.ensure()` einmal um (`Loot.migrate_rarity`,
  Feld `rarity_version` in `user://profil.json`). Pass- und Gacha-Daten sind umgestellt.
- Drop-Tabellen in `loot.gd`: normal 0,1 % Mythisch, Elite 1,5 %, Raid-Rüstung 2 %.

## Essenwacht (`scripts/game/raid_armor.gd`)

| Seltenheit | Name | Look |
| --- | --- | --- |
| Gewöhnlich | Essenwacht-Rekrut | Eisen und Leder |
| Ungewöhnlich | Essenwacht-Posten | geschwärztes Eisen, grüne Emaille, Kettenrock |
| Selten | Essenwacht-Hüter | polierter Stahl, blauer Wappenrock |
| Episch | Essenwacht-Glutritter | schwarz-violette Platte, Glut-Runen (glüht) |
| Legendär | Essenwacht-Schmiedekönig | Gold und Weiß, Schmelzrisse, roter Umhang (glüht) |
| Mythisch | Essenwacht-Sternenglut | Obsidian mit Sternenglut (glüht, Lichtwelle, Funkenschleier) |

- Teile: Harnisch (Oberteil), Beinschienen (Hose), Stiefel (Schuhe). Der Raid-Boss lässt bei
  Bonus-Beute immer ein Teil fallen (`RaidArmor.roll`, Tabelle `Loot.RAID_TABLE`).
- Das erste Teil einer Seltenheit schaltet den Look im Character Creator frei
  (`top/pants/shoes/hair` = `raid_<seltenheit>`; der Harnisch bringt den Helm mit).
- Glühen: `creator_tint.gdshader` (`glow`, `glow_color`, `shimmer`) hebt die Glut-Adern über 1.0,
  der Bloom macht den Rest. Funken: `LayeredBody._apply_raid_glow()`.

## Assets und Werkzeuge (PixelLab, 55 Generierungen)

- `tools/raid_armor/gen_armor.py`: Outfits (5 Raster je Stufe) und Helme (1 je Stufe).
  Ebenen: `assets/creator/parts/{top,pants,shoes}/raid_*.png`, Rohbilder in `parts/_raw/raid_*`,
  Helme `parts/hair/raid_*.png` (`clean_helms.py` entfernt Streupixel).
- `tools/raid_armor/gen_icons.py`: 18 Icons `assets/items/raid/essenwacht_<slot>_<seltenheit>.png`.
- `tools/raid_armor/preview.py`, `sheet_preview.py`: Vorschaubilder.
- Tests: `tools/raid_armor/test_armor.gd` (CI), Schaubild `tools/raid_armor/probe.gd`
  (CI legt die Bilder auf den Branch `ci-bilder/ruestung`).

## Helme decken den ganzen Kopf ab (Fix 6. November)

- Helme mit `covers_head` in `hair.json` (alle `raid_*` und `bollwerk_helm`) blenden den Kopf
  des Körpers aus (Shader `head_hide`, Kreis Radius 10 um `LayeredBody.HEAD_CENTER`) und drehen
  sich voll mit dem Kopf (auch liegend; Ankerwinkel werden auf ±180° normalisiert).
- `tools/raid_armor/helm_layers.py` schneidet die Helm-Ebene aus dem PixelLab-Bild neu
  (mit Gesicht, ohne Glatze), `clear_head_in_top.py` entfernt Kronen/Kragen-Pixel im Kopfkreis
  der Oberteile, `helm_preview.py` zeigt alle 68 Posen wie im Spiel.
