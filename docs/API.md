# M2DX-Core API Reference

Public API reference for the M2DX-Core DX7 FM synthesis engine library.

**Platform:** macOS 15+ / iOS 18+
**Swift:** 6.0+
**Dependencies:** Accelerate, Synchronization

---

## Table of Contents

- [SynthEngine](#synthengine) — Core synthesis engine
- [Parameter Types](#parameter-types) — Snapshot structures for parameter transfer
- [MIDI](#midi) — MIDI event handling
- [Preset](#preset) — DX7 preset data model
- [SysEx](#sysex) — DX7 SysEx parser
- [Algorithms](#algorithms) — DX7 algorithm definitions
- [Factory Presets](#factory-presets) — Built-in presets

---

## SynthEngine

```swift
public final class SynthEngine: @unchecked Sendable
```

DX7 FM synthesis engine with lock-free UI → audio thread parameter transfer.

**Thread safety:** UI thread writes parameters via setter methods; audio thread reads via `render()`. No locks on the render path — all cross-thread communication uses atomic SPSC ring buffers.

### Initialization

```swift
public init()
```

### Audio Rendering

```swift
public func render(
    into bufferL: UnsafeMutablePointer<Float>,
    bufferR: UnsafeMutablePointer<Float>,
    frameCount: Int
)
```

Render audio frames into stereo buffers. Call from the audio thread only.

- `bufferL` / `bufferR`: Pre-allocated output buffers (must be ≥ `frameCount`)
- `frameCount`: Number of frames to render
- Output is hard-clipped to [-1.0, 1.0]

### MIDI

```swift
public func sendMIDI(_ event: MIDIEvent)
```

Enqueue a MIDI event from the UI thread. Lock-free, allocation-free.

### Global Parameters

| Method | Range | Description |
|--------|-------|-------------|
| `setSampleRate(_ sr: Float)` | > 0 | Audio sample rate in Hz |
| `setMasterVolume(_ vol: Float)` | 0.0–1.0 | Master output volume |
| `setMasterTuning(_ cents: Int16)` | -100–100 | Master fine tuning in cents |
| `setAlgorithm(_ alg: Int)` | 0–31 | FM algorithm (0-indexed) |
| `setOversamplingMode(_ mode: OversamplingMode)` | — | Oversampling quality |

### Operator Parameters (DX7 Native Range)

All operator methods take `opIndex: Int` (0–5, maps to OP6–OP1 in DX7 convention).

| Method | Range | Description |
|--------|-------|-------------|
| `setOperatorDX7OutputLevel(_ opIndex:, level:)` | 0–99 | DX7 output level |
| `setOperatorDX7EGRates(_ opIndex:, r1:, r2:, r3:, r4:)` | 0–99 each | EG rate 1–4 |
| `setOperatorDX7EGLevels(_ opIndex:, l1:, l2:, l3:, l4:)` | 0–99 each | EG level 1–4 |
| `setOperatorRatio(_ opIndex:, ratio:)` | > 0 | Frequency ratio |
| `setOperatorDetune(_ opIndex:, cents:)` | Float | Detune in cents |
| `setOperatorFeedback(_ fb:)` | 0–7 | Feedback (OP1/slot 0 only) |

### Operator Extended Parameters

| Method | Range | Description |
|--------|-------|-------------|
| `setOperatorVelocitySensitivity(_ opIndex:, value:)` | 0–7 | Velocity sensitivity |
| `setOperatorAmpModSensitivity(_ opIndex:, value:)` | 0–3 | Amp mod sensitivity |
| `setOperatorKeyboardRateScaling(_ opIndex:, value:)` | 0–7 | Keyboard rate scaling |
| `setOperatorKLS(_ opIndex:, breakPoint:, leftDepth:, rightDepth:, leftCurve:, rightCurve:)` | 0–99/0–3 | Keyboard level scaling |
| `setOperatorFixedFrequency(_ opIndex:, enabled:, coarse:, fine:)` | 0–1/0–31/0–99 | Fixed frequency mode |

### Normalized Operator Parameters

| Method | Range | Description |
|--------|-------|-------------|
| `setOperatorLevel(_ opIndex:, level:)` | 0.0–1.0 | Normalized output level |
| `setOperatorEGRates(_ opIndex:, r1:, r2:, r3:, r4:)` | Float | EG rates (normalized) |
| `setOperatorEGLevels(_ opIndex:, l1:, l2:, l3:, l4:)` | Float | EG levels (normalized) |
| `setOperatorFeedback(_ opIndex:, feedback:)` | 0.0–1.0 | Per-operator feedback |
| `setOperatorWaveform(_ opIndex:, waveform:)` | UInt8 | Operator waveform |

### LFO Parameters

| Method | Range | Description |
|--------|-------|-------------|
| `setLFOSpeed(_ value:)` | 0–99 | LFO speed |
| `setLFODelay(_ value:)` | 0–99 | LFO delay |
| `setLFOPMD(_ value:)` | 0–99 | Pitch modulation depth |
| `setLFOAMD(_ value:)` | 0–99 | Amplitude modulation depth |
| `setLFOSync(_ value:)` | 0–1 | LFO key sync |
| `setLFOWaveform(_ value:)` | 0–5 | LFO waveform (tri/saw↓/saw↑/square/sin/S&H) |
| `setLFOPMS(_ value:)` | 0–7 | Pitch modulation sensitivity |

### Pitch Parameters

| Method | Range | Description |
|--------|-------|-------------|
| `setTranspose(_ value:)` | -24–24 | Transpose in semitones |
| `setPitchBendRange(_ value:)` | 1–12 | Pitch bend range in semitones |
| `setPitchEGRates(_ r0:, _ r1:, _ r2:, _ r3:)` | 0–99 | Pitch EG rates |
| `setPitchEGLevels(_ l0:, _ l1:, _ l2:, _ l3:)` | 0–99 | Pitch EG levels |

### Controller Mapping

| Method | Range | Description |
|--------|-------|-------------|
| `setWheelPitch(_ v:)` | 0–99 | Mod wheel → pitch depth |
| `setWheelAmp(_ v:)` | 0–99 | Mod wheel → amplitude depth |
| `setWheelEGBias(_ v:)` | 0–99 | Mod wheel → EG bias depth |
| `setFootPitch(_ v:)` | 0–99 | Foot controller → pitch |
| `setFootAmp(_ v:)` | 0–99 | Foot controller → amplitude |
| `setFootEGBias(_ v:)` | 0–99 | Foot controller → EG bias |
| `setBreathPitch(_ v:)` | 0–99 | Breath controller → pitch |
| `setBreathAmp(_ v:)` | 0–99 | Breath controller → amplitude |
| `setBreathEGBias(_ v:)` | 0–99 | Breath controller → EG bias |
| `setAftertouchPitch(_ v:)` | 0–99 | Aftertouch → pitch |
| `setAftertouchAmp(_ v:)` | 0–99 | Aftertouch → amplitude |
| `setAftertouchEGBias(_ v:)` | 0–99 | Aftertouch → EG bias |

### Multi-Timbral

| Method | Description |
|--------|-------------|
| `setTimbreMode(_ mode: TimbreMode, splitPoint: UInt8 = 60)` | Set multi-timbral mode |
| `setSplitPoint(_ note: UInt8)` | Set keyboard split point (MIDI note) |
| `setSlotEnabled(_ slotIdx: Int, enabled: Bool)` | Enable/disable a slot |
| `loadSlotParams(_ slotIdx: Int, slot: SlotSnapshot)` | Load full slot parameters |

---

## Parameter Types

### TimbreMode

```swift
public enum TimbreMode: UInt8, Sendable, CaseIterable
```

| Case | Value | Slot Count | Description |
|------|-------|------------|-------------|
| `.single` | 0 | 1 | Single timbre, 16 voices |
| `.dual` | 1 | 2 | Dual layer, 32 voices |
| `.split` | 2 | 2 | Keyboard split, 32 voices |
| `.tx816` | 3 | 8 | TX816 mode, 64 voices |

**Property:** `var slotCount: Int` — Number of active slots for this mode.

### OversamplingMode

```swift
public enum OversamplingMode: UInt8, Sendable, CaseIterable
```

| Case | Value | Description |
|------|-------|-------------|
| `.off` | 0 | No oversampling |
| `.highQuality` | 1 | 2× with halfband downsampler |
| `.lowCPU` | 2 | 2× with polyphase downsampler |

### OperatorSnapshot

```swift
public struct OperatorSnapshot: Sendable
```

Per-operator parameter snapshot. All fields have sensible defaults via `init()`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `level` | Float | 1.0 | Normalized level (0.0–1.0) |
| `ratio` | Float | 1.0 | Frequency ratio |
| `detune` | Float | 1.0 | Detune multiplier |
| `feedback` | Float | 0.0 | Feedback amount (0.0–1.0) |
| `egR0`–`egR3` | Float | 99/75/50/50 | EG rates |
| `egL0`–`egL3` | Float | 1.0/0.8/0.7/0.0 | EG levels |
| `dx7OutputLevel` | Int | 99 | DX7 native output level (0–99) |
| `dx7EgR0`–`dx7EgR3` | Int | 99/75/50/50 | DX7 native EG rates |
| `dx7EgL0`–`dx7EgL3` | Int | 99/80/70/0 | DX7 native EG levels |
| `velocitySensitivity` | UInt8 | 0 | Velocity sensitivity (0–7) |
| `ampModSensitivity` | UInt8 | 0 | Amp mod sensitivity (0–3) |
| `keyboardRateScaling` | UInt8 | 0 | KRS (0–7) |
| `klsBreakPoint` | UInt8 | 39 | KLS break point (0–99) |
| `klsLeftDepth` | UInt8 | 0 | KLS left depth (0–99) |
| `klsRightDepth` | UInt8 | 0 | KLS right depth (0–99) |
| `klsLeftCurve` | UInt8 | 0 | KLS left curve (0–3) |
| `klsRightCurve` | UInt8 | 0 | KLS right curve (0–3) |
| `fixedFrequency` | UInt8 | 0 | Fixed frequency mode (0–1) |
| `fixedFreqCoarse` | UInt8 | 1 | Fixed freq coarse (0–31) |
| `fixedFreqFine` | UInt8 | 0 | Fixed freq fine (0–99) |

### SlotSnapshot

```swift
public struct SlotSnapshot: Sendable
```

Per-slot parameter snapshot containing 6 operators and slot-specific settings.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ops` | (OperatorSnapshot ×6) | — | 6 operator snapshots |
| `algorithm` | Int | 0 | Algorithm index (0–31) |
| `lfoSpeed` | UInt8 | 35 | LFO speed (0–99) |
| `lfoDelay` | UInt8 | 0 | LFO delay (0–99) |
| `lfoPMD` | UInt8 | 0 | Pitch mod depth (0–99) |
| `lfoAMD` | UInt8 | 0 | Amp mod depth (0–99) |
| `lfoSync` | UInt8 | 1 | LFO key sync (0–1) |
| `lfoWaveform` | UInt8 | 0 | LFO waveform (0–5) |
| `lfoPMS` | UInt8 | 3 | Pitch mod sensitivity (0–7) |
| `pitchEGR0`–`pitchEGR3` | UInt8 | 99 | Pitch EG rates |
| `pitchEGL0`–`pitchEGL3` | UInt8 | 50 | Pitch EG levels |
| `transpose` | Int8 | 0 | Transpose (-24–24) |
| `pitchBendRange` | UInt8 | 2 | Pitch bend range (1–12) |
| `wheelPitch/Amp/EGBias` | UInt8 | 50/0/0 | Mod wheel mapping |
| `footPitch/Amp/EGBias` | UInt8 | 0/0/0 | Foot controller mapping |
| `breathPitch/Amp/EGBias` | UInt8 | 0/0/0 | Breath controller mapping |
| `aftertouchPitch/Amp/EGBias` | UInt8 | 0/0/0 | Aftertouch mapping |

### SlotConfig

```swift
public struct SlotConfig: Sendable
```

Configuration for a timbre slot (voice allocation and MIDI routing).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `voiceStart` | Int | 0 | First voice index |
| `voiceCount` | Int | 16 | Number of voices |
| `noteRangeLow` | UInt8 | 0 | Lowest MIDI note |
| `noteRangeHigh` | UInt8 | 127 | Highest MIDI note |
| `midiChannel` | UInt8 | 0 | MIDI channel (TX816 mode) |
| `enabled` | Bool | true | Slot enabled |

### SynthParamSnapshot

```swift
public struct SynthParamSnapshot: Sendable
```

Complete parameter snapshot for atomic UI → audio thread transfer. Uses fixed-size tuples (no heap allocation).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `timbreMode` | UInt8 | 0 | Timbre mode raw value |
| `splitPoint` | UInt8 | 60 | Split point (MIDI note) |
| `activeSlotCount` | Int | 1 | Number of active slots |
| `slots` | (SlotSnapshot ×8) | — | 8 slot snapshots (fixed-size) |
| `slotConfigs` | (SlotConfig ×8) | — | 8 slot configs (fixed-size) |
| `masterVolume` | Float | 0.7 | Master volume |
| `sampleRate` | Float | 44100 | Sample rate |
| `version` | UInt64 | 0 | Snapshot version counter |
| `oversamplingMode` | UInt8 | 0 | Oversampling mode raw value |
| `masterTuning` | Int16 | 0 | Master tuning in cents |

**Subscript Helpers:**

```swift
func slot(at i: Int) -> SlotSnapshot
mutating func setSlot(at i: Int, _ value: SlotSnapshot)
func config(at i: Int) -> SlotConfig
mutating func setConfig(at i: Int, _ value: SlotConfig)
```

**Slot 0 Convenience Accessors:** `ops`, `algorithm`, `lfoSpeed`, `lfoDelay`, `lfoPMD`, `lfoAMD`, `lfoSync`, `lfoWaveform`, `lfoPMS`, `transpose`, `pitchBendRange` — read/write directly to slot 0.

### Constants

```swift
public let kMaxSlots = 8
```

---

## MIDI

### MIDIEvent

```swift
public struct MIDIEvent: Sendable
```

MIDI event for lock-free queue transfer.

| Property | Type | Description |
|----------|------|-------------|
| `kind` | `Kind` | Event type |
| `data1` | UInt8 | Note number or CC number |
| `data2` | UInt32 | See per-event format below |

```swift
public init(kind: Kind, data1: UInt8, data2: UInt32)
```

### MIDIEvent.Kind

```swift
public enum Kind: UInt8, Sendable
```

| Case | data1 | data2 | Description |
|------|-------|-------|-------------|
| `.noteOn` | Note (0–127) | Velocity16 (see below) | Note On. velocity=0 treated as Note Off |
| `.noteOff` | Note (0–127) | unused | Note Off |
| `.controlChange` | CC# | 0–UInt32.max | Controller value (full 32-bit range) |
| `.pitchBend` | unused | 0x00000000–0xFFFFFFFF | Center = 0x80000000 |

**Velocity format (MIDI 2.0 style):** `data2` uses a 16-bit velocity in the low word. Standard 7-bit MIDI velocity must be left-shifted: `UInt32(velocity7) << 9`. For example, velocity 127 → `0xFE00`. A `data2` value of `0` is treated as Note Off.

**Supported CC numbers:**

| CC | Description |
|----|-------------|
| 1 | Mod Wheel |
| 2 | Breath Controller |
| 4 | Foot Controller |
| 7 | Volume |
| 11 | Expression |
| 64 | Sustain Pedal (≥ 0x40000000 = on) |
| 123 | All Notes Off |

---

## Preset

### DX7Preset

```swift
public struct DX7Preset: Codable, Sendable, Identifiable, Equatable
```

Complete DX7 voice preset (JSON serializable).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | UUID | auto | Unique identifier |
| `name` | String | — | Preset name |
| `algorithm` | Int | — | Algorithm (0–31, 0-indexed) |
| `feedback` | Int | — | Feedback level (0–7) |
| `operators` | [DX7OperatorPreset] | — | 6 operator presets |
| `category` | PresetCategory | — | Preset category |
| `lfoSpeed` | Int | 35 | LFO speed (0–99) |
| `lfoDelay` | Int | 0 | LFO delay (0–99) |
| `lfoPMD` | Int | 0 | Pitch mod depth |
| `lfoAMD` | Int | 0 | Amp mod depth |
| `lfoSync` | Int | 1 | LFO key sync |
| `lfoWaveform` | Int | 0 | LFO waveform |
| `lfoPMS` | Int | 3 | Pitch mod sensitivity |
| `pitchEGR1`–`pitchEGR4` | Int | 99 | Pitch EG rates |
| `pitchEGL1`–`pitchEGL4` | Int | 50 | Pitch EG levels |
| `transpose` | Int | 0 | Transpose |

**Computed Property:** `normalizedFeedback: Float` — Feedback normalized to 0.0–1.0.

### DX7OperatorPreset

```swift
public struct DX7OperatorPreset: Codable, Sendable, Equatable
```

Single operator preset data (DX7 native parameter format).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `outputLevel` | Int | 99 | Output level (0–99) |
| `frequencyCoarse` | Int | 1 | Frequency coarse (0–31) |
| `frequencyFine` | Int | 0 | Frequency fine (0–99) |
| `detune` | Int | 7 | Detune (0–14, 7=center) |
| `feedback` | Int | 0 | Feedback (0–7) |
| `egRate1`–`egRate4` | Int | 99/99/99/99 | EG rates |
| `egLevel1`–`egLevel4` | Int | 99/99/99/0 | EG levels |
| `velocitySensitivity` | Int | 0 | Velocity sensitivity (0–7) |
| `ampModSensitivity` | Int | 0 | Amp mod sensitivity (0–3) |
| `keyboardRateScaling` | Int | 0 | KRS (0–7) |
| `klsBreakPoint` | Int | 39 | KLS break point |
| `klsLeftDepth` | Int | 0 | KLS left depth |
| `klsRightDepth` | Int | 0 | KLS right depth |
| `klsLeftCurve` | Int | 0 | KLS left curve (0–3) |
| `klsRightCurve` | Int | 0 | KLS right curve (0–3) |
| `frequencyMode` | Int | 0 | 0=ratio, 1=fixed |
| `waveform` | Int | 0 | Waveform type |

**Computed Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `frequencyRatio` | Float | Coarse × (1 + fine/100) |
| `detuneCents` | Float | Detune in cents (detune - 7) |
| `normalizedLevel` | Float | Output level / 99 |
| `normalizedFeedback` | Float | Feedback / 7 |
| `egRatesDX7` | (Float ×4) | EG rates as Float tuple |
| `egLevelsNormalized` | (Float ×4) | EG levels normalized 0.0–1.0 |

### PresetCategory

```swift
public enum PresetCategory: String, Codable, CaseIterable, Sendable
```

Cases: `keys`, `bass`, `brass`, `strings`, `organ`, `percussion`, `woodwind`, `other`

---

## SysEx

### DX7SysExParser

```swift
public enum DX7SysExParser
```

Parses DX7 32-voice bulk dump SysEx files (.syx, 4104 bytes).

```swift
static func parse(url: URL, bankName: String, category: PresetCategory = .other) -> DX7SysExBank?
static func parse(data: Data, bankName: String, category: PresetCategory = .other) -> DX7SysExBank?
```

### DX7SysExBank

```swift
public struct DX7SysExBank: Sendable
```

| Property | Type | Description |
|----------|------|-------------|
| `name` | String | Bank name |
| `presets` | [DX7Preset] | 32 parsed presets |

---

## Algorithms

### DX7Algorithms

```swift
public enum DX7Algorithms
```

Complete set of 32 DX7 algorithm definitions.

```swift
static let all: [DX7AlgorithmDefinition]                      // All 32 algorithms (indexed 0–31)
static func definition(for number: Int) -> DX7AlgorithmDefinition?  // Lookup by number (1–32, DX7 convention)
```

> **Note:** `DX7AlgorithmDefinition.number` uses 1-based DX7 convention (1–32), while `SynthEngine.setAlgorithm()` and `DX7Preset.algorithm` use 0-based indexing (0–31).

### DX7AlgorithmDefinition

```swift
public struct DX7AlgorithmDefinition: Sendable, Equatable, Identifiable
```

| Property | Type | Description |
|----------|------|-------------|
| `number` | Int | Algorithm number (1–32) |
| `carriers` | [Int] | Carrier operator indices (1–6) |
| `connections` | [AlgorithmConnection] | Modulation connections |
| `feedbackOp` | Int | Feedback operator (1–6) |

### AlgorithmConnection

```swift
public struct AlgorithmConnection: Sendable, Equatable
```

| Property | Type | Description |
|----------|------|-------------|
| `from` | Int | Source (modulator) operator (1–6) |
| `to` | Int | Destination (carrier) operator (1–6) |

---

## Factory Presets

### DX7FactoryPresets

```swift
public enum DX7FactoryPresets
```

| Property | Type | Description |
|----------|------|-------------|
| `initVoice` | DX7Preset | Default init voice |
| `all` | [DX7Preset] | All factory presets |
| `factoryROMs` | [DX7Preset] | Factory ROM presets |
| `banks` | [DX7SysExBank] | Presets organized by bank |

---

## Usage Example

```swift
import M2DXCore

// Create engine
let engine = SynthEngine()
engine.setSampleRate(44100)
engine.setAlgorithm(0)
engine.setMasterVolume(0.7)

// Configure operators
for i in 0..<6 {
    engine.setOperatorDX7OutputLevel(i, level: 99)
    engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
    engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
    engine.setOperatorRatio(i, ratio: 1.0)
}

// Send MIDI (velocity 127 → left-shift by 9 → 0xFE00)
engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(127) << 9))

// Render audio (audio thread)
let frameCount = 512
let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
bufL.initialize(repeating: 0, count: frameCount)
bufR.initialize(repeating: 0, count: frameCount)
engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)

// Load a preset (algorithm is already 0-indexed)
let preset = DX7FactoryPresets.initVoice
engine.setAlgorithm(preset.algorithm)

// Parse SysEx bank
if let bank = DX7SysExParser.parse(url: sysExURL, bankName: "ROM1A") {
    print("Loaded \(bank.presets.count) presets")
}
```
