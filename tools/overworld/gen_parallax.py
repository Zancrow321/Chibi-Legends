#!/usr/bin/env python3
"""Generates the parallax backdrop of the overworld (Akademie-Hof): a clear
late-morning sky, distant mountains with floating islands and the academy's
main spire, academy buildings, a near row of trees and cherry blossoms and a
blurred blossom foreground. Everything is snapped to Resurrect 64.
Deterministic. Run from the repo root:
    python3 tools/overworld/gen_parallax.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "overworld")
H = 360
HORIZON = 228  # where the courtyard ground sits on screen (art px)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
PAL = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in open(os.path.join(ROOT, "assets", "palettes", "resurrect-64.hex")).read().split()], float)


def c(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def snap(img):
    rgb = img[:, :, :3].reshape(-1, 3)
    d = ((rgb[:, None, :] - PAL[None, :, :]) ** 2).sum(-1)
    img[:, :, :3] = PAL[d.argmin(1)].reshape(img.shape[0], img.shape[1], 3)
    img[:, :, 3] = np.where(img[:, :, 3] >= 128, 255, 0)
    return img


def save(img, name, do_snap=True):
    if do_snap:
        img = snap(img)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))
    print("wrote", name, img.shape[1], "x", img.shape[0])


def grad(stops, t):
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            k = (t - p0) / max(1e-6, p1 - p0)
            return c(c0) * (1 - k) + c(c1) * k
    return c(stops[-1][1])


def rect(img, x0, y0, x1, y1, col, a=255):
    h, w = img.shape[:2]
    x0, x1 = max(0, int(x0)), min(w, int(x1))
    y0, y1 = max(0, int(y0)), min(h, int(y1))
    if x0 < x1 and y0 < y1:
        img[y0:y1, x0:x1, :3] = col
        img[y0:y1, x0:x1, 3] = a


def blob(img, cx, cy, rx, ry, col):
    h, w = img.shape[:2]
    for y in range(max(0, int(cy - ry)), min(h, int(cy + ry) + 1)):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                img[y, x % w, :3] = col
                img[y, x % w, 3] = 255


def haze(img, col, amount):
    m = img[:, :, 3] > 0
    img[m, :3] = img[m, :3] * (1 - amount) + c(col) * amount


# --- sky ---------------------------------------------------------------------

def dither(stops, t, x, y):
    """Ordered dither between the two palette stops around t (no off-palette mixes)."""
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            k = (t - p0) / max(1e-6, p1 - p0)
            k = min(1.0, max(0.0, (k - 0.5) * 2.5 + 0.5))  # flat bands, short dithered seams
            return c(c1) if k + BAYER[y % 4, x % 4] > 0.5 else c(c0)
    return c(stops[-1][1])


def sky():
    w = 640
    stops = [(0.0, "4d65b4"), (0.42, "4d9be6"), (0.75, "8fd3ff"), (0.95, "c7dcd0"), (1.0, "c7dcd0")]
    img = np.zeros((H, w, 4))
    for y in range(H):
        t = min(1.0, y / (HORIZON - 10))
        # keep the bands: only dither inside a narrow strip around each step
        for x in range(w):
            img[y, x, :3] = dither(stops, t, x, y)
            img[y, x, 3] = 255
    sx, sy = 470, 58
    for y in range(20, 100):
        for x in range(420, 520):
            d = math.hypot(x - sx, y - sy)
            if d < 12:
                img[y, x, :3] = c("ffffff")
            elif d < 15:
                img[y, x, :3] = c("fbff86")
            elif d < 30 and (x + y) % 2 == 0:
                img[y, x, :3] = c("8fd3ff")
    rng = random.Random(9)
    for _ in range(8):
        cx = rng.randrange(0, w)
        cy = rng.randrange(60, 170)
        size = rng.uniform(0.6, 1.2)
        parts = [(cx + rng.randrange(-30, 30) * size, cy - rng.randrange(0, 10) * size, rng.uniform(9, 17) * size) for _ in range(rng.randrange(4, 7))]
        bottom = cy + 6
        tmp = np.zeros((H, w, 4))
        for (px, py, r) in parts:
            blob(tmp, px, py + 3, r, r * 0.8, c("c7dcd0"))
        for (px, py, r) in parts:
            blob(tmp, px - 2, py - 1, r - 3, r * 0.8 - 3, c("ffffff"))
        tmp[int(bottom):, :, 3] = 0
        row = tmp[int(bottom) - 1]
        row[row[:, 3] > 0, :3] = c("9babb2")
        m = tmp[:, :, 3] > 0
        img[m] = tmp[m]
    save(img, "sky.png")


# --- far: mountains, floating islands, the main spire ------------------------

def ridge(w, base, amps, seed, freqs):
    rng = random.Random(seed)
    ph = [rng.uniform(0, math.tau) for _ in freqs]
    return [base + sum(a * math.sin(x / w * math.tau * f + p) for a, f, p in zip(amps, freqs, ph)) for x in range(w)]


def spire(img, x, base, h, wdt, wall, roof, win):
    rect(img, x - wdt // 2, base - h, x + wdt // 2, base, wall)
    for k in range(wdt // 2 + 4):  # pointed roof
        rect(img, x - wdt // 2 - 2 + k, base - h - k * 2.2, x + wdt // 2 + 2 - k, base - h - k * 2.2 + 3, roof)
    for wy in range(base - h + 8, base - 6, 14):
        rect(img, x - 1, wy, x + 1, wy + 5, win)


def far():
    w = 960
    img = np.zeros((H, w, 4))
    back = ridge(w, 186, [14, 7, 3], 3, [2, 5, 13])
    front = ridge(w, 206, [10, 5, 2], 5, [3, 8, 17])
    for x in range(w):
        for y in range(int(back[x]), H):
            img[y, x] = list(c("8fd3ff")) + [255]
        if back[x] < 190:  # snow caps
            for y in range(int(back[x]), int(back[x]) + 3):
                img[y, x, :3] = c("ffffff")
        for y in range(int(front[x]), H):
            img[y, x] = list(c("9babb2")) + [255]
        img[int(front[x]), x, :3] = c("c7dcd0")
    # the academy on its hill: main spire and side towers
    ax = 470
    for x in range(ax - 90, ax + 90):
        hill = 196 - 18 * math.cos((x - ax) / 90 * math.pi / 2)
        for y in range(int(hill), H):
            img[y, x] = list(c("9babb2")) + [255]
    wall, roof, win = c("ffffff"), c("4d9be6"), c("8fd3ff")
    for (dx, h, wd) in [(-62, 44, 12), (-36, 62, 14), (0, 104, 20), (34, 70, 14), (60, 48, 12)]:
        spire(img, ax + dx, 182, h, wd, wall, roof, win)
    rect(img, ax - 70, 170, ax + 70, 184, wall)
    for k in range(0, 140, 6):
        rect(img, ax - 70 + k, 167, ax - 67 + k, 170, wall)
    # floating islands with thin waterfalls
    rng = random.Random(12)
    for (ix, iy, iw) in [(150, 70, 46), (310, 110, 24), (700, 56, 54), (860, 118, 30)]:
        for x in range(ix - iw, ix + iw):
            k = 1 - abs(x - ix) / iw
            depth = int(6 + 22 * k ** 1.5)
            rect(img, x, iy, x + 1, iy + depth, c("9babb2"))
            rect(img, x, iy + depth - 3, x + 1, iy + depth, c("7f708a"))
            rect(img, x, iy - 3 - int(4 * k), x + 1, iy, c("91db69") if k > 0.15 else c("547e64"))
            rect(img, x, iy, x + 1, iy + 2, c("ab947a"))
        for (tx, th) in [(ix - iw // 3, 10), (ix + iw // 4, 14)]:
            blob(img, tx, iy - 6 - th // 2, 5 + th // 4, th // 2, c("239063"))
            blob(img, tx + 1, iy - 8 - th // 2, 3 + th // 6, th // 3, c("1ebc73"))
        fx = ix + rng.randrange(-iw // 2, iw // 2)
        rect(img, fx, iy + 4, fx + 2, iy + 60, c("ffffff"))
        rect(img, fx + 2, iy + 4, fx + 3, iy + 60, c("8fd3ff"))
    # mist at the foot: dithered into the pale tone
    for y in range(200, H):
        a = min(1, (y - 200) / 30)
        for x in range(w):
            if img[y, x, 3] > 0 and a + BAYER[y % 4, x % 4] > 0.5:
                img[y, x, :3] = c("c7dcd0")
    save(img, "far.png")


# --- mid: academy buildings ----------------------------------------------------

def building(img, x, w, h, base, rng, roof_col="0b5e65", wall="fdcbb0"):
    top = base - h
    rect(img, x, top, x + w, base, c(wall))
    rect(img, x, top, x + 3, base, c("ab947a") if wall == "fdcbb0" else c("9babb2"))  # shaded left edge
    rect(img, x + w - 3, top, x + w, base, c("ffffff"))
    for yy in range(top + 6, base, 9):                   # plaster bands
        if rng.random() < 0.25:
            rect(img, x + 3, yy, x + w - 3, yy + 1, c("fca790") if wall == "fdcbb0" else c("9babb2"))
    rect(img, x, top + 10, x + w, top + 13, c("694f62"))  # beam
    # windows: dark glass, some warm-lit, frames
    for wy in range(top + 18, base - 14, 22):
        for wx in range(x + 7, x + w - 10, 16):
            lit = rng.random() < 0.3
            rect(img, wx - 1, wy - 1, wx + 8, wy + 13, c("694f62"))
            rect(img, wx, wy, wx + 7, wy + 12, c("f9c22b") if lit else c("323353"))
            rect(img, wx, wy, wx + 7, wy + 2, c("fbff86") if lit else c("4d65b4"))
            rect(img, wx + 3, wy, wx + 4, wy + 12, c("694f62"))
    # roof: overhanging, curved ends, tile stripes
    ov = 8
    rh = 16 + w // 14
    for k in range(rh):
        t = k / rh
        inset = int((1 - t) ** 1.6 * (w * 0.32))
        y = top - rh + k
        rect(img, x - ov + inset, y, x + w + ov - inset, y + 1, c(roof_col))
        if k % 3 == 0:
            rect(img, x - ov + inset, y, x + w + ov - inset, y + 1, c("0b8a8f"))
    rect(img, x - ov - 2, top - 2, x + w + ov + 2, top + 1, c("165a4c"))
    rect(img, x - ov - 4, top - 4, x - ov, top - 1, c("0b8a8f"))      # upturned tips
    rect(img, x + w + ov, top - 4, x + w + ov + 4, top - 1, c("0b8a8f"))
    rect(img, x + w // 2 - 2, top - rh - 6, x + w // 2 + 2, top - rh, c("f9c22b"))  # finial


def mid():
    w = 1280
    img = np.zeros((H, w, 4))
    rng = random.Random(21)
    base = HORIZON - 4
    x = -20
    while x < w:
        bw = rng.choice([70, 90, 110, 130])
        bh = rng.choice([60, 74, 90])
        if rng.random() < 0.25:  # tower
            bw, bh = 40, 128
        building(img, x, bw, bh, base, rng, rng.choice(["0b5e65", "323353", "0b5e65", "4d65b4"]), rng.choice(["fdcbb0", "c7dcd0", "c7dcd0"]))
        x += bw + rng.choice([16, 24, 40])
    # wall/fence along the bottom
    rect(img, 0, base, w, H, c("ab947a"))
    rect(img, 0, base, w, base + 2, c("c7dcd0"))
    for k in range(0, w, 24):
        rect(img, k, base - 6, k + 4, base, c("ab947a"))
    save(img, "mid.png")


# --- near: trees, cherry blossoms, hedges ---------------------------------------

def crown(img, cx, cy, r, cols, rng):
    dark, mid_, light, hi = [c(k) for k in cols]
    for _ in range(int(r * 1.4)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, r * 0.75)
        blob(img, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.7, r * 0.42, r * 0.36, dark)
    for _ in range(int(r)):
        a = rng.uniform(-math.pi, 0.3)
        d = rng.uniform(0, r * 0.6)
        blob(img, cx + math.cos(a) * d + 2, cy + math.sin(a) * d * 0.6 - 2, r * 0.32, r * 0.27, mid_)
    for _ in range(int(r * 0.6)):
        a = rng.uniform(-math.pi * 0.9, -0.2)
        d = rng.uniform(r * 0.2, r * 0.6)
        blob(img, cx + math.cos(a) * d + 4, cy + math.sin(a) * d * 0.6 - 4, r * 0.18, r * 0.14, light)
    for _ in range(int(r * 0.4)):
        px, py = int(cx + rng.uniform(-r * 0.6, r * 0.7)), int(cy + rng.uniform(-r * 0.6, 0))
        rect(img, px, py, px + 2, py + 1, hi)


def near():
    w = 1280
    img = np.zeros((H, w, 4))
    rng = random.Random(33)
    base = HORIZON + 6
    x = 20
    while x < w + 40:
        sak = rng.random() < 0.55
        th = rng.randrange(40, 70)
        rect(img, x - 3, base - th, x + 3, base, c("694f62"))
        rect(img, x - 3, base - th, x - 1, base, c("45293f"))
        r = rng.randrange(26, 40)
        cols = ["cf657f", "ed8099", "fca790", "fdcbb0"] if sak else ["165a4c", "239063", "1ebc73", "91db69"]
        crown(img, x, base - th - r * 0.3, r, cols, rng)
        x += rng.randrange(90, 170)
    # hedge row
    for x in range(0, w, 14):
        blob(img, x + 7, base + 2, 12, 9, c("239063"))
        blob(img, x + 8, base, 8, 5, c("1ebc73"))
    rect(img, 0, base + 6, w, H, c("165a4c"))
    save(img, "near.png")


# --- foreground: blurred blossom branches ----------------------------------------

def foreground():
    w = 1600
    img = np.zeros((H, w, 4))
    rng = random.Random(44)
    for bx in []:  # branches looked like smudges in play; only grass at the bottom
        # a branch hanging in from the top
        x, y = bx, -10
        ang = rng.uniform(0.3, 0.6)
        for _ in range(46):
            rect(img, x, y, x + 3, y + 3, c("45293f"))
            x += math.cos(ang) * 2.2
            y += math.sin(ang) * 1.6
            ang += rng.uniform(-0.06, 0.05)
            if rng.random() < 0.18:
                blob(img, x + rng.uniform(-6, 6), y + rng.uniform(0, 10), rng.uniform(6, 10), rng.uniform(5, 8), c("cf657f"))
                blob(img, x + rng.uniform(-4, 4), y + rng.uniform(-2, 6), rng.uniform(3, 6), rng.uniform(3, 5), c("ed8099"))
    # grass tufts at the bottom edge
    for x in range(0, w, 3):
        if rng.random() < 0.5:
            th = rng.randrange(6, 22)
            rect(img, x, H - th, x + 2, H, c("165a4c"))
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(1.6))
    save(np.array(im, float), "foreground.png", do_snap=False)


# --- light: sun shafts and a petal -------------------------------------------------

def shafts():
    w, h = 320, 180
    img = np.zeros((h, w, 4))
    rng = random.Random(5)
    for _ in range(7):
        x0 = rng.uniform(40, 300)
        wd = rng.uniform(8, 26)
        a = rng.uniform(0.25, 0.6)
        for y in range(h):
            fade = (1 - y / h) ** 1.2
            xc = x0 - y * 0.55
            for x in range(int(xc - wd), int(xc + wd)):
                if 0 <= x < w:
                    k = 1 - abs(x - xc) / wd
                    v = round(k * fade * a * 4) / 4
                    img[y, x, :3] = 255
                    img[y, x, 3] = max(img[y, x, 3], v * 120)
    Image.fromarray(img.astype(np.uint8), "RGBA").save(os.path.join(OUT, "shafts.png"))
    print("wrote shafts.png")
    p = np.zeros((3, 4, 4))
    p[0, 1:3] = list(c("fdcbb0")) + [255]
    p[1, 0:4] = list(c("ed8099")) + [255]
    p[2, 1:3] = list(c("cf657f")) + [255]
    Image.fromarray(p.astype(np.uint8), "RGBA").save(os.path.join(OUT, "petal.png"))
    print("wrote petal.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sky()
    far()
    mid()
    near()
    foreground()
    shafts()
