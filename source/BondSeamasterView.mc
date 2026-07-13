import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;

// Watch face lifecycle + compositing + power state machine.
// Render pipeline and states: specs/.../design.md §1, §4.
class BondSeamasterView extends WatchUi.WatchFace {
    private var _geo as Geometry;
    private var _theme as Theme;
    private var _dial as DialRenderer;
    private var _hands as Hands;
    private var _subs as Subdials;
    private var _dawn as FxDawnSweep;

    private var _bufRef as Graphics.BufferedBitmapReference?;
    private var _lowPower as Boolean = false;

    // Progressive static-render cursor: -1 = idle/complete, >=0 = the next
    // DialRenderer stage to paint into the buffer. The full dial is far too
    // heavy to draw in one onUpdate (it trips the device execution watchdog),
    // so we paint one bounded stage per frame until done, once — the buffer is
    // then reused for the whole session (no per-wake rebuild).
    private var _buildStage as Number = -1;

    // previous second-hand bounding box for partial-update clipping
    private var _prevBox as Array<Number>?;

    public function initialize() {
        WatchFace.initialize();
        _geo = new Geometry();
        _theme = new Theme();
        _dial = new DialRenderer(_geo);
        _hands = new Hands(_geo);
        _subs = new Subdials(_geo);
        _dawn = new FxDawnSweep(_geo);
    }

    public function onLayout(dc as Graphics.Dc) as Void {
        _geo.setBounds(dc.getWidth(), dc.getHeight());
        _theme.load();
        startBuild(dc.getWidth(), dc.getHeight());
    }

    public function onShow() as Void {
        if (_bufRef == null && _buildStage < 0) {
            startBuild(_geo.w, _geo.h);
        }
    }

    // Called by the app on a settings change — rebuild the static art once.
    public function reloadSettings() as Void {
        _theme.load();
        startBuild(_geo.w, _geo.h);
    }

    public function onExitSleep() as Void {
        _lowPower = false;
        _theme.lowPower = false;
        // NB: no static-art rebuild here — the baked buffer is reused, so we
        // never re-run the heavy render on a wrist-raise (watchdog safety).
        // The dawn-sweep flourish is intentionally NOT armed here: on a busy
        // AMOLED dial its warm sweep read as flicker/noise on wake. It stays
        // available via the setting but defaults off.
        WatchUi.requestUpdate();
    }

    public function onEnterSleep() as Void {
        _lowPower = true;
        _theme.lowPower = true;
        _dawn.cancel();
        _prevBox = null;
        WatchUi.requestUpdate();
    }

    // --- full paint ---
    public function onUpdate(dc as Graphics.Dc) as Void {
        if (_buildStage >= 0) {
            advanceBuild();          // paint one bounded stage into the buffer
        }
        blitStatic(dc);

        if (!_lowPower && _dawn.isActive()) {
            _dawn.draw(dc, _theme);
            lumeBloom(dc);
            _dawn.step();
        }

        var clock = System.getClockTime();
        var day = dayOfMonth();

        _subs.drawRight(dc, _theme);
        _subs.drawLeft(dc, _theme, clock.hour, clock.min);
        _subs.drawDate(dc, _theme, day);

        var hourFrac = ((clock.hour % 12) + clock.min / 60.0) / 12.0;
        var minFrac = (clock.min + clock.sec / 60.0) / 60.0;
        _hands.drawHour(dc, _theme, hourFrac);
        _hands.drawMinute(dc, _theme, minFrac);

        if (showSeconds()) {
            var secFrac = clock.sec / 60.0;
            _hands.drawSeconds(dc, _theme, secFrac);
            _prevBox = secBox(secFrac);
        }
        _hands.drawHub(dc, _theme);

        // keep frames coming while the dawn effect plays or the buffer is
        // still assembling itself over successive frames
        if (_buildStage >= 0 || (!_lowPower && _dawn.isActive())) {
            WatchUi.requestUpdate();
        }
    }

    // --- once-per-second seconds tick (active) ---
    public function onPartialUpdate(dc as Graphics.Dc) as Void {
        if (_lowPower || !showSeconds()) { return; }
        var clock = System.getClockTime();
        var secFrac = clock.sec / 60.0;
        var box = unionBox(_prevBox, secBox(secFrac));
        if (box == null) { return; }

        dc.setClip(box[0], box[1], box[2] - box[0], box[3] - box[1]);
        blitStatic(dc);
        // redraw the bits that live under the clip
        var hourFrac = ((clock.hour % 12) + clock.min / 60.0) / 12.0;
        var minFrac = (clock.min + clock.sec / 60.0) / 60.0;
        _hands.drawHour(dc, _theme, hourFrac);
        _hands.drawMinute(dc, _theme, minFrac);
        _hands.drawSeconds(dc, _theme, secFrac);
        _hands.drawHub(dc, _theme);
        dc.clearClip();
        _prevBox = secBox(secFrac);
    }

