#!/usr/bin/env python3
"""Bake the static dial art as PNG resources for the watch to blit.

Garmin's first-party faces pre-render artwork as image assets rather than
drawing it at runtime — that's how they get flawless anti-aliasing, gradients
and zero lag. We do the same: render the static dial (waves, markers, subdial
recesses, text, date frame — everything EXCEPT the moving hands and live
values) supersampled, and let the watch drawBitmap it. Hands + complication
values are drawn on top at runtime.

    python3 tools/gen_dial_assets.py [--ss=N] [theme ...]

Output: resources/drawables/dial_<theme>.png (454x454 RGBA).
"""
import os
import sys

import gen_preview as gp
from gen_preview import (render_face, THEMES, TOKENS, DIAL_FILL, c_glob,
                         Canvas, paint_background, draw_text, downsample)
from gen_icons import write_png

OUT = os.path.join(os.path.dirname(__file__), "..", "resources", "drawables")

# DialTheme setting -> baked file. Accent (bronze/red) is applied to the live
# seconds hand at runtime, so it needs no separate bake.
BAKE = ["black_ceramic", "dawn"]


def render_digital_bg(size, theme, ss=3):
    """Background for the Digital/Sport styles: carved waves + trident +
    wordmark only. Time, date, gauges and data fields are drawn live."""
    S = size * ss
    cv = Canvas(S)
    c = S / 2.0
    R = (S / 2.0) * DIAL_FILL
    c_glob[0] = c
    T = dict(TOKENS)
    T.update(theme)
    paint_background(cv, R, T)
    gp.draw_sunrise_emblem(cv, c, c - 0.500 * R, R, T)
    draw_text(cv, "FIRST LIGHT", c, c - 0.385 * R, 0.044 * R, 0.0046 * R,
              T["TEXT_OMEGA"], total_w=0.300 * R)
    return downsample(cv, size, ss)


def main():
    ss = 3
    sel = []
    for a in sys.argv[1:]:
        if a.startswith("--ss="):
            ss = int(a[5:])
        elif a in THEMES:
            sel.append(a)
    names = sel or BAKE
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        img = render_face(454, THEMES[name], ss=ss, hands=False)
        p1 = os.path.join(OUT, "dial_%s.png" % name)
        write_png(img, p1)
        print("wrote %s (%d KB), ss=%d" % (
            os.path.relpath(p1), os.path.getsize(p1) // 1024, ss))
        img2 = render_digital_bg(454, THEMES[name], ss=ss)
        p2 = os.path.join(OUT, "dial_digital_%s.png" % name)
        write_png(img2, p2)
        print("wrote %s (%d KB), ss=%d" % (
            os.path.relpath(p2), os.path.getsize(p2) // 1024, ss))


if __name__ == "__main__":
    main()
