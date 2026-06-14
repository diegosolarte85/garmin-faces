#!/usr/bin/env python3
"""Render full-resolution (454x454) face mockups for the store listing / README.

Pure standard library — reuses the primitives from gen_icons.py. These are
*design mockups* of the watch face (the same palette and geometry the Monkey C
renderer uses). Garmin's store requires real simulator/device screenshots for
submission; use these for marketing and the README.

    python3 tools/gen_preview.py
"""
import math
import os

from gen_icons import (
    Canvas, disc, ring, thick_line, write_png, lerp,
    CERAMIC, WAVE_HI, BEZEL, ENAMEL, RHODIUM, RHODIUM_HI, BRONZE, BRONZE_HI,
    LUME, POPPY_RED,
)

OUT = os.path.join(os.path.dirname(__file__), "..", "store", "screenshots")

THEMES = {
    "black_ceramic": {"base": CERAMIC, "wave": WAVE_HI, "accent": BRONZE, "accent_hi": BRONZE_HI},
    "dawn": {"base": (0x0B, 0x08, 0x05), "wave": (0x2A, 0x24, 0x18), "accent": BRONZE, "accent_hi": BRONZE_HI},
    "red_accent": {"base": CERAMIC, "wave": WAVE_HI, "accent": POPPY_RED, "accent_hi": (0xFF, 0x6A, 0x5E)},
}


def arc(cv, cx, cy, r, width, start_deg, end_deg, color):
    """Thick arc drawn as overlapping discs along the sweep (clockwise gap-safe)."""
    a = start_deg
    step = 4
    while a <= end_deg:
        rad = math.radians(a)
        x = cx + r * math.cos(rad)
        y = cy - r * math.sin(rad)
        disc(cv, x, y, width / 2.0, color)
        a += step


def pol(cx, cy, r, frac):
    """Point at dial fraction (0=12 o'clock, clockwise)."""
    ang = frac * 2 * math.pi
    return cx + r * math.sin(ang), cy - r * math.cos(ang)


