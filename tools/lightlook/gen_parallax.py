#!/usr/bin/env python3
"""Generates the original dusk parallax layers and light props for the
"Licht" look test (assets/lightlook/). Reuses the tree/bush cards from
assets/hd2d/ as silhouettes. Run from the repo root:
    python3 tools/lightlook/gen_parallax.py
Deterministic (fixed seeds)."""

import math
import os
import random

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "lightlook")
HD2D = os.path.join(ROOT, "assets", "hd2d")
H = 360  # art pixels (screen 720 at 2x)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))
    print("wrote", name, arr.shape[1], "x", arr.shape[0])


def gradient(stops, t):
    """stops: [(pos, hex)], t in [0,1] -> rgb"""
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            k = (t - p0) / max(1e-6, p1 - p0)
            return hexc(c0) * (1 - k) + hexc(c1) * k
    return hexc(stops[-1][1])


def sky():
    w = 640
    stops = [(0.0, "1d1838"), (0.35, "3b2a5c"), (0.6, "7a3f72"), (0.78, "d2647a"), (0.9, "f39a6a"), (1.0, "ffd08a")]
    img = np.zeros((H, w, 4))
    levels = 18
    for y in range(H):
        for x in range(w):
            t = y / (H - 1) + BAYER[y % 4, x % 4] * (1.0 / levels)
            t = round(max(0, min(1, t)) * levels) / levels  # banded, dithered
            img[y, x, :3] = gradient(stops, t)
            img[y, x, 3] = 255
    # low sun with soft rings (pixel steps)
    sx, sy = 170, 196
    for y in range(H):
        for x in range(w):
            d = math.hypot(x - sx, (y - sy) * 1.15)
            if d < 20:
                img[y, x, :3] = hexc("fff0c0") if d < 17 else hexc("ffd893")
            else:
                g = max(0.0, 1 - d / 140) ** 2 * 0.55
                g = round(g * 6) / 6
                img[y, x, :3] = img[y, x, :3] * (1 - g) + hexc("ffc27a") * g
    # long cloud streaks, lit from below
    rng = random.Random(4)
    for _ in range(9):
        cy = rng.randrange(70, 230)
        cx = rng.randrange(0, w)
        ln = rng.randrange(60, 180)
        th = rng.randrange(3, 8)
        for i in range(ln):
            x = (cx + i) % w
            taper = min(i, ln - i) / (ln / 2)
            t2 = max(1, int(th * taper + 0.5))
            for k in range(t2):
                y = cy + k
                lit = k == t2 - 1
                base = img[y, x, :3]
                img[y, x, :3] = base * 0.45 + (hexc("ffb38a") if lit else hexc("b0607e")) * 0.55
    save(img, "sky.png")


def ridge(w, base, amp, seed, freqs):
    rng = random.Random(seed)
    ph = [rng.uniform(0, math.tau) for _ in freqs]
    out = []
    for x in range(w):
        y = base
        for (f, a), p in zip(zip(freqs, amp), ph):
            y += a * math.sin(x / w * math.tau * f + p)
        out.append(y)
    return out


def blur(img, r):
    if r <= 0:
        return img
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    # premultiply-ish: blur rgb and alpha together on RGBA is fine for silhouettes
    im = im.filter(ImageFilter.GaussianBlur(r))
    return np.array(im, float)


def mountains():
    w = 640
    img = np.zeros((H, w, 4))
    far = ridge(w, 215, [22, 10, 5], 1, [2, 5, 11])
    near = ridge(w, 245, [16, 8, 4], 2, [3, 7, 13])
    for x in range(w):
        for y in range(H):
            if y >= far[x]:
                img[y, x] = list(hexc("6a4a86")) + [255]
                if y < far[x] + 2:
                    img[y, x, :3] = hexc("c07a9a")  # sunlit edge
            if y >= near[x]:
                t = min(1, (y - near[x]) / 60)
                img[y, x] = list(hexc("4e3a72") * (1 - t) + hexc("5c4a7c") * t) + [255]
                if y < near[x] + 2 and x < w * 0.6:
                    img[y, x, :3] = hexc("b06f8c")
    # mist band at the foot
    for y in range(250, H):
        a = min(1, (y - 250) / 80) * 0.6
        img[y, :, :3] = img[y, :, :3] * (1 - a) + hexc("a77a98") * a
    save(blur(img, 1.2), "mountains.png")


