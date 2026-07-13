#!/usr/bin/env python3
"""Render full-resolution (454x454) face mockups for the store listing / README.

Pure standard library -- reuses the low-level raster primitives from
gen_icons.py.  These are *design mockups* of the "007 First Light" Seamaster
Diver 300M Chronograph tribute face; every constant below mirrors
specs/001-bond-seamaster-007-first-light/fidelity-v2.md and must stay in
lockstep with Geometry.mc / Theme.mc / DialRenderer.mc (parity rule, spec S5).

    python3 tools/gen_preview.py [--ss=N] [theme ...]

ss defaults to 3 (supersampling). Pass a theme name (black_ceramic, dawn,
red_accent) to render just that one while iterating.
"""
import math
import os
import sys

from gen_icons import Canvas, disc, ring, thick_line, write_png, lerp

OUT = os.path.join(os.path.dirname(__file__), "..", "store", "screenshots")

# ---------------------------------------------------------------------------
# 1. Color tokens (fidelity-v2.md section 1)
# ---------------------------------------------------------------------------
TOKENS = {
    "CERAMIC_BASE": (0x0A, 0x0A, 0x0B),
    "WAVE_RIDGE":   (0x0D, 0x0D, 0x10),
    "WAVE_HI":      (0x68, 0x68, 0x6C),
    "WAVE_HI2":     (0x84, 0x84, 0x88),   # upper-left gloss zone crest
    "WAVE_GROOVE":  (0x02, 0x02, 0x03),
    "BEZEL_BLACK":  (0x06, 0x06, 0x08),
    "BEZEL_SHEEN1": (0x1E, 0x20, 0x23),
    "BEZEL_SHEEN2": (0x2E, 0x30, 0x33),
    "REHAUT":       (0x0A, 0x0B, 0x0D),
    "REHAUT_LINE":  (0x26, 0x28, 0x2B),
    "ENAMEL_WHITE": (0xF2, 0xF3, 0xF5),
    "BEZEL_DOT":    (0xF6, 0xF6, 0xF6),
    "FLANGE_WHITE": (0xE6, 0xE7, 0xE9),
    "STEEL_HI":     (0xE0, 0xE0, 0xE4),
    "STEEL_MID":    (0xAA, 0xB0, 0xB6),
    "STEEL_LO":     (0x55, 0x58, 0x5C),
    "MARKER_RIM":   (0xDF, 0xE3, 0xE7),
    "MARKER_SHADOW":(0x2B, 0x2D, 0x30),
    "BRONZE_HI":    (0xE3, 0xC4, 0xAF),
    "BRONZE_MID":   (0xC4, 0x9B, 0x7E),
    "BRONZE_LO":    (0x7E, 0x5B, 0x44),
    "BRONZE_RING":  (0xC8, 0x9E, 0x82),
    "BRONZE_RING_S":(0xA8, 0x81, 0x5F),   # south-edge shade of the ring
    "RING_PRINT":   (0x24, 0x1A, 0x12),
    "LUME_WHITE":   (0xF6, 0xF7, 0xF8),
    "LUME_HOT":     (0xFE, 0xFF, 0xFF),
    "LUME_HAND":    (0xF4, 0xF6, 0xF4),
    "LUME_LOLLI":   (0xFF, 0xFF, 0xFD),
    "LUME_PEARL":   (0xEB, 0xEA, 0xE8),
    "PEARL_RIM":    (0x9A, 0x9C, 0x9E),
    "RED_SCRIPT":   (0x8C, 0x20, 0x40),
    "TEXT_OMEGA_S": (0xE8, 0xE8, 0xE8),
    "TEXT_OMEGA":   (0xE6, 0xE6, 0xE6),
    "TEXT_PROF":    (0xD8, 0xD8, 0xD8),
    "TEXT_MID":     (0xD5, 0xD5, 0xD5),
    "TEXT_DIM":     (0x90, 0x90, 0x92),
    "ZRO2_GRAY":    (0x42, 0x42, 0x44),
    "DATE_FRAME":   (0x14, 0x14, 0x16),
    "DATE_SPEC":    (0x2A, 0x2A, 0x2C),
    "DATE_APERTURE":(0x0B, 0x0B, 0x0C),
    "DATE_NUMERAL": (0xC9, 0xC9, 0xCA),
    "SUB_FLANGE":   (0x28, 0x28, 0x2A),
    "SNAIL_BASE":   (0x0D, 0x0D, 0x0D),
    "SNAIL_GROOVE": (0x24, 0x24, 0x26),
    "SUB_PRINT":    (0xE8, 0xEA, 0xEA),
    "HUB_SLOT":     (0x5A, 0x44, 0x36),
    "WHITE":        (0xFF, 0xFF, 0xFF),
}

THEMES = {
    "black_ceramic": {},
    "dawn": {
        "CERAMIC_BASE": (0x0C, 0x09, 0x06),
        "WAVE_RIDGE":   (0x14, 0x0F, 0x0A),
        "WAVE_HI":      (0x4E, 0x40, 0x2E),
        "WAVE_HI2":     (0x60, 0x50, 0x3A),
        "WAVE_GROOVE":  (0x03, 0x02, 0x01),
        "BEZEL_BLACK":  (0x08, 0x06, 0x05),
        "BEZEL_SHEEN1": (0x24, 0x1E, 0x18),
        "BEZEL_SHEEN2": (0x36, 0x2E, 0x24),
        "SNAIL_BASE":   (0x10, 0x0C, 0x08),
        "SNAIL_GROOVE": (0x2A, 0x22, 0x18),
        "SUB_FLANGE":   (0x2C, 0x26, 0x1E),
    },
    "red_accent": {
        "BRONZE_HI":    (0xFF, 0x6A, 0x5E),
        "BRONZE_MID":   (0xE4, 0x26, 0x1B),
        "BRONZE_LO":    (0x7E, 0x16, 0x10),
        "BRONZE_RING":  (0xC8, 0x2A, 0x22),
        "BRONZE_RING_S":(0x9A, 0x1E, 0x18),
        "RING_PRINT":   (0x28, 0x06, 0x05),
        "HUB_SLOT":     (0x6E, 0x12, 0x0E),
    },
}

# ---------------------------------------------------------------------------
# 2. Geometry tokens (fidelity-v2.md section 2) -- fractions of face radius R
# ---------------------------------------------------------------------------
BEZEL_INNER   = 0.775
REHAUT_IN     = 0.755
DIAL_R        = 0.755
DIAL_FILL     = 1.28   # match Geometry.mc: dial fills screen, no drawn bezel

