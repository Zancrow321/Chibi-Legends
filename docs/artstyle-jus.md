# Stil-Leitfaden: Manga-Chibi-Look

Ziel: Das Spiel soll sich anfühlen wie die DS-Anime-Prügler der 2000er (Vorbild für das Gefühl: Jump Ultimate Stars). Das ist nur Inspiration. Alle Figuren, Effekte und Bildschirme sind eigene Entwürfe. Keine Sprites, Figuren, Logos oder UI-Elemente aus anderen Spielen übernehmen oder abpausen.

Entschieden am 2026-11-04: Figuren werden größer (ca. 48 × 64 px), dazu kommen Manga-Effekte. Die Panel-UI (Koma-Rahmen für Menüs und HUD) ist vorerst nicht dabei.

## Figuren

| Punkt | Regel |
|---|---|
| Zelle | 96 × 96 px pro Frame, Fußpunkt bei x 44, y 88, Blick nach rechts (links wird gespiegelt) |
| Figur | stehend ca. 28–32 breit × 56–60 hoch, Waffe, Haare und Angriffsposen nutzen den Rest der Zelle |
| Proportionen | ca. 2,7 Köpfe inkl. Frisur (ohne ca. 3,5): großer Kopf, aber echte Arme und Beine |
| Gesicht | große Anime-Augen mit 2 Glanzpunkten, Mimik muss in 3× Zoom lesbar sein |
| Umriss | 1 px, geschlossen; ca. 70 % fast schwarz, an farbigen Spitzen/Kanten ein kräftiger Flächenton; Innenlinien selektiv |
| Schattierung | Cel-Shading, 2–3 Töne pro Material, harte Kanten, kein Dithering, Figur gesamt 13–16 Farben |
| Farben | hell und satt, jede Figur hat 1 Signaturfarbe, die auch Aura und Effekte färbt |
| Silhouette | jede Figur muss schwarz gefüllt erkennbar sein (Haar, Waffe, Schal) |

## Animation

- Übertriebene Schlüsselposen, Squash & Stretch, Vorhol- und Nachschwung.
- Richtwerte: idle 4, run 8, Angriff 4–5, Treffer 1–2 Zeichnungen; Länge über Haltezeiten und Wiederverwendung.
- Treffer-Frame eines Angriffs ist der weiteste Pose und hält 2–3 Frames länger (Hit-Stop).

## Manga-Effekte

- **Speedlines:** radiale Linien bei Supers und starken Treffern, gerade Linien beim Dash.
- **Halbton-Raster:** Punktraster im Hintergrund während eines Supers und im Cut-in.
- **Lautmalerei:** kurze eigene Wörter in fetter Schrift mit dickem Umriss (z. B. „BAM!“, „ZACK!“, „DOOM“), schräg gestellt, poppen auf und verblassen.
- **Treffer:** sternförmige Blitze statt runder Funken, weiß mit Signaturfarbe am Rand.
- Die bestehenden M.U.G.E.N-Effekte (Glühen, Shake, Hit-Stop) bleiben und werden ergänzt.

## Referenz: wie Figuren im DS-Vorbild aufgebaut sind

Gemessen am 2026-11-04 an einer Kämpferfigur aus einem privaten Export (nur Zahlen ausgewertet, keine Bilder übernommen). Die Werte sind unser Maßstab für Größe, Farben und Animationsumfang. Figuren, Formen und Posen entwerfen wir selbst.

| Messwert | Vorbild |
|---|---|
| Stehen, sichtbare Pixel | ca. 28 × 56 px (Breite 27–30, Höhe 55–57) |
| Laufen | ca. 36 × 51 px (Körper geht tiefer, Schritt breiter) |
| alle Körperbilder | Höhe meist 55, max. 67 (Sprünge, große Angriffe) |
| Trefferbox | stehend 20 × 46, geduckt 20 × 38; die Frisur ragt ca. 10 px darüber |
| Kopf | ca. 20–23 px breit, Hals bei Zeile 20–21 von oben |
| Proportion | 2,6–2,8 Köpfe inkl. Frisur, ohne Frisur ca. 3,5; die Frisur macht rund ein Drittel der Höhe aus |
| Farben | 13 pro Bild, 13 für alle Grundposen (16er-Palette inkl. Transparenz), keine Verläufe |
| Umriss | ca. 70 % fast schwarz (8, 8, 8); der Rest in einem kräftigen Ton der angrenzenden Fläche (z. B. Haarspitzen) |
| Effekte | fast ohne schwarzen Umriss, aus Weiß und Gelb aufgebaut, bis 65 Farben |

**Bilder pro Animation** (verschiedene Zeichnungen):

| Animation | Bilder |
|---|---|
| Stehen | 4 |
| Laufen | 8 |
| Dash / Bremsen | 2 / 3 |
| Sprung | aufwärts 2, oben 1, fallen 2, landen 2 |
| Ducken, Drehen, Blocken | je 1 |
| Treffer / Umfallen / Aufstehen | 1–2 / 3 / 3 |
| Angriffe (schwach, stark, nach oben, Luft) | je 4–5 |
| Spezialangriff | 4–5 Zeichnungen, 14–17 Schlüsselbilder |
| großer Spezialangriff | 10–12 Zeichnungen, 22–46 Schlüsselbilder |
| Intro / Sieg | 6 / 9 |

**Lehren für uns**

- Klein und kopflastig: Die Figur ist etwa halb so breit wie hoch, und die Frisur ist die wichtigste Erkennungsform.
- 13 Farben reichen für eine ganze Figur. Jedes Material hat 2–3 Töne, harte Kanten.
- Der Umriss ist überwiegend fast schwarz, nur an farbigen Spitzen und Kanten nimmt er die Flächenfarbe auf.
- Sparsame Animation: wenige Zeichnungen, Bewegung durch Haltezeiten und wiederverwendete Bilder. Ein großer Spezialangriff zeigt bis zu 46 Schlüsselbilder aus nur 12 Zeichnungen. Für uns heißt das: weniger PixelLab-Frames, dafür Timing im Code.
- Effekte sind hell (Weiß, Gelb) und ohne schwarze Linie, damit sie sich von den Figuren abheben.

### Was das für uns heißt

| Punkt | Testfigur (Stand PR #10) | Ziel nach Referenz |
|---|---|---|
| Höhe | ca. 92 px | ca. 56–60 px in der 96er Zelle |
| Breite stehend | ca. 74 px inkl. Schwert | ca. 28–32 px Körper |
| Proportion | ca. 2,2 Köpfe | ca. 2,7 Köpfe inkl. Frisur |
| Farben | 46 | 13–16 |
| Umriss | überall schwarz | ca. 70 % fast schwarz, Rest Flächenfarbe |

## PixelLab

- Standbilder: `create-image-pixflux` oder `create-image-pixen` mit 96 × 96, `view: side`, `direction: east`, `outline: single color black outline`.
- Animation: `animate-with-text-v3` ausgehend vom gewählten Standbild (bei 96 × 96 kosten bis zu 7 Frames 1 Generierung).
- Skripte: `tools/jus_style/`. Erste Testfigur: `assets/characters/jus_test/`.

![Vorher/Nachher](screenshots/jus-vorher-nachher.png)
