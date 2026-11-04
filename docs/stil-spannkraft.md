# Kampfstil „Spannkraft“

Konzept für einen spielbaren Kampfstil (Gacha, Legendär). Grundlage ist Kaisers
ausgefüllte Skillset-Vorlage vom 2026-11-04 („Grenzenlose Freiheit“). Mechanik,
Aufbau, Züge, Alternativen und Meisterzug-Ideen sind Kaisers Entwurf. Geändert
wurden nur Namen und Optik, die direkt aus einer bekannten Anime-Vorlage stammen;
sie sind hier durch eigene ersetzt (siehe „Was umbenannt wurde“ ganz unten).
Der Entwurf brach bei Meisterzug-Variante C ab; diese Variante, Optik, Schwächen
und Gacha-Teil sind passend ergänzt und können frei geändert werden.

Aufbau wie bei Glutatem, Schwarzmond, Gleichklang und Bollwerk: 6 Züge + Meisterzug
mit 3 Varianten, je Zug Grundform und 3 Alternativen (genau eine aktiv, vor dem
Kampf gewählt). Steuerung: L + Richtung = Zug, L halten = Spannen (siehe unten),
P = Meisterzug (3 Stufen Legendenleiste).

---

## Grunddaten

| | |
|---|---|
| **Name** | Spannkraft – Freier Lauf |
| **Kraft** | Federleib: ein Körper, der sich dehnen, stauchen und aufblähen lässt wie ein Gummiband, dazu *Eisenwille*, eine innere Willenskraft, die Gliedmaßen kurz hart wie Metall macht |
| **Thema** | Elastische Gliedmaßen verwandeln Schwung, Rückstoß und verrückte Einfälle in wuchtige Angriffe |
| **Seltenheit** | Legendär (mehr Auswahl und Spektakel, keine höheren Werte als Episch) |
| **Heimatwelt** | *Windstromarchipel* (Arbeitstitel): tausende kleine Inseln in einem warmen, sehr weiten Meer, verbunden durch launische Windströme. Wer dort aufwächst, lernt früh, dass jede Insel hinter dem Horizont ein neues Abenteuer verspricht. Hafenstädte aus bunten Holzhäusern, Seilbrücken, Leuchttürme, Kraken-Legenden |
| **Waffe** | Fäuste, Füße und der eigene Körper |
| **Spielgefühl** | Ungewöhnliche Reichweite, federnde Bewegung, verzögerte Treffer und explosive Kombos |
| **Gefühl wie** | Abenteuerlust, Trotz und ansteckende Freude am Unmöglichen |

---

## Stil-Mechanik

### Besondere Regel: Spannung und Rückstoß

**Spannen.** Ausgewählte Züge (markiert mit ⟲) lassen sich halten. Die Figur zieht
dabei Arm oder Bein weit nach hinten, das Glied dehnt sich sichtbar und vibriert.
Die Spannung hat drei Stufen:

| Halten | Stufe | Wirkung beim Loslassen |
|---|---|---|
| unter 0,2 s | – | normale Fassung |
| 0,2 s | Gespannt I | +25 % Reichweite, +15 % Schaden |
| 0,45 s | Gespannt II | +50 % Reichweite, +30 % Schaden, mehr Rückstoß |
| 0,75 s | **Voll gespannt** | +80 % Reichweite, +50 % Schaden, Status *Aus dem Gleichgewicht* |

- Ist mindestens 1 Stufe Legendenleiste vorhanden, verbraucht *Voll gespannt*
  automatisch diese Stufe und löst zusätzlich die **verstärkte Fassung** des Zugs
  aus (Details bei den Zügen). Ohne Leiste bleibt es bei der Tabelle oben. So
  ersetzt das Spannen in diesem Stil das sonst übliche „L halten = verstärkt“.
- Über 1,2 s hinaus gehalten, schnellt der Zug von selbst los (kein endloses Warten).
- **Risiko:** Verfehlt ein gespannter Zug, ist die Erholung länger: Gespannt I
  +0,1 s, II +0,2 s, Voll +0,35 s. Die Figur schnalzt dabei sichtbar zurück und
  taumelt kurz.
- Während des Spannens kann die Figur langsam gehen (40 % Tempo), aber nicht springen.
  Ein eingesteckter Treffer bricht das Spannen ab.

**Rückschwung übernehmen.** Trifft ein Zug, schnellt das Glied zurück. Wer in
diesem Moment (Fenster 0,3 s ab dem Treffer; ein Druck bis 0,15 s vor dem Treffer
wird gemerkt; angezeigt durch ein kurzes Aufblitzen am Glied und „Schwung!“ im HUD)
einen **anderen** Zug startet, nimmt den Schwung mit: Dessen Vorbereitung ist um
40 % kürzer, und Spannen erreicht die nächste Stufe 30 % schneller.

