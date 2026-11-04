"""Shared sprite format for Chibi Legends paper-doll characters.

Every layer of every item uses the SAME sheet layout, so any hair fits any
outfit in every animation frame:

* cell 64 x 64 px, origin (between the feet) at ORIGIN inside the cell
* one row per animation (ANIMS order), up to COLUMNS frames per row
* side view facing right; the game mirrors it for left

Pixels are stored *palette-indexed* so the game can recolor them:

* red   = tone  * 32 + 16   (tone 0..7, 0 = outline, 4 = base color)
* green = slot  * 64 + 32   (slot 0..2 = item color channels, 3 = fixed colors)
* blue  = 0, alpha = 255 (or 0 = empty)

The Godot shader (assets/shaders/palette_swap.gdshader) turns slot/tone
back into real colors from the player's chosen palettes.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace

CELL = 64
COLUMNS = 8
ORIGIN = (28, 56)

# Layer order, back to front. Must match catalog.json "layers".
LAYERS = [
    "acc_back",
    "hair_back",
    "body",
    "face",
    "pants",
    "shoes",
    "top",
    "hair_front",
    "acc_front",
    "headgear",
    "weapon",
]

# Slot -> which layers an item of that slot may fill.
SLOTS = {
    "body": ["body"],
    "face": ["face"],
    "hair": ["hair_back", "hair_front"],
    "top": ["top"],
    "pants": ["pants"],
    "shoes": ["shoes"],
    "accessory": ["acc_back", "acc_front"],
    "headgear": ["headgear"],
    "weapon": ["weapon"],
}

FIXED = 3  # slot index of the fixed colors
# Fixed colors (slot 3), shared by all items: tone -> color
FIXED_COLORS = [
    "1a1020",  # 0 outline
    "ffffff",  # 1 white / highlight
    "ff9aa2",  # 2 blush
    "7a2a2a",  # 3 mouth
    "f2c14e",  # 4 gold
    "e8eef2",  # 5 steel
    "3a2a46",  # 6 belt / dark cloth
    "3a2a26",  # 7 dark leather
]

# Tone ramp built from one base color (mirrors palette.gd in the game).
# (mode, amount): "d" = darken, "l" = lighten. Tone 0 is the outline.
RAMP = [None, ("d", 0.55), ("d", 0.30), ("d", 0.15), ("b", 0.0), ("l", 0.25), ("l", 0.50), ("l", 0.75)]


@dataclass(frozen=True)
class Pose:
    bob: int = 0                 # upper body up/down
    lean: int = 0                # upper body left/right
    back_leg: tuple = (0, 0)
    front_leg: tuple = (0, 0)
    arm: str = "rest"            # rest, windup, swing, cast
    reach: int = 0               # extra arm/blade reach in swing
    eyes: str = "open"           # open, squint, closed
    mouth: str = "closed"        # closed, open
    wave: int = 0                # scarf / ribbon flutter


@dataclass
class Anim:
    name: str
    fps: float
    loop: bool
    frames: list = field(default_factory=list)


def _run_frames() -> list:
    xs = [-3, -2, 0, 2, 3, 2, 0, -2]
    ys = [0, -1, -1, 0, 0, -1, -1, 0]
    return [Pose(bob=ys[i], back_leg=(xs[i], ys[i]), front_leg=(-xs[i], ys[(i + 4) % 8]), wave=1 + i % 2) for i in range(8)]


def _attack(reach: int, lunge: int) -> list:
    wind = Pose(arm="windup", back_leg=(-2, 0), front_leg=(1, 0), mouth="open", lean=-1)
    swing = Pose(arm="swing", reach=reach, back_leg=(-3, 0), front_leg=(3 + lunge, 0), mouth="open", lean=lunge)
    follow = replace(swing, reach=max(0, reach - 1))
    settle = replace(swing, reach=0, mouth="closed", lean=0)
    return [wind, swing, follow, settle]


ANIMS = [
    Anim("idle", 4, True, [Pose(), Pose(), Pose(bob=-1), Pose(bob=-1)]),
    Anim("run", 12, True, _run_frames()),
    Anim("jump", 8, True, [Pose(front_leg=(2, -3), back_leg=(-1, -1), wave=1), Pose(bob=-1, front_leg=(2, -4), back_leg=(-1, -2), wave=2)]),
    Anim("fall", 8, True, [Pose(front_leg=(1, -1), back_leg=(-2, 0), wave=1), Pose(front_leg=(1, -1), back_leg=(-2, -1), wave=2)]),
    Anim("dash", 12, True, [Pose(front_leg=(3, -2), back_leg=(-4, -1), lean=1, wave=2), Pose(front_leg=(3, -2), back_leg=(-4, -1), lean=1, wave=3)]),
    Anim("attack_1", 16, False, _attack(0, 0)),
    Anim("attack_2", 16, False, _attack(2, 0)),
    Anim("attack_3", 14, False, _attack(4, 1)),
    Anim("cast", 10, True, [Pose(arm="cast", mouth="open"), Pose(arm="cast", mouth="open", bob=-1), Pose(arm="cast", mouth="open", bob=-1), Pose(arm="cast", mouth="open")]),
    Anim("hit", 10, False, [Pose(lean=-1, eyes="squint", mouth="open"), Pose(lean=-2, bob=1, eyes="squint", mouth="open")]),
    Anim("ko", 8, False, [Pose(bob=1, eyes="squint"), Pose(bob=3, lean=-1, eyes="closed", back_leg=(-2, 0), front_leg=(2, 0)), Pose(bob=5, lean=-2, eyes="closed", back_leg=(-3, 0), front_leg=(3, 0))]),
]

assert all(len(a.frames) <= COLUMNS for a in ANIMS)
SHEET_SIZE = (CELL * COLUMNS, CELL * len(ANIMS))


def anim_table() -> dict:
    return {a.name: {"row": i, "frames": len(a.frames), "fps": a.fps, "loop": a.loop} for i, a in enumerate(ANIMS)}


def encode(slot: int, tone: int) -> tuple:
    return (tone * 32 + 16, slot * 64 + 32, 0, 255)


def decode(px: tuple) -> tuple | None:
    """(slot, tone) for an encoded pixel, None for an empty one."""
    if px[3] < 128:
        return None
    return (px[1] // 64, px[0] // 32)


def is_encoded(px: tuple) -> bool:
    if px[3] == 0:
        return True
    return px[3] == 255 and px[2] == 0 and px[0] % 32 == 16 and px[1] % 64 == 32


# --- colors (used by previews and the import quantizer) ---

def hex_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def ramp_colors(base_hex: str) -> list:
    base = hex_rgb(base_hex)
    out = []
    for step in RAMP:
        if step is None:
            out.append(hex_rgb(FIXED_COLORS[0]))
            continue
        mode, amt = step
        if mode == "d":
            out.append(tuple(round(c * (1 - amt)) for c in base))
        elif mode == "l":
            out.append(tuple(round(c + (255 - c) * amt) for c in base))
        else:
            out.append(base)
    return out
