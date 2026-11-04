#!/usr/bin/env python3
"""Erzeugt "Probe", eine eigene kleine Testfigur im M.U.G.E.N-Format.

Damit testen wir den M.U.G.E.N-Importer (addons/mugen_importer), ohne fremde
Figuren zu benutzen. Alles hier ist selbst gezeichnet (Formen per Code) und
gehört zum Projekt.

Ausgabe in tools/mugen_testfigur/probe/:
  probe.def      Figur mit SFF v2 (Sprites gemischt als RLE8, LZ5, RLE5, PNG)
  probe_v1.def   dieselbe Figur mit SFF v1 (PCX) und .act-Palette
  probe.sff, probe_v1.sff, probe.act, probe.air, probe.cns, probe.cmd

Aufruf: python3 tools/mugen_testfigur/make_testfigur.py
"""
import io
import math
import os
import struct

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe")
W, H = 128, 112
AXIS = (56, 106)  # Fusspunkt im Bild

PALETTE = [
    (0, 0, 0),        # 0 durchsichtig
    (26, 18, 34),     # 1 Umriss
    (64, 170, 160),   # 2 Körper
    (38, 110, 112),   # 3 Körper Schatten
    (255, 214, 72),   # 4 Visier
    (250, 250, 240),  # 5 Glanz
    (120, 124, 140),  # 6 Glieder
    (236, 110, 48),   # 7 Schal
    (255, 246, 160),  # 8 Funken
    (150, 230, 255),  # 9 Funken kalt
]
PAL256 = PALETTE + [(0, 0, 0)] * (256 - len(PALETTE))


# ---------------------------------------------------------------- Zeichnen

def pose(**kw):
    p = dict(bx=0, by=0, fa=(0, 18), ba=(150, 14), fl=(8, 0), bl=(-8, 0), glow=0, scarf=0)
    p.update(kw)
    return p


def draw_figure(p):
    img = Image.new("P", (W, H), 0)
    img.putpalette([c for rgb in PAL256 for c in rgb])
    img.info["transparency"] = 0
    d = ImageDraw.Draw(img)
    ax, ay = AXIS

    def pt(x, y):
        return (ax + x, ay + y)

    bx, by = p["bx"], p["by"]
    hip = (bx, -36 + by)
    sh = (bx + 2, -54 + by)
    head = (bx + 3, -72 + by)

    def limb(a, b, w, col):
        d.line([pt(*a), pt(*b)], fill=1, width=w + 2)
        d.line([pt(*a), pt(*b)], fill=col, width=w)

    def arm(spec, col):
        ang, ln = spec
        r = math.radians(ang)
        end = (sh[0] + math.cos(r) * ln, sh[1] + math.sin(r) * ln)
        limb(sh, end, 5, col)
        d.ellipse([pt(end[0] - 4, end[1] - 4), pt(end[0] + 4, end[1] + 4)], fill=1)
        d.ellipse([pt(end[0] - 3, end[1] - 3), pt(end[0] + 3, end[1] + 3)], fill=5)
        return end

    # hinteres Bein und Arm
    limb(hip, p["bl"], 6, 3)
    arm(p["ba"], 3)
    # Körper (Kapsel)
    d.rounded_rectangle([pt(hip[0] - 11, sh[1] - 4), pt(hip[0] + 13, hip[1] + 4)], 7, fill=1)
    d.rounded_rectangle([pt(hip[0] - 10, sh[1] - 3), pt(hip[0] + 12, hip[1] + 3)], 6, fill=2)
    d.rectangle([pt(hip[0] - 8, hip[1] - 6), pt(hip[0] + 10, hip[1] + 1)], fill=3)
    # vorderes Bein
    limb(hip, p["fl"], 6, 6)
    # Schal flattert nach hinten
    sx = sh[0] - 8 - p["scarf"]
    d.polygon([pt(sh[0] - 4, sh[1] - 2), pt(sx - 10, sh[1] + 2), pt(sx - 6, sh[1] + 7), pt(sh[0] + 2, sh[1] + 3)], fill=7, outline=1)
    # Kopf mit Visier und Antenne
    hx, hy = head
    d.line([pt(hx - 2, hy - 15), pt(hx - 6, hy - 24)], fill=1, width=2)
    d.ellipse([pt(hx - 9, hy - 27), pt(hx - 3, hy - 21)], fill=7, outline=1)
    d.ellipse([pt(hx - 15, hy - 15), pt(hx + 15, hy + 14)], fill=1)
    d.ellipse([pt(hx - 14, hy - 14), pt(hx + 14, hy + 13)], fill=2)
    d.rounded_rectangle([pt(hx - 2, hy - 5), pt(hx + 14, hy + 4)], 3, fill=1)
    d.rounded_rectangle([pt(hx - 1, hy - 4), pt(hx + 13, hy + 3)], 2, fill=4)
    d.rectangle([pt(hx + 2, hy - 3), pt(hx + 5, hy - 2)], fill=5)
    # vorderer Arm
    fist = arm(p["fa"], 6)
    if p["glow"]:
        g = p["glow"]
        for i in range(8):
            r = math.radians(i * 45)
            a = (fist[0] + math.cos(r) * 4, fist[1] + math.sin(r) * 4)
            b = (fist[0] + math.cos(r) * (6 + g), fist[1] + math.sin(r) * (6 + g))
            d.line([pt(*a), pt(*b)], fill=8 if i % 2 == 0 else 9, width=2)
    return img