def load_card(name):
    return np.array(Image.open(os.path.join(HD2D, name)).convert("RGBA"), float)


def place(canvas, card, x, base_y, scale, color, rim=None):
    """Paste a card as a flat-colored silhouette (with optional warm rim on
    its left/top edges, where the low sun hits)."""
    h, w = card.shape[:2]
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    im = Image.fromarray(card.astype(np.uint8), "RGBA").resize((nw, nh), Image.NEAREST)
    a = np.array(im)[:, :, 3] > 0
    ch, cw = canvas.shape[:2]
    top = int(base_y - nh)
    left = int(x - nw / 2)
    for yy in range(nh):
        for xx in range(nw):
            if not a[yy, xx]:
                continue
            cx = (left + xx) % cw
            cy = top + yy
            if 0 <= cy < ch:
                col = color
                if rim is not None:
                    edge = (xx == 0 or not a[yy, xx - 1]) or (yy == 0 or not a[yy - 1, xx])
                    if edge:
                        col = rim
                canvas[cy, cx] = list(col) + [255]


def forest(name, w, base, scale_rng, color, rim, haze, blur_r, seed, density, ground_col):
    rng = random.Random(seed)
    img = np.zeros((H, w, 4))
    cards = [load_card(n) for n in ("tree_round_a.png", "tree_round_b.png", "tree_pine.png", "tree_pine.png")]
    x = 0
    while x < w:
        c = rng.choice(cards)
        s = rng.uniform(*scale_rng)
        place(img, c, x, base + rng.randint(-4, 4), s, color, rim)
        x += int(rng.uniform(0.35, 0.8) * c.shape[1] * s / density)
    # ground below the trees
    for y in range(base - 2, H):
        img[y, :] = list(ground_col) + [255]
    # haze toward the bottom (mist in the valley)
    if haze is not None:
        for y in range(base - 40, H):
            a = min(1, max(0, (y - (base - 40)) / 70)) * haze[1]
            m = img[y, :, 3] > 0
            img[y, m, :3] = img[y, m, :3] * (1 - a) + haze[0] * a
    save(blur(img, blur_r), name)


