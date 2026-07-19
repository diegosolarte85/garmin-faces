import Toybox.Lang;
import Toybox.Graphics;
using Toybox.System;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.ActivityMonitor;
using Toybox.Activity;

// The two digital styles of First Light (FaceStyle 1 = Digital, 2 = Sport).
// The wave background + trident + wordmark are a baked bitmap (DialDigital*);
// everything here is the live layer: time, date, gauges and tracking fields.
// Layout fractions match tools/gen_digital_mocks.py (unit = Geometry.R).
class DigitalFace {
    private var _geo as Geometry;

    // Family palette (matches the mocks + AOD lume)
    private const LUME as Number = 0xE8F4EE;
    private const TEAL as Number = 0x59B6A4;
    private const GOLD as Number = 0xC8A05A;
    private const RED  as Number = 0xC82A22;
    private const DIMC as Number = 0x9AA2A6;
    private const TRACK as Number = 0x2A3234;   // gauge arc background

    // sunrise/sunset cache (recomputed once per day)
    private var _sunDay as Number = -1;
    private var _sunRise as String = "--:--";
    private var _sunSet as String = "--:--";

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    // ------------------------------------------------------------------ active
    public function draw(dc as Graphics.Dc, theme as Theme, showSec as Boolean) as Void {
        var clock = System.getClockTime();
        var cx = _geo.cx; var cy = _geo.cy;
        var is24 = System.getDeviceSettings().is24Hour;
        var hh = is24 ? clock.hour : (((clock.hour + 11) % 12) + 1);
        var timeStr = hh.format(is24 ? "%02d" : "%d") + ":" + clock.min.format("%02d");

        // date — shared slot in both styles
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - _geo.rad(0.245), Graphics.FONT_TINY, dateStr(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (theme.faceStyle == 2) {
            drawSport(dc, theme, timeStr, clock, showSec);
        } else {
            drawDigital(dc, theme, timeStr, clock, is24, showSec);
        }
    }

    private function drawDigital(dc as Graphics.Dc, theme as Theme, timeStr as String,
                                 clock as System.ClockTime, is24 as Boolean,
                                 showSec as Boolean) as Void {
        var cx = _geo.cx; var cy = _geo.cy;

        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + _geo.rad(0.005), Graphics.FONT_NUMBER_THAI_HOT, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!is24) {
            dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - _geo.rad(0.265), cy + _geo.rad(0.225), Graphics.FONT_XTINY,
                        clock.hour < 12 ? "AM" : "PM",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        if (showSec) {
            drawSeconds(dc, theme, clock.sec);
        }

        // divider
        dc.setColor(0x3A4042, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx - _geo.rad(0.30), cy + _geo.rad(0.315),
                    cx + _geo.rad(0.30), cy + _geo.rad(0.315));

        // data fields: HR / steps / battery
        var fy = cy + _geo.rad(0.415);
        var iy = fy - _geo.rad(0.020);
        var vy = fy + _geo.rad(0.062);
        var xL = cx - _geo.rad(0.300);
        var xR = cx + _geo.rad(0.295);

        heart(dc, xL, iy, _geo.rad(0.044), RED);
        field(dc, xL, vy, hrStr());
        shoe(dc, cx - _geo.rad(0.008), iy, _geo.rad(0.048), TEAL);
        field(dc, cx - _geo.rad(0.005), vy, stepsStr());
        batteryIcon(dc, xR, iy, _geo.rad(0.080), _geo.rad(0.040), batteryFrac(), GOLD);
        field(dc, xR, vy, (batteryFrac() * 100).toNumber().toString());
    }

    private function drawSport(dc as Graphics.Dc, theme as Theme, timeStr as String,
                               clock as System.ClockTime, showSec as Boolean) as Void {
        var cx = _geo.cx; var cy = _geo.cy;
        var gr = _geo.rad(0.700);
        var pen = _geo.rad(0.014).toNumber();
        if (pen < 3) { pen = 3; }

        // left arc: steps vs goal.  Graphics degrees are CCW from 3 o'clock;
        // the arc spans the left side (120..240) and fills from the top down.
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

        // right arc: battery, filling from the top down
        dc.setPenWidth(pen);
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, gr, Graphics.ARC_COUNTER_CLOCKWISE, 300, 60);
        var bf = batteryFrac();
        if (bf > 0.01) {
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, gr, Graphics.ARC_CLOCKWISE, 60,
                       (60 - 120 * bf).toNumber());
        }
        batteryIcon(dc, cx + _geo.rad(0.585), cy, _geo.rad(0.062), _geo.rad(0.032), bf, GOLD);

        // time
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - _geo.rad(0.150), Graphics.FONT_NUMBER_HOT, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (showSec) {
            drawSeconds(dc, theme, clock.sec);
        }