ANIMS = {
    # Aktion: (Gruppe, Liste von (Pose, Bildzeit))
    0: [(pose(by=0), 8), (pose(by=1, fa=(5, 18)), 8), (pose(by=2, fa=(10, 17)), 8), (pose(by=1, fa=(5, 18)), 8)],
    20: [(pose(fl=(14, 0), bl=(-12, 0), fa=(-10, 18), ba=(170, 14)), 6),
         (pose(by=1, fl=(4, -4), bl=(-4, 0)), 6),
         (pose(fl=(-12, 0), bl=(14, 0), fa=(20, 18), ba=(140, 14)), 6),
         (pose(by=1, fl=(-4, 0), bl=(4, -4)), 6)],
    41: [(pose(by=-4, fl=(10, -10), bl=(-6, -6), fa=(-60, 18), ba=(-120, 14), scarf=4), 4)],
    44: [(pose(by=-2, fl=(6, -2), bl=(-10, -4), fa=(-20, 18), ba=(200, 14), scarf=6), 4)],
    # Leichter Schlag
    200: [(pose(fa=(160, 12)), 3), (pose(bx=2, fa=(0, 14)), 3), (pose(bx=4, fa=(0, 30), ba=(170, 14), fl=(12, 0)), 4),
          (pose(bx=2, fa=(10, 18)), 8)],
    # Schwerer Schlag
    210: [(pose(by=3, fa=(170, 12), ba=(30, 14)), 5), (pose(by=4, bx=-2, fa=(190, 12)), 6),
          (pose(bx=8, fa=(-5, 34), ba=(160, 16), fl=(18, 0), bl=(-14, 0), scarf=6), 6),
          (pose(bx=8, fa=(-5, 34), fl=(18, 0), bl=(-14, 0), scarf=4), 4), (pose(bx=4, fa=(20, 18)), 12)],
    # Vorwärts schwer: hoher Tritt
    220: [(pose(by=2, fl=(4, -6)), 6), (pose(bx=-2, fl=(34, -40), fa=(200, 14), ba=(220, 12), scarf=5), 6),
          (pose(bx=-2, fl=(32, -34), fa=(200, 14)), 4), (pose(fl=(10, -4)), 14)],
    # Geduckter Feger
    230: [(pose(by=12, fl=(10, 0), bl=(-10, 0), fa=(40, 14)), 4), (pose(by=14, fl=(36, -2), bl=(-12, 0), fa=(60, 14), ba=(200, 12)), 5),
          (pose(by=12, fl=(16, 0), fa=(40, 14)), 10)],
    # Luft: Abwärtstritt
    600: [(pose(by=-4, fl=(4, -12), bl=(-8, -8), fa=(-40, 16)), 4), (pose(by=-4, fl=(22, 4), bl=(-8, -10), fa=(-90, 14), scarf=6), 6),
          (pose(by=-4, fl=(8, -6), bl=(-8, -8)), 10)],
    # Spezial "Funkenstoss": Aufwärtshaken mit Funken
    1000: [(pose(by=8, fa=(120, 12), ba=(200, 12)), 6), (pose(by=4, fa=(-30, 22), glow=2), 3),
           (pose(by=-8, fa=(-80, 30), ba=(160, 14), fl=(6, 4), bl=(-6, 0), glow=7, scarf=8), 6),
           (pose(by=-6, fa=(-80, 30), glow=4, scarf=6), 4), (pose(by=0, fa=(-20, 18)), 14)],
}

