# Pixel-Art-Effekte (optional)

Alle Kampfeffekte werden per Code gezeichnet (`scripts/fx/hit_sparks.gd`).
Einzelne Effekte lassen sich mit handgezeichneten Frames ergänzen:
Lege hier einen Sprite-Streifen als PNG ab, quadratische Frames nebeneinander
(z. B. 6 Frames à 48×48 px = 288×48 px). Er wird mit 30 fps additiv über dem
Code-Effekt abgespielt und in Schlagrichtung gespiegelt.

| Datei | Wann |
|---|---|
| `hit_phys.png` / `hit_phys_heavy.png` | Katana-Treffer, leicht / schwer |
| `hit_feuer.png`, `hit_frost.png`, `hit_blitz.png`, `hit_wind.png` | Element-Treffer (mit `_heavy` für schwere) |
| `blast.png` | Reaktionen und Super-Finale |

Nur eigene Grafiken verwenden, keine Sprites aus anderen Spielen.
