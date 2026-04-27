# TODO

This document tracks the development roadmap for M2DX-Core, organized by project phase.

## Phase 2: Library Extraction & Clean Room ✅ **COMPLETED**

All 8 steps of Phase 2 have been completed as of 2026-02-16.

### Step 1: Package.swift & Directory Structure ✅

- [x] Create Swift Package with `swift-tools-version: 6.0`
- [x] Set platform requirements (macOS 15+ / iOS 18+)
- [x] Link Accelerate framework
- [x] Configure test target

### Step 2: Table Self-Generation ✅

- [x] Implement Q24 sin table generation from `Darwin.sin()` (2049 entries, linear interpolation)
- [x] Implement Q30 exp2 table generation from `Darwin.exp2()` (2049 entries, 10-bit indexing)
- [x] Generate MIDI note → frequency table (128 entries, 0.5Hz precision at 48kHz/2x)
- [x] Generate keyboard level scaling table (KLS, 101 entries for 0-100 curve)
- [x] Verify table accuracy against mathematical definitions

### Step 3: Lock-Free Infrastructure ✅

- [x] Implement `SnapshotRing<T>` SPSC ring buffer using `Synchronization.Atomic`
- [x] Verify lock-free behavior with `ManagedAtomic<UInt>` indices
- [x] Design `ParameterSnapshot` value type for parameter updates
- [x] Test concurrent enqueue/dequeue from UI and audio threads

### Step 4: Preset & Algorithm ✅

- [x] Encode 32 DX7 algorithms as `DX7Algorithms` enum
- [x] Define `DX7Preset` struct with 155-byte layout
- [x] Implement `DX7SysExParser` for 4096-byte SysEx parsing
- [x] Load factory presets from bundled SysEx resources

### Step 5: Synthesis Engine ✅

- [x] Implement `DX7Envelope` with 4-stage ADSR (rate 0-99, level 0-99)
- [x] Implement `DX7Operator` with modulation index, velocity sensitivity, and KLS
- [x] Implement `DX7Voice` with 6-operator FM kernel and algorithm routing
- [x] Implement `Algorithm` struct with carrier/modulator bus routing
- [x] Implement `SynthEngine` with 16-voice polyphony and note stealing

### Step 6: DSP & Accelerate Integration ✅

- [x] Implement `Downsampler` using 2x FIR decimation
- [x] Implement `VoiceMixer` with vDSP voice mixing and hard clipping
- [x] Use `vDSP_vflt32` for Int32 → Float conversion
- [x] Use `vDSP_vsma` for voice scaling and mixing
- [x] Use `vDSP_vclip` for output hard clipping

### Step 7: Test Suite ✅

- [x] Create `TableTests.swift`: Sin/Exp2 precision, frequency table, pitch bend, scaling
- [x] Create `EnvelopeTests.swift`: 4-stage EG, rate=99 fast attack, noteOff silence
- [x] Create `AlgorithmTests.swift`: 32 algorithms carrier count, feedback, bus routing
- [x] Create `WaveformTests.swift`: renderBlock output, silent voice, feedback effects
- [x] Create `ConcurrencyTests.swift`: SnapshotRing stress test, SynthEngine 1000 note on/off
- [x] Create `PerformanceTests.swift`: 16 voices × 512 frames rendering benchmark
- [x] Create `ReferenceTests.swift`: 10 operator-level DEXED comparison tests (ScaleRate, ScaleVelocity, ScaleLevel, exp2, EG, algorithms)
- [x] Create `VoiceComparisonTests.swift`: 14 voice-level waveform comparison tests against DEXED
- [x] Verify all 107 tests pass (17 test suites, 0 failures)

### Step 8: CI Pipeline ✅

- [x] Create `.github/workflows/ci.yml` for macOS 15 + Xcode 16
- [x] Configure `swift build` and `swift test` in CI
- [x] Verify scope: M2DXCore Swift target uses no MSFA imports/symbols at runtime; DX7Ref C target ports MSFA Apache 2.0 (test-only, see NOTICE)

### Real-Time Safety Improvements ✅

