import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Application.Properties as Props;

// Color tokens + resolved user settings (specs/.../design.md §3, §5).
// Active colors are used in high-power; *_DIM in always-on to cut lit pixels
// and mitigate burn-in (Constitution Article IV).
class Theme {
    // --- settings ---
    public var dialTheme as Number = 0;   // 0 Black Ceramic, 1 Dawn
    public var accentColor as Number = 0; // 0 Bronze, 1 Red
    public var leftSub as Number = 0;     // 0 24h,1 HR,2 Body,3 Off
    public var rightSub as Number = 0;    // 0 Batt,1 Steps,2 Active,3 Off
    public var secondsMode as Number = 0; // 0 sweep+hide AOD,1 hidden
    public var dawnSweep as Boolean = true;

    // --- runtime ---
    public var lowPower as Boolean = false;
    public var dirty as Boolean = true;   // static art needs rebuild

    // Active / dim token pairs (see design.md §3). Vars (not const) because
    // Monkey C const initializers must be scalar, not array literals.
    private var C_CERAMIC = [0x05070A, 0x000000];
    private var C_WAVE_LO = [0x0A0E13, 0x040506];
    private var C_WAVE_HI = [0x1B232C, 0x0B0E11];
    private var C_BEZEL   = [0x0A0C10, 0x000000];
    private var C_ENAMEL  = [0xF2F4F5, 0x9AA0A6];
    private var C_RHOD_HI = [0xDCE2E8, 0x7E848A];
    private var C_RHOD    = [0xAAB0B6, 0x595E63];
    private var C_RHOD_LO = [0x6E747A, 0x34383C];
    private var C_BRZ_HI  = [0xE9CD94, 0x6E5E3C];
    private var C_BRZ     = [0xC79A5B, 0x5C4A2C];
    private var C_BRZ_LO  = [0x8A6A36, 0x3C2F1C];
    private var C_LUME    = [0xEAF3EC, 0x39524A];
    private var C_LUMEGL  = [0x8FE9C0, 0x2E5F4C];
    private var C_RED     = [0xE4261B, 0x6E1712];
    private var C_TEXTDIM = [0xC9CDD2, 0x70757A];

    public const DAWN_WARM = 0xFF8A3D;
    public const DAWN_COOL = 0xFFD27A;

    public function initialize() {}

    public function load() as Void {
        dialTheme   = readNum("DialTheme", 0);
        accentColor = readNum("AccentColor", 0);
        leftSub     = readNum("LeftSubdial", 0);
        rightSub    = readNum("RightSubdial", 0);
        secondsMode = readNum("SecondsMode", 0);
        dawnSweep   = readBool("DawnSweep", true);
        dirty = true;
    }

    private function readNum(key as String, def as Number) as Number {
        var v = null;
        try { v = Props.getValue(key); } catch (e) { v = null; }
        return (v instanceof Number) ? v : ((v instanceof Float) ? v.toNumber() : def);
    }

    private function readBool(key as String, def as Boolean) as Boolean {
        var v = null;
        try { v = Props.getValue(key); } catch (e) { v = null; }
        return (v instanceof Boolean) ? v : def;
    }

    private function pick(pair as Array<Number>) as Number {
        return lowPower ? pair[1] : pair[0];
    }

    // --- resolved color accessors ---
    public function ceramicBase() as Number {
        var c = pick(C_CERAMIC);
        return (dialTheme == 1 && !lowPower) ? 0x0B0805 : c;
    }
    public function waveLo() as Number { return pick(C_WAVE_LO); }
    public function waveHi() as Number {
        var c = pick(C_WAVE_HI);
        return (dialTheme == 1 && !lowPower) ? 0x2A2418 : c;
    }
    public function bezel() as Number { return pick(C_BEZEL); }
    public function enamel() as Number { return pick(C_ENAMEL); }
    public function rhodiumHi() as Number { return pick(C_RHOD_HI); }
    public function rhodium() as Number { return pick(C_RHOD); }
    public function rhodiumLo() as Number { return pick(C_RHOD_LO); }
    public function bronzeHi() as Number { return pick(C_BRZ_HI); }
    public function bronze() as Number { return pick(C_BRZ); }
    public function bronzeLo() as Number { return pick(C_BRZ_LO); }
    public function lume() as Number { return pick(C_LUME); }
    public function lumeGlow() as Number { return pick(C_LUMEGL); }
    public function poppyRed() as Number { return pick(C_RED); }
    public function textDim() as Number { return pick(C_TEXTDIM); }

    // Accent set for the seconds hand & live marker tips.
    public function accentMain() as Number {
        return accentColor == 1 ? poppyRed() : bronze();
    }
    public function accentHi() as Number {
        return accentColor == 1 ? 0xFF6A5E : bronzeHi();
    }
    public function accentLo() as Number {
        return accentColor == 1 ? 0x8E1610 : bronzeLo();
    }
}
