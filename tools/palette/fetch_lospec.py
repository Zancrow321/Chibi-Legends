"""Download a palette from lospec.com into assets/palettes/<slug>.hex.

    python3 tools/palette/fetch_lospec.py endesga-32
    python3 tools/palette/build.py

Needs lospec.com in the network allowlist of the environment. Then set
"master" in assets/palettes/config.json to switch the game palette.
"""

from __future__ import annotations

import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette as pal  # noqa: E402


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    slug = sys.argv[1].strip().lower()
    url = f"https://lospec.com/palette-list/{slug}.json"
    with urllib.request.urlopen(url, timeout=20) as r:
        data = json.load(r)
    colors = [pal.parse_hex(c) for c in data["colors"]]
    out = pal.PALETTE_DIR / f"{slug}.hex"
    out.write_text("\n".join(pal.to_hex(c) for c in colors) + "\n", encoding="utf-8")
    print(f"{data.get('name', slug)} von {data.get('author') or 'unbekannt'}: {len(colors)} Farben -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
