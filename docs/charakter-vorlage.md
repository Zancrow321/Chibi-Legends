# Charakter-Vorlage

Mit dieser Vorlage beschreibst du einen Charakter. Ich arbeite ihn danach aus:
Design, Farben, Sprites, Animationen, Kampfwerte, Dialoge und den Einbau ins Spiel.

**So geht's**

1. Den Block "Zum Ausfüllen" kopieren (oder die Datei duplizieren).
2. Nur **Pflicht** (★) muss ausgefüllt sein, alles andere ist optional.
   Leere Felder entscheide ich selbst passend zum Spiel.
3. Stichworte reichen völlig. Du kannst auch Skizzen oder Bilder anhängen.
4. Mir schicken. Bevor ich mit PixelLab generiere, nenne ich dir Plan und Anzahl
   der Generierungen und warte auf dein OK.

**Was automatisch gilt** (musst du nicht eintragen)

- Nur eigene Figuren. Ein Vorbild aus Anime oder Spielen ist als Gefühl okay
  ("wirkt wie ein ruhiger Schwertmeister"), aber keine Namen, Kostüme, Frisuren
  oder Techniken, die man direkt wiedererkennt.
- Stil: schlank, ca. 2,8 Köpfe, dunkler Umriss, Seitenansicht, 13 bis 16 Farben
  aus der Palette Resurrect 64 (Referenz: `kaempfer-skizzen/raiga_7.png`).
- Größe: Spielerfigur ca. 28×56 px. NPCs und normale Gegner ähnlich groß,
  Elite- und Bossgegner dürfen deutlich größer sein.
- Effekte (Feuer, Blitze, Treffer) sind weich animiert im M.U.G.E.N-Stil, nicht
  Pixel-Art.
- Waffen sind eigene Teile an der Hand und können getauscht werden.

---

## Zum Ausfüllen

```text
=== GRUNDDATEN ===
★ Name:
★ Rolle:            [ ] NPC   [ ] Gegner   [ ] Elite-Gegner   [ ] Boss
                    [ ] Kampfstil-Vorlage (Moves für den Skilltree)
  Welt / Ort:       (z. B. Akademie-Hof, Trainingswald, Glutschmiede, neue Welt)
★ In einem Satz:    (Wer ist das? z. B. "grummelige Schmiedin, die Neulinge testet")
  Alter / Wirkung:  (jung, alt, wirkt gefährlich, niedlich, geheimnisvoll ...)

=== AUSSEHEN ===
  Körper:           (normal / klein / groß / breit / Tier / Monster / Golem ...)
  Haare:
  Gesicht / Augen:  (Narbe, Maske, Brille, leuchtende Augen ...)
  Kleidung:
  Besonderes:       (Umhang, Flügel, Schwanz, Tattoos, schwebende Teile ...)
  Hauptfarben:      (2 bis 4 Farben, z. B. "Rost-Orange, Schwarz, Gold")
  Waffe:            (Art, Größe, wie gehalten, z. B. "Hammer, einhändig, auf der Schulter")

=== PERSÖNLICHKEIT ===
  Charakter:        (3 Stichworte reichen)
  Spricht wie:      (knapp, förmlich, frech, Dialekt, Lieblingsspruch ...)
  Will / Ziel:
  Beziehung zum Spieler: (Lehrer, Rivale, Händler, Feind ...)

=== KAMPF (nur bei Gegner, Boss, Kampfstil) ===
  Element / Thema:  (Feuer, Wasser, Blitz, Schatten, Natur ... oder eigenes)
  Kampfart:         (nah / fern / gemischt, schnell / schwer, fliegt, springt ...)
  Angriffe:         (Stichworte, z. B. "Sprungschlag, wirft Funken, Schild-Konter")
  Schwäche:         (Wie besiegt man ihn am besten?)
  Schwierigkeit:    [ ] leicht   [ ] mittel   [ ] schwer   [ ] sehr schwer
  Boss-Phasen:      (nur Boss: was ändert sich bei halber HP?)
  Belohnung / Loot: (optional)

=== NPC (nur bei NPC) ===
  Funktion:         [ ] Story   [ ] Händler   [ ] Quests   [ ] Lehrer (schaltet Kampfstil frei)
                    [ ] schaltet Outfit/Frisur im Creator frei   [ ] nur Deko
  Erster Satz:      (Was sagt er/sie beim ersten Ansprechen?)

=== ANIMATIONEN ===
  (leer lassen = ich wähle passend zur Rolle)
  [ ] stehen   [ ] laufen   [ ] rennen   [ ] springen   [ ] getroffen   [ ] besiegt
  [ ] Angriff(e)   [ ] Spezialangriff   [ ] reden / Geste   [ ] eigene: ______

=== SONSTIGES ===
  Referenzen:       (eigene Skizzen, Bilder, Stimmung, Musik)
  Unbedingt so:     (Was darf ich auf keinen Fall ändern?)
  Bloß nicht:       (Was soll der Charakter auf keinen Fall sein?)
  Was soll ich machen?
                    [ ] nur Konzept (Text)   [ ] Konzept + Skizze
                    [ ] fertige Sprites      [ ] direkt ins Spiel einbauen
```

