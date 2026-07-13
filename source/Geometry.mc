import Toybox.Lang;
using Toybox.Math;

// Resolution-independent geometry. All radii are fractions of R = W/2 so the
// face scales to any round display (Constitution Article III).
// Angles are measured clockwise from 12 o'clock (screen "up").
// Values are the shared contract of specs/.../fidelity-v2.md §2 — the same
// numbers must appear in the constants block of tools/gen_preview.py.
class Geometry {
    public var cx as Float = 0.0;
    public var cy as Float = 0.0;
    public var R as Float = 0.0;
    public var w as Number = 0;
    public var h as Number = 0;

    // --- Radial architecture (§2.1) ---
    // The drawn bezel was removed — the physical Fenix 8 Pro bezel already
    // carries the dive scale, so drawing our own duplicated it and shrank the
    // dial. DIAL_FILL scales the radius unit so content designed within DIAL_R
    // (0.755) fills the screen to ~0.95 of the half-width. All tokens below are
    // still expressed in the original design space; the scale is applied once
    // in setBounds so every `R * token` grows together.
    public const DIAL_FILL   = 1.260;
    public const BEZEL_OUTER = 1.000;
    public const BEZEL_INNER = 0.775;   // (legacy — bezel no longer drawn)
    public const REHAUT_IN   = 0.755;
    public const REHAUT_OUT  = 0.775;
    public const DIAL_R      = 0.755;   // visible wave dial ends here

    // --- Bezel furniture (§2.2) ---
    public const BZ_NUM_R      = 0.875; // 10..50 numeral centers
    public const BZ_NUM_CAP    = 0.170; // numeral cap height
    public const BZ_NUM_STROKE = 0.033;
    public const BZ_NUM_GAP    = 0.040; // inter-digit gap
    public const BZ_DOT_TRACK  = 0.810; // minute-dot track radius
    public const BZ_DOT_D      = 0.024; // dot diameter
    public const BZ_BATON_W    = 0.030; // 5-min batons at 30/90/.../330 deg
    public const BZ_BATON_IN   = 0.795;
    public const BZ_BATON_OUT  = 0.965;
    public const BZ_TICK_W     = 0.011; // numeral-minute ticks at 60/.../300 deg
    public const BZ_TICK_L     = 0.027; //   centered on BZ_DOT_TRACK
    public const BZ_TRI_BASE_R = 0.955; // triangle at 12: outline only
    public const BZ_TRI_APEX_R = 0.800; //   apex points inward
    public const BZ_TRI_HALF_W = 0.125; //   base corners at tangential +/-0.125
    public const BZ_TRI_STROKE = 0.020;
    public const BZ_PEARL_R    = 0.900; // pearl center radius
    public const BZ_PEARL_D    = 0.071; // pearl diameter
    public const BZ_PEARL_RIM  = 0.008;

    // --- Dial minute-track flange (§2.3) ---
    public const CHAPTER_R    = 0.755;  // tick outer edge (= DIAL_R)
    public const TICK_IN      = 0.705;  // minute ticks, every 6 deg
    public const TICK_HALF_IN = 0.725;  // half-minute ticks, every 3 deg offset 3
    public const TICK_W       = 0.009;
    public const FLANGE_R     = 0.765;  // quarter-second dot arc (4 Hz), every 1.5 deg
    public const FLANGE_DOT_D = 0.007;
    public const FLANGE_GAP_DEG = 18;   // suppress ticks/dots +/-18 deg around 180

    // --- Hour markers (§2.4-2.6) ---
    public const MARKER_R        = 0.590;  // hour-dot center radius
    public const MARKER_DOT_R    = 0.052;  // lume disc radius (dia 0.104)
    public const MARKER_RIM_R    = 0.062;  // polished rim outer radius (dia 0.124)
    public const MARKER_RIM_W    = 0.008;
    public const MARKER_SHADOW_R = 0.066;  // shadow/step ring radius (dia 0.132)
    public const MARKER_OUTER    = 0.640;  // marker/bar outer alignment edge
    public const MARKER_INNER    = 0.458;  // 12 o'clock double-bar inner end
    public const BAR12_W         = 0.076;  // each bar of the double bar at 12
    public const BAR12_GAP       = 0.022;  // gap between the bars
    public const BAR12_CORNER    = 0.012;
    public const PLOT39_R        = 0.660;  // 3/9 lume rect center radius
    public const PLOT39_W        = 0.066;  //   tangential
    public const PLOT39_H        = 0.046;  //   radial
    public const PLOT6_R         = 0.667;  // 6 o'clock plot (wider than 3/9)
    public const PLOT6_W         = 0.085;
    public const PLOT6_H         = 0.050;
    public const PLOT_RIM_W      = 0.006;
    public const PLOT_CORNER     = 0.008;

