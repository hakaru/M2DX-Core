# M2DX-Core: DX7 FM Synthesis Library for Swift

**Date:** 2026-02-15
**License:** MIT
**Platform:** iOS 18+ / macOS 14+
**Language:** Swift 6
**Status:** Draft

---

## 1. Overview

M2DX-Core is an FM synthesis library that reproduces the Yamaha DX7 sound engine (OPS: YM21280) in pure Swift.

All code is **originally implemented** based on the DX7's published hardware specifications and the mathematical definition of FM synthesis. It does not depend on any existing DX7 reimplementation (msfa, Dexed, etc.) and is provided under the **MIT License**.

### Key Differentiators

| Feature | msfa (C++) | Dexed (C++/JUCE) | **M2DX-Core (Swift)** |
|---------|-----------|-------------------|----------------------|
| License | Apache 2.0 | GPL v3 | **MIT** |
| Thread Safety | Manual locking | JUCE message thread | **Swift 6 Strict Concurrency** |
| MIDI | 1.0 (7-bit) | 1.0 (7-bit) | **2.0 (16-bit velocity, 32-bit CC, MPE)** |
| Parameter Transfer | Shared mutable state | JUCE ValueTree | **Lock-free SPSC + Value Semantics** |
| SIMD | ARM NEON assembly | None | **Apple Accelerate (vDSP)** |
| Integration | Android NDK | VST3/AU plugin | **Swift Package Manager** |

---

## 2. Design Philosophy

### "Bit-Accurate Soul, Modern Body"

- **Soul**: The DX7's sonic character — log-domain arithmetic, envelope curves, feedback averaging, 32 algorithm routings — is reproduced at bit-level accuracy using Int32 fixed-point arithmetic.
- **Body**: Memory management, thread model, and API design are optimized for Apple platforms (iOS/macOS) with modern Swift paradigms.

---

## 3. Technical Specifications

### A. Original High-Precision Arithmetic Core

All lookup tables and computation kernels are independently implemented:

- **Sin / Exp2 Tables**: Generated at compile time from `sin()` / `exp2()` mathematical functions. Q24 phase, Q30 amplitude.
- **Velocity, KLS, EG Rate Tables**: Derived from the mathematical definition of FM synthesis and publicly available hardware specifications.
- **32 Algorithm Routing**: Encoded from Yamaha DX7 operator connection topology (documented in service manuals and patents).

Two engine modes:

| Mode | Arithmetic | Precision | Use Case |
|------|-----------|-----------|----------|
| **DX7** | Int32 fixed-point (Q24/Q30) | Bit-accurate to OPS chip | Authentic reproduction |
| **Clean** | Float32 | ~24-bit mantissa | Extensibility, custom waveforms |

### B. Real-time Safety

- **Zero-Allocation**: No `malloc`, `retain`, or `release` in the audio render loop. All voice arrays and scratch buffers are pre-allocated at engine initialization.
- **Lock-Free SPSC Ring Buffer**: UI-thread parameter changes are delivered to the audio thread via a single-producer single-consumer ring buffer using `swift-atomics` (release-acquire semantics). No locks held on the audio thread.

### C. MIDI 2.0 Native

- **16-bit Velocity**: 65,536 steps for expressive touch-to-timbre mapping.
- **32-bit CC / Pitch Bend**: Smooth, high-resolution modulation.
- **Property Exchange**: 155+ parameters accessible via standard MIDI-CI resource paths.
- **Per-Note Controllers**: Per-note pitch bend, aftertouch, timbre (MPE-compatible).

### D. SIMD / Accelerate (Hardware-Accelerated DSP)

Apple Accelerate (vDSP) is used for batch DSP operations:

| Operation | API | Context |
|-----------|-----|---------|
| FIR Downsampling | `vDSP_desamp` | 2x oversampling decimation |
| Int32 → Float conversion | `vDSP_vflt32` | DX7 Q24 block output |
| Voice mixing (scale + add) | `vDSP_vsma` | Per-voice stereo panning |
| Gain application | `vDSP_vmul` | Master volume, pan gains |
| Hard clipping | `vDSP_vclip` | Output limiter |

Target: ARM NEON (Apple Silicon). The FM operator kernel (sin calculation) uses table lookup by default; polynomial approximation (SIMD-friendly) is available as an optimization path if profiling indicates it is needed.

### E. Multi-Timbral Voice Architecture

| Mode | Slots | Voices/Slot | Description |
|------|-------|-------------|-------------|
| Single | 1 | 16 | Standard DX7 |
| Dual | 2 | 8 | Layer two patches |
| Split | 2 | 8 | Keyboard split |
| TX816 | 8 | 2 | 8-module monster synth |

