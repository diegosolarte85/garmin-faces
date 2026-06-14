# Tasks — 007 First Light Watch Face

Ordered, independently reviewable increments. Each leaves the project compiling.
Mapped to [`requirements.md`](requirements.md) (R*) and [`design.md`](design.md).

## Phase 0 — Project scaffold
- [x] T0.1 `manifest.xml` — watchface app, `fenix8pro47mm`, API 5.1, permissions. (R6.3)
- [x] T0.2 `monkey.jungle` build config.
- [x] T0.3 `resources/strings/strings.xml`, `drawables/drawables.xml`. (R5)
- [x] T0.4 `tools/gen_icons.py` + generated launcher icons.
- [x] T0.5 `.gitignore` for SDK build artifacts.

## Phase 1 — Foundations
- [x] T1.1 `Geometry.mc` — center/radius cache, polar helpers, radii tokens. (R6.1)
- [x] T1.2 `Theme.mc` — color tokens (active + dim), settings load, accent/theme resolve. (R5)
- [x] T1.3 `BondSeamasterApp.mc` — app entry + `onSettingsChanged`. (R5.2)
- [x] T1.4 `BondSeamasterView.mc` — lifecycle skeleton + power state machine. (R4)

## Phase 2 — Static dial art (off-screen buffer)
- [x] T2.1 `DialRenderer` buffer create + fallback path. (R4.3, NFR-3)
- [x] T2.2 Bezel ring + white-enamel diving scale + lume 12 pip. (R1, source)
- [x] T2.3 Horizontal wave guilloché field (layered shaded bands). (R1.4)
- [x] T2.4 Chapter ring + minute/seconds ticks. (R1.3)
- [x] T2.5 Applied hour markers (rhodium body + lume inlay, double bar @12). (R1.3, R3.1)
- [x] T2.6 Subdial rings (bronze @3, rhodium @9) + ticks; date aperture @6. (R2.1, R2.2)
- [x] T2.7 Dial text: Ω, SEAMASTER (red), DIVER 300M, CHRONOMETER, CHRONOGRAPH. (source)

## Phase 3 — Hands
- [x] T3.1 Broad-arrow hour & minute hands (rhodium body + lume inlay). (R1.1, R3.1)
- [x] T3.2 Central hub cap. (R1.1)
- [x] T3.3 Bronze lollipop seconds + counterweight (active only). (R1.2)

## Phase 4 — Complications
- [x] T4.1 6 o'clock date value. (R2.2, R6.2)
- [x] T4.2 9 o'clock subdial: 24h / HR / Body Battery / Off, null-safe. (R2.3, R2.5)
- [x] T4.3 3 o'clock subdial: Battery / Steps / Active min / Off swept gauge. (R2.4, R2.5)

## Phase 5 — Effects & power
- [x] T5.1 `FxDawnSweep` wrist-raise first-light flourish. (R3.2, R3.3)
- [x] T5.2 Lume bloom on hands/markers (active wake). (R3.1)
- [x] T5.3 Low-power dim palette + seconds suppression + partial-update clip. (R4.1, R4.2, R4.4)

## Phase 6 — Settings & polish
- [x] T6.1 `settings.xml` + `properties.xml` wired to `Theme`. (R5.1)
- [x] T6.2 Static-art invalidation on theme/accent change. (R5.2)
- [x] T6.3 12h/24h + locale date verification path. (R6.2)

## Phase 7 — Verification
- [x] T7.0 CI: SDK-free asset + XML validation (`.github/workflows/ci.yml`).
- [x] T7.1 Compile for `fenix8pro47mm` — green in CI `build` job (monkeyc 9.2.0,
  matco Connect IQ image); `.prg` artifact produced.
- [ ] T7.2 Simulator: active vs always-on visual check; burn-in audit.
- [ ] T7.3 Settings round-trip in simulator.

> T7.2–T7.3 require the interactive Connect IQ simulator and remain the human
> verification gate before store submission. T7.1 is covered by CI.

## Phase 8 — Connect IQ Store publishing
- [x] T8.1 CI `package` job builds the signed `.iq` export (key from secret or throwaway).
- [x] T8.2 `release.yml`: tag `vX.Y.Z` → build `.iq` → attach to GitHub Release.
- [x] T8.3 Store listing copy (`store/listing.md`) + permissions note (`store/PERMISSIONS.md`).
- [x] T8.4 Full-resolution marketing mockups (`tools/gen_preview.py` → `store/screenshots/`).
- [x] T8.5 End-to-end submission guide (`PUBLISHING.md`).
- [ ] T8.6 Provide a persistent developer key + set `CIQ_DEVELOPER_KEY_B64` secret. *(owner)*
- [ ] T8.7 Capture real simulator screenshots at 454×454. *(owner, needs SDK)*
- [ ] T8.8 Upload `.iq` + listing in the developer dashboard and submit for review. *(owner)*

> T8.6–T8.8 require your Garmin developer account, signing key, and the
> interactive simulator/dashboard — they cannot be automated from CI.
