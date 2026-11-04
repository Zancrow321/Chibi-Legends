# Effekte Kampfstil Grenzbrecher

Eigene Effekt-Sprites, mit PixelLab erzeugt (`tools/grenzbrecher/gen_fx.py`, pixflux,
128×128, transparent). 11 Generierungen am 2026-11-04 (Kaiser freigegeben).
Additiv mit Bloom gezeichnet (`scripts/grenzbrecher/grenz_fx.gd`); Bewegung, Strahl,
Aura-Flammen, Ki-Kugeln und schwebende Steine entstehen im Code.
Vorschau: `python3 -I tools/grenzbrecher/preview.py <ordner>`.

| Datei | Verwendung |
|---|---|
| kern | Mündung des Kernstrahls, Ki-Kugeln, Treffer am Strahlende |
| strahl | Textur im Kernstrahl und Fernstrahl |
| schockring | Ki-Erschütterung, verstärkte Fassungen, Konter |
| faust | Treffer der Steilpfad-Folge |
| tritt | Drehtritt, Lufttritt, Rücktritt |
| aura | Aura beim Sammeln, Ki-Auftrieb, Meisterzug-Intro |
| fernschritt | Fernschritt und Fernstrahl (Teleport) |
| meteor | Meteor-Abschluss |
| grenzbruch | Lichtsäule Meisterzug A |
| sonnenkern | Mini-Sonne Meisterzug C |
| einschlag | Einschlag Sonnenkern und Fernstrahl-Ende |
