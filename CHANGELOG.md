# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Issue #2**: Eliminated heap allocation on audio thread when SnapshotRing drops old snapshots
  - Changed `SynthParamSnapshot.slots` and `SynthParamSnapshot.slotConfigs` from dynamic `Array<T>` to fixed-size tuples (8 elements)
  - Added `activeSlotCount: Int` field to track active slots dynamically
  - Added subscript helpers (`slot(at:)`, `setSlot(at:)`, `config(at:)`, `setConfig(at:)`) for ergonomic tuple access
  - Updated all SynthEngine code paths to use new accessor methods
- **Issue #3**: Eliminated heap allocation in voice mixing path
  - Changed `VoiceMixer.accumulateVoice()` signature to accept caller-provided `scratch: UnsafeMutablePointer<Float>` buffer
  - Added pre-allocated `floatScratch: UnsafeMutablePointer<Float>` to SynthEngine for reuse across render calls
  - Audio thread now completely allocation-free during normal operation

### Added
- **Swift Package**: Created `Package.swift` with Swift 6.0, macOS 15+ / iOS 18+ support
- **Tables**: Self-generated Q24 sin table, Q30 exp2 table, frequency table, scaling table (all computed from mathematical functions)
- **Infrastructure**: Lock-free `SnapshotRing<T>` SPSC ring buffer using `Synchronization.Atomic`
- **Presets**: `DX7Algorithms` (32 algorithms), `DX7Preset` (155-byte layout), `DX7SysExParser`, factory presets
- **Engine**: `DX7Envelope`, `DX7Operator`, `DX7Voice`, `Algorithm` routing, `SynthEngine` with 16-voice polyphony
- **DSP**: `Downsampler` (2x FIR decimation), `VoiceMixer` (vDSP mixing/clipping)
- **Tests**: 66 tests across 6 test files (TableTests, EnvelopeTests, AlgorithmTests, WaveformTests, ConcurrencyTests, PerformanceTests)
- **CI**: GitHub Actions workflow for macOS 15 + Xcode 16

### Changed
- Migrated from documentation-only to fully functional synthesis library
- All lookup tables now generated from mathematical definitions (no msfa-derived code)
- Accelerate framework integrated for DSP operations (vDSP mixing, clipping, conversion)

### Notes
- **Phase 2 Complete** (2026-02-16): Library extraction and clean room implementation finished
- 17 Swift source files, all tests passing
- Clean room verification: `grep -ri msfa Sources/` returns 0 results
- Performance: 16 voices × 512 frames renders in ~17.8ms on x86_64 (target: <2ms on ARM)

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