BZ_NUM_R      = 0.875   # bezel numeral center radius
BZ_NUM_CAP    = 0.170   # numeral cap height
BZ_NUM_STROKE = 0.033
BZ_NUM_SPAN   = 0.1985  # digit pair tangential width (13 deg at r 0.875)
BZ_NUM_GAP    = 0.040
BZ_DOT_R      = 0.810
BZ_DOT_D      = 0.024
BZ_BATON_W    = 0.030
BZ_BATON_R0   = 0.795
BZ_BATON_R1   = 0.965
BZ_TICK_W     = 0.011
BZ_TICK_L     = 0.027
TRI_BASE_R    = 0.955
TRI_HALF_W    = 0.125
TRI_APEX_R    = 0.800
TRI_STROKE    = 0.020
PEARL_R       = 0.900
PEARL_D       = 0.071

MT_TICK_R0    = 0.705
MT_TICK_R1    = 0.755
MT_HALF_R0    = 0.725
MT_TICK_W     = 0.009
MT_DOT_R      = 0.765
MT_DOT_D      = 0.007
MT_GAP_DEG    = 18.0    # suppressed around 180

DOT_HOUR_R    = 0.590
DOT_SHADOW_D  = 0.132
DOT_RIM_D     = 0.124
DOT_LUME_D    = 0.104

BAR12_W       = 0.076
BAR12_GAP     = 0.022
BAR12_R0      = 0.458
BAR12_R1      = 0.640
BAR12_CR      = 0.012

PLOT39_W      = 0.066   # tangential
PLOT39_H      = 0.046   # radial
PLOT39_R      = 0.660
PLOT6_W       = 0.085
PLOT6_H       = 0.050
PLOT6_R       = 0.667

SUB_OFFSET    = 0.415
SUB_R         = 0.150
SUB_SNAIL_R   = 0.095
BRONZE_OUT    = 0.146

DATE_CY       = 0.531
DATE_W        = 0.174
DATE_H        = 0.160
DATE_CR       = 0.024
DATE_NUM_H    = 0.120

HOUR_LEN      = 0.440
MIN_LEN       = 0.680
SEC_LEN       = 0.730
SEC_TAIL      = 0.270


# ---------------------------------------------------------------------------
# extra raster primitives (kept here; gen_icons.py is not modified)
# ---------------------------------------------------------------------------
def fill_poly(cv, pts, color, a=1.0):
    """Even-odd scanline polygon fill (relies on supersampling for AA)."""
    ys = [p[1] for p in pts]
    y0 = max(0, int(math.floor(min(ys))))
    y1 = min(cv.s - 1, int(math.ceil(max(ys))))
    n = len(pts)
    for y in range(y0, y1 + 1):
        yc = y + 0.5
        xs = []
        for i in range(n):
            xa, ya = pts[i]
            xb, yb = pts[(i + 1) % n]
            if (ya <= yc < yb) or (yb <= yc < ya):
                t = (yc - ya) / (yb - ya)
                xs.append(xa + t * (xb - xa))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            xs0 = int(math.ceil(xs[k] - 0.5))
            xs1 = int(math.floor(xs[k + 1] - 0.5))
            for x in range(xs0, xs1 + 1):
                cv.blend(x, y, color, a)


def stroke_poly(cv, pts, halfw, color, a=1.0, close=True):
    n = len(pts)
    rng = range(n) if close else range(n - 1)
    for i in rng:
        xa, ya = pts[i]
        xb, yb = pts[(i + 1) % n]
        thick_line(cv, xa, ya, xb, yb, halfw, color, a)


def stroke_arc(cv, cx, cy, r, halfw, a0, a1, color, a=1.0, step=4.0):
    """Arc stroked with segments; angles in degrees clockwise from 12."""
    prev = None
    ang = a0
    while True:
        rad = math.radians(ang)
        p = (cx + r * math.sin(rad), cy - r * math.cos(rad))
        if prev is not None:
            thick_line(cv, prev[0], prev[1], p[0], p[1], halfw, color, a)
        prev = p
        if ang >= a1:
            break
        ang = min(a1, ang + step)


def rrect_pts(cx, cy, w, h, rad):
    """Rounded-rect polygon (clockwise), axis aligned."""
    rad = min(rad, w / 2.0, h / 2.0)
    pts = []
    for sx, sy, a0 in ((1, -1, 0), (1, 1, 90), (-1, 1, 180), (-1, -1, 270)):
        ccx = cx + sx * (w / 2.0 - rad)
        ccy = cy + sy * (h / 2.0 - rad)
        for i in range(7):
            a = math.radians(a0 + i * 15)
            pts.append((ccx + rad * math.sin(a), ccy - rad * math.cos(a)))
    return pts


def pt(c, R, r_frac, ang_deg):
    a = math.radians(ang_deg)
    return c + R * r_frac * math.sin(a), c - R * r_frac * math.cos(a)


def rad_rect(cv, c, R, ang_deg, r0, r1, width, color, a=1.0):
    """Radial rectangle (squared ends): from r0 to r1 along ang, given width."""
    rad = math.radians(ang_deg)
    dx, dy = math.sin(rad), -math.cos(rad)
    px, py = math.cos(rad), math.sin(rad)
    hw = width * R / 2.0
    p0 = (c + dx * r0 * R, c + dy * r0 * R)
    p1 = (c + dx * r1 * R, c + dy * r1 * R)
    fill_poly(cv, [
        (p0[0] - px * hw, p0[1] - py * hw),
        (p1[0] - px * hw, p1[1] - py * hw),
        (p1[0] + px * hw, p1[1] + py * hw),
        (p0[0] + px * hw, p0[1] + py * hw),
    ], color, a)


