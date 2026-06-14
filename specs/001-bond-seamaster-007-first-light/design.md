# Design — 007 First Light Watch Face

Implements [`requirements.md`](requirements.md). Governed by
[`../../docs/CONSTITUTION.md`](../../docs/CONSTITUTION.md).

## 1. Architecture

```
Application.AppBase  ── BondSeamasterApp
        │  getInitialView() → [BondSeamasterView]
        ▼
WatchUi.WatchFace    ── BondSeamasterView
        │  owns the render lifecycle + state machine
        ├── Theme            color tokens + resolved settings
        ├── DialRenderer     static art → off-screen BufferedBitmap
        ├── Hands            hour / minute / second hand geometry + draw
        ├── Subdials         9 o'clock, 3 o'clock, 6 o'clock complications
        └── FxDawnSweep      "first light" wrist-raise flourish
```

### Render lifecycle (state machine)

| Hook | Action |
| --- | --- |
| `onLayout(dc)` | Cache W/H/center/radius; build `Geometry`; render static art into buffer. |
| `onShow()` | Reload settings into `Theme`; rebuild static art if invalidated. |
| `onExitSleep()` | Enter **active**; if dawn-sweep enabled, arm `FxDawnSweep`. |
| `onEnterSleep()` | Enter **low-power**; cancel effects; force one clean redraw. |
| `onUpdate(dc)` | Blit static buffer → draw subdials → draw hands → (active) draw seconds. |
| `onPartialUpdate(dc)` | Active only: redraw the seconds hand within a clip rectangle. |

`onUpdate` is the per-minute (low-power) / per-second (active) full paint.
`onPartialUpdate` is the once-per-second seconds tick used to keep the bronze
hand alive with minimal cost. There is no sub-second timer available to watch
faces; the bronze hand therefore ticks at 1 Hz (documented, not a bug).

## 2. Coordinate system & geometry tokens

Origin at display center. `R = W/2`. Reference W = H = 454, R = 227, C = (227, 227).
All radii are fractions of `R` so the face scales to any round display.

Clock angle: for a value at clock-position `p` (0..12), the screen angle measured
**clockwise from 12 o'clock (up)** is `θ = p · 30°`. Convert to math coords:

```
x = cx + r · sin(θ)
y = cy − r · cos(θ)
```

| Token | Value (× R) | Meaning |
| --- | --- | --- |
| `BEZEL_OUTER` | 1.000 | outer edge |
| `BEZEL_INNER` | 0.905 | inner edge of bezel ring (diving scale band) |
| `DIAL_R` | 0.885 | dial face radius (wave field) |
| `CHAPTER_R` | 0.840 | minutes/seconds chapter-ring radius |
| `MARKER_OUTER` | 0.820 | outer end of applied hour markers |
| `MARKER_INNER` | 0.720 | inner end of applied hour markers |
| `SUB_OFFSET` | 0.430 | distance of 3 & 9 subdial centers from center (on x-axis) |
| `SUB_R` | 0.150 | subdial radius |
| `DATE_OFFSET` | 0.470 | distance of date window center from center (down y-axis) |
| `LOGO_R` | 0.430 | radius of upper logo block (Ω / SEAMASTER) below 12 |
| `HOUR_LEN` | 0.520 | hour hand length |
| `MIN_LEN` | 0.760 | minute hand length |
| `SEC_LEN` | 0.820 | second hand length (tip) |
| `SEC_TAIL` | 0.180 | second hand counterweight length |
| `SEC_LOLLIPOP_R` | 0.030 | lume dot radius near second-hand tip |
| `HAND_HUB_R` | 0.052 | central hub cap radius |

Subdial centers: 9 o'clock = `(cx − SUB_OFFSET·R, cy)`, 3 o'clock =
`(cx + SUB_OFFSET·R, cy)`, date = `(cx, cy + DATE_OFFSET·R)`. The 3 and 9 dials
sit on the horizontal axis; the lower half between them carries the date and the
"DIVER 300M / CHRONOMETER" lines, matching the real dial.

### Hand shapes
- **Hour/minute:** broad-arrow (Omega "Seamaster" style) — a tapered sword with a
  skeleton window holding a lume inlay. Built as polygons: outer rhodium body,
  inner lume polygon. Minute is a longer, narrower version of the hour shape.
- **Second:** thin bronze-gold needle, a lume **lollipop** disc near the tip and a
  circular counterweight on the tail.

## 3. Color tokens (`Theme`)

24-bit AMOLED. Active values; low-power uses the `*_DIM` column.

