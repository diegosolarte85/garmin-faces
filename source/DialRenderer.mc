import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;

// Renders the *static* dial art (everything that does not change second-to-second)
// onto a Dc — either an off-screen buffer (fast path) or the screen (fallback).
// Implements specs/001-bond-seamaster-007-first-light/fidelity-v2.md §2-§3:
//   1. carved wave field (per-scanline gloss base + crest highlight / groove
//      shadow strokes per row, §2.11/§3),
//   2. bezel: dot track, batons, outlined triangle + pearl, rotated stroked
//      numerals 10..50 (§2.2/§3 — fonts cannot rotate, so glyphs are shared
//      polyline path data),
//   3. minute-track flange (§2.3), round hour markers + double bar at 12 +
//      displaced 3/6/9 plots (§2.4-2.6),
//   4. subdial static art: recess flange, snailed centers, left white scale,
//      right wide bronze ring with black print (§2.7),
//   5. framed date aperture (§2.8) and the full text stack (§2.9).
// All geometry derives from Geometry tokens (fractions of R); the few spec
// numbers that are not shared tokens live here as scalar consts with § refs.
class DialRenderer {
    private var _geo as Geometry;

    // --- spec-local scalars (fractions of R unless noted) ---
    private const WAVE_HI_W    = 0.014; // §3 crest highlight stroke width
    private const WAVE_GR_W    = 0.011; // §3 groove shadow stroke width
    private const WAVE_STEP    = 0.075; // polyline x-step (coarse: watchdog budget)
    private const WAVE_PH_AMP  = 0.040; // §2.11 phase drift, fraction of wavelength
    private const WAVE_PH_RATE = 0.630; // rad/row — ±0.04 over ~5 rows
    private const GLOSS_MAX    = 0.230; // §3 gloss gradient blend cap (top third)
    private const BZ_SHEEN_W   = 0.030; // §3 outer bezel blend band
    private const NUM_ARC_DEG  = 13.0;  // §2.2 digit pair subtends ~13 deg
    private const DATE_BEVEL   = 0.014; // §2.8 frame bevel width
    private const MARKER_HI_W  = 0.005; // §2.4 rim top-left highlight arc pen
    private const SWISS_OFF    = 0.030; // dial fraction: SWISS/MADE word offset
    // sub-dial digit proportions (relative to cap height)
    private const DIGIT_W_RATIO      = 0.62;
    private const DIGIT_GAP_RATIO    = 0.20;
    private const DIGIT_STROKE_RATIO = 0.18;

    // Shared stroked-glyph path data (fidelity-v2.md §3 "Bezel numerals"):
    // Omega's rounded dive grotesque. Each digit is an array of polylines in a
    // unit box, x in [0,1] left->right, y in [0,1] top->bottom. The identical
    // table feeds tools/gen_preview.py (parity rule §5).
    // Var (not const): Monkey C const initializers must be scalar.
    private var _digits as Dictionary = {
        0 => [[[0.30, 0.05], [0.70, 0.05], [0.95, 0.28], [0.95, 0.72],
               [0.70, 0.95], [0.30, 0.95], [0.05, 0.72], [0.05, 0.28],
               [0.30, 0.05]]],
        1 => [[[0.28, 0.30], [0.62, 0.05], [0.62, 0.95]]],
        2 => [[[0.08, 0.28], [0.20, 0.08], [0.50, 0.03], [0.80, 0.08],
               [0.92, 0.28], [0.88, 0.48], [0.08, 0.95], [0.95, 0.95]]],
        3 => [[[0.08, 0.05], [0.92, 0.05], [0.48, 0.42], [0.78, 0.47],
               [0.94, 0.66], [0.84, 0.88], [0.50, 0.96], [0.16, 0.88],
               [0.06, 0.72]]],
        4 => [[[0.72, 0.05], [0.06, 0.64], [0.96, 0.64]],
              [[0.72, 0.05], [0.72, 0.95]]],
        5 => [[[0.90, 0.05], [0.14, 0.05], [0.09, 0.46], [0.48, 0.38],
               [0.82, 0.46], [0.95, 0.66], [0.85, 0.88], [0.50, 0.96],
               [0.16, 0.88], [0.06, 0.72]]],
        6 => [[[0.82, 0.10], [0.52, 0.03], [0.22, 0.14], [0.07, 0.42],
               [0.06, 0.70], [0.20, 0.91], [0.50, 0.97], [0.80, 0.90],
               [0.93, 0.70], [0.83, 0.52], [0.50, 0.44], [0.14, 0.54]]],
        8 => [[[0.50, 0.05], [0.78, 0.11], [0.87, 0.26], [0.78, 0.41],
               [0.50, 0.47], [0.22, 0.41], [0.13, 0.26], [0.22, 0.11],
               [0.50, 0.05]],
              [[0.50, 0.47], [0.83, 0.55], [0.94, 0.72], [0.83, 0.90],
               [0.50, 0.97], [0.17, 0.90], [0.06, 0.72], [0.17, 0.55],
               [0.50, 0.47]]]
    };

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    // Static art entry point — called once into the buffered bitmap.
    // Number of progressive render stages (see drawStage). The static art is
    // far too heavy to draw in one call without tripping the on-device
    // execution watchdog, so BondSeamasterView paints ONE stage per frame into
    // the off-screen buffer until complete. Kept once and reused (no per-wake
    // rebuild).
    public const STAGE_COUNT = 7;