# ---------------------------------------------------------------------------
# stroke-font glyph tables (shared path data; transcribe into DialRenderer.mc)
# glyph space: x in [0,1] of its own advance box, y in [0,1] top->baseline
# ---------------------------------------------------------------------------
GLYPHS = {
    "0": ([[(0.32, 0), (0.68, 0), (0.95, 0.18), (1, 0.5), (0.95, 0.82),
            (0.68, 1), (0.32, 1), (0.05, 0.82), (0, 0.5), (0.05, 0.18),
            (0.32, 0)]], 0.76),
    "1": ([[(0.12, 0.20), (0.52, 0), (0.52, 1)]], 0.46),
    "2": ([[(0.03, 0.20), (0.30, 0), (0.70, 0), (0.97, 0.20), (0.97, 0.40),
            (0.03, 1), (1, 1)]], 0.72),
    "3": ([[(0.05, 0.02), (0.95, 0.02), (0.50, 0.40), (0.75, 0.42),
            (0.97, 0.60), (0.97, 0.80), (0.70, 1), (0.28, 1),
            (0.03, 0.84)]], 0.72),
    "4": ([[(0.72, 0), (0.02, 0.70), (1, 0.70)], [(0.72, 0), (0.72, 1)]], 0.76),
    "5": ([[(0.92, 0), (0.14, 0), (0.08, 0.44), (0.55, 0.38), (0.92, 0.55),
            (0.95, 0.78), (0.68, 1), (0.26, 1), (0.03, 0.86)]], 0.72),
    "6": ([[(0.82, 0.06), (0.50, 0), (0.16, 0.18), (0.03, 0.50), (0.05, 0.78),
            (0.30, 1), (0.66, 1), (0.94, 0.80), (0.94, 0.60), (0.66, 0.44),
            (0.30, 0.47), (0.05, 0.62)]], 0.74),
    "7": ([[(0.03, 0), (0.97, 0), (0.42, 1)]], 0.64),
    "8": ([[(0.50, 0.46), (0.22, 0.32), (0.22, 0.12), (0.40, 0), (0.60, 0),
            (0.78, 0.12), (0.78, 0.32), (0.50, 0.46), (0.16, 0.62),
            (0.16, 0.86), (0.36, 1), (0.64, 1), (0.84, 0.86), (0.84, 0.62),
            (0.50, 0.46)]], 0.74),
    "9": ([[(0.18, 0.94), (0.50, 1), (0.84, 0.82), (0.97, 0.50), (0.95, 0.22),
            (0.70, 0), (0.34, 0), (0.06, 0.20), (0.06, 0.40), (0.34, 0.56),
            (0.70, 0.53), (0.95, 0.38)]], 0.74),
    "A": ([[(0, 1), (0.5, 0), (1, 1)], [(0.18, 0.64), (0.82, 0.64)]], 0.74),
    "C": ([[(1, 0.18), (0.72, 0), (0.28, 0), (0, 0.22), (0, 0.78), (0.28, 1),
            (0.72, 1), (1, 0.82)]], 0.70),
    "D": ([[(0, 0), (0, 1), (0.55, 1), (0.95, 0.75), (0.95, 0.25), (0.55, 0),
            (0, 0)]], 0.74),
    "E": ([[(0.95, 0), (0, 0), (0, 1), (0.95, 1)], [(0, 0.5), (0.80, 0.5)]], 0.62),
    "F": ([[(0.95, 0), (0, 0), (0, 1)], [(0, 0.5), (0.75, 0.5)]], 0.58),
    "G": ([[(1, 0.18), (0.72, 0), (0.28, 0), (0, 0.22), (0, 0.78), (0.28, 1),
            (0.72, 1), (1, 0.80), (1, 0.52), (0.55, 0.52)]], 0.74),
    "H": ([[(0, 0), (0, 1)], [(1, 0), (1, 1)], [(0, 0.5), (1, 0.5)]], 0.70),
    "I": ([[(0.5, 0), (0.5, 1)]], 0.30),
    "L": ([[(0, 0), (0, 1), (0.95, 1)]], 0.58),
    "M": ([[(0, 1), (0.04, 0), (0.50, 0.72), (0.96, 0), (1, 1)]], 0.86),
    "N": ([[(0, 1), (0.02, 0), (0.98, 1), (1, 0)]], 0.74),
    "O": ([[(0.30, 0), (0.70, 0), (1, 0.25), (1, 0.75), (0.70, 1), (0.30, 1),
            (0, 0.75), (0, 0.25), (0.30, 0)]], 0.78),
    "P": ([[(0, 1), (0, 0), (0.68, 0), (0.96, 0.14), (0.96, 0.40),
            (0.68, 0.54), (0, 0.54)]], 0.64),
    "R": ([[(0, 1), (0, 0), (0.68, 0), (0.96, 0.14), (0.96, 0.40),
            (0.68, 0.54), (0, 0.54)], [(0.52, 0.54), (0.98, 1)]], 0.66),
    "S": ([[(0.95, 0.16), (0.68, 0), (0.30, 0), (0.04, 0.16), (0.04, 0.36),
            (0.30, 0.50), (0.70, 0.50), (0.96, 0.64), (0.96, 0.84), (0.70, 1),
            (0.30, 1), (0.05, 0.84)]], 0.64),
    "T": ([[(0, 0), (1, 0)], [(0.5, 0), (0.5, 1)]], 0.62),
    "W": ([[(0, 0), (0.22, 1), (0.50, 0.30), (0.78, 1), (1, 0)]], 0.92),
    "X": ([[(0, 0), (1, 1)], [(1, 0), (0, 1)]], 0.66),
    "Z": ([[(0, 0), (1, 0), (0, 1), (1, 1)]], 0.64),
    "V": ([[(0, 0), (0.5, 1), (1, 0)]], 0.74),
    "U": ([[(0, 0), (0, 0.72), (0.16, 0.94), (0.5, 1), (0.84, 0.94), (1, 0.72), (1, 0)]], 0.74),
    "B": ([[(0, 0), (0, 1)], [(0, 0), (0.6, 0), (0.82, 0.14), (0.82, 0.32), (0.6, 0.46), (0, 0.46)], [(0.6, 0.46), (0.88, 0.60), (0.88, 0.84), (0.6, 1), (0, 1)]], 0.72),
    "-": ([[(0.12, 0.5), (0.88, 0.5)]], 0.50),
    "/": ([[(0.85, 0), (0.15, 1)]], 0.50),
    "[": ([[(0.85, 0), (0.30, 0), (0.30, 1), (0.85, 1)]], 0.42),
    "]": ([[(0.15, 0), (0.70, 0), (0.70, 1), (0.15, 1)]], 0.42),
    # lowercase (x-height forms occupying the lower band of the cap box)
    "m": ([[(0.04, 1), (0.04, 0.34)],
           [(0.04, 0.50), (0.20, 0.34), (0.35, 0.50), (0.35, 1)],
           [(0.35, 0.50), (0.51, 0.34), (0.66, 0.50), (0.66, 1)]], 0.84),
    "f": ([[(0.80, 0.10), (0.58, 0), (0.40, 0.14), (0.40, 1)],
           [(0.12, 0.34), (0.72, 0.34)]], 0.52),
    "t": ([[(0.38, 0.06), (0.38, 0.85), (0.52, 1), (0.74, 0.92)],
           [(0.10, 0.32), (0.72, 0.32)]], 0.52),
    "r": ([[(0.15, 1), (0.15, 0.36)],
           [(0.15, 0.56), (0.40, 0.36), (0.62, 0.46)]], 0.50),
}

# connected-cursive approximations for the red "Seamaster" script
# y: 0 = ascender top, ~0.42..1 = x-height band, 1 = baseline
SCRIPT = {
    "S": ([[(0.92, 0.10), (0.60, 0), (0.22, 0.06), (0.08, 0.26), (0.22, 0.44),
            (0.60, 0.55), (0.78, 0.72), (0.66, 0.92), (0.34, 1),
            (0.04, 0.90)]], 0.66),
    "e": ([[(0.12, 0.72), (0.68, 0.62), (0.60, 0.44), (0.30, 0.42),
            (0.08, 0.62), (0.10, 0.88), (0.36, 1), (0.74, 0.94)]], 0.55),
    "a": ([[(0.62, 0.52), (0.32, 0.42), (0.08, 0.62), (0.10, 0.90), (0.34, 1),
            (0.58, 0.90), (0.66, 0.48)],
           [(0.66, 0.48), (0.64, 0.92), (0.80, 1)]], 0.60),
    "m": ([[(0.02, 1), (0.08, 0.44)],
           [(0.08, 0.58), (0.22, 0.42), (0.32, 0.56), (0.32, 1)],
           [(0.32, 0.56), (0.46, 0.42), (0.58, 0.56), (0.58, 1)]], 0.72),
    "s": ([[(0.60, 0.50), (0.32, 0.42), (0.16, 0.56), (0.36, 0.70),
            (0.54, 0.82), (0.40, 0.98), (0.10, 0.94)]], 0.48),
    "t": ([[(0.42, 0.06), (0.32, 0.85), (0.44, 1), (0.66, 0.90)],
           [(0.10, 0.44), (0.64, 0.44)]], 0.48),
    "r": ([[(0.04, 1), (0.12, 0.44)],
           [(0.12, 0.60), (0.32, 0.42), (0.52, 0.50), (0.60, 0.70),
            (0.72, 0.78)]], 0.56),
}


