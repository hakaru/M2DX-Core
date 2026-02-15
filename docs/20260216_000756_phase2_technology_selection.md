# M2DX-Core Phase 2 Technology Selection Report

**Date**: 2026-02-16
**Author**: Claude (Technology Research Sub-Agent)
**Project**: M2DX-Core -- DX7 FM Synthesis Library for Swift
**Target**: iOS 18+ / macOS 14+, Swift 6, Apple Silicon

---

## 1. Swift 6 Strict Concurrency for Real-time Audio

### 1.1 Investigation Summary

| Item | Details |
|------|---------|
| Swift Version | 6.0 (SE-0410 Atomics included in stdlib) |
| Swift 6.2 Preview | `nonisolated(nonsending)` default, `@concurrent` attribute |
| Key Proposals | SE-0410 (Atomics), SE-0461 (nonisolated nonsending), SE-0466 (defaultIsolation) |

### 1.2 Audio Render Thread Pattern Recommendations

**Problem**: Audio render callbacks (AVAudioSourceNode) execute on a real-time thread. No allocations, no locks, no async/await are permitted.

**Recommended Pattern**:

1. **`nonisolated(unsafe)` for immutable global LUTs**: Sine/Exp2/Frequency tables allocated once at initialization and never mutated afterward. This is safe because the data is effectively immutable after `let` initialization. The existing M2DX approach using `nonisolated(unsafe) private let` is correct.

2. **`@Sendable` closures for render callbacks**: The `AVAudioSourceNode` render block must be `@Sendable`. All captured state must be `Sendable` -- use value types or `UnsafeMutablePointer` with ownership discipline.

3. **`nonisolated` methods on engine types**: The render path methods should be `nonisolated` to avoid actor isolation overhead. For Swift 6.0, explicitly mark render-path methods as `nonisolated`.

4. **`sending` parameter (Swift 6.0)**: Use `sending` for transferring ownership of buffers between isolation domains when handing off pre-allocated scratch buffers.

5. **Avoid `async`/`await` entirely on the render thread**: The render callback is synchronous. All parameter reads must be through lock-free mechanisms (atomic loads or SPSC ring buffer reads).

### 1.3 `Synchronization.Atomic` vs `swift-atomics` Decision

| Criterion | `Synchronization.Atomic` (stdlib) | `swift-atomics` 1.3.0 |
|-----------|-----------------------------------|-----------------------|
| Availability | Swift 6.0+ (iOS 18+, macOS 15+) | Swift 5.10+ |
| API Surface | `Atomic<Value>`, basic load/store/CAS | `ManagedAtomic`, `UnsafeAtomic`, richer API |
| Memory Ordering | `.acquiring`, `.releasing`, `.acquiringAndReleasing`, `.relaxed`, `.sequentiallyConsistent` | Similar set |
| Sendable | Built-in (noncopyable `~Copyable`) | `ManagedAtomic` is `@unchecked Sendable` |
| Dependency | None (stdlib) | External package |
| `AtomicRepresentable` | Int, UInt, Bool, pointers, etc. | Broader set via `AtomicValue` |

**Recommendation: `Synchronization.Atomic` (stdlib)**

Rationale:
- M2DX-Core targets iOS 18+ / macOS 14+ and Swift 6, so `Synchronization` module is available.
- Eliminates external dependency for a core safety mechanism.
- Native integration with Swift 6 ownership model (`~Copyable`).
- The SPSC ring buffer needs only `Atomic<Int>` for head/tail indices with `.acquiring`/`.releasing` ordering, which is fully supported.
- **Note**: macOS 14 is below macOS 15 where `Synchronization` was introduced. If macOS 14 support is truly required, `swift-atomics` 1.3.0 must be used as a fallback. **Verify**: `Synchronization` module availability on macOS 14.

**Fallback**: If macOS 14 compatibility is confirmed to lack `Synchronization`, use `swift-atomics` 1.3.0 with `ManagedAtomic<Int>`.

### 1.4 SPSC Ring Buffer Design