- Pro Kombofolge höchstens **3 Übergänge**. Angezeigt als drei kleine
  Federringe neben der Lebensleiste, die sich beim Übergang leeren.
- Derselbe Zug zweimal hintereinander zählt nicht als Übergang.
- Die Folge endet, wenn 1 s lang nichts trifft oder die Figur getroffen wird;
  danach sind alle drei Ringe wieder voll.
- Gilt die allgemeine Kombo-Abschwächung des Kampfsystems unverändert.

### Status-Effekt: Aus dem Gleichgewicht

Nur **voll gespannte Treffer** verursachen ihn: Der Gegner taumelt, und seine
Haltung (unsichtbare Widerstandsleiste der Gegner mit Super-Rüstung, wie bei
Schwarzmond) nimmt 3 s lang **+50 % Haltungsschaden**. Ein erneuter Treffer setzt
die Dauer auf 3 s zurück, verlängert aber nicht darüber hinaus. Bosse haben danach
6 s Ruhezeit, in der der Effekt nicht neu greift. Leichte Gegner rutschen dabei
zusätzlich ein Stück nach hinten.

### Kombi mit anderen Elementen

Der Rückstoß kann Gegner in **vorhandene Gefahrenflächen** befördern (Glutfeld aus
Glutatem, Eis, Stacheln der Umgebung, Abgründe in Dungeons). Wird ein Gegner durch
Rückstoß in eine solche Fläche geschleudert, löst sie sofort einmal aus, und der
Treffer zählt als Übergang, ohne einen Federring zu verbrauchen.

Im Spiel umgesetzt: Gegner, die von einem Treffer ab Spannung II (oder verstärkt,
oder von der Federkanone) weggeschleudert werden, fliegen 0,55 s lang als Geschoss.
Was sie treffen, nimmt Schaden („RUMMS!“), auch andere Gegner, die dann selbst
weiterfliegen (bis zu 2 Stufen Kettenreaktion). Fallen und Flächen der Umgebung
melden sich über die Gruppe `hazard_zones` (`hazard_rect()`, `trigger_on(node)`)
und werden so automatisch ausgelöst, sobald es sie gibt. Spannkraft bringt
selbst keine Elemente mit, sie arbeitet mit dem, was da ist.

---

## Die 6 Züge

Werte sind Startwerte zum Ausbalancieren (Schaden in Prozent eines normalen
Leichtschlags = 100). Alle Züge mit ⟲ lassen sich spannen. Die besondere
Bildsprache des Stils: Das Glied fliegt zuerst los, der Treffer kommt einen
Moment später (verzögerter Treffer, 0,05–0,1 s je nach Reichweite).

### Zug 1 – Schnappfaust ⟲ (neutral)

Ein gerader, elastischer Faustschlag mit größerer Reichweite als normaler
Nahkampf (1,8-fache Leichtschlag-Reichweite). Schaden 120.
**Verstärkt:** Die Faust schnappt doppelt zu (Hin- und Rückweg treffen, 120 + 90).

| Alternative | Wirkung |
|---|---|
| Schnelle Schnappfaust | Noch schneller, etwas weniger Reichweite; bester Übergangsstarter |
| Prasselfaust | Viele kurze Schläge (8 × 25) in einem begrenzten Bereich vor der Figur; Spannen verlängert die Dauer statt der Reichweite |
| Doppelstoß | Beide Hände treffen gemeinsam (200); langsamer, deutlich stärkerer Rückstoß |

### Zug 2 – Fegebein ⟲ (vor)

Ein verlängertes Bein fegt quer durch den Bereich vor der Figur. Schaden 140,
trifft auch Gegner am Boden.
**Verstärkt:** zwei Fegungen hin und zurück, die zweite wirft Gegner um.

| Alternative | Wirkung |
|---|---|
| Breites Fegebein | Große Fläche (+60 % Trefferzone), 0,2 s längere Erholung |
| Hakentritt | Zieht leichte Gegner zur Mitte des Angriffs, gut für Gruppen |
| Speerstoß | Beide Füße stoßen gerade nach vorne statt seitlich zu fegen (170, schmal, weit) |

### Zug 3 – Katapult ⟲ (hoch)

Die Figur greift kurz den Boden oder eine Kante, spannt sich und schießt diagonal
nach oben. Ein Treffer (130) nimmt den Gegner mit in die Luft.
**Verstärkt:** Am höchsten Punkt folgt ein Abschlussschlag, der den Gegner weiter
anhebt.

