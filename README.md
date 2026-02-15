# M2DX-Core

**DX7 FM Synthesis Library for Swift**

M2DX-Core is an FM synthesis library that reproduces the Yamaha DX7 sound engine in pure Swift. All code is originally implemented based on the DX7's published hardware specifications and the mathematical definition of FM synthesis.

## Status

**Phase 2 Complete** (2026-02-16) — The library extraction and clean room implementation is complete. All synthesis components, tests, and CI pipeline are functional. The next phase will focus on public API design and SPM release preparation.

## Key Features

- **MIT License** — Free for commercial and non-commercial use, no restrictions
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

All 66 tests should pass. Performance benchmarks may vary depending on your hardware (x86_64 vs ARM).

### Test Suite

The library includes comprehensive test coverage across 6 test suites:

| Test Suite | Tests | Coverage |
|------------|-------|----------|
| **TableTests** | 11 | Sin/Exp2 precision, frequency table, pitch bend, scaling curves |
| **EnvelopeTests** | 10 | 4-stage ADSR, rate=99 fast attack, noteOff silence verification |
| **AlgorithmTests** | 32 | All 32 DX7 algorithms carrier count, feedback, bus routing |
| **WaveformTests** | 8 | renderBlock output, silent voice, feedback modulation effects |
| **ConcurrencyTests** | 3 | SnapshotRing stress test, SynthEngine concurrent note on/off |
| **PerformanceTests** | 2 | 16 voices × 512 frames rendering benchmark |

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

### Original Implementation

All lookup tables and computation kernels are independently implemented:

- **Sin / Exp2 Tables**: Generated at compile time from mathematical functions
- **Velocity, KLS, EG Rate Tables**: Derived from FM synthesis definitions and publicly available hardware specifications
- **32 Algorithm Routing**: Encoded from Yamaha DX7 operator connection topology

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

Note: This library uses Swift 6.0's built-in `Synchronization` module for atomic operations, eliminating the need for external dependencies like swift-atomics.

## License

MIT License — See [LICENSE](LICENSE) for details.

## Roadmap

See [TODO.md](TODO.md) for the complete roadmap.

### ✅ Phase 2: Library Extraction & Clean Room (Complete)

- [x] Swift Package with Swift 6.0 strict concurrency
- [x] Self-generated lookup tables (sin, exp2, frequency, scaling)
- [x] Lock-free `SnapshotRing<T>` using `Synchronization.Atomic`
- [x] DX7 presets, algorithms, and SysEx parser
- [x] Full synthesis engine (envelope, operator, voice, polyphony)
- [x] Accelerate-based DSP (downsampler, voice mixer)
- [x] 66 tests across 6 test suites
- [x] GitHub Actions CI pipeline

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
