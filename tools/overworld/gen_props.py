#!/usr/bin/env python3
"""Generates the overworld props and NPCs with PixelLab (1 generation each,
pixflux for props, pixen for NPCs). Raw results go to assets/overworld/raw/,
tools/overworld/finish.py cleans and places them. Key only from
PIXELLAB_API_KEY. Usage:
    python3 tools/overworld/gen_props.py [name ...]   # default: all missing
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "jus_style"))
import pl2  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "overworld" / "raw"
STYLE = ("pixel art game asset, side view, bright saturated colors, cel shading with hard edges, "
         "bold dark outline, original fantasy magic academy design, clean readable silhouette, "
         "whole object fits inside the canvas")
NPC_STYLE = ("chibi anime character, 2.7 heads tall, big head with large expressive anime eyes, slim body with real arms and legs, "
             "standing calm idle pose, side view facing right, full body, bright saturated colors, cel shading, bold dark outline, "
             "whole body fits inside the canvas with a small margin")

PROPS = {
    "gate_wald": (128, 128, "tall stone archway gate of a magic academy, carved pale stone pillars with green moss and small vines, "
                  "glowing teal rune circle portal inside the arch, little green leaves floating, stone steps at the base"),
    "gate_glut": (128, 128, "tall dark basalt archway gate, sealed with heavy iron chains and a big glowing orange padlock seal, "
                  "orange glowing cracks and embers, hot forge theme, stone steps at the base"),
    "fountain": (128, 128, "round white marble fountain on a town plaza, two tiers, clear blue water splashing, "
                 "a small golden star ornament on top"),
    "board": (64, 64, "wooden quest notice board on two posts, small paper notes pinned on it, little red roof on top"),
    "forge_stall": (128, 128, "small blacksmith market stall with a red cloth awning, stone forge with glowing orange coals, "
                    "anvil in front, swords and a hammer hanging on the wall"),
    "shrine": (128, 128, "small elegant star shrine, white stone pedestal with a floating glowing blue star crystal, "
               "dark blue tiled roof with golden trim, lanterns at both sides"),
    "sakura": (192, 192, "big cherry blossom tree with a thick curved trunk and a wide crown of pink blossoms, "
               "a few petals falling"),
    "dorm": (192, 192, "front of a cozy academy dormitory building, cream plaster walls with dark wood beams, "
             "dark teal tiled roof, warm lit windows, wooden double door with three stone steps, flower boxes"),
}
NPCS = {
    "npc_rektorin": "elegant academy headmistress woman, long silver hair in a high ponytail, calm smile, long navy blue coat with golden trim, holding a closed book",
    "npc_schmiedin": "young blacksmith girl, short messy red hair with goggles on her head, rolled up sleeves, brown leather apron over a white shirt, big hammer on her shoulder",
    "npc_hueter": "gentle shrine keeper boy, black hair tied back, white and light blue robe with wide sleeves, holding a small glowing star lantern",
    "npc_waechter": "big friendly academy gate guard, broad shoulders, short dark green hair, light steel armor over a green tunic, holding a spear upright",
}


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    want = sys.argv[1:] or [n for n in list(PROPS) + list(NPCS) if not (RAW / f"{n}.png").exists()]
    log_path = RAW / "log.json"
    log = json.loads(log_path.read_text()) if log_path.exists() else {}
    before = pl2.balance()
    for name in want:
        if name in PROPS:
            w, h, desc = PROPS[name]
            p = {"description": desc + ", " + STYLE, "image_size": {"width": w, "height": h},
                 "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
                 "view": "side", "no_background": True, "text_guidance_scale": 8, "seed": 7}
            r = pl2.post("/create-image-pixflux", p)
        else:
            desc = NPCS[name]
            p = {"description": desc + ", " + NPC_STYLE, "image_size": {"width": 64, "height": 64},
                 "outline": "single color black outline", "view": "side", "direction": "east",
                 "no_background": True, "detail": "highly detailed", "seed": 11}
            r = pl2.post("/create-image-pixen", p)
        pl2.to_img(r["image"]).save(RAW / f"{name}.png")
        log[name] = {"prompt": p["description"], "seed": p["seed"], "usage": r.get("usage")}
        print(name, r.get("usage"), flush=True)
    after = pl2.balance()
    print("Generierungen verbraucht:", round(before - after, 2))
    log_path.write_text(json.dumps(log, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
