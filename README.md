# M2DX-Core

**DX7 FM Synthesis Library for Swift**

M2DX-Core is an FM synthesis library that reproduces the Yamaha DX7 sound engine in pure Swift. All code is originally implemented based on the DX7's published hardware specifications and the mathematical definition of FM synthesis.

## Status

**Early Development** — This project is currently in Phase 2 (Library Extraction & Clean Room). The core logic has been completed in the M2DX app and is now being extracted into a standalone library.

## Key Features

- **MIT License** — Free for commercial and non-commercial use, no restrictions
- **Swift 6** — Strict concurrency, value semantics, zero-allocation audio rendering
- **MIDI 2.0 Native** — 16-bit velocity, 32-bit CC, per-note controllers (MPE-compatible)
- **Apple Accelerate** — Hardware-accelerated DSP using vDSP (SIMD optimization)
- **Lock-Free Architecture** — Parameter changes delivered via atomic SPSC ring buffer
- **Bit-Accurate DX7 Mode** — Int32 fixed-point arithmetic reproduces the original OPS chip
- **Clean Float32 Mode** — Modern floating-point engine for extensibility

## Platform Requirements

- iOS 18.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

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
- **Lock-Free SPSC Ring Buffer**: UI-thread parameter changes delivered without blocking the audio thread
- **Pre-allocated Voice Arrays**: All voice structures and scratch buffers allocated at initialization

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
| swift-atomics | 1.2+ | Lock-free SPSC ring buffer |
| Accelerate (system) | — | vDSP batch DSP operations |

## License

MIT License — See [LICENSE](LICENSE) for details.

## Roadmap

This project is currently in **Phase 2**. See [TODO.md](TODO.md) for the complete roadmap.

### Completed (Phase 1)

- 32 DX7 algorithms
- Log-domain sin/exp2 tables and lookup
- 4-stage envelope generator
- DX7 SysEx parser
- Lock-free parameter snapshot ring

### In Progress (Phase 2)

- msfa-derived code elimination
- Table self-generation
- Accelerate integration
- Sound tuning
- Test suite

### Planned

- Phase 3: Swift Package Manager release
- Phase 4: TX816 multi-timbral support

## Documentation

- [docs/proposal.md](docs/proposal.md) — Full technical specification and design philosophy
- [TODO.md](TODO.md) — Detailed roadmap and task list
- [CHANGELOG.md](CHANGELOG.md) — Version history

## Contributing

This project is currently in early development. Contributions will be welcomed after the Phase 3 SPM release.

## Contact

This library is developed as part of the M2DX synthesizer app.

---

**M2DX-Core** — Bringing the legendary DX7 sound to modern Swift development.
