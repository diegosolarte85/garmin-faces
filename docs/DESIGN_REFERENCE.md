# Design Reference — Omega Seamaster Diver 300M Chronograph "007 First Light"

The visual ground truth for this watch face, compiled from Omega's release and
watch-press coverage. Used to author geometry/color in
[`specs/001-bond-seamaster-007-first-light/design.md`](../specs/001-bond-seamaster-007-first-light/design.md).

## The watch
A 44mm stainless-steel chronograph tied to the *007 First Light* video game —
Omega's first watch born from a game. Caliber 9900 Co-Axial Master Chronometer.

## Dial & layout
- **Dial:** black ceramic with the Seamaster **laser-engraved horizontal wave** pattern.
- **Layout (bicompax, caliber 9900):**
  - **9 o'clock** — small running seconds.
  - **3 o'clock** — combined 12-hour / 60-minute counter, ring finished in **PVD bronze-gold**.
  - **6 o'clock** — date window.
  - **Center** — chronograph **lollipop** seconds hand in PVD bronze-gold.
- **Hands:** rhodium-plated broad-arrow, white **Super-LumiNova** inlays.
- **Markers:** applied rhodium indices, white lume.
- **Bezel:** polished **black ceramic**, white-enamel diving scale, luminous 12 pip.
- **Accents:** poppy-**red** *Seamaster* script; bronze-gold subdial ring + central seconds.

## How the watch face maps it
The face is an analog **watch face**, not a working chronograph, so a few
deliberate choices were made (full list in `design.md` §7):

| Source element | Watch-face role |
| --- | --- |
| Central bronze chrono hand | Live **seconds** hand (active mode) |
| 9 o'clock running seconds | Glanceable complication (default 24-hour hand) |
| 3 o'clock 12h/60min counter | Swept data gauge (default battery) |
| Date at 6 | Live date |

## Sources
- [Time and Tide — introducing the 007 First Light](https://timeandtidewatches.com/omega-seamaster-diver-300m-chronograph-007-first-light-introducing/)
- [Watchonista — Omega brings 007 First Light to life](https://www.watchonista.com/articles/novelties/omega-brings-007-first-light-seamaster-diver-300m-chronograph-life)
- [Monochrome — first look](https://monochrome-watches.com/omega-seamaster-diver-300m-chronograph-007-first-light-from-video-game-to-reality-review-price/)
- Reference imagery supplied in the project brief (Time+Tide concept render; GQ Seamaster Diver 300M Chronograph 007).