def draw_glyph(cv, ch, cx, cy, h, halfw, color, rot_deg=0.0, font=None,
               shear=0.0, wf=1.0, a=1.0):
    """Draw one glyph centered on (cx, cy). rot is clockwise; glyph 'up'
    points radially outward when rot equals the placement angle."""
    font = font or GLYPHS
    if ch == " ":
        return
    strokes, adv = font[ch]
    cr = math.cos(math.radians(rot_deg))
    sr = math.sin(math.radians(rot_deg))
    for st in strokes:
        tp = []
        for (px, py) in st:
            x = (px - 0.5) * adv * h * wf + shear * (0.5 - py) * h
            y = (py - 0.5) * h
            tp.append((cx + x * cr - y * sr, cy + x * sr + y * cr))
        for i in range(len(tp) - 1):
            thick_line(cv, tp[i][0], tp[i][1], tp[i + 1][0], tp[i + 1][1],
                       halfw, color, a)


def glyph_adv(ch, font=None):
    font = font or GLYPHS
    if ch == " ":
        return 0.60
    return font[ch][1]


def measure_text(s, h, track, font=None):
    w = 0.0
    for ch in s:
        w += glyph_adv(ch, font) * h + track
    return w - track if s else 0.0


def draw_text(cv, s, cx, cy, h, halfw, color, total_w=None, track=None,
              font=None, shear=0.0, wf=1.0, a=1.0):
    """cy is the vertical center of the cap box. wf condenses glyphs."""
    if track is None:
        track = 0.14 * h
    if total_w is not None and len(s) > 1:
        base = measure_text(s, h, 0.0, font) * wf
        track = (total_w - base) / (len(s) - 1)
    x = cx - (measure_text(s, h, 0.0, font) * wf + track * (len(s) - 1)) / 2.0
    for ch in s:
        aw = glyph_adv(ch, font) * h * wf
        draw_glyph(cv, ch, x + aw / 2.0, cy, h, halfw, color, 0.0, font,
                   shear, wf, a)
        x += aw + track


def draw_arc_text(cv, s, c, R, r_frac, center_ang, h, halfw, color,
                  track=None):
    """Text along an arc near 6 o'clock, letters upright (tops toward
    center). center_ang in degrees cw from 12; reads left-to-right on
    screen, i.e. from larger angle to smaller."""
    if track is None:
        track = 0.22 * h
    widths = [glyph_adv(ch) * h + track for ch in s]
    total = sum(widths) - track
    r = r_frac * R
    ang = center_ang + math.degrees(total / 2.0 / r)
    for i, ch in enumerate(s):
        aw = widths[i] - track
        ang -= math.degrees(aw / 2.0 / r)
        x, y = pt(c_glob[0], R, r_frac, ang)
        draw_glyph(cv, ch, x, y, h, halfw, color, rot_deg=ang - 180.0)
        ang -= math.degrees((aw / 2.0 + track) / r)


c_glob = [0.0]  # set per render (draw_arc_text needs the canvas center)


# ---------------------------------------------------------------------------
# background: bezel + rehaut + carved wave dial in one per-pixel pass
# ---------------------------------------------------------------------------
def paint_background(cv, R, T):
    S = cv.s
    c = S / 2.0
    P = 0.100 * R          # finer wave pitch (~14 carved waves across)
    A = 0.058 * R          # undulation amplitude
    KX = 2 * math.pi / (0.820 * R)
    ridge = T["WAVE_RIDGE"]; hi = T["WAVE_HI"]; hi2 = T["WAVE_HI2"]
    gro = T["WAVE_GROOVE"]
    bez = T["BEZEL_BLACK"]; sh1 = T["BEZEL_SHEEN1"]; sh2 = T["BEZEL_SHEEN2"]
    reh = T["REHAUT"]; rehl = T["REHAUT_LINE"]
    sin = math.sin
    sqrt = math.sqrt
    TWO_PI = 2 * math.pi
    px = cv.px
    hairline = 1.6  # px width of rehaut hairline at the bezel inner edge
    for y in range(S):
        dy = y + 0.5 - c
        if abs(dy) >= R:
            continue
        half = sqrt(R * R - dy * dy)
        ph = 1.15 * sin(dy / (R * 0.33)) + 0.35 * sin(dy / (R * 0.11))
        x0 = int(c - half)
        x1 = int(c + half) + 1
        row = y * S
        for x in range(x0, x1):
            dx = x + 0.5 - c
            rpx = sqrt(dx * dx + dy * dy)
            if rpx >= R:
                continue
            rr = rpx / R
            if rr >= BEZEL_INNER:
                fo = (rr - 0.97) / 0.03
                cr, cg, cb = bez
                if fo > 0.0:
                    if fo > 1.0:
                        fo = 1.0
                    cr += (sh1[0] - cr) * fo
                    cg += (sh1[1] - cg) * fo
                    cb += (sh1[2] - cb) * fo
                u = -(dx + dy) / (rpx * 1.41421)
                if u > 0.0:
                    band = sin(3.14159 * (rr - BEZEL_INNER) / (1.0 - BEZEL_INNER))
                    spec = u * u * u * 0.55 * band
                    cr += (sh2[0] - cr) * spec
                    cg += (sh2[1] - cg) * spec
                    cb += (sh2[2] - cb) * spec
                p = px[row + x]
                p[0] = int(cr); p[1] = int(cg); p[2] = int(cb); p[3] = 255
            elif rr >= REHAUT_IN:
                col = rehl if (BEZEL_INNER * R - rpx) < hairline else reh
                p = px[row + x]
                p[0] = col[0]; p[1] = col[1]; p[2] = col[2]; p[3] = 255
            else:
                f = ((dy + A * sin(KX * dx + ph)) / P) % 1.0
                b = -sin(TWO_PI * f)
                t = b * b
                t = t * t  # narrow, crisp crest/groove bands
                if b > 0.0:
                    hh = hi2 if (dx + dy) < -0.55 * R else hi
                    cr = ridge[0] + (hh[0] - ridge[0]) * t
                    cg = ridge[1] + (hh[1] - ridge[1]) * t
                    cb = ridge[2] + (hh[2] - ridge[2]) * t
                else:
                    cr = ridge[0] + (gro[0] - ridge[0]) * t
                    cg = ridge[1] + (gro[1] - ridge[1]) * t
                    cb = ridge[2] + (gro[2] - ridge[2]) * t
                g = (-dy / R - 0.15) / 0.75
                if g > 0.0:
                    if g > 1.0:
                        g = 1.0
                    add = 9.0 * g
                    cr += add; cg += add; cb += add
                p = px[row + x]
                p[0] = int(cr); p[1] = int(cg); p[2] = int(cb); p[3] = 255


