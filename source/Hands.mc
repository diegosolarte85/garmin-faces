import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;

// Skeleton rhodium sword hour/minute hands + rose-bronze central chrono
// needle (specs/001-bond-seamaster-007-first-light/fidelity-v2.md §2.10, §3).
// The point tables below are the shared shape data of the §5 parity rule and
// mirror tools/gen_preview.py paint_hour_hand / paint_minute_hand /
// paint_chrono_hand / paint_hub literally. Every value is a fraction of R —
// no hard-coded pixels. Local hand frame: u = lateral, v = along the hand
// toward the tip (Draw.tp rotates it onto the dial).
class Hands {
    private var _geo as Geometry;

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    // --- shared local-frame helpers ---

    private function sincos(frac as Numeric) as Array {
        var a = frac * 2.0 * Math.PI;
        return [Math.sin(a), Math.cos(a)];
    }

    // Fill a polygon authored in R-fraction local coordinates.
    private function fpoly(dc as Graphics.Dc, sinT as Numeric, cosT as Numeric,
                           pts as Array, color as Number) as Void {
        var R = _geo.R;
        var n = pts.size();
        var px = new Array[n];
        for (var i = 0; i < n; i++) {
            var p = pts[i];
            px[i] = [R * p[0], R * p[1]];
        }
        Draw.poly(dc, _geo.cx, _geo.cy, sinT, cosT, px, color);
    }

    // Stroke a facet edge between two local-frame points (hw = half-width,
    // all in R-fractions) as a thin filled quad.
    private function edge(dc as Graphics.Dc, sinT as Numeric, cosT as Numeric,
                          u0 as Numeric, v0 as Numeric, u1 as Numeric, v1 as Numeric,
                          hw as Numeric, color as Number) as Void {
        var R = _geo.R;
        var p0 = Draw.tp(_geo.cx, _geo.cy, sinT, cosT, R * u0, R * v0);
        var p1 = Draw.tp(_geo.cx, _geo.cy, sinT, cosT, R * u1, R * v1);
        strokePx(dc, p0[0], p0[1], p1[0], p1[1], R * hw, color);
    }

