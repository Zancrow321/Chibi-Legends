# Werkzeuge: Palette, Fremd-Assets, Sound

Kurzüberblick, welches Werkzeug wofür da ist und wie die Dateien ins Spiel kommen.

## 1. Master-Palette (Lospec)

Alle Figuren, Effekte und Kulissen verwenden **eine** gemeinsame Palette. Das hält den Stil
zusammen (Figuren ~28×56 px, 13–16 Farben pro Figur, dunkler Umriss) und erlaubt Farbvarianten per Shader.

- Aktiv: **Resurrect 64** (Kerrie Lake, lospec.com/palette-list/resurrect-64), eingetragen in `assets/palettes/config.json`.
- Alternative im Repo: **Endesga 32** (lospec.com/palette-list/endesga-32). Umstellen = Name in `config.json` ändern
  und `python3 tools/palette/build.py` ausführen.
- Weitere Lospec-Paletten: `python3 tools/palette/fetch_lospec.py <slug>` (braucht lospec.com in der Netzwerk-Freigabe).

Dateien in `assets/palettes/` (von `build.py` erzeugt):

| Datei | Wofür |
| --- | --- |
| `<name>.gpl` | Aseprite: *Palette → Load Palette* (oder in den Paletten-Ordner von Aseprite kopieren) |
| `<name>.png` | N×1-Streifen für den Shader |
| `<name>_swatches.png` | Übersicht; auch als PixelLab *color image* (erzwingt die Palette beim Generieren) |
| `swaps_lut.png` / `.json` | Farbvarianten aus `swaps.json` für den Shader |

### PixelLab-Ausgaben quantisieren

```bash
# rohe PixelLab-Bilder -> saubere Sprites (harte Kanten, nur Palettenfarben, max. 16 Farben, Umriss)
python3 tools/palette/quantize.py pixellab_raw/ -o assets/characters/raw --max-colors 16 --outline

# prüfen (z. B. vor dem Commit): Exit-Code 1 bei Fremdfarben, Halbtransparenz oder zu vielen Farben
python3 tools/palette/quantize.py assets/characters/raw --check --max-colors 16

# als indizierte PNG für Aseprite
python3 tools/palette/quantize.py bild.png --indexed
```

Ein Sprite-Sheet zählt als ein Sprite: alle Frames teilen dieselben Farben. In Python-Skripten liefert
`palette.pixellab_color_image()` das Farbbild für PixelLab-Aufrufe mit `color_image`.

### Farbvarianten (Palette-Swap)

`assets/shaders/palette_remap.gdshader` tauscht Palettenfarben gegen eine Zeile aus `swaps_lut.png`.
In GDScript:

```gdscript
sprite.material = PaletteRemap.material("raiga_gi_blau")
PaletteRemap.set_variant(sprite.material, "original")
```

Varianten stehen in `assets/palettes/swaps.json` (`"alte Farbe": "neue Farbe"`). **Regel:** Haut und
umfärbbare Kleidung dürfen sich keine Palettenfarbe teilen, sonst färbt sich beides um. Beim Zeichnen oder
Nachbearbeiten in Aseprite also je Material eigene Töne verwenden.

Der bestehende `palette_swap.gdshader` (Paper-Doll-Format mit Slot/Ton-Kodierung) bleibt für den
Character Creator; der neue Shader ist für normal gemalte Sprites.

## 2. Platzhalter-Assets (CC0)

`python3 tools/assets/import_cc0.py` holt eine kuratierte Auswahl aus Kenneys Paketen (alles CC0) nach
`assets/third_party/kenney/` und schreibt `assets/third_party/LICENSES.md` + `manifest.json`.
Quellen sind GitHub-Spiegel mit festem Commit, weil kenney.nl und opengameart.org aus der Cloud nicht erreichbar sind.

| Bereich | Inhalt |
| --- | --- |
| `ui/` | UI Pack Pixel Adventure (Atlas), Fantasy UI Borders, Input Prompts Pixel (Atlas, Tastatur/Gamepad), Game Icons, Mobile Controls |
| `sfx/` | Interface Sounds, UI Audio, Impact Sounds (Treffer, Schritte), Sprung/Landung/Münze |
| `vfx/` | Particle Pack (auf 64 px verkleinert), Explosionen und Rauch als Streifen (gleiches Format wie `assets/vfx/`) |

