import Toybox.Lang;
import Toybox.Graphics;
using Toybox.System;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.ActivityMonitor;
using Toybox.Activity;

// The two digital styles of First Light (FaceStyle 1 = Digital, 2 = Sport),
// styled after Garmin's stock Fenix faces: two-tone big time, a ticked
// seconds ring, a dotted body-battery gauge, a weekday strip, and round
// complication pods — recolored to the First Light family (lume/teal/gold,
// red-ring accent from the chronograph counter).
// The wave background + trident + wordmark are a baked bitmap (DialDigital*);
// everything here is the live layer. Layout unit = Geometry.R fractions.
class DigitalFace {
    private var _geo as Geometry;

    // Family palette
    private const LUME as Number = 0xE8F4EE;    // hour digits / values
    private const TEAL as Number = 0x59B6A4;    // steps / body battery
    private const GOLD as Number = 0xC8A05A;    // minutes / battery / date
    private const RED  as Number = 0xC82A22;    // HR + seconds-ring accent
    private const DIMC as Number = 0x9AA2A6;    // secondary text
    private const MUTE as Number = 0x4A5254;    // inactive weekday / unlit dot
    private const TRACK as Number = 0x2A3234;   // gauge arc background
    private const PODF as Number = 0x101418;    // pod fill

    // sunrise/sunset cache (recomputed once per day)
    private var _sunDay as Number = -1;
    private var _sunRise as String = "--:--";
    private var _sunSet as String = "--:--";

    // seconds-ring center, measured from the rendered time width each draw
    // so the ring hugs the digits without ever overlapping them.
    private var _secPos as Array<Float>?;

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    // ------------------------------------------------------------------ active
    public function draw(dc as Graphics.Dc, theme as Theme, showSec as Boolean) as Void {
        var clock = System.getClockTime();
        var cx = _geo.cx; var cy = _geo.cy;

        // date — shared slot below the wordmark
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - _geo.rad(0.245), Graphics.FONT_TINY, dateStr(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (theme.faceStyle == 2) {
            drawSport(dc, theme, clock, showSec);
        } else {
            drawDigital(dc, theme, clock, showSec);
        }
    }

    private function drawDigital(dc as Graphics.Dc, theme as Theme,
                                 clock as System.ClockTime, showSec as Boolean) as Void {
        var cx = _geo.cx; var cy = _geo.cy;

        // top row flanking the baked trident: temperature + heart rate
        var ty = cy - _geo.rad(0.465);
        var temp = tempStr();
        if (!temp.equals("")) {
            thermo(dc, cx - _geo.rad(0.360), ty, _geo.rad(0.036), GOLD);
            dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - _geo.rad(0.270), ty, Graphics.FONT_XTINY, temp,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        heart(dc, cx + _geo.rad(0.360), ty, _geo.rad(0.036), RED);
        dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + _geo.rad(0.262), ty, Graphics.FONT_XTINY, hrStr(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // the time — two-tone like the stock face (lume hours, gold minutes)
        var t2y = cy + _geo.rad(0.005);
        var xr = twoToneTime(dc, clock, t2y, Graphics.FONT_NUMBER_THAI_HOT);
        _secPos = [xr + _geo.rad(0.115), t2y + _geo.rad(0.145)];

        if (showSec) { drawSeconds(dc, theme, clock.sec); }

        // left dotted gauge: body battery, lit bottom-up with a teal->gold ramp
        dottedGauge(dc, bodyBatteryFrac());

        // right weekday strip, today in gold
        weekdayStrip(dc);

        // bottom row: steps / battery / calories
        var fy = cy + _geo.rad(0.415);
        var iy = fy - _geo.rad(0.020);
        var vy = fy + _geo.rad(0.062);
        shoe(dc, cx - _geo.rad(0.305), iy, _geo.rad(0.046), TEAL);
        field(dc, cx - _geo.rad(0.300), vy, stepsStr());
        batteryIcon(dc, cx, iy, _geo.rad(0.078), _geo.rad(0.038), batteryFrac(), GOLD);
        field(dc, cx, vy, batteryStr());
        flame(dc, cx + _geo.rad(0.300), iy, _geo.rad(0.046), 0xE07A3A);
        field(dc, cx + _geo.rad(0.300), vy, caloriesStr());
    }

    private function drawSport(dc as Graphics.Dc, theme as Theme,
                               clock as System.ClockTime, showSec as Boolean) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        var gr = _geo.rad(0.700);
        var pen = _geo.rad(0.014).toNumber();
        if (pen < 3) { pen = 3; }

        // left arc: steps vs goal (fills top-down)
        dc.setPenWidth(pen);
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, gr, Graphics.ARC_COUNTER_CLOCKWISE, 120, 240);
        var sf = stepsFrac();
        if (sf > 0.01) {
            dc.setColor(TEAL, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, gr, Graphics.ARC_COUNTER_CLOCKWISE, 120,
                       (120 + 120 * sf).toNumber());
        }
        shoe(dc, cx - _geo.rad(0.590), cy, _geo.rad(0.042), TEAL);

        // right arc: battery (fills top-down)
        dc.setPenWidth(pen);
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, gr, Graphics.ARC_COUNTER_CLOCKWISE, 300, 60);
        var bf = batteryFrac();
        if (bf > 0.01) {
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, gr, Graphics.ARC_CLOCKWISE, 60,
                       (60 - 120 * bf).toNumber());
        }
        batteryIcon(dc, cx + _geo.rad(0.585), cy, _geo.rad(0.058), _geo.rad(0.030), bf, GOLD);

