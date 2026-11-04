#!/usr/bin/env python3
"""Generates the original pixel-art textures for the HD-2D test of the
training forest (assets/hd2d/). Everything is drawn procedurally here, no
external art. Run from the repo root:  python3 tools/hd2d/gen_textures.py
Deterministic (fixed seeds), so re-running gives the same files."""

import math
import os
import random

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "hd2d")


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


GRASS = [hexc(c) for c in ("27532c", "316b34", "3f823c", "559a45", "74b050", "a2cc68")]
ROCK = [hexc(c) for c in ("3a2f2c", "54453c", "6f5d4f", "8a7563", "a69078", "c2ad92")]
STONE = [hexc(c) for c in ("434852", "5c6470", "7a8590", "9aa5ad", "bcc5c9")]
WOOD = [hexc(c) for c in ("3d2416", "5a3720", "7a4e2c", "9a683c", "bb8752", "d9a96c")]
LEAF = [hexc(c) for c in ("173d24", "1f522c", "2c6a33", "3f873b", "5aa446", "82c457", "b2df73")]
BARK = [hexc(c) for c in ("2e1e16", "47301f", "634429", "7f5a36")]
OUTLINE = hexc("1a1420")


def tile_noise(n, cell, seed):
    """Tileable value noise in [0,1], size n x n, lattice spacing `cell`."""
    rng = np.random.default_rng(seed)
    g = n // cell
    lat = rng.random((g, g))
    out = np.zeros((n, n))
    for y in range(n):
        for x in range(n):
            fx, fy = x / cell, y / cell
            x0, y0 = int(fx) % g, int(fy) % g
            x1, y1 = (x0 + 1) % g, (y0 + 1) % g
            tx, ty = fx - int(fx), fy - int(fy)
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            a = lat[y0, x0] * (1 - tx) + lat[y0, x1] * tx
            b = lat[y1, x0] * (1 - tx) + lat[y1, x1] * tx
            out[y, x] = a * (1 - ty) + b * ty
    return out


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def quant(v, pal, x, y, dither=0.6):
    """Map v in [0,1] onto palette index with ordered dithering."""
    v = v * (len(pal) - 1) + BAYER[y % 4, x % 4] * dither
    return pal[int(max(0, min(len(pal) - 1, round(v))))]


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


# ---------------------------------------------------------------- terrain

def grass_top():
    n = 32
    big = tile_noise(n, 8, 1)
    fine = tile_noise(n, 4, 2)
    rng = random.Random(3)
    img = Image.new("RGB", (n, n))
    px = img.load()
    for y in range(n):
        for x in range(n):
            v = 0.25 + 0.45 * big[y, x] + 0.25 * fine[y, x]
            px[x, y] = quant(v, GRASS[:5], x, y)
    # blades: short 1x2 strokes, light tip over dark base
    for _ in range(70):
        x, y = rng.randrange(n), rng.randrange(n)
        px[x, y] = GRASS[4] if rng.random() < 0.6 else GRASS[5]
        px[x, (y + 1) % n] = GRASS[1]
    # tiny flowers
    for _ in range(5):
        x, y = rng.randrange(n), rng.randrange(n)
        c = hexc(rng.choice(["fff4d6", "ffd84a", "f7a6c8", "cfe8ff"]))
        px[x, y] = c
        px[x, (y + 1) % n] = GRASS[0]
    save(img, "grass_top.png")


def cliff_side():
    """Layered rock strata: rows of rounded stones, lit from above."""
    n = 32
    rng = random.Random(7)
    img = Image.new("RGB", (n, n), ROCK[0])
    px = img.load()
    noise = tile_noise(n, 8, 9)
    y = 0
    rows = [9, 7, 8, 8]  # sums to 32 so the texture tiles vertically
    for ri, rh in enumerate(rows):
        x = rng.randrange(0, 6)
        start = x
        widths = []
        while sum(widths) < n:
            widths.append(rng.choice([7, 8, 9, 10, 11, 12]))
        widths[-1] -= sum(widths) - n  # exact wrap
        if widths[-1] < 4:
            widths[-2] += widths[-1]
            widths.pop()
        for w in widths:
            for sy in range(rh - 1):
                for sx in range(w - 1):
                    # rounded corners
                    if (sx in (0, w - 2)) and (sy in (0, rh - 2)):
                        continue
                    t = sy / max(1, rh - 2)
                    v = 0.85 - 0.6 * t + 0.25 * noise[(y + sy) % n, (x + sx) % n] - 0.12
                    if sy == 0:
                        v += 0.2
                    if sx == 0:
                        v += 0.08
                    if sx == w - 2:
                        v -= 0.12
                    px[(x + sx) % n, (y + sy) % n] = quant(v, ROCK[1:], (x + sx), (y + sy), 0.5)
            # specks
            if rng.random() < 0.7:
                px[(x + rng.randrange(1, w - 2)) % n, (y + rng.randrange(1, rh - 2)) % n] = ROCK[5]
            x += w
        y += rh
    # moss streaks drip down from the top
    for _ in range(6):
        mx = rng.randrange(n)
        for my in range(rng.randrange(2, 7)):
            px[mx, my] = GRASS[1] if my > 1 else GRASS[2]
    save(img, "cliff_side.png")


