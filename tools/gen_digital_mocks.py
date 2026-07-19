#!/usr/bin/env python3
"""Mock up the two digital companions to First Light.

  A. DIGITAL  — clean: big time, date, three data fields (HR / steps / battery)
  B. SPORT    — Fenix-style data-rich: arc gauges (steps, battery), HR,
                body battery, floors, sunrise/sunset

Both reuse the carved-wave dial background, gold trident and lume tones so
they read as one family. Writes individual 454px faces plus a labeled
comparison sheet:  store/digital_mocks.png

    python3 tools/gen_digital_mocks.py
"""
import math
import os
import struct
import zlib

from gen_icons import Canvas, disc, thick_line, lerp
import gen_preview as gp
from gen_preview import (TOKENS, THEMES, DIAL_FILL, c_glob, paint_background,
                         draw_text, stroke_arc, fill_poly, downsample)

OUT = os.path.join(os.path.dirname(__file__), "..", "store")

# letters the dial never needed; format matches gen_preview.GLYPHS
gp.GLYPHS.setdefault("Y", ([[(0, 0), (0.5, 0.48)], [(1, 0), (0.5, 0.48)],
                            [(0.5, 0.48), (0.5, 1)]], 0.72))
gp.GLYPHS.setdefault("B", ([[(0, 0), (0, 1)],
                            [(0, 0), (0.6, 0), (0.78, 0.08), (0.82, 0.22),
                             (0.78, 0.38), (0.6, 0.46), (0, 0.46)],
                            [(0.6, 0.46), (0.82, 0.55), (0.88, 0.72),
                             (0.82, 0.9), (0.6, 1), (0, 1)]], 0.76))

LUME = (0xE8, 0xF4, 0xEE)          # big-digit near-white with lume tint
TEAL = (0x59, 0xB6, 0xA4)          # lume teal (matches AOD)
GOLD = (0xC8, 0xA0, 0x5A)          # trident gold
RED = (0xC8, 0x2A, 0x22)           # DIVER red
DIM = (0x9A, 0xA2, 0xA6)           # secondary text


# ---------------------------------------------------------------------------
# shared bits
# ---------------------------------------------------------------------------
def base(size, ss):
    S = size * ss
    cv = Canvas(S)
    c = S / 2.0
    R = (S / 2.0) * DIAL_FILL
    c_glob[0] = c
    T = dict(TOKENS)
    T.update(THEMES["black_ceramic"])
    paint_background(cv, R, T)
    return cv, c, R, T


def colon(cv, x, y, gap, r, col):
    disc(cv, x, y - gap, r, col)
    disc(cv, x, y + gap, r, col)


def big_time(cv, c, R, cy, h, col, hh="10", mm="08"):
    """HH:MM in fixed monospace slots with a hand-placed colon (no ':' glyph)."""
    halfw = 0.100 * h
    dw = 0.74 * h * 1.06           # digit slot width
    colw = 0.30 * h                # colon zone
    xs = [c - colw / 2 - 1.5 * dw, c - colw / 2 - 0.5 * dw,
          c + colw / 2 + 0.5 * dw, c + colw / 2 + 1.5 * dw]
    for x, ch in zip(xs, hh + mm):
        draw_text(cv, ch, x, cy, h, halfw, col)
    colon(cv, c, cy, h * 0.20, h * 0.060, col)


def heart(cv, x, y, s, col):
    disc(cv, x - s * 0.32, y - s * 0.18, s * 0.36, col)
    disc(cv, x + s * 0.32, y - s * 0.18, s * 0.36, col)
    fill_poly(cv, [(x - s * 0.62, y - 0.02 * s), (x + s * 0.62, y - 0.02 * s),
                   (x, y + s * 0.72)], col)


def battery_icon(cv, x, y, w, h, frac, col, case=DIM):
    hw = h * 0.10
    # case
    for (x0, y0, x1, y1) in [(x - w/2, y - h/2, x + w/2, y - h/2),
                             (x - w/2, y + h/2, x + w/2, y + h/2),
                             (x - w/2, y - h/2, x - w/2, y + h/2),
                             (x + w/2, y - h/2, x + w/2, y + h/2)]:
        thick_line(cv, x0, y0, x1, y1, hw, case)
    # nub
    thick_line(cv, x + w/2 + hw, y - h * 0.18, x + w/2 + hw, y + h * 0.18,
               hw * 1.4, case)
    # fill
    pad = hw * 2.2
    fw = (w - 2 * pad) * frac
    fill_poly(cv, [(x - w/2 + pad, y - h/2 + pad), (x - w/2 + pad + fw, y - h/2 + pad),
                   (x - w/2 + pad + fw, y + h/2 - pad), (x - w/2 + pad, y + h/2 - pad)],
              col)