# ---------------------------------------------------------------------------
# bezel furniture
# ---------------------------------------------------------------------------
def paint_bezel(cv, c, R, T):
    enam = T["ENAMEL_WHITE"]
    # minute dots (skip every 5th: batons/numerals/triangle live there)
    for k in range(60):
        if k % 5 == 0:
            continue
        x, y = pt(c, R, BZ_DOT_R, k * 6.0)
        disc(cv, x, y, BZ_DOT_D / 2.0 * R, T["BEZEL_DOT"])
    # 5-minute batons
    for ang in (30, 90, 150, 210, 270, 330):
        rad_rect(cv, c, R, ang, BZ_BATON_R0, BZ_BATON_R1, BZ_BATON_W, enam)
    # small tick at each numeral angle
    for ang in (60, 120, 180, 240, 300):
        rad_rect(cv, c, R, ang, BZ_DOT_R - BZ_TICK_L / 2.0,
                 BZ_DOT_R + BZ_TICK_L / 2.0, BZ_TICK_W, enam)
    # rotated numerals 10..50
    for num, ang in (("10", 60), ("20", 120), ("30", 180), ("40", 240),
                     ("50", 300)):
        cap = BZ_NUM_CAP * R
        halfw = BZ_NUM_STROKE / 2.0 * R
        a1 = glyph_adv(num[0]); a2 = glyph_adv(num[1])
        avail = (BZ_NUM_SPAN - BZ_NUM_GAP) * R
        wf = avail / ((a1 + a2) * cap)
        w1 = a1 * cap * wf
        w2 = a2 * cap * wf
        ncx, ncy = pt(c, R, BZ_NUM_R, ang)
        rad = math.radians(ang)
        pxv, pyv = math.cos(rad), math.sin(rad)
        for ch, off in ((num[0], -(BZ_NUM_GAP * R + w1) / 2.0 - (w1 - w1) ),
                        (num[1], (BZ_NUM_GAP * R + w2) / 2.0)):
            gx = ncx + pxv * off
            gy = ncy + pyv * off
            draw_glyph(cv, ch, gx, gy, cap, halfw, enam, rot_deg=ang, wf=wf)
    # 12 o'clock triangle (outline only) + lume pearl
    tri = [pt(c, R, TRI_BASE_R, 0)[0] - TRI_HALF_W * R,
           pt(c, R, TRI_BASE_R, 0)[1]]
    p_a = (c - TRI_HALF_W * R, c - TRI_BASE_R * R)
    p_b = (c + TRI_HALF_W * R, c - TRI_BASE_R * R)
    p_c = (c, c - TRI_APEX_R * R)
    fill_poly(cv, [p_a, p_b, p_c], T["BEZEL_BLACK"])
    stroke_poly(cv, [p_a, p_b, p_c], TRI_STROKE / 2.0 * R, enam)
    disc(cv, c, c - PEARL_R * R, PEARL_D / 2.0 * R, T["LUME_PEARL"])
    ring(cv, c, c - PEARL_R * R, PEARL_D / 2.0 * R,
         PEARL_D / 2.0 * R - 0.008 * R, T["PEARL_RIM"])
    stroke_arc(cv, c, c - PEARL_R * R, PEARL_D / 2.0 * R - 0.006 * R,
               0.004 * R, 280, 350, T["WHITE"], a=0.85)


# ---------------------------------------------------------------------------
# dial minute-track flange
# ---------------------------------------------------------------------------
def paint_flange(cv, c, R, T):
    fw = T["FLANGE_WHITE"]
    for k in range(60):
        ang = k * 6.0
        if abs(((ang - 180.0 + 180.0) % 360.0) - 180.0) < MT_GAP_DEG:
            continue
        rad_rect(cv, c, R, ang, MT_TICK_R0, MT_TICK_R1, MT_TICK_W, fw)
    for k in range(60):
        ang = k * 6.0 + 3.0
        if abs(((ang - 180.0 + 180.0) % 360.0) - 180.0) < MT_GAP_DEG:
            continue
        rad_rect(cv, c, R, ang, MT_HALF_R0, MT_TICK_R1, MT_TICK_W, fw)
    # quarter-second dots on the rehaut (caliber-9900 4 Hz graduation)
    k = 0
    while k < 240:
        ang = k * 1.5
        k += 1
        if k % 2 == 1:  # skip angles that coincide with ticks (mult of 3 deg)
            continue
        if abs(((ang - 180.0 + 180.0) % 360.0) - 180.0) < MT_GAP_DEG:
            continue
        x, y = pt(c, R, MT_DOT_R, ang)
        disc(cv, x, y, MT_DOT_D / 2.0 * R, fw)


# ---------------------------------------------------------------------------
# applied markers
# ---------------------------------------------------------------------------
def lume_dot(cv, x, y, R, T):
    disc(cv, x, y, DOT_SHADOW_D / 2.0 * R, T["MARKER_SHADOW"])
    disc(cv, x, y, DOT_RIM_D / 2.0 * R, T["MARKER_RIM"])
    disc(cv, x, y, DOT_LUME_D / 2.0 * R, T["LUME_WHITE"])
    disc(cv, x - 0.012 * R, y - 0.014 * R, 0.020 * R, T["LUME_HOT"], 0.55)
    stroke_arc(cv, x, y, (DOT_RIM_D + DOT_LUME_D) / 4.0 * R, 0.0035 * R,
               285, 345, T["WHITE"], a=0.9)


def lume_rrect(cv, cx, cy, w, h, cr, R, T, rim=0.006):
    fill_poly(cv, rrect_pts(cx, cy, (w + 0.010) * R, (h + 0.010) * R,
                            (cr + 0.004) * R), T["MARKER_SHADOW"])
    fill_poly(cv, rrect_pts(cx, cy, w * R, h * R, cr * R), T["MARKER_RIM"])
    fill_poly(cv, rrect_pts(cx, cy, (w - 2 * rim) * R, (h - 2 * rim) * R,
                            max(0.004, cr - rim) * R), T["LUME_WHITE"])


