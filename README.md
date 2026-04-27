# M2DX-Core

**DX7-Style FM Synthesis Library for Swift**

M2DX-Core is a 6-operator / 32-algorithm FM synthesis library written in Swift. The production target (`M2DXCore`) is independently implemented from the publicly documented DX7 hardware behavior and the mathematical definition of FM synthesis. A separate test-only C target (`DX7Ref`) ports reference functions from the Apache-2.0-licensed `msfa` code so that the Swift implementation can be cross-validated at the bit level — see [NOTICE](NOTICE) for attribution and scope.

## Status

**Phase 2 Complete** (2026-02-16) — The library extraction is complete: the Swift production target is implemented from spec and cross-validated against the `msfa` C reference (`DX7Ref`, test-only). All synthesis components, tests, and CI pipeline are functional. The next phase focuses on public API design and SPM release preparation.

## Key Features

- **MIT License** for the production `M2DXCore` Swift target. The test-only `DX7Ref` C target is Apache-2.0 (see [NOTICE](NOTICE))
- **Swift 6** — Strict concurrency, value semantics, zero-allocation audio rendering
- **MIDI 2.0 Native** — 16-bit velocity, 32-bit CC, per-note controllers (MPE-compatible)
- **Apple Accelerate** — Hardware-accelerated DSP using vDSP (SIMD optimization)
- **Lock-Free Architecture** — Parameter changes delivered via atomic SPSC ring buffer
- **Bit-Accurate DX7 Mode** — Int32 fixed-point arithmetic reproduces the original OPS chip
- **Clean Float32 Mode** — Modern floating-point engine for extensibility

## Platform Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.0+
- Xcode 16.0+

## Build Instructions

```bash
# Clone the repository
git clone https://github.com/yourusername/M2DX-Core.git
cd M2DX-Core

# Build the library
swift build

# Run tests
swift test

# Run tests with verbose output
swift test --verbose
```

All 107 tests should pass. Performance benchmarks may vary depending on your hardware (x86_64 vs ARM).

### Test Suite

The library includes comprehensive test coverage across 8 test suites:

| Test Suite | Tests | Coverage |
|------------|-------|----------|
| **TableTests** | 11 | Sin/Exp2 precision, frequency table, pitch bend, scaling curves |
| **EnvelopeTests** | 10 | 4-stage ADSR, rate=99 fast attack, noteOff silence verification |
| **AlgorithmTests** | 32 | All 32 DX7 algorithms carrier count, feedback, bus routing |
| **WaveformTests** | 8 | renderBlock output, silent voice, feedback modulation effects |
| **ConcurrencyTests** | 3 | SnapshotRing stress test, SynthEngine concurrent note on/off |
| **PerformanceTests** | 2 | 16 voices × 512 frames rendering benchmark |
| **ReferenceTests** | 10 | Operator-level DEXED comparison (ScaleRate, ScaleVelocity, ScaleLevel, exp2, EG, algorithms) |
| **VoiceComparisonTests** | 14 | Voice-level waveform comparison against DEXED (INIT VOICE, algorithms, feedback, velocity, rate scaling, KLS, detune, E.PIANO) |

Run tests with:
```bash
swift test                 # Run all tests
swift test --verbose       # Verbose output with test names
swift test --filter Table  # Run only TableTests
```

## Architecture

M2DX-Core provides two synthesis modes:

| Mode | Arithmetic | Precision | Use Case |
|------|-----------|-----------|----------|
| **DX7** | Int32 fixed-point (Q24/Q30) | Bit-accurate to OPS chip | Authentic reproduction |
| **Clean** | Float32 | ~24-bit mantissa | Extensibility, custom waveforms |

### Design Philosophy

**"Bit-Accurate Soul, Modern Body"**

- **Soul**: The DX7's sonic character — log-domain arithmetic, envelope curves, feedback averaging, 32 algorithm routings — is reproduced at bit-level accuracy.
- **Body**: Memory management, thread model, and API design are optimized for Apple platforms with modern Swift paradigms.

## Technical Highlights

### Implementation Approach

The production `M2DXCore` Swift target implements all synthesis logic and tables independently:

- **Sin / Exp2 Tables**: Generated at compile time from mathematical functions
- **Velocity, KLS, EG Rate Tables**: Derived from FM synthesis definitions and publicly documented hardware behavior
- **32 Algorithm Routing**: Encoded from the operator connection topology described in DX7 service literature

The separate `DX7Ref` C target (test-only, not linked into production) ports reference functions from the Apache-2.0 `msfa` code; the Swift implementation is verified bit-for-bit against this reference. See [NOTICE](NOTICE) for full attribution and modification log.

