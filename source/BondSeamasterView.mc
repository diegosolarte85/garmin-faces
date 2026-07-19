import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;

// Watch face lifecycle. The static dial is a pre-baked 454x454 image asset
// (resources/drawables/dial_*.png, rendered by tools/gen_dial_assets.py) blitted
// each frame — Garmin's own technique: flawless anti-aliasing, gradients, and no
// runtime render cost / watchdog risk. Only the moving hands and live
// complication values are drawn on top.
class BondSeamasterView extends WatchUi.WatchFace {
    private var _geo as Geometry;
    private var _theme as Theme;
    private var _hands as Hands;
    private var _subs as Subdials;
    private var _digital as DigitalFace;

    private var _dialBmp as WatchUi.BitmapResource?;
    private var _loadedKey as Number = -1;   // theme*2 + styleGroup currently loaded
    private var _lowPower as Boolean = false;
    private var _prevBox as Array<Number>?;

    public function initialize() {
        WatchFace.initialize();
        _geo = new Geometry();
        _theme = new Theme();
        _hands = new Hands(_geo);
        _subs = new Subdials(_geo);
        _digital = new DigitalFace(_geo);
    }

    public function onLayout(dc as Graphics.Dc) as Void {
        _geo.setBounds(dc.getWidth(), dc.getHeight());
        _theme.load();
        loadDial();
    }

    public function onShow() as Void {
        loadDial();
    }

    public function reloadSettings() as Void {
        _theme.load();
        loadDial();
    }

    // Load the bright baked background for the current theme + face style
    // (active mode only — always-on is drawn as sparse vector, no bitmap).
    // Digital and Sport share one background (waves + trident + wordmark).
    private function loadDial() as Void {
        var key = _theme.dialTheme * 2 + (_theme.faceStyle > 0 ? 1 : 0);
        if (key == _loadedKey && _dialBmp != null) { return; }
        var id;
        if (_theme.faceStyle > 0) {
            id = (_theme.dialTheme == 1) ? Rez.Drawables.DialDigitalDawn
                                         : Rez.Drawables.DialDigitalBlack;
        } else {
            id = (_theme.dialTheme == 1) ? Rez.Drawables.DialDawn : Rez.Drawables.DialBlack;
        }
        _dialBmp = WatchUi.loadResource(id) as WatchUi.BitmapResource;
        _loadedKey = key;
    }

    public function onExitSleep() as Void {
        _lowPower = false;
        _theme.lowPower = false;
        WatchUi.requestUpdate();
    }

    public function onEnterSleep() as Void {
        _lowPower = true;
        _theme.lowPower = true;
        _prevBox = null;
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        Draw.aa(dc, true);
        var clock = System.getClockTime();
        var hourFrac = ((clock.hour % 12) + clock.min / 60.0) / 12.0;
        var minFrac = (clock.min + clock.sec / 60.0) / 60.0;

        // --- Always-on: sparse vector face on black (Garmin AOD style) ---
        // Outlined hour markers + subdial rings + bright hands. Few lit pixels
        // (burn-in safe) but bright and alive — a full-screen bitmap blanks in
        // low power on-device, which is why the baked dial went black in AOD.
        if (_lowPower) {
            if (_theme.faceStyle > 0) {
                _digital.drawAod(dc, _theme);
            } else {
                drawAod(dc, hourFrac, minFrac);
            }
            return;
        }

        // --- Active: blit the baked dial, then live hands / complications ---
        if (_dialBmp != null) {
            dc.drawBitmap(0, 0, _dialBmp);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
        }
        if (_theme.faceStyle > 0) {
            _digital.draw(dc, _theme, showSeconds());
            return;
        }
        _subs.drawRight(dc, _theme);
        _subs.drawLeft(dc, _theme, clock.hour, clock.min);
        _subs.drawDate(dc, _theme, dayOfMonth());
        _hands.drawHour(dc, _theme, hourFrac);
        _hands.drawMinute(dc, _theme, minFrac);
        if (showSeconds()) {
            var secFrac = clock.sec / 60.0;
            _hands.drawSeconds(dc, _theme, secFrac);
            _prevBox = secBox(secFrac);
        }
        _hands.drawHub(dc, _theme);
    }

    // Always-on face: black + glowing lume hour markers + bright hands.
    // Few lit pixels (burn-in safe) but reads like a real diver's lume at night.
    private function drawAod(dc as Graphics.Dc, hourFrac as Float, minFrac as Float) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Refined lume tones (Super-LumiNova-style teal glow), dim for burn-in.
        var lume = 0x59B6A4;      // hour markers
        var lume12 = 0xB4ECDC;    // brighter 12 o'clock reference
        var dot = _geo.rad(0.026);

        for (var h = 1; h < 12; h++) {
            var p = _geo.ptFrac(h / 12.0, _geo.MARKER_R);
            dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(p[0], p[1], dot);
        }
        // 12 o'clock: an upright lume baton so the face is instantly oriented.
        var top = _geo.ptFrac(0.0, _geo.MARKER_R);
        var bw = dot * 1.5;
        var bh = dot * 3.0;
        dc.setColor(lume12, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(top[0] - bw / 2.0, top[1] - bh / 2.0, bw, bh, dot * 0.7);

        // bright hands (draw in active palette so they read on black)
        _theme.lowPower = false;
        _hands.drawHour(dc, _theme, hourFrac);
        _hands.drawMinute(dc, _theme, minFrac);
        _hands.drawHub(dc, _theme);
        _theme.lowPower = true;

        // subtle gold center pip echoing the trident accent
        dc.setColor(0xC8A05A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, dot * 0.5);
    }

    // Once-per-second seconds tick (active): repaint only the second-hand region.
    public function onPartialUpdate(dc as Graphics.Dc) as Void {
        if (_lowPower || !showSeconds() || _dialBmp == null) { return; }
        Draw.aa(dc, true);
        var clock = System.getClockTime();

        // Digital styles: repaint just the small seconds-text slot.
        if (_theme.faceStyle > 0) {
            var b = _digital.secBox(_theme.faceStyle);
            dc.setClip(b[0], b[1], b[2] - b[0], b[3] - b[1]);
            dc.drawBitmap(0, 0, _dialBmp);
            _digital.drawSeconds(dc, _theme, clock.sec);
            dc.clearClip();
            return;
        }
        var secFrac = clock.sec / 60.0;
        var box = unionBox(_prevBox, secBox(secFrac));
        if (box == null) { return; }

        dc.setClip(box[0], box[1], box[2] - box[0], box[3] - box[1]);
        dc.drawBitmap(0, 0, _dialBmp);
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
        if (_theme.secondsMode == 1) { return false; }
        return !_lowPower;
    }

    private function dayOfMonth() as Number {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return info.day;
    }

    private function secBox(frac as Float) as Array<Number> {
        var pts = [
            _geo.ptFrac(frac, _geo.SEC_LEN),
            _geo.ptFrac(frac, _geo.SEC_LEN * 0.80),
            _geo.ptFrac((frac + 0.5) - ((frac + 0.5) >= 1.0 ? 1.0 : 0.0), _geo.SEC_TAIL),
            [_geo.cx, _geo.cy]
        ];
        var pad = _geo.rad(0.06);
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
        if (minx < 0) { minx = 0; }
        if (miny < 0) { miny = 0; }
        if (maxx > _geo.w) { maxx = _geo.w; }
        if (maxy > _geo.h) { maxy = _geo.h; }
        return [minx, miny, maxx, maxy];
    }
}
