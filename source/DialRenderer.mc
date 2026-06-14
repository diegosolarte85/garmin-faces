import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;
using Toybox.WatchUi;

// Renders the *static* dial art (everything that does not change second-to-second)
// onto a Dc — either an off-screen buffer (fast path) or the screen (fallback).
// See specs/.../design.md §4 "Render pipeline".
class DialRenderer {
    private var _geo as Geometry;

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    public function draw(dc as Graphics.Dc, theme as Theme) as Void {
        Draw.aa(dc, true);
        dc.setColor(theme.ceramicBase(), theme.ceramicBase());
        dc.clear();

        waveField(dc, theme);
        vignette(dc, theme);
        bezel(dc, theme);
        chapterRing(dc, theme);
        hourMarkers(dc, theme);
        subdialRing(dc, theme, _geo.leftSubCenter(), theme.rhodium(), false);
        subdialRing(dc, theme, _geo.rightSubCenter(), theme.bronze(), true);
        dateAperture(dc, theme);
        dialPrint(dc, theme);
    }

    // --- laser-engraved wave field: horizontal striations + faint sine lines ---
    private function waveField(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        var rad = _geo.rad(_geo.DIAL_R);
        var lo = theme.waveLo();
        var hi = theme.waveHi();
        var y = (cy - rad).toNumber();
        var yEnd = (cy + rad).toNumber();
        while (y <= yEnd) {
            var dy = y - cy;
            var half = rad * rad - dy * dy;
            if (half > 0) {
                half = Math.sqrt(half);
                // striation brightness: smooth horizontal bands
                var t = 0.5 + 0.5 * Math.sin(dy / (rad * 0.05));
                dc.setColor(blend(lo, hi, t * 0.55), Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cx - half, y, cx + half, y);
            }
            y++;
        }
        // overlaid wavy lines for the unmistakable Seamaster ripple
        dc.setPenWidth(1);
        var rows = 22;
        for (var r = 0; r < rows; r++) {
            var baseY = cy - rad + (2.0 * rad) * (r + 0.5) / rows;
            var amp = rad * 0.012;
            var prevX = null; var prevY = null;
            var x = cx - rad;
            while (x <= cx + rad) {
                var yy = baseY + amp * Math.sin(x / (rad * 0.07) + r * 0.6);
                if (insideDial(x, yy, cx, cy, rad)) {
                    if (prevX != null) {
                        dc.setColor(blend(lo, hi, 0.5), Graphics.COLOR_TRANSPARENT);
                        dc.drawLine(prevX, prevY, x, yy);
                    }
                    prevX = x; prevY = yy;
                } else {
                    prevX = null; prevY = null;
                }
                x += 5.0;
            }
        }
    }

    private function insideDial(x as Numeric, y as Numeric, cx as Numeric, cy as Numeric, rad as Numeric) as Boolean {
        var dx = x - cx; var dy = y - cy;
        return (dx * dx + dy * dy) <= rad * rad;
    }

    // Soft darkening toward the rim for depth.
    private function vignette(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        var r0 = _geo.rad(_geo.DIAL_R);
        dc.setColor(theme.ceramicBase(), Graphics.COLOR_TRANSPARENT);
        var steps = 8;
        for (var i = 0; i < steps; i++) {
            var rr = r0 * (1.0 - 0.02 * i);
            dc.setPenWidth((r0 * 0.03).toNumber() + 1);
            dc.drawCircle(cx, cy, rr);
        }
        dc.setPenWidth(1);
    }

