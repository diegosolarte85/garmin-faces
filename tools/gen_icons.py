#!/usr/bin/env python3
"""Render the launcher icon for the 007 First Light watch face.

Pure standard-library: a tiny supersampled software renderer + minimal PNG
encoder (zlib). No Pillow / ImageMagick required. Re-run after changing the
palette in specs/.../design.md so the icon stays in sync.

    python3 tools/gen_icons.py
"""
import math
import struct
import zlib
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "resources", "drawables")

# Palette (mirrors Theme.mc / design.md §3) as (r, g, b)
CERAMIC = (0x07, 0x09, 0x0C)
WAVE_HI = (0x1B, 0x23, 0x2C)
BEZEL = (0x0A, 0x0C, 0x10)
ENAMEL = (0xF2, 0xF4, 0xF5)
RHODIUM_HI = (0xDC, 0xE2, 0xE8)
RHODIUM = (0xAA, 0xB0, 0xB6)
BRONZE = (0xC7, 0x9A, 0x5B)
BRONZE_HI = (0xE9, 0xCD, 0x94)
LUME = (0xEA, 0xF3, 0xEC)
POPPY_RED = (0xE4, 0x26, 0x1B)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


class Canvas:
    def __init__(self, size, bg=(0, 0, 0, 0)):
        self.s = size
        self.px = [list(bg) for _ in range(size * size)]

    def blend(self, x, y, rgb, a):
        if x < 0 or y < 0 or x >= self.s or y >= self.s or a <= 0:
            return
        i = y * self.s + x
        dst = self.px[i]
        da = dst[3] / 255.0
        sa = a
        oa = sa + da * (1 - sa)
        if oa <= 0:
            return
        for c in range(3):
            dst[c] = int(round((rgb[c] * sa + dst[c] * da * (1 - sa)) / oa))
        dst[3] = int(round(oa * 255))


def disc(cv, cx, cy, r, rgb, a=1.0):
    x0, x1 = int(cx - r - 1), int(cx + r + 1)
    y0, y1 = int(cy - r - 1), int(cy + r + 1)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            edge = r - d
            if edge >= 0.5:
                cv.blend(x, y, rgb, a)
            elif edge > -0.5:
                cv.blend(x, y, rgb, a * (edge + 0.5))


def ring(cv, cx, cy, r_out, r_in, rgb, a=1.0):
    x0, x1 = int(cx - r_out - 1), int(cx + r_out + 1)
    y0, y1 = int(cy - r_out - 1), int(cy + r_out + 1)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            cov = min(r_out - d, d - r_in) + 0.5
            if cov >= 1:
                cv.blend(x, y, rgb, a)
            elif cov > 0:
                cv.blend(x, y, rgb, a * cov)


def thick_line(cv, x0, y0, x1, y1, w, rgb, a=1.0):
    minx, maxx = int(min(x0, x1) - w - 1), int(max(x0, x1) + w + 1)
    miny, maxy = int(min(y0, y1) - w - 1), int(max(y0, y1) + w + 1)
    dx, dy = x1 - x0, y1 - y0
    ll = math.hypot(dx, dy) or 1.0
    for y in range(miny, maxy):
        for x in range(minx, maxx):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = max(0.0, min(1.0, (px * dx + py * dy) / (ll * ll)))
            qx, qy = px - t * dx, py - t * dy
            dist = math.hypot(qx, qy)
            cov = (w - dist) + 0.5
            if cov >= 1:
                cv.blend(x, y, rgb, a)
            elif cov > 0:
                cv.blend(x, y, rgb, a * cov)


def render(size, ss=4):
    S = size * ss
    cv = Canvas(S)
    c = S / 2.0
    R = S / 2.0

    # Bezel + dial
    disc(cv, c, c, R, BEZEL)
    ring(cv, c, c, R, R * 0.905, BEZEL)
    # diving-scale ticks on bezel
    for k in range(12):
        ang = math.radians(k * 30)
        r1, r2 = R * 0.985, R * 0.92
        x0, y0 = c + r1 * math.sin(ang), c - r1 * math.cos(ang)
        x1, y1 = c + r2 * math.sin(ang), c - r2 * math.cos(ang)
        thick_line(cv, x0, y0, x1, y1, max(1.0, S * 0.012), ENAMEL)
    # lume pip at 12
    disc(cv, c, c - R * 0.95, S * 0.018, LUME)

    # Dial face with faint wave shading (horizontal bands)
    disc(cv, c, c, R * 0.885, CERAMIC)
    band = R * 0.885
    y = int(c - band)
    while y < c + band:
        t = 0.5 + 0.5 * math.sin(y / (S * 0.045))
        shade = lerp(CERAMIC, WAVE_HI, 0.5 * t)
        for x in range(int(c - band), int(c + band)):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if d <= band * 0.995:
                cv.blend(x, y, shade, 0.5)
        y += 1

    # Applied hour markers
    for k in range(12):
        ang = math.radians(k * 30)
        r1, r2 = R * 0.80, R * 0.70
        x0, y0 = c + r1 * math.sin(ang), c - r1 * math.cos(ang)
        x1, y1 = c + r2 * math.sin(ang), c - r2 * math.cos(ang)
        thick_line(cv, x0, y0, x1, y1, S * 0.02, RHODIUM_HI)
        thick_line(cv, x0, y0, x1, y1, S * 0.011, LUME)

    # Subdials at 3 and 9
    for sx, col in ((c + R * 0.43, BRONZE), (c - R * 0.43, RHODIUM)):
        ring(cv, sx, c, R * 0.15, R * 0.128, col)
        disc(cv, sx, c, R * 0.118, lerp(CERAMIC, WAVE_HI, 0.25))

    # Hands at 10:10
    def hand(angle_deg, length, w, rgb, lume=False):
        a = math.radians(angle_deg)
        x1 = c + length * math.sin(a)
        y1 = c - length * math.cos(a)
        thick_line(cv, c, c, x1, y1, w, rgb)
        if lume:
            thick_line(cv, c, c, x1, y1, w * 0.45, LUME)

    hand(-55, R * 0.5, S * 0.022, RHODIUM_HI, lume=True)   # hour ~10
    hand(60, R * 0.72, S * 0.016, RHODIUM_HI, lume=True)   # minute ~2
    # bronze seconds toward ~7
    a = math.radians(210)
    thick_line(cv, c, c, c + R * 0.78 * math.sin(a), c - R * 0.78 * math.cos(a),
               S * 0.008, BRONZE)
    disc(cv, c + R * 0.62 * math.sin(a), c - R * 0.62 * math.cos(a), S * 0.018, BRONZE_HI)
    # hub
    disc(cv, c, c, S * 0.03, RHODIUM)
    disc(cv, c, c, S * 0.016, BRONZE)
    # red poppy dot accent below center
    disc(cv, c, c + R * 0.30, S * 0.014, POPPY_RED)

    # Downsample (box filter) to target size
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


def write_png(cv, path):
    raw = bytearray()
    for y in range(cv.s):
        raw.append(0)
        for x in range(cv.s):
            raw += bytes(cv.px[y * cv.s + x])

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", cv.s, cv.s, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as f:
        f.write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))


def main():
    os.makedirs(OUT, exist_ok=True)
    # 65x65 matches the fenix8pro47mm launcher-icon size (avoids scaling).
    write_png(render(65), os.path.join(OUT, "launcher_icon.png"))
    # A larger preview tile, handy for the store / README.
    write_png(render(240), os.path.join(OUT, "preview_icon.png"))
    print("wrote launcher_icon.png (65) and preview_icon.png (240)")


if __name__ == "__main__":
    main()