def paint_markers(cv, c, R, T):
    # round dots at 1,2,4,5,7,8,10,11
    for hnum in (1, 2, 4, 5, 7, 8, 10, 11):
        x, y = pt(c, R, DOT_HOUR_R, hnum * 30.0)
        lume_dot(cv, x, y, R, T)
    # double bar at 12
    bar_h = (BAR12_R1 - BAR12_R0)
    bar_cy = c - (BAR12_R0 + BAR12_R1) / 2.0 * R
    for side in (-1, 1):
        bx = c + side * (BAR12_W + BAR12_GAP) / 2.0 * R
        fill_poly(cv, rrect_pts(bx, bar_cy, (BAR12_W + 0.008) * R,
                                (bar_h + 0.008) * R, (BAR12_CR + 0.004) * R),
                  T["MARKER_SHADOW"])
        fill_poly(cv, rrect_pts(bx, bar_cy, BAR12_W * R, bar_h * R,
                                BAR12_CR * R), T["MARKER_RIM"])
        fill_poly(cv, rrect_pts(bx, bar_cy, (BAR12_W - 0.020) * R,
                                (bar_h - 0.020) * R, BAR12_CR * R),
                  T["LUME_WHITE"])
    # 3 and 9 plots (tangential = vertical there)
    for ang in (90.0, 270.0):
        x, y = pt(c, R, PLOT39_R, ang)
        lume_rrect(cv, x, y, PLOT39_H, PLOT39_W, 0.008, R, T)
    # 6 plot (wider, horizontal)
    x, y = pt(c, R, PLOT6_R, 180.0)
    lume_rrect(cv, x, y, PLOT6_W, PLOT6_H, 0.008, R, T)


# ---------------------------------------------------------------------------
# subdials
# ---------------------------------------------------------------------------
def subdial_base(cv, c, R, T, sx, bronze):
    """Per-pixel recess: flange (or bronze ring) annulus + snailed center."""
    sqrt = math.sqrt
    px = cv.px
    S = cv.s
    r_out = SUB_R * R
    x0 = int(sx - r_out) - 1
    x1 = int(sx + r_out) + 2
    y0 = int(c - r_out) - 1
    y1 = int(c + r_out) + 2
    fl = T["SUB_FLANGE"]
    ring_col = T["BRONZE_RING"]
    ring_s = T["BRONZE_RING_S"]
    sn_b = T["SNAIL_BASE"]
    sn_g = T["SNAIL_GROOVE"]
    wall = (0x04, 0x04, 0x05)
    pitch = 0.006 * R
    for y in range(y0, y1):
        dy = y + 0.5 - c
        row = y * S
        for x in range(x0, x1):
            dx = x + 0.5 - sx
            rpx = sqrt(dx * dx + dy * dy)
            rr = rpx / R
            if rr >= SUB_R:
                continue
            if rr >= SUB_SNAIL_R:
                if bronze:
                    if rr >= BRONZE_OUT:
                        col = wall
                    else:
                        # shade the annulus toward its south edge
                        tsh = max(0.0, dy / rpx) if rpx > 0 else 0.0
                        col = (int(ring_col[0] + (ring_s[0] - ring_col[0]) * tsh),
                               int(ring_col[1] + (ring_s[1] - ring_col[1]) * tsh),
                               int(ring_col[2] + (ring_s[2] - ring_col[2]) * tsh))
                else:
                    if rr >= SUB_R - 0.006:
                        col = wall
                    else:
                        col = fl
            else:
                m = rpx % pitch
                col = sn_g if m < pitch * 0.22 else sn_b
            p = px[row + x]
            p[0] = col[0]; p[1] = col[1]; p[2] = col[2]; p[3] = 255


def paint_subdial_left(cv, c, R, T, seconds, hand=True):
    sx = c - SUB_OFFSET * R
    subdial_base(cv, c, R, T, sx, bronze=False)
    pr = T["SUB_PRINT"]
    for k in range(12):
        rad = math.radians(k * 30.0)
        w = 0.010 * R if k % 3 == 0 else 0.0055 * R
        r0 = SUB_R * 0.66 * R; r1 = SUB_R * 0.82 * R
        thick_line(cv, sx + r0 * math.sin(rad), c - r0 * math.cos(rad),
                   sx + r1 * math.sin(rad), c - r1 * math.cos(rad), w, pr)
    if hand:
        ang = math.radians(seconds * 6.0)
        tl = SUB_R * 0.78 * R
        thick_line(cv, sx, c, sx + tl * math.sin(ang), c - tl * math.cos(ang),
                   0.0075 * R, T["STEEL_HI"])
        disc(cv, sx, c, 0.023 * R, T["STEEL_MID"])
        disc(cv, sx, c, 0.014 * R, T["STEEL_HI"])



def paint_subdial_right(cv, c, R, T, min_ang, hr_ang, hand=True):
    sx = c + SUB_OFFSET * R
    subdial_base(cv, c, R, T, sx, bronze=True)
    pr = T["RING_PRINT"]
    for k in range(12):
        rad = math.radians(k * 30.0)
        r0 = SUB_SNAIL_R * R; r1 = BRONZE_OUT * R
        thick_line(cv, sx + r0 * math.sin(rad), c - r0 * math.cos(rad),
                   sx + r1 * math.sin(rad), c - r1 * math.cos(rad), 0.006 * R, pr)
    if hand:
        ang = math.radians(min_ang)
        tl = SUB_R * 0.72 * R
        thick_line(cv, sx, c, sx + tl * math.sin(ang), c - tl * math.cos(ang),
                   0.0075 * R, T["STEEL_HI"])
        disc(cv, sx, c, 0.021 * R, T["STEEL_MID"])
        disc(cv, sx, c, 0.013 * R, T["STEEL_HI"])


# ---------------------------------------------------------------------------
# date window
# ---------------------------------------------------------------------------
def paint_date(cv, c, R, T, text="12", number=True):
    cy = c + DATE_CY * R
    fill_poly(cv, rrect_pts(c, cy, DATE_W * R, DATE_H * R, DATE_CR * R),
              T["DATE_FRAME"])
    aw = (DATE_W - 0.024) * R
    ah = (DATE_H - 0.024) * R
    fill_poly(cv, rrect_pts(c, cy, aw, ah, (DATE_CR - 0.008) * R),
              T["DATE_APERTURE"])
    # inner-top specular hairline
    thick_line(cv, c - aw / 2.0 + 0.012 * R, cy - ah / 2.0 + 0.004 * R,
               c + aw / 2.0 - 0.012 * R, cy - ah / 2.0 + 0.004 * R,
               0.0022 * R, T["DATE_SPEC"])
    if number:
        draw_text(cv, text, c, cy + 0.004 * R, DATE_NUM_H * R, 0.0105 * R,
                  T["DATE_NUMERAL"], total_w=0.128 * R)