The lock-free SPSC (Single-Producer Single-Consumer) ring buffer for parameter snapshots should follow this pattern:

- **Producer** (UI thread): Writes `ParameterSnapshot` value type into ring slot, then `store(writeIndex, ordering: .releasing)`.
- **Consumer** (Audio thread): `load(writeIndex, ordering: .acquiring)`, reads snapshot, then `store(readIndex, ordering: .releasing)`.
- Release-acquire semantics guarantee that the consumer sees all writes to the snapshot data before the index update becomes visible.
- Ring size should be a power of 2 (recommended: 4 or 8 slots) for efficient modulo via bitmask.
- `ParameterSnapshot` must be a plain value type (struct) with no reference types to avoid retain/release on the audio thread.

---

## 2. Apple Accelerate vDSP for Audio DSP

### 2.1 Investigation Summary

| Function | Purpose in M2DX-Core | Signature |
|----------|---------------------|-----------|
| `vDSP_desamp` | 2x FIR downsampling (oversampling decimation) | `vDSP_desamp(_ __A: UnsafePointer<Float>, _ __DF: vDSP_Stride, _ __F: UnsafePointer<Float>, _ __C: UnsafeMutablePointer<Float>, _ __N: vDSP_Length, _ __P: vDSP_Length)` |
| `vDSP_vflt32` | Int32 -> Float32 batch conversion | `vDSP_vflt32(_ __A: UnsafePointer<Int32>, _ __IA: vDSP_Stride, _ __C: UnsafeMutablePointer<Float>, _ __IC: vDSP_Stride, _ __N: vDSP_Length)` |
| `vDSP_vsma` | Vector scalar multiply and add (voice mixing) | `vDSP_vsma(_ __A: UnsafePointer<Float>, _ __IA: vDSP_Stride, _ __B: UnsafePointer<Float>, _ __C: UnsafePointer<Float>, _ __IC: vDSP_Stride, _ __D: UnsafeMutablePointer<Float>, _ __ID: vDSP_Stride, _ __N: vDSP_Length)` |
| `vDSP_vmul` | Vector multiply (gain application) | `vDSP_vmul(_ __A: UnsafePointer<Float>, _ __IA: vDSP_Stride, _ __B: UnsafePointer<Float>, _ __IB: vDSP_Stride, _ __C: UnsafeMutablePointer<Float>, _ __IC: vDSP_Stride, _ __N: vDSP_Length)` |
| `vDSP_vclip` | Vector clip (hard limiting) | `vDSP_vclip(_ __A: UnsafePointer<Float>, _ __IA: vDSP_Stride, _ __B: UnsafePointer<Float>, _ __C: UnsafePointer<Float>, _ __D: UnsafeMutablePointer<Float>, _ __ID: vDSP_Stride, _ __N: vDSP_Length)` |

### 2.2 Performance Characteristics at N=64

**Concern**: vDSP has function call overhead. For very small vectors (N=32 or N=64), the overhead may negate the SIMD benefit.

**Findings**:
- ARM NEON processes 4 floats per instruction (128-bit SIMD). N=64 means 16 NEON iterations -- sufficient for meaningful vectorization.
- vDSP on Apple Silicon achieves up to 1.49 TFLOPS (M4) for large vectors. Small vectors are less benchmarked but still benefit from NEON.
- vDSP may fall back to scalar path if data is misaligned. **Pre-allocate aligned buffers** using `UnsafeMutablePointer<Float>.allocate(capacity:)` (which defaults to proper alignment on Apple platforms).
- **Recommendation**: Use vDSP for N=64 operations in the voice mixer and output stage. The per-operator kernel (inner loop of 1 sample) should remain scalar/inline -- vDSP overhead dominates at N=1.

### 2.3 `vDSP_desamp` for 2x Oversampling

**Configuration for 2x decimation**:
- Decimation factor (stride): 2
- Filter: Half-band FIR anti-aliasing filter
- Recommended filter length: 17 taps (good tradeoff between stopband attenuation and latency)
- Coefficients: Design using `vDSP_hamm_window` or pre-computed half-band coefficients with equiripple design
- Input length: 2 * N (128 samples for N=64 output)
- Output length: N (64 samples)