- [x] **Issue #2**: Fix heap allocation when SnapshotRing drops old SynthParamSnapshot instances
  - Changed `slots` and `slotConfigs` from dynamic `Array` to fixed-size tuples (8 elements)
  - Added `activeSlotCount` field to track active slots
  - Added subscript helpers: `slot(at:)`, `setSlot(at:)`, `config(at:)`, `setConfig(at:)`
  - Updated all SynthEngine.swift access to use new accessors
- [x] **Issue #3**: Fix heap allocation in VoiceMixer.accumulateVoice
  - Changed signature to accept caller-provided `scratch` buffer
  - Added pre-allocated `floatScratch` buffer to SynthEngine
  - Eliminated all internal heap allocation in mixing path
- [x] **Issue #4**: Replace NSLock + Array-based MIDI event queue with lock-free SPSC FIFO ring buffer
  - Created `SPSCRing<T>` generic lock-free FIFO ring buffer using `Synchronization.Atomic` (same pattern as SnapshotRing)
  - Replaced `SynthEngine.midiEvents: [MIDIEvent]` + `midiLock: NSLock` with `midiRing: SPSCRing<MIDIEvent>(capacity: 256)`
  - `sendMIDI()`: Removed lock acquisition, now calls `midiRing.push()` (lock-free)
  - `drainMIDI()`: Removed lock + array copy, now uses `while let event = midiRing.pop()` loop
  - Removed `import Foundation` dependency (NSLock no longer needed)
  - All 66 tests pass
- [x] **Bug Fix**: CC state persists after preset reload
  - Added `resetControllers()` method to reset all CC-derived state (modWheelDepth, breathDepth, footDepth, aftertouchDepth, pitchBendValue, sustainPedalOn)
  - Added `resetControllers: Bool = true` parameter to `loadSlotParams()` for automatic controller reset on preset load
  - Fixed `DX7Operator.noteOn()` to reset `gainOut = 0` to prevent stale gain from previous note
  - All 73 tests pass

### DX7 Accuracy Improvements (2026-02-18) ✅

- [x] **DEXED Reference Testing Infrastructure**
  - Created DX7Ref C target with DEXED msfa reference functions (operator-level)
  - Implemented ReferenceTests.swift with 10 comprehensive comparison tests
  - All DSP functions verified to match DEXED exactly (ScaleRate, ScaleVelocity, ScaleLevel, exp2, EG advance, algorithm flags)
- [x] **DEXED Voice-Level Rendering**
  - Extended DX7Ref with complete voice rendering functions (sin lookup, frequency LUT, oscillator frequency, FM core render, voice init/render/noteoff)
  - Implemented VoiceComparisonTests.swift with 14 waveform-level comparison tests
  - All voice-level tests pass with exact waveform match to DEXED (107 total tests, 17 suites)
- [x] **Keyboard Rate Scaling Bug Fix**
  - Fixed keyboardRateScaling() algorithm in ScalingTable.swift to match DEXED ScaleRate()
  - Changed from `min(7,(note-36+1)/3)*scaling` to `(scaling*min(31,max(0,note/3-7)))>>3`
  - Verified against DEXED for all 128 notes × 8 sensitivities
- [x] **Envelope Rate Scaling Application Fix**
  - Fixed DX7Envelope.advance() and recalcCurrentInc() to apply rateScaling to qrate instead of raw rate
  - Matches DEXED env.cc implementation exactly
  - Resolves E.PIANO1 sustain issue (1.3s → 40s+ decay)
- [x] **Atomic Preset Loading API**
  - Added SynthEngine.loadDX7Preset() for race-free preset application
  - Eliminates intermediate snapshot leakage from multi-setter approach
  - Includes PresetLoadTests.swift integration tests
- [x] **MIDI Event Ordering Fix**
  - Fixed drainMIDI() to process events in FIFO order
  - Prevents stuck notes from out-of-order note on/off
- [x] **Feedback Parameter Correction**
  - Fixed feedback to apply preset-global value to operator 0 only
  - Matches DX7 specification (algorithm-level, not per-operator)
- [x] **Output Processing Refinement**
  - Removed hard clipping from SynthEngine output
  - Delegates dynamic range management to host FX chain
