"""Fetch the curated CC0 placeholder assets (Kenney) into assets/third_party/.

    python3 tools/assets/import_cc0.py            # clone sources (git), copy, convert
    python3 tools/assets/import_cc0.py --src DIR  # reuse clones already in DIR

Everything here is CC0 (public domain): free for commercial use, no credit
required. We credit Kenney anyway in assets/third_party/LICENSES.md, which this
script rewrites together with manifest.json (one entry per output file group).

Sources are pinned to exact commits, so a re-run gives the same files:
- shorepine/kenney: full Kenney library, organized by pack (CC0)
- Calinou/kenney-*: Kenney audio/particle packs, packaged for Godot (CC0)
- KenneyNL/Starter-Kit-3D-Platformer: official Kenney kit; sounds are CC0
  (the kit's code is MIT, but we take only the sound files)

kenney.nl / opengameart.org are not reachable from the cloud environment, so we
use these GitHub mirrors. Add new packs to PACKS below, never hand-copy files
without a manifest entry.

Conversions: WAV -> OGG (smaller web build, needs ffmpeg), big soft particle
textures -> 64 px, numbered frames -> one horizontal strip (square cells,
same format as assets/vfx), 16 px tile folders -> one atlas sheet.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "third_party"

SOURCES = {
    "kenney_lib": ("https://github.com/shorepine/kenney", "3694c6879e487c108f55677be7dd2ca75b07cc3b"),
    "interface_sounds": ("https://github.com/Calinou/kenney-interface-sounds", "4596a49eaf5a533948d49a47467f606bcdea70ff"),
    "ui_audio": ("https://github.com/Calinou/kenney-ui-audio", "8c3d81b9159d058c444f89d12d518276b0b09345"),
    "particle_pack": ("https://github.com/Calinou/kenney-particle-pack", "ab7086639ee73be31abd87feb21bf1402d4e8144"),
    "impact_sounds": ("https://github.com/Boyquotes/kenney-impact-sounds-for-godot", "999dd1684873f8b020a3aa5b26e713da21688924"),
    "platformer_kit": ("https://github.com/KenneyNL/Starter-Kit-3D-Platformer", "3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0"),
}

# Sparse paths for the big library (avoid downloading 50k files).
SPARSE = {
    "kenney_lib": [
        "ui/UI Pack - Pixel Adventure", "ui/Fantasy UI Borders", "ui/Mobile Controls/Sprites/Style A",
        "ui/Mobile Controls/Sprites/Icons", "icons/Input Prompts Pixel", "icons/Game Icons/White/1x",
        "2d/Explosion Pack", "2d/Smoke Particles/White puff", "2d/Smoke Particles/Flash",
    ],
}

# (pack title, kenney.nl page, source, glob, destination, conversion)
PACKS = [
    # --- UI ---
    ("UI Pack - Pixel Adventure", "https://kenney.nl/assets/ui-pack-pixel-adventure", "kenney_lib",
     "ui/UI Pack - Pixel Adventure/Tiles/*/*", "ui/pixel_adventure", "atlas"),
    ("Fantasy UI Borders", "https://kenney.nl/assets/fantasy-ui-borders", "kenney_lib",
     "ui/Fantasy UI Borders/**/*.png", "ui/fantasy_borders", "copy_tree"),
    ("Input Prompts Pixel", "https://kenney.nl/assets/input-prompts-pixel-16", "kenney_lib",
     "icons/Input Prompts Pixel/Tiles", "ui/input_prompts", "atlas"),
    ("Game Icons", "https://kenney.nl/assets/game-icons", "kenney_lib",
     "icons/Game Icons/White/1x/*.png", "ui/game_icons", "copy"),
    ("Mobile Controls", "https://kenney.nl/assets/mobile-controls", "kenney_lib",
     "ui/Mobile Controls/Sprites/Style A/*.png", "ui/mobile_controls", "copy"),
    ("Mobile Controls (Icons)", "https://kenney.nl/assets/mobile-controls", "kenney_lib",
     "ui/Mobile Controls/Sprites/Icons/*.png", "ui/mobile_controls/icons", "copy"),
    # --- SFX ---
    ("Interface Sounds", "https://kenney.nl/assets/interface-sounds", "interface_sounds",
     "addons/*/*.wav", "sfx/interface", "ogg"),
    ("UI Audio", "https://kenney.nl/assets/ui-audio", "ui_audio",
     "addons/*/*.wav", "sfx/ui", "ogg"),
    ("Impact Sounds", "https://kenney.nl/assets/impact-sounds", "impact_sounds",
     "addons/*/*.ogg", "sfx/impact", "copy"),
    ("Starter Kit 3D Platformer (Sounds)", "https://github.com/KenneyNL/Starter-Kit-3D-Platformer", "platformer_kit",
     "sounds/*.ogg", "sfx/movement", "copy"),
    # --- VFX ---
    ("Particle Pack", "https://kenney.nl/assets/particle-pack", "particle_pack",
     "addons/*/*.png", "vfx/particles", "shrink64"),
    ("Explosion Pack (Pixel)", "https://kenney.nl/assets/explosion-pack", "kenney_lib",
     "2d/Explosion Pack/Pixel explosion", "vfx/explosions/pixel_explosion.png", "strip"),
    ("Explosion Pack (Regular)", "https://kenney.nl/assets/explosion-pack", "kenney_lib",
     "2d/Explosion Pack/Regular explosion", "vfx/explosions/regular_explosion.png", "strip"),
    ("Explosion Pack (Simple)", "https://kenney.nl/assets/explosion-pack", "kenney_lib",
     "2d/Explosion Pack/Simple explosion", "vfx/explosions/simple_explosion.png", "strip"),
    ("Explosion Pack (Sonic)", "https://kenney.nl/assets/explosion-pack", "kenney_lib",
     "2d/Explosion Pack/Sonic explosion", "vfx/explosions/sonic_explosion.png", "strip"),
    ("Smoke Particles (White puff)", "https://kenney.nl/assets/smoke-particles", "kenney_lib",
     "2d/Smoke Particles/White puff", "vfx/smoke/white_puff.png", "strip64"),
    ("Smoke Particles (Flash)", "https://kenney.nl/assets/smoke-particles", "kenney_lib",
     "2d/Smoke Particles/Flash", "vfx/smoke/flash.png", "strip64"),
]


def clone(name: str, dest: Path) -> Path:
    url, commit = SOURCES[name]
    path = dest / name
    if path.exists():
        return path
    if name in SPARSE:
        subprocess.run(["git", "clone", "-q", "--filter=blob:none", "--no-checkout", url, str(path)], check=True)
        subprocess.run(["git", "-C", str(path), "sparse-checkout", "set", "--no-cone", *[f"/{p}/" for p in SPARSE[name]]],
                       check=True)
    else:
        subprocess.run(["git", "clone", "-q", "--no-checkout", url, str(path)], check=True)
    subprocess.run(["git", "-C", str(path), "checkout", "-q", commit], check=True)
    return path


def _num(p: Path) -> int:
    m = re.findall(r"\d+", p.stem)
    return int(m[-1]) if m else 0


def safe_name(name: str) -> str:
    return re.sub(r"[^a-z0-9_.-]+", "_", name.lower()).strip("_")


def ogg(src: Path, dst: Path) -> None:
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-c:a", "libvorbis", "-q:a", "4", str(dst)],
                   check=True)


def strip(frames: list[Path], dst: Path, cell_max: int = 0) -> dict:
    imgs = [Image.open(f).convert("RGBA") for f in sorted(frames, key=_num)]
    cell = max(max(i.size) for i in imgs)
    if cell_max and cell > cell_max:
        scale = cell_max / cell
        imgs = [i.resize((max(1, round(i.width * scale)), max(1, round(i.height * scale))), Image.LANCZOS) for i in imgs]
        cell = cell_max
    sheet = Image.new("RGBA", (cell * len(imgs), cell), (0, 0, 0, 0))
    for k, i in enumerate(imgs):
        sheet.alpha_composite(i, (k * cell + (cell - i.width) // 2, (cell - i.height) // 2))
    sheet.save(dst)
    return {"frames": len(imgs), "cell": cell}


def atlas(tiles: list[Path], dst: Path, columns: int = 32) -> dict:
    """Pack tile_NNNN.png files into one sheet; atlas index = tile number."""
    tiles = sorted(tiles, key=_num)
    size = Image.open(tiles[0]).size
    count = _num(tiles[-1]) + 1
    rows = (count + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * size[0], rows * size[1]), (0, 0, 0, 0))
    for t in tiles:
        n = _num(t)
        sheet.alpha_composite(Image.open(t).convert("RGBA"), ((n % columns) * size[0], (n // columns) * size[1]))
    sheet.save(dst)
    return {"tiles": len(tiles), "tile_size": list(size), "columns": columns}


def run_pack(pack: tuple, src_root: Path) -> dict:
    title, page, source, pattern, dest, mode = pack
    base = src_root / source
    out = OUT / "kenney" / dest
    entry = {"pack": title, "author": "Kenney (www.kenney.nl)", "license": "CC0-1.0", "page": page,
             "source": f"{SOURCES[source][0]}@{SOURCES[source][1][:12]}", "path": f"assets/third_party/kenney/{dest}"}

    if mode in ("strip", "strip64"):
        out.parent.mkdir(parents=True, exist_ok=True)
        entry.update(strip(list((base / pattern).glob("*.png")), out, 64 if mode == "strip64" else 0))
        return entry

    if mode == "atlas":
        out.mkdir(parents=True, exist_ok=True)
        groups: dict[str, list[Path]] = {}
        if (base / pattern).is_dir():
            groups["tiles"] = list((base / pattern).glob("*.png"))
        else:
            for d in base.glob(pattern):
                if d.is_dir():
                    rel = d.relative_to(base / pattern.split("/*")[0])
                    groups[safe_name("_".join(rel.parts))] = list(d.glob("*.png"))
        entry["sheets"] = {}
        for name, tiles in sorted(groups.items()):
            entry["sheets"][f"{name}.png"] = atlas(tiles, out / f"{name}.png")
        return entry

    files = [f for f in base.glob(pattern) if f.is_file()]
    if mode == "copy_tree":
        root = base / pattern.split("/**")[0]
    out.mkdir(parents=True, exist_ok=True)
    for f in files:
        if mode == "copy_tree":
            rel = f.relative_to(root)
            dst = out.joinpath(*[safe_name(p) for p in rel.parts])
            dst.parent.mkdir(parents=True, exist_ok=True)
        else:
            dst = out / safe_name(f.name)
        if mode == "ogg":
            ogg(f, dst.with_suffix(".ogg"))
        elif mode == "shrink64":
            img = Image.open(f).convert("RGBA")
            img.thumbnail((64, 64), Image.LANCZOS)
            img.save(dst)
        else:
            shutil.copyfile(f, dst)
    entry["files"] = len(files)
    return entry


def write_licenses(entries: list) -> None:
    (OUT / "manifest.json").write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    lines = [
        "# Fremd-Assets und Lizenzen",
        "",
        "Platzhalter für UI, Sound und Effekte. Alles hier ist **CC0 1.0** (Public Domain):",
        "kommerzielle Nutzung erlaubt, keine Namensnennung nötig. Wir nennen Kenney trotzdem im Abspann.",
        "Diese Datei und `manifest.json` schreibt `tools/assets/import_cc0.py`; nicht von Hand ändern.",
        "",
        "| Paket | Urheber | Lizenz | Ordner | Quelle |",
        "| --- | --- | --- | --- | --- |",
    ]
    for e in entries:
        lines.append(f"| [{e['pack']}]({e['page']}) | {e['author']} | {e['license']} | `{e['path']}` | `{e['source']}` |")
    lines += [
        "",
        "CC0-Text: https://creativecommons.org/publicdomain/zero/1.0/legalcode",
        "",
        "Unterstützen: https://kenney.nl/donate",
        "",
    ]
    (OUT / "LICENSES.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", help="Ordner für die Git-Klone (Standard: build/cc0_src)")
    args = ap.parse_args()
    src = Path(args.src) if args.src else ROOT / "build" / "cc0_src"
    src.mkdir(parents=True, exist_ok=True)
    for name in sorted({p[2] for p in PACKS}):
        clone(name, src)
    kenney = OUT / "kenney"
    if kenney.exists():
        shutil.rmtree(kenney)
    entries = []
    for pack in PACKS:
        e = run_pack(pack, src)
        entries.append(e)
        print(f"{e['pack']}: {e.get('files') or e.get('frames') or len(e.get('sheets', {}))} -> {e['path']}")
    write_licenses(entries)
    return 0


if __name__ == "__main__":
    sys.exit(main())
