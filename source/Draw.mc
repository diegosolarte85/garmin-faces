import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;

// Small shared drawing helpers. Local hand/marker geometry is authored in a
// coordinate frame that points "up" (toward 12): u = lateral, v = along the
// length toward the tip. transform() rotates+translates it onto the dial.
module Draw {

    // Map a local (u,v) point to screen coords given a precomputed rotation.
    function tp(cx as Numeric, cy as Numeric, sinT as Numeric, cosT as Numeric,
                u as Numeric, v as Numeric) as Array {
        return [cx + u * cosT + v * sinT, cy + u * sinT - v * cosT];
    }

    // Fill a polygon defined in local (u,v) space, rotated by angle and centered.
    function poly(dc as Graphics.Dc, cx as Numeric, cy as Numeric, sinT as Numeric,
                  cosT as Numeric, locals as Array, color as Number) as Void {
        var pts = new Array[locals.size()];
        for (var i = 0; i < locals.size(); i++) {
            var l = locals[i];
            pts[i] = tp(cx, cy, sinT, cosT, l[0], l[1]);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    function aa(dc as Graphics.Dc, on as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(on);
        }
    }

    // Filled disc convenience.
    function dot(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
    }
}
