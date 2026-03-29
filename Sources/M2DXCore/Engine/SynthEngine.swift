// SynthEngine.swift
// M2DX-Core — DX7 FM Synthesis Engine (voice management, render, MIDI)

import Darwin

// MARK: - Oversampling Mode

public enum OversamplingMode: UInt8, Sendable, CaseIterable {
    case off = 0
    case highQuality = 1
    case lowCPU = 2
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

    private var shadowSnapshot = SynthParamSnapshot()
    private let snapshotRing = SnapshotRing<SynthParamSnapshot>(capacity: 64)
    private var currentSnapshot = SynthParamSnapshot()

    private let downsampler = Downsampler()
    private var currentOversamplingMode: OversamplingMode = .off

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
    private var algorithm: Int = 0
    private var sustainPedalOn: Bool = false
    private var pitchBendValue: Float = 1.0
    private var modWheelDepth: Float = 0
    private var footDepth: Float = 0
    private var breathDepth: Float = 0
    private var aftertouchDepth: Float = 0

    // RPN tuning state
    private var rpnFineTuningCents: Float = 0
    private var rpnCoarseTuningSemitones: Float = 0

    // LFO state
    private var lfoPhase: [Float] = Array(repeating: 0, count: kMaxSlots)
    private var lfoCurrentValue: [Float] = Array(repeating: 0, count: kMaxSlots)
    private var lfoDelayFadeIn: [Float] = Array(repeating: 0, count: kMaxSlots)
    private var lfoSHValue: [Float] = Array(repeating: 0, count: kMaxSlots)

    private var currentTimbreMode: TimbreMode = .single
    private var effectiveMaxVoices: Int = 16
    private var dx7VoiceStealIdx: Int = 0

    // Pan gains
    private var panGainL: UnsafeMutablePointer<Float> = .allocate(capacity: kMaxVoices)
    private var panGainR: UnsafeMutablePointer<Float> = .allocate(capacity: kMaxVoices)

    // Scratch buffers for block processing
    private let dx7BlockBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
    private let dx7Bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
    private let dx7Bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
    private let floatScratch = UnsafeMutablePointer<Float>.allocate(capacity: kBlockSize)

