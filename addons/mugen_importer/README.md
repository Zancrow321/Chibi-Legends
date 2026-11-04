# M.U.G.E.N-Importer

Godot-Editor-Plugin, das einen M.U.G.E.N-Charakter in unser Format umwandelt:
Bilderstreifen (PNG) plus eine Moveset-Datei, die der Kampf-Prototyp direkt lädt.

> **Nur eigene oder lizenzierte Figuren.** Importiere nur Charaktere, die du selbst
> gemacht hast oder deren Lizenz die Weiterverwendung in unserem Spiel ausdrücklich
> erlaubt. Fan-Rips von Anime-, Manga- oder Spielfiguren (z. B. aus Bleach, Naruto,
> Jump Ultimate Stars) dürfen weder importiert noch committet noch ausgeliefert
> werden, auch nicht "nur zum Testen". Der Importer verlangt deshalb vor jedem
> Import eine Bestätigung und schreibt sie mit Autor in die Moveset-Datei.

## Benutzen

1. Projekt im Godot-Editor öffnen. Das Plugin ist aktiv (Projekt → Projekteinstellungen → Plugins).
2. Rechts oben im Dock **M.U.G.E.N** auf **Wählen…** klicken und die `.def` des Charakters wählen.
3. ID (Dateiname im Spiel) prüfen, Figurenhöhe bleibt normal bei 56 px.
4. Häkchen bei den Rechten setzen, **Importieren** klicken.
5. Spiel starten und mit **M** zum neuen Kämpfer wechseln.

Ohne Editor geht es auch über die Kommandozeile:

```
godot --headless --path . -s addons/mugen_importer/cli.gd -- pfad/figur.def --id=figur --rechte-bestaetigt
godot --headless --path . --import
```

## Was wird übernommen

| M.U.G.E.N | bei uns |
|---|---|
| `.sff` v1 (PCX, `.act`-Palette) und v2 (RLE8, RLE5, LZ5, PNG) | Bilder |
| `.air`: Aktionen, Bildzeiten, Spiegeln, Loopstart | ein Streifen pro Aktion in `assets/characters/imported/<id>/`, Zeiten in Ticks |
| `.air`: Clsn1 (Angriffsbox), Clsn2 (Körper) | `hitbox` der Bewegung, `sprite.body` |
| `.cns`: Statedefs mit `movetype = A` und HitDef/Projectile | eine Bewegung: Anlauf/aktiv/Erholung aus den Clsn1-Bildern, Schaden, Rückstoß, Hochwurf |
| `.cmd`: Befehle und `[Statedef -1]` | Vorschlag für Taste + Richtung (siehe unten) |
| Aktion 0, 20/100, 41, 44 | Stehen, Laufen, Sprung, Fallen |

Alles wird auf die Figurenhöhe skaliert (Stehbild Fuß bis Kopf), Boxen werden mitskaliert.

**Tastenzuordnung (Vorschlag):** x/a → Leicht, y/b/z/c → Schwer, zwei Tasten
zugleich → Griff, Befehle mit Bewegung (z. B. `~D, DF, F, x`) → Spezial.
Gehaltene Richtung (`/F`, `/D`, …) wird zu vor/unten/oben, `statetype = A` zu Luft,
geduckte Zustände zu unten. Doppelte Belegungen und Supers (Zustand ab 3000) bleiben
als `extra_<nr>` in der Datei und stehen im Bericht. Ohne `.cmd` wird nach den
üblichen Nummern (200er stehend, 400er geduckt, 600er Luft, 1000er Spezial) verteilt.

**Nicht übernommen:** eigene Zustandslogik der `.cns` (Helfer, Variablen, Bewegungen
im Zustand), Sounds, Supers, Effekt-Sprites außerhalb der Animationen. Schaden
(× 0,25 bei 1000 Leben), Rückstoß und Hochwurf sind Schätzungen: im Bericht
(`import_bericht.txt`) stehen alle Werte, die Feinabstimmung passiert in der JSON.

## Testfigur

`tools/mugen_testfigur/make_testfigur.py` zeichnet "Probe", eine eigene kleine
Figur, und schreibt sie im M.U.G.E.N-Format (SFF v1 und v2 mit allen
Kompressionsarten). Daraus stammt `assets/combat/movesets/probe.json`.
Beide SFF-Versionen ergeben beim Import Pixel für Pixel dieselben Streifen.

## Dateien

- `plugin.gd`, `dock.gd`: Editor-Dock
- `cli.gd`: Kommandozeile
- `converter.gd`: Umwandlung, Zuordnung, Bericht
- `mugen/sff.gd`, `mugen/air.gd`, `mugen/states.gd`, `mugen/text.gd`: Leser für die Formate
