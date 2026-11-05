# Shader (Grafik-Feinschliff)

Alle Shader sind selbst geschrieben (gleiche Lizenz wie das Projekt), keine
Fremd-Shader. Sie laufen im Compatibility-Renderer (WebGL 2, Browser).

| Shader | Datei | Wo |
|---|---|---|
| Bildnachbearbeitung: Farbkorrektur, Vignette, Schockwellen, Farbversatz, Hitzeflimmern | `shaders/post/post_fx.gdshader`, `scripts/fx/post_fx.gd` | Wald (Dämmerung + flach), Akademie-Hof |
| Pixel-Auflösen mit leuchtender Naht beim Gegnertod | `shaders/fx/dissolve*.gdshader`, `Enemy._burn_away` | alle Gegner |
| Randlicht (Silhouette leuchtet, wenn eine Lampe von der Seite scheint) | `shaders/lightlook/pixel_lit.gdshader` (`rim`) | Figuren im Licht-Look |
| Wind in Baum-Ebenen (pixelgenau, Böen) | `shaders/fx/wind_sway.gdshader` | Parallax-Bäume Wald + Hof |
| Lichtstrahlen + Bodennebel (gestuft, Pixel-Blöcke) | `shaders/fx/atmosphere.gdshader`, `scripts/fx/atmosphere.gd` | Wald (Dämmerung), Hof (nur Nebel) |

## Auslöser
- `CombatFx.hit/blast`: Reaktionen und Meisterzug-Finisher erzeugen Schockwelle + Farbversatz,
  schwere Feuertreffer kurzes Hitzeflimmern. `CombatFx.flash` gibt Farbversatz, `dim` (Super-Pause) hält ihn.
- Hitzequellen: Esse im Wald und im Hof, brennende Glut-Gefahren (`GlutHazard`), heiße Glutatem-Klinge.
- Eigene Effekte: `PostFx.shockwave(pos, stärke)`, `PostFx.aberrate(px)`, `PostFx.heat_burst(pos)`,
  `PostFx.add_heat_source(node, offset, radius, stärke_oder_callable)`.

## Grafikqualität (Optionen → Grafik, Taste G)
- **Hoch**: alles.
- **Mittel**: ohne Hitzeflimmern.
- **Niedrig**: keine Bildnachbearbeitung, keine Lichtstrahlen/Nebel, Gegner blinken statt sich aufzulösen.
  Wind und Randlicht bleiben (kosten fast nichts).

## Testlauf
`xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/shader/probe.gd -- <ordner> [0|1|2] [ohne_hud]`
