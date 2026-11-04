# Spielmenü, Fortschritt und Beute

Das Spielmenü öffnet sich mit **Esc** (im Hof auch über die Knöpfe unten rechts)
und pausiert das Spiel. Reiter wechseln mit Q/E oder 1-3, die Maus geht überall.

| Reiter | Inhalt |
| --- | --- |
| Charakter | Figur, Stufe und EXP, alle Werte, die drei Ausrüstungsplätze, „Aussehen ändern“ (Creator) |
| Inventar | Tasche mit 30 Plätzen, Karte mit Vergleich zum angelegten Teil, Anlegen (Leer), Zerlegen in Splitter (X), Sortieren (R) |
| Optionen | Gesamt- und Effektlautstärke, Effektstärke, Grafik, Schadenszahlen, Bildschirmwackeln, Vollbild |

## Fortschritt (`scripts/game/profile.gd`)

- Stufe und EXP bleiben über Kämpfe hinweg (gespeichert in `user://profil.json`).
  EXP für die nächste Stufe: 300 + 120 je Stufe. Pro Stufe +3 % Leben und +2 % Schaden.
- Splitter: jeder Gegner gibt EXP/4, Zerlegen gibt mehr je Seltenheit.
- Ausrüstung ist kontoweit: Waffe, Rüstung, Talisman.

## Beute (`scripts/game/loot.gd`, `loot_drop.gd`)

- Elite-Gegner lassen immer etwas fallen (mindestens Selten), andere zu 35 %.
- Seltenheit: Gewöhnlich (1 Wert), Selten (2), Episch (3), Legendär (4 Werte + Spruch).
- Werte werden zufällig gewürfelt: Schaden, Leben, Krit-Chance, Leistenladung.
  Jeder Platz würfelt zuerst seinen Hauptwert (Waffe Schaden, Rüstung Leben,
  Talisman Leistenladung). Die Gegenstandsstufe ist die Spielerstufe beim Fund.
- Beute springt aus dem Gegner, landet mit einer Lichtsäule in der Seltenheitsfarbe
  und fliegt in die Tasche, wenn man nah ist (oder nach drei Sekunden).
  Ist die Tasche voll, wird sie sofort zu Splittern.
- Kritische Treffer: 5 % Grundchance, 150 % Schaden, gelbe Zahl und „KRITISCH!“.

Die Symbole der Gegenstände sind gezeichnet (`scripts/game/item_icon.gd`), keine Bilder.
