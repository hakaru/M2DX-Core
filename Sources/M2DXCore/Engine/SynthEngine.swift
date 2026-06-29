// SynthEngine.swift
// M2DX-Core — DX7 FM Synthesis Engine (voice management, render, MIDI)

import Darwin
import Synchronization

// MARK: - Oversampling Mode

public enum OversamplingMode: UInt8, Sendable, CaseIterable {
    case off = 0
    case highQuality = 1
    case lowCPU = 2
}

// MARK: - FM Engine

public enum FMEngine: UInt8, Sendable, CaseIterable {
    case modern = 0
    case markI  = 1

    public var displayName: String {
        switch self {
        case .modern: return "Modern"
        case .markI:  return "Mark I"
        }
    }

    /// True for the Mark I (OPS) engine; false for Modern.
    public var isMarkI: Bool { self == .markI }
}

// MARK: - MIDI Event

/// MIDI event for lock-free queue transfer
public struct MIDIEvent: Sendable {
    public enum Kind: UInt8, Sendable {
        case noteOn, noteOff, controlChange, pitchBend
        case channelPressure      // data2 = 32-bit pressure value
        case polyPressure         // data1 = note, data2 = 32-bit pressure value
        case perNotePitchBend     // data1 = note, data2 = 32-bit bend value
        case perNoteCC            // data1 = note, data2 = (index << 24) | (value & 0x00FFFFFF)
        case perNoteManagement    // data1 = note, data2 = flags (bit1=Detach, bit0=Reset)
        case registeredController // data1 = bank, data2 = (index << 24) | (value & 0x00FFFFFF)
        case assignableController // data1 = bank, data2 = (index << 24) | (value & 0x00FFFFFF)
    }
    public let kind: Kind
    public let data1: UInt8
    public let data2: UInt32

    public init(kind: Kind, data1: UInt8, data2: UInt32) {
        self.kind = kind; self.data1 = data1; self.data2 = data2
    }
}

// MARK: - SynthEngine

/// DX7 FM synth engine.
///
/// Thread-safety: `@unchecked Sendable` — manually ensured:
/// - UI thread writes `shadowSnapshot` and pushes via lock-free `snapshotRing`.
/// - Audio render thread pops the latest snapshot (consumer-only).
/// - No locks on the render path.
public final class SynthEngine: @unchecked Sendable {

    private struct SlotMod {
        var pmsDepth: Float = 0
        var hasPitchMod: Bool = false
        var wheelPitchDepth: Float = 0
        var footPitchDepth: Float = 0
        var breathPitchDepth: Float = 0
        var atPitchDepth: Float = 0
        var controllerAmpMod: Float = 1.0
        var lfoAMDNorm: Float = 0
    }

    /// SplitMix64 — small, fast, deterministic PRNG used for LFO Sample-and-Hold.
    /// Replaces Float.random so that render output is reproducible given a fixed seed.
    private struct SplitMix64 {
        var state: UInt64

        @inline(__always)
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        /// Returns a Float in [-1, 1) by mapping a 32-bit slice via signed reinterpretation.
        @inline(__always)
        mutating func nextSignedUnit() -> Float {
            let bits = UInt32(truncatingIfNeeded: next())
            return Float(Int32(bitPattern: bits)) / Float(0x80000000)
        }
    }

    private let slotModScratch: UnsafeMutablePointer<SlotMod> = {
        let ptr = UnsafeMutablePointer<SlotMod>.allocate(capacity: kMaxSlots)
        ptr.initialize(repeating: SlotMod(), count: kMaxSlots)
        return ptr
    }()

    private var shadowSnapshot = SynthParamSnapshot()
    private let snapshotRing = SnapshotRing<SynthParamSnapshot>(initial: SynthParamSnapshot())
    private var currentSnapshot = SynthParamSnapshot()
    /// #89-detune: advances once per note-on so random voice-stack detune re-rolls
    /// every note. Audio-thread only (mutated solely inside doNoteOn) → no atomics.
    private var voiceStackNoteOnCounter: UInt64 = 0

    private let downsampler = Downsampler()
    private var currentOversamplingMode: OversamplingMode = .off
    private var currentFMEngine: FMEngine = .modern

    private var baseSampleRate: Float = 44100
    private var appliedVersion: UInt64 = 0

    private let voicesDX7: UnsafeMutablePointer<DX7Voice> = {
        let ptr = UnsafeMutablePointer<DX7Voice>.allocate(capacity: kMaxVoices)
        ptr.initialize(repeating: DX7Voice(), count: kMaxVoices)
        return ptr
    }()

    private var sampleRate: Float = 44100
    private var masterVolume: Float = 0.7
    private var expression: Float = 1.0
    /// CC7 channel volume, kept separate from `masterVolume` (which the snapshot
    /// apply path overwrites) so a MIDI volume setting is not discarded by an
    /// unrelated UI parameter change. Mirrors how `expression` (CC11) is handled.
    private var ccVolume: Float = 1.0
    private var algorithm: Int = 0
    private var sustainPedalOn: Bool = false
    /// Per-slot pitch bend factor. Recomputed by doPitchBend32 using each slot's
    /// own SlotSnapshot.pitchBendRange (or the RPN override if set), so TX816 /
    /// dual / split modes honor per-slot bend range correctly.
    private var pitchBendValueBySlot: [Float] = Array(repeating: 1.0, count: kMaxSlots)
    private var modWheelDepth: Float = 0
    private var footDepth: Float = 0
    private var breathDepth: Float = 0
    private var aftertouchDepth: Float = 0

    // RPN state (audio-local; written by drainMIDI on render thread, never crosses thread boundary)
    private var rpnFineTuningCents: Float = 0
    private var rpnCoarseTuningSemitones: Float = 0
    private var rpnPitchBendRangeOverride: UInt8 = 0  // 0 = no override, else 1-24 takes priority over snapshot

    // LFO state
    private var lfoPhase: [Float] = Array(repeating: 0, count: kMaxSlots)
    private var lfoCurrentValue: [Float] = Array(repeating: 0, count: kMaxSlots)
    private var lfoDelayFadeIn: [Float] = Array(repeating: 0, count: kMaxSlots)
    private var lfoSHValue: [Float] = Array(repeating: 0, count: kMaxSlots)
    /// Per-slot deterministic PRNG for Sample-and-Hold. Seeded at init from a fixed
    /// constant XOR'd with the slot index so every slot has an independent stream
    /// while overall output stays bit-reproducible across runs.
    private var lfoSHPRNG: [SplitMix64] = (0..<kMaxSlots).map {
        SplitMix64(state: 0xA5A5A5A55A5A5A5A &+ UInt64($0))
    }

    private var currentTimbreMode: TimbreMode = .single
    private var effectiveMaxVoices: Int = 16
    private var dx7VoiceStealIdx: Int = 0

    /// #79 portamento: MIDI note of the most recent note-on, the glide START
    /// reference for the next note. Updated on EVERY note-on (even when off) so
    /// enabling mid-phrase glides from the right note. nil until the first note.
    private var previousNoteForGlide: UInt8?

    // Pan gains
    private var panGainL: UnsafeMutablePointer<Float> = .allocate(capacity: kMaxVoices)
    private var panGainR: UnsafeMutablePointer<Float> = .allocate(capacity: kMaxVoices)

    // Scratch buffers for block processing
    private let dx7BlockBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
    private let dx7Bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
    private let dx7Bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
    private let floatScratch = UnsafeMutablePointer<Float>.allocate(capacity: kBlockSize)

    // Lock-free MIDI event ring buffer (SPSC FIFO)
    // Capacity 1024 to reduce overflow risk (was 256; MIDI 2.0 per-note messages
    // can burst heavily during MPE/polyphonic passages).
    private let midiRing = SPSCRing<MIDIEvent>(capacity: 1024)

    /// Diagnostic counter: number of MIDI events dropped due to ring overflow.
    /// Accessed from UI thread (read) and audio thread indirectly (write via sendMIDI).
    private let _droppedMIDICount = Atomic<Int>(0)

    /// Controller-reset request counter: bumped by resetControllers() (any thread),
    /// consumed by render() so the actual reset runs on the audio thread instead of
    /// mutating render-owned voice/controller state from the UI thread.
    private let _ctrlResetRequest = Atomic<Int>(0)
    private var appliedCtrlResetCount = 0

    /// Number of MIDI events dropped due to ring buffer overflow since engine creation.
    /// Check this periodically from the UI thread for diagnostics.
    public var droppedMIDICount: Int {
        _droppedMIDICount.load(ordering: .relaxed)
    }

    public init() {
        for i in 0..<kMaxVoices {
            panGainL[i] = 0.70710678
            panGainR[i] = 0.70710678
        }
    }

    deinit {
        voicesDX7.deinitialize(count: kMaxVoices)
        voicesDX7.deallocate()
        panGainL.deallocate()
        panGainR.deallocate()
        dx7BlockBuf.deallocate()
        dx7Bus1.deallocate()
        dx7Bus2.deallocate()
        floatScratch.deallocate()
        slotModScratch.deinitialize(count: kMaxSlots)
        slotModScratch.deallocate()
    }

    // MARK: - MIDI Event Queue

    /// Enqueue a MIDI event (UI thread). Lock-free, allocation-free.
    /// Note Off events are never silently dropped — if the ring is full,
    /// the diagnostic counter increments but Note Off is retried after a
    /// brief spin (at most 3 attempts) to avoid stuck notes.
    public func sendMIDI(_ event: MIDIEvent) {
        if midiRing.push(event) { return }

        // Ring is full — record the drop
        _droppedMIDICount.wrappingAdd(1, ordering: .relaxed)

        // For Note Off (and NoteOn with velocity 0), retry a few times.
        // The render thread drains the ring every ~5ms at 48kHz/256 frames,
        // so a brief spin has a good chance of succeeding.
        let isNoteOff = event.kind == .noteOff ||
            (event.kind == .noteOn && (event.data2 & 0xFFFF) == 0)
        if isNoteOff {
            for _ in 0..<3 {
                if midiRing.push(event) { return }
            }
            // Still failed — stuck note is possible. The diagnostic counter
            // alerts the UI layer to show a warning.
        }
    }