**Half-band filter property**: Every other coefficient is zero (except center tap), enabling efficient computation. `vDSP_desamp` handles this transparently.

### 2.4 Swift-Friendly vs C-Style API

Two API styles are available:
1. **C-style** (`vDSP_vsma`, pointer-based): Zero overhead, no temporary Array allocation. **Use this on the render thread.**
2. **Swift-style** (`vDSP.multiply(addition:)`, Array-based): Convenient but may allocate. **Avoid on the render thread.**

**Recommendation**: Use C-style `UnsafePointer`-based vDSP APIs exclusively on the audio render thread. Pre-allocate all scratch buffers at engine initialization.

---

## 3. DX7 OPS (YM21280) Hardware Specifications

### 3.1 Architecture Overview

| Parameter | Value |
|-----------|-------|
| Chip | YM21280 (OPS) + YM21290 (EGS) |
| Operators per voice | 6 |
| Polyphony | 16 voices |
| Sample rate | 49,096 Hz (derived from 9.4265 MHz / 192) |
| Processing time per voice | ~20.368 us |
| Algorithms | 32 |
| Arithmetic domain | Logarithmic (addition replaces multiplication) |

### 3.2 Sin Table (Log-Sine ROM)

| Parameter | Value |
|-----------|-------|
| Table entries | 1024 (quarter-wave, symmetry exploited) |
| Full period | 4096 samples |
| Output width | 14 bits (13-bit absolute + delta encoding) |
| Format | -log2(sin(w)) where w = (n + 0.5) / 1024 * pi/2 |
| Precision | round(y * 1024) for Q10 representation |
| ROM compression | Delta encoding, 5344 bits actual (63% reduction from 14K bits) |
| Storage | Every 4th value stored as 13-bit "absolute"; 3 intermediate values as deltas |

**Mathematical definition for independent implementation**:
```
For input n (0..1023):
  angle = (n + 0.5) / 1024 * pi / 2
  output = round(-log2(sin(angle)) * 1024)
```

### 3.3 Exp2 Table (Exponential ROM)

| Parameter | Value |
|-----------|-------|
| Table entries | 1024 (10-bit address) |
| Input format | 14-bit: 4-bit integer + 10-bit fraction |
| Output | 11-bit mantissa + leading 1 bit = 12 bits, then shifted by integer part |
| Frequency path | `round(2^frac * 2048) << int >> 5` (22-bit output) |
| Signal path | `round(2^frac * 2048) << int >> 13` (14-bit output) |
| ROM compression | Delta encoding (64% size reduction) |

**Mathematical definition for independent implementation**:
```
For input x (14-bit, 4-bit integer + 10-bit fraction):
  frac = (x & 0x3FF) / 1024.0
  int_part = x >> 10
  mantissa = round(2^frac * 2048)  // 11-bit + implicit leading 1
  result = (mantissa | 0x800) << int_part
```

### 3.4 Algorithm Routing (32 Algorithms)

**ROM structure**: 192 x 9 bits (32 algorithms x 6 operators x 9 control bits)

**9-bit control word per operator**:
- Bits [2:0] SEL (3 bits): Modulation source selector (0=none, 1=raw, 2=summed, 3=delayed, 4=delayed feedback, 5=averaged feedback)
- Bits [4:3] MREN (2 bits): Memory register enable (C, D lines for hold/load/add)
- Bit [5] FREN (1 bit): Feedback register enable
- Bits [8:6] COM (3 bits): Compensation scaling value

**Processing order**: Operators 6 -> 5 -> 4 -> 3 -> 2 -> 1 (reverse order, hardware pipeline constraint).

**Feedback**: Every algorithm has exactly one feedback loop. Only algorithms 4 and 6 have multi-operator feedback (cross-operator feedback). All others have self-feedback on one operator.

### 3.5 Envelope Generator

