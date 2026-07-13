#!/usr/bin/env python3
"""Render the Connect IQ Store hero image (1440x720, <2048 KB).

Pure stdlib; composes the real face renderer from gen_preview.py onto a
cinematic banner: dark wave-motif backdrop, warm "first light" dawn glow,
title lockup on the left, the watch face large on the right.

    python3 tools/gen_hero.py
"""
import math
import os

from gen_icons import Canvas, disc, thick_line, write_png, lerp
from gen_preview import TOKENS, THEMES, render_face, draw_text, measure_text
import gen_preview as _gp

# The dial never needed these letters; add them for banner copy.
# Format matches gen_preview.GLYPHS: ([polylines in unit box], advance).
_gp.GLYPHS.setdefault("V", ([[(0, 0), (0.5, 1), (1, 0)]], 0.74))
_gp.GLYPHS.setdefault("U", ([[(0, 0), (0, 0.72), (0.16, 0.94), (0.5, 1),
                              (0.84, 0.94), (1, 0.72), (1, 0)]], 0.74))
_gp.GLYPHS.setdefault("B", ([[(0, 0), (0, 1)],
                             [(0, 0), (0.6, 0), (0.78, 0.08), (0.82, 0.22),
                              (0.78, 0.38), (0.6, 0.46), (0, 0.46)],
                             [(0.6, 0.46), (0.82, 0.55), (0.88, 0.72),
                              (0.82, 0.9), (0.6, 1), (0, 1)]], 0.76))
_gp.GLYPHS.setdefault("Q", ([[(0.3, 0), (0.7, 0), (0.95, 0.25), (0.95, 0.75),
                              (0.7, 1), (0.3, 1), (0.05, 0.75), (0.05, 0.25),
                              (0.3, 0)],
                             [(0.64, 0.7), (1.02, 1.06)]], 0.80))

OUT = os.path.join(os.path.dirname(__file__), "..", "store")

W, H = 1440, 720
FACE_D = 600                      # watch face diameter on the banner
FACE_CX, FACE_CY = 1040, 360      # face center
TXT_CX = 400                      # text column center


def background(cv):
    """Vertical gradient + faint wave striations + vignette."""
    top = (0x08, 0x08, 0x0A)
    bot = (0x03, 0x03, 0x04)
    for y in range(H):
        t = y / (H - 1.0)
        col = lerp(top, bot, t)
        for x in range(W):
            cv.blend(x, y, col, 1.0)
    # faint horizontal waves echoing the dial (amplitude grows to the right)
    wave_hi = TOKENS["WAVE_HI"]
    rows = 12
    for r in range(rows):
        base_y = (r + 0.5) * H / rows
        ph = r * 0.9
        prev = None
        x = 0.0
        while x <= W:
            yy = base_y + 10.0 * math.sin(x / 90.0 + ph)
            if prev is not None:
                thick_line(cv, prev[0], prev[1], x, yy, 1.0, wave_hi, 0.10)
            prev = (x, yy)
            x += 12.0
    # vignette (darken corners)
    for y in range(H):
        for x in range(0, W, 1):
            dx = (x - W / 2.0) / (W / 2.0)
            dy = (y - H / 2.0) / (H / 2.0)
            d = dx * dx + dy * dy
            if d > 0.55:
                cv.blend(x, y, (0, 0, 0), min(0.35, (d - 0.55) * 0.6))


def dawn_glow(cv):
    """Warm radial 'first light' glow behind the watch."""
    warm = TOKENS["BRONZE_HI"]
    r_max = 470.0
    x0 = max(0, int(FACE_CX - r_max)); x1 = min(W, int(FACE_CX + r_max))
    y0 = max(0, int(FACE_CY - r_max)); y1 = min(H, int(FACE_CY + r_max))
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x - FACE_CX, y - FACE_CY)
            if d < r_max:
                a = 0.12 * (1.0 - d / r_max) ** 2
                if a > 0.004:
                    cv.blend(x, y, warm, a)


def face_shadow(cv):
    """Soft dark halo so the watch sits into the banner."""
    r0 = FACE_D / 2.0
    for i in range(18):
        rr = r0 + 2 + i * 2.2
        a = 0.16 * (1.0 - i / 18.0)
        steps = int(2 * math.pi * rr / 3)
        for k in range(steps):
            ang = 2 * math.pi * k / steps
            cv.blend(int(FACE_CX + rr * math.cos(ang)),
                     int(FACE_CY + rr * math.sin(ang)), (0, 0, 0), a)


def blit(cv, src, ox, oy):
    for y in range(src.s):
        row = y * src.s
        for x in range(src.s):
            p = src.px[row + x]
            if p[3] > 0:
                cv.blend(ox + x, oy + y, (p[0], p[1], p[2]), p[3] / 255.0)


def title_block(cv):
    bronze = TOKENS["BRONZE_RING"]
    white = (0xF2, 0xF3, 0xF5)
    mid = TOKENS["TEXT_MID"]
    dim = TOKENS["TEXT_DIM"]
    # overline
    draw_text(cv, "SUPPORTED ON FENIX 8 PRO", TXT_CX, 172, 22, 1.6,
              bronze, total_w=460)
    # title (stacked)
    draw_text(cv, "FIRST", TXT_CX, 302, 98, 8.0, white, total_w=430)
    draw_text(cv, "LIGHT", TXT_CX, 408, 98, 8.0, white, total_w=430)
    # bronze rule
    thick_line(cv, TXT_CX - 260, 462, TXT_CX + 260, 462, 1.4, bronze, 0.9)
    disc(cv, TXT_CX, 462, 4.0, bronze)
    # subtitle lines
    draw_text(cv, "PROFESSIONAL DIVE CHRONOGRAPH", TXT_CX, 506, 23, 1.5,
              mid, total_w=520)
    draw_text(cv, "CARVED WAVE DIAL - BRONZE CHRONO - LUME", TXT_CX, 546, 20,
              1.3, dim, total_w=500)
    # footer
    draw_text(cv, "DIVE CHRONOGRAPH WATCH FACE", TXT_CX, 648, 17, 1.1, dim,
              total_w=300)


def main():
    cv = Canvas(W)
    # Canvas is square (side W); we only use the top H rows and crop on write.
    background(cv)
    dawn_glow(cv)
    face_shadow(cv)
    face = render_face(FACE_D, THEMES["black_ceramic"], ss=2)
    blit(cv, face, FACE_CX - FACE_D // 2, FACE_CY - FACE_D // 2)
    title_block(cv)

    # crop the square canvas to 1440x720
    out = Canvas(1)  # placeholder; we write raw rows directly
    out.s = -1       # unused
    import struct, zlib
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
    path = os.path.join(OUT, "hero.png")
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    kb = os.path.getsize(path) // 1024
    print("wrote store/hero.png (%dx%d, %d KB)" % (W, H, kb))
    assert kb < 2048, "hero exceeds 2048 KB store limit"


if __name__ == "__main__":
    main()
