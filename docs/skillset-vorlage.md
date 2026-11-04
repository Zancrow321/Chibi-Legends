# Skillset-Vorlage (Kampfstile aus dem Gacha)

Mit dieser Vorlage beschreibst du ein Skillset, also einen Kampfstil, den der
Spieler per Gacha ziehen kann. Ich arbeite ihn danach aus: Skilltree mit Werten,
Effekte, Posen, Icons, Stil-Datei (`assets/combat/styles/<id>.json`) und den
Einbau ins Spiel. Vorbild ist der erste Stil **Glutatem**.

**So geht's**

1. Den Block "Zum Ausfüllen" kopieren.
2. Nur **Pflicht** (★) muss ausgefüllt sein. Alles andere ist optional;
   leere Felder entscheide ich passend zum Spiel.
3. Stichworte reichen. Bei den Zügen genügt ein Name und ein halber Satz,
   die Alternativen und Zahlen kann ich selbst machen.
4. Mir schicken. Bevor ich mit PixelLab generiere (Waffe, Posen, Icons), nenne
   ich dir Plan und Anzahl der Generierungen und warte auf dein OK.

**Was automatisch gilt** (musst du nicht eintragen)

- **Aufbau wie Glutatem:** 6 Züge + 1 Meisterzug. Jeder Zug hat eine Grundform
  und 3 Alternativen. Eine Alternative verändert den Zug (Reichweite, zwei
  Richtungen, länger, zusätzlicher Effekt), sie ersetzt ihn nicht. Pro Zug ist
  genau eine Alternative aktiv, gewählt vor dem Kampf.
- **Kosten:** Zug 1 SP, Alternative 2 SP, Meisterzug 4 SP + zwei weitere
  Varianten je 2 SP. Zusammen genau 50 SP, also Stufe 1 bis 50 des Stils.
  Jeder Stil hat eine eigene Stufe; ein neu gezogener Stil startet mit Aufholbonus.
- **Steuerung:** L + Richtung = Zug, L halten = verstärkte Fassung (kostet 1 Stufe
  der Legendenleiste), P = Meisterzug (3 Stufen Leiste).
- **Kein Pay-to-win:** Eine höhere Seltenheit bringt mehr Auswahl und mehr
  Spektakel, aber keine höheren Werte. Legendär ist nicht stärker als Episch.
- **Eigene Ideen:** Ein Vorbild aus Anime oder Spielen ist als Gefühl okay, aber
  keine wiedererkennbaren Namen, Techniken, Formnummern ("Erste Form") oder
  Markenzeichen. Glutatem ist z. B. Feuer mit Thema Schmiede statt Sonne oder
  Flammenwirbel.
- **Effekte** sind weich animiert im M.U.G.E.N-Stil (Partikel, Glühen, Bloom,
  Screen-Shake), nicht Pixel-Art. Effekt-Texturen sind grau und werden
  eingefärbt, so gibt es Skins als Umfärbung.
- **Figur:** Der Stil läuft auf der Creator-Figur (schlank, ca. 2,8 Köpfe,
  Palette Resurrect 64). Die Waffe ist ein eigenes, tauschbares Teil an der Hand.

---

## Zum Ausfüllen

