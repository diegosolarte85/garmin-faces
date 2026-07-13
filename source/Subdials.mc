import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.ActivityMonitor;
using Toybox.Activity;

// Dynamic complications: the 9 o'clock and 3 o'clock subdial hands/values and
// the 6 o'clock date number. Every sensor read is null-safe (R2.5, Article V).
class Subdials {
    private var _geo as Geometry;

    public function initialize(geo as Geometry) {
        _geo = geo;
    }

    public function drawDate(dc as Graphics.Dc, theme as Theme, day as Number) as Void {
        var c = _geo.dateCenter();
        dc.setColor(theme.enamel(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(c[0], c[1], Graphics.FONT_TINY, day.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // 9 o'clock: default 24-hour hand; or HR / Body Battery; or Off.
    public function drawLeft(dc as Graphics.Dc, theme as Theme, clockHour as Number, clockMin as Number) as Void {
        var c = _geo.leftSubCenter();
        switch (theme.leftSub) {
            case 0: { // 24-hour hand
                var frac = ((clockHour % 24) + clockMin / 60.0) / 24.0;
                hand(dc, theme, c, frac, theme.rhodiumHi(), 0.74);
                break;
            }
            case 1: { // heart rate
                var hr = readHeartRate();
                if (hr != null) {
                    hand(dc, theme, c, clampFrac(hr, 40, 200), theme.poppyRed(), 0.70);
                } else {
                }
                break;
            }
            case 2: { // body battery
                var bb = readBodyBattery();
                if (bb != null) {
                    hand(dc, theme, c, bb / 100.0, theme.lumeGlow(), 0.70);
                } else {
                }
                break;
            }
            default: break; // Off
        }
    }

    // 3 o'clock (bronze): default Battery; or Steps / Active minutes; or Off.
    public function drawRight(dc as Graphics.Dc, theme as Theme) as Void {
        var c = _geo.rightSubCenter();
        switch (theme.rightSub) {
            case 0: { // battery %
                var pct = System.getSystemStats().battery;
                hand(dc, theme, c, pct / 100.0, theme.accentMain(), 0.70);
                break;
            }
            case 1: { // steps vs goal
                var info = ActivityMonitor.getInfo();
                var steps = (info != null && info.steps != null) ? info.steps : 0;
                var goal = (info != null && info.stepGoal != null && info.stepGoal > 0) ? info.stepGoal : 10000;
                hand(dc, theme, c, frac01(steps.toFloat() / goal), theme.accentMain(), 0.70);
                break;
            }
            case 2: { // active minutes vs weekly goal
                var info = ActivityMonitor.getInfo();
                var am = 0;
                var goal = 150;
                if (info != null && info.activeMinutesWeek != null && info.activeMinutesWeek.total != null) {
                    am = info.activeMinutesWeek.total;
                }
                if (info != null && info has :activeMinutesWeekGoal && info.activeMinutesWeekGoal != null && info.activeMinutesWeekGoal > 0) {
                    goal = info.activeMinutesWeekGoal;
                }
                hand(dc, theme, c, frac01(am.toFloat() / goal), theme.accentMain(), 0.70);
                break;
            }
            default: break; // Off
        }
    }

    // --- helpers ---
    private function hand(dc as Graphics.Dc, theme as Theme, c as Array,
                          frac as Numeric, color as Number, lenFrac as Numeric) as Void {
        var r = _geo.rad(_geo.SUB_R);
        var sc = frac * 2.0 * Math.PI;
        var sinT = Math.sin(sc); var cosT = Math.cos(sc);
        var w = r * 0.06;
        var len = r * lenFrac;
        var tail = r * 0.18;
        var poly = [[-w, -tail], [w, -tail], [w * 0.5, len], [-w * 0.5, len]];
        Draw.poly(dc, c[0], c[1], sinT, cosT, poly, color);
        Draw.dot(dc, c[0], c[1], r * 0.09, color);
    }

    private function label(dc as Graphics.Dc, theme as Theme, c as Array, txt as String) as Void {
        dc.setColor(theme.textDim(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(c[0], c[1] + _geo.rad(_geo.SUB_R) * 0.42, Graphics.FONT_XTINY, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function clampFrac(v as Number, lo as Number, hi as Number) as Numeric {
        var f = (v - lo).toFloat() / (hi - lo);
        return frac01(f);
    }

    private function frac01(f as Numeric) as Numeric {
        if (f < 0.0) { return 0.0; }
        if (f > 1.0) { return 1.0; }
        return f;
    }

    private function shortNum(n as Number) as String {
        if (n >= 10000) { return (n / 1000).format("%d") + "k"; }
        if (n >= 1000) { return (n / 1000.0).format("%.1f") + "k"; }
        return n.toString();
    }

    private function readHeartRate() as Number? {
        try {
            var act = Activity.getActivityInfo();
            if (act != null && act.currentHeartRate != null) {
                return act.currentHeartRate;
            }
            if (Toybox has :SensorHistory && (Toybox.SensorHistory has :getHeartRateHistory)) {
                var it = Toybox.SensorHistory.getHeartRateHistory({:period => 1});
                if (it != null) {
                    var s = it.next();
                    if (s != null && s.data != null) { return s.data.toNumber(); }
                }
            }
        } catch (e) {}
        return null;
    }

    private function readBodyBattery() as Number? {
        try {
            if (Toybox has :SensorHistory && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var it = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
                if (it != null) {
                    var s = it.next();
                    if (s != null && s.data != null) { return s.data.toNumber(); }
                }
            }
        } catch (e) {}
        return null;
    }
}