def trees_near():
    w = 1280
    rng = random.Random(9)
    img = np.zeros((H, w, 4))
    trunk = hexc("241b33")
    rim = hexc("a8586a")
    leaf = hexc("1d1a30")
    for i in range(7):
        cx = int(i * w / 7 + rng.randint(-40, 40))
        tw = rng.randint(14, 24)
        for y in range(H):
            sway = int(3 * math.sin(y / 40 + i))
            for x in range(cx - tw // 2 + sway, cx + tw // 2 + sway):
                xx = x % w
                img[y, xx] = list(trunk) + [255]
                if x == cx - tw // 2 + sway:
                    img[y, xx, :3] = rim
                if (x + y // 6) % 7 == 0:
                    img[y, xx, :3] = trunk * 0.8
        # roots
        for k in range(8):
            for x in range(cx - tw, cx + tw):
                if abs(x - cx) < tw - k * 1.5:
                    img[H - 8 + k, x % w] = list(trunk) + [255]
        # hanging leaf clusters at the top
        for _ in range(34):
            lx = cx + rng.randint(-70, 70)
            ly = rng.randint(-6, 46)
            r = rng.randint(10, 18)
            for y in range(ly - r, ly + r):
                for x in range(lx - r, lx + r):
                    if 0 <= y < H and (x - lx) ** 2 + (y - ly) ** 2 < r * r:
                        img[y, x % w] = list(leaf) + [255]
    save(img, "trees_near.png")


def foreground():
    w = 1280
    rng = random.Random(13)
    img = np.zeros((H, w, 4))
    col = hexc("0f0b18")
    # grass and bushes along the bottom edge, leaves hanging from the top
    x = 0
    while x < w:
        if rng.random() < 0.55:
            r = rng.randint(18, 40)
            cx, cy = x, H - rng.randint(0, 14)
            for y in range(cy - r, H):
                for xx in range(cx - r, cx + r):
                    if (xx - cx) ** 2 + (y - cy) ** 2 < r * r:
                        img[y, xx % w] = list(col) + [255]
            for _ in range(14):
                bx = cx + rng.randint(-r, r)
                bh = rng.randint(10, 34)
                for y in range(cy - r // 2 - bh, H):
                    img[y, bx % w] = list(col) + [255]
        x += rng.randint(60, 160)
    x = 0
    while x < w:
        if rng.random() < 0.35:
            for _ in range(rng.randint(3, 6)):
                lx = x + rng.randint(-30, 30)
                ln = rng.randint(20, 60)
                for y in range(0, ln):
                    for k in range(-2, 3):
                        img[y, (lx + k + int(4 * math.sin(y / 8))) % w] = list(col) + [255]
                r = rng.randint(14, 26)
                for y in range(0, r):
                    for xx in range(lx - r, lx + r):
                        if (xx - lx) ** 2 + y * y < r * r:
                            img[y, xx % w] = list(col) + [255]
        x += rng.randint(120, 240)
    save(blur(img, 3.0), "foreground.png")


def lantern():
    w, h = 16, 44
    img = np.zeros((h, w, 4))
    wood, dark, metal = hexc("6b4a2e"), hexc("3a2718"), hexc("2b2730")
    for y in range(12, h):
        for x in range(7, 10):
            img[y, x] = list(wood if x < 9 else dark) + [255]
    for x in range(4, 13):  # arm
        img[10, x] = list(dark) + [255]
    # lantern box with glowing glass
    for y in range(12, 24):
        for x in range(2, 9):
            edge = y in (12, 23) or x in (2, 8)
            img[y, x] = list(metal if edge else hexc("ffd27a" if y > 14 else "ffe9b0")) + [255]
    img[11, 4:7] = list(metal) + [255]
    for y in range(h - 3, h):
        for x in range(5, 12):
            img[y, x] = list(dark) + [255]
    save(img, "lantern.png")


def crystal():
    w, h = 22, 26
    img = np.zeros((h, w, 4))
    rng = random.Random(3)
    shards = [(11, 2, 5), (6, 9, 4), (16, 8, 4), (9, 13, 3)]
    for (cx, top, hw) in shards:
        for y in range(top, h - 2):
            half = hw * min(1.0, (y - top) / 6 + 0.2)
            for x in range(int(cx - half), int(cx + half) + 1):
                if 0 <= x < w:
                    left = x < cx
                    c = hexc("bff6ff") if left and x > cx - half + 1 else hexc("6fd6ff") if left else hexc("7b6cff")
                    if x in (int(cx - half), int(cx + half)):
                        c = hexc("2c2560")
                    img[y, x] = list(c) + [255]
    for y in range(h - 3, h):
        for x in range(3, w - 3):
            img[y, x] = list(hexc("3d3550")) + [255]
    save(img, "crystal.png")


def halo(name, size=64, power=2.2):
    img = np.zeros((size, size, 4))
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = max(0.0, 1 - d) ** power
            img[y, x] = [255, 255, 255, a * 255]
    save(img, name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sky()
    mountains()
    forest("forest_far.png", 640, 296, (0.5, 0.75), hexc("7a5a8c"), hexc("c88096"), (hexc("a07c9e"), 0.5), 1.2, 21, 1.3, hexc("7a5a8c"))
    forest("forest_mid.png", 960, 318, (0.95, 1.35), hexc("2e2448"), hexc("d0707a"), (hexc("5a4470"), 0.3), 0.4, 22, 0.9, hexc("2e2448"))
    trees_near()
    foreground()
    lantern()
    crystal()
    halo("halo.png")
