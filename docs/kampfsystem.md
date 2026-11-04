# Kampfsystem (Prototyp, Schritt 1 und 2)

Entwurf: https://claude.ai/artifact/FSD49UZN5gsPBd6rWWknXc . Eigene Regeln und Zahlen, nur die Genre-Prinzipien der DS-Arena-Fighter dienen als Vorbild.

## Steuerung

Drei Angriffstasten, jede mit Richtung. Die Richtung zählt in dem Moment, in dem die Taste gedrückt wird.

| Taste | neutral | vor | oben | unten | Luft |
| --- | --- | --- | --- | --- | --- |
| Leicht (J) | Kette aus 3 Hieben | Stich mit Vorschub | Aufwärtsschnitt (hebt leicht an) | Tiefer Schnitt | Luftschnitt |
| Schwer (K) | Schwerer Hieb | Wegstoß | Hochschlag (schleudert hoch) | Feger (hebt an) | Abwärtsschlag (schmettert runter) |
| Spezial (L) | Fähigkeit 1 | Fähigkeit 2 | Fähigkeit 3 | Fähigkeit 4 | Fähigkeit 1 |

Griff: Leicht und Schwer zusammen (bis 3 Bilder Abstand).

## Abbrech-Regeln

- Leicht-Kette: der nächste Leicht-Druck läuft ab der Erholungsphase des vorigen Hiebs.
- Nach einem Treffer: Leicht kann in Schwer, Leicht und Schwer können in Spezial abgebrochen werden.
- Sonst wartet der nächste Druck, bis der Angriff fertig ist (kein Eingabeverlust).

## Datenformat

Jeder Charakter hat eine Datei `assets/combat/movesets/<id>.json`. Pro Angriff:

| Feld | Bedeutung |
| --- | --- |
| button, dir | light / heavy / grab und neutral / forward / up / down / air |
| startup, active, recovery | Bilder bei 60 fps |
| damage | Grundschaden |
| hitbox | [x, y, Breite, Höhe], Mitte relativ zum Fußpunkt, Blick nach rechts |
| knockback, launch | Rückstoß zur Seite, Wurf nach oben (negativ = nach unten) |
| lunge | Vorschub während Anlauf und aktiv |
| chain | nächster Angriff der Kette |
| profile | Treffergefühl (light / heavy) |
| draw, angle, phase | Aussehen des Schlag-Bogens |
| pose | Bilder aus dem Schwertstreifen je Phase |

## Noch nicht drin (Schritte 3 bis 5)

Legendenleiste mit 3 Stufen, Block, Perfekt-Block, Ausweich-Dash mit Unverwundbarkeit, Befreiungsstoß, Schadensformel mit Kombo-Abschwächung, Gewichtsklassen, Statuseffekte, Arena mit Pickups, Helfer, KI-Gegner. Der Super läuft bis Schritt 3 weiter über die Abklingzeit.

Die Testfigur hat bisher nur Stand- und Schwertbilder. Laufen, Springen und Dash sind daraus mit Neigung und Stauchung im Code gebaut, bis eigene Bilder kommen.