```text
=== GRUNDDATEN ===
★ Name des Stils:
★ Element / Kraft:   (Feuer, Wasser, Blitz, Schatten, Wind, Gift, Klang, Ketten ...)
★ Thema in einem Satz: (Bildwelt, aus der alles kommt, z. B. "Schmiede: Funken, Amboss, Schlacke")
  Seltenheit:        [ ] Selten   [ ] Episch   [ ] Legendär
  Heimatwelt:        (welche Welt der Stil herkommt, optional)
  Waffe:             (Katana, Zweihänder, Fäuste, Speer, Sense, Bogen, Kette, Fächer ...)
  Spielgefühl:       (schnell / schwer, nah / fern, Konter, Fallen, Luftkampf ...)
  Gefühl wie:        (Stimmung oder Vorbild als Gefühl, nicht zum Kopieren)

=== STIL-MECHANIK ===
  Besondere Regel:   (Was macht nur dieser Stil? Bei Glutatem: verschiedene Züge
                      in einer Kombo heizen die Klinge Rot → Orange → Weiß,
                      bei Weiß gibt es einen Extra-Treffer.)
  Status-Effekt:     (was der Stil beim Gegner auslöst, z. B. Brand, Nass, Lähmung)
  Kombi mit anderen Elementen: (optional, z. B. "Nass + Blitz = Leitung")

=== DIE 6 ZÜGE ===
  (Richtung leer lassen = ich verteile sie. Alternativen leer = ich mache 3.)

  Zug 1 – Name:            Richtung: [ ] neutral [ ] vor [ ] hoch [ ] runter/Luft
          Was er macht:
          Alternativen:    1)            2)            3)
  Zug 2 – Name:            Richtung:
          Was er macht:
          Alternativen:    1)            2)            3)
  Zug 3 – Name:            Richtung:
          Was er macht:
          Alternativen:    1)            2)            3)
  Zug 4 – Name:            (Vorschlag: Konter oder Abwehr)
          Was er macht:
          Alternativen:    1)            2)            3)
  Zug 5 – Name:            (Vorschlag: Bewegung, Dash oder Sprung)
          Was er macht:
          Alternativen:    1)            2)            3)
  Zug 6 – Name:            (Vorschlag: Luftangriff oder Sturz)
          Was er macht:
          Alternativen:    1)            2)            3)

=== MEISTERZUG (Super, 3 Varianten) ===
  Variante A – Name:       Was passiert:
  Variante B – Name:       Was passiert:
  Variante C – Name:       Was passiert:
  Großes Bild dazu:        (Super-Flash, Hintergrund wird ..., Kamera ...)

=== OPTIK ===
  Effektfarben:      (3 bis 5 Farben, z. B. "Asche, Glutrot, Orange, Weißgelb")
  Effekt-Stil:       (Funken, Wasserspritzer, Tinte, Glas, Rauch, Federn ...)
  Lautmalerei:       (Manga-Schriftzüge bei Treffern, z. B. "ZASH", "DOOOM")
  Besondere Posen:   (z. B. Ausfallschritt, Ladepose, Konterhaltung)

=== GACHA ===
  Banner / Saison:   (optional)
  Duplikate:         (leer = ich schlage etwas Kosmetisches vor, z. B. Effekt-Recolor)
  Passendes Outfit:  (optional, als Creator-Freischaltung)

=== SONSTIGES ===
  Unbedingt so:      (Was darf ich auf keinen Fall ändern?)
  Bloß nicht:        (Was soll der Stil auf keinen Fall sein?)
  Was soll ich machen?
                     [ ] nur Konzept (Text)    [ ] Konzept + Effekt-Skizzen
                     [ ] spielbar einbauen     [ ] alles inkl. Icons und Waffe
```

---

## Kurzform

Wenn es schnell gehen soll, reicht das. Den Rest leite ich ab:

```text
Name:
Element:
Thema in einem Satz:
Waffe:
Spielgefühl:
3 Ideen für Züge:
Idee für den Meisterzug:
Was soll ich machen:
```

---

## Beispiel (ausgefüllt)

Ein möglicher Wasser-Stil, nur als Beispiel, noch nicht entschieden.

