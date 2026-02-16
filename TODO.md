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
- [x] Verify all 66 tests pass

### Step 8: CI Pipeline ✅

- [x] Create `.github/workflows/ci.yml` for macOS 15 + Xcode 16
- [x] Configure `swift build` and `swift test` in CI
- [x] Verify clean room implementation (no msfa references)

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

### Remaining Verification Tasks

- [ ] **Sound Tuning Verification**: Compare audio output against real DX7 hardware for all 32 algorithms
- [ ] **ARM Performance Benchmarks**: Profile rendering performance on Apple Silicon (target: <2ms for 16 voices × 512 frames)
- [ ] **Integration Testing**: Test library integration with M2DX app
- [ ] **MIDI 2.0 Integration**: Implement MIDI 2.0 note on/off message handling in host app

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

- [ ] Create MIT LICENSE file with copyright notice
- [ ] Add license headers to all source files
- [ ] Create NOTICE file documenting independent implementation
- [ ] Verify no unintended license obligations
- [ ] Document DX7 trademark usage policy (descriptive use only)

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