def grass_lip():
    """Grass overhang that hangs over a cliff edge (32 x 12, alpha)."""
    w, h = 32, 12
    rng = random.Random(11)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    depth = [0] * w
    x = 0
    while x < w:
        tuft = rng.randrange(2, 5)
        d = rng.randrange(4, h - 1)
        for i in range(tuft):
            if x + i < w:
                depth[x + i] = max(3, d - abs(i - tuft // 2) * 2)
        x += tuft
    depth[-1] = depth[0]
    for x in range(w):
        for y in range(depth[x]):
            if y == depth[x] - 1:
                c = GRASS[0]
            elif y < 2:
                c = GRASS[4] if (x + y) % 3 else GRASS[5]
            else:
                c = quant(0.75 - y / depth[x] * 0.6, GRASS[1:5], x, y)
            px[x, y] = c + (255,)
    save(img, "grass_lip.png")


def wood_planks():
    n = 32
    rng = random.Random(5)
    img = Image.new("RGB", (n, n))
    px = img.load()
    noise = tile_noise(n, 4, 6)
    x = 0
    for pw in (8, 8, 8, 8):
        base = rng.uniform(0.45, 0.7)
        for sx in range(pw):
            for y in range(n):
                v = base + 0.18 * math.sin((y + sx * 3) * 0.7 + x) * 0.5 + 0.2 * noise[y, (x + sx) % n] - 0.1
                if sx == 0:
                    v += 0.15
                if sx == pw - 1:
                    c = WOOD[0]
                else:
                    c = quant(v, WOOD[1:], x + sx, y, 0.4)
                px[x + sx, y] = c
        # nails
        for ny in (3, 19):
            px[x + 2, ny] = STONE[3]
            px[x + pw - 3, ny] = STONE[3]
        x += pw
    save(img, "wood_planks.png")


def wood_log():
    """Bark texture for posts and rails (16 x 16)."""
    n = 16
    img = Image.new("RGB", (n, n))
    px = img.load()
    noise = tile_noise(n, 4, 12)
    for y in range(n):
        for x in range(n):
            v = 0.3 + 0.5 * noise[y, x] + (0.2 if x % 5 == 1 else 0.0) - (0.25 if x % 5 == 3 else 0.0)
            px[x, y] = quant(v, WOOD[:5], x, y, 0.5)
    save(img, "wood_log.png")


# ---------------------------------------------------------------- sprites

def blob_canopy(w, h, blobs, seed, pal, light=(-0.55, -0.75)):
    """Canopy from overlapping leaf clusters, each shaded like a small
    sphere lit from the upper left, with a dark outline. Returns RGBA."""
    rng = random.Random(seed)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    mask = np.zeros((h, w), bool)
    shade = np.zeros((h, w))
    lx, ly = light
    ll = math.hypot(lx, ly)
    lx, ly = lx / ll, ly / ll
    for (cx, cy, r) in blobs:
        for y in range(max(0, int(cy - r - 1)), min(h, int(cy + r + 2))):
            for x in range(max(0, int(cx - r - 1)), min(w, int(cx + r + 2))):
                dx, dy = (x - cx) / r, (y - cy) / r
                d = dx * dx + dy * dy
                # bumpy edge: leaf clusters, not perfect circles
                ang = math.atan2(dy, dx)
                edge = 1.0 + 0.12 * math.sin(ang * 7 + cx) + 0.08 * math.sin(ang * 13 + cy)
                if d <= edge * edge:
                    nz = math.sqrt(max(0.0, 1 - min(1.0, d)))
                    lit = -(dx * lx + dy * ly) * 0.6 + nz * 0.5
                    mask[y, x] = True
                    shade[y, x] = lit  # later blobs (drawn on top) win
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            v = 0.35 + shade[y, x] * 0.55 + rng.uniform(-0.06, 0.06)
            c = quant(max(0, min(1, v)), pal, x, y, 0.7)
            img[y, x] = c + (255,)
    # leaf speckle highlights on the lit side
    for _ in range(w * h // 18):
        x, y = rng.randrange(w), rng.randrange(h)
        if mask[y, x] and shade[y, x] > 0.35:
            img[y, x, :3] = pal[-1]
    # outline
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if mask[y, x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and mask[yy, xx]:
                    out[y, x] = OUTLINE + (255,)
                    break
    return out, mask


def trunk(img, x0, y0, y1, wdt):
    h, w = img.shape[:2]
    for y in range(y0, min(h, y1)):
        spread = wdt + (2 if y > y1 - 4 else 0) + (1 if y > y1 - 2 else 0)
        for x in range(x0 - spread // 2, x0 + (spread + 1) // 2):
            if 0 <= x < w and img[y, x, 3] == 0:
                rel = (x - (x0 - spread // 2)) / max(1, spread - 1)
                v = 0.85 - rel * 0.75 + (0.15 if (y // 3 + x) % 4 == 0 else 0)
                img[y, x] = quant(v, BARK, x, y) + (255,)
        # outline both sides
        for x in (x0 - spread // 2 - 1, x0 + (spread + 1) // 2):
            if 0 <= x < w and img[y, x, 3] == 0:
                img[y, x] = OUTLINE + (255,)


def tree_round(seed, name):
    w, h = 64, 80
    rng = random.Random(seed)
    blobs = []
    for i in range(14):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0, 16)
        blobs.append((32 + math.cos(a) * rr * 1.1, 30 + math.sin(a) * rr * 0.8, rng.uniform(9, 13)))
    blobs.sort(key=lambda b: b[1])  # lower clusters on top
    canopy, _ = blob_canopy(w, h, blobs, seed, LEAF[1:])
    img = np.zeros((h, w, 4), np.uint8)
    trunk(img, 32, 40, h, 5)
    # branch stubs
    for y in range(44, 52):
        for x in (28 - (y - 44) // 2, 36 + (y - 44) // 2):
            img[y, x] = BARK[2] + (255,)
    m = canopy[:, :, 3] > 0
    img[m] = canopy[m]
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


def tree_pine(seed, name):
    w, h = 64, 96
    rng = random.Random(seed)
    img = np.zeros((h, w, 4), np.uint8)
    trunk(img, 32, 60, h, 4)
    layers = 6
    for i in range(layers):
        top = 6 + i * 11
        half = 7 + i * 3
        bh = 16
        blobs = []
        for k in range(5):
            t = k / 4
            blobs.append((32 - half + t * half * 2, top + bh * 0.7 + rng.uniform(-1, 1), 4.5 + (1 - abs(t - 0.5) * 2) * 3))
        blobs.append((32, top + 6, 5))
        canopy, m = blob_canopy(w, h, blobs, seed + i, LEAF[:6], light=(-0.6, -0.8))
        img[canopy[:, :, 3] > 0] = canopy[canopy[:, :, 3] > 0]
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


def bush(seed, name, w=32, h=22):
    rng = random.Random(seed)
    blobs = [(rng.uniform(8, w - 8), rng.uniform(10, h - 7), rng.uniform(6, 8)) for _ in range(6)]
    blobs.sort(key=lambda b: b[1])
    canopy, _ = blob_canopy(w, h, blobs, seed, LEAF[2:])
    # flowers on some bushes
    if seed % 2 == 0:
        for _ in range(6):
            x, y = rng.randrange(4, w - 4), rng.randrange(4, h - 6)
            if canopy[y, x, 3]:
                canopy[y, x, :3] = hexc("ffe9f2") if seed % 4 == 0 else hexc("ffd84a")
    Image.fromarray(canopy, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


def grass_tuft(seed, name):
    w, h = 16, 12
    rng = random.Random(seed)
    img = np.zeros((h, w, 4), np.uint8)
    for b in range(9):
        x = rng.randrange(1, w - 1)
        bh = rng.randrange(5, h)
        lean = rng.choice([-1, 0, 1])
        for y in range(bh):
            xx = x + (lean if y > bh * 0.6 else 0)
            c = GRASS[5] if y > bh - 2 else GRASS[3] if y > bh // 2 else GRASS[1]
            if 0 <= xx < w:
                img[h - 1 - y, xx] = c + (255,)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


def rock_sprite(seed, name):
    w, h = 20, 14
    rng = random.Random(seed)
    blobs = [(10 + rng.uniform(-3, 3), 9, 6), (6, 10, 4), (14, 10, 4)]
    img, _ = blob_canopy(w, h, blobs, seed, STONE[:5])
    for y in range(h - 3, h):  # a little moss at the foot
        for x in range(w):
            if img[y, x, 3] and rng.random() < 0.5:
                img[y, x, :3] = GRASS[2]
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


def flowers(name):
    w, h = 16, 10
    img = np.zeros((h, w, 4), np.uint8)
    rng = random.Random(31)
    for _ in range(5):
        x = rng.randrange(2, w - 2)
        top = rng.randrange(1, 5)
        for y in range(top + 1, h):
            img[y, x] = GRASS[2] + (255,)
        c = hexc(rng.choice(["fff4d6", "ffd84a", "f7a6c8", "9fd0ff"]))
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
            img[top + dy, x + dx] = c + (255,)
        img[top, x] = hexc("f2a53a") + (255,)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


def soft_dot(name, size=16):
    """Round soft particle for pollen / spray (white, alpha falloff)."""
    img = np.zeros((size, size, 4), np.uint8)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = max(0.0, 1 - d) ** 1.6
            img[y, x] = (255, 255, 255, int(a * 255))
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))
    print("wrote", name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    grass_top()
    cliff_side()
    grass_lip()
    wood_planks()
    wood_log()
    tree_round(41, "tree_round_a.png")
    tree_round(57, "tree_round_b.png")
    tree_pine(63, "tree_pine.png")
    bush(2, "bush_a.png")
    bush(5, "bush_b.png")
    bush(8, "bush_c.png", 40, 26)
    grass_tuft(71, "tuft.png")
    rock_sprite(81, "rock.png")
    flowers("flowers.png")
    soft_dot("dot.png")