        // heart rate row
        heart(dc, cx - _geo.rad(0.150), cy + _geo.rad(0.078), _geo.rad(0.042), RED);
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + _geo.rad(0.015), cy + _geo.rad(0.085), Graphics.FONT_NUMBER_MILD,
                    hrStr(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + _geo.rad(0.160), cy + _geo.rad(0.098), Graphics.FONT_XTINY, "BPM",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // body battery + floors
        var ry = cy + _geo.rad(0.250);
        dc.setColor(TEAL, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - _geo.rad(0.235), ry - _geo.rad(0.012), _geo.rad(0.028));
        field(dc, cx - _geo.rad(0.150), ry, bodyBatteryStr());
        stairs(dc, cx + _geo.rad(0.095), ry - _geo.rad(0.012), _geo.rad(0.040), GOLD);
        field(dc, cx + _geo.rad(0.190), ry, floorsStr());

        // sunrise / sunset
        refreshSunTimes();
        var by = cy + _geo.rad(0.425);
        sunIcon(dc, cx - _geo.rad(0.215), by, _geo.rad(0.042), GOLD, true);
        dc.setColor(DIMC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - _geo.rad(0.100), by, Graphics.FONT_XTINY, _sunRise,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        sunIcon(dc, cx + _geo.rad(0.085), by, _geo.rad(0.042), 0xB07A4A, false);
        dc.drawText(cx + _geo.rad(0.200), by, Graphics.FONT_XTINY, _sunSet,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Seconds slot (also repainted from onPartialUpdate through drawSeconds).
    public function secondsPos(style as Number) as Array<Float> {
        if (style == 2) {
            return [_geo.cx + _geo.rad(0.545), _geo.cy - _geo.rad(0.075)];
        }
        return [_geo.cx + _geo.rad(0.265), _geo.cy + _geo.rad(0.225)];
    }

    public function drawSeconds(dc as Graphics.Dc, theme as Theme, sec as Number) as Void {
        var p = secondsPos(theme.faceStyle);
        dc.setColor(TEAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(p[0], p[1], Graphics.FONT_NUMBER_MILD, sec.format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Clip box for the per-second partial update.
    public function secBox(style as Number) as Array<Number> {
        var p = secondsPos(style);
        var hw = _geo.rad(0.110); var hh = _geo.rad(0.085);
        return [(p[0] - hw).toNumber(), (p[1] - hh).toNumber(),
                (p[0] + hw).toNumber(), (p[1] + hh).toNumber()];
    }

    // -------------------------------------------------------------- always-on
    // Dim time only — few lit pixels, instantly readable.
    public function drawAod(dc as Graphics.Dc, theme as Theme) as Void {
        var clock = System.getClockTime();
        var cx = _geo.cx; var cy = _geo.cy;
        var is24 = System.getDeviceSettings().is24Hour;
        var hh = is24 ? clock.hour : (((clock.hour + 11) % 12) + 1);
        var timeStr = hh.format(is24 ? "%02d" : "%d") + ":" + clock.min.format("%02d");

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0x8A9694, Graphics.COLOR_TRANSPARENT);   // dim lume gray-teal
        dc.drawText(cx, cy - _geo.rad(0.040),
                    theme.faceStyle == 2 ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_THAI_HOT,
                    timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x5A6462, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + _geo.rad(0.170), Graphics.FONT_TINY, dateStr(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------ icons
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

    private function stairs(dc as Graphics.Dc, x as Float, y as Float, s as Float,
                            col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(x - s * 0.6, y + s * 0.5, x - s * 0.2, y + s * 0.5);
        dc.drawLine(x - s * 0.2, y + s * 0.5, x - s * 0.2, y + s * 0.1);
        dc.drawLine(x - s * 0.2, y + s * 0.1, x + s * 0.2, y + s * 0.1);
        dc.drawLine(x + s * 0.2, y + s * 0.1, x + s * 0.2, y - s * 0.3);
        dc.drawLine(x + s * 0.2, y - s * 0.3, x + s * 0.6, y - s * 0.3);
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

    private function batteryFrac() as Float {
        var f = System.getSystemStats().battery / 100.0;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f;
    }

    private function bodyBatteryStr() as String {
        try {
            if (Toybox has :SensorHistory
                && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var it = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
                if (it != null) {
                    var s = it.next();
                    if (s != null && s.data != null) { return s.data.toNumber().toString(); }
                }
            }
        } catch (e) {}
        return "--";
    }

    private function floorsStr() as String {
        try {
            var info = ActivityMonitor.getInfo();
            if (info != null && info has :floorsClimbed && info.floorsClimbed != null) {
                return info.floorsClimbed.toString();
            }
        } catch (e) {}
        return "--";
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
