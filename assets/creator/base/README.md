# Grundkörper für den Character Creator (Phase 1)

Ein einziger Grundkörper für alle Spielerfiguren, schlank mit etwa 2,8 Köpfen,
rund 28 × 56 px in einer 64 × 64-Zelle, Seitenansicht (die andere Richtung wird gespiegelt).
Jedes Kleidungsteil wird später auf genau diese 60 Zeichnungen gelegt.

| Datei | Inhalt |
| --- | --- |
| `base.png` | Ausgangsfigur (aus der Referenz raiga_7 per PixelLab zum neutralen Grundkörper umgewandelt) |
| `frames/*.png` | die 68 Posen einzeln (60 + 8 Zweihand-Varianten), 64 × 64, transparent |
| `sheet.png` | alle 68 Posen als Sheet, 10 Spalten, Reihenfolge wie `tools/pixellab/creator_base/frames.json` |
| `anchors.json` | gemessene Ankerpunkte pro Frame: Kopf (Hals + Kopfneigung), vordere und hintere Hand (Handgelenk + Unterarm-Winkel), Rücken (Schultermitte + Rumpfneigung), Füße |

Winkel: 0° = zeigt nach unten, positiv = nach vorne (Blickrichtung), 180° = nach oben.
Angehängte Teile (Frisur, Gesicht, Kopfbedeckung, Waffe, Rücken) werden an diese Anker
gesetzt und gedreht. Körperteile (Oberteil, Hose, Schuhe, Handschuhe) bekommen eine
eigene Zeichnung pro Frame.

## Neu erzeugen

```
cd tools/pixellab/creator_base
python3 poses.py                                  # frames.json aus den Pose-Winkeln
python3 generate_base.py ../../../assets/creator/base/base.png base_keypoints.json /tmp/roh   # ca. 24 Generierungen
python3 finish_frames.py /tmp/roh ../../../assets/creator/base/frames ../../../assets/creator/base/anchors.json  # ca. 6
python3 build_sheet.py ../../../assets/creator/base/frames ../../../assets/creator/base/sheet.png /tmp/vorschau.png --anchors ../../../assets/creator/base/anchors.json
```

Der Key kommt nur aus `PIXELLAB_API_KEY`. Einzelne Gruppen lassen sich neu erzeugen,
indem man ihre Namen anhängt (zum Beispiel `... /tmp/roh air strikes`).

Bekannte Schönheitsfehler: In `upper_hit`, `airpunch_hit` und `cast_hit` hat das
Modell kleine Effekt-Reste gemalt. Diese drei Frames werden vor Phase 2 nachgebessert.