# Angriffsboxen (Clsn1) pro Aktion und Bild-Index: x1, y1, x2, y2 relativ zum Fusspunkt
CLSN1 = {
    200: {2: [(14, -64, 40, -48)]},
    210: {2: [(18, -66, 50, -46)], 3: [(18, -66, 48, -48)]},
    220: {1: [(14, -86, 42, -58)], 2: [(12, -80, 38, -56)]},
    230: {1: [(14, -14, 46, 0)]},
    600: {1: [(6, -40, 30, -12)]},
    1000: {2: [(-4, -110, 30, -60), (0, -70, 24, -40)], 3: [(-2, -104, 28, -62)]},
}
CLSN2_STAND = [(-14, -94, 16, 0)]
CLSN2_CROUCH = [(-16, -70, 18, 0)]


# ---------------------------------------------------------------- Kodierer

def rle8(px):
    out = bytearray()
    i = 0
    while i < len(px):
        c = px[i]
        n = 1
        while i + n < len(px) and px[i + n] == c and n < 63:
            n += 1
        if n > 1 or (c & 0xC0) == 0x40:
            out += bytes([0x40 | n, c])
        else:
            out.append(c)
        i += n
    return bytes(out)


def rle5(px):
    out = bytearray()
    i = 0
    while i < len(px):
        c = px[i]
        n = 1
        while i + n < len(px) and px[i + n] == c and n < 256:
            n += 1
        out += bytes([n - 1, 0x80, c])  # Lauf, keine Zusatzdaten, Farbe folgt
        i += n
    return bytes(out)


def lz5(px):
    """LZ5 nach der SFF-v2-Beschreibung (RLE- und LZ-Pakete, 8 pro Steuerbyte)."""
    packets = []  # [is_lz, bytearray]
    short_pending = []  # Indizes der kurzen LZ-Pakete 1-3 einer Vierergruppe
    chains = {}
    i = 0
    n = len(px)

    def add_hash(pos):
        if pos + 2 < n:
            chains.setdefault(bytes(px[pos:pos + 3]), []).append(pos)

    while i < n:
        # Lauf gleicher Farbe
        run = 1
        while i + run < n and px[i + run] == px[i] and run < 263:
            run += 1
        # bester Treffer davor
        best_len, best_off = 0, 0
        key = bytes(px[i:i + 3])
        for cand in reversed(chains.get(key, [])[-24:]):
            off = i - cand
            if off > 1024:
                break
            ln = 0
            while i + ln < n and ln < 258 and px[cand + ln] == px[i + ln]:
                ln += 1
            if ln > best_len:
                best_len, best_off = ln, off
        if best_len >= 3 and best_len > run:
            if best_off <= 256 and best_len <= 64:
                # kurzes LZ-Paket; Versatz der ersten drei steht im Folgebyte,
                # der vierte nutzt das aus deren obersten Bits gesammelte Byte
                if len(short_pending) < 3:
                    packets.append([True, bytearray([best_len - 1, best_off - 1])])
                    short_pending.append(len(packets) - 1)
                else:
                    o = best_off - 1
                    for k, idx in enumerate(short_pending):
                        bits = (o >> (6 - 2 * k)) & 3
                        packets[idx][1][0] |= bits << 6
                    packets.append([True, bytearray([(best_len - 1) | ((o & 3) << 6)])])
                    short_pending = []
            else:
                o = best_off - 1
                packets.append([True, bytearray([(o >> 8) << 6, o & 0xFF, best_len - 3])])
            for k in range(best_len):
                add_hash(i + k)
            i += best_len
            continue
        c = px[i]
        if run < 8:
            packets.append([False, bytearray([(run << 5) | c])])
        else:
            packets.append([False, bytearray([c, run - 8])])
        for k in range(run):
            add_hash(i + k)
        i += run
    out = bytearray()
    for g in range(0, len(packets), 8):
        group = packets[g:g + 8]
        ctrl = 0
        for k, (is_lz, _) in enumerate(group):
            if is_lz:
                ctrl |= 1 << k
        out.append(ctrl)
        for _, data in group:
            out += data
    return bytes(out)