Atlas-Index = Kachelnummer aus Kenneys Paket, 32 Spalten (siehe `manifest.json`).
Neue Pakete nur über `PACKS` im Skript ergänzen, damit die Lizenzliste stimmt.

Sounds spielt `Sfx.play("jump")` (`scripts/audio/sfx.gd`) ab; welches Ereignis welche Datei nutzt, steht in
`assets/audio/sfx_map.json`. Final-Sounds ersetzen dort einfach den Pfad.

Schwung- und Dash-Geräusche (`swing_light`, `swing_heavy`, `dash`) sind eigene Platzhalter aus gefiltertem
Rauschen: `python3 tools/audio/synth_whoosh.py` schreibt sie nach `assets/audio/sfx/*.wav`.

## 3. Eigene Sounds (Stable Audio 3)

Stable Audio 3 Medium läuft auf Kaisers PC in ComfyUI (`http://127.0.0.1:8188`, Modell `stable_audio_3_medium`,
Text-Encoder `t5gemma_b_b_ul2`). Die Skripte sprechen die ComfyUI-API direkt an, ein Clip braucht etwa eine Sekunde.

1. Prompts pflegen: `tools/audio/sa3_prompts.json` (je Ereignis Prompt, Länge, Anzahl Seeds, wie viele ins Spiel).
2. Erzeugen: `python tools/audio/sa3_generate.py` (alle) oder `python tools/audio/sa3_generate.py dash glut_super`.
   Rohdateien (FLAC) landen in ComfyUIs Output-Ordner unter `chibi-sfx/<ereignis>/`.
3. Auswählen und aufbereiten (braucht PyAV + numpy, z. B. Pythons aus ComfyUIs `.venv`):
   `<comfy-venv>/python.exe -I tools/audio/sa3_finish.py G:/Comfy-Desktop/ComfyUI-Shared/output/chibi-sfx [ereignis ...]`
   schneidet Stille, kürzt, gleicht die Lautheit an, wählt die besten Takes und schreibt Mono-WAVs nach
   `assets/audio/sfx/sa3/` (Godot komprimiert sie beim Import zu QOA) plus `picks.json` mit Seeds.
4. In `assets/audio/sfx_map.json` eintragen und in `assets/audio/SOURCES.md` Prompt und Seed notieren.

Stil-Ereignisse heißen `<stil>_cast`, `_attack`, `_impact`, `_super` mit den Kürzeln glut, mond, klang, bollwerk,
grenz, wirbel, spann, lauf. Glutatem nutzt sie schon; die anderen Stile rufen sie auf, sobald es sie im Code gibt.

Lizenz: Stability AI Community License. Ausgaben dürfen kommerziell genutzt werden, solange der Jahresumsatz unter
1 Mio. US-Dollar liegt (darüber Enterprise-Lizenz); zusätzlich gelten die Gemma-Bedingungen des Text-Encoders.
Vor dem Echtgeld-Start noch einmal unter https://stability.ai/license prüfen.

## 4. Aseprite

- Palette laden: `assets/palettes/resurrect-64.gpl`.
- Export per Kommandozeile (Pfad zur `Aseprite.exe` anpassen):

```bash
Aseprite.exe -b figur.aseprite --sheet figur.png --data figur.json --format json-array --sheet-type horizontal --list-tags
```

- Danach zur Sicherheit: `python3 tools/palette/quantize.py figur.png --check --max-colors 16`.

## 5. Godot-MCP

Nicht eingerichtet. Godot-MCP braucht eine laufende Godot-Installation auf demselben Rechner wie Claude Code.
In der Cloud gibt es nur die Prüfung über GitHub Actions (Import, Skriptfehler, Web-Export).
Auf Kaisers PC ginge es über eine Remote-Control-Sitzung (MCP-Server lokal eintragen, nicht ins Repo).