| Alternative | Wirkung |
|---|---|
| Hohes Katapult | Mehr Höhe, weniger seitliche Bewegung, für Luftkombos |
| Flaches Katapult | Weiter Vorstoß knapp über dem Boden |
| Himmelshaken | Keine Bewegung; die Faust schießt senkrecht nach oben (180), starker Abwehrschlag gegen Gegner über der Figur |

### Zug 4 – Prallbauch (neutral + Abwehr)

Die Figur bläht sich kurz kugelrund auf (0,4 s). Geeignete **stumpfe** Treffer
(Schläge, Keulen, Körpertreffer, stumpfe Geschosse) federn ab: kein Schaden, der
Angreifer wird leicht zurückgestoßen. **Scharfe** Angriffe (Klingen, Pfeile, Krallen)
und **besondere Energieangriffe** umgehen diesen Vorteil und werden wie ein normaler
Block behandelt (−50 %). Perfektes Timing (erste 0,15 s) wirkt wie ein Perfekt-Block.
**Verstärkt:** Der abgefederte Treffer wird mit doppelter Wucht als Druckwelle
zurückgegeben.

| Alternative | Wirkung |
|---|---|
| Rückprall | Mit perfektem Timing werden geeignete Geschosse zurückgeworfen; außerhalb des Fensters nur Block |
| Willensdeckung | Kurze, harte Armdeckung durch Eisenwille: hält **alle** Trefferarten (−70 %), ohne Reflexion |
| Federkörper | Ein abgefangener Treffer lässt die Figur zurückspringen und gibt sofort Spannung Stufe II für den nächsten Zug |

### Zug 5 – Spannzug (vor + Bewegung)

Die Figur greift einen geeigneten Punkt (Kante, Pfahl, Ankerpunkt, großer Gegner)
und zieht sich nach vorne; ein Folgeangriff trifft im Flug (110). Ohne passenden
Punkt erfolgt ein kürzerer federnder Sprung. Greifpunkte werden beim Halten von L
kurz hervorgehoben.
**Verstärkt:** Die Figur prallt am Ziel ab und landet mit Spannung Stufe II.

| Alternative | Wirkung |
|---|---|
| Langer Zug | +50 % Strecke, deutlichere Vorbereitung |
| Seitenschwung | Bogenförmige Bewegung um ein Ziel herum, endet hinter dem Gegner |
| Siedeschritt | Kurzer, sehr schneller Vorstoß im Siedepuls-Look (Hitzeflimmern, siehe Meisterzug A), 3 s statt 1,5 s Abklingzeit |

### Zug 6 – Fallbeilferse ⟲ (runter / Luft)

Ein hoch gestrecktes Bein schnellt nach unten und trifft einen schmalen Bereich
(190). Verfehlt der Tritt, steckt der Fuß kurz im Boden (0,35 s offen).
**Verstärkt:** Der Aufprall schleudert kleine Gegner zu beiden Seiten hoch.

| Alternative | Wirkung |
|---|---|
| Schweres Fallbeil | Langsame Vorbereitung, hoher Haltungsschaden |
| Doppelstampfer | Beide Füße treffen konzentriert ein Ziel (240), kein Flächenschaden |
| Wirbelsturz | Drehender Fall gegen mehrere Gegner, geringerer Einzelschaden (4 × 50) |

---

## Meisterzug – 3 Varianten

Alle drei kosten 3 Stufen Legendenleiste. Vor jedem Meisterzug grinst die Figur
breit und ballt die Faust; ein kurzer Manga-Panel-Cut-in zeigt das Grinsen.

### Variante A – Siedepuls: Dampfhagel (gegen ein Ziel)

Die Figur pumpt ihr Blut so schnell, dass die Haut leicht glüht und
**Hitzeflimmern** und feiner, hellgrauer Dampf aufsteigen. Dann entfesselt sie eine
kurze, rasante Schlagfolge vor sich (24 × 30, Abschluss 200). Stark gegen ein Ziel,
aber während der Ausführung nur begrenzt drehbar (einmal Richtungswechsel).
Danach 2 s Erschöpfung: Lauftempo −20 %.

### Variante B – Prallform: Federkanone (gegen ein großes Ziel)

Die Figur bläst einen Arm mit Luft auf, bis er dick wie ein Fass ist und in
sichtbaren Federwindungen gestaucht wird. Eisenwille legt einen matten,
stahlblauen Schimmer über den Arm. Nach 0,8 s Vorbereitung (gut sichtbar) entlädt
sich ein gewaltiger Fauststoß (850, sehr hoher Haltungsschaden). Der Rückstoß
schleudert leichte Gegner weit zurück, gern in Gefahrenflächen (siehe Kombi). Die
Figur selbst rutscht dabei ein Stück nach hinten.