    // Thin filled quad between two screen points (hw = half-width in px).
    private function strokePx(dc as Graphics.Dc, x0 as Numeric, y0 as Numeric,
                              x1 as Numeric, y1 as Numeric, hw as Numeric,
                              color as Number) as Void {
        var dx = x1 - x0;
        var dy = y1 - y0;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.001) { return; }
        var nx = -dy / len * hw;
        var ny = dx / len * hw;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x0 + nx, y0 + ny], [x1 + nx, y1 + ny],
                        [x1 - nx, y1 - ny], [x0 - nx, y0 - ny]]);
    }

    // Rhodium rail lighting: light falls from the upper-left, so whichever
    // flank faces it takes STEEL_HI (mirrors gen_preview.py lit_sides()).
    private function litRight(sinT as Numeric, cosT as Numeric) as Boolean {
        return (cosT * -0.6 + sinT * -0.8) > 0;
    }

    // Hour-sword outer half-width at axial position v: linear flare from the
    // hub exit toward the lume circle (mirrors gen_preview.py w_at()).
    private function hourHalfW(v as Numeric) as Numeric {
        var wHub = _geo.HOUR_W_HUB * 0.5;   // 0.023
        var wMax = _geo.HOUR_W_MAX * 0.5;   // 0.060 at the lume circle
        return wHub + (wMax - wHub) * (v - 0.05) / (_geo.HOUR_LUME_POS - 0.05);
    }

    // --- public hands (signatures unchanged) ---

    // Blunt-tipped skeleton sword: solid stem, open slot 0.119->0.302 showing
    // the dial through, solid blade block with a circular lume window.
    public function drawHour(dc as Graphics.Dc, theme as Theme, frac as Float) as Void {
        var sc = sincos(frac);
        var sinT = sc[0];
        var cosT = sc[1];
        var right = litRight(sinT, cosT);
        var railL = right ? theme.steelLo() : theme.steelHi();
        var railR = right ? theme.steelHi() : theme.steelLo();

        var vIn = _geo.HOUR_SLOT_IN;    // 0.119
        var vOut = _geo.HOUR_SLOT_OUT;  // 0.302
        var vLume = _geo.HOUR_LUME_POS; // 0.372
        var L = _geo.HOUR_LEN;          // 0.440, blunt chamfered end
        var wIn = hourHalfW(vIn);
        var wOut = hourHalfW(vOut);
        var wHub = _geo.HOUR_W_HUB * 0.5;
        var wMax = _geo.HOUR_W_MAX * 0.5;
        var rail = _geo.HAND_RAIL_W;
        var hwF = _geo.HAND_FRAME_STROKE * 0.5;

        // solid stem from the hub to the slot mouth
        fpoly(dc, sinT, cosT,
              [[-wHub, 0.030], [-wIn, vIn], [wIn, vIn], [wHub, 0.030]],
              theme.steel());
        // open skeleton rails — dial stays visible between them
        fpoly(dc, sinT, cosT,
              [[-wIn, vIn], [-wOut, vOut], [-(wOut - rail), vOut], [-(wIn - rail), vIn]],
              railL);
        fpoly(dc, sinT, cosT,
              [[wIn, vIn], [wOut, vOut], [wOut - rail, vOut], [wIn - rail, vIn]],
              railR);
        // crossbar closing the slot mouth
        fpoly(dc, sinT, cosT,
              [[-wIn, 0.105], [wIn, 0.105], [wIn, 0.121], [-wIn, 0.121]],
              theme.steel());
        // solid blade block 0.302 -> tip, wide chamfered flat end (no point);
        // 0.046@0.433 / 0.032@tip are the shared chamfer table (parity §5)
        fpoly(dc, sinT, cosT,
              [[-wOut, vOut], [-wMax, vLume], [-0.046, 0.433], [-0.032, L],
               [0.032, L], [0.046, 0.433], [wMax, vLume], [wOut, vOut]],
              theme.steel());
        // polished facet strokes along the blade edges
        edge(dc, sinT, cosT, -wOut, vOut, -wMax, vLume, hwF, railL);
        edge(dc, sinT, cosT, -wMax, vLume, -0.040, L, hwF, railL);
        edge(dc, sinT, cosT, wOut, vOut, wMax, vLume, hwF, railR);
        edge(dc, sinT, cosT, wMax, vLume, 0.040, L, hwF, railR);
        // circular lume window at 0.372, framed by a dark step
        var R = _geo.R;
        var lp = Draw.tp(_geo.cx, _geo.cy, sinT, cosT, 0.0, R * vLume);
        Draw.dot(dc, lp[0], lp[1], R * (_geo.HOUR_LUME_R + hwF), theme.steelLo());
        Draw.dot(dc, lp[0], lp[1], R * _geo.HOUR_LUME_R, theme.lumeHand());
    }

    // Lance minute hand: open slot 0.110->0.503, neck flaring into a solid
    // white lume arrowhead whose apex is the needle point at MIN_LEN.
    public function drawMinute(dc as Graphics.Dc, theme as Theme, frac as Float) as Void {
        var sc = sincos(frac);
        var sinT = sc[0];
        var cosT = sc[1];
        var right = litRight(sinT, cosT);
        var railL = right ? theme.steelLo() : theme.steelHi();
        var railR = right ? theme.steelHi() : theme.steelLo();

        var vIn = _geo.MIN_SLOT_IN;          // 0.110
        var vOut = _geo.MIN_SLOT_OUT;        // 0.503
        var vBase = _geo.MIN_ARROW_BASE;     // 0.530
        var L = _geo.MIN_LEN;                // 0.680
        var half = _geo.MIN_W * 0.5;         // 0.024 shaft half-width
        var railIn = half - _geo.HAND_RAIL_W;
        var aHalf = _geo.MIN_ARROW_W * 0.5;  // 0.0525 arrowhead half-base

        // solid base from the hub to the slot mouth
        fpoly(dc, sinT, cosT,
              [[-half, 0.030], [-half, vIn], [half, vIn], [half, 0.030]],
              theme.steel());
        // open skeleton rails
        fpoly(dc, sinT, cosT,
              [[-half, vIn], [-half, vOut], [-railIn, vOut], [-railIn, vIn]],
              railL);
        fpoly(dc, sinT, cosT,
              [[half, vIn], [half, vOut], [railIn, vOut], [railIn, vIn]],
              railR);
        // crossbar closing the slot mouth
        fpoly(dc, sinT, cosT,
              [[-half, 0.100], [half, 0.100], [half, 0.114], [-half, 0.114]],
              theme.steel());
        // neck flaring into the arrow base
        fpoly(dc, sinT, cosT,
              [[-half, vOut], [-aHalf, vBase], [aHalf, vBase], [half, vOut]],
              theme.steel());
        // solid lume arrowhead, bordered in STEEL_HI (border 0.007 -> hw 0.0035)
        fpoly(dc, sinT, cosT,
              [[-aHalf, vBase], [0.0, L], [aHalf, vBase]],
              theme.lumeHand());
        edge(dc, sinT, cosT, -aHalf, vBase, 0.0, L, 0.0035, theme.steelHi());
        edge(dc, sinT, cosT, aHalf, vBase, 0.0, L, 0.0035, theme.steelHi());
        edge(dc, sinT, cosT, -aHalf, vBase, aHalf, vBase, 0.0035, theme.steelHi());
    }

    // Central chrono needle: thin bronze shaft faceted LO->MID->HI along its
    // length, small arrow tip to a fine point at the tick band, lume lollipop
    // annulus mid-needle at 0.485, plain square-ended tail to 0.270 — no
    // counterweight disc (§2.10). Accent tokens keep the red-accent setting.
    public function drawSeconds(dc as Graphics.Dc, theme as Theme, frac as Float) as Void {
        var sc = sincos(frac);
        var sinT = sc[0];
        var cosT = sc[1];
        var hw = _geo.SEC_W * 0.5;  // 0.005 needle half-width
        var L = _geo.SEC_LEN;       // 0.730

        // plain tail, square end
        fpoly(dc, sinT, cosT,
              [[-hw, -_geo.SEC_TAIL], [hw, -_geo.SEC_TAIL], [hw, 0.0], [-hw, 0.0]],
              theme.accentLo());
        // main shaft
        fpoly(dc, sinT, cosT,
              [[-hw, 0.0], [hw, 0.0], [hw, 0.50], [-hw, 0.50]],
              theme.accentMain());
        // fore-needle, slightly narrower, lit facet
        fpoly(dc, sinT, cosT,
              [[-hw * 0.9, 0.50], [hw * 0.9, 0.50], [hw * 0.9, 0.66], [-hw * 0.9, 0.66]],
              theme.accentHi());
        // small diamond arrow tip closing to a fine point at SEC_LEN
        fpoly(dc, sinT, cosT,
              [[0.0, 0.66], [hw * 2.2, 0.695], [0.0, L], [-hw * 2.2, 0.695]],
              theme.accentHi());
        // mid-needle lume lollipop: bronze annulus + hot lume fill
        var R = _geo.R;
        var lp = Draw.tp(_geo.cx, _geo.cy, sinT, cosT, 0.0, R * _geo.SEC_LOLLIPOP_POS);
        Draw.dot(dc, lp[0], lp[1], R * _geo.SEC_LOLLIPOP_R, theme.accentMain());
        Draw.dot(dc, lp[0], lp[1], R * _geo.SEC_LOLLIPOP_LUME, theme.lumeGlow());
    }

    // Hub: polished steel ring capped by a bronze disc with a dark screw
    // slot and a small specular glint — the hub reads bronze, not steel.
    public function drawHub(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx;
        var cy = _geo.cy;
        var R = _geo.R;
        var outer = R * _geo.HAND_HUB_R;
        var inner = R * (_geo.HAND_HUB_R - _geo.HUB_RING_W);
        var pw = (outer - inner + 0.5).toNumber();
        if (pw < 1) { pw = 1; }
        dc.setColor(theme.steel(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw);
        dc.drawCircle(cx, cy, (outer + inner) * 0.5);
        dc.setPenWidth(1);
        // bronze cap
        Draw.dot(dc, cx, cy, R * _geo.HUB_CAP_R, theme.accentMain());
        // dark screw slot across the cap at 35 deg (half-length 0.020)
        var a = 35.0 * Math.PI / 180.0;
        var sx = Math.sin(a) * R * 0.020;
        var sy = -Math.cos(a) * R * 0.020;
        strokePx(dc, cx - sx, cy - sy, cx + sx, cy + sy,
                 R * _geo.HUB_SLOT_W * 0.5, theme.bronzeSlot());
        // upper-left specular glint
        Draw.dot(dc, cx - R * 0.008, cy - R * 0.008, R * 0.007, theme.accentHi());
    }
}
