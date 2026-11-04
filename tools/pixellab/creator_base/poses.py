"""Frame-Liste des Grundkörpers mit Skelett-Posen (60 Zeichnungen).

Jede Pose ist eine Handvoll Winkel. Daraus rechnet die Vorwärtskinematik die
18 Gelenke (OpenPose COCO-18) im 64x64-Raster, so wie PixelLab Skeleton v3 sie
erwartet. Winkel in Grad: 0 = Glied zeigt nach unten, positiv = nach vorne
(Blickrichtung, +x), 180 = nach oben.

LEFT = vordere Seite (zur Blickrichtung), RIGHT = hintere Seite, passend zur
Skelett-Schätzung des Grundkörpers.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

CELL = 64
GROUND = 54.3  # y des Knöchels, wenn der Fuß auf dem Boden steht

# Gliedlängen in Pixeln, gemessen an der Skelett-Schätzung von base.png
TORSO = 14.8
UPPER_ARM = 8.5
FOREARM = 8.7
THIGH = 11.0
SHIN = 8.4

# Feste Versätze relativ zum Hals (Kopf dreht sich um den Hals)
HEAD = {
    "NOSE": (5.7, -6.7),
    "LEFT EYE": (7.2, -8.8),
    "RIGHT EYE": (2.2, -8.6),
    "LEFT EAR": (4.4, -10.9),
    "RIGHT EAR": (-3.8, -10.2),
}
SHOULDER = {"LEFT": (6.8, 0.4), "RIGHT": (-6.8, -0.4)}
HIP = {"LEFT": (2.0, 0.0), "RIGHT": (-2.6, 0.0)}

# Grundstellung (aus der Schätzung zurückgerechnet)
BASE = dict(t=-4, h=0, la=45, lf=136, ra=-54, rf=1, lt=43, ls=3, rt=-31, rs=-29, x=0.0, y=None)


def _dir(a: float) -> tuple[float, float]:
    r = math.radians(a)
    return math.sin(r), math.cos(r)


def _rot(v, deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return v[0] * c - v[1] * s, v[0] * s + v[1] * c


def _ik(sh, target, bend):
    """Zwei-Glieder-IK: Ellbogen und Handgelenk für ein Ziel."""
    dx, dy = target[0] - sh[0], target[1] - sh[1]
    dist = max(1e-3, min(math.hypot(dx, dy), UPPER_ARM + FOREARM - 0.2))
    a = math.atan2(dy, dx)
    cos_e = (UPPER_ARM ** 2 + dist ** 2 - FOREARM ** 2) / (2 * UPPER_ARM * dist)
    e = math.acos(max(-1.0, min(1.0, cos_e)))
    ang = a + bend * e
    el = (sh[0] + UPPER_ARM * math.cos(ang), sh[1] + UPPER_ARM * math.sin(ang))
    wr = (sh[0] + dist * math.cos(a), sh[1] + dist * math.sin(a))
    return el, wr


def solve(p: dict) -> dict:
    """Pose-Winkel -> Gelenkpunkte in Pixeln (plus Anker)."""
    q = dict(BASE)
    q.update(p)
    hip_c = (31.1 + q["x"], 0.0)
    tx, ty = _dir(180 - q["t"])  # Rumpf zeigt nach oben, t > 0 = nach vorne lehnen
    pts = {}

    def build(hy):
        hc = (hip_c[0], hy)
        neck = (hc[0] + TORSO * tx, hc[1] + TORSO * ty)
        out = {"NECK": neck}
        for k, off in HEAD.items():
            o = _rot(off, q["t"] * 0.6 + q["h"])
            out[k] = (neck[0] + o[0], neck[1] + o[1])
        for side, a_up, a_lo, t_up, t_lo in (("LEFT", "la", "lf", "lt", "ls"), ("RIGHT", "ra", "rf", "rt", "rs")):
            so = _rot(SHOULDER[side], q["t"])
            sh = (neck[0] + so[0], neck[1] + so[1])
            if "grip" in q:
                gd = _dir(q["sw"])
                back = 0.0 if side == "LEFT" else 2.0  # hintere Hand sitzt tiefer am Griff
                target = (neck[0] + q["grip"][0] - gd[0] * back, neck[1] + q["grip"][1] - gd[1] * back)
                el, wr = _ik(sh, target, q.get("bend", 1))
            else:
                d = _dir(q[a_up]); el = (sh[0] + UPPER_ARM * d[0], sh[1] + UPPER_ARM * d[1])
                d = _dir(q[a_lo]); wr = (el[0] + FOREARM * d[0], el[1] + FOREARM * d[1])
            hp = (hc[0] + HIP[side][0], hc[1] + HIP[side][1])
            d = _dir(q[t_up]); kn = (hp[0] + THIGH * d[0], hp[1] + THIGH * d[1])
            d = _dir(q[t_lo]); an = (kn[0] + SHIN * d[0], kn[1] + SHIN * d[1])
            out.update({f"{side} SHOULDER": sh, f"{side} ELBOW": el, f"{side} ARM": wr,
                        f"{side} HIP": hp, f"{side} KNEE": kn, f"{side} LEG": an})
        return out

    # Höhe: entweder fest (y = Hüfthöhe) oder so, dass der tiefste Fuß am Boden steht
    if q["y"] is None:
        probe = build(0.0)
        low = max(probe["LEFT LEG"][1], probe["RIGHT LEG"][1])
        hy = GROUND - low
    else:
        hy = q["y"]
    pts = build(hy)
    return pts


def anchors(p: dict, pts: dict) -> dict:
    q = dict(BASE); q.update(p)
    if "grip" in q:
        q["lf"] = q["rf"] = q["sw"]
    return {
        "head": {"pos": pts["NECK"], "angle": q["t"] * 0.6 + q["h"]},
        "hand_front": {"pos": pts["LEFT ARM"], "angle": q["lf"]},
        "hand_back": {"pos": pts["RIGHT ARM"], "angle": q["rf"]},
        "back": {"pos": ((pts["LEFT SHOULDER"][0] + pts["RIGHT SHOULDER"][0]) / 2,
                         (pts["LEFT SHOULDER"][1] + pts["RIGHT SHOULDER"][1]) / 2), "angle": q["t"]},
    }


# z_index: vordere Glieder vorne, hintere hinten
Z = {"LEFT": 2, "RIGHT": -2}


def keypoints(pts: dict) -> list[dict]:
    out = []
    for label, (x, y) in pts.items():
        side = label.split(" ")[0]
        z = Z.get(side, 0)
        if label in ("NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR", "NECK"):
            z = 1
        out.append({"label": label, "x": round(min(max(x / CELL, 0.0), 1.0), 4),
                    "y": round(min(max(y / CELL, 0.0), 1.0), 4), "z_index": z})
    return out


# ---------------------------------------------------------------------------
# Die 60 Zeichnungen, in 8 Gruppen (eine PixelLab-Anfrage pro Gruppe)
# ---------------------------------------------------------------------------
S = BASE  # Abkürzung

GROUPS: list[dict] = [
    {"group": "idle", "action": "fighting stance idle breathing", "frames": [
        ("idle_0", {}),
        ("idle_1", {"y_drop": 0.6, "la": 47, "lf": 134, "ra": -52}),
        ("idle_2", {"y_drop": 1.0, "la": 49, "lf": 132, "ra": -50, "t": -2}),
        ("idle_3", {"y_drop": 0.6, "la": 47, "lf": 134, "ra": -52}),
    ]},
    {"group": "walk", "action": "walk forward", "frames": [
        ("walk_0", dict(t=2, la=20, lf=60, ra=-25, rf=-5, lt=25, ls=5, rt=-20, rs=-30)),
        ("walk_1", dict(t=2, la=10, lf=50, ra=-15, rf=0, lt=10, ls=0, rt=-5, rs=-40, y_up=0.8)),
        ("walk_2", dict(t=2, la=-5, lf=30, ra=5, rf=30, lt=-10, ls=-15, rt=15, rs=-20)),
        ("walk_3", dict(t=2, la=-20, lf=20, ra=20, rf=60, lt=-20, ls=-30, rt=25, rs=5)),
        ("walk_4", dict(t=2, la=-10, lf=25, ra=10, rf=50, lt=-5, ls=-40, rt=10, rs=0, y_up=0.8)),
        ("walk_5", dict(t=2, la=5, lf=40, ra=-5, rf=30, lt=15, ls=-20, rt=-10, rs=-15)),
    ]},
    {"group": "run", "action": "sprint run", "frames": [
        ("run_0", dict(t=14, la=-40, lf=60, ra=50, rf=110, lt=45, ls=10, rt=-35, rs=-80)),
        ("run_1", dict(t=14, la=-10, lf=80, ra=20, rf=90, lt=10, ls=-40, rt=5, rs=-20, y_up=1.5)),
        ("run_2", dict(t=14, la=50, lf=110, ra=-40, rf=60, lt=-35, ls=-80, rt=45, rs=10)),
        ("run_3", dict(t=14, la=20, lf=90, ra=-10, rf=80, lt=5, ls=-20, rt=10, rs=-40, y_up=1.5)),
    ]},
    {"group": "air", "action": "jump fall land dash and double jump", "frames": [
        ("jump_0", dict(t=4, la=150, lf=170, ra=-30, rf=-10, lt=10, ls=-10, rt=-10, rs=-30, y=34)),
        ("jump_1", dict(t=2, la=120, lf=160, ra=-50, rf=-20, lt=60, ls=0, rt=20, rs=-40, y=34)),
        ("fall_0", dict(t=-4, la=100, lf=130, ra=-100, rf=-80, lt=20, ls=-10, rt=-15, rs=-25, y=34)),
        ("fall_1", dict(t=-6, la=120, lf=150, ra=-120, rf=-100, lt=10, ls=-5, rt=-20, rs=-20, y=34)),
        ("land_0", dict(t=18, la=40, lf=60, ra=-40, rf=-20, lt=70, ls=-10, rt=-20, rs=-80)),
        ("dash_0", dict(t=28, la=-70, lf=-60, ra=-80, rf=-70, lt=50, ls=-20, rt=-60, rs=-80)),
        ("dash_1", dict(t=24, la=-60, lf=-40, ra=-70, rf=-50, lt=30, ls=-10, rt=-40, rs=-50)),
        ("djump_0", dict(t=20, la=60, lf=80, ra=-60, rf=-40, lt=90, ls=10, rt=60, rs=-20, y=34)),
        ("djump_1", dict(t=-10, la=160, lf=175, ra=150, rf=170, lt=20, ls=-20, rt=-10, rs=-40, y=34)),
    ]},
    {"group": "defense", "action": "block, get hit, knocked back, lying down and getting up", "frames": [
        ("block_0", dict(t=-6, la=100, lf=170, ra=80, rf=160, lt=35, ls=0, rt=-30, rs=-30)),
        ("hit_0", dict(t=-14, h=-12, la=30, lf=60, ra=-60, rf=-30, lt=30, ls=0, rt=-30, rs=-25)),
        ("hit_1", dict(t=-22, h=-18, la=60, lf=90, ra=-80, rf=-50, lt=40, ls=10, rt=-35, rs=-20)),
        ("knock_0", dict(t=-45, h=-20, la=100, lf=120, ra=-120, rf=-110, lt=60, ls=30, rt=20, rs=-10, y=30)),
        ("knock_1", dict(t=-70, h=-20, la=130, lf=150, ra=-140, rf=-130, lt=80, ls=60, rt=50, rs=20, y=38)),
        ("lie_0", dict(t=-88, h=-5, la=-80, lf=-90, ra=-100, rf=-90, lt=85, ls=88, rt=95, rs=92, x=6, y=50)),
        ("getup_0", dict(t=6, la=30, lf=10, ra=-20, rf=0, lt=90, ls=0, rt=5, rs=-88)),
        ("getup_1", dict(t=6, la=30, lf=80, ra=-40, rf=-10, lt=60, ls=0, rt=-25, rs=-40)),
    ]},
    {"group": "strikes", "action": "martial arts punches, kicks and sword slashes", "frames": [
        ("jab_wind", dict(t=-6, la=20, lf=110, ra=-50, rf=10)),
        ("jab_hit", dict(t=8, la=88, lf=90, ra=-60, rf=-10, lt=45, rt=-35)),
        ("cross_hit", dict(t=14, la=-40, lf=20, ra=80, rf=90, lt=40, ls=0, rt=-45, rs=-40)),
        ("hook_hit", dict(t=10, la=100, lf=150, ra=-50, rf=0, lt=40, rt=-35)),
        ("lowkick_wind", dict(t=-8, la=60, lf=140, ra=-60, rf=0, lt=80, ls=-30, rt=-15, rs=-20)),
        ("lowkick_hit", dict(t=-14, la=60, lf=130, ra=-70, rf=-20, lt=75, ls=75, rt=-15, rs=-15)),
        ("highkick_wind", dict(t=-12, la=70, lf=140, ra=-60, rf=0, lt=110, ls=20, rt=-10, rs=-10)),
        ("highkick_hit", dict(t=-26, la=50, lf=120, ra=-90, rf=-40, lt=125, ls=120, rt=-5, rs=-5)),
        ("slash_wind", dict(t=-10, la=170, lf=200, ra=-40, rf=0, lt=30, rt=-30)),
        ("slash_hit", dict(t=20, la=70, lf=40, ra=-50, rf=-10, lt=55, ls=0, rt=-40, rs=-50)),
        ("slash_side", dict(t=10, la=95, lf=95, ra=-70, rf=-30, lt=50, ls=0, rt=-40, rs=-40)),
        ("upper_wind", dict(t=16, la=0, lf=40, ra=-40, rf=-10, lt=75, ls=-15, rt=-30, rs=-80)),
        ("upper_hit", dict(t=-6, h=8, la=170, lf=175, ra=-40, rf=-20, lt=30, ls=0, rt=-20, rs=-30)),
    ]},
    {"group": "specials", "action": "aerial attacks, throws, magic casting and power-up poses", "frames": [
        ("stomp_hit", dict(t=0, la=90, lf=120, ra=-90, rf=-60, lt=5, ls=5, rt=60, rs=-30, y=34)),
        ("airkick_hit", dict(t=-20, la=70, lf=110, ra=-80, rf=-60, lt=100, ls=100, rt=20, rs=-40, y=34)),
        ("airpunch_hit", dict(t=30, la=40, lf=40, ra=-60, rf=-30, lt=30, ls=-20, rt=-20, rs=-50, y=34)),
        ("airspin_hit", dict(t=0, la=90, lf=90, ra=-90, rf=-90, lt=40, ls=-30, rt=20, rs=-50, y=34)),
        ("grab_0", dict(t=14, la=80, lf=95, ra=70, rf=85, lt=45, ls=0, rt=-35, rs=-35)),
        ("throw_0", dict(t=-24, la=160, lf=190, ra=150, rf=180, lt=40, ls=10, rt=-35, rs=-20)),
        ("cast_wind", dict(t=-12, la=-60, lf=-30, ra=-70, rf=-40, lt=40, ls=0, rt=-30, rs=-30)),
        ("cast_hit", dict(t=12, la=90, lf=92, ra=85, rf=88, lt=45, ls=0, rt=-40, rs=-40)),
        ("charge_0", dict(t=10, h=10, la=20, lf=-20, ra=-20, rf=20, lt=60, ls=-20, rt=-55, rs=-30)),
        ("super_0", dict(t=-8, h=-10, la=120, lf=140, ra=-120, rf=-140, lt=35, ls=0, rt=-35, rs=-10)),
        ("thrust_hit", dict(t=26, la=90, lf=90, ra=-80, rf=-60, lt=70, ls=0, rt=-55, rs=-70)),
        ("dashpunch_hit", dict(t=30, la=88, lf=88, ra=-100, rf=-80, lt=60, ls=-10, rt=-70, rs=-90)),
    ]},
    # Zweihand-Varianten (Mischform, 2026-11-04): beide Hände am Griff, sw = Klingenrichtung
    {"group": "twohand", "action": "both empty fists clasped together in front, heavy two-handed swing motion, no weapon", "frames": [
        ("th_idle_0", dict(t=4, grip=(6, 12), sw=150, lt=40, ls=0, rt=-30, rs=-30)),
        ("th_idle_1", dict(t=6, grip=(6, 13), sw=148, lt=40, ls=0, rt=-30, rs=-30, y_drop=0.8)),
        ("th_wind_up", dict(t=-12, grip=(-2, -10), sw=200, lt=35, ls=0, rt=-30, rs=-25)),
        ("th_overhead_hit", dict(t=26, grip=(9, 12), sw=60, lt=60, ls=0, rt=-45, rs=-60)),
        ("th_side_wind", dict(t=-6, grip=(-7, 6), sw=-110, lt=45, ls=0, rt=-30, rs=-30)),
        ("th_side_hit", dict(t=16, grip=(10, 6), sw=95, lt=55, ls=0, rt=-45, rs=-55)),
        ("th_thrust", dict(t=24, grip=(11, 4), sw=92, lt=65, ls=0, rt=-55, rs=-70)),
        ("th_rise", dict(t=-4, grip=(5, -8), sw=170, lt=30, ls=0, rt=-20, rs=-30)),
    ]},
    {"group": "extra", "action": "victory and taunt poses", "frames": [
        ("win_0", dict(t=-4, h=-6, la=170, lf=178, ra=-40, rf=-10, lt=15, ls=0, rt=-15, rs=0)),
        ("win_1", dict(t=0, h=6, la=40, lf=-20, ra=-40, rf=10, lt=10, ls=0, rt=-12, rs=0)),
        ("taunt_0", dict(t=-6, h=10, la=90, lf=150, ra=-30, rf=30, lt=20, ls=0, rt=-20, rs=0)),
        ("taunt_1", dict(t=-6, h=4, la=90, lf=170, ra=-30, rf=30, lt=20, ls=0, rt=-20, rs=0)),
    ]},
]


def frame_pose(p: dict) -> dict:
    """Kleine Hilfsfelder (y_drop/y_up) in echte Pose-Felder umrechnen."""
    p = dict(p)
    drop = p.pop("y_drop", 0.0) - p.pop("y_up", 0.0)
    if drop:
        q = dict(BASE); q.update(p); q["y"] = None
        pts = solve(q)
        hip_y = (pts["LEFT HIP"][1] + pts["RIGHT HIP"][1]) / 2
        p["y"] = hip_y + drop
    return p


def build_all() -> list[dict]:
    out = []
    for g in GROUPS:
        frames = []
        for name, p in g["frames"]:
            p = frame_pose(p)
            pts = solve(p)
            frames.append({"name": name, "pose": p, "keypoints": keypoints(pts), "anchors": anchors(p, pts)})
        out.append({"group": g["group"], "action": g["action"], "frames": frames})
    return out


if __name__ == "__main__":
    data = build_all()
    n = sum(len(g["frames"]) for g in data)
    Path(__file__).with_name("frames.json").write_text(json.dumps(data, indent=1))
    print(f"{n} Frames in {len(data)} Gruppen")