### Real-time Safety

- **Zero-Allocation**: No `malloc`, `retain`, or `release` in the audio render loop
- **Lock-Free SPSC Ring Buffers**: UI-thread parameter changes and MIDI events delivered without blocking the audio thread
  - `SnapshotRing<T>`: Parameter snapshot delivery (UI → Audio)
  - `SPSCRing<T>`: MIDI event FIFO queue (UI → Audio, preserves event order)
- **Pre-allocated Voice Arrays**: All voice structures and scratch buffers allocated at initialization
- **Fixed-Size Tuples**: Parameter snapshots use fixed-size tuples instead of dynamic arrays to prevent heap deallocation on audio thread
- **Caller-Provided Scratch Buffers**: DSP operations use pre-allocated scratch space to eliminate internal allocations
- **No Locks**: All cross-thread communication uses atomic operations (`Synchronization.Atomic`) instead of NSLock/pthread_mutex

### Hardware Acceleration

Apple Accelerate (vDSP) is used for batch DSP operations:

- FIR downsampling (2x oversampling decimation)
- Int32 → Float conversion (DX7 Q24 block output)
- Voice mixing (scale + add, stereo panning)
- Gain application (master volume)
- Hard clipping (output limiter)

### Multi-Timbral Voice Architecture

| Mode | Slots | Voices/Slot | Description |
|------|-------|-------------|-------------|
| Single | 1 | 16 | Standard DX7 |
| Dual | 2 | 8 | Layer two patches |
| Split | 2 | 8 | Keyboard split |
| TX816 | 8 | 2 | 8-module monster synth |

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Synchronization (stdlib) | Swift 6.0+ | Lock-free atomic operations for SPSC ring buffer |
| Accelerate (system) | — | vDSP batch DSP operations (mixing, clipping, conversion) |

Note: The production target uses only Swift 6.0's built-in `Synchronization` module and Apple's Accelerate. There are no external Swift package dependencies.

## License & Attribution

| Target | License | Notes |
|--------|---------|-------|
| `M2DXCore` (production) | MIT | See [LICENSE](LICENSE) |
| `DX7Ref` (test-only C) | Apache 2.0 | Ported from `msfa` (Google Inc., 2012). See [NOTICE](NOTICE) and [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt) |

The Apache-2.0-licensed `DX7Ref` target is built only by `swift test` and is not part of any binary an application links against. Downstream consumers of `M2DXCore` therefore depend only on MIT-licensed code at runtime.

DX7 is a registered trademark of Yamaha Corporation. M2DX-Core is not affiliated with or endorsed by Yamaha. References to DX7 are nominative use to describe the family of FM synthesis algorithms this library implements.

## Roadmap

See [TODO.md](TODO.md) for the complete roadmap.

### ✅ Phase 2: Library Extraction & Clean Room (Complete)

- [x] Swift Package with Swift 6.0 strict concurrency
- [x] Self-generated lookup tables (sin, exp2, frequency, scaling)
- [x] Lock-free `SnapshotRing<T>` using `Synchronization.Atomic`
- [x] DX7 presets, algorithms, and SysEx parser
- [x] Full synthesis engine (envelope, operator, voice, polyphony)
- [x] Accelerate-based DSP (downsampler, voice mixer)
- [x] 107 tests across 8 test suites (including voice-level DEXED comparison)
- [x] GitHub Actions CI pipeline
- [x] Bit-exact waveform verification against DEXED reference implementation

### 🎯 Next: Phase 3 — SPM Library Release

- [ ] Public API design and documentation
- [ ] DocC documentation for all public types
- [ ] API stability guarantees
- [ ] MIT license headers
- [ ] Getting-started tutorial and code examples

### 🔮 Future: Phase 4 — TX816 Multi-Timbral

- [ ] 8-slot voice routing (2-16 voices per slot)
- [ ] Keyboard split/layer logic
- [ ] Macro controls (brightness, attack, sustain)
- [ ] AudioUnit v3 wrapper

## Documentation

- **[docs/API.md](docs/API.md)** — Complete public API reference
- [docs/proposal.md](docs/proposal.md) — Full technical specification and design philosophy
- [TODO.md](TODO.md) — Detailed roadmap and task list
- [CHANGELOG.md](CHANGELOG.md) — Version history

## Contributing

This project is currently in early development. Contributions will be welcomed after the Phase 3 SPM release.

## Contact

This library is developed as part of the M2DX synthesizer app.

---

**M2DX-Core** — Bringing the legendary DX7 sound to modern Swift development.
