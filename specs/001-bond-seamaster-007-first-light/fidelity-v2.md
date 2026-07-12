# Fidelity Spec v2 — "007 First Light" Seamaster Diver 300M Chronograph

**Status: authoritative.** Merges the three lens critiques (bezel-markers, dial-typography, hands-subdials), with every conflict resolved against the reference photo (`scratchpad/ref_007.jpg`, dial center (320.1, 320.4), face radius 225 px). Both renderers — `tools/gen_preview.py` and the Monkey C source (`Geometry.mc`, `Theme.mc`, `DialRenderer.mc`, `Hands.mc`, `Subdials.mc`) — MUST consume these exact numbers. Any constant appearing in one renderer and not the other is a bug.

## 0. Coordinate convention (read first)

- **R = face radius = bezel outer edge = half the render width.** In the photo R = 225 px; on a 454 px device R = 227 px.
- All lengths below are fractions of R. All angles are degrees clockwise from 12 o'clock. "Above/below center" means along the vertical axis.
- The three source reports used different normalizations; all numbers here are already converted to this convention (bezel-lens ×1.000, typography-lens ×0.804, hands-lens ×0.914). Do not reuse raw numbers from the old reports.

## 1. Color tokens

| Token | Hex | Where used |
|---|---|---|
| `CERAMIC_BASE` | `#0A0A0B` | dial base fill (dead-neutral black — kill all blue bias) |
| `WAVE_RIDGE` | `#0E0E10` | wave ridge face fill |
| `WAVE_HI` | `#3A3A3C` | wave crest highlight stroke (raise to `#4A4A4A` in the upper-left gloss zone) |
| `WAVE_GROOVE` | `#020203` | wave groove shadow stroke |
| `BEZEL_BLACK` | `#060608` | bezel ceramic base |
| `BEZEL_SHEEN` | `#1E2023` → `#2E3033` | bezel bevel sheen band / specular arc (upper-left) |
| `REHAUT` | `#0A0B0D` | rehaut/gasket ring between dial and bezel |
| `REHAUT_LINE` | `#26282B` | 1 px hairline circle at the bezel inner edge |
| `ENAMEL_WHITE` | `#F2F3F5` | bezel numerals, batons, triangle outline |
| `BEZEL_DOT` | `#F6F6F6` | bezel minute-dot track |
| `FLANGE_WHITE` | `#E6E7E9` | dial minute-track ticks, half-ticks, quarter dots |
| `STEEL_HI` | `#E0E0E4` | hand top facets/rails, subdial hands, sub hub caps |
| `STEEL_MID` | `#AAB0B6` | center hub steel ring, mid facets |
| `STEEL_LO` | `#55585C` | hand flank edges (dark side of skeleton rails) |
| `MARKER_RIM` | `#DFE3E7` | applied rims of hour dots / bars / lume plots (+ `#FFFFFF` top-left highlight arc) |
| `MARKER_SHADOW` | `#2B2D30` | shadow/step ring separating every applied marker from the dial |
| `BRONZE_HI` | `#E3C4AF` | chrono-hand lit facet |
| `BRONZE_MID` | `#C49B7E` | chrono hand + hub cap main tone (rose/Sedna gold — NOT brass; R−G≈38, G−B≈25) |
| `BRONZE_LO` | `#7E5B44` | chrono-hand shadow facet |
| `BRONZE_RING` | `#C89E82` | right-subdial bronze annulus fill (optional shade to `#A8815F` at its south edge) |
| `RING_PRINT` | `#241A12` | black numerals/ticks/dots printed on the bronze ring |
| `LUME_WHITE` | `#F6F7F8` | hour-dot / bar / plot lume fill (hotspot `#FEFFFF`); replaces mint-tinted `0xEAF3EC` |
| `LUME_HAND` | `#F4F6F4` | hand lume fills (lollipop fill `#FFFFFD`) |
| `LUME_PEARL` | `#EBEAE8` | bezel pearl at 12 (warm silver, rim `#9A9C9E`) |
| `RED_SCRIPT` | `#8C2040` | "Seamaster" script — wine/raspberry, never pure red |
| `TEXT_HI` | `#E7E7E7` | Ω symbol (`#E8E8E8`) and OMEGA wordmark (`#E6E6E6`) |
| `TEXT_MID` | `#D6D6D6` | PROFESSIONAL (`#D8D8D8`), CO-AXIAL / MASTER CHRONOMETER / 300m stack (`#D5D5D5`) |
| `TEXT_DIM` | `#909092` | SWISS MADE arc |
| `ZRO2_GRAY` | `#424244` | [ZrO₂] mark — must whisper, not shout |
| `DATE_FRAME` | `#141416` | date-window bevel frame (+ 1 px inner-top specular `#2A2A2C`) |
| `DATE_APERTURE` | `#0B0B0C` | date recess interior |
| `DATE_NUMERAL` | `#C9C9CA` | date digit (white dimmed by recess) |
| `SUB_FLANGE` | `#28282A` | subdial recess flange (clearly lighter than the wave dial) |
| `SNAIL_BASE` | `#0D0D0D` | subdial snailed center base |
| `SNAIL_GROOVE` | `#242426` | snailing groove highlight rings |
| `SUB_PRINT` | `#E8EAEA` | left-subdial white scale print |

