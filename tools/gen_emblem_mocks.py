#!/usr/bin/env python3
"""Mock up candidate dial emblems on the real face renderer.

Renders the Fenix face six times, each with a different central emblem
monkey-patched in, and composes them into one labeled comparison sheet:
    store/emblem_mocks.png

Pure stdlib. Run from the repo root:
    python3 tools/gen_emblem_mocks.py
"""
import math
import os
import struct
import zlib

from gen_icons import Canvas, disc, thick_line, lerp
import gen_preview as gp
from gen_preview import (THEMES, render_face, stroke_arc, fill_poly,
                         stroke_poly, draw_text)

OUT = os.path.join(os.path.dirname(__file__), "..", "store")


# ---------------------------------------------------------------------------
# emblem candidates  —  signature (cv, cx, cy, R, T)
# ---------------------------------------------------------------------------
def em_sunrise(cv, cx, cy, R, T):
    """First-light sun cresting the horizon with rays. Ties to the app name."""
    col = T["BRONZE_RING"]
    hw = 0.0045 * R
    r = 0.030 * R
    hy = cy + r * 0.55                       # horizon line y
    # sun half-disc above the horizon
    stroke_arc(cv, cx, hy, r, hw, 270, 450, col, step=5)
    # horizon
    thick_line(cv, cx - 0.058 * R, hy, cx + 0.058 * R, hy, hw, col)
    # rays
    for a in (-58, -32, 0, 32, 58):
        rad = math.radians(a)
        x0 = cx + math.sin(rad) * r * 1.5
        y0 = hy - math.cos(rad) * r * 1.5
        x1 = cx + math.sin(rad) * r * 2.35
        y1 = hy - math.cos(rad) * r * 2.35
        thick_line(cv, x0, y0, x1, y1, hw * 0.85, col)


def em_wave(cv, cx, cy, R, T):
    """A single carved wave crest — echoes the guilloche dial."""
    col = T["TEXT_OMEGA_S"]
    hw = 0.0050 * R
    w = 0.085 * R
    amp = 0.020 * R
    pts = []
    n = 40
    for i in range(n + 1):
        t = i / n
        x = cx + (t - 0.5) * w
        y = cy - amp * math.sin(t * math.pi * 2.0)
        pts.append((x, y))
    for i in range(len(pts) - 1):
        thick_line(cv, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], hw, col)
    # a small foam curl at the crest
    stroke_arc(cv, cx - w * 0.25, cy - amp * 0.9, 0.012 * R, hw * 0.8,
               120, 340, col, step=6)


def em_trident(cv, cx, cy, R, T):
    """Neptune's trident — classic dive-watch motif, unowned."""
    col = T["TEXT_OMEGA_S"]
    hw = 0.0048 * R
    top = cy - 0.048 * R
    bot = cy + 0.048 * R
    sp = 0.026 * R                            # tine spacing
    tine_top = top + 0.010 * R
    # shaft
    thick_line(cv, cx, top + 0.004 * R, cx, bot, hw, col)
    # crossbar
    thick_line(cv, cx - sp, top + 0.028 * R, cx + sp, top + 0.028 * R, hw, col)
    # centre tine (point)
    thick_line(cv, cx, top - 0.006 * R, cx, tine_top, hw, col)
    disc(cv, cx, top - 0.010 * R, hw * 1.3, col)
    # side tines (curved outward, barbed)
    for s in (-1, 1):
        stroke_arc(cv, cx + s * sp, top + 0.030 * R, sp, hw,
                   90 if s > 0 else 270, 180 if s > 0 else 360, col, step=6)
        thick_line(cv, cx + s * sp * 2, top + 0.030 * R,
                   cx + s * sp * 2, top - 0.002 * R, hw, col)
        disc(cv, cx + s * sp * 2, top - 0.006 * R, hw * 1.2, col)
    # base ball
    disc(cv, cx, bot + 0.003 * R, hw * 1.6, col)


def em_compass(cv, cx, cy, R, T):
    """8-point compass rose — navigation/explorer feel."""
    col = T["TEXT_OMEGA_S"]
    bronze = T["BRONZE_RING"]
    ro = 0.052 * R                            # long point radius
    ri = 0.016 * R                            # waist radius
    rs = 0.030 * R                            # short (diagonal) point
    def star(rad_long, color, a=1.0):
        pts = []
        for k in range(8):
            ang = math.radians(k * 45.0)
            rr = rad_long if k % 2 == 0 else ri
            pts.append((cx + rr * math.sin(ang), cy - rr * math.cos(ang)))
        fill_poly(cv, pts, color, a)
    # bronze diagonal star behind
    dpts = []
    for k in range(8):
        ang = math.radians(k * 45.0 + 45.0)
        rr = rs if k % 2 == 0 else ri * 0.8
        dpts.append((cx + rr * math.sin(ang), cy - rr * math.cos(ang)))
    fill_poly(cv, dpts, bronze, 0.9)
    star(ro, col)
    disc(cv, cx, cy, 0.006 * R, bronze)