### Variante C – Grenzenlos: Freier Lauf (Verwandlung, ergänzt)

Die Figur lacht laut los, und für **8 s** gelten für sie verrückte Comic-Regeln:

- Jeder Spannzug erreicht sofort **Voll gespannt**, ohne Halten und ohne
  Legendenleiste zu verbrauchen (nur verstärkte Fassung kostet dann nichts).
- Statt 3 sind **5 Übergänge** pro Folge erlaubt.
- Prallbauch federt auch scharfe Angriffe ab (Energieangriffe weiterhin nicht).
- Treffer verformen die Gegner kurz comichaft (Stauchen und Strecken, rein optisch,
  Gegner-Hitboxen bleiben gleich).
- Zum Abschluss ein großer Sprung mit Aufprall (500) im Umkreis.

Danach 3 s lang kein Spannen möglich (die Figur japst nach Luft). Kein Schaden-
Multiplikator: Die Stärke kommt aus Tempo und Freiheit, nicht aus Werten.

### Großes Bild

Glieder fliegen weit über den Bildschirmrand hinaus und schnellen zurück,
Bewegungslinien, Stauchen beim Aufprall, Strecken beim Abflug. Der Hintergrund
wird bei Variante C bunt und flächig wie ein Comic-Panel (Sonnengelb, Himmelblau,
Korallenrot), alle Effekte bekommen dicke, schwarze Umrisslinien.

---

## Optik

- **Effektfarben:** Korallenrot, Sonnengelb, Himmelblau, Hellgrau (Dampf),
  Stahlblau (Eisenwille). Bewusst **kein** reines Weiß als Verwandlungsfarbe und
  kein Rosa-Dampf.
- **Effekt-Stil:** Dehnlinien, Mehrfach-Fäuste als Nachbild, Stoßringe beim
  Aufprall, Squash & Stretch der ganzen Figur, Comic-Umrisse. Weich animiert
  (M.U.G.E.N-Stil), Texturen grau und per Verlauf eingefärbt, wie bei den anderen
  Stilen.
- **Lautmalerei:** „BOING“, „SCHNAPP“, „WUMMS“, „PRASSEL“
- **Posen:**
  - Arm weit nach hinten gezogen, Körper nach vorne gelehnt beim Spannen.
  - Breites Grinsen, Faust in die Handfläche vor dem Meisterzug.
  - Sitzend auf dem besiegten Gegner oder lachend auf dem Rücken liegend als Siegpose.

## Schwächen

- Voll gespannte Fehlschläge sind teuer (bis +0,35 s offen).
- Scharfe Waffen und Energieangriffe umgehen den Prallbauch.
- Ohne Greifpunkte ist Spannzug deutlich kürzer; offene Arenen nehmen Mobilität.
- Wenig Flächenschaden in den Grundformen; Gruppen brauchen die passenden Alternativen.

## Gacha

- **Banner:** „Kein Meer zu weit“
- **Duplikate:** nur Kosmetik: alternative Dehnlinien-Farben, Nachbild-Stile,
  neue Lacher und Siegposen. Keine Schadensboni.
- **Passendes Outfit (Creator):** *Deckshand-Tracht des Windstromarchipels*:
  weites, kurzärmeliges Leinenhemd in Senfgelb mit Knotengürtel, aufgekrempelte
  dunkelgrüne Segeltuchhose, Seilbandagen an den Unterarmen, Stiefel mit
  Messingschnallen, ein geflochtenes Seilarmband; als Kopfstück eine Kapitänsmütze
  aus Segeltuch mit Kompass-Abzeichen. Alternativ *Strand-Trainingskleidung*:
  ärmelloses Oberteil, Shorts in Türkis, barfuß mit Fußbandagen.

## Skillpunkte

6 Züge à 1 SP + 18 Alternativen à 2 SP + Meisterzug 4 SP + 2 Varianten à 2 SP
= 6 + 36 + 8 = **50 SP**.

## Umsetzung im Spiel

- Kein Waffen-Sprite nötig. Die Dehnung entsteht im Code: Arm/Bein als
  gestrecktes Segment zwischen Schulter-/Hüft-Anker und Faust-/Fuß-Sprite
  (Line2D oder gestrecktes Sprite mit 9-Slice), Faust und Fuß aus dem Creator-Körper.
- **Erledigt (2026-11-04):** 12 Effekt-Sprites mit PixelLab, 14 Generierungen,
  in `assets/combat/vfx/spannkraft/` (Liste dort im README).
