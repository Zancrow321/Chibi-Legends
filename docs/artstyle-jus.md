# Stil-Leitfaden: Manga-Chibi-Look

Ziel: Das Spiel soll sich anfühlen wie die DS-Anime-Prügler der 2000er (Vorbild für das Gefühl: Jump Ultimate Stars). Das ist nur Inspiration. Alle Figuren, Effekte und Bildschirme sind eigene Entwürfe. Keine Sprites, Figuren, Logos oder UI-Elemente aus anderen Spielen übernehmen oder abpausen.

Entschieden am 2026-11-04: Figuren werden größer (ca. 48 × 64 px), dazu kommen Manga-Effekte. Die Panel-UI (Koma-Rahmen für Menüs und HUD) ist vorerst nicht dabei.

## Figuren

| Punkt | Regel |
|---|---|
| Zelle | 96 × 96 px pro Frame, Fußpunkt bei x 44, y 88, Blick nach rechts (links wird gespiegelt) |
| Figur | ca. 48 breit × 64 hoch, Waffe und Haare dürfen in die Zelle hinausragen |
| Proportionen | ca. 2,5 Köpfe: großer Kopf, aber echte Arme und Beine mit Ellbogen und Knien |
| Gesicht | große Anime-Augen mit 2 Glanzpunkten, Mimik muss in 3× Zoom lesbar sein |
| Umriss | kräftig und dunkel, außen 1 px fast schwarz; innen Linien in dunklem Ton der Fläche (selektiv) |
| Schattierung | Cel-Shading, 3–4 Töne pro Material (Licht, Grund, Schatten, tiefer Schatten), harte Kanten, kein Dithering |
| Farben | hell und satt, jede Figur hat 1 Signaturfarbe, die auch Aura und Effekte färbt |
| Silhouette | jede Figur muss schwarz gefüllt erkennbar sein (Haar, Waffe, Schal) |

## Animation

- Übertriebene Schlüsselposen, Squash & Stretch, Vorhol- und Nachschwung.
- Richtwerte: idle 4–6, run 8, Angriff 6–8, Treffer 2–3 Frames.
- Treffer-Frame eines Angriffs ist der weiteste Pose und hält 2–3 Frames länger (Hit-Stop).

## Manga-Effekte

- **Speedlines:** radiale Linien bei Supers und starken Treffern, gerade Linien beim Dash.
- **Halbton-Raster:** Punktraster im Hintergrund während eines Supers und im Cut-in.
- **Lautmalerei:** kurze eigene Wörter in fetter Schrift mit dickem Umriss (z. B. „BAM!“, „ZACK!“, „DOOM“), schräg gestellt, poppen auf und verblassen.
- **Treffer:** sternförmige Blitze statt runder Funken, weiß mit Signaturfarbe am Rand.
- Die bestehenden M.U.G.E.N-Effekte (Glühen, Shake, Hit-Stop) bleiben und werden ergänzt.

## PixelLab

- Standbilder: `create-image-pixflux` oder `create-image-pixen` mit 96 × 96, `view: side`, `direction: east`, `outline: single color black outline`.
- Animation: `animate-with-text-v3` ausgehend vom gewählten Standbild (bei 96 × 96 kosten bis zu 7 Frames 1 Generierung).
- Skripte: `tools/jus_style/`. Erste Testfigur: `assets/characters/jus_test/`.

![Vorher/Nachher](screenshots/jus-vorher-nachher.png)