    // Full render in one pass — only the buffer-unavailable fallback path uses
    // this (real devices go through drawStage). Order matches drawStage.
    public function draw(dc as Graphics.Dc, theme as Theme) as Void {
        for (var s = 0; s < STAGE_COUNT; s++) {
            drawStage(dc, theme, s);
        }
    }

    // Render exactly one stage into dc. Returns true when `stage` was the last.
    // Each stage is bounded (<~500 draw ops) to stay under the watchdog budget.
    public function drawStage(dc as Graphics.Dc, theme as Theme, stage as Number) as Boolean {
        Draw.aa(dc, true);
        switch (stage) {
            case 0:
                dc.setColor(theme.ceramicBase(), theme.ceramicBase());
                dc.clear();
                waveBase(dc, theme);                 // §2.11 scanline gloss base
                break;
            case 1:
                waveLines(dc, theme, false);         // §3 crest highlights
                break;
            case 2:
                waveLines(dc, theme, true);          // §3 groove shadows
                break;
            case 3:
                bezel(dc, theme);                    // §2.2 + §3 (paints rehaut)
                break;
            case 4:
                minuteTrack(dc, theme);              // §2.3
                hourMarkers(dc, theme);              // §2.4-2.6
                break;
            case 5:
                subdialLeft(dc, theme);              // §2.7 left
                subdialRight(dc, theme);             // §2.7 right
                break;
            default:
                textStack(dc, theme);                // §2.9
                dateAperture(dc, theme);             // §2.8 (numeral dynamic)
                return true;
        }
        return false;
    }

    // ------------------------------------------------------------------
    // Wave field (§2.11): per-scanline gloss-graded base fill, then per row
    // a crest highlight band with the groove shadow immediately below it.
    // ------------------------------------------------------------------
    // Stage 0 helper: ridge-face fill with a broad gloss gradient over the top
    // third. Stride-3 scanlines with a 12-entry precomputed band LUT.
    private function waveBase(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        var dialR = _geo.rad(_geo.DIAL_R);
        var ridge = theme.waveRidge();
        var hi = theme.waveHi();
        var topThird = dialR / 3.0;
        var bands = new Array<Number>[12];
        for (var b = 0; b < 12; b++) {
            bands[b] = blend(ridge, hi, GLOSS_MAX * b / 11.0);
        }
        var lastCol = -1;
        var stride = 3;
        dc.setPenWidth(stride + 1);
        var y = (cy - dialR).toNumber() + 1;
        var yEnd = (cy + dialR).toNumber() - 1;
        while (y <= yEnd) {
            var dy = y - cy;
            var half = dialR * dialR - dy * dy;
            if (half > 0) {
                half = Math.sqrt(half);
                var col = ridge;
                if (dy < -topThird) {
                    var idx = (((-dy) - topThird) / (dialR - topThird) * 11.0).toNumber();
                    if (idx > 11) { idx = 11; }
                    col = bands[idx];
                }
                if (col != lastCol) {
                    dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                    lastCol = col;
                }
                dc.drawLine(cx - half, y, cx + half, y);
            }
            y += stride;
        }
        dc.setPenWidth(1);
    }

