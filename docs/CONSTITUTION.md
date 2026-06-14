# Project Constitution — Spec-Driven Development

These are the non-negotiable principles that govern how this watch face is built.
Every change flows **spec → design → tasks → code → verify**. The artifact a
reviewer trusts is the spec; the code is its faithful implementation.

## Articles

### I. Spec before code
No feature is implemented before it exists as an acceptance criterion in
`requirements.md` and is reflected in `design.md`. If code needs something the
spec doesn't cover, the spec is updated first (in the same change).

### II. Fidelity to the source object
This is a tribute rendering of a real watch. Geometry, layout, and color are
anchored to the **Omega Seamaster Diver 300M Chronograph "007 First Light"**:
bicompax caliber-9900 layout (running indicator at 9, counter at 3, date at 6),
black ceramic wave dial, rhodium broad-arrow lume hands, PVD bronze-gold central
seconds and 3 o'clock ring, poppy-red *Seamaster* script. Deviations must be
deliberate and documented in `design.md` under "Intentional deviations".

### III. Resolution independence
All geometry is derived from `dc.getWidth()`/`getHeight()`. The reference target
is 454×454 (Fenix 8 Pro 47mm) but nothing hard-codes pixel coordinates; the face
must render correctly on any round display.

### IV. Power discipline (AMOLED)
- High-power (active): live seconds and full art.
- Low-power / always-on: no animation, dimmed palette, minimal lit pixels,
  burn-in-safe (no large static bright fills, sub-second updates disabled).
- Static art is rendered **once** into an off-screen buffer and blitted; per-frame
  work is bounded to hands + dynamic complications.

### V. Graceful degradation
Every sensor/complication read is null-checked and falls back to a sensible empty
state. The face must never crash on missing data, missing permissions, or an
unsupported API level.

### VI. Verifiable increments
Each task in `tasks.md` is independently reviewable and leaves the project in a
compiling state. Commits map to tasks.

## Definition of Done
A change is done when: the spec is updated, the code compiles for
`fenix8pro47mm`, it renders in both high- and low-power states, settings round-trip
correctly, and `tasks.md` checkboxes reflect reality.