def lz5_decode(rle, size):
    """Prüft den Kodierer (gleiche Logik wie der Leser in Godot)."""
    p = bytearray(size)
    i = j = 0
    ct, cts, rb, rbc = rle[0], 0, 0, 0
    i = 1
    while j < size:
        d = rle[i]; i += 1
        if ct & (1 << cts):
            if d & 0x3F == 0:
                d = ((d << 2) | rle[i]) + 1; i += 1
                ln = rle[i] + 2; i += 1
            else:
                rb |= (d & 0xC0) >> rbc
                rbc += 2
                ln = d & 0x3F
                if rbc < 8:
                    d = rle[i] + 1; i += 1
                else:
                    d = rb + 1
                    rb = rbc = 0
            while True:
                if j < size:
                    p[j] = p[j - d]; j += 1
                ln -= 1
                if ln < 0:
                    break
        else:
            if d & 0xE0 == 0:
                ln = rle[i] + 8; i += 1
            else:
                ln = d >> 5
                d &= 0x1F
            for _ in range(ln):
                if j < size:
                    p[j] = d; j += 1
        cts += 1
        if cts >= 8 and i < len(rle):
            ct, cts = rle[i], 0
            i += 1
    return bytes(p)


def pcx(img, with_palette):
    w, h = img.size
    px = img.tobytes()
    hdr = bytearray(128)
    struct.pack_into("<BBBBHHHHHH", hdr, 0, 10, 5, 1, 8, 0, 0, w - 1, h - 1, 72, 72)
    hdr[65] = 1
    struct.pack_into("<HH", hdr, 66, w, 1)
    data = bytearray()
    for y in range(h):
        row = px[y * w:(y + 1) * w]
        x = 0
        while x < w:
            c = row[x]
            n = 1
            while x + n < w and row[x + n] == c and n < 63:
                n += 1
            if n > 1 or c >= 0xC0:
                data += bytes([0xC0 | n, c])
            else:
                data.append(c)
            x += n
    out = bytes(hdr) + bytes(data)
    if with_palette:
        out += b"\x0c" + bytes(c for rgb in PAL256 for c in rgb)
    return out


# ---------------------------------------------------------------- Dateien

def build_sprites():
    """Liste von (Gruppe, Nummer, Bild, Achse) plus Verweise (gleiches Bild)."""
    sprites = []
    seen = {}
    for action, frames in ANIMS.items():
        for k, (p, _) in enumerate(frames):
            img = draw_figure(p)
            key = img.tobytes()
            link = seen.get(key)
            sprites.append({"group": action, "no": k, "img": img, "link": link})
            if link is None:
                seen[key] = len(sprites) - 1
    return sprites


def write_sff_v2(path, sprites):
    formats = [2, 4, 3, 10]  # RLE8, LZ5, RLE5, PNG8 abwechselnd
    ldata = bytearray()
    nodes = bytearray()
    pal = bytes(c for rgb in PALETTE for c in (*rgb, 0)) + bytes(4 * (32 - len(PALETTE)))
    pal_off = len(ldata)
    ldata += pal
    for idx, s in enumerate(sprites):
        img = s["img"]
        w, h = img.size
        if s["link"] is not None:
            nodes += struct.pack("<HHHHhhHBBIIHH", s["group"], s["no"], w, h, AXIS[0], AXIS[1], s["link"], 0, 8, 0, 0, 0, 0)
            continue
        fmt = formats[idx % len(formats)]
        px = img.tobytes()
        if fmt == 2:
            data = rle8(px)
        elif fmt == 3:
            data = rle5(px)
        elif fmt == 4:
            data = lz5(px)
            assert lz5_decode(data, len(px)) == px, "LZ5-Kodierer fehlerhaft"
        else:
            buf = io.BytesIO()
            img.save(buf, "PNG")
            data = buf.getvalue()
        blob = struct.pack("<I", len(px)) + data
        off = len(ldata)
        ldata += blob
        nodes += struct.pack("<HHHHhhHBBIIHH", s["group"], s["no"], w, h, AXIS[0], AXIS[1], 0, fmt, 8, off, len(blob), 0, 0)
    pal_node = struct.pack("<HHHHII", 1, 1, 32, 0, pal_off, len(pal))
    header = bytearray(512)
    header[0:12] = b"ElecbyteSpr\x00"
    header[12:16] = bytes([0, 1, 0, 2])
    spr_off = 512
    pal_off_file = spr_off + len(nodes)
    ldata_off = pal_off_file + len(pal_node)
    struct.pack_into("<IIIIIIII", header, 36, spr_off, len(sprites), pal_off_file, 1, ldata_off, len(ldata), ldata_off + len(ldata), 0)
    with open(path, "wb") as f:
        f.write(header + nodes + pal_node + ldata)