- PixelLab (optional, später): Faust- und Fußendstücke in 8 Winkeln (8–12
  Generierungen), Prallbauch- und Prallform-Pose (2–4). Wird vorher angefragt.
- **Spielbar seit 2026-11-04** (PR #43): `scripts/spannkraft/` (FederCaster,
  FederFx, FederSuper, FederIcons), Daten `assets/combat/styles/spannkraft.json`,
  im Creator als Stil wählbar (die Figur kämpft ohne Waffe).
- Trefferarten für Prallbauch: Krallen und Dornen (Säbeltiger, Sumpfdorn) gelten
  als scharf, Feueratem (Glutigel) als Energie; beides geht durch. Schläge, Keulen,
  Körper und geworfene Holzscheite sind stumpf. Neue Gegner können `sharp` oder
  `energy` setzen.
- Greifpunkte für Spannzug: der nächste Gegner vor der Figur (bis 170 px, Langer
  Zug 250 px). Eigene Ankerpunkte im Level sind eine spätere Erweiterung.
- Klänge selbst synthetisiert (`tools/audio/synth_rubber.py`): Boing, Dehnen,
  Schnapp, Prall.
- Testlauf mit Screenshots: `tools/spannkraft/probe.gd`.
- Outfit Deckshand-Tracht (Hemd, Segeltuchhose, Stiefel) und Segeltuch-Kapitänsmütze
  (Frisur-Slot) mit PixelLab, 6 Generierungen; im Creator gesperrt, Freischaltung
  über das Gacha-Banner „Kein Meer zu weit“.

---

## Was umbenannt wurde

Das Spiel verwendet nur eigene Namen, Figuren und Markenzeichen. Ein elastischer
Körper als Kampfkraft ist eine allgemeine Idee und bleibt; Kaisers Mechanik ist
vollständig übernommen.

| Im Entwurf | Hier | Warum |
|---|---|---|
| Monkey D. Ruffy | „die Figur“ | Figur der Vorlage; Stil läuft auf der eigenen Creator-Figur |
| Strohhut – Grenzenlose Freiheit | Spannkraft – Freier Lauf | „Strohhut“ ist Spitzname und Markenzeichen der Vorlage |
| Gummikörper | Federleib | Begriff ist eng mit der Teufelsfrucht der Vorlage verbunden |
| Haki | Eisenwille | Fachbegriff der Vorlage |
| East Blue / Grandline | Windstromarchipel | Orte der Vorlage |
| Gum-Gum-… (Namensmuster aller Züge) | eigene, einzelne Namen ohne gemeinsames Präfix | Das Präfix-Muster ist das bekannteste Markenzeichen der Vorlage |
| Pistole / Gatling / Bazooka | Schnappfaust / Prasselfaust / Doppelstoß | Technik-Namen der Vorlage |
| Peitsche / Speer | Fegebein / Speerstoß | dito |
| Rakete | Katapult | dito |
| Ballon | Prallbauch | dito |
| Schleuder | Spannzug | dito |
| Axt / Stempel | Fallbeilferse / Doppelstampfer | dito |
| Haki-Deckung | Willensdeckung | Begriff der Vorlage |
| Jet-Schritt (Gear-2-Look) | Siedeschritt (Siedepuls-Look) | Technikname und Optik der Vorlage |
| Gear 2: Jet Gatling | Siedepuls: Dampfhagel | Name der Vorlage; eigene Optik: Hitzeflimmern und hellgrauer Dampf statt rosa Haut und Dampf |
| Gear 4: Kong Gun, Boundman-Form | Prallform: Federkanone | Namen und Form der Vorlage; nur ein Arm wird aufgeblasen, Federwindungen statt aufgeblähtem Ganzkörper mit schwarzen Armen |
| Gear 5 (weiße Gestalt, Trommel-Rhythmus) | Grenzenlos: Freier Lauf | Name und Optik der Vorlage; bunte Comic-Panel-Optik statt weißer Haare und weißer Kleidung |
| Strohhut, rote Weste, blaue Shorts, Sandalen, Narbe unter dem Auge | Deckshand-Tracht mit Segeltuchmütze | Markenzeichen-Look der Vorlage |

### Namensvorschläge zur Auswahl

- **Stil:** Spannkraft · Federkraft · Freilauf · Gummiwerk
- **Innere Kraft:** Eisenwille · Kernwille · Trotzkraft
- **Heimatwelt:** Windstromarchipel · Weite Kimm · Brandungsinseln
- **Meisterzug C:** Grenzenlos · Narrenfreiheit · Freier Lauf