```text
=== GRUNDDATEN ===
★ Name des Stils:    Gezeiten
★ Element / Kraft:   Wasser
★ Thema in einem Satz: Meer und Küste: Brandung, Ebbe und Flut, Strudel, Gischt.
  Seltenheit:        [x] Episch
  Heimatwelt:        Küstenwelt (noch ohne Namen)
  Waffe:             leicht gebogenes Langschwert, einhändig
  Spielgefühl:       fließend, mittlere Reichweite, gut im Kontern
  Gefühl wie:        ruhig und elegant, wird plötzlich gewaltig wie eine Welle

=== STIL-MECHANIK ===
  Besondere Regel:   Flut-Anzeige: Treffer füllen sie, ein Konter leert sie auf
                     einen Schlag und der nächste Zug wird zur großen Welle.
  Status-Effekt:     Nass (Gegner rutscht beim Landen, langsamer beim Aufstehen)
  Kombi mit anderen Elementen: Nass + Blitz = Leitung (Kettenschaden),
                     Nass + Brand = Dampf (Sichtwolke)

=== DIE 6 ZÜGE ===
  Zug 1 – Gischtschnitt     Richtung: vor
          Was er macht:     Schnitt, der eine flache Wasserwelle nach vorn schickt.
          Alternativen:     1) Welle läuft weiter   2) nach vorn und hinten
                            3) Welle bleibt kurz als Wand stehen
  Zug 2 – Geysirstoß        Richtung: hoch
          Was er macht:     Stich nach unten, vor dir schießt ein Geysir hoch.
          Alternativen:     1) zwei Geysire   2) Geysir wandert zum Gegner
                            3) trägt dich selbst nach oben
  Zug 3 – Perlenwelle       Richtung: neutral
          Was er macht:     3 Wasserperlen schweben um dich und fliegen dann los.
          Alternativen:     (du entscheidest)
  Zug 4 – Ebbehaltung       (Konter)
          Was er macht:     Klinge senken; wer jetzt trifft, wird weggespült.
          Alternativen:     1) längeres Fenster   2) zieht den Gegner heran
                            3) füllt die Flut-Anzeige ganz
  Zug 5 – Strudelschritt    (Dash)
          Was er macht:     Kurzer Dash, hinterlässt einen kleinen Strudel.
          Alternativen:     (du entscheidest)
  Zug 6 – Brandungssturz    (Luft)
          Was er macht:     Sturz aus der Luft, Aufprall spritzt zu beiden Seiten.
          Alternativen:     (du entscheidest)

=== MEISTERZUG ===
  Variante A – Springflut:    eine riesige Welle rollt einmal über den ganzen Bildschirm
  Variante B – Mahlstrom:     Strudel zieht alle Gegner in die Mitte, dann ein Schnitt
  Variante C – Tiefseestille: Bildschirm wird dunkelblau und still, dann 12 schnelle Schnitte
  Großes Bild dazu:           Super-Flash in Türkis, Hintergrund wird zu Tiefsee

=== OPTIK ===
  Effektfarben:      Tiefblau, Türkis, Schaumweiß, ein Hauch Gold
  Effekt-Stil:       Wasserspritzer, Schaumkronen, Luftblasen
  Lautmalerei:       "SPLASH", "ZAAA", "DOGOOO"
  Besondere Posen:   tiefe Konterhaltung, Ausholen über der Schulter

=== GACHA ===
  Duplikate:         Effekt-Recolor "Mondflut" (silber-violett)

=== SONSTIGES ===
  Unbedingt so:      die Flut-Anzeige
  Bloß nicht:        keine Atem-Technik mit Formnummern
  Was soll ich machen?
                     [x] Konzept + Effekt-Skizzen
```

---

## Was du von mir zurückbekommst

- **Konzept:** Design-Doc wie bei Glutatem, mit allen 7 Skills, je 3 Alternativen,
  Werten (Schaden, Frames, Abklingzeit), verstärkten Fassungen und SP-Kosten.
- **Effekt-Skizzen:** Screenshots der wichtigsten Züge im Spiel.
- **Einbau:** Stil-Datei `assets/combat/styles/<id>.json` + Moveset, Effekte im
  Code, Stil-Menü, 10 Icons, ggf. neue Posen und die Waffe.
