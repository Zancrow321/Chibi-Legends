# Fremd-Skills in diesem Repo

## pixellab-pip

- Quelle: https://github.com/Shilo/pixellab-pip
- Version: v3.1.0 (Commit 4fe90d5366dfc7e909fc9423bd9a445a27e58c39), Ordner `skills/pixellab-pip/`
- Lizenz: MIT, siehe `pixellab-pip/LICENSE.md`
- Unverändert kopiert (ohne die lokale Einstellungsdatei `pixellab-pip.json`).

### Projekt-Abweichungen (gelten vor den Anweisungen im Skill)

- Der PixelLab-Token liegt in der Umgebungsvariable `PIXELLAB_API_KEY`, nicht in
  `PIXELLAB_SECRET`. Für REST-Aufrufe `Authorization: Bearer $PIXELLAB_API_KEY`
  verwenden. Der Wert wird nie ausgegeben, geloggt oder ins Repo geschrieben.
- PixelLab MCP ist über `/.mcp.json` angebunden (verweist ebenfalls nur auf
  `${PIXELLAB_API_KEY}`).
- Ausgaben, die Generierungen gekostet haben, vor Session-Ende nach `assets/`
  übernehmen und committen; die Cloud-VM wird danach gelöscht.

### Update

Neue Version bewusst per PR übernehmen:

```sh
git clone https://github.com/Shilo/pixellab-pip /tmp/pip
git -C /tmp/pip archive <tag> skills/pixellab-pip | tar -x -C .claude/skills --strip-components=1
rm -f .claude/skills/pixellab-pip/pixellab-pip.json
```

Dann Diff prüfen, Version oben anpassen, committen.