    // --- helpers ---
    private function showSeconds() as Boolean {
        if (_theme.secondsMode == 1) { return false; } // always hidden
        return !_lowPower;                              // sweep, hidden in AOD
    }

    private function blitStatic(dc as Graphics.Dc) as Void {
        if (_bufRef != null) {
            var bmp = _bufRef.get();
            if (bmp != null) {
                dc.drawBitmap(0, 0, bmp);
                return;
            }
        }
        // fallback: draw static art straight to screen
        _dial.draw(dc, _theme);
    }

    // Allocate the off-screen buffer and arm progressive rendering. Paints a
    // cheap base fill so the first frames aren't blank while the dial assembles
    // over the next STAGE_COUNT updates.
    private function startBuild(w as Number, h as Number) as Void {
        if (Graphics has :createBufferedBitmap) {
            _bufRef = Graphics.createBufferedBitmap({:width => w, :height => h});
            var bmp = (_bufRef != null) ? _bufRef.get() : null;
            if (bmp != null) {
                var bdc = bmp.getDc();
                bdc.setColor(_theme.ceramicBase(), _theme.ceramicBase());
                bdc.clear();
                _buildStage = 0;
                _theme.dirty = false;
                return;
            }
        }
        // no buffer available — blitStatic falls back to direct draw
        _bufRef = null;
        _buildStage = -1;
        _theme.dirty = false;
    }

    // Paint exactly one static-render stage into the buffer per call.
    private function advanceBuild() as Void {
        if (_bufRef == null) { _buildStage = -1; return; }
        var bmp = _bufRef.get();
        if (bmp == null) { _buildStage = -1; return; }
        var done = _dial.drawStage(bmp.getDc(), _theme, _buildStage);
        _buildStage = done ? -1 : _buildStage + 1;
    }

    private function dayOfMonth() as Number {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.day;
    }

    // Soft lume bloom at the hour-marker tips during the wake flourish.
    private function lumeBloom(dc as Graphics.Dc) as Void {
        for (var h = 0; h < 12; h++) {
            var p = _geo.ptFrac(h / 12.0, _geo.MARKER_OUTER);
            Draw.dot(dc, p[0], p[1], _geo.rad(0.018), _theme.lumeGlow());
        }
    }

    // Bounding box [minX, minY, maxX, maxY] of the second hand at a fraction.
    private function secBox(frac as Float) as Array<Number> {
        var pts = [
            _geo.ptFrac(frac, _geo.SEC_LEN),
            _geo.ptFrac(frac, _geo.SEC_LEN * 0.80),
            _geo.ptFrac((frac + 0.5) - ((frac + 0.5) >= 1.0 ? 1.0 : 0.0), _geo.SEC_TAIL),
            [_geo.cx, _geo.cy]
        ];
        var pad = _geo.rad(0.05);
        var minx = pts[0][0]; var maxx = pts[0][0];
        var miny = pts[0][1]; var maxy = pts[0][1];
        for (var i = 1; i < pts.size(); i++) {
            if (pts[i][0] < minx) { minx = pts[i][0]; }
            if (pts[i][0] > maxx) { maxx = pts[i][0]; }
            if (pts[i][1] < miny) { miny = pts[i][1]; }
            if (pts[i][1] > maxy) { maxy = pts[i][1]; }
        }
        return [(minx - pad).toNumber(), (miny - pad).toNumber(),
                (maxx + pad).toNumber(), (maxy + pad).toNumber()];
    }

    private function unionBox(a as Array<Number>?, b as Array<Number>?) as Array<Number>? {
        if (a == null) { return b; }
        if (b == null) { return a; }
        var minx = a[0] < b[0] ? a[0] : b[0];
        var miny = a[1] < b[1] ? a[1] : b[1];
        var maxx = a[2] > b[2] ? a[2] : b[2];
        var maxy = a[3] > b[3] ? a[3] : b[3];
        // clamp to screen
        if (minx < 0) { minx = 0; }
        if (miny < 0) { miny = 0; }
        if (maxx > _geo.w) { maxx = _geo.w; }
        if (maxy > _geo.h) { maxy = _geo.h; }
        return [minx, miny, maxx, maxy];
    }
}