- [x] **exp2LookupQ24 Integer Overflow**
  - Fixed 32-bit wrapping multiply to match DEXED C int overflow behavior
  - Changed from Swift Int (64-bit) to Int32 wrapping arithmetic (&*)
- [x] **dgain Rounding Direction**
  - Fixed envelope dgain calculation to use arithmetic right shift instead of division
  - Matches DEXED env.cc rounding behavior exactly (floor instead of truncate toward zero)
  - Added kLgBlockSize constant (6) for clarity

### Remaining Verification Tasks

- [x] **Output Scaling Normalization** (2026-02-18): Fixed SynthEngine divisor from 2^25 to 2^28 to match DEXED normalization (prevents clipping on multi-carrier algorithms)
- [ ] **Sound Tuning Verification**: Compare audio output against real DX7 hardware for all 32 algorithms
- [ ] **ARM Performance Benchmarks**: Profile rendering performance on Apple Silicon (target: <2ms for 16 voices × 512 frames)
- [ ] **Integration Testing**: Test library integration with M2DX app
- [ ] **MIDI 2.0 Integration**: Implement MIDI 2.0 note on/off message handling in host app

---

## Phase 3a: Real-Time Contract Cleanup (Pre-Release)

Identified by Codex critical review on 2026-04-26 + code verification. These RT-contract bugs in the current Swift codebase blocked Phase 4 multi-language porting (bit-exact Golden Master cannot be generated while determinism is broken) and had to be fixed before Phase 3 SPM release.

### P0 — Blocks Golden Master / Multi-Language Port — ✅ 6/6 complete (2026-04-27)

- [x] **SnapshotRing latest-value semantics fix** ✅ `69d987d`
  - Was: dropped NEW value when ring was full instead of overwriting OLDEST. Contradicted the `"latest value semantics"` docstring.
  - Fixed: rewrote as classic three-slot triple buffer with atomic state encoding (slot index in low bits, FRESH flag in bit 2). API: `init(capacity:)` → `init(initial:)`.

- [x] **doRPN SPSC violation** ✅ `acfcfe1`
  - Was: audio thread (via `drainMIDI` → `doRPN`) wrote `shadowSnapshot.pitchBendRange` + called `bumpVersion()`. Violated SnapshotRing's single-producer contract.
  - Fixed: new audio-local field `rpnPitchBendRangeOverride`; `doRPN` no longer touches `shadowSnapshot`. Reads via `effectivePitchBendRange(forSlot:)` helper.

- [x] **Per-slot pitchBendRange** ✅ `02a0815`
  - Was: `doPitchBend32` / `doPerNotePitchBend` read only the slot-0 convenience accessor; TX816 / dual / split modes ignored per-slot `SlotSnapshot.pitchBendRange`.
  - Fixed: replaced global `pitchBendValue` with `pitchBendValueBySlot: [Float]` (kMaxSlots entries). `doPitchBend32` pre-computes per-slot factors using each slot's own range; voices read by their `slotId`.

- [x] **slotMods heap allocation in render** ✅ `0123b6e`
  - Was: `var slotMods = [SlotMod](repeating: ..., count: slotCount)` allocated an Array per render call.
  - Fixed: moved `SlotMod` to a private nested struct on `SynthEngine`; pre-allocated `UnsafeMutablePointer<SlotMod>` scratch of size `kMaxSlots` in `init()`, deallocated in `deinit`.

- [x] **Float.random in S&H LFO** ✅ `b57c485`
  - Was: S&H LFO used non-deterministic `Float.random(in:)`. Affected the Int32 kernel via `lfoAmpModVal` and the Float stage via `lfoCurrentValue` → pitch factor; would have prevented bit-exact Golden Master.
  - Fixed: per-slot `SplitMix64` PRNG seeded at init from a fixed constant XOR'd with slot index. Reproducible across runs.

- [x] **masterTuning + RPN tuning unification** ✅ `29eca83`
  - Was: `masterTuning` was applied at note-on by baking `kTuningLUT` into op.frequency; RPN fine/coarse tuning was summed per block. Two paths had inconsistent scope — changing master tuning during a held note had no effect.
  - Fixed: removed the note-on master tuning override; new per-block `totalTuningOffset = (Float(snapshot.masterTuning) + rpnFineTuningCents) / 100 + rpnCoarseTuningSemitones` feeds `pitchBendFactorExt`. `kTuningLUT` is now unused (left in place pending separate cleanup).

