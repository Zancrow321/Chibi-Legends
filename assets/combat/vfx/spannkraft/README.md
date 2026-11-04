# Effekte Kampfstil Spannkraft

Eigene Effekt-Sprites, mit PixelLab erzeugt (`tools/spannkraft/gen_fx.py`, pixflux,
128×128, transparent). 14 Generierungen am 2026-11-04 (12 Effekte, 2 Nachbesserungen:
Fallbeilferse und Federkanone). `federkanone.png` ist gespiegelt, damit sich der
Kegel in Schlagrichtung (rechts) weitet.

Gedacht für additive Darstellung mit Bloom (`scripts/fx/bloom.gd`); Bewegung
(Wachsen, Ausblenden, Spiegeln in Schlagrichtung) entsteht im Code.
Vorschau: `python3 -I tools/spannkraft/preview.py <ordner>`.

| Datei | Zug |
|---|---|
| schnappfaust | Zug 1 Grundform (Dehnspur mit Faust) |
| prasselfaust | Zug 1 Alternative Prasselfaust |
| fegebein | Zug 2 |
| katapult | Zug 3 |
| prallbauch | Zug 4 |
| spannzug | Zug 5 |
| fallbeil | Zug 6 Fallbeilferse (Aufprall) |
| stossring | Treffer „voll gespannt“ / Aus dem Gleichgewicht |
| dampfhagel | Meisterzug A Siedepuls |
| eisenwille | Eisenwille (Willensdeckung, Prallform-Arm) |
| federkanone | Meisterzug B Prallform |
| grenzenlos | Meisterzug C Grenzenlos |