---

## Kurzform

Wenn es schnell gehen soll, reicht das:

```text
Name:
Rolle:          (NPC / Gegner / Boss / Kampfstil)
Wo:
In einem Satz:
Aussehen:
Farben:
Kampf / Funktion:
Was soll ich machen:
```

---

## Beispiel (ausgefüllt)

```text
=== GRUNDDATEN ===
★ Name:             Brannok, der Ambossvogt
★ Rolle:            [x] Boss
  Welt / Ort:       Glutschmiede (Ende des ersten Abschnitts)
★ In einem Satz:    Alter Schmiedemeister, der zu lange im Feuer stand und jetzt
                    selbst halb aus glühendem Metall ist.
  Alter / Wirkung:  alt, riesig, langsam, aber furchteinflößend

=== AUSSEHEN ===
  Körper:           groß und breit, ca. doppelt so hoch wie der Spieler
  Haare:            kein Haar, dafür ein Bart aus Funken, der flackert
  Gesicht / Augen:  Schweißermaske mit einem glühenden Sehschlitz
  Kleidung:         schwere Lederschürze, ein Arm komplett aus Metall
  Besonderes:       Risse im Metallarm glühen, wenn er wütend wird
  Hauptfarben:      Rost-Orange, Kohleschwarz, Glutgelb
  Waffe:            riesiger Schmiedehammer, zweihändig, schleift über den Boden

=== PERSÖNLICHKEIT ===
  Charakter:        stolz, stur, eigentlich nicht böse
  Spricht wie:      kurze Sätze, Schmiede-Vergleiche ("Du bist noch kaltes Eisen.")
  Will / Ziel:      einen würdigen Nachfolger finden
  Beziehung zum Spieler: Prüfer; nach dem Sieg wird er zum Lehrer

=== KAMPF ===
  Element / Thema:  Feuer, Schmiede (passt zu Glutatem)
  Kampfart:         nah, schwer, langsam; springt selten, aber mit Schockwelle
  Angriffe:         Hammerschlag (Bodenwelle), Funkenregen von oben,
                    Ambossstampfer (Plattformen wackeln), Glut-Ansturm
  Schwäche:         nach dem Ambossstampfer 2 Sekunden lang offen
  Schwierigkeit:    [x] schwer
  Boss-Phasen:      ab 50 % HP glüht der Arm, Angriffe schneller, Boden wird
                    stellenweise heiß
  Belohnung / Loot: Hammer "Brannoks Last" (legendär), schaltet Outfit "Schmied+" frei

=== ANIMATIONEN ===
  [x] stehen   [x] laufen   [x] getroffen   [x] besiegt
  [x] Angriff(e)   [x] Spezialangriff   [x] eigene: Wut-Übergang zu Phase 2

=== SONSTIGES ===
  Referenzen:       Stimmung wie ein Hochofen bei Nacht
  Unbedingt so:     die Schweißermaske
  Bloß nicht:       kein Dämon, kein Monster mit Hörnern, er bleibt ein Mensch
  Was soll ich machen?
                    [x] Konzept + Skizze   (Sprites erst nach meinem OK)
```

---

## Was du von mir zurückbekommst

- **Konzept:** fertige Beschreibung mit Hintergrund, Dialogen und (bei Kampf)
  Angriffen mit Werten, Phasen und Konterfenstern.
- **Skizze:** 1 bis 3 Varianten der Figur zum Auswählen.
- **Sprites:** Animationsstreifen im Projektformat (`frames.json`), mit Palette
  Resurrect 64 und Recolor-Varianten für Skins.
- **Einbau:** NPC mit Dialog im Overworld oder Gegner/Boss in einem Kampfgebiet,
  mit Screenshots zum Prüfen.