def shoe(cv, x, y, s, col):
    """Minimal step icon: footprint = big pad + heel dot."""
    disc(cv, x - s * 0.10, y - s * 0.22, s * 0.34, col)
    disc(cv, x + s * 0.16, y + s * 0.30, s * 0.22, col)


def sun_icon(cv, x, y, s, col, rising=True):
    stroke_arc(cv, x, y, s * 0.5, s * 0.10, 270, 450, col, step=8)
    thick_line(cv, x - s * 0.85, y, x + s * 0.85, y, s * 0.09, col)
    # arrow
    dy = -s * 0.95 if rising else s * 0.15
    tip = y + dy + (-s * 0.28 if rising else s * 0.28)
    fill_poly(cv, [(x - s * 0.20, y + dy), (x + s * 0.20, y + dy), (x, tip)], col)


def stairs(cv, x, y, s, col):
    hw = s * 0.10
    pts = [(x - s * 0.6, y + s * 0.5), (x - s * 0.2, y + s * 0.5),
           (x - s * 0.2, y + s * 0.1), (x + s * 0.2, y + s * 0.1),
           (x + s * 0.2, y - s * 0.3), (x + s * 0.6, y - s * 0.3)]
    for i in range(len(pts) - 1):
        thick_line(cv, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], hw, col)


# ---------------------------------------------------------------------------
# Face A — DIGITAL (clean)
# ---------------------------------------------------------------------------
def face_digital(size, ss=3):
    cv, c, R, T = base(size, ss)

    # identity: trident + wordmark up top
    gp.draw_sunrise_emblem(cv, c, c - 0.480 * R, R, T)
    draw_text(cv, "FIRST LIGHT", c, c - 0.360 * R, 0.046 * R, 0.0048 * R,
              T["TEXT_OMEGA"], total_w=0.310 * R)

    # date
    draw_text(cv, "SUN 19", c, c - 0.245 * R, 0.052 * R, 0.0052 * R, GOLD,
              total_w=0.230 * R)

    # the time — huge
    big_time(cv, c, R, c + 0.005 * R, 0.340 * R, LUME)

    # seconds + am/pm flanking under the time
    draw_text(cv, "37", c + 0.265 * R, c + 0.225 * R, 0.070 * R, 0.0068 * R, TEAL)
    draw_text(cv, "AM", c - 0.265 * R, c + 0.225 * R, 0.048 * R, 0.0048 * R, DIM)

    # divider
    thick_line(cv, c - 0.30 * R, c + 0.315 * R, c + 0.30 * R, c + 0.315 * R,
               0.0018 * R, (0x3A, 0x40, 0x42))

    # three data fields: HR / steps / battery
    fy = c + 0.415 * R
    heart(cv, c - 0.300 * R, fy - 0.020 * R, 0.044 * R, RED)
    draw_text(cv, "72", c - 0.300 * R, fy + 0.062 * R, 0.050 * R, 0.0052 * R, LUME)
    shoe(cv, c - 0.008 * R, fy - 0.022 * R, 0.048 * R, TEAL)
    draw_text(cv, "8432", c - 0.005 * R, fy + 0.062 * R, 0.050 * R, 0.0052 * R, LUME)
    battery_icon(cv, c + 0.295 * R, fy - 0.020 * R, 0.080 * R, 0.040 * R, 0.85, GOLD)
    draw_text(cv, "85", c + 0.295 * R, fy + 0.062 * R, 0.050 * R, 0.0052 * R, LUME)

    return downsample(cv, size, ss)