def write_sff_v1(path, sprites):
    header = bytearray(512)
    header[0:12] = b"ElecbyteSpr\x00"
    header[12:16] = bytes([0, 1, 0, 1])
    groups = len({s["group"] for s in sprites})
    struct.pack_into("<IIIIB", header, 16, groups, len(sprites), 512, 32, 1)
    body = bytearray()
    pos = 512
    for idx, s in enumerate(sprites):
        if s["link"] is not None:
            data = b""
        else:
            data = pcx(s["img"], with_palette=(idx == 0))
        nxt = pos + 32 + len(data) if idx < len(sprites) - 1 else 0
        sub = struct.pack("<IIhhHHHB", nxt, len(data), AXIS[0], AXIS[1], s["group"], s["no"], s["link"] or 0, 0 if idx == 0 else 1)
        sub += bytes(32 - len(sub))
        body += sub + data
        pos += 32 + len(data)
    with open(path, "wb") as f:
        f.write(header + body)


def write_act(path):
    # M.U.G.E.N speichert .act-Paletten rückwärts (Eintrag 0 = Farbe 255)
    with open(path, "wb") as f:
        f.write(bytes(c for rgb in reversed(PAL256) for c in rgb))


def clsn_lines(tag, boxes):
    out = [f"{tag}: {len(boxes)}"]
    for k, (x1, y1, x2, y2) in enumerate(boxes):
        out.append(f" {tag.replace('Default', '')}[{k}] = {x1}, {y1}, {x2}, {y2}")
    return out


def write_air(path):
    lines = ["; Probe - eigene Testfigur fuer den M.U.G.E.N-Importer", ""]
    names = {0: "Stehen", 20: "Gehen", 41: "Sprung", 44: "Fallen", 200: "Leichter Schlag", 210: "Schwerer Schlag",
             220: "Hoher Tritt", 230: "Feger", 600: "Lufttritt", 1000: "Funkenstoss"}
    for action, frames in ANIMS.items():
        lines.append(f"; {names[action]}")
        lines.append(f"[Begin Action {action}]")
        lines += clsn_lines("Clsn2Default", CLSN2_CROUCH if action == 230 else CLSN2_STAND)
        if action == 0:
            lines.append("Loopstart")
        for k, (_, t) in enumerate(frames):
            boxes = CLSN1.get(action, {}).get(k)
            if boxes:
                lines += clsn_lines("Clsn1", boxes)
            flip = ""
            lines.append(f"{action},{k}, 0,0, {t}{flip}")
        lines.append("")
    with open(path, "w", newline="\r\n") as f:
        f.write("\n".join(lines))


CNS = """; Probe - Zustaende (eigene Testfigur)
[Data]
life = 1000
attack = 100
defence = 100

[Size]
xscale = 1
yscale = 1

[Velocity]
walk.fwd = 2.4
run.fwd = 4.6, 0
jump.neu = 0, -8.4

[Movement]
yaccel = .44

; Leichter Schlag
[Statedef 200]
type = S
movetype = A
physics = S
anim = 200
ctrl = 0
velset = 0, 0

[State 200, Treffer]
type = HitDef
trigger1 = AnimElem = 3
attr = S, NA
damage = 24, 0
animtype = Light
guardflag = MA
hitflag = MAF
pausetime = 8, 8
sparkxy = -10, -60
ground.type = High
ground.slidetime = 6
ground.hittime = 10
ground.velocity = -4
air.velocity = -3, -4

[State 200, Kette]
type = ChangeState
trigger1 = command = "x" && movecontact
trigger1 = AnimElem = 3, >= 0
value = 210

[State 200, Ende]
type = ChangeState
trigger1 = AnimTime = 0
value = 0
ctrl = 1

; Schwerer Schlag
[Statedef 210]
type = S
movetype = A
physics = S
anim = 210
ctrl = 0
velset = 0, 0

[State 210, Treffer]
type = HitDef
trigger1 = AnimElem = 3
attr = S, NA
damage = 60, 4
animtype = Hard
pausetime = 12, 12
ground.velocity = -8
air.velocity = -6, -5

[State 210, Ende]
type = ChangeState
trigger1 = AnimTime = 0
value = 0
ctrl = 1

; Hoher Tritt (vorwaerts + y)
[Statedef 220]
type = S
movetype = A
physics = S
anim = 220
ctrl = 0

[State 220, Treffer]
type = HitDef
trigger1 = AnimElem = 2
attr = S, NA
damage = 55
ground.velocity = -6, -3
air.velocity = -5, -5

[State 220, Ende]
type = ChangeState
trigger1 = AnimTime = 0
value = 0
ctrl = 1

; Feger (geduckt + a)
[Statedef 230]
type = C
movetype = A
physics = C
anim = 230
ctrl = 0

[State 230, Treffer]
type = HitDef
trigger1 = AnimElem = 2
attr = C, NA
damage = 40
ground.type = Trip
ground.velocity = -3, -5

[State 230, Ende]
type = ChangeState
trigger1 = AnimTime = 0
value = 11
ctrl = 1

; Lufttritt
[Statedef 600]
type = A
movetype = A
physics = A
anim = 600
ctrl = 0

[State 600, Treffer]
type = HitDef
trigger1 = AnimElem = 2
attr = A, NA
damage = 45
ground.velocity = -3, 6
air.velocity = -3, 6

; Funkenstoss (Spezial)
[Statedef 1000]
type = S
movetype = A
physics = N
anim = 1000
ctrl = 0
poweradd = 40

[State 1000, Treffer]
type = HitDef
trigger1 = AnimElem = 3
attr = S, SA
damage = 90, 10
animtype = Up
ground.velocity = -3, -9
air.velocity = -3, -9

[State 1000, Ende]
type = ChangeState
trigger1 = AnimTime = 0
value = 0
ctrl = 1
"""