| Parameter | Value |
|-----------|-------|
| Stages | 4 rates + 4 levels (effectively 5-segment ADSR variant) |
| Amplitude resolution | 12 bits (~0.0235 dB per step) |
| Dynamic range | ~96 dB |
| Gain formula | Linear gain = 2^(value / 256) |

**Rate conversion**: `qrate = (rate * 41) / 64` (patch rate 0-99 -> 6-bit quantized rate 0-63)

**Decay rate**: `0.2819 * 2^(qrate/4) * (1 + 0.25 * (qrate % 4))` dB/s

**Attack behavior**: Non-exponential. Multiplies decay rate by factor `2 + floor((full_scale - current_level) / 256)`. Amplitude immediately jumps to 39.98 dB above minimum for crisp onset.

**Level scaling**: For level values 20-99: `28 + level`. Total level = `64 * actual_level + 32 * output_level`.

### 3.6 Feedback Implementation

- Stores previous two output samples per feedback operator.
- Feedback value = average of previous two samples: `(sample[n-1] + sample[n-2]) / 2`.
- This averaging acts as a 1st-order low-pass filter (anti-hunting filter) preventing oscillation instability.
- Feedback amount controlled by FBL (Feedback Level) signal: bit-shifting of averaged value.

### 3.7 Sources (Public Information)

All specifications are derived from publicly available sources:
- Ken Shirriff's reverse-engineering blog series (righto.com, 2021-2022): Die photos and ROM extraction of YM21280
- Yamaha DX7 service manual (publicly available)
- Yamaha patents (expired)
- ajxs.me DX7 Technical Analysis
- Google music-synthesizer-for-android wiki (Dx7Envelope, Dx7Hardware)

---

## 4. MIDI 2.0 / UMP (Universal MIDI Packet)

### 4.1 CoreMIDI MIDI 2.0 Support

| Feature | iOS Version | macOS Version | API |
|---------|-------------|---------------|-----|
| MIDIEventList / UMP | iOS 15+ | macOS 12+ | `MIDIInputPortCreateWithProtocol` |
| MIDI 2.0 protocol selection | iOS 18+ | macOS 14+ | Protocol negotiation |
| MIDIUniversalMessage parsing | iOS 15+ | macOS 12+ | `MIDIEventListForEachEvent` |

**Key API**: `MIDIInputPortCreateWithProtocol(.midi2_0)` creates a MIDI 2.0 port that receives `MIDIEventList` with UMP format.

**Event iteration**: Use `MIDIEventListForEachEvent` with a C callback to iterate UMP events. Swift wrapper needed to bridge `@convention(c)` limitation (cannot capture context directly).

### 4.2 MIDI 2.0 Message Types for M2DX-Core

| Message Type | UMP Size | Key Data |
|-------------|----------|----------|
| Note On (Channel Voice 2) | 64 bits | 16-bit velocity, attribute type |
| Note Off (Channel Voice 2) | 64 bits | 16-bit velocity |
| Per-Note Pitch Bend | 64 bits | 32-bit pitch bend per note |
| Per-Note CC | 64 bits | Index + 32-bit value |
| Registered Per-Note Controller | 64 bits | Index + 32-bit value |
| Channel Pitch Bend | 64 bits | 32-bit value (vs 14-bit MIDI 1.0) |
| Channel CC | 64 bits | 32-bit value |

### 4.3 Library Selection for MIDI 2.0

| Library | Version | License | MIDI-CI | Property Exchange | Per-Note CC | Swift 6 |
|---------|---------|---------|---------|-------------------|-------------|---------|
| **CoreMIDI (native)** | System | Apple | Partial | No | Yes (UMP) | Yes |
| **MIDIKit** | 0.11.0 | MIT | No | No | Yes | Yes (6.0) |
| **MIDI2Kit** | 1.0.5 | MIT | Yes | Yes (async/await) | UMP level | Unknown |

**Recommendation for Phase 2**: Use **CoreMIDI directly** for UMP parsing and MIDI I/O.