    // --- Subdials (§2.7) ---
    public const SUB_OFFSET      = 0.415;  // centers at (+/-0.393, 0)
    public const SUB_R           = 0.150;  // recess outer (edge reaches 0.640)
    public const SUB_SNAIL_R     = 0.095;  // snailed black center
    public const SUB_SNAIL_PITCH = 0.006;  // snailing ring pitch
    public const SUB_RING_IN     = 0.095;  // right-sub bronze annulus
    public const SUB_RING_OUT    = 0.146;
    public const SUB_RING_W      = 0.051;  // = SUB_RING_OUT - SUB_RING_IN
    // Left (small seconds)
    public const SUBL_NUM_R    = 0.224;    // 10..60 numeral center radius
    public const SUBL_NUM_CAP  = 0.048;
    public const SUBL_TICK_IN  = 0.100;    // 5-second ticks
    public const SUBL_TICK_OUT = 0.122;
    public const SUBL_TICK_W   = 0.009;
    public const SUBL_DOT_R    = 0.187;    // 1-second dots
    public const SUBL_DOT_D    = 0.006;
    public const SUBL_HAND_LEN = 0.157;    // steel baton, no tail
    public const SUBL_HAND_W   = 0.020;
    public const SUBL_HUB_R    = 0.036;
    // Right (12h/60min counter)
    public const SUBR_NUM_R   = 0.201;     // 12-2-...-10 numeral center radius
    public const SUBR_NUM_CAP = 0.046;
    public const SUBR_TICK_W  = 0.011;     // odd-hour hairlines, full ring width
    public const SUBR_DOT_R   = 0.174;     // minute dots, four per 5-min sector
    public const SUBR_DOT_D   = 0.008;
    public const SUBR_MIN_LEN = 0.162;     // minute counter hand (steel, pointed)
    public const SUBR_MIN_W   = 0.016;
    public const SUBR_HR_LEN  = 0.124;     // hour counter hand (steel, lance tip)
    public const SUBR_HR_W    = 0.024;
    public const SUBR_HUB_R   = 0.029;

    // --- Date window at 6 (§2.8) ---
    public const DATE_OFFSET = 0.531;      // center (0, +0.531)
    public const DATE_W      = 0.174;      // portrait-leaning
    public const DATE_H      = 0.160;
    public const DATE_CORNER = 0.024;
    public const DATE_NUM_H  = 0.120;

    // --- Text block, vertical offsets from center (§2.9) ---
    public const TXT_OMEGA_SYM = 0.394;    // above center
    public const LOGO_R        = 0.313;    // OMEGA wordmark, above center
    public const TXT_SEAMASTER = 0.233;    // above
    public const TXT_PROF      = 0.126;    // above (clears the script's descenders)
    public const TXT_ZRO2      = 0.149;    // below
    public const TXT_COAXIAL   = 0.247;    // below
    public const TXT_MASTER    = 0.290;    // below
    public const TXT_DEPTH     = 0.335;    // below (300m / 1000ft)
    public const TXT_PITCH     = 0.043;    // lower-stack line pitch
    public const TXT_SWISS_R   = 0.715;    // SWISS MADE arc radius

    // --- Hands (§2.10) ---
    public const HOUR_LEN       = 0.440;   // blunt chamfered tip
    public const HOUR_W_MAX     = 0.120;   // frame width at the lume circle
    public const HOUR_W_HUB     = 0.046;   // frame width at hub exit
    public const HOUR_LUME_R    = 0.047;   // circular lume window radius
    public const HOUR_LUME_POS  = 0.372;   // lume window center radius
    public const HOUR_SLOT_IN   = 0.119;   // open skeleton slot
    public const HOUR_SLOT_OUT  = 0.302;
    public const HAND_RAIL_W    = 0.014;   // skeleton rail width (hour + minute)
    public const HAND_FRAME_STROKE = 0.008;
    public const MIN_LEN        = 0.680;
    public const MIN_W          = 0.048;   // shaft outer width
    public const MIN_ARROW_BASE = 0.530;   // lume arrowhead base radius
    public const MIN_ARROW_W    = 0.105;   // arrowhead base width
    public const MIN_SLOT_IN    = 0.110;
    public const MIN_SLOT_OUT   = 0.503;
    public const SEC_LEN        = 0.730;   // bronze chrono needle
    public const SEC_W          = 0.010;
    public const SEC_TAIL       = 0.270;   // plain tail — no counterweight disc
    public const SEC_LOLLIPOP_POS  = 0.485;  // mid-needle, not at tip
    public const SEC_LOLLIPOP_R    = 0.0375; // annulus outer radius
    public const SEC_LOLLIPOP_RIM  = 0.011;
    public const SEC_LOLLIPOP_LUME = 0.0265; // lume fill radius
    public const HAND_HUB_R  = 0.040;      // steel ring outer
    public const HUB_RING_W  = 0.006;
    public const HUB_CAP_R   = 0.029;      // bronze cap disc
    public const HUB_SLOT_W  = 0.009;      // dark slot across the cap

    // --- Wave field (§2.11) ---
    public const WAVE_PITCH = 0.075;       // crest-to-crest row pitch (~20 rows: finer detail)
    public const WAVE_AMP   = 0.032;       // undulation amplitude (flatter, more refined)
    public const WAVE_LEN   = 0.560;       // undulation wavelength

    public function initialize() {}

    public function setBounds(width as Number, height as Number) as Void {
        w = width;
        h = height;
        cx = width / 2.0;
        cy = height / 2.0;
        // Scale the radius unit up (no drawn bezel) so the dial fills the screen.
        R = ((width < height ? width : height) / 2.0) * DIAL_FILL;
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
