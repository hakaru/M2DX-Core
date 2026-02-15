// SynthEngine.swift
// M2DX-Core — DX7 FM Synthesis Engine (voice management, render, MIDI)

import Foundation
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

    // MIDI event ring buffer
    private var midiEvents: [MIDIEvent] = []
    private let midiLock = NSLock()

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
    }

    // MARK: - MIDI Event Queue

    /// Enqueue a MIDI event (UI thread).
    public func sendMIDI(_ event: MIDIEvent) {
        midiLock.lock()
        midiEvents.append(event)
        midiLock.unlock()
    }

    private func drainMIDI() {
        midiLock.lock()
        let events = midiEvents
        midiEvents.removeAll(keepingCapacity: true)
        midiLock.unlock()

        for event in events {
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
            }
        }
    }

    // MARK: - UI Thread Parameter Setters

    @inline(__always)
    private func bumpVersion() {
        shadowSnapshot.version &+= 1
        snapshotRing.pushLatest(shadowSnapshot)
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

    public func setTimbreMode(_ mode: TimbreMode, splitPoint: UInt8 = 60) {
        shadowSnapshot.timbreMode = mode.rawValue
        shadowSnapshot.splitPoint = splitPoint
        let slotCount = mode.slotCount
        let baseSlot = shadowSnapshot.slots[0]
        while shadowSnapshot.slots.count < slotCount {
            shadowSnapshot.slots.append(baseSlot)
        }
        shadowSnapshot.slots = Array(shadowSnapshot.slots.prefix(slotCount))

        switch mode {
        case .single:
            shadowSnapshot.slotConfigs = [SlotConfig()]
        case .dual:
            shadowSnapshot.slotConfigs = [SlotConfig(), SlotConfig()]
        case .split:
            shadowSnapshot.slotConfigs = [
                SlotConfig(noteRangeLow: 0, noteRangeHigh: splitPoint > 0 ? splitPoint - 1 : 0),
                SlotConfig(noteRangeLow: splitPoint, noteRangeHigh: 127)
            ]
        case .tx816:
            shadowSnapshot.slotConfigs = (0..<8).map { SlotConfig(midiChannel: UInt8($0)) }
        }
        bumpVersion()
    }

    package func loadSlotParams(_ slotIdx: Int, slot: SlotSnapshot) {
        guard slotIdx >= 0, slotIdx < shadowSnapshot.slots.count else { return }
        shadowSnapshot.slots[slotIdx] = slot
        bumpVersion()
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
        // Pop latest snapshot
        if let newSnapshot = snapshotRing.popLatest() {
            currentSnapshot = newSnapshot
        }
        let snapshot = currentSnapshot

        // Apply parameter changes
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

            for i in 0..<kMaxVoices {
                let slotIdx = voicesDX7[i].slotId
                let slot = slotIdx < snapshot.slots.count ? snapshot.slots[slotIdx] : snapshot.slots[0]
                voicesDX7[i].algorithm = slot.algorithm
                voicesDX7[i].feedbackShiftValue = feedbackShift(Int(slot.ops.0.feedback))
                voicesDX7[i].applyParams(slot.ops.0, opIndex: 0)
                voicesDX7[i].applyParams(slot.ops.1, opIndex: 1)
                voicesDX7[i].applyParams(slot.ops.2, opIndex: 2)
                voicesDX7[i].applyParams(slot.ops.3, opIndex: 3)
                voicesDX7[i].applyParams(slot.ops.4, opIndex: 4)
                voicesDX7[i].applyParams(slot.ops.5, opIndex: 5)
            }
        }

        // Drain MIDI events
        drainMIDI()

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
        let slotCount = snapshot.slots.count

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
            let slot = snapshot.slots[s]
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
                updateLFOForSlot(s, snapshot.slots[s])
            }

            for i in 0..<maxV {
                guard voicesDX7[i].active else { continue }
                let s = voicesDX7[i].slotId
                guard s < slotCount else { continue }
                let sm = slotMods[s]
                if sm.hasPitchMod {
                    let slot = snapshot.slots[s]
                    let lfoPitch = lfoCurrentValue[s] * Float(slot.lfoPMD) / 99.0 * sm.pmsDepth
                    let controllerPitch = sm.wheelPitchDepth + sm.footPitchDepth + sm.breathPitchDepth + sm.atPitchDepth
                    let factor = pitchBendValue * pitchBendFactorExt(lfoPitch + controllerPitch)
                    voicesDX7[i].applyPitchBend(factor)
                }

                let lfoUni = (lfoCurrentValue[s] + 1.0) * 0.5
                let lfoAtten = 1.0 - lfoUni
                let amdDepth = lfoAtten * slotMods[s].lfoAMDNorm
                let controllerAmd = 1.0 - slotMods[s].controllerAmpMod
                let totalAmd = (amdDepth + controllerAmd) * 12.0
                voicesDX7[i].lfoAmpMod = Int32(totalAmd * Float(1 << 24))
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
                let scale = vol * pL / 33554432.0
                let scaleR = vol * pR / 33554432.0
                for s in 0..<blockSize {
                    let sample = Float(blockBuf[s])
                    outBufL[s] += sample * scale
                    outBufR[s] += sample * scaleR
                }
            }

            for s in 0..<blockSize {
                outBufL[s] = min(1.0, max(-1.0, outBufL[s]))
                outBufR[s] = min(1.0, max(-1.0, outBufR[s]))
            }

            offset += blockSize
        }
    }

    // MARK: - MIDI Handling

    private func doNoteOn(_ note: UInt8, velocity16: UInt16) {
        let snapshot = currentSnapshot
        let targetSlots = determineTargetSlots(note: note, snapshot: snapshot)

        for slotIdx in targetSlots {
            guard slotIdx < snapshot.slots.count, slotIdx < snapshot.slotConfigs.count else { continue }
            let slot = snapshot.slots[slotIdx]
            let config = snapshot.slotConfigs[slotIdx]
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
            voicesDX7[target].feedbackShiftValue = feedbackShift(Int(slot.ops.0.feedback))

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

    private func determineTargetSlots(note: UInt8, snapshot: SynthParamSnapshot) -> [Int] {
        let mode = TimbreMode(rawValue: snapshot.timbreMode) ?? .single
        switch mode {
        case .single: return [0]
        case .dual: return Array(0..<snapshot.slots.count)
        case .split:
            return snapshot.slotConfigs.indices.filter { idx in
                let cfg = snapshot.slotConfigs[idx]
                return cfg.enabled && note >= cfg.noteRangeLow && note <= cfg.noteRangeHigh
            }
        case .tx816:
            return snapshot.slotConfigs.indices.filter { snapshot.slotConfigs[$0].enabled }
        }
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
}