Rationale:
- M2DX-Core is a low-level synthesis library. It should receive parsed note/CC events, not manage MIDI ports.
- The library's public API should accept `NoteEvent` / `ControlChange` value types, not raw UMP.
- MIDI port management and Property Exchange belong in the host application (M2DX app), not the synthesis library.
- For the M2DX app layer, **MIDI2Kit** (1.0.5) is recommended for Property Exchange and MIDI-CI device discovery if those features are needed.

**Phase 2 Scope**: Define a protocol-agnostic `NoteEvent` type with 16-bit velocity and 32-bit CC resolution. The host application converts UMP -> NoteEvent before passing to the engine.

### 4.4 Per-Note Controller Integration for MPE

M2DX-Core voice architecture already supports per-voice parameters. MPE mapping:
- Per-Note Pitch Bend -> Voice pitch offset
- Per-Note CC 74 (Timbre/Brightness) -> Per-voice filter or modulation index adjustment
- Channel Pressure / Per-Note Aftertouch -> Per-voice amplitude or modulation modulation

---

## 5. Swift Package Manager Configuration

### 5.1 Recommended Package.swift Structure

**swift-tools-version**: 6.0 (matches M2DX app, supports Swift 6 language mode)

**Platform targets**:
- `.iOS(.v18)` -- required for Synchronization module and latest CoreMIDI
- `.macOS(.v15)` -- Synchronization module requires macOS 15 (Sequoia), NOT macOS 14

**IMPORTANT**: The proposal states macOS 14+ but `Synchronization` module requires macOS 15+. Either:
  - (a) Raise minimum to macOS 15, or
  - (b) Keep macOS 14 and use `swift-atomics` package instead of `Synchronization`

### 5.2 Accelerate Framework Linking

Accelerate is a system framework. In SPM, link it using `linkerSettings`:

```swift
.target(
    name: "M2DXCore",
    linkerSettings: [
        .linkedFramework("Accelerate"),
    ]
)
```

**Note**: `import Accelerate` works without explicit linking in most cases because Accelerate is auto-linked on Apple platforms. The explicit `linkedFramework` declaration is defensive and documents the dependency.

### 5.3 swift-atomics Dependency (if used)

```swift
.package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
```

- Version constraint `from: "1.2.0"` is correct. Latest release is 1.3.0 (June 2024).
- 1.3.0 bumped minimum toolchain to Swift 5.10 and fixed LTO miscompilation. No breaking API changes.
- No need to pin to 1.3.0 specifically; SemVer resolution will pick it up.

