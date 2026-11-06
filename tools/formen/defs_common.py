"""Bausteine für die Stil-Definitionen der Baukasten-Kampfstile (tools/formen).

Ein Stil = 6 Züge (Spezial-Taste + Richtung) mit je 3 Alternativen und ein
Meisterzug mit 3 Varianten. Jeder Zug hat eine Art ("kind"), die der
Baukasten-Code (scripts/formen/form_caster.gd) ausführt; params überschreiben
die Standardwerte der Art (siehe docs/formen-baukasten.md).
"""


def A(id, name, desc, p=None, f=None):
    a = {"id": id, "name": name, "sp": 2, "desc": desc, "params": p or {}}
    if f:
        a["frames"] = f
    return a


def Z(id, name, kind, desc, p, e, alts, fx, dir=None, frames=None, cd=None):
    return {"id": id, "name": name, "kind": kind, "desc": desc, "params": p, "enhanced": e,
            "alts": alts, "fx": fx, "dir": dir, "frames": frames, "cd": cd}


def V(id, name, kind, desc, p, fx):
    return {"id": id, "name": name, "kind": kind, "desc": desc, "params": p, "fx": fx}


def S(**kw):
    return kw
