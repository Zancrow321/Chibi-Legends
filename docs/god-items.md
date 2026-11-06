# GOD-Stufe: weltweit einzigartige Teile

GOD ist die siebte Seltenheit über Mythisch (`Loot.GOD`). Es gibt 18 GOD-Teile, jedes **genau einmal auf der Welt**.

## Teile

| Serie I · Heilig | Platz | Effekt |
|---|---|---|
| Sonnenkrone des Seraphen | Accessoire (Look: Frisur-Slot) | schwebender Heiligenschein, drehender Strahlenkranz |
| Gewand des Ersten Lichts | Oberteil | goldene Aura, Lichtwelle, aufsteigende Funken |
| Beinkleid der Gnade | Hose | Bannkreis aus Licht-Runen am Boden |
| Schritte des Morgens | Schuhe | Lichtfedern bei jedem Schritt |
| Flügel des Seraphen | Talisman | schlagende Lichtflügel, rieselnde Federn |
| Glockenschwinge | Waffe Gleichklang | leuchtende Sense, Funkenschweif |
| Engelsruf | Waffe Bollwerk | heiliges Gewehr statt „Wachhund“ |
| Sonnenfäuste | Waffe Grenzbrecher | Sonnen-Aura an beiden Fäusten |
| Himmelswirbel | Waffe Wirbelwille | kreisender Himmelswind an den Fäusten |

| Serie II · Dämon | Platz | Effekt |
|---|---|---|
| Hörnerkrone des Abgrunds | Accessoire (Look: Frisur-Slot) | Flammen an beiden Hornspitzen, Rauch |
| Panzer des Höllenfürsten | Oberteil | rote Aura, glühende Adern |
| Kettenbeinkleid der Verdammnis | Hose | Höllenfeuer-Ring am Boden |
| Aschewandler | Schuhe | Glutabdrücke beim Laufen |
| Schwingen der Verdammnis | Talisman | Fledermausflügel aus Glut und Rauch |
| Höllenschlund | Waffe Glutatem | Dämonen-Katana |
| Mondfresser | Waffe Schwarzmond | riesige Halbmond-Klinge |
| Höllenfaust | Waffe Lauffeuer | Höllenfeuer an den Fäusten |
| Teufelsfeder | Waffe Spannkraft | purpurne Glut an den Fäusten |

Alle fünf Kleidungsteile einer Serie zusammen geben die **Erhebung**: Lichtsäule (Heilig) oder Höllentor (Dämon).
Beide Flügelpaare gleichzeitig (zwei Talisman-Plätze) geht auch: „Gefallener Engel“.

## Regeln

- Werte: alle sechs Werte voll, mal 3,2, wachsen mit der Spielerstufe. 3 Sockel, Waffen mit Mod ihres Stils.
- Nicht zerlegbar, nicht umschmiedbar, kommen auch bei voller Tasche an.
- Getragene GOD-Kleidung erzwingt ihren Look; im Creator sind die Teile nur für den Besitzer frei.
- Die GOD-Waffe zeigt sich nur mit ihrem Kampfstil (sie ersetzt die Grundwaffe des Stils).

## Vergabe (Server)

`supabase/migrations/0004_god_items.sql`: Tabelle `god_items` (Primärschlüssel = Teil, also nie doppelt),
`cl_god_roll(source, ref)` würfelt nach einem echten Sieg genau einmal:

- `raid`: je Essenwächter-Sieg des Tages, 0,4 %
- `world`: je abgeholtem Weltboss, 3 %
- `tower`: Wochen-Bestmarke ab Etage 20 in Zehnerschritten, 1 %

Gewinnt man, gibt es ein zufälliges noch freies Teil und die Enthüllung. `cl_god_mine` gleicht beim Login ab,
`cl_god_hall` zeigt die Besitzer. Wird ein Konto gelöscht, wird sein Teil wieder frei.

## Im Spiel

- **GOD-Halle**: Altar im Akademie-Hof (zwischen Brunnen und Kirschbaum). Alle Teile, Besitzer, Anprobe mit großer Figur.
- Offline (nur zum Ansehen): F9 in der Halle gibt Testbesitz, der beim nächsten Login verschwindet.

## Dateien

- Code: `scripts/game/god_items.gd`, `scripts/fx/god_fx.gd`, `scripts/ui/god_hall.gd`
- Art (PixelLab, eigene Entwürfe): `tools/god_items/gen_art.py`, Einbau `tools/god_items/install.py`
- Tests: `tools/god_items/test_god.gd` (CI), `supabase/test/test_4_god_items.sql`, Schaubild `tools/god_items/probe.gd`
