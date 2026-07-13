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

from gen_preview import render_face, THEMES
from gen_icons import write_png

OUT = os.path.join(os.path.dirname(__file__), "..", "resources", "drawables")

# DialTheme setting -> baked file. Accent (bronze/red) is applied to the live
# seconds hand at runtime, so it needs no separate bake.
BAKE = ["black_ceramic", "dawn"]


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
        # active (bright) dial
        img = render_face(454, THEMES[name], ss=ss, hands=False)
        p1 = os.path.join(OUT, "dial_%s.png" % name)
        write_png(img, p1)
        # dimmed dial for always-on display
        dimg = render_face(454, THEMES[name], ss=ss, hands=False, dim=True)
        p2 = os.path.join(OUT, "dim_%s.png" % name)
        write_png(dimg, p2)
        print("wrote %s (%d KB) + %s (%d KB), ss=%d" % (
            os.path.relpath(p1), os.path.getsize(p1) // 1024,
            os.path.relpath(p2), os.path.getsize(p2) // 1024, ss))


if __name__ == "__main__":
    main()