## 2. Geometry tokens

### 2.1 Radial architecture (everything keys off these)

| Token | Value | Note |
|---|---|---|
| `BEZEL_OUTER` | 1.000 | |
| `BEZEL_INNER` | 0.775 | bezel occupies the outer 22.5% of the face |
| `REHAUT_IN` / `REHAUT_OUT` | 0.755 / 0.775 | glossy black separation ring |
| `DIAL_R` | 0.755 | visible wave dial ends here (was 0.885 — wrong) |

### 2.2 Bezel furniture

| Feature | Numbers |
|---|---|
| Numerals 10/20/30/40/50 | centers at r 0.875, angles 60/120/180/240/300; **each glyph rotated by its own angle**; cap height 0.170; stroke 0.033; radial extent 0.79→0.96; digit pair subtends ≈13°; inter-digit gap 0.040 |
| Dot track | round dots Ø 0.024 at r 0.810, one per minute (every 6°), skipped at 0° and at baton/numeral angles |
| 5-min batons | at 30/90/150/210/270/330°: radial bars 0.030 wide, spanning 0.795→0.965, squared ends |
| Numeral-minute ticks | small radial rects 0.011 wide × 0.027 long, centered at r 0.810, at 60/120/180/240/300° |
| Triangle at 12 | **outline only**, stroke 0.020, fill = `BEZEL_BLACK`; base edge at r 0.955, base width 0.250 (corners at tangential ±0.125), apex pointing inward at r 0.800 |
| Pearl at 12 | circle Ø 0.071 centered at r 0.900; fill `LUME_PEARL`, rim 0.008 `#9A9C9E`, top-left `#FFFFFF` highlight arc |

There are **no per-minute tick marks on the bezel** — delete every railroad tick in both renderers.

### 2.3 Dial minute-track flange (all `FLANGE_WHITE`, uniform color — no dim minors)

| Feature | Numbers |
|---|---|
| Minute ticks (every 6°) | radial 0.705→0.755, width 0.009 |
| Half-minute ticks (every 3°, offset 3°) | radial 0.725→0.755, width 0.009 |
| Quarter-second dot arc | dots Ø 0.007 at r 0.765, every 1.5°, skipping angles that coincide with ticks (caliber-9900 4 Hz graduation) |
| Interruption | suppress ticks/dots for ≈ ±18° around 180° where SWISS MADE and the 6 o'clock plot sit |

### 2.4 Hour markers (round dots — NOT batons)

At hours 1, 2, 4, 5, 7, 8, 10, 11 (h×30°), center radius **0.590**, concentric from outside in:

| Layer | Ø / width | Color |
|---|---|---|
| shadow/step ring | Ø 0.132 | `MARKER_SHADOW` |
| polished rim | Ø 0.124 (ring 0.008 wide) | `MARKER_RIM` + `#FFFFFF` top-left arc |
| lume disc | Ø 0.104 | `LUME_WHITE` |

### 2.5 Double bar at 12

Two vertical applied bars flanking the 12 axis: each **0.076 wide**, gap **0.022** (bar centers at tangential ±0.049), radial extent **0.458→0.640**, corner radius 0.012. Same 3-layer shadow-ring/rim/lume construction as §2.4. Outer ends align with the hour-dot outer edge (~0.64).

