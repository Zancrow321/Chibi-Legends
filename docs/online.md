# Online-Basis (Endgame Schritt 3)

Supabase-Projekt `twfapncxxfykevinakke` (https://twfapncxxfykevinakke.supabase.co). Der Client (`scripts/autoload/online.gd`) meldet sich als Gast an und ruft Server-Funktionen auf. Ohne Verbindung läuft alles offline mit denselben Regeln weiter.

## Einmal einrichten (im Supabase-Dashboard)

1. **Schema einspielen:** SQL Editor → New query → Inhalt von `supabase/migrations/0001_online_base.sql` einfügen → Run. Kann gefahrlos wiederholt werden.
2. **Gast-Konten erlauben:** Authentication → Sign In / Providers → „Allow anonymous sign-ins“ an.

Der öffentliche Anon-Key steht im Client (so ist er gedacht). Der service_role-Key gehört nie ins Repo oder in den Chat.

## Was der Server entscheidet

| Funktion | Zweck |
| --- | --- |
| `cl_state()` | Profil anlegen/holen (Name, Raid-Marken, Turm-Woche) |
| `cl_claim_boss(boss, fight_seconds, level)` | Boss-Sieg: Marken, Tageschance, Bonus-Beute (Seltenheit, Teil-Art, Seed). Kampfzeit und Abstand werden grob geprüft, bis der Kampfserver (Schritt 4/5) mitschaut. |
| `cl_buy(kind, rarity, level)` | Raid-Marken gegen Wunschteil |
| `cl_tower(floor_reached)` | Turm-Wochenrekord, gibt den Platz zurück |
| `cl_tower_board()` | Wochen-Bestenliste Top 50 |
| `cl_set_name(name)` | Anzeigename |

Beute kommt als `{slot, rarity, ilvl, seed}`; `Online.build_item()` baut daraus mit festem Zufall immer dasselbe Teil. Spieler dürfen ihre Tabellen nur lesen, geschrieben wird nur über diese Funktionen.

Online gilt der Marken-Stand des Servers; offline gesammelte Marken werden nicht hochgeladen (sonst wären sie fälschbar). Edelsteine aus dem Raid würfelt vorerst noch der Client.

## Tests

- `supabase/test/run.sh`: Wegwerf-Postgres, Schema zweimal einspielen, Regeln und Rechte prüfen (CI-Job „datenbank“).
- `tools/online/test_online.gd`: Client bleibt headless offline, Seed-Beute ist stabil.
- Web: `?offline=1` schaltet die Verbindung ab.

## Gilden (`supabase/migrations/0002_guilds.sql`, Schritt 6)

Gildenhaus im Akademie-Hof (x 385, PixelLab-Sprite `guild_hall`), Bildschirm `scripts/guild/guild_screen.gd`.

| Regel | Wert |
| --- | --- |
| Gründen | Name 3-20 Zeichen, Kürzel 2-4 Buchstaben/Ziffern, beides eindeutig. Eine Gilde pro Spieler. |
| Stufen | 1-10, Stufe n → n+1 braucht n × 1000 Gilden-XP. Plätze 15 + 5 je Stufe (Stufe 10: 60). |
| XP | Essenwächter/Turmwache 20, neue Turm-Etage 2, Raid-Marke 1, erfülltes Wochenziel 400. Der Server zählt selbst mit (Trigger), Spieler melden nichts. |
| Wochenziele | Drei aus: Essenwächter 15, Turm-Etagen 120, Raid-Marken 100, Turmwachen 25. Jede Woche fällt ein anderes weg. Erfülltes Ziel = Trophäe in der Halle. |
| Boni | +1 % EXP je Stufe; ab Stufe 5 +1 Raid-Marke pro Essenwächter. Banner-Farben: 2 zum Start, eine mehr je Stufe (8 insgesamt). |
| Ränge | Anführer (Banner, Ränge, entfernen), Offizier (Mitglieder entfernen), Mitglied. Geht der Anführer, übernimmt der dienstälteste Offizier, sonst das älteste Mitglied; leere Gilden lösen sich auf. |
| Später | Gilden-Krieg 4v4 und Wochen-Liga brauchen den Kampfserver. |

## Weltbosse (`supabase/migrations/0003_world_boss.sql`, Schritt 8)

Braucht 0001 und 0002. Einspielen wie die anderen: SQL Editor, Inhalt einfügen, Run.

- `world_bosses`: ein Boss mit EINER Lebensleiste für alle (`hp`, `max_hp`), lebt 72 Stunden.
  Nach Sieg oder Flucht 20 Minuten Pause, dann öffnet sich der Riss neu mit
  60 000 Lebenspunkten je Spieler, der beim letzten Boss Schaden gemacht hat (höchstens 40).
- `world_hits`: Schaden pro Spieler und Boss, Zeitpunkt der letzten Meldung, Beute abgeholt.
- `cl_world_state()`: Stand für das Spiel (Leiste, wer gerade kämpft, Bestenliste, eigener Platz,
  `next_in` bis zum nächsten Riss).
- `cl_world_hit(boss_id, damage, seconds)`: das Spiel meldet alle ~8 Sekunden den eigenen Schaden.
  Der Server glaubt höchstens 1500 Schaden pro Sekunde seit der letzten Meldung (höchstens 60 s).
- `cl_world_claim(boss_id, level)`: nach dem Sieg einmal Beute holen, ab 0,5 % Anteil:
  4 Raid-Marken + bis zu 4 für den Anteil + 2 für den letzten Schlag, ein Teil ab Episch,
  ein zweites für die drei Besten oder ab 10 % Anteil.

Offline (oder solange 0003 fehlt) kämpft das Spiel gegen einen eigenen Pool (`user://weltboss.json`).
