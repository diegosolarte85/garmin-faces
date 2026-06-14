import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;

// "First Light" wrist-raise flourish: a warm band of light sweeps down the dial
// when the wearer raises their wrist, then settles. (R3.2, R3.3)
//
// Watch faces update at ~1 Hz, so this is a few-tick sweep (≈3 s), not a 60 fps
// animation — the honest ceiling for a watch-face lifecycle. It never runs in
// low-power mode. See specs/.../design.md §7 "Intentional deviations".
class FxDawnSweep {
    private var _geo as Geometry;
    private var _phase as Number = 0;
    private const MAX_PHASE = 3;

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    public function arm() as Void { _phase = MAX_PHASE; }
    public function cancel() as Void { _phase = 0; }
    public function isActive() as Boolean { return _phase > 0; }

    // Advance one tick; call once per awake onUpdate.
    public function step() as Void {
        if (_phase > 0) { _phase--; }
    }

    public function draw(dc as Graphics.Dc, theme as Theme) as Void {
        if (_phase <= 0) { return; }
        var cx = _geo.cx; var cy = _geo.cy;
        var rad = _geo.rad(_geo.DIAL_R);
        // progress 0..1 across the sweep (top → toward center+)
        var p = 1.0 - (_phase.toFloat() / MAX_PHASE);
        var bandY = (cy - rad) + (1.6 * rad) * p;
        var bandH = rad * 0.22;
        // intensity eases out as it descends
        var intensity = 1.0 - p * 0.65;

        var lines = 14;
        for (var i = 0; i < lines; i++) {
            var t = i.toFloat() / (lines - 1);          // 0..1 across band
            var y = bandY - bandH + 2.0 * bandH * t;
            var dy = y - cy;
            var inside = rad * rad - dy * dy;
            if (inside <= 0) { continue; }
            var half = Math.sqrt(inside);
            // brightest at band center, warm core → cool edge
            var falloff = 1.0 - (2.0 * (t - 0.5)).abs();
            var warm = DialRenderer.blend(theme.DAWN_COOL, theme.DAWN_WARM, falloff);
            var shade = DialRenderer.blend(theme.ceramicBase(), warm, falloff * intensity * 0.9);
            dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - half, y, cx + half, y);
        }
    }
}