    // Stage 1/2 helper: carved wave rows, one undulating polyline per row.
    // `groove` false = crest highlight (offset 0), true = groove shadow
    // (offset grOff below the crest). Split across two frames so neither
    // pass exceeds the watchdog budget.
    private function waveLines(dc as Graphics.Dc, theme as Theme, groove as Boolean) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var dialR = _geo.rad(_geo.DIAL_R);
        var rr2 = (dialR - 1.0) * (dialR - 1.0);
        var amp = R * _geo.WAVE_AMP;
        var k = 2.0 * Math.PI / (R * _geo.WAVE_LEN);
        var step = R * WAVE_STEP;
        var pitch = R * _geo.WAVE_PITCH;
        var grOff = groove ? R * (WAVE_HI_W + WAVE_GR_W) / 2.0 : 0.0;
        var grooveCol = theme.waveGroove();
        var hiCol = theme.waveHi();
        var glossCol = theme.waveGloss();
        var nRows = ((dialR + amp) / pitch).toNumber() + 1;
        dc.setPenWidth(groove ? penW(R * WAVE_GR_W) : penW(R * WAVE_HI_W));
        for (var i = -nRows; i <= nRows; i++) {
            var ph = 2.0 * Math.PI * WAVE_PH_AMP * Math.sin(i * WAVE_PH_RATE);
            var rowY = i * pitch;
            var have = false;
            var px = 0.0; var py = 0.0;
            var x = cx - dialR;
            var xEnd = cx + dialR;
            while (x <= xEnd) {
                var yy = cy + rowY + amp * Math.sin(k * (x - cx) + ph);
                var dx = x - cx; var dy = yy - cy;
                if (dx * dx + dy * dy <= rr2) {
                    if (have) {
                        if (groove) {
                            dc.setColor(grooveCol, Graphics.COLOR_TRANSPARENT);
                            dc.drawLine(px, py + grOff, x, yy + grOff);
                        } else {
                            dc.setColor((x < cx && yy < cy) ? glossCol : hiCol,
                                        Graphics.COLOR_TRANSPARENT);
                            dc.drawLine(px, py, x, yy);
                        }
                    }
                    px = x; py = yy; have = true;
                } else {
                    have = false;
                }
                x += step;
            }
        }
        dc.setPenWidth(1);
    }

    // ------------------------------------------------------------------
    // Bezel (§2.2 + §3): ceramic band, sheen, rehaut, dot track, batons,
    // numeral ticks, rotated stroked numerals, outlined triangle + pearl.
    // ------------------------------------------------------------------
    private function bezel(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var rOut = _geo.rad(_geo.BEZEL_OUTER);
        var rIn = _geo.rad(_geo.BEZEL_INNER);
        var midR = (rOut + rIn) / 2.0;
        var bandW = rOut - rIn;

        // band fill
        dc.setColor(theme.bezel(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(bandW.toNumber() + 2);
        dc.drawCircle(cx, cy, midR);
        // outer 0.03 blend toward the sheen tone
        dc.setColor(theme.bezelSheen(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penW(R * BZ_SHEEN_W));
        dc.drawCircle(cx, cy, rOut - R * BZ_SHEEN_W / 2.0);
        // specular sheen arc, upper-left quadrant (Garmin degrees: CCW from 3 o'clock)
        dc.setPenWidth((bandW * 0.7).toNumber());
        dc.setColor(theme.bezelSheen(), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, midR, Graphics.ARC_COUNTER_CLOCKWISE, 100, 170);
        dc.setPenWidth((bandW * 0.4).toNumber());
        dc.setColor(theme.bezelSheenHi(), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, midR, Graphics.ARC_COUNTER_CLOCKWISE, 115, 155);

        // rehaut gasket ring + hairline at the bezel inner edge (§2.1)
        var rhIn = _geo.rad(_geo.REHAUT_IN);
        var rhOut = _geo.rad(_geo.REHAUT_OUT);
        dc.setColor(theme.rehaut(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((rhOut - rhIn).toNumber() + 1);
        dc.drawCircle(cx, cy, (rhOut + rhIn) / 2.0);
        dc.setPenWidth(1);
        dc.setColor(theme.rehautLine(), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rhOut);

        // minute-dot track: one dot per minute, skipped at 0 and at
        // baton/numeral angles (every 5th minute). No railroad ticks.
        var dotR = R * _geo.BZ_DOT_D / 2.0;
        for (var m = 1; m < 60; m++) {
            if (m % 5 == 0) { continue; }
            var a = (m / 60.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(cx, cy, a, R * _geo.BZ_DOT_TRACK);
            Draw.dot(dc, p[0], p[1], dotR, theme.bezelDot());
        }
        // 5-minute batons at 30/90/150/210/270/330 deg, squared ends
        for (var b = 0; b < 6; b++) {
            var a = ((b * 10 + 5) / 60.0) * 2.0 * Math.PI;
            radialBarAt(dc, cx, cy, a, R * _geo.BZ_BATON_IN, R * _geo.BZ_BATON_OUT,
                        R * _geo.BZ_BATON_W, theme.enamel());
        }
        // numeral-minute ticks at the numeral angles (between the digit pairs)
        for (var t = 1; t <= 5; t++) {
            var a = (t / 6.0) * 2.0 * Math.PI;
            radialBarAt(dc, cx, cy, a,
                        R * (_geo.BZ_DOT_TRACK - _geo.BZ_TICK_L / 2.0),
                        R * (_geo.BZ_DOT_TRACK + _geo.BZ_TICK_L / 2.0),
                        R * _geo.BZ_TICK_W, theme.enamel());
        }
        // rotated numerals 10..50 — stroked glyphs, each rotated by its own angle
        var digitW = (R * _geo.BZ_NUM_R * (NUM_ARC_DEG * Math.PI / 180.0)
                      - R * _geo.BZ_NUM_GAP) / 2.0;
        for (var v = 10; v <= 50; v += 10) {
            var a = (v / 60.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(cx, cy, a, R * _geo.BZ_NUM_R);
            drawNumeral(dc, v, p[0], p[1], a, R * _geo.BZ_NUM_CAP, digitW,
                        R * _geo.BZ_NUM_GAP, R * _geo.BZ_NUM_STROKE, theme.enamel());
        }

        bezelTriangle(dc, theme);
        bezelPearl(dc, theme);
    }

    // Outline-only triangle at 12 (§2.2): enamel outer fill, then the inner
    // triangle (edges inset by the stroke width, via the incenter) back in
    // bezel black.
    private function bezelTriangle(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var bw = _geo.BZ_TRI_HALF_W;             // tangential half-width
        var vb = _geo.BZ_TRI_BASE_R;             // base radius
        var va = _geo.BZ_TRI_APEX_R;             // apex radius (inward)
        var ht = vb - va;
        var slant = Math.sqrt(bw * bw + ht * ht);
        var icV = (2.0 * bw * va + 2.0 * slant * vb) / (2.0 * bw + 2.0 * slant);
        var inr = (bw * ht) / (bw + slant);      // inradius
        var kk = 1.0 - _geo.BZ_TRI_STROKE / inr; // edge inset scale
        if (kk < 0.2) { kk = 0.2; }
        var outer = [[cx - bw * R, cy - vb * R],
                     [cx + bw * R, cy - vb * R],
                     [cx, cy - va * R]];
        dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(outer);
        var inner = [[cx - bw * kk * R, cy - (icV + kk * (vb - icV)) * R],
                     [cx + bw * kk * R, cy - (icV + kk * (vb - icV)) * R],
                     [cx, cy - (icV + kk * (va - icV)) * R]];
        dc.setColor(theme.bezel(), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(inner);
    }

    // Lume pearl inside the triangle (§2.2): warm silver disc, rim, highlight arc.
    private function bezelPearl(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var px = cx; var py = cy - R * _geo.BZ_PEARL_R;
        var pr = R * _geo.BZ_PEARL_D / 2.0;
        Draw.dot(dc, px, py, pr, theme.lumePearl());
        dc.setColor(theme.pearlRim(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penW(R * _geo.BZ_PEARL_RIM));
        dc.drawCircle(px, py, pr);
        dc.setPenWidth(1);
        dc.setColor(theme.lumeGlow(), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(px, py, pr * 0.6, Graphics.ARC_COUNTER_CLOCKWISE, 100, 160);
    }

    // ------------------------------------------------------------------
    // Dial minute-track flange (§2.3): minute ticks, half-minute ticks and
    // the 4 Hz quarter-second dot arc, all FLANGE_WHITE; suppressed for
    // ±FLANGE_GAP_DEG around 180 (SWISS MADE / 6 o'clock plot).
    // ------------------------------------------------------------------
    private function minuteTrack(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        var col = theme.flangeWhite();
        var lo = 180 - _geo.FLANGE_GAP_DEG;
        var hi = 180 + _geo.FLANGE_GAP_DEG;
        // minute ticks every 6 deg. (Half-minute ticks and the quarter-second
        // dot ring were dropped: sub-pixel detail at watch size, and their
        // ~180 extra fill ops pushed the static render over the on-device
        // execution-watchdog budget.)
        for (var m = 0; m < 60; m++) {
            var deg = m * 6;
            if (deg > lo && deg < hi) { continue; }
            var a = deg * Math.PI / 180.0;
            radialBarAt(dc, cx, cy, a, R * _geo.TICK_IN, R * _geo.CHAPTER_R,
                        R * _geo.TICK_W, col);
        }
    }

    // ------------------------------------------------------------------
    // Applied markers (§2.4-2.6): round lume dots with polished rim + shadow
    // step ring, the broad double bar at 12, and the 3/6/9 lume plots.
    // ------------------------------------------------------------------
    private function hourMarkers(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        // round dots at 1,2,4,5,7,8,10,11
        for (var h = 1; h < 12; h++) {
            if (h == 3 || h == 6 || h == 9) { continue; }
            var a = (h / 12.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(cx, cy, a, R * _geo.MARKER_R);
            Draw.dot(dc, p[0], p[1], R * _geo.MARKER_SHADOW_R, theme.markerShadow());
            Draw.dot(dc, p[0], p[1], R * _geo.MARKER_RIM_R, theme.markerRim());
            Draw.dot(dc, p[0], p[1], R * _geo.MARKER_DOT_R, theme.lume());
            // top-left #FFFFFF highlight on the polished rim
            dc.setColor(theme.lumeGlow(), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(penW(R * MARKER_HI_W));
            dc.drawArc(p[0], p[1], R * (_geo.MARKER_RIM_R - _geo.MARKER_RIM_W / 2.0),
                       Graphics.ARC_COUNTER_CLOCKWISE, 100, 160);
            dc.setPenWidth(1);
        }
        // double bar at 12 (§2.5): vertical, so axis-aligned rounded rects
        var barCx = R * (_geo.BAR12_GAP / 2.0 + _geo.BAR12_W / 2.0);
        var barCy = cy - R * (_geo.MARKER_INNER + _geo.MARKER_OUTER) / 2.0;
        var barH = R * (_geo.MARKER_OUTER - _geo.MARKER_INNER);
        lumeBlock(dc, theme, cx - barCx, barCy, R * _geo.BAR12_W, barH,
                  R * _geo.BAR12_CORNER, R * _geo.MARKER_RIM_W);
        lumeBlock(dc, theme, cx + barCx, barCy, R * _geo.BAR12_W, barH,
                  R * _geo.BAR12_CORNER, R * _geo.MARKER_RIM_W);
        // displaced plots at 3 / 9 (tangential = vertical) and 6 (§2.6)
        lumeBlock(dc, theme, cx + R * _geo.PLOT39_R, cy,
                  R * _geo.PLOT39_H, R * _geo.PLOT39_W,
                  R * _geo.PLOT_CORNER, R * _geo.PLOT_RIM_W);
        lumeBlock(dc, theme, cx - R * _geo.PLOT39_R, cy,
                  R * _geo.PLOT39_H, R * _geo.PLOT39_W,
                  R * _geo.PLOT_CORNER, R * _geo.PLOT_RIM_W);
        lumeBlock(dc, theme, cx, cy + R * _geo.PLOT6_R,
                  R * _geo.PLOT6_W, R * _geo.PLOT6_H,
                  R * _geo.PLOT_CORNER, R * _geo.PLOT_RIM_W);
    }

    // 3-layer applied block (§2.4 construction): shadow step ring, polished
    // rim, lume fill. (x, y) is the block center; w/h are the rim rect size.
    private function lumeBlock(dc as Graphics.Dc, theme as Theme, x as Numeric,
                               y as Numeric, w as Numeric, h as Numeric,
                               corner as Numeric, rimW as Numeric) as Void {
        var s = _geo.R * (_geo.MARKER_SHADOW_R - _geo.MARKER_RIM_R);
        dc.setColor(theme.markerShadow(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - w / 2.0 - s, y - h / 2.0 - s,
                                w + 2.0 * s, h + 2.0 * s, corner + s);
        dc.setColor(theme.markerRim(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - w / 2.0, y - h / 2.0, w, h, corner);
        dc.setColor(theme.lume(), Graphics.COLOR_TRANSPARENT);
        var iw = w - 2.0 * rimW; var ih = h - 2.0 * rimW;
        var cr = corner - rimW;
        if (cr < 1.0) { cr = 1.0; }
        dc.fillRoundedRectangle(x - iw / 2.0, y - ih / 2.0, iw, ih, cr);
    }

    // ------------------------------------------------------------------
    // Subdials (§2.7). Static art only — hands and hub caps are dynamic.
    // ------------------------------------------------------------------

    // Left, 9 o'clock (small seconds): flange recess, snailed center, white
    // rotated 10..60 scale, 5-second ticks, 1-second dots.
    private function subdialLeft(dc as Graphics.Dc, theme as Theme) as Void {
        var c = _geo.leftSubCenter();
        var sx = c[0]; var sy = c[1]; var R = _geo.R;
        subRecess(dc, theme, sx, sy);
        var col = theme.subPrint();
        // 5-second ticks (every 30 deg)
        for (var t = 0; t < 12; t++) {
            var a = (t / 12.0) * 2.0 * Math.PI;
            radialBarAt(dc, sx, sy, a, R * _geo.SUBL_TICK_IN, R * _geo.SUBL_TICK_OUT,
                        R * _geo.SUBL_TICK_W, col);
        }
        // 1-second dots between the ticks
        var dr = R * _geo.SUBL_DOT_D / 2.0;
        if (dr < 1.0) { dr = 1.0; }
        for (var s = 0; s < 60; s++) {
            if (s % 5 == 0) { continue; }
            var a = (s / 60.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(sx, sy, a, R * _geo.SUBL_DOT_R);
            Draw.dot(dc, p[0], p[1], dr, col);
        }
        // tangentially rotated numerals 10..60 ("30" upside-down at the bottom)
        var cap = R * _geo.SUBL_NUM_CAP;
        for (var v = 10; v <= 60; v += 10) {
            var a = ((v % 60) / 60.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(sx, sy, a, R * _geo.SUBL_NUM_R);
            drawNumeral(dc, v, p[0], p[1], a, cap, cap * DIGIT_W_RATIO,
                        cap * DIGIT_GAP_RATIO, cap * DIGIT_STROKE_RATIO, col);
        }
    }

    // Right, 3 o'clock (12h/60min counter): the wide flat rose-bronze annulus
    // with black print — numerals 12-2-..-10, odd-hour hairlines, minute dots.
    private function subdialRight(dc as Graphics.Dc, theme as Theme) as Void {
        var c = _geo.rightSubCenter();
        var sx = c[0]; var sy = c[1]; var R = _geo.R;
        subRecess(dc, theme, sx, sy);
        // wide bronze band 0.160->0.242 (a filled band, not a stroked circle)
        var rIn = R * _geo.SUB_RING_IN;
        var rOut = R * _geo.SUB_RING_OUT;
        var ringMid = (rIn + rOut) / 2.0;
        dc.setColor(theme.bronzeRing(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((rOut - rIn).toNumber() + 1);
        dc.drawCircle(sx, sy, ringMid);
        // optional south-edge shading (§2.7)
        dc.setColor(blend(theme.bronzeRing(), theme.bronzeLo(), 0.30),
                    Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(((rOut - rIn) * 0.9).toNumber());
        dc.drawArc(sx, sy, ringMid, Graphics.ARC_COUNTER_CLOCKWISE, 250, 290);
        dc.setPenWidth(1);
        var col = theme.ringPrint();
        // full-ring-width hairline ticks at odd hours
        for (var hh = 1; hh < 12; hh += 2) {
            var a = (hh / 12.0) * 2.0 * Math.PI;
            radialBarAt(dc, sx, sy, a, rIn, rOut, R * _geo.SUBR_TICK_W, col);
        }
        // minute dots: four per 5-minute sector
        var dr = R * _geo.SUBR_DOT_D / 2.0;
        if (dr < 1.0) { dr = 1.0; }
        for (var m = 0; m < 60; m++) {
            if (m % 5 == 0) { continue; }
            var a = (m / 60.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(sx, sy, a, R * _geo.SUBR_DOT_R);
            Draw.dot(dc, p[0], p[1], dr, col);
        }
        // rotated numerals 12-2-4-6-8-10, black on the bronze
        var cap = R * _geo.SUBR_NUM_CAP;
        for (var v = 12; v >= 2; v -= 2) {
            var a = ((v % 12) / 12.0) * 2.0 * Math.PI;
            var p = _geo.ptAt(sx, sy, a, R * _geo.SUBR_NUM_R);
            drawNumeral(dc, v, p[0], p[1], a, cap, cap * DIGIT_W_RATIO,
                        cap * DIGIT_GAP_RATIO, cap * DIGIT_STROKE_RATIO, col);
        }
    }

    // Shared recess base: flange disc, dark recess edge, snailed center —
    // concentric SNAIL_GROOVE rings on SNAIL_BASE (alternating, ~0.006 pitch).
    private function subRecess(dc as Graphics.Dc, theme as Theme,
                               sx as Numeric, sy as Numeric) as Void {
        var R = _geo.R;
        var subR = R * _geo.SUB_R;
        dc.setColor(theme.subdialRecess(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, subR);
        // recess shadow edge against the wave dial
        dc.setColor(theme.waveGroove(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penW(R * 0.006));
        dc.drawCircle(sx, sy, subR);
        // snailed black center
        dc.setPenWidth(1);
        var snailR = R * _geo.SUB_SNAIL_R;
        dc.setColor(theme.snailBase(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, snailR);
        dc.setColor(theme.snailGroove(), Graphics.COLOR_TRANSPARENT);
        var pitch = R * _geo.SUB_SNAIL_PITCH * 2.0; // groove/base alternation
        var rr = pitch;
        while (rr < snailR) {
            dc.drawCircle(sx, sy, rr);
            rr += pitch;
        }
    }

    // ------------------------------------------------------------------
    // Date window at 6 (§2.8): glossy black bevel frame (no silver outline),
    // recess aperture, inner-top specular hairline. Numeral is dynamic.
    // ------------------------------------------------------------------
    private function dateAperture(dc as Graphics.Dc, theme as Theme) as Void {
        var c = _geo.dateCenter();
        var R = _geo.R;
        var w = R * _geo.DATE_W; var h = R * _geo.DATE_H;
        var bevel = R * DATE_BEVEL;
        dc.setColor(theme.dateFrame(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(c[0] - w / 2.0, c[1] - h / 2.0, w, h,
                                R * _geo.DATE_CORNER);
        var aw = w - 2.0 * bevel; var ah = h - 2.0 * bevel;
        var cr = R * _geo.DATE_CORNER - bevel;
        if (cr < 1.0) { cr = 1.0; }
        dc.setColor(theme.dateAperture(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(c[0] - aw / 2.0, c[1] - ah / 2.0, aw, ah, cr);
        dc.setPenWidth(1);
        dc.setColor(theme.dateSpecular(), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(c[0] - aw / 2.0 + cr, c[1] - ah / 2.0,
                    c[0] + aw / 2.0 - cr, c[1] - ah / 2.0);
    }

    // ------------------------------------------------------------------
    // Text stack (§2.9): Ω mark + OMEGA / red Seamaster / PROFESSIONAL above,
    // [ZrO2] + CO-AXIAL / MASTER CHRONOMETER / 300m stack below, SWISS MADE
    // flanking the 6 o'clock plot on the flange arc.
    // ------------------------------------------------------------------
    private function textStack(dc as Graphics.Dc, theme as Theme) as Void {
        var cx = _geo.cx; var cy = _geo.cy; var R = _geo.R;
        omegaMark(dc, theme, cx, cy - R * _geo.TXT_OMEGA_SYM);
        line(dc, cx, cy - R * _geo.LOGO_R, theme.textHi(), "OMEGA");
        line(dc, cx, cy - R * _geo.TXT_SEAMASTER, theme.poppyRed(), "Seamaster");
        line(dc, cx, cy - R * _geo.TXT_PROF, theme.textMid(), "PROFESSIONAL");
        line(dc, cx, cy + R * _geo.TXT_ZRO2, theme.zro2Gray(), "[ZrO2]");
        line(dc, cx, cy + R * _geo.TXT_COAXIAL, theme.textMid(), "CO-AXIAL");
        line(dc, cx, cy + R * _geo.TXT_MASTER, theme.textMid(), "MASTER CHRONOMETER");
        line(dc, cx, cy + R * _geo.TXT_DEPTH, theme.textMid(), "300m / 1000ft");
        // SWISS ... MADE on the arc at TXT_SWISS_R, one word each side of 6
        var pSwiss = _geo.ptFrac(0.5 + SWISS_OFF, _geo.TXT_SWISS_R);
        var pMade = _geo.ptFrac(0.5 - SWISS_OFF, _geo.TXT_SWISS_R);
        line(dc, pSwiss[0], pSwiss[1], theme.textDim(), "SWISS");
        line(dc, pMade[0], pMade[1], theme.textDim(), "MADE");
    }

    private function line(dc as Graphics.Dc, x as Numeric, y as Numeric,
                          color as Number, txt as String) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, txt,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Ω symbol (§2.9): 0.069 tall x 0.080 wide, stroke 0.011, two feet ~0.023.
    private function omegaMark(dc as Graphics.Dc, theme as Theme,
                               cx as Numeric, cy as Numeric) as Void {
        var R = _geo.R;
        var r = R * 0.080 / 2.0;         // arc radius from the symbol width
        var stroke = R * 0.011;
        var fl = R * 0.023;              // foot length
        dc.setColor(theme.textHi(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penW(stroke));
        // open at the bottom (Garmin arc: 0 deg = 3 o'clock, CCW positive)
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 310, 230);
        dc.setPenWidth(1);
        var fy = cy + r * 0.62;
        dc.fillRectangle(cx - r * 0.80 - fl / 2.0, fy, fl, stroke);
        dc.fillRectangle(cx + r * 0.80 - fl / 2.0, fy, fl, stroke);
    }

    // ------------------------------------------------------------------
    // Primitives
    // ------------------------------------------------------------------

    // Radial rectangle about an arbitrary center (bezel batons, flange ticks,
    // subdial scale strokes). All params in pixels; angle radians cw from up.
    private function radialBarAt(dc as Graphics.Dc, ox as Numeric, oy as Numeric,
                                 angle as Numeric, rInPx as Numeric, rOutPx as Numeric,
                                 wPx as Numeric, color as Number) as Void {
        var sinT = Math.sin(angle); var cosT = Math.cos(angle);
        var mid = (rInPx + rOutPx) / 2.0;
        var hl = (rOutPx - rInPx) / 2.0;
        var hw = wPx / 2.0;
        if (hw < 0.5) { hw = 0.5; }
        var p = _geo.ptAt(ox, oy, angle, mid);
        Draw.poly(dc, p[0], p[1], sinT, cosT,
                  [[-hw, -hl], [hw, -hl], [hw, hl], [-hw, hl]], color);
    }

    // Rotated one- or two-digit numeral centered at (px, py), glyph top facing
    // radially outward at `angle` (radians cw from up). Fonts cannot rotate,
    // so digits render from the shared stroked path table (§3).
    private function drawNumeral(dc as Graphics.Dc, value as Number, px as Numeric,
                                 py as Numeric, angle as Numeric, capH as Numeric,
                                 digitW as Numeric, gap as Numeric, strokeW as Numeric,
                                 color as Number) as Void {
        var sinA = Math.sin(angle); var cosA = Math.cos(angle);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (value >= 10) {
            var off = (digitW + gap) / 2.0;
            var c1 = Draw.tp(px, py, sinA, cosA, -off, 0.0);
            var c2 = Draw.tp(px, py, sinA, cosA, off, 0.0);
            drawDigit(dc, value / 10, c1[0], c1[1], sinA, cosA, digitW, capH, strokeW);
            drawDigit(dc, value % 10, c2[0], c2[1], sinA, cosA, digitW, capH, strokeW);
        } else {
            drawDigit(dc, value, px, py, sinA, cosA, digitW, capH, strokeW);
        }
    }

    // One stroked digit. Glyph frame: x right (tangential, clockwise), y down
    // (radially inward) — so the digit's top faces outward and "30" renders
    // upside-down at the bottom of its ring. Joints are rounded with discs.
    private function drawDigit(dc as Graphics.Dc, d as Number, gx as Numeric,
                               gy as Numeric, sinA as Numeric, cosA as Numeric,
                               w as Numeric, h as Numeric, sw as Numeric) as Void {
        var strokes = _digits[d];
        if (strokes == null) { return; }
        dc.setPenWidth(penW(sw));
        var jr = sw / 2.0;
        var sArr = strokes as Array;
        for (var s = 0; s < sArr.size(); s++) {
            var pts = sArr[s] as Array;
            var have = false;
            var lx = 0.0; var ly = 0.0;
            for (var i = 0; i < pts.size(); i++) {
                var g = pts[i] as Array;
                var u = ((g[0] as Numeric) - 0.5) * w;        // glyph right
                var v = -(((g[1] as Numeric) - 0.5) * h);     // glyph down -> -v
                var p = Draw.tp(gx, gy, sinA, cosA, u, v);
                var x = (p[0] as Numeric).toFloat();
                var y = (p[1] as Numeric).toFloat();
                if (have) {
                    dc.drawLine(lx, ly, x, y);
                }
                if (jr >= 1.0) {
                    dc.fillCircle(x, y, jr);
                }
                lx = x; ly = y; have = true;
            }
        }
        dc.setPenWidth(1);
    }

    // Pen width in whole pixels, minimum 1.
    private function penW(px as Numeric) as Number {
        var n = (px + 0.5).toNumber();
        return n < 1 ? 1 : n;
    }

    // 8-8-8 channel blend between two RGB colors, t in [0,1].
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
