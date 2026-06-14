import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;

// Rhodium broad-arrow hour/minute hands with white-lume inlays, and a thin
// bronze-gold lollipop central seconds hand. (specs/.../design.md §2 "Hand shapes")
class Hands {
    private var _geo as Geometry;

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    private function sincos(frac as Numeric) as Array {
        var a = frac * 2.0 * Math.PI;
        return [Math.sin(a), Math.cos(a)];
    }

    // Broad-arrow body + lume inlay. widthScale lets minute be slimmer/longer.
    private function broadArrow(len as Float, wBody as Float, wShoulder as Float,
                                tail as Float) as Array {
        var L = len;
        return [
            [-wBody * 0.6, -tail],
            [ wBody * 0.6, -tail],
            [ wBody,        L * 0.34],
            [ wShoulder,    L * 0.70],
            [ 0.0,          L],
            [-wShoulder,    L * 0.70],
            [-wBody,        L * 0.34]
        ];
    }

    public function drawHour(dc as Graphics.Dc, theme as Theme, frac as Float) as Void {
        var sc = sincos(frac);
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var len = R * _geo.HOUR_LEN;
        var body = broadArrow(len, R * 0.050, R * 0.044, R * 0.105);
        // shadow edge, body, then lume inlay
        Draw.poly(dc, cx, cy, sc[0], sc[1], body, theme.rhodiumLo());
        var body2 = broadArrow(len * 0.985, R * 0.044, R * 0.038, R * 0.095);
        Draw.poly(dc, cx, cy, sc[0], sc[1], body2, theme.rhodium());
        var spine = broadArrow(len * 0.96, R * 0.020, R * 0.018, R * 0.04);
        Draw.poly(dc, cx, cy, sc[0], sc[1], spine, theme.rhodiumHi());
        // lume inlay window
        var lume = lumeWindow(len, R * 0.028, R * 0.34, R * 0.66);
        Draw.poly(dc, cx, cy, sc[0], sc[1], lume, theme.lume());
    }

    public function drawMinute(dc as Graphics.Dc, theme as Theme, frac as Float) as Void {
        var sc = sincos(frac);
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var len = R * _geo.MIN_LEN;
        var body = broadArrow(len, R * 0.038, R * 0.032, R * 0.110);
        Draw.poly(dc, cx, cy, sc[0], sc[1], body, theme.rhodiumLo());
        var body2 = broadArrow(len * 0.99, R * 0.032, R * 0.027, R * 0.10);
        Draw.poly(dc, cx, cy, sc[0], sc[1], body2, theme.rhodium());
        var spine = broadArrow(len * 0.965, R * 0.015, R * 0.013, R * 0.05);
        Draw.poly(dc, cx, cy, sc[0], sc[1], spine, theme.rhodiumHi());
        var lume = lumeWindow(len, R * 0.020, R * 0.40, R * 0.74);
        Draw.poly(dc, cx, cy, sc[0], sc[1], lume, theme.lume());
    }

    // A slim diamond-ish lume window between vLo and vHi along the hand.
    private function lumeWindow(len as Float, w as Float, vLo as Float, vHi as Float) as Array {
        return [
            [0.0, vLo],
            [w,   (vLo + vHi) / 2.0],
            [0.0, vHi],
            [-w,  (vLo + vHi) / 2.0]
        ];
    }

    // Bronze-gold central seconds: needle + lume lollipop + counterweight.
    public function drawSeconds(dc as Graphics.Dc, theme as Theme, frac as Float) as Void {
        var sc = sincos(frac);
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var len = R * _geo.SEC_LEN;
        var tail = R * _geo.SEC_TAIL;
        var w = R * 0.011;
        // needle
        var needle = [
            [-w * 0.4, -tail],
            [ w * 0.4, -tail],
            [ w,        len * 0.55],
            [ w * 0.35, len],
            [-w * 0.35, len],
            [-w,        len * 0.55]
        ];
        Draw.poly(dc, cx, cy, sc[0], sc[1], needle, theme.accentMain());
        // lollipop lume disc near tip
        var lp = Draw.tp(cx, cy, sc[0], sc[1], 0.0, len * 0.80);
        Draw.dot(dc, lp[0], lp[1], R * _geo.SEC_LOLLIPOP_R, theme.accentMain());
        Draw.dot(dc, lp[0], lp[1], R * _geo.SEC_LOLLIPOP_R * 0.6, theme.lume());
        // counterweight
        var cwBase = Draw.tp(cx, cy, sc[0], sc[1], 0.0, -tail * 0.55);
        Draw.dot(dc, cwBase[0], cwBase[1], R * 0.026, theme.accentMain());
        Draw.dot(dc, cwBase[0], cwBase[1], R * 0.012, theme.accentHi());
    }

    public function drawHub(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        Draw.dot(dc, cx, cy, R * _geo.HAND_HUB_R, theme.rhodiumLo());
        Draw.dot(dc, cx, cy, R * _geo.HAND_HUB_R * 0.78, theme.rhodiumHi());
        Draw.dot(dc, cx, cy, R * _geo.HAND_HUB_R * 0.42, theme.accentMain());
    }
}
