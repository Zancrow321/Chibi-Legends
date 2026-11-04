# Chibi Legends

2D-Action-Plattformer im Pixel-Art-Stil für den Browser, gebaut mit **Godot 4.3** (GDScript, Web-Export).
Spielwelt: die Multiversum-Akademie. Fähigkeiten und Outfits sind eigene Entwürfe nach typischen Anime-Archetypen.

![Trainingswald mit Kristallbruch-Reaktion](docs/screenshots/training-reaktionen.png)

## Stand: Phase 1 (Fundament)

- Chibi-Spielfigur (ca. 32 × 48 Pixel, in Ebenen gezeichnet) mit Laufen, Doppelsprung, Dash und Durch-Plattform-Fallen
- Katana-Combo mit drei Hieben und vier Fähigkeiten: Flammenschnitt, Frostlanze, Kettenblitz, Sturmklinge
- Element-Reaktionen: Dampfexplosion, Überladung, Kristallbruch, Feuersturm
- Trainingswald mit Trainingspuppen, Schaden pro Sekunde, Gesamtschaden und Reaktions-Quest
- HUD: Leisten oben links, Minikarte und Quests oben rechts, Fähigkeiten-Leiste und Menüleiste unten
- Tastatur und Gamepad

## Steuerung

| Aktion | Tastatur | Gamepad |
| --- | --- | --- |
| Laufen | A / D oder Pfeiltasten | Linker Stick / Steuerkreuz |
| Springen (2x = Doppelsprung) | Leertaste, W oder Pfeil hoch | A |
| Durch Plattform fallen | S + Leertaste | Unten + A |
| Dash | Shift | B |
| Katana-Combo | J | X |
| Fähigkeiten 1–4 | K, L, I, O (oder 1–4) | Y, RB, LB, RT |
| Unendlich Aura / Abklingzeiten zurücksetzen | U / R | – / Back |
| Look wechseln | C | Start |
| Hilfe ein/aus | H | – |

## Starten

**Im Godot-Editor:** Godot 4.3 öffnen, `project.godot` importieren, F5 drücken.

**Als Web-Build:** Jeder Push baut über GitHub Actions einen Web-Export (Artefakt `chibi-legends-web`).
Entpacken und über einen lokalen Server öffnen, z. B. `python3 -m http.server` im Ordner, dann `http://localhost:8000`.
Optional: GitHub Pages einrichten und die Repo-Variable `DEPLOY_PAGES=true` setzen, dann wird automatisch veröffentlicht.

## Aufbau

```
scripts/
  autoload/game_input.gd   Eingaben (Tastatur + Gamepad)
  data/game_data.gd        Elemente, Fähigkeiten, Reaktionen, Looks (reine Daten)
  combat/reactions.gd      Reaktionsregeln (reine Logik, später auch auf dem Server)
  combat/attack.gd         Hitboxen und Geschosse
  entities/                Spieler, Chibi-Grafik, Trainingspuppe
  world/                   Trainingswald und Parallax-Hintergrund
  fx/                      Schadenszahlen und Pixel-Effekte
  ui/hud.gd                HUD
```

Daten und Reaktionslogik hängen nicht an Szenen. Dadurch kann der spätere Godot-Headless-Server (Koop, Phase 4) denselben Code nutzen.

## Roadmap

1. **Fundament** (dieser Stand)
2. **Kernspiel:** alle 12 Fähigkeiten, Stil-Set-Boni, ausführliches Customizing, 5 Story-Level mit Boss, Wellen-Arena, Touch-Steuerung
3. **Online-Basis:** Supabase-Accounts, Cloud-Speicher, Gilden mit Chat, Bestenlisten
4. **Koop:** Godot-Server auf Fly.io, Gruppen bis 4 Spieler
5. **Gacha und Shop:** Banner, Pity, Stripe (Echtgeld erst nach Rechtsprüfung)

Grafik ist vorerst prozedural gezeichnet. Echte Sprites (z. B. aus PixelLab) ersetzen später die Ebenen in `chibi_visual.gd`.

## Lizenzen

Schrift: Pixelify Sans, SIL Open Font License 1.1 (siehe `assets/fonts/OFL-NOTICE.txt`).
