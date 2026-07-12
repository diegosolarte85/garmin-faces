#!/usr/bin/env python3
"""Render the Connect IQ Store cover image (500x500, <300 KB).

The face nearly full-bleed on a dark backdrop with a faint dawn glow —
the product is the picture.

    python3 tools/gen_cover.py
"""
import math
import os
import struct
import zlib

from gen_icons import Canvas, lerp
from gen_preview import TOKENS, THEMES, render_face

OUT = os.path.join(os.path.dirname(__file__), "..", "store")

S = 500
FACE_D = 470
C = S / 2.0


def main():
    cv = Canvas(S)
    top = (0x0A, 0x0A, 0x0C)
    bot = (0x03, 0x03, 0x04)
    warm = TOKENS["BRONZE_HI"]
    r_glow = S * 0.52
    for y in range(S):
        col = lerp(top, bot, y / (S - 1.0))
        for x in range(S):
            cv.blend(x, y, col, 1.0)
            # warm glow, brightest up-left of center ("first light")
            d = math.hypot(x - C * 0.82, y - C * 0.82)
            if d < r_glow:
                a = 0.10 * (1.0 - d / r_glow) ** 2
                if a > 0.004:
                    cv.blend(x, y, warm, a)

    face = render_face(FACE_D, THEMES["black_ceramic"], ss=2)
    off = (S - FACE_D) // 2
    for y in range(FACE_D):
        row = y * FACE_D
        for x in range(FACE_D):
            p = face.px[row + x]
            if p[3] > 0:
                cv.blend(off + x, off + y, (p[0], p[1], p[2]), p[3] / 255.0)

    raw = bytearray()
    for y in range(S):
        raw.append(0)
        row = y * S
        for x in range(S):
            p = cv.px[row + x]
            raw += bytes((p[0], p[1], p[2], 255))

    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)

    ihdr = struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)
    path = os.path.join(OUT, "cover.png")
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    kb = os.path.getsize(path) // 1024
    print("wrote store/cover.png (%dx%d, %d KB)" % (S, S, kb))
    assert kb < 300, "cover exceeds 300 KB store limit"


if __name__ == "__main__":
    main()