def em_anchor(cv, cx, cy, R, T):
    """Fouled anchor — nautical, generic maritime symbol."""
    col = T["TEXT_OMEGA_S"]
    hw = 0.0048 * R
    top = cy - 0.050 * R
    bot = cy + 0.044 * R
    # ring at top
    stroke_arc(cv, cx, top, 0.012 * R, hw, 0, 360, col, step=8)
    # shank
    thick_line(cv, cx, top + 0.012 * R, cx, bot, hw, col)
    # stock (crossbar)
    thick_line(cv, cx - 0.030 * R, top + 0.026 * R,
               cx + 0.030 * R, top + 0.026 * R, hw, col)
    # arms (curved flukes)
    w = 0.050 * R
    stroke_arc(cv, cx, bot - 0.006 * R, w, hw, 250, 290, col, step=4)
    for s in (-1, 1):
        # fluke tips
        bx = cx + s * w * 0.95
        by = bot - 0.006 * R + w * 0.34
        thick_line(cv, bx, by, cx + s * (w * 0.72), by - 0.020 * R, hw, col)


def em_northstar(cv, cx, cy, R, T):
    """4-point sparkle/north star — minimalist tool-watch mark."""
    col = T["TEXT_OMEGA_S"]
    ro = 0.055 * R
    ri = 0.012 * R
    pts = []
    for k in range(8):
        ang = math.radians(k * 45.0)
        rr = ro if k % 2 == 0 else ri
        pts.append((cx + rr * math.sin(ang), cy - rr * math.cos(ang)))
    fill_poly(cv, pts, col)
    disc(cv, cx, cy, 0.010 * R, T["BRONZE_RING"])


CANDIDATES = [
    ("SUNRISE - FIRST LIGHT", em_sunrise),
    ("WAVE CREST", em_wave),
    ("TRIDENT", em_trident),
    ("COMPASS ROSE", em_compass),
    ("FOULED ANCHOR", em_anchor),
    ("NORTH STAR", em_northstar),
]


# ---------------------------------------------------------------------------
# compose sheet
# ---------------------------------------------------------------------------
def blit(dst, src, ox, oy):
    for y in range(src.s):
        row = y * src.s
        for x in range(src.s):
            p = src.px[row + x]
            if p[3] > 0:
                dst.blend(ox + x, oy + y, (p[0], p[1], p[2]), p[3] / 255.0)


def write_png_rect(cv, W, H, path):
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        row = y * cv.s
        for x in range(W):
            p = cv.px[row + x]
            raw += bytes((p[0], p[1], p[2], 255))
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def main():
    FACE = 300
    COLS, ROWS = 3, 2
    PAD = 24
    LABEL_H = 40
    CELL_W = FACE + PAD
    CELL_H = FACE + LABEL_H
    W = COLS * CELL_W + PAD
    H = ROWS * CELL_H + PAD + 60
    S = max(W, H)                             # Canvas is square
    cv = Canvas(S)
    # dark backdrop
    for y in range(H):
        for x in range(W):
            cv.px[y * S + x] = [0x12, 0x12, 0x14, 255]
    # header
    draw_text(cv, "EMBLEM OPTIONS", W // 2, 30, 26, 2.2, (0xEA, 0xEA, 0xEC),
              total_w=360)

    theme = THEMES["black_ceramic"]
    for idx, (name, fn) in enumerate(CANDIDATES):
        gp.draw_sunrise_emblem = fn           # monkey-patch the emblem call
        face = render_face(FACE, theme, ss=2)
        r, cpos = divmod(idx, COLS)
        ox = PAD + cpos * CELL_W
        oy = 60 + PAD + r * CELL_H
        blit(cv, face, ox, oy)
        draw_text(cv, name, ox + FACE // 2, oy + FACE + 20, 18, 1.4,
                  (0xC8, 0xC8, 0xCC), total_w=FACE - 20)
        print("rendered", name)

    path = os.path.join(OUT, "emblem_mocks.png")
    write_png_rect(cv, W, H, path)
    kb = os.path.getsize(path) // 1024
    print("wrote store/emblem_mocks.png (%dx%d, %d KB)" % (W, H, kb))


if __name__ == "__main__":
    main()