# ---------------------------------------------------------------------------
# dial text stack
# ---------------------------------------------------------------------------
def draw_sunrise_emblem(cv, cx, cy, R, T):
    """Trident emblem — a classic dive-watch motif (Neptune's trident), a
    generic maritime symbol not owned by any single brand."""
    col = T["TEXT_OMEGA_S"]
    hw = 0.0056 * R
    top = cy - 0.050 * R
    bot = cy + 0.050 * R
    sp = 0.027 * R                            # tine spacing
    # shaft
    thick_line(cv, cx, top + 0.004 * R, cx, bot, hw, col)
    # crossbar joining the tines
    thick_line(cv, cx - sp * 2, top + 0.030 * R,
               cx + sp * 2, top + 0.030 * R, hw, col)
    # centre tine (barbed point)
    thick_line(cv, cx, top - 0.008 * R, cx, top + 0.030 * R, hw, col)
    disc(cv, cx, top - 0.012 * R, hw * 1.35, col)
    # side tines: curl outward from the crossbar, then rise to barbed points
    for s in (-1, 1):
        stroke_arc(cv, cx + s * sp, top + 0.030 * R, sp, hw,
                   90 if s > 0 else 270, 180 if s > 0 else 360, col, step=5)
        thick_line(cv, cx + s * sp * 2, top + 0.030 * R,
                   cx + s * sp * 2, top - 0.004 * R, hw, col)
        disc(cv, cx + s * sp * 2, top - 0.008 * R, hw * 1.25, col)
    # base ball
    disc(cv, cx, bot + 0.004 * R, hw * 1.7, col)


def draw_omega_symbol(cv, cx, cy, R, T):
    h = 0.069 * R
    w = 0.080 * R
    halfw = 0.0055 * R
    col = T["TEXT_OMEGA_S"]
    r = w * 0.42
    ccy = cy - h / 2.0 + r * 1.05
    # open ring (gap at the bottom)
    stroke_arc(cv, cx, ccy, r, halfw, 215, 505, col, step=6)
    # feet
    fy = cy + h / 2.0 - halfw
    gap = r * 0.60
    thick_line(cv, cx - w / 2.0, fy, cx - gap * 0.55, fy, halfw, col)
    thick_line(cv, cx + gap * 0.55, fy, cx + w / 2.0, fy, halfw, col)


def draw_zro2(cv, cx, cy, R, T):
    col = T["ZRO2_GRAY"]
    lh = 0.044 * R
    bh = 0.062 * R
    halfw = 0.0032 * R
    # layout: [ Z r O 2 ]
    items = [("[", bh, 0.0), ("Z", lh, 0.0), ("r", lh, 0.0), ("O", lh, 0.0),
             ("2", lh * 0.60, lh * 0.28), ("]", bh, 0.0)]
    track = 0.012 * R
    total = sum(glyph_adv(ch) * h for ch, h, _ in items) + track * (len(items) - 1)
    x = cx - total / 2.0
    for ch, h, dy in items:
        aw = glyph_adv(ch) * h
        draw_glyph(cv, ch, x + aw / 2.0, cy + dy, h, halfw, col)
        x += aw + track


def paint_text_stack(cv, c, R, T):
    draw_sunrise_emblem(cv, c, c - 0.400 * R, R, T)
    draw_text(cv, "FIRST LIGHT", c, c - 0.300 * R, 0.050 * R, 0.0052 * R,
              T["TEXT_OMEGA"], total_w=0.340 * R)
    draw_text(cv, "DIVER", c, c - 0.205 * R, 0.052 * R, 0.0048 * R,
              T["RED_SCRIPT"], total_w=0.150 * R)
    draw_text(cv, "PROFESSIONAL", c, c - 0.118 * R, 0.034 * R, 0.0034 * R,
              T["TEXT_PROF"], total_w=0.300 * R)
    draw_text(cv, "CHRONOMETER", c, c + 0.255 * R, 0.030 * R, 0.0030 * R,
              T["TEXT_MID"], total_w=0.320 * R)
    draw_text(cv, "300m / 1000ft", c, c + 0.305 * R, 0.030 * R, 0.0030 * R,
              T["TEXT_MID"], total_w=0.270 * R)


# ---------------------------------------------------------------------------
# hands
# ---------------------------------------------------------------------------
def hand_frame(c, R, ang_deg):
    rad = math.radians(ang_deg)
    d = (math.sin(rad), -math.cos(rad))
    p = (math.cos(rad), math.sin(rad))

    def tp(t, u):
        return (c + (p[0] * t + d[0] * u) * R, c + (p[1] * t + d[1] * u) * R)
    return tp, d, p


def lit_sides(p):
    """Return (left_col_key, right_col_key) given the hand's perp vector."""
    # light from upper-left
    lit_right = (p[0] * -0.6 + p[1] * -0.8) > 0
    return ("STEEL_LO", "STEEL_HI") if lit_right else ("STEEL_HI", "STEEL_LO")


def hand_shadow(cv, c, R, ang_deg, length, hw, tail=0.0):
    rad = math.radians(ang_deg)
    ox, oy = 0.010 * R, 0.016 * R
    x0 = c - tail * R * math.sin(rad) + ox
    y0 = c + tail * R * math.cos(rad) + oy
    x1 = c + length * R * math.sin(rad) + ox
    y1 = c - length * R * math.cos(rad) + oy
    thick_line(cv, x0, y0, x1, y1, hw * R, (0, 0, 0), 0.30)


def paint_hour_hand(cv, c, R, T, ang):
    tp, d, p = hand_frame(c, R, ang)
    lcol, rcol = lit_sides(p)
    hand_shadow(cv, c, R, ang, HOUR_LEN, 0.045)

    def w_at(u):  # outer half-width along the sword
        return 0.023 + (0.060 - 0.023) * (u - 0.05) / (0.372 - 0.05)
    # solid base near hub
    fill_poly(cv, [tp(-0.023, 0.030), tp(-w_at(0.119), 0.119),
                   tp(w_at(0.119), 0.119), tp(0.023, 0.030)], T["STEEL_MID"])
    # skeleton rails (open slot 0.119 -> 0.302)
    for side, col in ((-1, T[lcol]), (1, T[rcol])):
        fill_poly(cv, [tp(side * w_at(0.119), 0.119),
                       tp(side * w_at(0.302), 0.302),
                       tp(side * (w_at(0.302) - 0.015), 0.302),
                       tp(side * (w_at(0.119) - 0.015), 0.119)], col)
    # crossbar at slot base
    fill_poly(cv, [tp(-w_at(0.119), 0.105), tp(w_at(0.119), 0.105),
                   tp(w_at(0.119), 0.121), tp(-w_at(0.119), 0.121)],
              T["STEEL_MID"])
    # solid blunt tip block 0.302 -> 0.440
    tip = [tp(-w_at(0.302), 0.302), tp(-0.060, 0.372), tp(-0.046, 0.433),
           tp(-0.032, HOUR_LEN), tp(0.032, HOUR_LEN), tp(0.046, 0.433),
           tp(0.060, 0.372), tp(w_at(0.302), 0.302)]
    fill_poly(cv, tip, T["STEEL_MID"])
    # facet strokes along the outer edges of the tip block
    thick_line(cv, tp(-w_at(0.302), 0.302)[0], tp(-w_at(0.302), 0.302)[1],
               tp(-0.060, 0.372)[0], tp(-0.060, 0.372)[1], 0.004 * R, T[lcol])
    thick_line(cv, tp(-0.060, 0.372)[0], tp(-0.060, 0.372)[1],
               tp(-0.040, HOUR_LEN)[0], tp(-0.040, HOUR_LEN)[1], 0.004 * R,
               T[lcol])
    thick_line(cv, tp(w_at(0.302), 0.302)[0], tp(w_at(0.302), 0.302)[1],
               tp(0.060, 0.372)[0], tp(0.060, 0.372)[1], 0.004 * R, T[rcol])
    thick_line(cv, tp(0.060, 0.372)[0], tp(0.060, 0.372)[1],
               tp(0.040, HOUR_LEN)[0], tp(0.040, HOUR_LEN)[1], 0.004 * R,
               T[rcol])
    # circular lume window
    lx, ly = tp(0, 0.372)
    disc(cv, lx, ly, 0.051 * R, T["STEEL_LO"])
    disc(cv, lx, ly, 0.047 * R, T["LUME_HAND"])