# ---------------------------------------------------------------------------
# Face B — SPORT (Fenix-style data-rich)
# ---------------------------------------------------------------------------
def face_sport(size, ss=3):
    cv, c, R, T = base(size, ss)

    # top: small trident between weekday and battery %
    gp.draw_sunrise_emblem(cv, c, c - 0.560 * R, R, T)
    draw_text(cv, "SUN 19", c, c - 0.415 * R, 0.048 * R, 0.0048 * R, GOLD,
              total_w=0.210 * R)

    # arc gauges hugging the bezel: left = steps (teal), right = battery (gold)
    ga_r = 0.700 * R
    ga_w = 0.014 * R
    # steps: 62% of goal
    stroke_arc(cv, c, c, ga_r, ga_w, 210, 330, (0x2A, 0x32, 0x34), step=3)
    stroke_arc(cv, c, c, ga_r, ga_w, 330 - 120 * 0.62, 330, TEAL, step=3)
    shoe(cv, c - 0.590 * R, c + 0.005 * R, 0.042 * R, TEAL)
    # battery: 85%
    stroke_arc(cv, c, c, ga_r, ga_w, 30, 150, (0x2A, 0x32, 0x34), step=3)
    stroke_arc(cv, c, c, ga_r, ga_w, 30, 30 + 120 * 0.85, GOLD, step=3)
    battery_icon(cv, c + 0.585 * R, c + 0.002 * R, 0.062 * R, 0.032 * R, 0.85, GOLD)

    # the time — huge, slightly high (seconds tucked at its baseline)
    big_time(cv, c, R, c - 0.150 * R, 0.260 * R, LUME)
    draw_text(cv, "37", c + 0.545 * R, c - 0.075 * R, 0.055 * R, 0.0054 * R, TEAL)

    # heart rate front and center below time
    heart(cv, c - 0.150 * R, c + 0.078 * R, 0.042 * R, RED)
    draw_text(cv, "72", c + 0.015 * R, c + 0.085 * R, 0.078 * R, 0.0078 * R, LUME)
    draw_text(cv, "BPM", c + 0.160 * R, c + 0.098 * R, 0.036 * R, 0.0036 * R, DIM)

    # second data row: body battery + floors
    ry = c + 0.250 * R
    disc(cv, c - 0.235 * R, ry - 0.012 * R, 0.028 * R, TEAL)
    draw_text(cv, "68", c - 0.150 * R, ry, 0.058 * R, 0.0058 * R, LUME)
    stairs(cv, c + 0.095 * R, ry - 0.012 * R, 0.040 * R, GOLD)
    draw_text(cv, "12", c + 0.190 * R, ry, 0.058 * R, 0.0058 * R, LUME)

    # bottom: sunrise / sunset
    by = c + 0.425 * R
    sun_icon(cv, c - 0.215 * R, by, 0.042 * R, GOLD, rising=True)
    draw_text(cv, "6-12", c - 0.100 * R, by, 0.044 * R, 0.0044 * R, DIM)
    sun_icon(cv, c + 0.085 * R, by, 0.042 * R, (0xB0, 0x7A, 0x4A), rising=False)
    draw_text(cv, "8-45", c + 0.200 * R, by, 0.044 * R, 0.0044 * R, DIM)

    return downsample(cv, size, ss)


# ---------------------------------------------------------------------------
# output
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
        cdat = t + d
        return struct.pack(">I", len(d)) + cdat + struct.pack(">I", zlib.crc32(cdat) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def write_face(img, name):
    from gen_icons import write_png
    path = os.path.join(OUT, "screenshots", name)
    write_png(img, path)
    print("wrote store/screenshots/%s" % name)


def main():
    FACE = 420
    a = face_digital(FACE)
    b = face_sport(FACE)
    write_face(face_digital(454), "face_digital.png")
    write_face(face_sport(454), "face_sport.png")

    PAD = 24
    LABEL_H = 44
    W = 2 * FACE + 3 * PAD
    H = FACE + LABEL_H + 2 * PAD + 50
    S = max(W, H)
    cv = Canvas(S)
    for y in range(H):
        for x in range(W):
            cv.px[y * S + x] = [0x12, 0x12, 0x14, 255]
    draw_text(cv, "FIRST LIGHT - DIGITAL FAMILY", W // 2, 30, 24, 2.0,
              (0xEA, 0xEA, 0xEC), total_w=520)
    blit(cv, a, PAD, 50 + PAD)
    blit(cv, b, 2 * PAD + FACE, 50 + PAD)
    draw_text(cv, "DIGITAL", PAD + FACE // 2, 50 + PAD + FACE + 24, 20, 1.6,
              (0xC8, 0xC8, 0xCC))
    draw_text(cv, "SPORT", 2 * PAD + FACE + FACE // 2, 50 + PAD + FACE + 24,
              20, 1.6, (0xC8, 0xC8, 0xCC))
    path = os.path.join(OUT, "digital_mocks.png")
    write_png_rect(cv, W, H, path)
    print("wrote store/digital_mocks.png (%dx%d, %d KB)"
          % (W, H, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
