import Toybox.Lang;
using Toybox.Math;

// Resolution-independent geometry. All radii are fractions of R = W/2 so the
// face scales to any round display (Constitution Article III).
// Angles are measured clockwise from 12 o'clock (screen "up").
class Geometry {
    public var cx as Float = 0.0;
    public var cy as Float = 0.0;
    public var R as Float = 0.0;
    public var w as Number = 0;
    public var h as Number = 0;

    // Radius tokens (× R) — see specs/.../design.md §2.
    public const BEZEL_OUTER = 1.000;
    public const BEZEL_INNER = 0.905;
    public const DIAL_R = 0.885;
    public const CHAPTER_R = 0.840;
    public const MARKER_OUTER = 0.820;
    public const MARKER_INNER = 0.720;
    public const SUB_OFFSET = 0.430;
    public const SUB_R = 0.150;
    public const DATE_OFFSET = 0.470;
    public const LOGO_R = 0.430;
    public const HOUR_LEN = 0.520;
    public const MIN_LEN = 0.760;
    public const SEC_LEN = 0.820;
    public const SEC_TAIL = 0.180;
    public const SEC_LOLLIPOP_R = 0.030;
    public const HAND_HUB_R = 0.052;

    public function initialize() {}

    public function setBounds(width as Number, height as Number) as Void {
        w = width;
        h = height;
        cx = width / 2.0;
        cy = height / 2.0;
        R = (width < height ? width : height) / 2.0;
    }

    // Absolute radius in pixels for a fraction of R.
    public function rad(frac as Numeric) as Float {
        return R * frac;
    }

    // Point [x, y] at a given dial fraction (0..1, 0 = 12 o'clock) and radius fraction.
    public function ptFrac(dialFrac as Numeric, rFrac as Numeric) as Array {
        var a = dialFrac * 2.0 * Math.PI;
        return [cx + R * rFrac * Math.sin(a), cy - R * rFrac * Math.cos(a)];
    }

    // Point at an explicit angle (radians, clockwise from up) about an arbitrary
    // center, at an absolute radius in pixels.
    public function ptAt(ox as Numeric, oy as Numeric, angle as Numeric, r as Numeric) as Array {
        return [ox + r * Math.sin(angle), oy - r * Math.cos(angle)];
    }

    // Convenience centers.
    public function leftSubCenter() as Array {
        return [cx - R * SUB_OFFSET, cy];
    }
    public function rightSubCenter() as Array {
        return [cx + R * SUB_OFFSET, cy];
    }
    public function dateCenter() as Array {
        return [cx, cy + R * DATE_OFFSET];
    }
}