    // Lock-free MIDI event ring buffer (SPSC FIFO)
    private let midiRing = SPSCRing<MIDIEvent>(capacity: 256)

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
    }

    // MARK: - MIDI Event Queue

    /// Enqueue a MIDI event (UI thread). Lock-free, allocation-free.
    public func sendMIDI(_ event: MIDIEvent) {
        midiRing.push(event)
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
        shadowSnapshot.sampleRate = sr
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
        withShadowOp(0) { $0.feedback = Float(fb) / 7.0 }
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

    // MARK: - Split Point / Slot Control

    public func setSplitPoint(_ note: UInt8) {
        shadowSnapshot.splitPoint = note
        let mode = TimbreMode(rawValue: shadowSnapshot.timbreMode) ?? .single
        if mode == .split {
            shadowSnapshot.setConfig(at: 0, SlotConfig(noteRangeLow: 0, noteRangeHigh: note > 0 ? note - 1 : 0))
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
        if level <= 0 { ol = 0 }
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
        withShadowOp(opIndex) {
            $0.dx7EgR0 = Int(r1); $0.dx7EgR1 = Int(r2)
            $0.dx7EgR2 = Int(r3); $0.dx7EgR3 = Int(r4)
        }
        bumpVersion()
    }

    /// Set operator EG levels from normalized Float (0.0-1.0).
    /// Converts to DX7 level (0-99) internally.
    public func setOperatorEGLevels(_ opIndex: Int, l1: Float, l2: Float, l3: Float, l4: Float) {
        guard opIndex >= 0, opIndex < kNumOperators else { return }
        withShadowOp(opIndex) {
            $0.dx7EgL0 = Int(l1 * 99); $0.dx7EgL1 = Int(l2 * 99)
            $0.dx7EgL2 = Int(l3 * 99); $0.dx7EgL3 = Int(l4 * 99)
        }
        bumpVersion()
    }

    /// Set per-operator feedback from Float.
    /// DX7 has global feedback; this sets on the algorithm's feedback operator.
    public func setOperatorFeedback(_ opIndex: Int, feedback: Float) {
        // Convert float feedback gain to DX7 integer (0-7)
        let fb: Int
        if feedback <= 0 { fb = 0 }
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

        // Copy slot 0 to any new slots
        for i in shadowSnapshot.activeSlotCount..<slotCount {
            shadowSnapshot.setSlot(at: i, baseSlot)
        }
        shadowSnapshot.activeSlotCount = slotCount

        switch mode {
        case .single:
            shadowSnapshot.setConfig(at: 0, SlotConfig())
        case .dual:
            shadowSnapshot.setConfig(at: 0, SlotConfig())
            shadowSnapshot.setConfig(at: 1, SlotConfig())
        case .split:
            shadowSnapshot.setConfig(at: 0, SlotConfig(noteRangeLow: 0, noteRangeHigh: splitPoint > 0 ? splitPoint - 1 : 0))
            shadowSnapshot.setConfig(at: 1, SlotConfig(noteRangeLow: splitPoint, noteRangeHigh: 127))
        case .tx816:
            for i in 0..<8 {
                shadowSnapshot.setConfig(at: i, SlotConfig(midiChannel: UInt8(i)))
            }
        }
        bumpVersion()
    }

    public func loadSlotParams(_ slotIdx: Int, slot: SlotSnapshot, resetControllers: Bool = true) {
        guard slotIdx >= 0, slotIdx < shadowSnapshot.activeSlotCount else { return }
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
        snapshotRing.pushLatest(shadowSnapshot)
    }

    /// Reset all MIDI controller state to defaults.
    /// Call when switching presets to clear stale CC values.
    public func resetControllers() {
        modWheelDepth = 0
        footDepth = 0
        breathDepth = 0
        aftertouchDepth = 0
        pitchBendValue = 1.0
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
                downsampler.beginTransition(sampleRate: baseSampleRate)
            } else if snapshot.sampleRate != baseSampleRate {
                baseSampleRate = snapshot.sampleRate
                let factor: Float = (currentOversamplingMode == .off) ? 1.0 : 2.0
                sampleRate = baseSampleRate * factor
                for i in 0..<kMaxVoices { voicesDX7[i].setSampleRate(sampleRate) }
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
            }
            effectiveMaxVoices = (currentOversamplingMode == .off) ? voicesForMode : max(8, voicesForMode / 2)

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
            let osFrameCount = min(frameCount * 2, 2048)
            let actualOutput = osFrameCount / 2
            let osL = downsampler.oversampledL
            let osR = downsampler.oversampledR
            osL.initialize(repeating: 0, count: osFrameCount)
            osR.initialize(repeating: 0, count: osFrameCount)
            renderFramesDX7(osL, osR, osFrameCount, snapshot)

            switch currentOversamplingMode {
            case .highQuality:
                downsampler.downsampleHalfband(
                    srcL: UnsafePointer(osL), srcR: UnsafePointer(osR),
                    dstL: bufferL, dstR: bufferR,
                    oversampledCount: osFrameCount, outputCount: actualOutput)
            case .lowCPU:
                downsampler.downsamplePolyphase(
                    srcL: UnsafePointer(osL), srcR: UnsafePointer(osR),
                    dstL: bufferL, dstR: bufferR,
                    oversampledCount: osFrameCount, outputCount: actualOutput)
            case .off: break
            }

            if actualOutput < frameCount {
                memset(bufferL.advanced(by: actualOutput), 0,
                       (frameCount - actualOutput) * MemoryLayout<Float>.size)
                memset(bufferR.advanced(by: actualOutput), 0,
                       (frameCount - actualOutput) * MemoryLayout<Float>.size)
            }

            downsampler.applyCrossfade(bufferL: bufferL, bufferR: bufferR, frameCount: frameCount)
        }
    }

    // MARK: - LFO

    private static func lfoSpeedToHz(_ speed: UInt8) -> Float {
        0.06 * expf(Float(speed) * 0.0693)
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

    private func updateLFOForSlot(_ slotIdx: Int, _ slot: SlotSnapshot) {
        let lfoHz = Self.lfoSpeedToHz(slot.lfoSpeed)
        let lfoInc = lfoHz / sampleRate * Float(kBlockSize)

        lfoPhase[slotIdx] += lfoInc
        if lfoPhase[slotIdx] >= 1.0 {
            lfoPhase[slotIdx] -= 1.0
            if slot.lfoWaveform == 5 {
                lfoSHValue[slotIdx] = Float.random(in: -1...1)
            }
        }

        lfoCurrentValue[slotIdx] = lfoWaveformValue(lfoPhase[slotIdx], waveform: slot.lfoWaveform, slotIdx: slotIdx)

        if slot.lfoDelay > 0 && lfoDelayFadeIn[slotIdx] < 1.0 {
            let delayTime = 0.01 * expf(Float(slot.lfoDelay) * 0.069)
            let fadeInc = Float(kBlockSize) / (delayTime * sampleRate)
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
        let vol = masterVolume * expression
        let maxV = effectiveMaxVoices
        let slotCount = snapshot.activeSlotCount

        for i in 0..<maxV { voicesDX7[i].checkActive() }

        // Per-slot modulation
        struct SlotMod {
            var pmsDepth: Float = 0
            var hasPitchMod: Bool = false
            var wheelPitchDepth: Float = 0
            var footPitchDepth: Float = 0
            var breathPitchDepth: Float = 0
            var atPitchDepth: Float = 0
            var controllerAmpMod: Float = 1.0
            var lfoAMDNorm: Float = 0
        }
        var slotMods = [SlotMod](repeating: SlotMod(), count: slotCount)
        for s in 0..<slotCount {
            let slot = snapshot.slot(at: s)
            slotMods[s].pmsDepth = kPMSDepth[Int(min(slot.lfoPMS, 7))]
            slotMods[s].hasPitchMod = slot.lfoPMD > 0 || modWheelDepth > 0.001
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

        let c: Float = 0.70710678
        for i in 0..<maxV { panGainL[i] = c; panGainR[i] = c }

        let blockBuf = dx7BlockBuf
        let bus1 = dx7Bus1
        let bus2 = dx7Bus2
        var offset = 0

        while offset < frameCount {
            let blockSize = min(kBlockSize, frameCount - offset)

            for s in 0..<slotCount {
                updateLFOForSlot(s, snapshot.slot(at: s))
            }

            // RPN tuning offset (semitones), computed once per block
            let rpnTuningOffset = rpnFineTuningCents / 100.0 + rpnCoarseTuningSemitones

            for i in 0..<maxV {
                guard voicesDX7[i].active else { continue }
                let s = voicesDX7[i].slotId
                guard s < slotCount else { continue }
                let sm = slotMods[s]

                // Compute combined pitch factor including per-note pitch bend and RPN tuning
                let pnpbFactor = voicesDX7[i].perNotePitchBendFactor
                let rpnFactor = rpnTuningOffset != 0 ? pitchBendFactorExt(rpnTuningOffset) : 1.0
                if sm.hasPitchMod || pnpbFactor != 1.0 || rpnFactor != 1.0 {
                    let slot = snapshot.slot(at: s)
                    let lfoPitch = lfoCurrentValue[s] * Float(slot.lfoPMD) / 99.0 * sm.pmsDepth
                    let controllerPitch: Float
                    if voicesDX7[i].detached {
                        controllerPitch = 0
                    } else {
                        controllerPitch = sm.wheelPitchDepth + sm.footPitchDepth + sm.breathPitchDepth + sm.atPitchDepth
                    }
                    let factor = pitchBendValue * pitchBendFactorExt(lfoPitch + controllerPitch) * pnpbFactor * rpnFactor
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
                // DEXED normalizes Q24 output as: >> 4, >> 9, / 32768 = / 2^28.
                // Previous /2^25 was 8× too hot, clipping on multi-carrier algorithms.
                let scale = vol * pL / 268435456.0
                let scaleR = vol * pR / 268435456.0
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

            let transposedNote = UInt8(clamping: Int(note) + Int(slot.transpose))
            let maxV = effectiveMaxVoices

            var target = 0
            var foundFree = false
            for i in 0..<maxV {
                voicesDX7[i].checkActive()
                if !voicesDX7[i].active { target = i; foundFree = true; break }
            }
            if !foundFree {
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
            voicesDX7[target].slotId = slotIdx
            voicesDX7[target].feedbackShiftValue = feedbackShift(Int(slot.ops.0.feedback * 7.0 + 0.5))

            voicesDX7[target].applyParams(slot.ops.0, opIndex: 0)
            voicesDX7[target].applyParams(slot.ops.1, opIndex: 1)
            voicesDX7[target].applyParams(slot.ops.2, opIndex: 2)
            voicesDX7[target].applyParams(slot.ops.3, opIndex: 3)
            voicesDX7[target].applyParams(slot.ops.4, opIndex: 4)
            voicesDX7[target].applyParams(slot.ops.5, opIndex: 5)

            voicesDX7[target].noteOn(transposedNote, velocity16: velocity16, midiNote: note)

            // Master tuning
            if snapshot.masterTuning != 0 {
                let tuningIdx = Int(snapshot.masterTuning) + 100
                let tuningFactor = kTuningLUT[max(0, min(200, tuningIdx))]
                for opIdx in 0..<6 {
                    voicesDX7[target].withOp(opIdx) { op in
                        let freq = op.baseFrequency * op.ratio * op.detune * tuningFactor
                        op.frequency = freq
                        op.updateFreqPublic()
                    }
                }
            }

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
                        let fixedHz = fixedFreqHz(coarse: opSnap.fixedFreqCoarse, fine: opSnap.fixedFreqFine)
                        op.baseFrequency = fixedHz / (op.ratio * op.detune)
                        op.frequency = fixedHz
                        op.updateFreqPublic()
                    }
                    op.env.rateScaling = keyboardRateScaling(note: transposedNote, scaling: opSnap.keyboardRateScaling)
                }
            }

            if pitchBendValue != 1.0 {
                voicesDX7[target].applyPitchBend(pitchBendValue)
            }
        }
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
            for i in 0..<snapshot.activeSlotCount {
                if snapshot.config(at: i).enabled {
                    appendTarget(i, to: &result, count: &count)
                }
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
            }
        }
    }

    private func doControlChange(_ cc: UInt8, value32: UInt32) {
        switch cc {
        case 1: modWheelDepth = Float(value32) / Float(UInt32.max)
        case 2: breathDepth = Float(value32) / Float(UInt32.max)
        case 4: footDepth = Float(value32) / Float(UInt32.max)
        case 7: masterVolume = Float(value32) / Float(UInt32.max)
        case 11: expression = Float(value32) / Float(UInt32.max)
        case 64:
            let on = value32 >= 0x40000000
            sustainPedalOn = on
            if !on {
                for i in 0..<kMaxVoices { voicesDX7[i].releaseSustain() }
            }
        case 123: doAllNotesOff()
        default: break
        }
    }

    private func doPitchBend32(_ value: UInt32) {
        let signed = Int64(value) - 0x80000000
        let range = Float(currentSnapshot.pitchBendRange)
        let semitones = Float(signed) / Float(0x80000000) * range
        pitchBendValue = pitchBendFactorExt(semitones)
        for i in 0..<kMaxVoices {
            if voicesDX7[i].active { voicesDX7[i].applyPitchBend(pitchBendValue) }
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
        let depth = Float(value32) / Float(UInt32.max)
        for i in 0..<kMaxVoices where voicesDX7[i].active && voicesDX7[i].midiNote == note {
            voicesDX7[i].perNoteAftertouch = depth
        }
    }

    private func doPerNotePitchBend(_ note: UInt8, value32: UInt32) {
        let range = Float(currentSnapshot.pitchBendRange)
        let signed = Int32(bitPattern: value32 &- 0x80000000)
        let semitones = Float(signed) / Float(0x80000000) * range
        let factor = pitchBendFactorExt(semitones)
        for i in 0..<kMaxVoices where voicesDX7[i].active && voicesDX7[i].midiNote == note {
            voicesDX7[i].perNotePitchBendFactor = factor
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
                voicesDX7[i].resetPerNoteState()
                if detach { voicesDX7[i].detached = true }
            } else if detach {
                voicesDX7[i].detached = true
            }
        }
    }

    private func doRPN(_ bank: UInt8, index: UInt8, value: UInt32) {
        switch (bank, index) {
        case (0, 0): // Pitch Bend Range
            let semitones = UInt8(value >> 17)  // top 7 bits of 24-bit value
            shadowSnapshot.pitchBendRange = max(1, min(24, semitones))
            bumpVersion()
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