CMD = """; Probe - Befehle (eigene Testfigur)
[Remap]
x = x
y = y
z = z
a = a
b = b
c = c
s = s

[Defaults]
command.time = 15
command.buffer.time = 1

[Command]
name = "Funkenstoss"
command = ~D, DF, F, x
time = 15

[Command]
name = "x"
command = x
time = 1

[Command]
name = "y"
command = y
time = 1

[Command]
name = "a"
command = a
time = 1

[Command]
name = "holdfwd"
command = /$F
time = 1

[Command]
name = "holddown"
command = /$D
time = 1

[Statedef -1]

[State -1, Funkenstoss]
type = ChangeState
value = 1000
triggerall = command = "Funkenstoss"
trigger1 = statetype != A
trigger1 = ctrl

[State -1, Hoher Tritt]
type = ChangeState
value = 220
triggerall = command = "y"
triggerall = command = "holdfwd"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, Leichter Schlag]
type = ChangeState
value = 200
triggerall = command = "x"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, Schwerer Schlag]
type = ChangeState
value = 210
triggerall = command = "y"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, Feger]
type = ChangeState
value = 230
triggerall = command = "a"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl

[State -1, Lufttritt]
type = ChangeState
value = 600
triggerall = command = "x"
trigger1 = statetype = A
trigger1 = ctrl
"""


def write_def(path, sff, extra=""):
    text = f"""; Probe - eigene Testfigur fuer den M.U.G.E.N-Importer von Chibi Legends
[Info]
name = "Probe"
displayname = "Probe"
versiondate = 11,04,2026
mugenversion = 1.1
author = "Chibi Legends Team"

[Files]
cmd = probe.cmd
cns = probe.cns
st = probe.cns
sprite = {sff}
anim = probe.air
{extra}"""
    with open(path, "w", newline="\r\n") as f:
        f.write(text)


def main():
    os.makedirs(OUT, exist_ok=True)
    sprites = build_sprites()
    write_sff_v2(os.path.join(OUT, "probe.sff"), sprites)
    write_sff_v1(os.path.join(OUT, "probe_v1.sff"), sprites)
    write_act(os.path.join(OUT, "probe.act"))
    write_air(os.path.join(OUT, "probe.air"))
    with open(os.path.join(OUT, "probe.cns"), "w", newline="\r\n") as f:
        f.write(CNS)
    with open(os.path.join(OUT, "probe.cmd"), "w", newline="\r\n") as f:
        f.write(CMD)
    write_def(os.path.join(OUT, "probe.def"), "probe.sff")
    write_def(os.path.join(OUT, "probe_v1.def"), "probe_v1.sff", "pal1 = probe.act\n")
    # Vorschau aller Bilder (zum Ansehen)
    sheet = Image.new("RGBA", (W * 6, H * ((len(sprites) + 5) // 6)), (40, 40, 50, 255))
    for k, s in enumerate(sprites):
        sheet.alpha_composite(s["img"].convert("RGBA"), ((k % 6) * W, (k // 6) * H))
    sheet.save(os.path.join(OUT, "_vorschau.png"))
    print(f"{len(sprites)} Bilder, {sum(1 for s in sprites if s['link'] is not None)} Verweise -> {OUT}")


if __name__ == "__main__":
    main()
