#!/usr/bin/env python3
"""PixelLab item frames, one per rarity (Loot.RARITIES order): 96x96 pixflux,
2 candidates each (seeds), 1 generation per image. pick.py turns the chosen
candidate into assets/items/frames/<rarity>.png (slot with its inner
background) and <rarity>_rand.png (hollow, for the item card nine-slice).
Key only from PIXELLAB_API_KEY.

    python3 -I tools/item_frames/gen_frames.py [rarity ...]   (missing only)
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "items" / "frames" / "raw"
SIZE = 96
SEEDS = [77, 311]
BASE = ("square picture frame border, empty hollow middle, game UI inventory slot, "
        "pixel art, front view, symmetric, no text, no item inside")

RARITIES = {
    "gewoehnlich": "plain worn grey iron frame with simple round rivets in the four corners",
    "ungewoehnlich": "bronze frame wrapped with green jade vines, small leaves and green gems in the four corners",
    "selten": "polished blue steel frame with silver rivets and sapphire gems in the four corners",
    "episch": "purple amethyst crystal frame with silver filigree and glowing violet gems in the four corners",
    "legendaer": "ornate golden frame with sun engravings and glowing amber gems in the four corners",
    "mythisch": "crimson and black dragon scale frame with flame ornaments, small horns and glowing red gems in the four corners",
}


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    log_p = RAW / "log.json"
    log = json.loads(log_p.read_text()) if log_p.exists() else {}
    want = sys.argv[1:] or list(RARITIES)
    before = pl2.balance()
    for rid in want:
        for s in SEEDS:
            if (RAW / f"{rid}_{s}.png").exists():
                continue
            p = {"description": RARITIES[rid] + ", " + BASE, "image_size": {"width": SIZE, "height": SIZE},
                 "outline": "single color black outline", "detail": "highly detailed",
                 "no_background": True, "text_guidance_scale": 9, "seed": s}
            r = pl2.post("/create-image-pixflux", p)
            pl2.to_img(r["image"]).save(RAW / f"{rid}_{s}.png")
            log[f"{rid}_{s}"] = {"prompt": p["description"], "seed": s, "usage": r.get("usage")}
            print(rid, s, r.get("usage"), flush=True)
    log_p.write_text(json.dumps(log, indent=1, ensure_ascii=False))
    print("Generierungen:", round(before - pl2.balance(), 2))


if __name__ == "__main__":
    main()