### P1

- [ ] **sendMIDI public producer ambiguity** (`SynthEngine.swift:122`)
  - Risk: public API → multiple producers can call → SPSCRing single-producer contract may be violated.
  - Fix: docstring "single producer only" guarantee, or convert internal queue to MPSC ring.

- [ ] **VoiceMixer.swift dead code** (`Sources/M2DXCore/DSP/VoiceMixer.swift`)
  - Status: vDSP-based `accumulateVoice` is never called; render uses scalar for-loop at `SynthEngine.swift:840-855`. Mono dst signature would not fit current stereo render path anyway.
  - Decision: delete (Codex Q5 recommendation). If SIMD optimization is needed later, design a stereo-friendly variant after benchmarking.

- [ ] **Pitch EG libm in render path** (`Sources/M2DXCore/Engine/DX7Voice.swift`, `pitchEG.process`)
  - Status: `powf` / `expf` called on stage transitions in audio thread. RT-acceptable but undocumented.
  - Fix: explicit policy comment "permitted libm calls in RT path" so future RT audits don't flag.

### P2

- [ ] **RTSafetyTests.swift** — malloc-hook (Linux: `__libc_malloc` interpose; macOS: `malloc_zone_register`) or `os_signpost` based test that asserts zero heap allocation across N render blocks. Run in CI after every change to SynthEngine / DSP. **Phase 4a entry condition #4.**

- [ ] **CI matrix expansion** — add Linux build job (no Accelerate) to validate Phase 4 platform-independent path readiness. Currently CI is macOS 15 single-job (`.github/workflows/ci.yml:11`).

---

## Phase 3b: Golden Master Test Vector Generation

Generate language-neutral, deterministic test vectors that capture the current Swift kernel's output for representative scenarios. These vectors become the multi-language porting reference (replacing the Apache-2.0 DEXED dependency for Rust / C / C++ / C# kernels) and a regression detector for any future Swift-side optimisation.

**Status**: ready to start (Phase 3a P0 unblocked determinism on 2026-04-27).
**Phase 4a entry condition #1** per `docs/20260427_003000_phase4a_rust_rationale.md` — must complete before Rust code lands.

### Sub-tasks

- [ ] **Format spec** — `docs/golden-master-format.md` defining manifest schema, binary layout (Int32 LE block output, Float32 LE stereo output), scenario invariants, ULP tolerance for the Float stage.
- [ ] **Scenario design** — 30+ scenarios covering: INIT VOICE basic note-on; each algorithm's signature behaviour; KLS curves; LFO triangle / saw / square / sin / S&H; RPN tuning; channel/poly pressure; per-note CC and pitch-bend; sustain pedal; multi-timbral (dual / split / TX816); oversampling on/off.
- [ ] **Dump runner** — `Tests/GoldenMaster/Generator/GoldenMasterGenerator.swift` test target that drives `SynthEngine` through each scenario and writes Int32 block output + Float32 stereo output as `.bin` files alongside a `manifest.json`.
- [ ] **Verification test** — `Tests/M2DXCoreTests/GoldenMasterTests.swift` that re-runs each scenario and asserts byte-identical Int32 output + ULP-tolerant Float output match against the committed `.bin` files. Runs in CI.
- [ ] **Vector commit** — initial generation + `Tests/GoldenMaster/scenarios/<name>/{manifest.json, int32.bin, stereoL.bin, stereoR.bin}` committed to the repo (estimated total < 5 MB; acceptable inline).
- [ ] **Documentation** — `docs/golden-master-usage.md` for port authors: how to consume the vectors, expected pass/fail criteria.

### Out of scope (deferred to Phase 4a)

- Rust / C / C++ / C# implementations consuming the vectors.
- Float-stage bit-exact reproduction (libm transcendentals are platform-dependent; Float comparison stays ULP-tolerant by design).

---

## Sequencing — Next 4 Milestones

