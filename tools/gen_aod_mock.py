#!/usr/bin/env python3
"""Preview the always-on (AOD) view — mirrors BondSeamasterView.drawAod.

Black + glowing lume hour markers + 12 o'clock baton + bright hands + gold
center pip. Writes store/aod_preview.png.  python3 tools/gen_aod_mock.py
"""
import math
import os
import struct
import zlib

from gen_icons import Canvas, disc
from gen_preview import (TOKENS, THEMES, DIAL_FILL, c_glob,
                         paint_hour_hand, paint_minute_hand, paint_hub,
                         downsample)

MARKER_R = 0.590
OUT = os.path.join(os.path.dirname(__file__), "..", "store")


def render(size, ss, h=8, m=20):
    S = size * ss
    cv = Canvas(S)
    c = S / 2.0
    R = (S / 2.0) * DIAL_FILL
    c_glob[0] = c
    T = dict(TOKENS)
    T.update(THEMES["black_ceramic"])

    lume = (0x59, 0xB6, 0xA4)
    lume12 = (0xB4, 0xEC, 0xDC)
    gold = (0xC8, 0xA0, 0x5A)
    dot = 0.026 * R

    # hour markers 1..11
    for hh in range(1, 12):
        ang = math.radians(hh / 12.0 * 360.0)
        x = c + R * MARKER_R * math.sin(ang)
        y = c - R * MARKER_R * math.cos(ang)
        disc(cv, x, y, dot, lume)
    # 12 o'clock baton (upright rounded bar ~ stack of discs)
    tx = c
    ty = c - R * MARKER_R
    bh = dot * 3.0
    steps = 24
    for i in range(steps + 1):
        yy = ty - bh / 2.0 + bh * i / steps
        disc(cv, tx, yy, dot * 0.75, lume12)

    # bright hands
    hour_ang = ((h % 12) + m / 60.0) * 30.0
    min_ang = m * 6.0
    paint_hour_hand(cv, c, R, T, hour_ang)
    paint_minute_hand(cv, c, R, T, min_ang)
    paint_hub(cv, c, R, T)
    disc(cv, c, c, dot * 0.5, gold)

    return downsample(cv, size, ss)


def write_png(img, path):
    W = img.s
    raw = bytearray()
    for y in range(W):
        raw.append(0)
        for x in range(W):
            p = img.px[y * W + x]
            raw += bytes((p[0], p[1], p[2], 255))
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", W, W, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def main():
    img = render(454, 3)
    path = os.path.join(OUT, "aod_preview.png")
    write_png(img, path)
    print("wrote store/aod_preview.png (454x454, %d KB)" % (os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