    // --- polished ceramic bezel with white-enamel dive scale ---
    private function bezel(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        var rOut = _geo.rad(_geo.BEZEL_OUTER);
        var rIn = _geo.rad(_geo.BEZEL_INNER);
        // ring fill
        dc.setColor(theme.bezel(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((rOut - rIn).toNumber() + 1);
        dc.drawCircle(cx, cy, (rOut + rIn) / 2.0);
        dc.setPenWidth(1);
        // enamel hairline
        dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rIn);

        for (var m = 0; m < 60; m++) {
            var frac = m / 60.0;
            var major = (m % 5 == 0);
            var a = frac * 2.0 * Math.PI;
            var rr1 = major ? rIn + (rOut - rIn) * 0.18 : rIn + (rOut - rIn) * 0.34;
            var rr2 = rOut - (rOut - rIn) * 0.14;
            dc.setPenWidth(major ? 3 : 1);
            dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
            var p1 = _geo.ptAt(cx, cy, a, rr1);
            var p2 = _geo.ptAt(cx, cy, a, rr2);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        dc.setPenWidth(1);
        // dive-scale numerals
        var nums = [10, 20, 30, 40, 50];
        for (var i = 0; i < nums.size(); i++) {
            var frac = nums[i] / 60.0;
            var p = _geo.ptFrac(frac, _geo.BEZEL_INNER + (_geo.BEZEL_OUTER - _geo.BEZEL_INNER) * 0.5);
            dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(p[0], p[1], Graphics.FONT_XTINY, nums[i].toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        // luminous pip triangle at 12 (0/60)
        var top = _geo.ptFrac(0.0, _geo.BEZEL_INNER + (_geo.BEZEL_OUTER - _geo.BEZEL_INNER) * 0.5);
        var s = _geo.rad(0.030);
        var tri = [[top[0], top[1] - s], [top[0] - s, top[1] + s * 0.7], [top[0] + s, top[1] + s * 0.7]];
        dc.setColor(theme.lume(), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(tri);
    }

    // --- minute/seconds chapter ring ---
    private function chapterRing(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        for (var m = 0; m < 60; m++) {
            var frac = m / 60.0;
            var a = frac * 2.0 * Math.PI;
            var major = (m % 5 == 0);
            var rOuter = _geo.rad(_geo.CHAPTER_R);
            var rInner = major ? _geo.rad(_geo.CHAPTER_R - 0.030) : _geo.rad(_geo.CHAPTER_R - 0.016);
            dc.setPenWidth(major ? 2 : 1);
            dc.setColor(major ? theme.enamel() : theme.textDim(), Graphics.COLOR_TRANSPARENT);
            var p1 = _geo.ptAt(cx, cy, a, rOuter);
            var p2 = _geo.ptAt(cx, cy, a, rInner);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        dc.setPenWidth(1);
    }

    // --- applied rhodium hour markers with lume inlay (double bar at 12) ---
    private function hourMarkers(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        for (var h = 0; h < 12; h++) {
            var frac = h / 12.0;
            var a = frac * 2.0 * Math.PI;
            var sinT = Math.sin(a); var cosT = Math.cos(a);
            var rO = R * _geo.MARKER_OUTER;
            var rI = R * _geo.MARKER_INNER;
            var midR = (rO + rI) / 2.0;
            var len = (rO - rI) / 2.0;
            var w = R * 0.030;
            // center of marker
            var mx = cx + midR * sinT; var my = cy - midR * cosT;
            if (h == 0) {
                // double baton at 12
                marker(dc, theme, mx - (R * 0.028) * cosT, my - (R * 0.028) * sinT, sinT, cosT, len, w * 0.72);
                marker(dc, theme, mx + (R * 0.028) * cosT, my + (R * 0.028) * sinT, sinT, cosT, len, w * 0.72);
            } else {
                marker(dc, theme, mx, my, sinT, cosT, len, w);
            }
        }
    }

    private function marker(dc as Graphics.Dc, theme as Theme, mx as Numeric, my as Numeric,
                            sinT as Numeric, cosT as Numeric, len as Numeric, w as Numeric) as Void {
        var body = [[-w, -len], [w, -len], [w, len], [-w, len]];
        Draw.poly(dc, mx, my, sinT, cosT, body, theme.rhodiumLo());
        var body2 = [[-w * 0.84, -len * 0.96], [w * 0.84, -len * 0.96], [w * 0.84, len * 0.96], [-w * 0.84, len * 0.96]];
        Draw.poly(dc, mx, my, sinT, cosT, body2, theme.rhodiumHi());
        var lume = [[-w * 0.5, -len * 0.8], [w * 0.5, -len * 0.8], [w * 0.5, len * 0.8], [-w * 0.5, len * 0.8]];
        Draw.poly(dc, mx, my, sinT, cosT, lume, theme.lume());
    }

    // --- subdial ring (azurage detail + ticks); hand drawn dynamically ---
    private function subdialRing(dc as Graphics.Dc, theme as Theme, c as Array,
                                 ringColor as Number, bronzeRing as Boolean) as Void {
        var cx = c[0]; var cy = c[1];
        var r = _geo.rad(_geo.SUB_R);
        // recessed face
        dc.setColor(blend(theme.ceramicBase(), theme.waveHi(), 0.35), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        // outer ring
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((r * 0.16).toNumber() + 1);
        dc.drawCircle(cx, cy, r * 0.92);
        if (bronzeRing) {
            dc.setColor(theme.bronzeHi(), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawCircle(cx, cy, r * 0.99);
        }
        dc.setPenWidth(1);
        // ticks
        for (var i = 0; i < 12; i++) {
            var a = (i / 12.0) * 2.0 * Math.PI;
            var p1 = _geo.ptAt(cx, cy, a, r * 0.82);
            var p2 = _geo.ptAt(cx, cy, a, r * 0.70);
            dc.setColor(theme.textDim(), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        // sub-pinion
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 0.10);
    }

    // --- date aperture frame at 6 (number drawn dynamically) ---
    private function dateAperture(dc as Graphics.Dc, theme as Theme) as Void {
        var c = _geo.dateCenter();
        var w = _geo.rad(0.085); var h = _geo.rad(0.060);
        dc.setColor(theme.rhodiumHi(), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(c[0] - w - 2, c[1] - h - 2, 2 * (w + 2), 2 * (h + 2));
        dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(c[0] - w, c[1] - h, 2 * w, 2 * h);
    }

    // --- dial print: Omega mark + wordmarks ---
    private function dialPrint(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        omegaMark(dc, theme, cx, cy - R * 0.52, R * 0.060);
        dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - R * 0.40, Graphics.FONT_XTINY, "OMEGA",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(theme.poppyRed(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - R * 0.295, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.DialBrand) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(theme.textDim(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - R * 0.215, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.DialLine1) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, cy + R * 0.235, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.DialChrono) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Stylised Omega Ω: arc open at the bottom with two feet.
    private function omegaMark(dc as Graphics.Dc, theme as Theme, cx as Numeric, cy as Numeric, r as Numeric) as Void {
        dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((r * 0.34).toNumber() + 1);
        // Garmin arc: 0deg=3 o'clock, CCW. Leave a gap at the bottom (~270deg).
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 310, 230);
        dc.setPenWidth(1);
        // feet
        var fy = cy + r * 0.55;
        var fw = r * 0.30; var fh = r * 0.22;
        dc.fillRectangle(cx - r * 0.78 - fw / 2, fy, fw, fh);
        dc.fillRectangle(cx + r * 0.78 - fw / 2, fy, fw, fh);
    }

    // 5-6-5 channel blend between two RGB colors, t in [0,1].
    public static function blend(a as Number, b as Number, t as Numeric) as Number {
        if (t <= 0) { return a; }
        if (t >= 1) { return b; }
        var ar = (a >> 16) & 0xFF; var ag = (a >> 8) & 0xFF; var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF; var bg = (b >> 8) & 0xFF; var bb = b & 0xFF;
        var r = (ar + (br - ar) * t).toNumber();
        var g = (ag + (bg - ag) * t).toNumber();
        var bl = (ab + (bb - ab) * t).toNumber();
        return (r << 16) | (g << 8) | bl;
    }
}
