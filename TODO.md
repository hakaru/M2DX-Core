# TODO

This document tracks the development roadmap for M2DX-Core, organized by project phase.

## Phase 2: Library Extraction & Clean Room (Current)

### msfa-derived Code Elimination

- [ ] Identify all msfa-originated tables and logic in current codebase
- [ ] Document which components need independent reimplementation
- [ ] Replace msfa-derived lookup tables with self-generated versions
- [ ] Remove all msfa-specific logic and replace with original implementations
- [ ] Verify no Apache 2.0 license obligations remain

### Table Self-Generation

- [ ] Implement compile-time sin table generation from `Darwin.sin()`
- [ ] Implement compile-time exp2 table generation from `Darwin.exp2()`
- [ ] Generate velocity sensitivity table from mathematical definition
- [ ] Generate keyboard level scaling (KLS) table
- [ ] Generate EG rate scaling table
- [ ] Verify table accuracy against DX7 hardware specifications

### Rename & Restructure

- [ ] Remove all `kMsfa*` identifiers
- [ ] Remove all `msfa*` prefixed variables and types
- [ ] Adopt original naming conventions consistent with Swift API guidelines
- [ ] Restructure directory layout to match planned library architecture
- [ ] Update all internal documentation to reflect new naming

### Accelerate Integration

- [ ] Implement vDSP-based downsampler (`vDSP_desamp`)
- [ ] Implement Int32 → Float conversion using `vDSP_vflt32`
- [ ] Implement voice mixing with `vDSP_vsma` (scale + add)
- [ ] Implement gain application with `vDSP_vmul`
- [ ] Implement hard clipping with `vDSP_vclip`
- [ ] Profile performance gains from Accelerate integration
- [ ] Consider SIMD optimization for FM operator kernel if needed

### Sound Tuning

- [ ] Calibrate modulation index for accurate DX7 timbre
- [ ] Tune velocity sensitivity curves
- [ ] Implement feedback correction (averaging/delay)
- [ ] Verify operator routing for all 32 algorithms
- [ ] Test against reference DX7 patches
- [ ] Document any intentional deviations from hardware behavior

### Test Suite

- [ ] Create waveform regression tests (compare against known-good output)
- [ ] Create LUT accuracy tests (verify sin/exp2 precision)
- [ ] Create EG curve verification tests
- [ ] Create algorithm routing correctness tests
- [ ] Create concurrency stress tests for lock-free ring buffer
- [ ] Create performance benchmarks for audio rendering
- [ ] Set up continuous integration (CI) pipeline

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