### 5.4 Recommended Target Layout

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "M2DX-Core",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),   // or .v14 if using swift-atomics
    ],
    products: [
        .library(name: "M2DXCore", targets: ["M2DXCore"]),
    ],
    dependencies: [
        // Only needed if targeting macOS 14 (no Synchronization module)
        // .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "M2DXCore",
            dependencies: [
                // .product(name: "Atomics", package: "swift-atomics"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),
        .testTarget(
            name: "M2DXCoreTests",
            dependencies: ["M2DXCore"]
        ),
    ]
)
```

### 5.5 No Additional External Dependencies

Per the proposal, M2DX-Core should have minimal dependencies:
- **Accelerate**: System framework (no package dependency)
- **swift-atomics**: Only if macOS 14 support is required; otherwise use stdlib `Synchronization`
- No other external packages

---

## 6. Summary of Recommendations

### Critical Decisions Required

| Decision | Option A (Recommended) | Option B (Fallback) |
|----------|----------------------|---------------------|
| Atomics | `Synchronization.Atomic` (stdlib) | `swift-atomics` 1.3.0 |
| macOS minimum | macOS 15 (enables stdlib Atomic) | macOS 14 (requires swift-atomics) |
| MIDI 2.0 in library | Protocol-agnostic `NoteEvent` type | Direct UMP parsing |
| vDSP API style | C-style pointer API on render thread | Swift Array API (avoid on RT) |
| Sine/Exp2 tables | Self-generated from `Darwin.sin()` / `Darwin.exp2()` | -- |

### Technology Stack Summary

| Component | Selection | Version | Rationale |
|-----------|-----------|---------|-----------|
| Language | Swift 6 | 6.0+ | Strict concurrency, ownership model |
| Atomics | `Synchronization.Atomic` or `swift-atomics` | stdlib / 1.3.0 | Lock-free SPSC ring buffer |
| DSP | Apple Accelerate (vDSP) | System | NEON-optimized batch operations |
| MIDI | CoreMIDI (direct) | System | UMP/MIDI 2.0 native support |
| MIDI 2.0 App Layer | MIDI2Kit (for host app) | 1.0.5 | Property Exchange, MIDI-CI |
| Package Manager | SPM | swift-tools-version 6.0 | Native Swift ecosystem |
| Testing | XCTest + Swift Testing | Built-in | Waveform regression, concurrency stress |

### Per-Domain Implementation Notes

1. **Swift 6 Concurrency**: Use `nonisolated` for all render-path methods. Use `nonisolated(unsafe)` for immutable global LUTs. Avoid `async`/`await` on the audio thread entirely.

2. **Accelerate vDSP**: Use C-style API with pre-allocated `UnsafeMutablePointer<Float>` buffers. Apply to voice mixing (`vDSP_vsma`), output gain (`vDSP_vmul`), clipping (`vDSP_vclip`), and downsampling (`vDSP_desamp`). Not for per-sample operator kernel.

3. **DX7 OPS Tables**: Generate all tables from mathematical definitions at compile time or initialization. Sin table: `-log2(sin((n+0.5)/1024 * pi/2)) * 1024`. Exp2 table: `round(2^(frac) * 2048)` with shift. No dependency on msfa/Dexed table data.

4. **MIDI 2.0**: Library accepts `NoteEvent` value type with 16-bit velocity, 32-bit CC. Host app handles CoreMIDI port management and UMP->NoteEvent conversion.

5. **SPM**: Single library target `M2DXCore` with Accelerate linked. Test target `M2DXCoreTests`. Minimal or zero external dependencies.

---

## References

- [apple/swift-atomics GitHub](https://github.com/apple/swift-atomics) -- Latest: 1.3.0 (June 2024)
- [SE-0410: Low-Level Atomic Operations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0410-atomics.md) -- Synchronization module in Swift 6.0
- [Ken Shirriff: DX7 Log-Sine ROM](http://www.righto.com/2021/12/yamaha-dx7-reverse-engineering-part-iii.html)
- [Ken Shirriff: DX7 Exponential Circuit](http://www.righto.com/2021/11/reverse-engineering-yamaha-dx7_28.html)
- [Ken Shirriff: DX7 Algorithm Implementation](http://www.righto.com/2021/12/yamaha-dx7-chip-reverse-engineering.html)
- [ajxs.me: Yamaha DX7 Technical Analysis](https://ajxs.me/blog/Yamaha_DX7_Technical_Analysis.html)
- [Google msfa wiki: DX7 Envelope](https://github.com/google/music-synthesizer-for-android/blob/master/wiki/Dx7Envelope.wiki)
- [Apple vDSP Documentation](https://developer.apple.com/documentation/accelerate/vdsp)
- [Apple CoreMIDI MIDI 2.0](https://developer.apple.com/documentation/coremidi/incorporating-midi-2-into-your-apps)
- [MIDI2Kit SDK](https://midi2kit.dev/)
- [MIDIKit](https://github.com/orchetect/MIDIKit) -- v0.11.0
- [Swift 6.2 Concurrency Changes (Donny Wals)](https://www.donnywals.com/exploring-concurrency-changes-in-swift-6-2/)
- [Synchronization Framework in Swift 6 (Jacob's Tech Tavern)](https://blog.jacobstechtavern.com/p/the-synchronisation-framework)
- [Furnace Creek: Modern CoreMIDI Event Handling](https://furnacecreek.org/blog/2024-04-06-modern-coremidi-event-handling-with-swift)