| Token | Active | Dim (AOD) | Use |
| --- | --- | --- | --- |
| `CERAMIC_BASE` | `0x05070A` | `0x000000` | dial base |
| `WAVE_LO` | `0x0A0E13` | `0x040506` | wave trough shade |
| `WAVE_HI` | `0x1B232C` | `0x0B0E11` | wave crest highlight |
| `BEZEL` | `0x0A0C10` | `0x000000` | bezel ring |
| `ENAMEL` | `0xF2F4F5` | `0x9AA0A6` | white diving scale |
| `RHODIUM_HI` | `0xDCE2E8` | `0x7E848A` | hand/marker highlight |
| `RHODIUM` | `0xAAB0B6` | `0x595E63` | hand/marker body |
| `RHODIUM_LO` | `0x6E747A` | `0x34383C` | hand/marker shadow edge |
| `BRONZE_HI` | `0xE9CD94` | `0x6E5E3C` | bronze highlight |
| `BRONZE` | `0xC79A5B` | `0x5C4A2C` | bronze body (seconds, 3 o'c ring) |
| `BRONZE_LO` | `0x8A6A36` | `0x3C2F1C` | bronze shadow |
| `LUME` | `0xEAF3EC` | `0x39524A` | lume at rest |
| `LUME_GLOW` | `0x8FE9C0` | `0x2E5F4C` | lume bloom (active wake) |
| `POPPY_RED` | `0xE4261B` | `0x6E1712` | *Seamaster* script |
| `TEXT_DIM` | `0xC9CDD2` | `0x70757A` | secondary dial text |
| `DAWN_WARM` | `0xFF8A3D` | — | dawn-sweep core |
| `DAWN_COOL` | `0xFFD27A` | — | dawn-sweep edge |

Themes:
- **Black Ceramic** (default): tokens as above.
- **Dawn First-Light:** dial base warmed to `0x0B0805`, wave highlight gets a faint
  amber bias; everything else identical (keeps the bronze/red coherent).

Accent setting swaps the **central seconds hand + active marker tips** between
`BRONZE*` (default) and `POPPY_RED`.

## 4. Render pipeline (performance)

1. **Static layer** (built once in `DialRenderer.build()` → BufferedBitmap):
   bezel + diving scale, wave field, chapter ring + minute ticks, applied hour
   markers (rhodium body + lume inlay, **dimmed lume baked in**), subdial rings &
   ticks, all dial text (Ω, SEAMASTER, DIVER 300M, CHRONOMETER, CHRONOGRAPH).
2. **Dynamic layer** (every `onUpdate`): blit static buffer; draw subdial hands /
   values; draw hour & minute hands; draw central hub.
3. **Seconds layer** (active; `onUpdate` + `onPartialUpdate`): draw bronze seconds
   needle + lollipop + counterweight. `onPartialUpdate` clips to the union of the
   previous and current needle bounding boxes to minimise repaint.
4. **Dawn FX** (active, transient): on `onExitSleep`, overlay a warm radial/linear
   sweep with decreasing alpha across ~6 frames driven by `onPartialUpdate`,
   then settle. Implemented as additive light bands; never in low-power.

If `Graphics.createBufferedBitmap` is unavailable, `DialRenderer` falls back to
drawing the static layer directly each `onUpdate` (correctness over speed).

## 5. Settings & properties

`resources/settings/properties.xml` defines defaults; `settings.xml` exposes UI.
`Theme.load()` reads via `Application.Properties.getValue`, null-coalescing to
defaults. Keys:

| Key | Type | Default | Domain |
| --- | --- | --- | --- |
| `DialTheme` | number | 0 | 0 Black Ceramic, 1 Dawn |
| `AccentColor` | number | 0 | 0 Bronze, 1 Red |
| `LeftSubdial` | number | 0 | 0 24h, 1 HR, 2 Body Battery, 3 Off |
| `RightSubdial` | number | 0 | 0 Battery, 1 Steps, 2 Active min, 3 Off |
| `SecondsMode` | number | 0 | 0 sweep+hide AOD, 1 always hidden |
| `DawnSweep` | boolean | true | wrist-raise flourish |

A settings change sets `Theme.dirty`; `onShow`/next `onUpdate` rebuilds the static
buffer when the dial-affecting tokens changed.

## 6. Permissions

Watch faces run with minimal scope. Battery (`System.getSystemStats`), steps and
active minutes (`ActivityMonitor`) need no permission. Heart rate / Body Battery
read through `Toybox.SensorHistory`, which requires the **`SensorHistory`**
permission — the compiler enforces this even behind a runtime `has` guard, so it
is declared in `manifest.xml`. All reads are guarded so the face shows empty
subdials when a value is null. No network, no positioning.

## 7. Intentional deviations from the source object

- The real central chrono hand rests at 12 unless the chronograph runs; here it is
  the **live seconds** hand (a watch-face needs a running seconds indication).
- The 9 o'clock running-seconds subdial is **repurposed** as a glanceable
  complication (default 24-hour hand) so both subdials carry data.
- The 3 o'clock 12h/60min counter becomes a **swept data gauge** (default battery).
- 1 Hz seconds cadence (platform limit for watch faces), not a continuous sweep.

## 8. File map

| File | Responsibility |
| --- | --- |
| `source/BondSeamasterApp.mc` | App entry, view wiring, settings-change hook. |
| `source/BondSeamasterView.mc` | WatchFace lifecycle + state machine + compositing. |
| `source/Theme.mc` | Color tokens, settings load, active/dim resolution. |
| `source/Geometry.mc` | Center/radius cache + polar helpers + token radii. |
| `source/DialRenderer.mc` | Static art into off-screen buffer (bezel, waves, markers, text). |
| `source/Hands.mc` | Broad-arrow hour/minute + bronze lollipop seconds. |
| `source/Subdials.mc` | 9/3 o'clock complications + 6 o'clock date. |
| `source/FxDawnSweep.mc` | First-light wrist-raise animation. |
| `tools/gen_icons.py` | Pure-python launcher-icon renderer. |