def paint_minute_hand(cv, c, R, T, ang):
    tp, d, p = hand_frame(c, R, ang)
    lcol, rcol = lit_sides(p)
    hand_shadow(cv, c, R, ang, MIN_LEN, 0.028)
    # solid base
    fill_poly(cv, [tp(-0.024, 0.030), tp(-0.024, 0.110), tp(0.024, 0.110),
                   tp(0.024, 0.030)], T["STEEL_MID"])
    # rails 0.110 -> 0.503
    for side, col in ((-1, T[lcol]), (1, T[rcol])):
        fill_poly(cv, [tp(side * 0.024, 0.110), tp(side * 0.024, 0.503),
                       tp(side * 0.009, 0.503), tp(side * 0.009, 0.110)], col)
    # crossbar closing the slot
    fill_poly(cv, [tp(-0.024, 0.100), tp(0.024, 0.100), tp(0.024, 0.114),
                   tp(-0.024, 0.114)], T["STEEL_MID"])
    # neck flaring into the arrow base
    fill_poly(cv, [tp(-0.024, 0.503), tp(-0.0525, 0.530), tp(0.0525, 0.530),
                   tp(0.024, 0.503)], T["STEEL_MID"])
    # solid lume arrowhead
    arrow = [tp(-0.0525, 0.530), tp(0, MIN_LEN), tp(0.0525, 0.530)]
    fill_poly(cv, arrow, T["LUME_HAND"])
    stroke_poly(cv, arrow, 0.0035 * R, T["STEEL_HI"])


def paint_chrono_hand(cv, c, R, T, ang):
    tp, d, p = hand_frame(c, R, ang)
    hand_shadow(cv, c, R, ang, SEC_LEN, 0.008, tail=SEC_TAIL)
    hw = 0.005 * R
    # tail (square end)
    x0, y0 = tp(0, -SEC_TAIL)
    x1, y1 = tp(0, 0)
    thick_line(cv, x0, y0, x1, y1, hw, T["BRONZE_LO"])
    # main shaft, faceted along its length
    xa, ya = tp(0, 0.50)
    thick_line(cv, x1, y1, xa, ya, hw, T["BRONZE_MID"])
    xb, yb = tp(0, SEC_LEN)
    thick_line(cv, xa, ya, xb, yb, hw * 0.9, T["BRONZE_HI"])
    # mid-needle lollipop
    lx, ly = tp(0, 0.485)
    ring(cv, lx, ly, 0.0375 * R, 0.0265 * R, T["BRONZE_MID"])
    disc(cv, lx, ly, 0.0265 * R, T["LUME_LOLLI"])
    stroke_arc(cv, lx, ly, 0.032 * R, 0.0028 * R, 285, 345, T["WHITE"], a=0.8)


def paint_hub(cv, c, R, T):
    ring(cv, c, c, 0.040 * R, 0.034 * R, T["STEEL_MID"])
    disc(cv, c, c, 0.029 * R, T["BRONZE_MID"])
    # screw slot
    rad = math.radians(35.0)
    dx, dy = math.sin(rad) * 0.020 * R, -math.cos(rad) * 0.020 * R
    thick_line(cv, c - dx, c - dy, c + dx, c + dy, 0.0045 * R, T["HUB_SLOT"])
    disc(cv, c - 0.008 * R, c - 0.008 * R, 0.007 * R, T["BRONZE_HI"], 0.7)


# ---------------------------------------------------------------------------
# face assembly
# ---------------------------------------------------------------------------
def render_face(size, theme, ss=3, h=10, m=9, s=37, date="12", hands=True, dim=False):
    S = size * ss
    cv = Canvas(S)
    c = S / 2.0
    R = (S / 2.0) * DIAL_FILL
    c_glob[0] = c
    T = dict(TOKENS)
    T.update(theme)
    if dim:
        T = {k: (tuple(int(round(ch * 0.60)) for ch in v)
                 if isinstance(v, tuple) and len(v) == 3 else v)
             for k, v in T.items()}

    paint_background(cv, R, T)
    # paint_bezel removed — the physical metal bezel carries the dive scale
    paint_flange(cv, c, R, T)
    paint_text_stack(cv, c, R, T)
    paint_subdial_left(cv, c, R, T, seconds=s, hand=hands)
    paint_subdial_right(cv, c, R, T, min_ang=66.0, hr_ang=30.0, hand=hands)
    paint_date(cv, c, R, T, date, number=hands)
    paint_markers(cv, c, R, T)

    if hands:
        hour_ang = ((h % 12) + m / 60.0 + s / 3600.0) * 30.0
        min_ang = (m + s / 60.0) * 6.0
        sec_ang = s * 6.0
        paint_hour_hand(cv, c, R, T, hour_ang)
        paint_minute_hand(cv, c, R, T, min_ang)
        paint_chrono_hand(cv, c, R, T, sec_ang)
        paint_hub(cv, c, R, T)

    return downsample(cv, size, ss)


def downsample(cv, size, ss):
    S = cv.s
    out = Canvas(size)
    for y in range(size):
        for x in range(size):
            r = g = b = a = 0
            for j in range(ss):
                for i in range(ss):
                    p = cv.px[(y * ss + j) * S + (x * ss + i)]
                    r += p[0]; g += p[1]; b += p[2]; a += p[3]
            n = ss * ss
            out.px[y * size + x] = [r // n, g // n, b // n, a // n]
    return out


def main():
    args = sys.argv[1:]
    ss = 3
    sel = []
    for a in args:
        if a.startswith("--ss="):
            ss = int(a[5:])
        elif a in THEMES:
            sel.append(a)
        else:
            raise SystemExit("unknown arg %r (themes: %s)" % (a, ", ".join(THEMES)))
    names = sel or list(THEMES)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        img = render_face(454, THEMES[name], ss=ss)
        path = os.path.join(OUT, "face_%s.png" % name)
        write_png(img, path)
        print("wrote", os.path.relpath(path))


if __name__ == "__main__":
    main()