### 2.6 Displaced positions 3 / 6 / 9 (photo-verified)

| Position | Shape | Size (tangential × radial) | Center r |
|---|---|---|---|
| 3 and 9 (outboard of subdials) | rounded lume rect, corner r 0.008 | 0.066 × 0.046 | 0.660 |
| 6 (below date, on the track) | rounded lume rect — measurably **wider** than 3/9 | 0.085 × 0.050 | 0.667 |

All with rim 0.006 `MARKER_RIM`, lume `LUME_WHITE`, shadow ring `MARKER_SHADOW`. (Conflict resolution: reports gave 0.065 vs 0.113 width for the 6 block; photo remeasurement gives 3/9 ≈ 0.066–0.068 and 6 ≈ 0.084–0.085.)

### 2.7 Subdials (centers on the horizontal axis)

| Token | Value |
|---|---|
| `SUB_OFFSET` | **0.393** (centers at (−0.393, 0) and (+0.393, 0)) — was 0.430 under the old dial mapping |
| `SUB_R` (recess outer) | **0.247** (outer edge reaches 0.640 — it *should* visually crowd the 2/4/8/10 dots; the current empty moat is a fidelity tell) |
| `SUB_SNAIL_R` (snailed black center) | 0.160 |

**Left (9 o'clock, small seconds):** flange annulus 0.160→0.247 filled `SUB_FLANGE`; numerals 10-20-30-40-50-60 every 60° in `SUB_PRINT`, cap height 0.048, center radius 0.224, **tangentially rotated** (base faces sub center — "30" upside-down); 5-second ticks radial 0.165→0.201, width 0.009; 1-second dots Ø 0.006 at r 0.187; hand: polished steel baton, length **0.157**, shaft width 0.020 with slight taper, rounded tip, hub cap r 0.036, **no tail**.

**Right (3 o'clock, 12h/60min counter):** the identity feature is the **wide rose-bronze annulus 0.160→0.242** (ring width ≈ 0.082, one third of the sub radius) filled `BRONZE_RING` — a filled band, not a stroked circle. Printed **in `RING_PRINT` black on the bronze**: numerals 12-2-4-6-8-10 (12 at top), cap height 0.046, center radius 0.201, tangentially rotated; full-ring-width hairline ticks at odd hours, thickness 0.011, radial 0.160→0.242; minute dots Ø 0.008 at r 0.174, four per 5-min sector. Center: snailed black identical to left. Hands: **two, both steel/rhodium — never bronze**: minute counter length **0.162** × width 0.016, pointed; hour counter length **0.124** × width 0.024, lance/diamond tip; shared polished hub cap r 0.029. (Subdial-internal radii above scale with `SUB_R`; keep them expressed as R-fractions in code so both renderers match literally.)

Both subdial centers are **snailed**: concentric rings alternating `SNAIL_BASE` / `SNAIL_GROOVE` at ~0.006 pitch out to `SUB_SNAIL_R`.

### 2.8 Date window at 6

| Feature | Numbers |
|---|---|
| Center | (0, +0.531) — was 0.467, too high |
| Outer frame | 0.174 wide × 0.160 tall (**portrait-leaning**, was landscape), corner radius 0.024 |
| Frame | `DATE_FRAME` glossy black bevel + 1 px inner-top specular `#2A2A2C` — **no white/silver outline, delete it** |
| Aperture | `DATE_APERTURE` |
| Numeral | height **0.120** (nearly fills the aperture), `DATE_NUMERAL`, centered, rounded semi-condensed digits |

### 2.9 Text block (all centered on the vertical axis; distances from dial center)

| Line | Center offset | Cap/x-height | Total width | Color |
|---|---|---|---|---|
| Ω symbol | 0.394 above | 0.069 tall × 0.080 wide, stroke 0.011, two horizontal feet ~0.023 each | — | `#E8E8E8` |
| OMEGA (spaced caps) | 0.313 above | 0.056 | 0.282 | `#E6E6E6` |
| *Seamaster* (red script) | 0.233 above | x-height 0.032, ascenders to 0.072 | 0.314 | `RED_SCRIPT` |
| PROFESSIONAL (spaced caps) | 0.126 above | 0.040 | 0.346 | `#D8D8D8` |
| [ZrO₂] | 0.149 below | letters 0.044, brackets 0.062 (taller than letters), subscript 2 | 0.153 | `ZRO2_GRAY` |
| CO-AXIAL | 0.247 below | 0.029 | 0.338 | `#D5D5D5` |
| MASTER CHRONOMETER | 0.290 below | 0.031 | 0.394 (widest) | `#D5D5D5` |
| 300m / 1000ft | 0.335 below | 0.033 (lowercase m/ft, spaced slash) | 0.298 | `#D5D5D5` |
| SWISS ◾ MADE | arc at r 0.715, flanking the 6 o'clock tick/plot | letter height 0.027 | — | `TEXT_DIM` |

Lower-stack line pitch is uniform at **0.043** so CO-AXIAL/MASTER CHRONOMETER/300m read as one block. Relative font-size ratios (vs OMEGA cap = 1.00): PROFESSIONAL 0.72, lower stack 0.52–0.59, SWISS MADE 0.48, date numeral 2.14.

### 2.10 Hands (skeleton rhodium + bronze chrono)

| Token | Value | Note |
|---|---|---|
| `HOUR_LEN` | **0.440** | tip is **blunt** — wide chamfered flat end, no point |
| hour frame width | 0.120 max at the lume circle, tapering to 0.046 at hub exit; frame stroke 0.008 | |
| hour lume window | **circular**, radius 0.047, centered at r 0.372, `LUME_HAND` | |
| hour skeleton slot | open window 0.119→0.302 between rails 0.014 wide; slot shows dial through | |
| `MIN_LEN` | **0.680** | needle point reaches toward the tick band |
| minute lume arrowhead | solid triangle: base at r 0.530, base width 0.105, apex at tip; border 0.007 `STEEL_HI` | |
| minute skeleton slot | 0.110→0.503; rails 0.014; shaft outer width 0.048 | |
| `SEC_LEN` (chrono) | **0.730** | fine point touching the tick band |
| chrono needle width | 0.010 (half-width 0.005) | |
| chrono lollipop | **mid-needle, not at tip**: ring centered at r 0.485, outer radius 0.0375, rim ~0.011, lume fill radius 0.0265 `#FFFFFD` | |
| `SEC_TAIL` | **0.270**, constant width, square/soft end — **no counterweight disc; delete the tail dots in both renderers** | |
| `HAND_HUB_R` | steel ring outer 0.040 (stroke 0.006, `STEEL_MID`) capped by **bronze** disc r 0.029 `BRONZE_MID` with 0.009 dark slot `#5A4436` | hub reads bronze, not steel |

Hour/minute fills: rhodium gradient — `STEEL_HI` on lit rail faces, `STEEL_LO` on flanks — around **open** skeletons (dial visible through the windows), never solid gray slabs.

### 2.11 Wave field

| Parameter | Value |
|---|---|
| Row pitch (crest-to-crest) | **0.058** → ~26 rows across the dial |
| Undulation amplitude | ±0.045 |
| Undulation wavelength | 0.560 (~1.35 slow S-curves across the dial width) |
| Phase | adjacent rows nearly in phase, drifting slowly (±0.04 over 5 rows) — organic, not cloned sines |

## 3. Render recipes

**Bezel.** Fill 0.775→1.000 with `BEZEL_BLACK`; blend the outer 0.03 toward `#1E2023`; add a low-alpha specular arc toward `#2E3033` in the upper-left quadrant. Draw rehaut 0.755→0.775 in `REHAUT` with a 1 px `REHAUT_LINE` circle at 0.775. Then dots, batons, numeral ticks per §2.2.

**Bezel numerals.** Garmin fonts cannot rotate, so define the five glyphs (Omega's rounded dive grotesque: "0" = rounded rect with rounded-rect counter; "1" = plain bar with short angled flag; "4" = closed triangular top, no foot; "3" = flat spine) as **shared stroked polygon/path data**, stroke 0.033, and rotate each glyph by its own angle (60/120/180/240/300°) about its center at r 0.875 — "30" renders upside-down at the bottom. The identical path table must feed `gen_preview.py` and `DialRenderer.mc`.

**Wave field shading.** For each row (top to bottom of every 0.058 cycle): fill the ridge face `WAVE_RIDGE`; stroke the crest highlight 0.014 wide in `WAVE_HI` (lift toward `#4A4A4A` in the upper-left gloss zone); stroke the groove 0.011 wide in `WAVE_GROOVE` **immediately below** the highlight. Base dial `CERAMIC_BASE`; add a broad gloss gradient of +8–12 luminance points over the top third. Clip to `DIAL_R` and under the subdial recesses.

**Snailing.** Inside each subdial center (r ≤ 0.160): concentric circles alternating `SNAIL_BASE` / `SNAIL_GROOVE` at ~0.006 radial pitch (a 1 px `SNAIL_GROOVE` ring every ~0.006 on `SNAIL_BASE` is sufficient at watch resolution).

**Applied markers.** Every dot/bar/plot = shadow ring, then rim (with optional `#FFFFFF` top-left highlight arc), then lume fill, per §2.4–§2.6.

**Text lines.** Each line per §2.9: letter-spaced caps sized by cap height and tracked to hit the specified total width. The *Seamaster* script is italic connected cursive with a swash tail — pre-drawn path data at `RED_SCRIPT`, never a plain italic font in pure red. [ZrO₂] renders with brackets taller than the letters and a true subscript 2, deliberately low-contrast. SWISS and MADE are set on the arc r 0.715, one word each side of the 6 o'clock plot.

**Date.** Portrait rounded rect per §2.8; the frame is *nearly invisible* — it must read as a glossy black bevel betrayed only by its inner-top specular hairline.

**Chrono hand.** One straight bronze element hub→tip (facet it `BRONZE_HI`/`BRONZE_MID`/`BRONZE_LO` along its length); annulus lollipop at 0.485; plain tail to 0.270. No disc, ever.

## 4. Render checklist — the 12 identity features a viewer checks first

1. **Massive bezel**: black band occupies the outer 22.5% of the face (inner edge 0.775), separated from the dial by a rehaut hairline.
2. **Bezel dot track, not tick railroad**: minute dots + six long batons + rotated 10–50 numerals.
3. **Outlined (not filled) triangle at 12 with a lume pearl** inside it.
4. **Round lume hour dots** (Ø 0.120 at r 0.59) — never batons — with rim + shadow ring.
5. **Broad double lume bar at 12** (0.458→0.640, bars 0.076 wide).
6. **Carved wave dial**: ~26 fine rows (pitch 0.058) with crest highlight + groove shadow, on neutral black `#0A0A0B` — no blue cast, no coarse hairlines.
7. **Red *Seamaster* script in wine `#8C2040`** plus the full text stack (Ω, OMEGA, PROFESSIONAL, [ZrO₂], CO-AXIAL / MASTER CHRONOMETER / 300m / 1000ft, SWISS MADE).
8. **Wide flat rose-bronze ring** (width ⅓ of sub radius) on the 3 o'clock counter, printed in black with rotated numerals — and **two steel hands** inside it, never a bronze one.
9. **Snailed black subdial centers**, left sub with rotated 10–60 scale; subdial outer edges reach 0.64 and crowd the hour dots.
10. **Skeleton rhodium hands**: blunt-tipped hour sword with a *circular* lume window, minute lance with a solid white lume arrowhead — open windows showing dial through.
11. **Rose-bronze central chrono needle** (`#C49B7E`, pink not brass) with its lollipop at mid-shaft (0.485) and a plain tail — no counterweight disc.
12. **Portrait glossy-black date window** at (0, +0.531) with a large white numeral and **no silver outline**, the wider 6 o'clock lume plot below it.

## 5. Parity rule

Every number in §1–§2 becomes a named token defined **once** per renderer, with identical values: `Geometry.mc`/`Theme.mc` on the device side, a mirrored constants block at the top of `gen_preview.py`. The three-way divergence catalogued in the reports (numerals present/absent, triangle filled vs disc, three different tick geometries, three different hand constructions, differing hub/tail sizes) is eliminated by construction: if a shape needs path data (bezel numerals, Seamaster script, skeleton hands), the point tables are authored once and transcribed literally into both renderers.
