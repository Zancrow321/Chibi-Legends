# Effekt-Skins der Kampfstile

Ein Effekt-Skin färbt **alle Effekte eines Kampfstils** um, zum Beispiel grünes
Feuer für Glutatem. Skins sind reine Optik: keine Werte, kein Vorteil.

## Was umgefärbt wird

- Funken, Flammen, Rauch, Wellen, Ringe und Schriftzüge der Züge
- die PixelLab-Effektstreifen (Schnittbögen, Explosionen, Strahlen ...)
- der Meisterzug mit allen drei Varianten
- Geschosse, Herde, Wände, Granaten und Klone, die der Stil erzeugt
- die kurzen echten Lichtblitze (grünes Feuer wirft grünes Licht)
- die Schwungspur von J/K

Die Figur, die Gegner und das HUD bleiben, wie sie sind. Die allgemeinen
Treffer-Funken und Schadenszahlen gehören allen und bleiben ebenfalls.

## Die Skins

| Stil | Skins |
| --- | --- |
| Glutatem | Giftglut (grün), Blauglut (blau), Schattenglut (violett/rosa) |
| Lauffeuer | Irrlicht (türkisgrün), Seelenfeuer (blau), Purpurbrand (magenta) |
| Schwarzmond | Blutmond (rot), Goldmond (gold), Leermond (fahles Violett) |
| Gleichklang | Totenrot (rot), Mondsilber (silbern), Seelengrün (grün) |
| Bollwerk | Rotalarm (rot), Tarnfeld (oliv/grün), Violettplasma (violett) |
| Wirbelwille | Glutwind (orange/rot), Sturmviolett (violett), Goldwind (gold) |
| Grenzbrecher | Goldaura (gold), Purpur-Ki (violett), Zornrot (rot) |
| Spannkraft | Eiskraft (eisblau), Giftkraft (grün), Nachtkraft (violett/rosa) |

## Freischalten

- **Glutatem** (Starter-Stil, kein Banner): Saisonpass. Giftglut gratis auf
  Stufe 4, Blauglut (Stufe 10) und Schattenglut (Stufe 25) in der Premium-Spur.
- **Alle anderen Stile**: Episch-Preis im Sternschrein-Banner des Stils, neben
  den Creator-Teilen des Banners.
- Test: F9 im Sternschrein schaltet alles frei, auch alle Skins.

## Auswählen

Im Stil-Menü (Tab) gibt es unten die Zeile **Effekt-Skin**. Links/Rechts
wechselt zwischen den freigeschalteten Skins, Klick auf eine Karte geht auch.
Der Wechsel wirkt sofort, auch auf Effekte, die gerade laufen. Gesperrte Skins
zeigen, woher man sie bekommt. Gespeichert wird in `user://skins.json`.

## Technik

- Daten: `assets/combat/skins.json` (Farbton drehen in Grad, Sättigung,
  Helligkeit, optional ein Farbverlauf `ramp` über die bunten Stellen).
- Code: `scripts/fx/style_skin.gd`. Jeder CanvasItem der Stil-Effekte bekommt
  ein ShaderMaterial mit derselben Mischart wie vorher (additiv, unbeleuchtet
  ...), das danach die Farbe dreht. Weiß und Grau bleiben, HDR-Werte über 1
  bleiben, das Bloom leuchtet also weiter. Eigene Shader (Hitzeflimmern) und
  Lichter werden nicht angefasst, Lichtfarben dreht `map_color` auf der CPU.
- Der Spieler-Stil hat dafür eine eigene Effektebene (`GlutCaster.fx`, Kind von
  `room.glut_fx`), damit Gegnerflammen orange bleiben.
- Icons in Menü, Schrein und Pass sind die PixelLab-Skill-Icons, pixelweise
  mit demselben Skin umgefärbt (`StyleSkin.icon`).
- Test: `tools/skins/test_skins.gd` (CI), Schaubild: `tools/skins/probe.gd`.

Neuer Skin: Eintrag in `skins.json` ergänzen, fertig. Neuer Stil: sein Caster
muss von `GlutCaster` erben und Geschosse/Supers mit `caster = self` erzeugen,
dann wird alles automatisch umgefärbt.