        // the time — two-tone (lower than the digital style so the date clears
        // the tall system font)
        var t2y = cy - _geo.rad(0.085);
        var xr = twoToneTime(dc, clock, t2y, Graphics.FONT_NUMBER_HOT);
        _secPos = [xr + _geo.rad(0.110), t2y];
        if (showSec) { drawSeconds(dc, theme, clock.sec); }

        // complication pods (stock-analog style): HR / body battery / calories
        var py = cy + _geo.rad(0.290);
        var pr = _geo.rad(0.125);
        pod(dc, cx - _geo.rad(0.300), py, pr, RED);
        heart(dc, cx - _geo.rad(0.300), py - _geo.rad(0.048), _geo.rad(0.034), RED);
        field(dc, cx - _geo.rad(0.300), py + _geo.rad(0.045), hrStr());
        pod(dc, cx, py, pr, TEAL);
        bolt(dc, cx, py - _geo.rad(0.048), _geo.rad(0.040), TEAL);
        field(dc, cx, py + _geo.rad(0.045), bodyBatteryStr());
        pod(dc, cx + _geo.rad(0.300), py, pr, GOLD);
        flame(dc, cx + _geo.rad(0.300), py - _geo.rad(0.048), _geo.rad(0.040), 0xE07A3A);
        field(dc, cx + _geo.rad(0.300), py + _geo.rad(0.045), caloriesStr());