1. **Phase 3b** (Golden Master) — current focus; satisfies Phase 4a entry condition #1.
2. **Phase 3a P2** (`RTSafetyTests` + Linux CI job) — confirms Phase 3a P0; satisfies Phase 4a entry condition #4.
3. **Phase 3** (SPM Library Release: public API stability, DocC, NOTICE for DX7Ref Apache-2.0).
4. **Phase 4a** (Rust kernel under `ports/rust/`, gated on the five entry conditions in `docs/20260427_003000_phase4a_rust_rationale.md`).

P1 items in Phase 3a (sendMIDI / VoiceMixer / Pitch EG comment) are minor and can interleave anywhere; they do not block downstream work. The existing "Phase 4: TX816 Multi-Timbral" section below will be renumbered to Phase 5 when Phase 4 (port) work actually starts.

---

## Phase 3: SPM Library Release (Next)

### Swift Package Manager

- [ ] Create `Package.swift` with proper platform/version constraints
- [ ] Define library targets and test targets
- [ ] Declare swift-atomics dependency
- [ ] Declare Accelerate framework dependency
- [ ] Test package builds on iOS and macOS
- [ ] Verify package can be imported by external projects

### Public API Design

- [ ] Design minimal public API surface
- [ ] Expose `SynthEngine` as primary interface
- [ ] Expose `Preset` model for patch management
- [ ] Expose `NoteEvent` for MIDI input
- [ ] Hide internal implementation details (tables, operators, etc.)
- [ ] Document API stability guarantees

### API Documentation

- [x] **API Reference**: Complete public API reference created in `docs/API.md` (2026-02-16)
  - Covers all public types and methods in SynthEngine
  - Includes parameter types, MIDI handling, preset system, SysEx parsing
  - Documents all 32 DX7 algorithms and factory presets
  - Usage examples provided
- [ ] Write DocC documentation for all public types
- [ ] Create getting-started tutorial
- [ ] Create code examples for common use cases
- [ ] Document MIDI 2.0 integration patterns
- [ ] Create architecture overview diagram
- [ ] Generate and publish DocC archive

### Licensing

- [x] Apache License 2.0 set at repository root (`LICENSE`)
- [x] `NOTICE` file with MSFA / Google Inc. attribution and modification log
- [x] `LICENSES/Apache-2.0.txt` for SPDX/REUSE tooling
- [ ] Add Apache 2.0 short headers (SPDX-License-Identifier) to each source file
- [ ] Surface `NOTICE` contents in any consumer app (M2DX iOS About / Acknowledgements screen) — required by Apache 2.0 §4(d)
- [ ] Document DX7 trademark usage policy (nominative / descriptive use only)

## Phase 4: TX816 Multi-Timbral (Future)

### 8-Slot Voice Routing

- [ ] Implement slot allocation system
- [ ] Implement per-slot voice management (2-16 voices per slot)
- [ ] Implement MIDI channel routing to slots
- [ ] Implement slot mix and panning
- [ ] Test dynamic slot reconfiguration

### Key Split / Layer Logic

- [ ] Implement keyboard split mode (note range per slot)
- [ ] Implement layer mode (multiple slots on same note)
- [ ] Implement dual mode (2 slots, 8 voices each)
- [ ] Implement velocity-based slot selection
- [ ] Test complex split/layer configurations

### Macro Controls

- [ ] Design macro control system
- [ ] Implement brightness macro (multi-slot filter cutoff mapping)
- [ ] Implement attack macro (multi-slot EG mapping)
- [ ] Implement sustain macro (multi-slot EG mapping)
- [ ] Implement global modulation routing
- [ ] Test macro control performance impact

### AudioUnit Wrapper

- [ ] Create AUv3 extension target
- [ ] Implement Audio Unit v3 protocol
- [ ] Implement AU parameter tree
- [ ] Implement AU preset system
- [ ] Test in GarageBand/Logic Pro
- [ ] Submit to App Store (if standalone AU is desired)

---

## Notes

- Tasks are listed in suggested implementation order within each phase
- Dependencies between tasks are not explicitly marked; use judgment when parallelizing work
- Some Phase 4 features may be deferred to future major versions
- This TODO will be updated as requirements evolve