- **Dynamic Voice Allocation**: Round-robin voice stealing with priority-based allocation.
- **Per-Slot Independence**: Each slot has its own algorithm, envelopes, LFO, and MIDI channel.

---

## 4. Library Architecture

```
M2DX-Core (Swift Package)
├── Sources/
│   └── M2DXCore/
│       ├── Engine/
│       │   ├── SynthEngine.swift        — Top-level engine, voice management
│       │   ├── Operator.swift           — FM operator (sin oscillator + EG)
│       │   ├── OperatorDX7.swift        — DX7-mode Int32 operator
│       │   ├── Voice.swift              — 6-operator voice (Clean mode)
│       │   ├── VoiceDX7.swift           — 6-operator voice (DX7 mode)
│       │   ├── Envelope.swift           — ADSR envelope (Float)
│       │   ├── EnvelopeDX7.swift        — DX7 4-stage EG (Int32)
│       │   └── Algorithm.swift          — 32 algorithm routing
│       ├── Tables/
│       │   ├── SinTable.swift           — Self-generated Q30 sin LUT
│       │   ├── Exp2Table.swift          — Self-generated Q30 exp2 LUT
│       │   ├── VelocityTable.swift      — DX7 velocity sensitivity
│       │   └── FrequencyTable.swift     — MIDI note → frequency
│       ├── DSP/
│       │   ├── Downsampler.swift        — 2x FIR decimation (vDSP)
│       │   └── VoiceMixer.swift         — Accelerate-based mixing
│       ├── Infrastructure/
│       │   ├── SnapshotRing.swift       — Lock-free SPSC ring buffer
│       │   └── ParameterSnapshot.swift  — Atomic parameter transfer
│       └── Preset/
│           ├── DX7Preset.swift          — Preset data model
│           ├── DX7SysExParser.swift      — .syx bulk import
│           └── FactoryPresets.swift      — Built-in presets
└── Tests/
    └── M2DXCoreTests/
        ├── SinTableTests.swift          — LUT accuracy verification
        ├── EnvelopeTests.swift          — EG curve regression
        ├── AlgorithmTests.swift         — Routing correctness
        └── SnapshotRingTests.swift      — Concurrency stress test
```

### Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| swift-atomics | 1.2+ | Lock-free SPSC ring buffer |
| Accelerate (system) | — | vDSP batch DSP operations |

No other external dependencies.

---

## 5. Roadmap

### Phase 1: Core Logic (Completed in M2DX app)

- [x] 32 DX7 algorithms
- [x] Log-domain sin/exp2 tables and lookup
- [x] 4-stage envelope generator
- [x] DX7 SysEx parser
- [x] Lock-free parameter snapshot ring

### Phase 2: Library Extraction & Clean Room (Current)

- [ ] **msfa-derived code elimination**: Replace all msfa-originated tables and logic with independent implementations
- [ ] **Table self-generation**: Sin/Exp2 LUTs computed from `Darwin.sin()` / `Darwin.exp2()`
- [ ] **Rename & restructure**: Remove all `kMsfa*` / `msfa*` identifiers; adopt original naming
- [ ] **Accelerate integration**: vDSP for downsampler, voice mixing, clipping
- [ ] **Sound tuning**: Modulation index, velocity sensitivity, feedback correction
- [ ] **Test suite**: Waveform regression tests, LUT accuracy, EG curve verification

### Phase 3: SPM Library Release (Next)

- [ ] Swift Package Manager with `Package.swift`
- [ ] Public API design (minimal surface: `SynthEngine` + `Preset` + `NoteEvent`)
- [ ] API documentation (DocC)
- [ ] MIT LICENSE file

### Phase 4: TX816 Multi-Timbral (Future)

- [ ] 8-slot voice routing
- [ ] Key split / layer logic
- [ ] Macro controls (brightness, attack, sustain → multi-slot mapping)
- [ ] AudioUnit (AUv3) wrapper

---

## 6. License

**MIT License**

- Free for commercial and non-commercial use, modification, and redistribution.
- The only obligation is to include the LICENSE file (copyright notice + MIT text).
- All code is originally implemented. No dependency on msfa (Apache 2.0) or Dexed (GPL).
- All LUTs (Sin, Exp2, Velocity, KLS, etc.) are generated from mathematical functions and publicly available hardware specifications.
- FM synthesis kernels, envelopes, and operator structures are designed from the mathematical definition of phase modulation and publicly documented DX7 behavior.

---

## 7. Expected Impact

This library enables developers to integrate DX7-quality FM synthesis into their apps **without license restrictions**, as naturally as using CoreAudio. Target use cases include:

- Music production apps (DAWs, standalone synths)
- Game audio engines
- Educational synthesizer tools
- Creative coding / generative music