        // sunrise / sunset
        refreshSunTimes();
        var by = cy + _geo.rad(0.505);
        sunIcon(dc, cx - _geo.rad(0.215), by, _geo.rad(0.040), GOLD, true);
        dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - _geo.rad(0.100), by, Graphics.FONT_XTINY, _sunRise,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        sunIcon(dc, cx + _geo.rad(0.085), by, _geo.rad(0.040), 0xB07A4A, false);
        dc.drawText(cx + _geo.rad(0.200), by, Graphics.FONT_XTINY, _sunSet,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Two-tone HH:MM — hours in lume, colon in teal, minutes in gold.
    // Returns the right edge x of the rendered time.
    private function twoToneTime(dc as Graphics.Dc, clock as System.ClockTime,
                                 ty as Float, font as Graphics.FontType) as Float {
        var cx = _geo.cx;
        var is24 = System.getDeviceSettings().is24Hour;
        var h = is24 ? clock.hour : (((clock.hour + 11) % 12) + 1);
        var hh = h.format(is24 ? "%02d" : "%d");
        var mm = clock.min.format("%02d");
        var wH = dc.getTextWidthInPixels(hh, font);
        var wM = dc.getTextWidthInPixels(mm, font);
        var colw = _geo.rad(0.075);
        var x0 = cx - (wH + colw + wM) / 2.0;

        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, ty, font, hh,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(TEAL, Graphics.COLOR_TRANSPARENT);
        var colx = x0 + wH + colw / 2.0;
        dc.fillCircle(colx, ty - _geo.rad(0.055), _geo.rad(0.015));
        dc.fillCircle(colx, ty + _geo.rad(0.055), _geo.rad(0.015));
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + wH + colw, ty, font, mm,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        return x0 + wH + colw + wM;
    }

    // Dotted left gauge (stock-style): 24 dots on an arc, lit bottom-up.
    private function dottedGauge(dc as Graphics.Dc, frac as Float) as Void {
        var n = 24;
        var lit = (frac * n + 0.5).toNumber();
        for (var i = 0; i < n; i++) {
            var f = 0.655 + 0.190 * i / (n - 1.0);   // dial fraction, bottom-up
            var p = _geo.ptFrac(f, 0.655);
            if (i < lit) {
                dc.setColor(mix(TEAL, GOLD, i.toFloat() / (n - 1)), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], _geo.rad(0.013));
            } else {
                dc.setColor(MUTE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], _geo.rad(0.008));
            }
        }
    }

    // Right-edge weekday strip, today highlighted gold (stock-style).
    private function weekdayStrip(dc as Graphics.Dc) as Void {
        var wd = ["S", "M", "T", "W", "T", "F", "S"];
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day_of_week as Number;
        for (var i = 0; i < 7; i++) {
            var f = 0.155 + 0.190 * i / 6.0;         // top-right -> bottom-right
            var p = _geo.ptFrac(f, 0.685);
            if (i == today - 1) {
                dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(MUTE, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(p[0], p[1], Graphics.FONT_XTINY, wd[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Ticked seconds ring (stock "SEC" pod, red-ring accent from the chrono
    // counter of the analog mockup). Ticks fill with the seconds.
    public function secondsPos(style as Number) as Array<Float> {
        if (_secPos != null) { return _secPos; }
        if (style == 2) {
            return [_geo.cx + _geo.rad(0.460), _geo.cy - _geo.rad(0.085)];
        }
        return [_geo.cx + _geo.rad(0.545), _geo.cy + _geo.rad(0.150)];
    }

    public function drawSeconds(dc as Graphics.Dc, theme as Theme, sec as Number) as Void {
        var p = secondsPos(theme.faceStyle);
        var r = _geo.rad(theme.faceStyle == 2 ? 0.078 : 0.085);
        dc.setColor(PODF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], r);
        var n = 30;
        var lit = sec * n / 60 + 1;
        dc.setPenWidth(2);
        for (var i = 0; i < n; i++) {
            var a = 2.0 * Math.PI * i / n;
            var sa = Math.sin(a); var ca = Math.cos(a);
            dc.setColor(i < lit ? RED : MUTE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(p[0] + r * 0.74 * sa, p[1] - r * 0.74 * ca,
                        p[0] + r * 0.95 * sa, p[1] - r * 0.95 * ca);
        }
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(p[0], p[1], Graphics.FONT_TINY, sec.format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Clip box for the per-second partial update.
    public function secBox(style as Number) as Array<Number> {
        var p = secondsPos(style);
        var hr = _geo.rad(style == 2 ? 0.082 : 0.090);
        return [(p[0] - hr).toNumber(), (p[1] - hr).toNumber(),
                (p[0] + hr).toNumber(), (p[1] + hr).toNumber()];
    }

    // -------------------------------------------------------------- always-on
    // Dim two-tone time only — few lit pixels, instantly readable.
    public function drawAod(dc as Graphics.Dc, theme as Theme) as Void {
        var clock = System.getClockTime();
        var cx = _geo.cx; var cy = _geo.cy;
        var is24 = System.getDeviceSettings().is24Hour;
        var h = is24 ? clock.hour : (((clock.hour + 11) % 12) + 1);
        var hh = h.format(is24 ? "%02d" : "%d");
        var mm = clock.min.format("%02d");
        var font = theme.faceStyle == 2 ? Graphics.FONT_NUMBER_HOT
                                        : Graphics.FONT_NUMBER_THAI_HOT;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var wH = dc.getTextWidthInPixels(hh, font);
        var wM = dc.getTextWidthInPixels(mm, font);
        var colw = _geo.rad(0.075);
        var x0 = cx - (wH + colw + wM) / 2.0;
        var ty = cy - _geo.rad(0.040);
        dc.setColor(0x707C7A, Graphics.COLOR_TRANSPARENT);   // dim lume
        dc.drawText(x0, ty, font, hh,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x6B5A38, Graphics.COLOR_TRANSPARENT);   // dim gold
        dc.drawText(x0 + wH + colw, ty, font, mm,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x4A5254, Graphics.COLOR_TRANSPARENT);
        var colx = x0 + wH + colw / 2.0;
        dc.fillCircle(colx, ty - _geo.rad(0.055), _geo.rad(0.013));
        dc.fillCircle(colx, ty + _geo.rad(0.055), _geo.rad(0.013));
        dc.setColor(0x5A6462, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + _geo.rad(0.170), Graphics.FONT_TINY, dateStr(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------ icons
    private function pod(dc as Graphics.Dc, x as Float, y as Float, r as Float,
                         ring as Number) as Void {
        dc.setColor(PODF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(ring, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(x, y, r);
    }

    private function heart(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                           col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.32, y - s * 0.18, s * 0.38);
        dc.fillCircle(x + s * 0.32, y - s * 0.18, s * 0.38);
        dc.fillPolygon([[(x - s * 0.62).toNumber(), (y - 0.02 * s).toNumber()],
                        [(x + s * 0.62).toNumber(), (y - 0.02 * s).toNumber()],
                        [x.toNumber(), (y + s * 0.72).toNumber()]]);
    }

    private function shoe(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                          col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.10, y - s * 0.22, s * 0.36);
        dc.fillCircle(x + s * 0.16, y + s * 0.30, s * 0.24);
    }

    private function batteryIcon(dc as Graphics.Dc, x as Float, y as Float,
                                 w as Float, h as Float, frac as Float,
                                 col as Number) as Void {
        dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x - w / 2, y - h / 2, w, h, 2);
        dc.fillRectangle(x + w / 2 + 1, y - h * 0.20, 3, h * 0.40);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var pad = 3;
        var fw = (w - 2 * pad) * frac;
        if (fw > 1) {
            dc.fillRectangle(x - w / 2 + pad, y - h / 2 + pad, fw, h - 2 * pad);
        }
    }

    private function flame(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                           col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y + s * 0.22, s * 0.40);
        dc.fillPolygon([[(x - s * 0.38).toNumber(), (y + s * 0.30).toNumber()],
                        [(x + s * 0.38).toNumber(), (y + s * 0.30).toNumber()],
                        [x.toNumber(), (y - s * 0.62).toNumber()]]);
    }

    private function bolt(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                          col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[(x + s * 0.28).toNumber(), (y - s * 0.55).toNumber()],
                        [(x - s * 0.30).toNumber(), (y + s * 0.10).toNumber()],
                        [(x - s * 0.02).toNumber(), (y + s * 0.10).toNumber()],
                        [(x - s * 0.28).toNumber(), (y + s * 0.55).toNumber()],
                        [(x + s * 0.30).toNumber(), (y - s * 0.10).toNumber()],
                        [(x + s * 0.02).toNumber(), (y - s * 0.10).toNumber()]]);
    }

    private function thermo(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                            col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x, y - s * 0.6, x, y + s * 0.15);
        dc.fillCircle(x, y + s * 0.45, s * 0.32);
    }

    private function sunIcon(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                             col as Number, rising as Boolean) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(x, y, s * 0.5, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawLine(x - s * 0.85, y, x + s * 0.85, y);
        var ay = rising ? y - s * 0.95 : y + s * 0.15;
        var tip = rising ? ay - s * 0.30 : ay + s * 0.30;
        dc.fillPolygon([[(x - s * 0.22).toNumber(), ay.toNumber()],
                        [(x + s * 0.22).toNumber(), ay.toNumber()],
                        [x.toNumber(), tip.toNumber()]]);
    }

    private function field(dc as Graphics.Dc, x as Float, y as Float, v as String) as Void {
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_TINY, v,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function mix(c1 as Number, c2 as Number, t as Float) as Number {
        var r = ((c1 >> 16 & 0xFF) * (1 - t) + (c2 >> 16 & 0xFF) * t).toNumber();
        var g = ((c1 >> 8 & 0xFF) * (1 - t) + (c2 >> 8 & 0xFF) * t).toNumber();
        var b = ((c1 & 0xFF) * (1 - t) + (c2 & 0xFF) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // ------------------------------------------------------------------- data
    private function dateStr() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var day = (info.day instanceof Number) ? info.day.format("%d") : "";
        var dow = (info.day_of_week instanceof String) ? (info.day_of_week as String).toUpper() : "";
        if (dow.length() > 3) { dow = dow.substring(0, 3); }
        return dow + " " + day;
    }

    private function hrStr() as String {
        var hr = null;
        try {
            var act = Activity.getActivityInfo();
            if (act != null && act.currentHeartRate != null) {
                hr = act.currentHeartRate;
            } else if (Toybox has :SensorHistory
                       && (Toybox.SensorHistory has :getHeartRateHistory)) {
                var it = Toybox.SensorHistory.getHeartRateHistory({:period => 1});
                if (it != null) {
                    var s = it.next();
                    if (s != null && s.data != null) { hr = s.data.toNumber(); }
                }
            }
        } catch (e) {}
        return hr == null ? "--" : hr.toString();
    }

    private function tempStr() as String {
        try {
            if (Toybox has :Weather) {
                var cc = Toybox.Weather.getCurrentConditions();
                if (cc != null && cc.temperature != null) {
                    var t = cc.temperature;
                    if (System.getDeviceSettings().temperatureUnits
                        == System.UNIT_STATUTE) {
                        t = t * 9 / 5 + 32;
                    }
                    return t.format("%d") + "°";
                }
            }
        } catch (e) {}
        return "";
    }

    private function stepsStr() as String {
        try {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.steps != null) { return info.steps.toString(); }
        } catch (e) {}
        return "--";
    }

    private function stepsFrac() as Float {
        try {
            var info = ActivityMonitor.getInfo();
            var steps = (info != null && info.steps != null) ? info.steps : 0;
            var goal = (info != null && info.stepGoal != null && info.stepGoal > 0)
                       ? info.stepGoal : 10000;
            var f = steps.toFloat() / goal;
            return f > 1.0 ? 1.0 : f;
        } catch (e) {}
        return 0.0;
    }

    private function caloriesStr() as String {
        try {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.calories != null) { return info.calories.toString(); }
        } catch (e) {}
        return "--";
    }

    private function batteryFrac() as Float {
        var f = System.getSystemStats().battery / 100.0;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f;
    }

    // "8d" days-remaining like the stock face when available, else percent.
    private function batteryStr() as String {
        try {
            var stats = System.getSystemStats();
            if (stats has :batteryInDays && stats.batteryInDays != null
                && stats.batteryInDays > 0) {
                return stats.batteryInDays.toNumber().toString() + "d";
            }
        } catch (e) {}
        return (batteryFrac() * 100).toNumber().toString();
    }

    private function bodyBatteryStr() as String {
        var v = bodyBatteryNum();
        return v == null ? "--" : v.toString();
    }

    private function bodyBatteryFrac() as Float {
        var v = bodyBatteryNum();
        return v == null ? 0.0 : v / 100.0;
    }

    private function bodyBatteryNum() as Number? {
        try {
            if (Toybox has :SensorHistory
                && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var it = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
                if (it != null) {
                    var s = it.next();
                    if (s != null && s.data != null) { return s.data.toNumber(); }
                }
            }
        } catch (e) {}
        return null;
    }

    private function refreshSunTimes() as Void {
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (today.day == _sunDay) { return; }
        var rise = "--:--"; var set = "--:--";
        try {
            if (Toybox has :Weather) {
                var cc = Toybox.Weather.getCurrentConditions();
                if (cc != null && cc.observationLocationPosition != null
                    && (Toybox.Weather has :getSunrise)) {
                    var pos = cc.observationLocationPosition;
                    var now = Time.now();
                    var r = Toybox.Weather.getSunrise(pos, now);
                    if (r != null) { rise = fmtMoment(r); }
                    var s = Toybox.Weather.getSunset(pos, now);
                    if (s != null) { set = fmtMoment(s); }
                }
            }
        } catch (e) {}
        _sunRise = rise;
        _sunSet = set;
        _sunDay = today.day;
    }

    private function fmtMoment(m as Time.Moment) as String {
        var g = Gregorian.info(m, Time.FORMAT_SHORT);
        var h = g.hour;
        if (!System.getDeviceSettings().is24Hour) { h = ((h + 11) % 12) + 1; }
        return h.format("%d") + ":" + g.min.format("%02d");
    }
}