    private func drainMIDI() {
        while let event = midiRing.pop() {
            switch event.kind {
            case .noteOn:
                let vel16 = UInt16(event.data2 & 0xFFFF)
                if vel16 == 0 { doNoteOff(event.data1) }
                else { doNoteOn(event.data1, velocity16: vel16) }
            case .noteOff:
                doNoteOff(event.data1)
            case .controlChange:
                doControlChange(event.data1, value32: event.data2)
            case .pitchBend:
                doPitchBend32(event.data2)
            case .channelPressure:
                doChannelPressure(event.data2)
            case .polyPressure:
                doPolyPressure(event.data1, value32: event.data2)
            case .perNotePitchBend:
                doPerNotePitchBend(event.data1, value32: event.data2)
            case .perNoteCC:
                let index = UInt8(event.data2 >> 24)
                let value = event.data2 & 0x00FFFFFF
                doPerNoteCC(event.data1, index: index, value: value)
            case .perNoteManagement:
                doPerNoteManagement(event.data1, flags: event.data2)
            case .registeredController:
                let index = UInt8(event.data2 >> 24)
                let value = event.data2 & 0x00FFFFFF
                doRPN(event.data1, index: index, value: value)
            case .assignableController:
                let index = UInt8(event.data2 >> 24)
                let value = event.data2 & 0x00FFFFFF
                doNRPN(event.data1, index: index, value: value)
            }
        }
    }

    // MARK: - UI Thread Parameter Setters

    private var batchDepth = 0

    /// Begin a batch update — suppresses snapshot pushes until endBatch().
    /// Nestable. Call endBatch() to push the final snapshot.
    public func beginBatch() { batchDepth += 1 }

    /// End a batch update — pushes the snapshot if this is the outermost batch.
    public func endBatch() {
        batchDepth = max(0, batchDepth - 1)
        if batchDepth == 0 { bumpVersion() }
    }

    @inline(__always)
    private func bumpVersion() {
        shadowSnapshot.version &+= 1
        if batchDepth == 0 {
            snapshotRing.pushLatest(shadowSnapshot)
        }
    }

    public func setSampleRate(_ sr: Float) {
        // Validate: a zero / negative / non-finite rate would propagate to the
        // render thread and trap in Int(inc) / Int64(...) conversions. Clamp to a
        // sane audio range, falling back to 44.1 kHz for non-finite input.
        shadowSnapshot.sampleRate = (sr.isFinite && sr >= 1) ? min(192000, max(8000, sr)) : 44100
        bumpVersion()
    }

    public func setAlgorithm(_ alg: Int) {
        shadowSnapshot.algorithm = max(0, min(kNumAlgorithms - 1, alg))
        bumpVersion()
    }

    public func setMasterVolume(_ vol: Float) {
        shadowSnapshot.masterVolume = max(0, min(1, vol))
        bumpVersion()
    }

    public func setUnison(count: Int, detuneCents: Float, detuneMode: UInt8 = 0) {
        shadowSnapshot.unisonCount = max(1, min(8, count))
        shadowSnapshot.unisonDetune = max(0, min(50, detuneCents))
        shadowSnapshot.unisonDetuneMode = detuneMode
        bumpVersion()
    }

    /// #89 experimental Voice Stack multiplier. 1 = off (default). Clamped 1...16.
    /// Publishes via the shadow snapshot exactly like setUnison.
    public func setVoiceStackMultiplier(_ m: Int) {
        shadowSnapshot.voiceStackMultiplier = max(1, min(16, m))
        bumpVersion()
    }

    /// #89-detune: per-copy Voice Stack detune (cents, clamped 0…25) + distribution
    /// mode (0 even, 1 random). Publishes via the shadow snapshot like setUnison.
    public func setVoiceStackDetune(detuneCents: Float, detuneMode: UInt8) {
        shadowSnapshot.voiceStackDetune = max(0, min(25, detuneCents))
        shadowSnapshot.voiceStackDetuneMode = detuneMode
        bumpVersion()
    }

    /// #79 portamento on/off + glide Time (0…1). Time maps to a constant glide
    /// rate (cents/sec) via `portamentoRate(fromTime:)`. Off (default) leaves the
    /// render path bit-identical.
    public func setPortamento(enabled: Bool, time: Float) {
        shadowSnapshot.portamentoEnabled = enabled ? 1 : 0
        shadowSnapshot.portamentoRateCentsPerSec = Self.portamentoRate(fromTime: max(0, min(1, time)))
        bumpVersion()
    }

    /// Glide Time (0…1) → constant rate in cents/second. Exponential so the
    /// control feels even: Time 0 ≈ near-instant (24000 c/s — a 2-octave leap in
    /// 0.1 s), Time 1 ≈ slow (60 c/s — a semitone in ~1.7 s). Lives in the engine
    /// so standalone and AUv3 agree. RT-safe (called from the UI thread only).
    public static func portamentoRate(fromTime time: Float) -> Float {
        let t = max(0, min(1, time))
        let fast: Float = 24000, slow: Float = 60
        return fast * powf(slow / fast, t)
    }

    /// Test accessor: a voice's current glide offset in cents (0 = arrived).
    public func debugGlideOffsetCents(voice i: Int) -> Float {
        guard i >= 0, i < kMaxVoices else { return 0 }
        return voicesDX7[i].glideOffsetCents
    }

    /// Introspection for tests: number of currently-active voices.
    internal var activeVoiceCount: Int {
        var c = 0
        for i in 0..<kMaxVoices where voicesDX7[i].active { c += 1 }
        return c
    }

    /// Public test accessor: number of currently-active voices (used by FMEngineSwitchTests).
    public var debugActiveVoiceCount: Int { (0..<kMaxVoices).reduce(0) { $0 + (voicesDX7[$1].active ? 1 : 0) } }

    /// Test introspection: slotId of each active voice.
    internal func activeVoiceSlotIds() -> [Int] {
        var r: [Int] = []
        for i in 0..<kMaxVoices where voicesDX7[i].active { r.append(voicesDX7[i].slotId) }
        return r
    }

    /// Test introspection: operator `opIndex` frequencies of all active voices.
    internal func activeVoiceOperatorFreqs(_ opIndex: Int) -> [Float] {
        var r: [Float] = []
        for i in 0..<kMaxVoices where voicesDX7[i].active {
            r.append(voicesDX7[i].operatorFrequency(opIndex))
        }
        return r
    }