def render_face(size, theme, ss=3, h=10, m=9, s=37):
    S = size * ss
    cv = Canvas(S)
    c = S / 2.0
    R = S / 2.0
    base, wave, accent, accent_hi = theme["base"], theme["wave"], theme["accent"], theme["accent_hi"]

    # bezel
    disc(cv, c, c, R, BEZEL)
    # dive scale ticks + numerals positions
    for k in range(60):
        ang = math.radians(k * 6)
        major = (k % 5 == 0)
        r1 = R * (0.985 if major else 0.975)
        r2 = R * 0.915
        x0, y0 = c + r1 * math.sin(ang), c - r1 * math.cos(ang)
        x1, y1 = c + r2 * math.sin(ang), c - r2 * math.cos(ang)
        thick_line(cv, x0, y0, x1, y1, S * (0.006 if major else 0.0028), ENAMEL)
    # lume pip at 12
    disc(cv, c, c - R * 0.95, S * 0.015, LUME)

    # dial face
    disc(cv, c, c, R * 0.885, base)
    band = R * 0.885
    # horizontal wave striations
    y = int(c - band)
    while y < c + band:
        t = 0.5 + 0.5 * math.sin((y - c) / (S * 0.022))
        shade = lerp(base, wave, 0.5 * t)
        half = band * band - (y - c) ** 2
        if half > 0:
            half = math.sqrt(half)
            for x in range(int(c - half), int(c + half)):
                cv.blend(x, y, shade, 0.5)
        y += 1
    # overlaid ripple lines
    rows = 30
    for r in range(rows):
        baseY = c - band + 2 * band * (r + 0.5) / rows
        amp = band * 0.012
        prev = None
        x = c - band
        while x <= c + band:
            yy = baseY + amp * math.sin(x / (band * 0.07) + r * 0.6)
            if (x - c) ** 2 + (yy - c) ** 2 <= band * band:
                if prev:
                    thick_line(cv, prev[0], prev[1], x, yy, S * 0.0015, lerp(base, wave, 0.5))
                prev = (x, yy)
            else:
                prev = None
            x += S * 0.01

    # chapter ring ticks
    for k in range(60):
        ang = math.radians(k * 6)
        major = (k % 5 == 0)
        r1 = R * 0.84
        r2 = R * (0.81 if major else 0.825)
        x0, y0 = c + r1 * math.sin(ang), c - r1 * math.cos(ang)
        x1, y1 = c + r2 * math.sin(ang), c - r2 * math.cos(ang)
        thick_line(cv, x0, y0, x1, y1, S * (0.004 if major else 0.002), ENAMEL if major else lerp(base, ENAMEL, 0.5))

    # hour markers (double at 12), skip none
    for k in range(12):
        ang = math.radians(k * 30)
        rO, rI = R * 0.80, R * 0.70
        if k == 0:
            for off in (-S * 0.016, S * 0.016):
                x0 = c + rO * math.sin(ang) + off * math.cos(ang)
                y0 = c - rO * math.cos(ang) + off * math.sin(ang)
                x1 = c + rI * math.sin(ang) + off * math.cos(ang)
                y1 = c - rI * math.cos(ang) + off * math.sin(ang)
                thick_line(cv, x0, y0, x1, y1, S * 0.016, RHODIUM_HI)
                thick_line(cv, x0, y0, x1, y1, S * 0.008, LUME)
        else:
            x0, y0 = c + rO * math.sin(ang), c - rO * math.cos(ang)
            x1, y1 = c + rI * math.sin(ang), c - rI * math.cos(ang)
            thick_line(cv, x0, y0, x1, y1, S * 0.022, RHODIUM_HI)
            thick_line(cv, x0, y0, x1, y1, S * 0.011, LUME)

    # subdials at 3 (bronze) and 9 (rhodium)
    def subdial(cx, ring_col, val_frac):
        r = R * 0.15
        disc(cv, cx, c, r, lerp(base, wave, 0.25))
        ring(cv, cx, c, r, r * 0.86, ring_col)
        for i in range(12):
            aa = math.radians(i * 30)
            x0, y0 = cx + r * 0.82 * math.sin(aa), c - r * 0.82 * math.cos(aa)
            x1, y1 = cx + r * 0.70 * math.sin(aa), c - r * 0.70 * math.cos(aa)
            thick_line(cv, x0, y0, x1, y1, S * 0.0025, lerp(base, ENAMEL, 0.5))
        hx, hy = cx + r * 0.68 * math.sin(val_frac * 2 * math.pi), c - r * 0.68 * math.cos(val_frac * 2 * math.pi)
        thick_line(cv, cx, c, hx, hy, S * 0.006, ring_col)
        disc(cv, cx, c, r * 0.09, ring_col)

    subdial(c + R * 0.43, BRONZE, 0.72)      # 3 o'clock (battery-like)
    subdial(c - R * 0.43, RHODIUM_HI, h / 24.0)  # 9 o'clock (24h)

    # date window at 6
    dcx, dcy = c, c + R * 0.47
    w2, h2 = R * 0.085, R * 0.060
    cv_rect(cv, dcx - w2 - S * 0.004, dcy - h2 - S * 0.004, dcx + w2 + S * 0.004, dcy + h2 + S * 0.004, RHODIUM_HI)
    cv_rect(cv, dcx - w2, dcy - h2, dcx + w2, dcy + h2, (0x10, 0x14, 0x18))

    # omega mark near 12 (open at the bottom, like the Ω)
    omx, omy, omr = c, c - R * 0.52, R * 0.060
    arc(cv, omx, omy, omr, S * 0.018, -60, 240, ENAMEL)
    cv_rect(cv, omx - omr * 1.0, omy + omr * 0.45, omx - omr * 0.45, omy + omr * 0.8, ENAMEL)
    cv_rect(cv, omx + omr * 0.45, omy + omr * 0.45, omx + omr * 1.0, omy + omr * 0.8, ENAMEL)

    # hands at h:m
    def hand(frac, length, w, col, lume=False):
        x1, y1 = pol(c, c, length, frac)
        thick_line(cv, c, c, x1, y1, w, col)
        if lume:
            thick_line(cv, c, c, x1, y1, w * 0.42, LUME)

    hour_frac = ((h % 12) + m / 60.0) / 12.0
    min_frac = m / 60.0
    sec_frac = s / 60.0
    hand(hour_frac, R * 0.52, S * 0.020, RHODIUM_HI, lume=True)
    hand(min_frac, R * 0.74, S * 0.014, RHODIUM_HI, lume=True)
    # seconds (accent) with lollipop + counterweight
    sx, sy = pol(c, c, R * 0.80, sec_frac)
    thick_line(cv, c, c, sx, sy, S * 0.005, accent)
    lx, ly = pol(c, c, R * 0.64, sec_frac)
    disc(cv, lx, ly, S * 0.016, accent)
    disc(cv, lx, ly, S * 0.009, LUME)
    tx, ty = pol(c, c, -R * 0.10, sec_frac)
    disc(cv, tx, ty, S * 0.018, accent)
    # hub
    disc(cv, c, c, S * 0.028, RHODIUM)
    disc(cv, c, c, S * 0.016, accent_hi)

    return downsample(cv, size, ss)


def cv_rect(cv, x0, y0, x1, y1, color):
    for y in range(int(y0), int(y1)):
        for x in range(int(x0), int(x1)):
            cv.blend(x, y, color, 1.0)


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
    os.makedirs(OUT, exist_ok=True)
    for name, theme in THEMES.items():
        img = render_face(454, theme)
        path = os.path.join(OUT, "face_%s.png" % name)
        write_png(img, path)
        print("wrote", os.path.relpath(path))


if __name__ == "__main__":
    main()
