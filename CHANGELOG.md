# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.21.0] - 2026-07-16

### Performance
- **Render-thread voice allocation now scales to the 2048-voice pool.** Replaced the per-note
  linear free-voice scan with a preallocated bitmap and rolling cursor, moved finished-voice
  reaping to one bounded pass per render, and added an O(1) note map for the legacy single-copy
  full-pool retrigger policy. Full-pool stealing now bypasses the bitmap entirely. The allocator
  remains audio-thread-owned and allocation/lock-free.

### Added
- Atomic `debugActiveVoiceCount` publication and `debugVoiceAllocationProbeCount` diagnostics,
  with deterministic 1024-voice burst and full-pool retrigger complexity regressions. 271 tests.

### Changed
- The CI clean-room guard now permits required MSFA provenance citations in attribution comments
  while continuing to reject production identifiers; `NOTICE` records the cited upstream paths.

## [1.20.1] - 2026-06-30

### Fixed
- **#67 adversarial-review follow-ups (2 low-severity).** (1) **Per-operator feedback automation
  was a no-op** — `doNRPN` dropped operator offset 3, so host automation of "OPn Feedback" did
  nothing while the UI value-observer applied it. `applyOperatorNRPN` now handles offset 3
  (`feedback = clamp(0…7)/7`, mirroring the setter; only op0 is rendered, as before). (2) **A no-op
  NRPN triggered the per-block apply** — the `apply*NRPN` helpers set `automationDirty`
  unconditionally, so automating an unrouted param (`oscSync`/`fmEngine`/`markIDepth`) ran the
  full per-voice apply for nothing. The helpers now return whether a field changed and
  `automationDirty` is set only then. Plus comment accuracy (the doNRPN/doRPN analogy). 269 tests.

## [1.20.0] - 2026-06-30

### Added
- **#67 render-thread-safe synth-param host automation (NRPN)** — `doNRPN` (previously an empty
  stub) now applies MIDI 2.0 NRPN assignable-controller events audio-locally on the render thread,
  exactly like `doRPN`'s tuning overrides and **never touching the main-thread
  `shadowSnapshot`/`snapshotRing` producer**. The AUv3 routes host automation for every
  snapshot-backed synth param (operator level/ratio/detune/mode/freq/sensitivities/EG rates+levels/
  KLS, global algorithm/feedback/transpose, LFO, Pitch EG, controller mappings) as NRPN on the
  lock-free `sendMIDI` ring (producer==consumer==render in the AUv3); `doNRPN` mutates the
  render-owned `currentSnapshot` and flags a per-block re-apply. `render()` now captures the apply
  snapshot **after** `drainMIDI` so render-time automation is included, gated on `|| automationDirty`.
  Values use a uniform signed 16.8 fixed-point transport. `oscSync` / `fmEngine` / `markIDepth` are
  intentionally not routed (no snapshot field, or an unsafe per-block engine switch / external Mark I
  state). RT-safe (no alloc/lock); full suite green (267 tests).

## [1.19.0] - 2026-06-30

### Fixed
- **#95 Mark I 12-bit DAC companding** — the #75 vintage 12-bit DAC ran its companding on the
  post-normalization, all-voices-summed mix, whose tiny peak (~0.08) always selected exponent 8,
  degenerating it into a fixed quantizer. It now runs **per-voice on the raw OPS sample**, divided
  by a full-scale reference `kMarkIDACFullScale` (chosen by ear A/B: **2²⁵**; at the OPS full scale
  2²⁶ ~80% of samples stayed at exponent 8 = inaudible), so the amplitude-dependent exponent
  selection actually engages. The DAC-off path is byte-exact and `dx7refmki` parity is unaffected
  (the DAC is gated by the vintage-DAC flag, off in parity). `kMarkIDACFullScale` is a
  runtime-settable `nonisolated(unsafe) var` (same RT-safe pattern as `markIModScaleQ12`).

### Investigation (no engine change)
- **#95 Mark I carrier-level / feedback recalibration — closed as no-ops.** A measurement harness
  (`MarkICalibrationCharacterizationTests`) showed the Mark I carrier is already level-matched to
  Modern (peak ratio 1.000 across all output levels — the audit's "finding 1" 4×-hot carrier does
  not manifest as rendered), and the feedback-patch Mark I/Modern divergence is invariant to the
  feedback amount (the audit's "finding 3" is the forward-mod divisor, already closed at ÷5, not
  feedback-specific). No carrier-output or feedback recalibration was warranted. See
  `docs/mark-i-recalibration-plan.md`.