    public func setOperatorDX7OutputLevel(_ opIndex: Int, level: Int) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) { $0.dx7OutputLevel = level }
        bumpVersion()
    }

    public func setOperatorDX7EGRates(_ opIndex: Int, r1: Int, r2: Int, r3: Int, r4: Int) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) {
            $0.dx7EgR0 = r1; $0.dx7EgR1 = r2; $0.dx7EgR2 = r3; $0.dx7EgR3 = r4
        }
        bumpVersion()
    }

    public func setOperatorDX7EGLevels(_ opIndex: Int, l1: Int, l2: Int, l3: Int, l4: Int) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) {
            $0.dx7EgL0 = l1; $0.dx7EgL1 = l2; $0.dx7EgL2 = l3; $0.dx7EgL3 = l4
        }
        bumpVersion()
    }

    public func setOperatorRatio(_ opIndex: Int, ratio: Float) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) { $0.ratio = ratio }
        bumpVersion()
    }

    public func setOperatorDetune(_ opIndex: Int, cents: Float) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) { $0.detune = powf(2.0, cents / 1200.0) }
        bumpVersion()
    }

    public func setOperatorFeedback(_ fb: Int) {
        // Clamp to the DX7 0...7 range; an unclamped value yields a negative
        // feedback shift (a left shift) and garbage output downstream.
        withShadowOp(0) { $0.feedback = Float(max(0, min(7, fb))) / 7.0 }
        bumpVersion()
    }

    public func setOperatorVelocitySensitivity(_ opIndex: Int, value: UInt8) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) { $0.velocitySensitivity = min(7, value) }
        bumpVersion()
    }

    public func setOperatorAmpModSensitivity(_ opIndex: Int, value: UInt8) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) { $0.ampModSensitivity = min(3, value) }
        bumpVersion()
    }

    public func setOperatorKeyboardRateScaling(_ opIndex: Int, value: UInt8) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) { $0.keyboardRateScaling = min(7, value) }
        bumpVersion()
    }

    public func setOperatorKLS(_ opIndex: Int, breakPoint: UInt8, leftDepth: UInt8, rightDepth: UInt8,
                                leftCurve: UInt8, rightCurve: UInt8) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) {
            $0.klsBreakPoint = min(99, breakPoint)
            $0.klsLeftDepth = min(99, leftDepth)
            $0.klsRightDepth = min(99, rightDepth)
            $0.klsLeftCurve = min(3, leftCurve)
            $0.klsRightCurve = min(3, rightCurve)
        }
        bumpVersion()
    }

    public func setOperatorFixedFrequency(_ opIndex: Int, enabled: UInt8, coarse: UInt8, fine: UInt8) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) {
            $0.fixedFrequency = min(1, enabled)
            $0.fixedFreqCoarse = min(31, coarse)
            $0.fixedFreqFine = min(99, fine)
        }
        bumpVersion()
    }

    // LFO
    public func setLFOSpeed(_ value: UInt8) { shadowSnapshot.lfoSpeed = min(99, value); bumpVersion() }
    public func setLFODelay(_ value: UInt8) { shadowSnapshot.lfoDelay = min(99, value); bumpVersion() }
    public func setLFOPMD(_ value: UInt8) { shadowSnapshot.lfoPMD = min(99, value); bumpVersion() }
    public func setLFOAMD(_ value: UInt8) { shadowSnapshot.lfoAMD = min(99, value); bumpVersion() }
    public func setLFOSync(_ value: UInt8) { shadowSnapshot.lfoSync = min(1, value); bumpVersion() }
    public func setLFOWaveform(_ value: UInt8) { shadowSnapshot.lfoWaveform = min(5, value); bumpVersion() }
    public func setLFOPMS(_ value: UInt8) { shadowSnapshot.lfoPMS = min(7, value); bumpVersion() }

    public func setTranspose(_ value: Int8) {
        shadowSnapshot.transpose = max(-24, min(24, value))
        bumpVersion()
    }

    public func setPitchBendRange(_ value: UInt8) {
        shadowSnapshot.pitchBendRange = max(1, min(12, value))
        bumpVersion()
    }

    public func setMasterTuning(_ cents: Int16) {
        shadowSnapshot.masterTuning = max(-100, min(100, cents))
        bumpVersion()
    }

    // MARK: - Controller Mapping Setters

    public func setWheelPitch(_ v: UInt8) { shadowSnapshot.slots.0.wheelPitch = min(99, v); bumpVersion() }
    public func setWheelAmp(_ v: UInt8) { shadowSnapshot.slots.0.wheelAmp = min(99, v); bumpVersion() }
    public func setWheelEGBias(_ v: UInt8) { shadowSnapshot.slots.0.wheelEGBias = min(99, v); bumpVersion() }
    public func setFootPitch(_ v: UInt8) { shadowSnapshot.slots.0.footPitch = min(99, v); bumpVersion() }
    public func setFootAmp(_ v: UInt8) { shadowSnapshot.slots.0.footAmp = min(99, v); bumpVersion() }
    public func setFootEGBias(_ v: UInt8) { shadowSnapshot.slots.0.footEGBias = min(99, v); bumpVersion() }
    public func setBreathPitch(_ v: UInt8) { shadowSnapshot.slots.0.breathPitch = min(99, v); bumpVersion() }
    public func setBreathAmp(_ v: UInt8) { shadowSnapshot.slots.0.breathAmp = min(99, v); bumpVersion() }
    public func setBreathEGBias(_ v: UInt8) { shadowSnapshot.slots.0.breathEGBias = min(99, v); bumpVersion() }
    public func setAftertouchPitch(_ v: UInt8) { shadowSnapshot.slots.0.aftertouchPitch = min(99, v); bumpVersion() }
    public func setAftertouchAmp(_ v: UInt8) { shadowSnapshot.slots.0.aftertouchAmp = min(99, v); bumpVersion() }
    public func setAftertouchEGBias(_ v: UInt8) { shadowSnapshot.slots.0.aftertouchEGBias = min(99, v); bumpVersion() }

    // MARK: - Pitch EG Setters

    public func setPitchEGRates(_ r0: UInt8, _ r1: UInt8, _ r2: UInt8, _ r3: UInt8) {
        shadowSnapshot.slots.0.pitchEGR0 = min(99, r0)
        shadowSnapshot.slots.0.pitchEGR1 = min(99, r1)
        shadowSnapshot.slots.0.pitchEGR2 = min(99, r2)
        shadowSnapshot.slots.0.pitchEGR3 = min(99, r3)
        bumpVersion()
    }

    public func setPitchEGLevels(_ l0: UInt8, _ l1: UInt8, _ l2: UInt8, _ l3: UInt8) {
        shadowSnapshot.slots.0.pitchEGL0 = min(99, l0)
        shadowSnapshot.slots.0.pitchEGL1 = min(99, l1)
        shadowSnapshot.slots.0.pitchEGL2 = min(99, l2)
        shadowSnapshot.slots.0.pitchEGL3 = min(99, l3)
        bumpVersion()
    }

    // MARK: - Oversampling

    public func setOversamplingMode(_ mode: OversamplingMode) {
        shadowSnapshot.oversamplingMode = mode.rawValue
        bumpVersion()
    }

    /// #75 vintage 12-bit DAC mode on/off. Off (default) leaves the render path bit-identical.
    public func setVintageDAC(_ on: Bool) {
        shadowSnapshot.vintageDAC12bit = on ? 1 : 0
        bumpVersion()
    }

    // MARK: - FM Engine

    public func setFMEngine(_ engine: FMEngine) {
        if engine.isMarkI { markIPrewarm() }   // materialize tables off the audio thread
        shadowSnapshot.fmEngine = engine.rawValue
        bumpVersion()
    }

    /// Mark I forward-modulation depth as a divisor ÷X (larger = darker). The
    /// engine stores it as a Q12 scale (4096/X), so 0.1 steps stay distinct
    /// across the whole ÷2…÷16 range. Read by the Mark I kernels on the render
    /// thread; a plain aligned-Int32 write is atomic, and the value only changes
    /// when the user moves the depth control.
    public func setMarkIModDivisor(_ divisor: Double) {
        let d = max(0.5, divisor)
        markIModScaleQ12 = Int32(max(1, min(4096, (4096.0 / d).rounded())))
    }

    /// Test-only read of the current Mark I Q12 modulation scale.
    public var debugMarkIModScaleQ12: Int32 { markIModScaleQ12 }

    /// Test-only read of the shadow snapshot's engine selection.
    public var debugShadowFMEngine: UInt8 { shadowSnapshot.fmEngine }

    // MARK: - Split Point / Slot Control

    public func setSplitPoint(_ note: UInt8) {
        shadowSnapshot.splitPoint = note
        let mode = TimbreMode(rawValue: shadowSnapshot.timbreMode) ?? .single
        if mode == .split {
            // splitPoint 0 has no lower zone: disable slot 0 rather than giving it
            // an overlapping [0,0] range (which would double-trigger note 0).
            shadowSnapshot.setConfig(at: 0, SlotConfig(noteRangeLow: 0, noteRangeHigh: note > 0 ? note - 1 : 0, enabled: note > 0))
            shadowSnapshot.setConfig(at: 1, SlotConfig(noteRangeLow: note, noteRangeHigh: 127))
        }
        bumpVersion()
    }

    public func setSlotEnabled(_ slotIdx: Int, enabled: Bool) {
        guard slotIdx >= 0, slotIdx < kMaxSlots else { return }
        var cfg = shadowSnapshot.config(at: slotIdx)
        cfg.enabled = enabled
        shadowSnapshot.setConfig(at: slotIdx, cfg)
        bumpVersion()
    }

    /// Per-slot output level (layer balancing). Clamped to 0...4 (≈ +12 dB).
    public func setSlotLevel(_ slotIdx: Int, gain: Float) {
        guard slotIdx >= 0, slotIdx < kMaxSlots else { return }
        var c = shadowSnapshot.config(at: slotIdx)
        c.gain = max(0, min(4, gain))
        shadowSnapshot.setConfig(at: slotIdx, c)
        bumpVersion()
    }

    /// Per-slot stereo pan (layer stereo width). Clamped to -1...1 (L…R).
    public func setSlotPan(_ slotIdx: Int, pan: Float) {
        guard slotIdx >= 0, slotIdx < kMaxSlots else { return }
        var c = shadowSnapshot.config(at: slotIdx)
        c.pan = max(-1, min(1, pan))
        shadowSnapshot.setConfig(at: slotIdx, c)
        bumpVersion()
    }

    /// #76: per-slot random-pan toggle. When true, each note-on draws a
    /// deterministic random pan (per slot+voice) instead of the fixed `pan`.
    public func setSlotPanRandom(_ slotIdx: Int, _ random: Bool) {
        guard slotIdx >= 0, slotIdx < kMaxSlots else { return }
        var c = shadowSnapshot.config(at: slotIdx)
        c.panRandom = random
        shadowSnapshot.setConfig(at: slotIdx, c)
        bumpVersion()
    }

    // MARK: - Render Overload Monitoring

    /// Render overload count for adaptive buffer monitoring.
    /// Written by render thread via benign race (Int32 on arm64 is atomic for reads).
    public private(set) var renderOverloadCount: Int32 = 0

    // MARK: - Clean API Compatibility Wrappers

    /// Set operator level from normalized Float (0.0-1.0).
    /// Converts to DX7 output level (0-99) internally.
    public func setOperatorLevel(_ opIndex: Int, level: Float) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        // Convert normalized level to DX7 OL: OL = 99 + dB / 0.75
        let ol: Int
        if !level.isFinite || level <= 0 { ol = 0 }   // guard NaN/Inf -> Int() trap
        else if level >= 1.0 { ol = 99 }
        else {
            let dB = 20.0 * log10f(level)
            ol = max(0, min(99, Int(99.0 + dB / 0.75)))
        }
        withShadowOp(opIndex) { $0.dx7OutputLevel = ol }
        bumpVersion()
    }

    /// Set operator EG rates from Float (0-99 range, same as DX7 native).
    public func setOperatorEGRates(_ opIndex: Int, r1: Float, r2: Float, r3: Float, r4: Float) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        // Clamp before Int() — a non-finite or out-of-range Float traps the conversion.
        func r(_ f: Float) -> Int { f.isFinite ? Int(max(0.0, min(99.0, f))) : 0 }
        withShadowOp(opIndex) {
            $0.dx7EgR0 = r(r1); $0.dx7EgR1 = r(r2)
            $0.dx7EgR2 = r(r3); $0.dx7EgR3 = r(r4)
        }
        bumpVersion()
    }

    /// Set operator EG levels from normalized Float (0.0-1.0).
    /// Converts to DX7 level (0-99) internally.
    public func setOperatorEGLevels(_ opIndex: Int, l1: Float, l2: Float, l3: Float, l4: Float) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        // Clamp before Int() — a non-finite or out-of-range Float traps the conversion.
        func l(_ f: Float) -> Int { f.isFinite ? Int(max(0.0, min(99.0, f * 99.0))) : 0 }
        withShadowOp(opIndex) {
            $0.dx7EgL0 = l(l1); $0.dx7EgL1 = l(l2)
            $0.dx7EgL2 = l(l3); $0.dx7EgL3 = l(l4)
        }
        bumpVersion()
    }

    /// Set per-operator feedback from Float.
    /// DX7 has global feedback; this sets on the algorithm's feedback operator.
    public func setOperatorFeedback(_ opIndex: Int, feedback: Float) {
        // Convert float feedback gain to DX7 integer (0-7). Guard non-finite
        // input: log2f(NaN/Inf) -> Int(...) would trap.
        let fb: Int
        if !feedback.isFinite || feedback <= 0 { fb = 0 }
        else { fb = max(0, min(7, Int(log2f(feedback) + 9.0 + 0.5))) }
        setOperatorFeedback(fb)
    }

    /// Set operator waveform (DX7II OPZ: 0-7, currently no-op for pure DX7 mode).
    public func setOperatorWaveform(_ opIndex: Int, waveform: UInt8) {
        // DX7 only supports sine wave; store for future DX7II support
    }

    public func setTimbreMode(_ mode: TimbreMode, splitPoint: UInt8 = 60) {
        shadowSnapshot.timbreMode = mode.rawValue
        shadowSnapshot.splitPoint = splitPoint
        let slotCount = mode.slotCount
        let baseSlot = shadowSnapshot.slot(at: 0)

        // Copy slot 0 into any newly-activated slots. Guard the range: when
        // shrinking (e.g. tx816 -> single) activeSlotCount > slotCount, and an
        // unguarded `activeSlotCount..<slotCount` traps (lowerBound > upperBound).
        if slotCount > shadowSnapshot.activeSlotCount {
            for i in shadowSnapshot.activeSlotCount..<slotCount {
                shadowSnapshot.setSlot(at: i, baseSlot)
            }
        }
        shadowSnapshot.activeSlotCount = slotCount

        switch mode {
        case .single:
            shadowSnapshot.setConfig(at: 0, SlotConfig())
        case .dual:
            shadowSnapshot.setConfig(at: 0, SlotConfig())
            shadowSnapshot.setConfig(at: 1, SlotConfig())
        case .split:
            // splitPoint 0 has no lower zone: disable slot 0 (see setSplitPoint).
            shadowSnapshot.setConfig(at: 0, SlotConfig(noteRangeLow: 0, noteRangeHigh: splitPoint > 0 ? splitPoint - 1 : 0, enabled: splitPoint > 0))
            shadowSnapshot.setConfig(at: 1, SlotConfig(noteRangeLow: splitPoint, noteRangeHigh: 127))
        case .tx816:
            for i in 0..<8 {
                shadowSnapshot.setConfig(at: i, SlotConfig(midiChannel: UInt8(i)))
            }
        case .layer:
            // Layer mode stacks every enabled slot on every note (TX816-style),
            // so it shares tx816's 8-slot init; per-slot routing differences are
            // handled in determineTargetSlots and the voice budget.
            for i in 0..<8 {
                shadowSnapshot.setConfig(at: i, SlotConfig(midiChannel: UInt8(i)))
            }
        }
        bumpVersion()
    }

    /// Configure a "P parts × U unison" layer in one call: enable the first
    /// `parts` slots (full keyboard range), set the global unison count + detune,
    /// and switch to `.layer` mode. A single setter so callers never have to
    /// coordinate a separate `setUnison` / `setTimbreMode` sequence.
    ///
    /// Publishes via the same `bumpVersion()` path as `setTimbreMode`; the render
    /// thread observes `.layer` by reading `shadowSnapshot.timbreMode` off the
    /// snapshot ring (it sets its own `currentTimbreMode` internally), so writing
    /// the shadow field and bumping the version is sufficient.
    public func setLayerPartition(parts: Int, unison: Int, detuneCents: Float = 0, detuneMode: UInt8 = 0) {
        let p = max(1, min(kMaxSlots, parts))

        // Seed newly-activated slots with slot 0's patch, exactly like
        // setTimbreMode does. We raise activeSlotCount to kMaxSlots below, so
        // without this seed every slot above the previous activeSlotCount would
        // be enabled+routed but carry a default/uninitialized SlotSnapshot and
        // render the wrong sound. Read the OLD activeSlotCount first; the
        // `kMaxSlots > prev` guard means re-partitioning while already at
        // activeSlotCount = kMaxSlots does NOT re-clobber loaded slot patches.
        let prev = shadowSnapshot.activeSlotCount
        if kMaxSlots > prev {
            let baseSlot = shadowSnapshot.slot(at: 0)
            for i in prev..<kMaxSlots { shadowSnapshot.setSlot(at: i, baseSlot) }
        }

        for i in 0..<kMaxSlots {
            var c = shadowSnapshot.config(at: i)
            c.enabled = (i < p)
            c.noteRangeLow = 0
            c.noteRangeHigh = 127
            // Mirror setTimbreMode's .layer/.tx816 cases for forward consistency
            // with future per-channel routing. No functional effect today: layer's
            // determineTargetSlots fans out regardless of midiChannel.
            c.midiChannel = UInt8(i)
            shadowSnapshot.setConfig(at: i, c)
        }
        shadowSnapshot.unisonCount = max(1, min(8, unison))
        shadowSnapshot.unisonDetune = max(0, min(50, detuneCents))
        shadowSnapshot.unisonDetuneMode = detuneMode
        shadowSnapshot.timbreMode = TimbreMode.layer.rawValue
        shadowSnapshot.activeSlotCount = kMaxSlots
        bumpVersion()
    }

    public func loadSlotParams(_ slotIdx: Int, slot: SlotSnapshot, resetControllers: Bool = true) {
        guard slotIdx >= 0, slotIdx < shadowSnapshot.activeSlotCount else { return }
        // Sanitize caller-supplied values that the render thread consumes without
        // its own guard: a negative algorithm would OOB kAlgorithmFlags, and a
        // non-finite ops.0.feedback would trap Int(feedback*7+0.5).
        var slot = slot
        slot.algorithm = max(0, min(kNumAlgorithms - 1, slot.algorithm))
        let fb0 = slot.ops.0.feedback
        slot.ops.0.feedback = fb0.isFinite ? max(0, min(1, fb0)) : 0
        shadowSnapshot.setSlot(at: slotIdx, slot)
        if resetControllers { self.resetControllers() }
        bumpVersion()
    }

    /// Load a DX7 preset into slot 0 atomically.
    /// Directly writes all parameters to the shadow snapshot and pushes once.
    /// This avoids intermediate snapshot races that occur with individual setters.
    public func loadDX7Preset(_ preset: DX7Preset, slotIdx: Int = 0) {
        guard slotIdx >= 0, slotIdx < shadowSnapshot.activeSlotCount else { return }

        // Build operator snapshots
        func makeOpSnap(_ op: DX7OperatorPreset, isFeedbackOp: Bool, voiceFeedback: Int) -> OperatorSnapshot {
            var s = OperatorSnapshot()
            s.level = op.normalizedLevel
            s.ratio = op.frequencyRatio
            s.detune = powf(2.0, op.detuneCents / 1200.0)
            // Feedback stored as Float(fb)/7.0 — only on the feedback operator (op0)
            s.feedback = isFeedbackOp ? Float(voiceFeedback) / 7.0 : 0
            s.dx7OutputLevel = op.outputLevel
            s.dx7EgR0 = op.egRate1; s.dx7EgR1 = op.egRate2
            s.dx7EgR2 = op.egRate3; s.dx7EgR3 = op.egRate4
            s.dx7EgL0 = op.egLevel1; s.dx7EgL1 = op.egLevel2
            s.dx7EgL2 = op.egLevel3; s.dx7EgL3 = op.egLevel4
            let levels = op.egLevelsNormalized
            s.egR0 = Float(op.egRate1); s.egR1 = Float(op.egRate2)
            s.egR2 = Float(op.egRate3); s.egR3 = Float(op.egRate4)
            s.egL0 = levels.0; s.egL1 = levels.1
            s.egL2 = levels.2; s.egL3 = levels.3
            s.velocitySensitivity = UInt8(clamping: op.velocitySensitivity)
            s.ampModSensitivity = UInt8(clamping: op.ampModSensitivity)
            s.keyboardRateScaling = UInt8(clamping: op.keyboardRateScaling)
            s.klsBreakPoint = UInt8(clamping: op.klsBreakPoint)
            s.klsLeftDepth = UInt8(clamping: op.klsLeftDepth)
            s.klsRightDepth = UInt8(clamping: op.klsRightDepth)
            s.klsLeftCurve = UInt8(clamping: op.klsLeftCurve)
            s.klsRightCurve = UInt8(clamping: op.klsRightCurve)
            s.fixedFrequency = UInt8(clamping: op.frequencyMode)
            s.fixedFreqCoarse = UInt8(clamping: op.frequencyCoarse)
            s.fixedFreqFine = UInt8(clamping: op.frequencyFine)
            return s
        }

        var slot = SlotSnapshot()
        slot.algorithm = max(0, min(kNumAlgorithms - 1, preset.algorithm))

        // DX7Preset.operators: [OP1, OP2, OP3, OP4, OP5, OP6] (OP1=carrier in Alg1)
        // kAlgorithmFlags opIdx: 0=OP6, 1=OP5, 2=OP4, 3=OP3, 4=OP2, 5=OP1
        // Map: operators[i] → opIdx = 5 - i
        // Feedback goes on opIdx 0 (= OP6 = operators[5])
        let ops = preset.operators
        if ops.count >= 6 {
            slot.ops.0 = makeOpSnap(ops[5], isFeedbackOp: true, voiceFeedback: preset.feedback)
            slot.ops.1 = makeOpSnap(ops[4], isFeedbackOp: false, voiceFeedback: 0)
            slot.ops.2 = makeOpSnap(ops[3], isFeedbackOp: false, voiceFeedback: 0)
            slot.ops.3 = makeOpSnap(ops[2], isFeedbackOp: false, voiceFeedback: 0)
            slot.ops.4 = makeOpSnap(ops[1], isFeedbackOp: false, voiceFeedback: 0)
            slot.ops.5 = makeOpSnap(ops[0], isFeedbackOp: false, voiceFeedback: 0)
        }

        // LFO
        slot.lfoSpeed = UInt8(clamping: preset.lfoSpeed)
        slot.lfoDelay = UInt8(clamping: preset.lfoDelay)
        slot.lfoPMD = UInt8(clamping: preset.lfoPMD)
        slot.lfoAMD = UInt8(clamping: preset.lfoAMD)
        slot.lfoSync = UInt8(clamping: preset.lfoSync)
        slot.lfoWaveform = UInt8(clamping: preset.lfoWaveform)
        slot.lfoPMS = UInt8(clamping: preset.lfoPMS)

        // Pitch EG
        slot.pitchEGR0 = UInt8(clamping: preset.pitchEGR1)
        slot.pitchEGR1 = UInt8(clamping: preset.pitchEGR2)
        slot.pitchEGR2 = UInt8(clamping: preset.pitchEGR3)
        slot.pitchEGR3 = UInt8(clamping: preset.pitchEGR4)
        slot.pitchEGL0 = UInt8(clamping: preset.pitchEGL1)
        slot.pitchEGL1 = UInt8(clamping: preset.pitchEGL2)
        slot.pitchEGL2 = UInt8(clamping: preset.pitchEGL3)
        slot.pitchEGL3 = UInt8(clamping: preset.pitchEGL4)
        slot.transpose = Int8(clamping: preset.transpose)

        // Controller mapping — DX7 defaults
        slot.wheelPitch = 50; slot.wheelAmp = 0; slot.wheelEGBias = 0
        slot.footPitch = 0; slot.footAmp = 0; slot.footEGBias = 0
        slot.breathPitch = 0; slot.breathAmp = 0; slot.breathEGBias = 0
        slot.aftertouchPitch = 0; slot.aftertouchAmp = 0; slot.aftertouchEGBias = 0

        // Write to shadow snapshot and push atomically
        shadowSnapshot.setSlot(at: slotIdx, slot)
        resetControllers()
        shadowSnapshot.version &+= 1
        // Honor an open batch: don't publish a partial snapshot mid-batch.
        if batchDepth == 0 {
            snapshotRing.pushLatest(shadowSnapshot)
        }
    }

    /// Reset all MIDI controller state to defaults.
    /// Call when switching presets to clear stale CC values.
    public func resetControllers() {
        // Defer to the render thread: this resets render-owned voice/controller
        // state (voicesDX7, modWheelDepth, etc.), which must not be mutated from
        // the UI thread concurrently with render() (data race). render() consumes
        // the request and calls performControllerReset() on the audio thread.
        _ctrlResetRequest.wrappingAdd(1, ordering: .relaxed)
    }

    /// Actual controller reset — render thread only.
    private func performControllerReset() {
        modWheelDepth = 0
        footDepth = 0
        breathDepth = 0
        aftertouchDepth = 0
        for i in 0..<kMaxSlots { pitchBendValueBySlot[i] = 1.0 }
        sustainPedalOn = false
        for i in 0..<kMaxVoices {
            voicesDX7[i].sustained = false
            if voicesDX7[i].active {
                voicesDX7[i].applyPitchBend(1.0)
            }
        }
    }

    @inline(__always)
    private func withShadowOp(_ i: Int, _ body: (inout OperatorSnapshot) -> Void) {
        switch i {
        case 0: body(&shadowSnapshot.ops.0)
        case 1: body(&shadowSnapshot.ops.1)
        case 2: body(&shadowSnapshot.ops.2)
        case 3: body(&shadowSnapshot.ops.3)
        case 4: body(&shadowSnapshot.ops.4)
        case 5: body(&shadowSnapshot.ops.5)
        default: break
        }
    }

    // MARK: - Render (audio thread)

    public func render(into bufferL: UnsafeMutablePointer<Float>,
                       bufferR: UnsafeMutablePointer<Float>,
                       frameCount: Int) {
        // Pop latest snapshot first so MIDI handlers see current params
        if let newSnapshot = snapshotRing.popLatest() {
            currentSnapshot = newSnapshot
        }
        let snapshot = currentSnapshot

        // Consume any pending controller-reset request on the render thread.
        let ctrlGen = _ctrlResetRequest.load(ordering: .relaxed)
        if ctrlGen != appliedCtrlResetCount {
            appliedCtrlResetCount = ctrlGen
            performControllerReset()
        }

        // Drain MIDI before applyParams so allNotesOff is processed
        // before intermediate preset change snapshots corrupt active voices.
        drainMIDI()

        // Apply parameter changes to all voices
        if snapshot.version != appliedVersion {
            appliedVersion = snapshot.version

            let newOSMode = OversamplingMode(rawValue: snapshot.oversamplingMode) ?? .off
            if newOSMode != currentOversamplingMode {
                currentOversamplingMode = newOSMode
                doAllNotesOff()
                let factor: Float = (newOSMode == .off) ? 1.0 : 2.0
                baseSampleRate = snapshot.sampleRate
                sampleRate = baseSampleRate * factor
                for i in 0..<kMaxVoices { voicesDX7[i].setSampleRate(sampleRate) }
                // Only arm the de-zipper crossfade when entering an oversampled
                // mode; the .off render path never consumes it, so arming it there
                // would leave crossfadeRemaining stranded.
                if newOSMode != .off {
                    downsampler.beginTransition(sampleRate: baseSampleRate)
                }
            } else if snapshot.sampleRate != baseSampleRate {
                baseSampleRate = snapshot.sampleRate
                let factor: Float = (currentOversamplingMode == .off) ? 1.0 : 2.0
                sampleRate = baseSampleRate * factor
                for i in 0..<kMaxVoices { voicesDX7[i].setSampleRate(sampleRate) }
            }

            let newFMEngine = FMEngine(rawValue: snapshot.fmEngine) ?? .modern
            if newFMEngine != currentFMEngine {
                currentFMEngine = newFMEngine
                // Modern↔MarkI use incompatible gain scales; kill all voices immediately
                // rather than letting them release through the old engine's path.
                doAllNotesOff()
                for i in 0..<kMaxVoices {
                    voicesDX7[i].active = false
                    voicesDX7[i].engineMode = newFMEngine
                }
            }

            algorithm = snapshot.algorithm
            masterVolume = snapshot.masterVolume

            let newTimbreMode = TimbreMode(rawValue: snapshot.timbreMode) ?? .single
            currentTimbreMode = newTimbreMode

            let voicesForMode: Int
            switch currentTimbreMode {
            case .single: voicesForMode = 16
            case .dual, .split: voicesForMode = 32
            case .tx816: voicesForMode = 64
            case .layer: voicesForMode = kLayerBaseVoices   // #89: was kMaxVoices; decoupled so LAYER stays 128 while the buffer grows.
            }
            let baseVoices = (currentOversamplingMode == .off) ? voicesForMode : max(8, voicesForMode / 2)
            // #89: preserve the pre-Voice-Stack budget exactly — min(legacy 128 cap, base×unison) —
            // so LAYER/dual + unison≥2 at stack=1 stay byte-identical to pre-#89 (spec §2). The
            // Voice Stack multiplier then scales that up to the kMaxVoices (2048) buffer.
            let preStackVoices = min(kLayerBaseVoices, baseVoices * max(1, snapshot.unisonCount))
            effectiveMaxVoices = min(kMaxVoices, preStackVoices * max(1, snapshot.voiceStackMultiplier))

            // Reap voices outside the (possibly shrunken) active range. The render
            // loop only runs checkActive() within effectiveMaxVoices, so a voice
            // allocated at a higher index under a larger mode would otherwise keep
            // its `active` flag set forever (and could resurrect on a later grow).
            if effectiveMaxVoices < kMaxVoices {
                for i in effectiveMaxVoices..<kMaxVoices where voicesDX7[i].active {
                    voicesDX7[i].noteOff()
                    voicesDX7[i].active = false
                    voicesDX7[i].sustained = false
                }
            }

            // Apply per-voice params unconditionally.
            // Preset loads use loadDX7Preset (atomic 1-push), so versionDelta is always 1.
            for i in 0..<kMaxVoices {
                let slotIdx = voicesDX7[i].slotId
                let slot = slotIdx < snapshot.activeSlotCount ? snapshot.slot(at: slotIdx) : snapshot.slot(at: 0)
                voicesDX7[i].algorithm = slot.algorithm
                voicesDX7[i].feedbackShiftValue = feedbackShift(Int(slot.ops.0.feedback * 7.0 + 0.5))
                voicesDX7[i].applyParams(slot.ops.0, opIndex: 0)
                voicesDX7[i].applyParams(slot.ops.1, opIndex: 1)
                voicesDX7[i].applyParams(slot.ops.2, opIndex: 2)
                voicesDX7[i].applyParams(slot.ops.3, opIndex: 3)
                voicesDX7[i].applyParams(slot.ops.4, opIndex: 4)
                voicesDX7[i].applyParams(slot.ops.5, opIndex: 5)
            }
        }

        // Render
        if currentOversamplingMode == .off {
            renderFramesDX7(bufferL, bufferR, frameCount, snapshot)
        } else {
            // Process in chunks of up to 1024 output frames (2048 oversampled)
            // to stay within the downsampler's fixed buffer capacity.
            // Previously, frameCount > 1024 caused zero-fill dropout.
            // Derive from the downsampler's buffer capacity so the two cannot drift.
            let kMaxChunkOutput = downsampler.kMaxOversampledFrames / 2
            var remaining = frameCount
            var outOffset = 0

            while remaining > 0 {
                let chunkOutput = min(remaining, kMaxChunkOutput)
                let chunkOS = chunkOutput * 2

                let osL = downsampler.oversampledL
                let osR = downsampler.oversampledR
                osL.initialize(repeating: 0, count: chunkOS)
                osR.initialize(repeating: 0, count: chunkOS)
                renderFramesDX7(osL, osR, chunkOS, snapshot)

                switch currentOversamplingMode {
                case .highQuality:
                    downsampler.downsampleHalfband(
                        srcL: UnsafePointer(osL), srcR: UnsafePointer(osR),
                        dstL: bufferL.advanced(by: outOffset),
                        dstR: bufferR.advanced(by: outOffset),
                        oversampledCount: chunkOS, outputCount: chunkOutput)
                case .lowCPU:
                    downsampler.downsamplePolyphase(
                        srcL: UnsafePointer(osL), srcR: UnsafePointer(osR),
                        dstL: bufferL.advanced(by: outOffset),
                        dstR: bufferR.advanced(by: outOffset),
                        oversampledCount: chunkOS, outputCount: chunkOutput)
                case .off: break
                }

                outOffset += chunkOutput
                remaining -= chunkOutput
            }

            downsampler.applyCrossfade(bufferL: bufferL, bufferR: bufferR, frameCount: frameCount)
        }

        // #75: DX7 12-bit DAC companding — Mark I only, on the final all-voices-summed,
        // native-rate mix (post-downsample), before the app FX chain.
        if currentFMEngine == .markI && snapshot.vintageDAC12bit != 0 {
            for s in 0..<frameCount {
                bufferL[s] = dac12bitCompand(bufferL[s])
                bufferR[s] = dac12bitCompand(bufferR[s])
            }
        }
    }

    // MARK: - LFO

    /// DX7 LFO speed (0…99) → frequency in Hz. Calibrated to the documented DX7
    /// LFO range: 0.0625 Hz at speed 0, ≈47 Hz at speed 99 (exponential).
    package static func lfoSpeedToHz(_ speed: UInt8) -> Float {
        // Usable vibrato range: ~1.5 Hz at speed 0, ~5 Hz at the default 35, ~47 Hz
        // at 99. (Pragmatic exponential — pending exact DX7/Dexed reference data.)
        1.47 * expf(Float(speed) * 0.0350)
    }

    private func lfoWaveformValue(_ phase: Float, waveform: UInt8, slotIdx: Int = 0) -> Float {
        switch waveform {
        case 0:
            let p = phase * 4.0
            if phase < 0.25 { return p }
            else if phase < 0.75 { return 2.0 - p }
            else { return p - 4.0 }
        case 1: return 1.0 - 2.0 * phase
        case 2: return 2.0 * phase - 1.0
        case 3: return phase < 0.5 ? 1.0 : -1.0
        case 4: return sinf(phase * 2.0 * .pi)
        case 5: return lfoSHValue[slotIdx]
        default: return sinf(phase * 2.0 * .pi)
        }
    }

    private func updateLFOForSlot(_ slotIdx: Int, _ slot: SlotSnapshot, blockSize: Int) {
        let lfoHz = Self.lfoSpeedToHz(slot.lfoSpeed)
        // Scale by the actual block size, not the fixed kBlockSize: the final inner
        // block can be partial, and advancing a full step there would couple LFO
        // rate (and the delay fade-in) to host buffer chunking.
        let lfoInc = lfoHz / sampleRate * Float(blockSize)

        lfoPhase[slotIdx] += lfoInc
        if lfoPhase[slotIdx] >= 1.0 {
            lfoPhase[slotIdx] -= 1.0
            if slot.lfoWaveform == 5 {
                lfoSHValue[slotIdx] = lfoSHPRNG[slotIdx].nextSignedUnit()
            }
        }

        lfoCurrentValue[slotIdx] = lfoWaveformValue(lfoPhase[slotIdx], waveform: slot.lfoWaveform, slotIdx: slotIdx)

        if slot.lfoDelay > 0 && lfoDelayFadeIn[slotIdx] < 1.0 {
            let delayTime = 0.01 * expf(Float(slot.lfoDelay) * 0.069)
            let fadeInc = Float(blockSize) / (delayTime * sampleRate)
            lfoDelayFadeIn[slotIdx] = min(1.0, lfoDelayFadeIn[slotIdx] + fadeInc)
            lfoCurrentValue[slotIdx] *= lfoDelayFadeIn[slotIdx]
        }
    }

    // MARK: - DX7 Block Render

    private func renderFramesDX7(
        _ bufferL: UnsafeMutablePointer<Float>,
        _ bufferR: UnsafeMutablePointer<Float>,
        _ frameCount: Int,
        _ snapshot: SynthParamSnapshot
    ) {
        // Unison loudness compensation: N detuned copies sum incoherently (~√N
        // louder), so attenuate by 1/√N to keep a unison note ≈ a single note's
        // loudness and avoid clipping on dense chords.
        let unisonGain = 1.0 / sqrtf(Float(max(1, snapshot.unisonCount)))
        // Layer auto-gain: stacking P enabled slots sums ~√P louder, so attenuate
        // by 1/√P (mirrors the unison law) to preserve headroom. Only in .layer
        // mode — other modes are byte-for-byte unchanged (layerGain stays 1.0).
        var layerGain: Float = 1.0
        if currentTimbreMode == .layer {
            var enabled = 0
            for i in 0..<snapshot.activeSlotCount where snapshot.config(at: i).enabled { enabled += 1 }
            layerGain = 1.0 / sqrtf(Float(max(1, enabled)))
        }
        // #89-detune: 1/N when phase-locked (detune 0), crossfading to 1/√N as the
        // stacked copies decorrelate, so a detuned supersaw stays ≈ a single note's loudness.
        let voiceStackGain = voiceStackGainFactor(multiplier: snapshot.voiceStackMultiplier, detuneCents: snapshot.voiceStackDetune)
        let vol = masterVolume * expression * ccVolume * unisonGain * layerGain * voiceStackGain
        let maxV = effectiveMaxVoices
        let slotCount = snapshot.activeSlotCount

        for i in 0..<maxV { voicesDX7[i].checkActive() }

        // Per-slot modulation — uses pre-allocated slotModScratch (no heap alloc per render)
        let slotMods = slotModScratch
        for s in 0..<slotCount {
            let slot = snapshot.slot(at: s)
            slotMods[s].pmsDepth = kPMSDepth[Int(min(slot.lfoPMS, 7))]
            slotMods[s].hasPitchMod = slot.lfoPMD > 0 || modWheelDepth > 0.001
                || footDepth > 0.001 || breathDepth > 0.001 || aftertouchDepth > 0.001
            slotMods[s].lfoAMDNorm = Float(slot.lfoAMD) / 99.0
            slotMods[s].wheelPitchDepth = Float(slot.wheelPitch) / 99.0 * modWheelDepth
            slotMods[s].footPitchDepth = Float(slot.footPitch) / 99.0 * footDepth
            slotMods[s].breathPitchDepth = Float(slot.breathPitch) / 99.0 * breathDepth
            slotMods[s].atPitchDepth = Float(slot.aftertouchPitch) / 99.0 * aftertouchDepth
            let wAmp = Float(slot.wheelAmp) / 99.0 * modWheelDepth
            let fAmp = Float(slot.footAmp) / 99.0 * footDepth
            let bAmp = Float(slot.breathAmp) / 99.0 * breathDepth
            let aAmp = Float(slot.aftertouchAmp) / 99.0 * aftertouchDepth
            slotMods[s].controllerAmpMod = 1.0 - (wAmp + fAmp + bAmp + aAmp) * 0.5
        }

        for i in 0..<maxV {
            // #76: random pan reads the per-voice value captured at note-on; even
            // (default) reads the live slot pan — bit-identical to before.
            let cfg = snapshot.config(at: voicesDX7[i].slotId)
            let pan = cfg.panRandom ? voicesDX7[i].pan : cfg.pan
            if pan == 0 {
                panGainL[i] = 0.70710678
                panGainR[i] = 0.70710678
            } else {
                let p = max(-1, min(1, pan))
                let theta = (p + 1.0) * 0.25 * Float.pi   // 0 → π/2
                panGainL[i] = cosf(theta)
                panGainR[i] = sinf(theta)
            }
        }

        let blockBuf = dx7BlockBuf
        let bus1 = dx7Bus1
        let bus2 = dx7Bus2
        var offset = 0

        while offset < frameCount {
            let blockSize = min(kBlockSize, frameCount - offset)

            for s in 0..<slotCount {
                updateLFOForSlot(s, snapshot.slot(at: s), blockSize: blockSize)
            }

            // Global tuning offset (semitones), computed once per block.
            // Sums UI master tuning (snapshot, Int16 cents) and RPN fine/coarse tuning
            // (audio-local). Master tuning now takes effect on held notes, not just at
            // note-on, fixing the prior scope mismatch with RPN tuning.
            let totalTuningOffset = (Float(snapshot.masterTuning) + rpnFineTuningCents) / 100.0 + rpnCoarseTuningSemitones

            for i in 0..<maxV {
                guard voicesDX7[i].active else { continue }
                let s = voicesDX7[i].slotId
                guard s < slotCount else { continue }
                let sm = slotMods[s]

                // Pitch EG — advance once per block, get semitone offset
                var pitchEGSemitones: Float = 0
                if voicesDX7[i].pitchEG.enabled {
                    // Use the engine's render rate (oversampled), not the base
                    // snapshot rate, so the pitch EG advances at the correct cadence
                    // under oversampling (mirrors the operator EGs and the LFO).
                    voicesDX7[i].pitchEG.process(sampleRate: sampleRate)
                    pitchEGSemitones = voicesDX7[i].pitchEG.semitones
                }

                // #79 portamento: advance the glide toward target at constant rate,
                // then fold the remaining offset into the pitch factor below. When
                // off / not gliding, wasGliding=false and glideFactor=1.0, so the
                // condition and the factor are bit-identical to the non-glide path
                // (×1.0f is exact). `wasGliding` keeps the SETTLING block (offset
                // hitting 0) inside the factor branch so the final pitch is applied.
                let wasGliding = voicesDX7[i].glideOffsetCents != 0
                var glideFactor: Float = 1.0
                if wasGliding {
                    if snapshot.portamentoEnabled != 0 {
                        let step = snapshot.portamentoRateCentsPerSec * (Float(blockSize) / sampleRate)
                        let off = voicesDX7[i].glideOffsetCents
                        voicesDX7[i].glideOffsetCents = (abs(off) <= step) ? 0 : off - (off > 0 ? step : -step)
                    } else {
                        voicesDX7[i].glideOffsetCents = 0   // portamento turned off mid-glide → snap to target
                    }
                    glideFactor = exp2f(voicesDX7[i].glideOffsetCents / 1200.0)
                }

                // Compute combined pitch factor including per-note pitch bend and global tuning
                let pnpbFactor = voicesDX7[i].perNotePitchBendFactor
                let tuningFactor = totalTuningOffset != 0 ? pitchBendFactorExt(totalTuningOffset) : 1.0
                if sm.hasPitchMod || pnpbFactor != 1.0 || tuningFactor != 1.0 || pitchEGSemitones != 0 || wasGliding {
                    let slot = snapshot.slot(at: s)
                    // Mod wheel / foot / breath / aftertouch assigned to pitch scale the
                    // LFO vibrato DEPTH — they add vibrato, not a static pitch bend.
                    let controllerPitchMod = voicesDX7[i].detached ? 0
                        : (sm.wheelPitchDepth + sm.footPitchDepth + sm.breathPitchDepth + sm.atPitchDepth)
                    let lfoPitch = lfoCurrentValue[s] * (Float(slot.lfoPMD) / 99.0 + controllerPitchMod) * sm.pmsDepth
                    // Detached (per-note-managed) voices ignore channel-wide pitch bend.
                    let chanBend = voicesDX7[i].detached ? Float(1.0) : pitchBendValueBySlot[s]
                    let factor = chanBend * pitchBendFactorExt(lfoPitch + pitchEGSemitones) * pnpbFactor * tuningFactor * glideFactor
                    voicesDX7[i].applyPitchBend(factor)
                }

                // Amp mod — skip global controllers for detached voices
                let lfoUni = (lfoCurrentValue[s] + 1.0) * 0.5
                let lfoAtten = 1.0 - lfoUni
                let amdDepth = lfoAtten * slotMods[s].lfoAMDNorm
                let controllerAmd: Float = voicesDX7[i].detached ? 0.0 : (1.0 - slotMods[s].controllerAmpMod)
                let totalAmd = (amdDepth + controllerAmd) * 12.0
                var lfoAmpModVal = Int32(totalAmd * Float(1 << 24))

                // Per-note volume attenuation in log domain
                let pnVol = voicesDX7[i].perNoteVolume
                if pnVol < 1.0 {
                    let safeVol = pnVol < 0.001 ? 0.001 : pnVol
                    let volAtten = -logf(safeVol) * Float(1 << 24) / 0.6931471805599453 // log(2)
                    lfoAmpModVal = lfoAmpModVal &+ Int32(volAtten)
                }
                voicesDX7[i].lfoAmpMod = lfoAmpModVal
            }

            for i in 0..<maxV {
                guard voicesDX7[i].active else { continue }
                voicesDX7[i].updateGains()
            }

            let outBufL = bufferL + offset
            let outBufR = bufferR + offset
            for s in 0..<blockSize { outBufL[s] = 0; outBufR[s] = 0 }

            for i in 0..<maxV {
                guard voicesDX7[i].active else { continue }
                for s in 0..<blockSize { blockBuf[s] = 0 }
                voicesDX7[i].renderBlock(output: blockBuf, bus1: bus1, bus2: bus2, blockSize: blockSize)

                let pL = panGainL[i]
                let pR = panGainR[i]
                let slotGain = snapshot.config(at: voicesDX7[i].slotId).gain
                // DEXED normalizes Q24 output as: >> 4, >> 9, / 32768 = / 2^28.
                // Previous /2^25 was 8× too hot, clipping on multi-carrier algorithms.
                let scale = vol * pL / 268435456.0 * slotGain
                let scaleR = vol * pR / 268435456.0 * slotGain
                for s in 0..<blockSize {
                    let sample = Float(blockBuf[s])
                    outBufL[s] += sample * scale
                    outBufR[s] += sample * scaleR
                }
            }

            // No hard clipping here — let the FX chain's Maximizer
            // (look-ahead peak limiter) handle peak limiting gracefully.

            offset += blockSize
        }
    }

    // MARK: - MIDI Handling

    private func doNoteOn(_ note: UInt8, velocity16: UInt16) {
        let snapshot = currentSnapshot
        voiceStackNoteOnCounter &+= 1   // #89-detune: re-roll random spread each note-on
        // #79: capture the previous note BEFORE this note-on overwrites it, so
        // every voice seeded below glides from the last-played note.
        let glidePrev = previousNoteForGlide
        var anyVoiceTriggered = false   // only an AUDIBLE note becomes the next glide anchor

        // Fixed-size slot target buffer — no heap allocation
        var targetSlots: (Int, Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0, 0)
        var targetCount = 0
        determineTargetSlots(note: note, snapshot: snapshot, result: &targetSlots, count: &targetCount)

        for ti in 0..<targetCount {
            let slotIdx: Int
            switch ti {
            case 0: slotIdx = targetSlots.0; case 1: slotIdx = targetSlots.1
            case 2: slotIdx = targetSlots.2; case 3: slotIdx = targetSlots.3
            case 4: slotIdx = targetSlots.4; case 5: slotIdx = targetSlots.5
            case 6: slotIdx = targetSlots.6; case 7: slotIdx = targetSlots.7
            default: continue
            }
            guard slotIdx < snapshot.activeSlotCount else { continue }
            let slot = snapshot.slot(at: slotIdx)
            let config = snapshot.config(at: slotIdx)
            guard config.enabled else { continue }

            if slot.lfoSync == 1 {
                lfoPhase[slotIdx] = 0; lfoDelayFadeIn[slotIdx] = 0
            }

            let unisonCount = max(1, snapshot.unisonCount)
            let unisonDetune = snapshot.unisonDetune
            let voiceStack = max(1, snapshot.voiceStackMultiplier)   // #89
            let stackDetune = snapshot.voiceStackDetune              // #89-detune
            let stackMode = snapshot.voiceStackDetuneMode            // 0 even, 1 random
            let stackNote = voiceStackNoteOnCounter                  // captured once for this note-on

            for s in 0..<voiceStack {                                // #89-detune: `s` identifies the stack copy
                // #89-detune: per-copy spread. 1.0 when single copy or detune off
                // (keeps detune=0 byte-identical to the legacy identical stack).
                let stackFactor: Float = (voiceStack < 2 || stackDetune == 0) ? 1.0
                    : (stackMode == 0
                        ? unisonDetuneFactor(index: s, count: voiceStack, detuneCents: stackDetune)
                        : voiceStackDetuneFactorRandom(noteOnIndex: stackNote, copyIndex: s, detuneCents: stackDetune))
                for u in 0..<unisonCount {
                // #83: even spread (default, bit-identical) or deterministic random.
                let unisonFactor = snapshot.unisonDetuneMode == 0
                    ? unisonDetuneFactor(index: u, count: unisonCount, detuneCents: unisonDetune)
                    : unisonDetuneFactorRandom(slotIndex: slotIdx, voiceIndex: u, detuneCents: unisonDetune)
                let detuneFactor = unisonFactor * stackFactor        // #89-detune: combine unison × stack

                let transposedNote = UInt8(clamping: Int(note) + Int(slot.transpose))
                let maxV = effectiveMaxVoices

                var target = 0
                var foundFree = false
                for i in 0..<maxV {
                    voicesDX7[i].checkActive()
                    if !voicesDX7[i].active { target = i; foundFree = true; break }
                }
                if !foundFree && unisonCount == 1 && voiceStack == 1 {   // #89: no retrigger-collapse while stacking — steal instead so N distinct voices survive a full pool
                    for i in 0..<maxV {
                        if voicesDX7[i].midiNote == note && voicesDX7[i].slotId == slotIdx {
                            target = i; foundFree = true; break
                        }
                    }
                }
                if !foundFree {
                    target = dx7VoiceStealIdx % maxV
                    dx7VoiceStealIdx += 1
                }

                voicesDX7[target].algorithm = slot.algorithm
                voicesDX7[target].engineMode = currentFMEngine
                voicesDX7[target].slotId = slotIdx
                // #76: capture a deterministic random pan at note-on (random mode).
                if snapshot.config(at: slotIdx).panRandom {
                    voicesDX7[target].pan = layerPanRandom(slotIndex: slotIdx, voiceIndex: u)
                }
                voicesDX7[target].feedbackShiftValue = feedbackShift(Int(slot.ops.0.feedback * 7.0 + 0.5))

                voicesDX7[target].applyParams(slot.ops.0, opIndex: 0)
                voicesDX7[target].applyParams(slot.ops.1, opIndex: 1)
                voicesDX7[target].applyParams(slot.ops.2, opIndex: 2)
                voicesDX7[target].applyParams(slot.ops.3, opIndex: 3)
                voicesDX7[target].applyParams(slot.ops.4, opIndex: 4)
                voicesDX7[target].applyParams(slot.ops.5, opIndex: 5)

                voicesDX7[target].noteOn(transposedNote, velocity16: velocity16, midiNote: note, detuneFactor: detuneFactor)
                // #79 portamento (Poly/Always): start at the previous note's pitch
                // and glide to target. Slot transpose cancels (prev and note share
                // it). Set explicitly every note-on so a reused voice never keeps a
                // stale offset; 0 when off or on the first note (no glide).
                voicesDX7[target].glideOffsetCents = (snapshot.portamentoEnabled != 0)
                    ? Float(Int(glidePrev ?? note) - Int(note)) * 100.0
                    : 0
                anyVoiceTriggered = true

                // Master tuning is applied per-block in renderFramesDX7 alongside RPN
                // fine/coarse tuning, so it takes effect immediately on held notes
                // rather than only at note-on. (kTuningLUT in FrequencyTable.swift is now
                // unused; left in place pending a separate cleanup.)

                // Per-operator velocity/KLS/AMS/rateScaling
                for opIdx in 0..<6 {
                    let opSnap: OperatorSnapshot
                    switch opIdx {
                    case 0: opSnap = slot.ops.0
                    case 1: opSnap = slot.ops.1
                    case 2: opSnap = slot.ops.2
                    case 3: opSnap = slot.ops.3
                    case 4: opSnap = slot.ops.4
                    case 5: opSnap = slot.ops.5
                    default: continue
                    }

                    voicesDX7[target].withOp(opIdx) { op in
                        op.velocityOffset = scaleVelocity(velocity16, sens: Int(opSnap.velocitySensitivity))
                        op.klsOffset = scaleKeyboardLevel(
                            transposedNote, breakPoint: opSnap.klsBreakPoint,
                            leftDepth: opSnap.klsLeftDepth, rightDepth: opSnap.klsRightDepth,
                            leftCurve: opSnap.klsLeftCurve, rightCurve: opSnap.klsRightCurve
                        )
                        op.amsDepth = kAMSDepthQ24[Int(min(opSnap.ampModSensitivity, 3))]
                        let scaledOL = scaleOutputLevel(op.outputLevel)
                        op.env.outlevel = max(0, (min(127, scaledOL + op.klsOffset) << 5) + op.velocityOffset)
                        op.env.recalcTargetLevel()
                        op.isFixedFreq = opSnap.fixedFrequency != 0
                        if op.isFixedFreq {
                            let fixedHz = fixedFreqHz(coarse: opSnap.fixedFreqCoarse, fine: opSnap.fixedFreqFine) * detuneFactor
                            op.baseFrequency = fixedHz / (op.ratio * op.detune)
                            op.frequency = fixedHz
                            op.updateFreqPublic()
                        }
                        op.env.rateScaling = keyboardRateScaling(note: transposedNote, scaling: opSnap.keyboardRateScaling)
                        // rateScaling is set after env.noteOn() computed the attack inc,
                        // so recompute the current stage's increment (matching DEXED,
                        // which applies rate scaling before eg_note_on). Mirrors the
                        // recalcTargetLevel() fixup above for the level.
                        op.env.recalcCurrentInc()
                    }
                }

                // Pitch EG
                voicesDX7[target].pitchEG.noteOn(
                    r0: slot.pitchEGR0, r1: slot.pitchEGR1,
                    r2: slot.pitchEGR2, r3: slot.pitchEGR3,
                    l0: slot.pitchEGL0, l1: slot.pitchEGL1,
                    l2: slot.pitchEGL2, l3: slot.pitchEGL3,
                    sampleRate: sampleRate)

                let bendFactor = pitchBendValueBySlot[slotIdx]
                if bendFactor != 1.0 {
                    voicesDX7[target].applyPitchBend(bendFactor)
                }
            }
            }
        }
        // #79: anchor the next glide to the last AUDIBLE note only — a note that
        // triggered no voice (e.g. a coverage gap from a disabled slot) must not
        // become the glide start, or the next note would glide from an unheard pitch.
        if anyVoiceTriggered { previousNoteForGlide = note }
    }

    /// Determine target slots without heap allocation. Results written to fixed-size tuple.
    private func determineTargetSlots(
        note: UInt8, snapshot: SynthParamSnapshot,
        result: inout (Int, Int, Int, Int, Int, Int, Int, Int),
        count: inout Int
    ) {
        count = 0
        let mode = TimbreMode(rawValue: snapshot.timbreMode) ?? .single
        switch mode {
        case .single:
            result.0 = 0; count = 1
        case .dual:
            for i in 0..<snapshot.activeSlotCount {
                appendTarget(i, to: &result, count: &count)
            }
        case .split:
            for i in 0..<snapshot.activeSlotCount {
                let cfg = snapshot.config(at: i)
                if cfg.enabled && note >= cfg.noteRangeLow && note <= cfg.noteRangeHigh {
                    appendTarget(i, to: &result, count: &count)
                }
            }
        case .tx816:
            // NOTE: true per-part MIDI-channel routing (SlotConfig.midiChannel) is
            // Phase 4 and not yet implemented — MIDIEvent carries no channel, so a
            // note currently layers across every enabled slot rather than being
            // routed to the slot whose midiChannel matches.
            for i in 0..<snapshot.activeSlotCount {
                if snapshot.config(at: i).enabled {
                    appendTarget(i, to: &result, count: &count)
                }
            }
        case .layer:
            // Layer mode routes every played note to all enabled slots (stacking
            // patches across the voice pool). Same fan-out as tx816 today.
            for i in 0..<snapshot.activeSlotCount where snapshot.config(at: i).enabled {
                appendTarget(i, to: &result, count: &count)
            }
        }
    }

    @inline(__always)
    private func appendTarget(_ value: Int, to tuple: inout (Int, Int, Int, Int, Int, Int, Int, Int), count: inout Int) {
        switch count {
        case 0: tuple.0 = value; case 1: tuple.1 = value
        case 2: tuple.2 = value; case 3: tuple.3 = value
        case 4: tuple.4 = value; case 5: tuple.5 = value
        case 6: tuple.6 = value; case 7: tuple.7 = value
        default: return
        }
        count += 1
    }

    private func doNoteOff(_ note: UInt8) {
        for i in 0..<kMaxVoices {
            if voicesDX7[i].active && voicesDX7[i].midiNote == note {
                voicesDX7[i].noteOff(held: sustainPedalOn)
                if !sustainPedalOn {
                    voicesDX7[i].pitchEG.noteOff(sampleRate: sampleRate)
                }
            }
        }
    }

    private func doControlChange(_ cc: UInt8, value32: UInt32) {
        switch cc {
        case 1: modWheelDepth = Float(value32) / Float(UInt32.max)
        case 2: breathDepth = Float(value32) / Float(UInt32.max)
        case 4: footDepth = Float(value32) / Float(UInt32.max)
        case 7: ccVolume = Float(value32) / Float(UInt32.max)
        case 11: expression = Float(value32) / Float(UInt32.max)
        case 64:
            let on = value32 >= 0x40000000
            sustainPedalOn = on
            if !on {
                let sr = sampleRate
                for i in 0..<kMaxVoices {
                    // Release the pitch EG too for voices held only by the pedal —
                    // releaseSustain() releases the amp EGs but not the pitch EG.
                    if voicesDX7[i].sustained {
                        voicesDX7[i].pitchEG.noteOff(sampleRate: sr)
                    }
                    voicesDX7[i].releaseSustain()
                }
            }
        case 123: doAllNotesOff()
        default: break
        }
    }

    @inline(__always)
    private func effectivePitchBendRange(forSlot s: Int) -> Float {
        let override = rpnPitchBendRangeOverride
        if override != 0 { return Float(override) }
        return Float(currentSnapshot.slot(at: s).pitchBendRange)
    }

    private func doPitchBend32(_ value: UInt32) {
        let signed = Int64(value) - 0x80000000
        let normalized = Float(signed) / Float(0x80000000)
        // Pre-compute factor per slot using each slot's own SlotSnapshot.pitchBendRange,
        // so TX816 / dual / split honor per-slot bend range. RPN override (if set) wins
        // for all slots.
        for s in 0..<kMaxSlots {
            let semitones = normalized * effectivePitchBendRange(forSlot: s)
            pitchBendValueBySlot[s] = pitchBendFactorExt(semitones)
        }
        for i in 0..<kMaxVoices where voicesDX7[i].active && !voicesDX7[i].detached {
            voicesDX7[i].applyPitchBend(pitchBendValueBySlot[voicesDX7[i].slotId])
        }
    }

    private func doAllNotesOff() {
        sustainPedalOn = false
        for i in 0..<kMaxVoices {
            voicesDX7[i].sustained = false
            voicesDX7[i].noteOff()
        }
    }

    // MARK: - MIDI 2.0 Handlers

    private func doChannelPressure(_ value32: UInt32) {
        aftertouchDepth = Float(value32) / Float(UInt32.max)
    }

    private func doPolyPressure(_ note: UInt8, value32: UInt32) {
        // NOTE: perNoteAftertouch is captured per-voice but not yet routed into the
        // synthesis (no per-voice aftertouch->pitch/amp mapping yet). Stored for a
        // future per-note expression path; currently this handler has no audible
        // effect. (Channel aftertouch IS wired via doChannelPressure.)
        let depth = Float(value32) / Float(UInt32.max)
        for i in 0..<kMaxVoices where voicesDX7[i].active && voicesDX7[i].midiNote == note {
            voicesDX7[i].perNoteAftertouch = depth
        }
    }

    private func doPerNotePitchBend(_ note: UInt8, value32: UInt32) {
        let signed = Int32(bitPattern: value32 &- 0x80000000)
        let normalized = Float(signed) / Float(0x80000000)
        for i in 0..<kMaxVoices where voicesDX7[i].active && voicesDX7[i].midiNote == note {
            let semitones = normalized * effectivePitchBendRange(forSlot: voicesDX7[i].slotId)
            voicesDX7[i].perNotePitchBendFactor = pitchBendFactorExt(semitones)
        }
    }

    private func doPerNoteCC(_ note: UInt8, index: UInt8, value: UInt32) {
        let normalized = Float(value) / Float(0x00FFFFFF)
        for i in 0..<kMaxVoices where voicesDX7[i].active && voicesDX7[i].midiNote == note {
            switch index {
            case 7: voicesDX7[i].perNoteVolume = normalized
            default: break
            }
        }
    }

    private func doPerNoteManagement(_ note: UInt8, flags: UInt32) {
        let detach = (flags & 0x02) != 0
        let reset = (flags & 0x01) != 0
        for i in 0..<kMaxVoices where voicesDX7[i].active && voicesDX7[i].midiNote == note {
            if reset {
                // Reset per-note controllers only; the pitch EG keeps running.
                voicesDX7[i].resetPerNoteControllers()
            }
            if detach {
                voicesDX7[i].detached = true
                // Detached voices ignore channel bend; remove any already-applied
                // channel bend NOW (apply the per-note-only factor) so the pitch is
                // deterministic — the per-block gate may not fire again to do it.
                voicesDX7[i].applyPitchBend(voicesDX7[i].perNotePitchBendFactor)
            }
        }
    }

    private func doRPN(_ bank: UInt8, index: UInt8, value: UInt32) {
        switch (bank, index) {
        case (0, 0): // Pitch Bend Range — audio-local override (do NOT touch shadowSnapshot from render thread)
            let semitones = UInt8(value >> 17)  // top 7 bits of 24-bit value
            rpnPitchBendRangeOverride = max(1, min(24, semitones))
        case (0, 1): // Fine Tuning — center 0x800000 = 0 cents, range ±100
            let signed = Int32(bitPattern: (value << 8) &- 0x80000000)
            rpnFineTuningCents = Float(signed) / Float(0x80000000) * 100.0
        case (0, 2): // Coarse Tuning — center 0x800000 = 0 semitones, range ±64
            let signed = Int32(bitPattern: (value << 8) &- 0x80000000)
            rpnCoarseTuningSemitones = Float(signed) / Float(0x80000000) * 64.0
        default: break
        }
    }

    private func doNRPN(_ bank: UInt8, index: UInt8, value: UInt32) {
        // Vendor-specific: reserved for future use
    }
}
