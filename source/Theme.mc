import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Application.Properties as Props;

// Color tokens + resolved user settings (specs/.../fidelity-v2.md §1).
// Active colors are used in high-power; the dimmed variant (index 1, ~40%
// channel value, hue preserved) in always-on to cut lit pixels and mitigate
// burn-in (Constitution Article IV).
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

    // Active / dim token pairs (fidelity-v2.md §1). Vars (not const) because
    // Monkey C const initializers must be scalar, not array literals.
    // Dial + wave field
    private var C_CERAMIC    = [0x0A0A0B, 0x040404]; // CERAMIC_BASE — dead-neutral black
    private var C_WAVE_RIDGE = [0x0E0E10, 0x060606]; // WAVE_RIDGE face fill
    private var C_WAVE_HI    = [0x3A3A3C, 0x171718]; // WAVE_HI crest highlight
    private var C_WAVE_GLOSS = [0x4A4A4A, 0x1E1E1E]; // WAVE_HI in upper-left gloss zone
    private var C_WAVE_LO    = [0x020203, 0x010101]; // WAVE_GROOVE shadow stroke
    // Bezel + rehaut
    private var C_BEZEL      = [0x060608, 0x020203]; // BEZEL_BLACK
    private var C_SHEEN      = [0x1E2023, 0x0C0D0E]; // BEZEL_SHEEN bevel band
    private var C_SHEEN_HI   = [0x2E3033, 0x121314]; // BEZEL_SHEEN specular arc (upper-left)
    private var C_REHAUT     = [0x0A0B0D, 0x040405]; // REHAUT gasket ring
    private var C_REHAUT_LN  = [0x26282B, 0x0F1011]; // REHAUT_LINE hairline
    private var C_ENAMEL     = [0xF2F3F5, 0x616162]; // ENAMEL_WHITE numerals/batons/triangle
    private var C_BEZEL_DOT  = [0xF6F6F6, 0x626262]; // BEZEL_DOT minute-dot track
    private var C_FLANGE     = [0xE6E7E9, 0x5C5C5D]; // FLANGE_WHITE minute-track ticks/dots
    // Steel / rhodium
    private var C_STEEL_HI   = [0xE0E0E4, 0x5A5A5B]; // STEEL_HI top facets, subdial hands
    private var C_STEEL_MID  = [0xAAB0B6, 0x444649]; // STEEL_MID hub ring, mid facets
    private var C_STEEL_LO   = [0x55585C, 0x222325]; // STEEL_LO flank edges
    // Applied markers
    private var C_MARKER_RIM = [0xDFE3E7, 0x595B5C]; // MARKER_RIM applied rims
    private var C_MARKER_SH  = [0x2B2D30, 0x111213]; // MARKER_SHADOW step ring
    // Bronze (rose/Sedna — pink, not brass)
    private var C_BRZ_HI     = [0xE3C4AF, 0x5B4E46]; // BRONZE_HI lit facet
    private var C_BRZ        = [0xC49B7E, 0x4E3E32]; // BRONZE_MID main tone
    private var C_BRZ_LO     = [0x7E5B44, 0x32241B]; // BRONZE_LO shadow facet
    private var C_BRZ_RING   = [0xC89E82, 0x503F34]; // BRONZE_RING right-sub annulus
    private var C_BRZ_SLOT   = [0x5A4436, 0x241B16]; // hub-cap dark slot
    private var C_RING_PRINT = [0x241A12, 0x0E0A07]; // RING_PRINT black on bronze
    // Lume (neutral white — mint tint killed per spec)
    private var C_LUME       = [0xF6F7F8, 0x626363]; // LUME_WHITE markers
    private var C_LUME_HAND  = [0xF4F6F4, 0x626262]; // LUME_HAND hand fills
    private var C_LUME_HOT   = [0xFEFFFF, 0x666666]; // lume hotspot / lollipop fill
    private var C_PEARL      = [0xEBEAE8, 0x5E5E5D]; // LUME_PEARL bezel pearl
    private var C_PEARL_RIM  = [0x9A9C9E, 0x3E3E3F]; // pearl rim
    // Print + text
    private var C_RED        = [0x8C2040, 0x380D1A]; // RED_SCRIPT wine/raspberry Seamaster
    private var C_TEXT_HI    = [0xE7E7E7, 0x5C5C5C]; // TEXT_HI Ω + OMEGA wordmark
    private var C_TEXT_MID   = [0xD6D6D6, 0x565656]; // TEXT_MID PROFESSIONAL / lower stack
    private var C_TEXTDIM    = [0x909092, 0x3A3A3A]; // TEXT_DIM SWISS MADE arc
    private var C_ZRO2       = [0x424244, 0x1A1A1B]; // ZRO2_GRAY [ZrO₂] mark
    // Date window
    private var C_DATE_FRAME = [0x141416, 0x080809]; // DATE_FRAME glossy bevel
    private var C_DATE_SPEC  = [0x2A2A2C, 0x111112]; // frame inner-top specular hairline
    private var C_DATE_AP    = [0x0B0B0C, 0x040405]; // DATE_APERTURE recess interior
    private var C_DATE_NUM   = [0xC9C9CA, 0x505051]; // DATE_NUMERAL
    // Subdial recesses
    private var C_SUB_FLANGE = [0x28282A, 0x101011]; // SUB_FLANGE recess flange
    private var C_SNAIL_BASE = [0x0D0D0D, 0x050505]; // SNAIL_BASE snailed center
    private var C_SNAIL_GRV  = [0x242426, 0x0E0E0F]; // SNAIL_GROOVE highlight rings
    private var C_SUB_PRINT  = [0xE8EAEA, 0x5D5E5E]; // SUB_PRINT left-sub scale

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
    // Dial + wave
    public function ceramicBase() as Number {
        var c = pick(C_CERAMIC);
        return (dialTheme == 1 && !lowPower) ? 0x0B0805 : c;
    }
    public function waveRidge() as Number { return pick(C_WAVE_RIDGE); }
    public function waveLo() as Number { return pick(C_WAVE_LO); }      // groove shadow
    public function waveGroove() as Number { return pick(C_WAVE_LO); }  // spec-name alias
    public function waveHi() as Number {
        var c = pick(C_WAVE_HI);
        return (dialTheme == 1 && !lowPower) ? 0x2A2418 : c;
    }
    public function waveGloss() as Number { return pick(C_WAVE_GLOSS); }
    // Bezel + rehaut
    public function bezel() as Number { return pick(C_BEZEL); }
    public function bezelSheen() as Number { return pick(C_SHEEN); }
    public function bezelSheenHi() as Number { return pick(C_SHEEN_HI); }
    public function rehaut() as Number { return pick(C_REHAUT); }
    public function rehautLine() as Number { return pick(C_REHAUT_LN); }
    public function enamel() as Number { return pick(C_ENAMEL); }
    public function bezelDot() as Number { return pick(C_BEZEL_DOT); }
    public function flangeWhite() as Number { return pick(C_FLANGE); }
    // Steel / rhodium (rhodium* kept for existing call sites; steel* = spec names)
    public function rhodiumHi() as Number { return pick(C_STEEL_HI); }
    public function rhodium() as Number { return pick(C_STEEL_MID); }
    public function rhodiumLo() as Number { return pick(C_STEEL_LO); }
    public function steelHi() as Number { return pick(C_STEEL_HI); }
    public function steel() as Number { return pick(C_STEEL_MID); }
    public function steelLo() as Number { return pick(C_STEEL_LO); }
    // Applied markers
    public function markerRim() as Number { return pick(C_MARKER_RIM); }
    public function markerShadow() as Number { return pick(C_MARKER_SH); }
    // Bronze
    public function bronzeHi() as Number { return pick(C_BRZ_HI); }
    public function bronze() as Number { return pick(C_BRZ); }
    public function bronzeLo() as Number { return pick(C_BRZ_LO); }
    public function bronzeRing() as Number { return pick(C_BRZ_RING); }
    public function bronzeSlot() as Number { return pick(C_BRZ_SLOT); }
    public function ringPrint() as Number { return pick(C_RING_PRINT); }
    // Lume
    public function lume() as Number { return pick(C_LUME); }
    public function lumeHand() as Number { return pick(C_LUME_HAND); }
    public function lumeGlow() as Number { return pick(C_LUME_HOT); }
    public function lumePearl() as Number { return pick(C_PEARL); }
    public function pearlRim() as Number { return pick(C_PEARL_RIM); }
    // Print + text
    public function poppyRed() as Number { return pick(C_RED); }        // legacy name
    public function redScript() as Number { return pick(C_RED); }       // spec-name alias
    public function textHi() as Number { return pick(C_TEXT_HI); }
    public function textMid() as Number { return pick(C_TEXT_MID); }
    public function textDim() as Number { return pick(C_TEXTDIM); }
    public function zro2Gray() as Number { return pick(C_ZRO2); }
    // Date window
    public function dateFrame() as Number { return pick(C_DATE_FRAME); }
    public function dateSpecular() as Number { return pick(C_DATE_SPEC); }
    public function dateAperture() as Number { return pick(C_DATE_AP); }
    public function dateNumeral() as Number { return pick(C_DATE_NUM); }
    // Subdial recesses
    public function subdialRecess() as Number { return pick(C_SUB_FLANGE); }
    public function snailBase() as Number { return pick(C_SNAIL_BASE); }
    public function snailGroove() as Number { return pick(C_SNAIL_GRV); }
    public function subPrint() as Number { return pick(C_SUB_PRINT); }

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