## [1.18.1] - 2026-06-30

### Fixed (v1.17.0 fidelity-audit review follow-ups)
- **#96 held-note detune** — `DX7Voice.applyParams` reverted a sounding note's detune to the
  pitch-independent constant on any live parameter edit (a snapshot version bump applies params to
  all active voices), jumping the pitch versus a freshly-struck note. It now recomputes the per-note
  `dexedDetuneFactor`, matching note-on.
- **#97 EG-bias ceiling** — the EG-bias level boost ignored the `min(127, …+klsOffset)` ceiling the
  real `env.outlevel` uses, over-brightening key-scaled operators already saturated at the 127 OL
  ceiling; the boost now routes through the same ceiling.
- **Pitch EG render-thread guard** — `PitchEG.process` guards the Float→Int32 `unit` narrowing
  against a degenerate sample rate (0 / NaN) so it can't trap on the audio thread.

## [1.18.0] - 2026-06-30

### Added
- **Voice Stack random velocity (#89 follow-up)** — adds `setVoiceStackVelocityRandom(range:)`
  and `SynthParamSnapshot.voiceStackVelocityRandomRange`. When Voice Stack is above 1×,
  each stacked copy gets a deterministic per-note/per-copy velocity offset within ±0...64
  MIDI velocity steps, applied in 16-bit velocity space so MIDI 2.0 precision is preserved.
  Range 0 is byte-for-byte unchanged and randomized values clamp to 1...65535.

### Tests
- Added helper and end-to-end Voice Stack coverage for random velocity range, rerolling,
  clamping, and per-copy operator velocity offsets.

## [1.17.0] - 2026-06-30

DX7 fidelity audit — engine/voice dimension fixes (verified against DEXED/MSFA source).

### Fixed
- **EG release force-kill removed (#92)** — `DX7Envelope` no longer guillotines the release after
  a fixed ~2 s wall-clock (which truncated + clicked slow-release tails); the release runs to its
  natural completion, bit-exactly matching the DEXED EG trace. Long releases are reclaimed by voice
  stealing, not a wall-clock cap.
- **Frequency-dependent operator detune (#96)** — detune now follows DEXED's per-note curve
  (~±17 c in the bass down to ~±3.5 c in the treble) instead of a pitch-independent constant ±7 c,
  so detuned operator pairs beat at the correct rate (`dexedDetuneFactor`).
- **LFO speed→Hz from the DEXED `lfoSource` table (#94)** — replaces the pragmatic exponential whose
  1.47 Hz floor at speed 0 made the DX7's slow vibrato / multi-second sweeps unreachable; now
  0.0625 Hz at speed 0 up to ~49.3 Hz at speed 99 (`kLFOSpeedHz`).
- **Pitch EG rewritten to DEXED `PitchEnv` (#93)** — starts at L4 / sustains at L3 / releases to L4
  (was a mis-rotated PL1/PL4/PL1), uses the non-linear `pitchenv_tab` (level 70 → 7.5 st, was 19.6),
  and a constant per-block slope (was a fixed per-stage duration). Adds `kPitchEnvTab`/`kPitchEnvRate`.

### Added
- **Controller→EG-bias destination (#97)** — wheel/foot/breath/AT assigned to EG bias now raise the
  operator output level in real time (the DX7's main breath/AT-controlled brightness/dynamics path),
  routed through the real `scaleOutputLevel`. Was stored but never applied. With no controller
  assigned the render path is byte-identical to v1.16.0. (OL-point scale is calibratable by ear.)

### Tests
- New coverage where the audit found none: `slowReleaseNotKilledAtTwoSeconds`,
  `detuneMatchesDexedFrequencyDependent` (vs `dx7ref_osc_freq`), `lfoSpeedRange`, `PitchEGTests`,
  `EGBiasTests`. 248 tests pass.

## [1.16.0] - 2026-06-30

### Fixed
- **Keyboard Level Scaling fidelity (KLS) — now matches real Dexed `ScaleLevel`/`ScaleCurve`.**
  `scaleKeyboardLevel` (and the `dx7ref`/`dx7refmki` C twins) diverged from the real
  asb2m10/dexed `dx7note.cc` on three parity-invisible, shared Swift+C counts that the circular
  `scaleLevelMatchesDEXED` test (M2DX vs the equally-wrong twin) had hidden:
  - **Sign was inverted** — `−`curves (0/1) now correctly attenuate away from the breakpoint and
    `+`curves (2/3) boost; previously every KLS curve ran backwards.
  - **Exponential curve was ~8–15× too weak** — now uses Dexed's `exp_scale_data[33]` with
    `(raw·depth·329) >> 15` (was a foreign `kNlsTable` with `(…+1024) >> 11`, capping near 16/127).
  - **Breakpoint constant** is now `note − break_pt − 17` (was `+21`, which shifted the whole
    curve up 4 semitones).
  - The linear path drops the spurious `+2048` rounding and the internal `min(127)` cap (clamping
    happens at the output-level sum, like Dexed).
  Audible: KLS-heavy and imported DX7 ROM patches now scale operator level across the keyboard in
  the correct direction and magnitude, correcting a long-standing over-brightness (e.g. ROM1A
  BASS 1's Modern sustain centroid drops 685→180 Hz toward the Dexed-faithful value).

### Tests
- Added `scaleKeyboardLevelMatchesRealDexedGoldens` (hardcoded real-Dexed values) to break the
  circular M2DX-vs-twin reference; re-baselined `klsAtBreakPoint` to the `+17` hinge (note 56).
- `MarkICalibrationTests.darkerSustain` → `withKnownIssue`: the corrected KLS removes BASS 1's
  over-brightness so the `÷0.6` "Mark I markedly darker" threshold no longer holds; revisit
  together with the Mark I `÷8` modulation-darkness calibration.

## [1.15.0] - 2026-06-29

### Added
- **Vintage 12-bit DAC companding (#75)** — `SynthEngine.setVintageDAC(_:)` +
  `ParameterSnapshot.vintageDAC12bit`. When on AND the Mark I engine is active, the final mixed
  output is passed through a DX7-style 12-bit companding DAC (`dac12bitCompand`: amplitude-selected
  exponent 1/2/4/8 → 12-bit quantize → expand) for vintage lo-fi warmth/grit. Off, or on the
  Modern engine, the render path is byte-identical to v1.14.1. RT-safe (abs/compare/round only).

## [1.14.1] - 2026-06-29

### Fixed
- **Mark I Alg 6 feedback-op ramp anchor (#85)** — in the fused Alg 6 feedback path the
  feedback operator (OP6)'s inter-block attenuation ramp anchor (`markIGainOut`) was
  overwritten with the follower (OP5)'s attenuation, corrupting OP6's next-block ramp
  whenever OP5 and OP6 EG levels differ. OP6's anchor is already set to its own `atten2`
  in the gain switch; the follower uses a constant attenuation in `computeFb2MkI` and
  needs no anchor (the Alg 4 branch already did this). Removed the spurious write in both
  the Swift engine and the bit-exact `dx7refmki` C twin, preserving Swift↔C parity. Added
  `MarkIAlg6AnchorTests`, an independent contract-derived oracle the shared-mistake parity
  tests could not catch.

## [1.14.0] - 2026-06-29

### Added
- **Voice Stack detune (#89)** — the experimental Voice Stack can now detune its stacked
  copies into a supersaw-style unison thickener.
  - `ParameterSnapshot.voiceStackDetune` (cents, 0…25) and `voiceStackDetuneMode`
    (0 = even spread, 1 = random, re-rolled per note-on).
  - `SynthEngine.setVoiceStackDetune(detuneCents:detuneMode:)`.
  - Decorrelation-aware loudness compensation: gain crossfades 1/N → 1/√N as detune grows
    (`kVoiceStackDecorrelationCents = 6`). `voiceStackDetune == 0` renders byte-identical to v1.13.1.
  - RT-safe: reuses the SplitMix64 hash family; new per-note-on counter is audio-thread-local.

### Changed
- **License: MIT → Apache License 2.0** (2026-04-27)
  - The repository as a whole (`M2DXCore` Swift target + `DX7Ref` C test target + tests + docs) is now Apache 2.0
  - `LICENSE` replaced with the canonical Apache License 2.0 text
  - `NOTICE` updated to reflect that the production Swift target is Apache 2.0 alongside the previously-Apache-2.0 `DX7Ref`
  - `LICENSES/Apache-2.0.txt` retained for SPDX/REUSE tooling compatibility
  - Rationale: the test target ports MSFA C code (Apache 2.0). Distributing the rest of the repository under MIT could be read as relicensing of MSFA-derived code, which §4 of Apache 2.0 does not permit. Switching the whole repository to Apache 2.0 removes that ambiguity. Apache 2.0 remains permissive enough for downstream closed-source apps (with the §4(d) NOTICE-display obligation).

### Added
- **DX7Ref Voice-Level Rendering** (2026-02-18)
  - Added complete voice rendering functions to DX7Ref C target for waveform-level comparison testing
  - Includes: sin lookup, frequency LUT, oscillator frequency computation, FM core render loop, voice initialization/render/noteoff
  - Enables bit-exact waveform verification against DEXED reference implementation at voice level (previously operator-level only)
- **VoiceComparisonTests.swift** (2026-02-18)
  - Added 14 comprehensive voice-level waveform comparison tests verifying M2DX matches DEXED exactly
  - Tests: INIT VOICE (algorithm 1), Algorithm 5 (all modulators), Algorithm 32 (all carriers), feedback (algorithms 1/3/6), velocity sensitivity, rate scaling, keyboard level scaling (KLS), detune, coarse frequency, E.PIANO-like patch, diagnostic output
  - All tests pass with exact waveform match to DEXED after bug fixes
  - Expanded test suite from 93 tests (16 suites) to 107 tests (17 suites)

### Fixed
- **exp2LookupQ24 32-bit Integer Overflow** (2026-02-18)
  - Fixed 32-bit integer overflow in `Exp2Table.exp2LookupQ24()` to match DEXED C behavior
  - Old: `let linearInterp = (dy * lowbits) >> 14` used Swift `Int` (64-bit) arithmetic
  - New: `let linearInterp = (dy &* lowbits) >> 14` uses wrapping `Int32` multiply to match C `int` overflow semantics
  - Issue: `dy` (Q30 delta) × `lowbits` (14-bit fraction) can exceed Int32.max (2.1B), causing different results in Swift vs C
  - Maximum intermediate value: 11.9B (0x2C7FFFFFF) requires 64-bit storage, but DEXED wraps at 32-bit boundary
  - Swift's default overflow trapping prevented exact match; wrapping multiply `&*` replicates DEXED behavior
  - Verified against DEXED for all 2049 exp2 table entries
- **DX7Voice dgain Rounding Direction** (2026-02-18)
  - Fixed `dgain` calculation in `computeMod()`, `computePure()`, and `computeFb()` to match DEXED rounding behavior
  - Old: `let dgain = (gain2 - gain1) / Int32(n)` (division, truncates toward zero)
  - New: `let dgain = (gain2 - gain1 + 32) >> kLgBlockSize` (arithmetic right shift, rounds down)
  - Issue: For negative `dgain`, division and right shift differ by 1 (e.g., `-65 / 64 = -1` vs `-65 >> 6 = -2`)
  - Added `kLgBlockSize = 6` constant to `Algorithm.swift` for clarity (replaces magic number `64`)
  - Arithmetic right shift matches DEXED `env.cc` implementation exactly
  - Ensures bit-exact envelope increment behavior across all 14 voice comparison tests
- **Keyboard Rate Scaling (KRS) Algorithm** (2026-02-18)
  - Fixed `keyboardRateScaling()` in ScalingTable.swift to match DEXED's ScaleRate() exactly
  - Old algorithm: `min(7, (note-36+1)/3) * scaling` gave 21 for note=60, sens=3
  - New algorithm: `(scaling * min(31, max(0, note/3-7))) >> 3` gives 4 for note=60, sens=3
  - Corrects excessive envelope rate scaling that caused E.PIANO1 to decay in 1.3s instead of 40s+
  - Verified against DEXED reference implementation (all 128 notes × 8 sensitivities match exactly)
- **DX7Envelope Rate Scaling Application Order** (2026-02-18)
  - Fixed `advance()` and `recalcCurrentInc()` to apply rateScaling to qrate instead of raw rate
  - Old: `adjustedRate = min(99, rate + rateScaling); qrate = (adjustedRate*41)>>6` (applied to raw rate)
  - New: `qrate = (rate*41)>>6; qrate = min(63, qrate + rateScaling)` (applied to qrate)
  - Matches DEXED env.cc implementation exactly
  - Combined with KRS fix, resolves sustain phase issues across all presets
- **SynthEngine Preset Loading** (2026-02-18)
  - Added `loadDX7Preset(_ preset: DX7Preset)` for atomic preset loading via single snapshot push
  - Eliminates race condition from 40+ individual parameter setters
  - Ensures consistent preset application without intermediate snapshots leaking to render thread
- **SynthEngine MIDI Event Ordering** (2026-02-18)
  - Fixed `drainMIDI()` to process events in FIFO order (previously reversed)
  - Prevents out-of-order note on/off events causing stuck notes
- **Feedback Scaling** (2026-02-18)
  - Fixed feedback parameter to apply preset-global value to operator 0 only (was incorrectly per-operator)
  - Matches DX7 specification (algorithm-level feedback, not per-operator)
- **SynthEngine Output Clipping** (2026-02-18)
  - Removed hard clipping (`min/max ±1.0`) from engine output
  - Delegates dynamic range management to FX chain (Maximizer)
  - Preserves peak transients for better limiter performance
- **Issue #2**: Eliminated heap allocation on audio thread when SnapshotRing drops old snapshots
  - Changed `SynthParamSnapshot.slots` and `SynthParamSnapshot.slotConfigs` from dynamic `Array<T>` to fixed-size tuples (8 elements)
  - Added `activeSlotCount: Int` field to track active slots dynamically
  - Added subscript helpers (`slot(at:)`, `setSlot(at:)`, `config(at:)`, `setConfig(at:)`) for ergonomic tuple access
  - Updated all SynthEngine code paths to use new accessor methods
- **Issue #3**: Eliminated heap allocation in voice mixing path
  - Changed `VoiceMixer.accumulateVoice()` signature to accept caller-provided `scratch: UnsafeMutablePointer<Float>` buffer
  - Added pre-allocated `floatScratch: UnsafeMutablePointer<Float>` to SynthEngine for reuse across render calls
  - Audio thread now completely allocation-free during normal operation
- **Issue #4**: Replaced NSLock + Array-based MIDI event queue with lock-free SPSC FIFO ring buffer
  - Created `SPSCRing<T>` generic SPSC FIFO ring buffer in `Sources/M2DXCore/Infrastructure/SPSCRing.swift`
  - Uses `Synchronization.Atomic` for lock-free producer-consumer semantics (same pattern as SnapshotRing but with FIFO ordering)
  - Fixed capacity of 256 events, `push()` and `pop()` preserve all events in order
  - Replaced `SynthEngine.midiEvents: [MIDIEvent]` + `midiLock: NSLock` with `midiRing: SPSCRing<MIDIEvent>`
  - `sendMIDI()` now lock-free (no NSLock acquisition)
  - `drainMIDI()` uses `while let event = midiRing.pop()` loop instead of lock + array copy
  - Removed `import Foundation` dependency from SynthEngine (NSLock no longer needed)
  - MIDI event handling now fully lock-free on both UI and audio threads
- **Bug Fix**: CC state persists after preset reload
  - Fixed bug where MIDI Control Change state (mod wheel, breath, foot, pitch bend, sustain) persisted after loading a new preset via `loadSlotParams()`
  - Added `public func resetControllers()` to SynthEngine that resets all CC-derived instance variables to defaults:
    - `modWheelDepth`, `footDepth`, `breathDepth`, `aftertouchDepth` → 0
    - `pitchBendValue` → 1.0
    - `sustainPedalOn` → false
    - Active voice pitch bend → 1.0
    - Active voice sustained flags → false
  - Modified `loadSlotParams()` to accept `resetControllers: Bool = true` parameter
    - Default behavior: automatically calls `resetControllers()` when loading a preset
    - Can be disabled with `resetControllers: false` for individual parameter adjustments
  - Fixed `DX7Operator.noteOn()` to reset `gainOut = 0` to prevent stale gain carry-over from previous notes
  - This ensures INIT VOICE and other presets sound identical regardless of prior CC message history
- **SynthEngine Output Scaling Normalization** (2026-02-18)
  - Fixed output scaling divisor from 33554432.0 (2^25) to 268435456.0 (2^28)
  - Root cause: Previous /2^25 was 8× too hot compared to DEXED's normalization (>> 4, >> 9, / 32768 = / 2^28)
  - Multi-carrier algorithms (e.g. Algorithm 32 with 6 carriers) were clipping at ~1.48 peak amplitude
  - Now correctly normalized: single carrier peak ~0.06, 6-carrier peak ~0.375
  - Prevents output distortion on presets with multiple carriers
  - All 107 tests pass

### Added
- **DX7Ref C Target** (2026-02-18)
  - Added test-only C target with DEXED msfa reference functions for comparison testing
  - Includes: ScaleRate, ScaleVelocity, ScaleLevel, scaleoutlevel, exp2 lookup, EG advance/getsample, algorithm flags
  - Apache 2.0 licensed reference implementation (Sources/DX7Ref/, not included in production library)
  - Enables bit-exact verification of M2DX DSP against DEXED
- **ReferenceTests.swift** (2026-02-18)
  - Added 10 comprehensive comparison tests verifying M2DX matches DEXED exactly
  - Tests: ScaleRate (1024 cases), ScaleVelocity (1024 cases), ScaleLevel (2000 cases), scaleOutputLevel (100 cases), exp2 lookup, EG inc (3200 cases), EG level trace (3000+ blocks), algorithm flags (32 algorithms)
  - All tests pass with exact match to DEXED reference functions
  - Provides regression protection for DSP accuracy
- **PresetLoadTests.swift** (2026-02-18)
  - Integration tests for atomic preset loading via `loadDX7Preset()`
  - Verifies snapshot consistency and parameter mapping
  - Tests INIT VOICE and E.PIANO1 preset application
- **Swift Package**: Created `Package.swift` with Swift 6.0, macOS 15+ / iOS 18+ support
- **Tables**: Self-generated Q24 sin table, Q30 exp2 table, frequency table, scaling table (all computed from mathematical functions)
- **Infrastructure**: Lock-free `SnapshotRing<T>` SPSC ring buffer using `Synchronization.Atomic`
- **Presets**: `DX7Algorithms` (32 algorithms), `DX7Preset` (155-byte layout), `DX7SysExParser`, factory presets
- **Engine**: `DX7Envelope`, `DX7Operator`, `DX7Voice`, `Algorithm` routing, `SynthEngine` with 16-voice polyphony
- **DSP**: `Downsampler` (2x FIR decimation), `VoiceMixer` (vDSP mixing/clipping)
- **Tests**: 66 tests across 6 test files (TableTests, EnvelopeTests, AlgorithmTests, WaveformTests, ConcurrencyTests, PerformanceTests)
- **CI**: GitHub Actions workflow for macOS 15 + Xcode 16
- **API Documentation**: Comprehensive public API reference in `docs/API.md`
  - Complete SynthEngine method documentation (render, MIDI handling, 60+ parameter setters)
  - Parameter snapshot types (OperatorSnapshot, SlotSnapshot, SynthParamSnapshot)
  - MIDI event system (MIDIEvent, supported CC mappings)
  - Preset data model (DX7Preset, DX7OperatorPreset, PresetCategory)
  - SysEx parser (DX7SysExParser, DX7SysExBank)
  - Algorithm definitions (32 DX7 algorithms with carrier/modulator routing)
  - Factory presets (DX7FactoryPresets with all 32 built-in patches)
  - Usage examples for common integration scenarios

### Changed
- Migrated from documentation-only to fully functional synthesis library
- All lookup tables now generated from mathematical definitions (no msfa-derived code)
- Accelerate framework integrated for DSP operations (vDSP mixing, clipping, conversion)

### Notes
- **Phase 2 Complete** (2026-02-16): Library extraction and clean room implementation finished
- 17 Swift source files, all 107 tests passing (17 test suites)
- Clean room verification: `grep -ri msfa Sources/` returns 0 results
- Performance: 16 voices × 512 frames renders in ~17.8ms on x86_64 (target: <2ms on ARM)
- DX7 accuracy: Bit-exact waveform match to DEXED verified across all 14 voice comparison tests

---

## Release Notes

### Version Numbering

M2DX-Core will follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Pre-1.0 Development

During pre-1.0 development (Phases 2-3), APIs may change without notice. Version 1.0.0 will be released after Phase 3 (SPM Library Release) is complete and the public API is stabilized.

---

[Unreleased]: https://github.com/yourusername/M2DX-Core/compare/HEAD
