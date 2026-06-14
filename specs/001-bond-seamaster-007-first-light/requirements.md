# Requirements — 007 First Light Watch Face

- **Feature ID:** 001
- **Status:** Approved
- **Target device:** Garmin Fenix 8 Pro 47mm (454×454 round AMOLED, touch, always-on capable)
- **Min SDK / API level:** Connect IQ 7.x / API 5.1.0
- **Type:** `watchface`

## 1. Overview

Deliver a Connect IQ analog watch face that is a high-fidelity tribute to the
**Omega Seamaster Diver 300M Chronograph "007 First Light"**, with smooth live
animation in active use and burn-in-safe behaviour in always-on mode.

## 2. Source-object reference (ground truth)

The visual target, confirmed from Omega's release and watch press:

| Aspect | Detail |
| --- | --- |
| Dial | Black ceramic, laser-engraved **horizontal wave** pattern |
| Layout | Bicompax (caliber 9900): **9 o'clock** small running seconds, **3 o'clock** combined 12h/60min counter with **PVD bronze-gold** ring, **6 o'clock** date window |
| Center | Central chronograph **lollipop** seconds hand in **PVD bronze-gold** |
| Hands | Rhodium-plated broad-arrow hour/minute, white **Super-LumiNova** inlays |
| Markers | Applied rhodium indices, white lume |
| Bezel | Polished **black ceramic**, white-enamel diving scale, luminous 12 pip |
| Accents | Poppy-**red** *Seamaster* script; bronze-gold subdial ring + central seconds |
| Text | Ω at 12; "SEAMASTER" (red) / "DIVER 300M" / "CHRONOMETER" / "CHRONOGRAPH" |

## 3. User stories & acceptance criteria (EARS)

### US-1 — Tell the time, beautifully
*As a wearer, I want an accurate analog time display that looks like the real watch.*

- **R1.1** The system SHALL display hours and minutes with rhodium broad-arrow
  hands positioned for the current local time, minute hand advancing smoothly per minute.
- **R1.2** WHEN in high-power (active) mode, the system SHALL display a bronze-gold
  central seconds hand updated at least once per second.
- **R1.3** The system SHALL render 12 applied hour markers (double bar at 12) and a
  minute/seconds track true to the dial.
- **R1.4** The system SHALL render the dial with a layered horizontal wave texture on
  a near-black ceramic base.

### US-2 — Subdials & complications
*As a wearer, I want the bicompax subdials to carry useful, glanceable data.*

- **R2.1** The system SHALL render a subdial at 9 o'clock and a bronze-ringed subdial
  at 3 o'clock, geometrically matching the source layout.
- **R2.2** The system SHALL render a date window at 6 o'clock showing the current day
  of month.
- **R2.3** The 9 o'clock subdial SHALL show a user-selected datum (default: 24-hour
  hand) from {24-hour, Heart rate, Body Battery, Off}.
- **R2.4** The 3 o'clock subdial SHALL show a user-selected datum (default: Battery)
  from {Battery, Steps, Active minutes, Off}, rendered as a swept gauge hand.
- **R2.5** IF a complication's data source is unavailable or null, THEN the system
  SHALL render the subdial's empty/neutral state without error.

### US-3 — Lume & "First Light" signature
*As a wearer, I want the watch to feel alive, evoking dawn / "First Light".*

- **R3.1** Hour/minute hands and hour markers SHALL carry a luminous fill with a soft
  bloom suggesting Super-LumiNova.
- **R3.2** WHEN the wearer raises the wrist (exit sleep) AND the dawn-sweep setting is
  on, the system SHALL play a brief warm "first light" sweep across the dial.
- **R3.3** The dawn-sweep SHALL complete within ~1 second and SHALL NOT run in
  low-power mode.

### US-4 — Power & always-on discipline
*As a wearer, I want long battery life and no burn-in.*

- **R4.1** WHEN entering low-power/always-on mode, the system SHALL stop the seconds
  animation and any active-only effects.
- **R4.2** WHEN in always-on mode, the system SHALL dim the palette and avoid large
  static bright fills to mitigate AMOLED burn-in.
- **R4.3** The system SHALL pre-render static dial art once and reuse it, bounding
  per-frame work to hands and live complications.
- **R4.4** The seconds hand visibility in always-on SHALL follow the user setting
  (default: hidden in always-on).

### US-5 — Configuration
*As a wearer, I want to personalise the face from Garmin Connect.*

- **R5.1** The system SHALL expose settings: dial theme, accent color, 9 o'clock data,
  3 o'clock data, seconds-hand behaviour, dawn-sweep on/off.
- **R5.2** WHEN a setting changes, the system SHALL apply it on the next update,
  re-rendering static art if the change affects it.

### US-6 — Robustness & portability
- **R6.1** All geometry SHALL be derived from runtime display dimensions (no
  hard-coded pixels), per Constitution Article III.
- **R6.2** The face SHALL render correctly with the system clock in both 12h and 24h
  modes and adapt the date format to the device locale.
- **R6.3** The face SHALL request only the permissions it uses.

## 4. Non-functional requirements

- **NFR-1 Performance:** Per-frame (active) update budget ≤ ~30 ms on-device; static
  art rendered at most on layout/settings-change.
- **NFR-2 Memory:** Stay within watch-face memory budget; one full-screen off-screen
  buffer maximum.
- **NFR-3 Compatibility:** Compile cleanly for `fenix8pro47mm`; degrade gracefully if
  `createBufferedBitmap` or a sensor is unavailable.

## 5. Out of scope
- Functioning chronograph/stopwatch (the counters are styled complications, not a
  running chrono).
- Watch face "Cloud"/companion data, music, or maps.
