// PresetLoadTests.swift
// M2DX-Core — Tests for preset loading via SynthEngine

import Testing
import Darwin
@testable import M2DXCore

@Suite("Preset Load Tests")
struct PresetLoadTests {

    /// Helper: load preset using individual setters (same as M2DXAudioEngine.loadPreset)
    func loadPresetViaSetters(_ engine: SynthEngine, _ preset: DX7Preset) {
        // allNotesOff
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 123, data2: 0))

        engine.setAlgorithm(preset.algorithm)
        engine.setOperatorFeedback(preset.feedback)

        // DX7Preset.operators: [OP1, OP2, ..., OP6]
        // kAlgorithmFlags opIdx: 0=OP6, 1=OP5, ..., 5=OP1
        // Map: operators[i] → opIdx = 5 - i
        for (i, op) in preset.operators.enumerated() {
            guard i < 6 else { break }
            let opIdx = 5 - i
            engine.setOperatorDX7OutputLevel(opIdx, level: op.outputLevel)
            engine.setOperatorDX7EGRates(opIdx, r1: op.egRate1, r2: op.egRate2, r3: op.egRate3, r4: op.egRate4)
            engine.setOperatorDX7EGLevels(opIdx, l1: op.egLevel1, l2: op.egLevel2, l3: op.egLevel3, l4: op.egLevel4)
            engine.setOperatorRatio(opIdx, ratio: op.frequencyRatio)
            engine.setOperatorDetune(opIdx, cents: op.detuneCents)
            engine.setOperatorVelocitySensitivity(opIdx, value: UInt8(op.velocitySensitivity))
            engine.setOperatorAmpModSensitivity(opIdx, value: UInt8(op.ampModSensitivity))
            engine.setOperatorKeyboardRateScaling(opIdx, value: UInt8(op.keyboardRateScaling))
            engine.setOperatorKLS(opIdx, breakPoint: UInt8(op.klsBreakPoint),
                                 leftDepth: UInt8(op.klsLeftDepth), rightDepth: UInt8(op.klsRightDepth),
                                 leftCurve: UInt8(op.klsLeftCurve), rightCurve: UInt8(op.klsRightCurve))
            engine.setOperatorFixedFrequency(opIdx, enabled: UInt8(op.frequencyMode),
                                             coarse: UInt8(op.frequencyCoarse), fine: UInt8(op.frequencyFine))
        }
        engine.setLFOSpeed(UInt8(preset.lfoSpeed))
        engine.setLFODelay(UInt8(preset.lfoDelay))
        engine.setLFOPMD(UInt8(preset.lfoPMD))
        engine.setLFOAMD(UInt8(preset.lfoAMD))
        engine.setLFOSync(UInt8(preset.lfoSync))
        engine.setLFOWaveform(UInt8(preset.lfoWaveform))
        engine.setLFOPMS(UInt8(preset.lfoPMS))
        engine.setPitchEGRates(UInt8(preset.pitchEGR1), UInt8(preset.pitchEGR2),
                               UInt8(preset.pitchEGR3), UInt8(preset.pitchEGR4))
        engine.setPitchEGLevels(UInt8(preset.pitchEGL1), UInt8(preset.pitchEGL2),
                                UInt8(preset.pitchEGL3), UInt8(preset.pitchEGL4))
        engine.setWheelPitch(50); engine.setWheelAmp(0); engine.setWheelEGBias(0)
        engine.setFootPitch(0); engine.setFootAmp(0); engine.setFootEGBias(0)
        engine.setBreathPitch(0); engine.setBreathAmp(0); engine.setBreathEGBias(0)
        engine.setAftertouchPitch(0); engine.setAftertouchAmp(0); engine.setAftertouchEGBias(0)
        engine.setTranspose(Int8(preset.transpose))
    }

    /// Helper: render N blocks and return peak amplitude
    func renderAndGetPeak(_ engine: SynthEngine, blocks: Int = 20) -> Float {
        let frames = kBlockSize * blocks
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer { bufL.deallocate(); bufR.deallocate() }
        bufL.initialize(repeating: 0, count: frames)
        bufR.initialize(repeating: 0, count: frames)

        engine.render(into: bufL, bufferR: bufR, frameCount: frames)

        var peak: Float = 0
        for i in 0..<frames {
            peak = max(peak, abs(bufL[i]))
            peak = max(peak, abs(bufR[i]))
        }
        return peak
    }

    @Test("INIT VOICE produces sound after loadPreset via setters")
    func initVoiceViaSetters() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)

        let preset = DX7FactoryPresets.initVoice
        loadPresetViaSetters(engine, preset)

        // Render a few blocks to let allNotesOff + snapshot propagate
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))

        // Render and check output
        let peak = renderAndGetPeak(engine, blocks: 20)
        print("INIT VOICE peak (setters): \(peak)")
        #expect(peak > 0.01, "INIT VOICE should produce audible output, peak=\(peak)")
    }

    @Test("INIT VOICE simple: minimal setup produces sound")
    func initVoiceSimple() {
        let engine = SynthEngine()

        // Use default sampleRate (44100)
        // Set INIT VOICE parameters
        // OP1 (carrier in Alg1) = operators[0] → opIdx 5
        engine.setAlgorithm(0)
        engine.setOperatorDX7OutputLevel(5, level: 99)  // OP1 at opIdx 5
        engine.setOperatorDX7EGRates(5, r1: 99, r2: 99, r3: 99, r4: 99)
        engine.setOperatorDX7EGLevels(5, l1: 99, l2: 99, l3: 99, l4: 0)
        engine.setOperatorRatio(5, ratio: 1.0)
        engine.setOperatorDetune(5, cents: 0)
        for i in 0..<5 {
            engine.setOperatorDX7OutputLevel(i, level: 0)  // OP6-OP2 at opIdx 0-4
        }

        // Render once to sync snapshot
        _ = renderAndGetPeak(engine, blocks: 1)

        // Note on
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))

        // Render block by block to see when sound appears
        for block in 0..<10 {
            let frames = kBlockSize
            let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            defer { bufL.deallocate(); bufR.deallocate() }
            bufL.initialize(repeating: 0, count: frames)
            bufR.initialize(repeating: 0, count: frames)
            engine.render(into: bufL, bufferR: bufR, frameCount: frames)
            var peak: Float = 0
            for i in 0..<frames {
                peak = max(peak, abs(bufL[i]))
            }
            print("Block \(block): peak=\(peak)")
        }
    }

    @Test("INIT VOICE produces sound after loadDX7Preset (atomic)")
    func initVoiceViaAtomic() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)

        // allNotesOff
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 123, data2: 0))
        let preset = DX7FactoryPresets.initVoice
        engine.loadDX7Preset(preset)

        // Render to propagate
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))

        // Render and check output
        let peak = renderAndGetPeak(engine, blocks: 20)
        print("INIT VOICE peak (atomic): \(peak)")
        #expect(peak > 0.01, "INIT VOICE atomic should produce audible output, peak=\(peak)")
    }

    @Test("INIT VOICE produces same sound consistently after PC switch")
    func initVoiceConsistentAfterPCSwitch() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)

        // Load INIT VOICE first
        loadPresetViaSetters(engine, DX7FactoryPresets.initVoice)
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on, capture peak
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))
        let peak1 = renderAndGetPeak(engine, blocks: 20)
        print("INIT VOICE peak1: \(peak1)")

        // Note off
        engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: 60, data2: 0))
        _ = renderAndGetPeak(engine, blocks: 5)

        // Switch to BRASS1
        let brass1 = DX7FactoryPresets.all[1]
        loadPresetViaSetters(engine, brass1)
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on BRASS1
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))
        let peakBrass = renderAndGetPeak(engine, blocks: 20)
        print("BRASS1 peak: \(peakBrass)")

        // Note off
        engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: 60, data2: 0))
        _ = renderAndGetPeak(engine, blocks: 5)

        // Switch back to INIT VOICE
        loadPresetViaSetters(engine, DX7FactoryPresets.initVoice)
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on again
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))
        let peak2 = renderAndGetPeak(engine, blocks: 20)
        print("INIT VOICE peak2 (after PC switch): \(peak2)")

        // peaks should be similar (within 20%)
        let ratio = peak2 / max(peak1, 0.0001)
        #expect(ratio > 0.8, "INIT VOICE should sound similar after PC switch, ratio=\(ratio) peak1=\(peak1) peak2=\(peak2)")
        #expect(ratio < 1.2, "INIT VOICE should sound similar after PC switch, ratio=\(ratio)")
    }

    @Test("loadSlotParams produces sound (batch approach)")
    func initVoiceViaLoadSlotParams() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)

        let preset = DX7FactoryPresets.initVoice
        // Build SlotSnapshot manually
        // Map operators[i] → opIdx = 5-i
        var slotSnap = SlotSnapshot()
        slotSnap.algorithm = preset.algorithm
        for (i, op) in preset.operators.enumerated() {
            guard i < 6 else { break }
            let opIdx = 5 - i
            var opSnap = OperatorSnapshot()
            opSnap.dx7OutputLevel = op.outputLevel
            opSnap.dx7EgR0 = op.egRate1; opSnap.dx7EgR1 = op.egRate2
            opSnap.dx7EgR2 = op.egRate3; opSnap.dx7EgR3 = op.egRate4
            opSnap.dx7EgL0 = op.egLevel1; opSnap.dx7EgL1 = op.egLevel2
            opSnap.dx7EgL2 = op.egLevel3; opSnap.dx7EgL3 = op.egLevel4
            opSnap.ratio = op.frequencyRatio
            opSnap.detune = powf(2.0, op.detuneCents / 1200.0)
            opSnap.feedback = (opIdx == 0) ? Float(preset.feedback) / 7.0 : 0
            opSnap.velocitySensitivity = UInt8(op.velocitySensitivity)
            opSnap.ampModSensitivity = UInt8(op.ampModSensitivity)
            opSnap.keyboardRateScaling = UInt8(op.keyboardRateScaling)
            opSnap.klsBreakPoint = UInt8(op.klsBreakPoint)
            opSnap.klsLeftDepth = UInt8(op.klsLeftDepth)
            opSnap.klsRightDepth = UInt8(op.klsRightDepth)
            opSnap.klsLeftCurve = UInt8(op.klsLeftCurve)
            opSnap.klsRightCurve = UInt8(op.klsRightCurve)
            opSnap.fixedFrequency = UInt8(op.frequencyMode)
            opSnap.fixedFreqCoarse = UInt8(op.frequencyCoarse)
            opSnap.fixedFreqFine = UInt8(op.frequencyFine)

            switch opIdx {
            case 0: slotSnap.ops.0 = opSnap
            case 1: slotSnap.ops.1 = opSnap
            case 2: slotSnap.ops.2 = opSnap
            case 3: slotSnap.ops.3 = opSnap
            case 4: slotSnap.ops.4 = opSnap
            case 5: slotSnap.ops.5 = opSnap
            default: break
            }
        }

        // allNotesOff
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 123, data2: 0))
        engine.loadSlotParams(0, slot: slotSnap)

        // Render to propagate
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7FFF)))

        let peak = renderAndGetPeak(engine, blocks: 20)
        print("INIT VOICE peak (loadSlotParams): \(peak)")
        #expect(peak > 0.01, "INIT VOICE via loadSlotParams should produce sound, peak=\(peak)")
    }

    @Test("DX7Envelope decay rate R3=20 timing")
    func envelopeDecayTiming() {
        var env = DX7Envelope()
        env.setSampleRate(48000)
        env.setRates(96, 25, 20, 67)  // E.PIANO1 OP1 carrier rates
        env.setLevels(99, 75, 0, 0)    // E.PIANO1 OP1 carrier levels
        env.setOutputLevel(99)

        env.noteOn()

        // Run through attack + decay stages to reach sustain decay (stage 2)
        var lastIx = env.ix
        for block in 0..<100000 {
            let level = env.getsample()
            if env.ix != lastIx {
                let t = Float(block) * 64.0 / 48000.0
                print("Stage change: ix=\(env.ix) at t=\(String(format: "%.3f", t))s level=\(level) targetLevel=\(env.targetLevel) inc=\(env.inc)")
                lastIx = env.ix
            }
            if env.ix < 0 { break }
            if block < 5 || (block % 750 == 0) {
                let t = Float(block) * 64.0 / 48000.0
                print("block=\(block) ix=\(env.ix) level=\(level) target=\(env.targetLevel) inc=\(env.inc) t=\(String(format: "%.2f", t))s")
            }
        }
    }

    @Test("E.PIANO1 sustain lasts at least 5 seconds")
    func ePiano1Sustain() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)

        // E.PIANO1 is ROM1A index 10 (all[11] since [0]=INIT VOICE)
        let epiano = DX7FactoryPresets.all[11]
        print("Preset: \(epiano.name), Algorithm: \(epiano.algorithm)")
        engine.loadDX7Preset(epiano)

        // Render a couple blocks to propagate snapshot
        _ = renderAndGetPeak(engine, blocks: 2)

        // Note on
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))

        // Measure peak at short intervals to find exact cutoff
        let sr: Float = 48000
        let blocksPerStep = Int(sr * 0.1) / kBlockSize  // 75 blocks = 0.1s
        for step in 1...30 {
            let peak = renderAndGetPeak(engine, blocks: blocksPerStep)
            let t = Float(step) * 0.1
            print("E.PIANO1 t=\(String(format: "%.1f", t))s peak=\(peak)")
            if peak == 0 && step > 5 { break }
        }
        // Should still have sound at 3 seconds
        let peakAt3s = renderAndGetPeak(engine, blocks: 1)
        print("E.PIANO1 final check peak=\(peakAt3s)")
    }

    @Test("E.PIANO1 direct voice render diagnostic")
    func ePiano1DirectVoiceDiagnostic() {
        // Build the voice directly like SynthEngine.doNoteOn would
        var voice = DX7Voice()
        voice.setSampleRate(48000)

        let epiano = DX7FactoryPresets.all[11]
        print("Algorithm: \(epiano.algorithm)")

        // Build slot from loadDX7Preset logic
        var slot = SlotSnapshot()
        slot.algorithm = epiano.algorithm
        let ops = epiano.operators
        func makeSnap(_ op: DX7OperatorPreset, fb: Bool) -> OperatorSnapshot {
            var s = OperatorSnapshot()
            s.dx7OutputLevel = op.outputLevel
            s.ratio = op.frequencyRatio
            s.detune = powf(2.0, op.detuneCents / 1200.0)
            s.feedback = fb ? Float(epiano.feedback) / 7.0 : 0
            s.dx7EgR0 = op.egRate1; s.dx7EgR1 = op.egRate2
            s.dx7EgR2 = op.egRate3; s.dx7EgR3 = op.egRate4
            s.dx7EgL0 = op.egLevel1; s.dx7EgL1 = op.egLevel2
            s.dx7EgL2 = op.egLevel3; s.dx7EgL3 = op.egLevel4
            s.velocitySensitivity = UInt8(op.velocitySensitivity)
            s.keyboardRateScaling = UInt8(op.keyboardRateScaling)
            s.klsBreakPoint = UInt8(op.klsBreakPoint)
            s.klsLeftDepth = UInt8(op.klsLeftDepth)
            s.klsRightDepth = UInt8(op.klsRightDepth)
            s.klsLeftCurve = UInt8(op.klsLeftCurve)
            s.klsRightCurve = UInt8(op.klsRightCurve)
            return s
        }
        slot.ops.0 = makeSnap(ops[5], fb: true)   // OP6 → opIdx 0
        slot.ops.1 = makeSnap(ops[4], fb: false)  // OP5 → opIdx 1
        slot.ops.2 = makeSnap(ops[3], fb: false)  // OP4 → opIdx 2
        slot.ops.3 = makeSnap(ops[2], fb: false)  // OP3 → opIdx 3
        slot.ops.4 = makeSnap(ops[1], fb: false)  // OP2 → opIdx 4
        slot.ops.5 = makeSnap(ops[0], fb: false)  // OP1 → opIdx 5

        voice.algorithm = slot.algorithm
        voice.feedbackShiftValue = feedbackShift(Int(slot.ops.0.feedback * 7.0 + 0.5))

        // Apply params like doNoteOn
        voice.applyParams(slot.ops.0, opIndex: 0)
        voice.applyParams(slot.ops.1, opIndex: 1)
        voice.applyParams(slot.ops.2, opIndex: 2)
        voice.applyParams(slot.ops.3, opIndex: 3)
        voice.applyParams(slot.ops.4, opIndex: 4)
        voice.applyParams(slot.ops.5, opIndex: 5)

        // noteOn
        let velocity16: UInt16 = 0xFE00
        voice.noteOn(60, velocity16: velocity16)

        // Apply velocity/KLS like doNoteOn
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
            voice.withOp(opIdx) { op in
                op.velocityOffset = scaleVelocity(velocity16, sens: Int(opSnap.velocitySensitivity))
                op.klsOffset = scaleKeyboardLevel(60, breakPoint: opSnap.klsBreakPoint,
                    leftDepth: opSnap.klsLeftDepth, rightDepth: opSnap.klsRightDepth,
                    leftCurve: opSnap.klsLeftCurve, rightCurve: opSnap.klsRightCurve)
                let scaledOL = scaleOutputLevel(op.outputLevel)
                op.env.outlevel = max(0, (min(127, scaledOL + op.klsOffset) << 5) + op.velocityOffset)
                op.env.recalcTargetLevel()
                op.env.rateScaling = keyboardRateScaling(note: 60, scaling: opSnap.keyboardRateScaling)
            }
        }

        // Print initial state
        for opIdx in 0..<6 {
            voice.withOp(opIdx) { op in
                print("opIdx=\(opIdx) OL=\(op.outputLevel) outlevel=\(op.env.outlevel) velOff=\(op.velocityOffset) klsOff=\(op.klsOffset) ix=\(op.env.ix) level=\(op.env.level) target=\(op.env.targetLevel) rateScaling=\(op.env.rateScaling) inc=\(op.env.inc) rates=\(op.env.rates)")
            }
        }

        // Render blocks and dump carrier state
        let bs = kBlockSize
        let output = UnsafeMutablePointer<Int32>.allocate(capacity: bs)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: bs)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: bs)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        for block in 0..<1500 {
            voice.checkActive()
            guard voice.active else {
                let t = Float(block) * Float(kBlockSize) / 48000.0
                print("VOICE INACTIVE at block=\(block) t=\(String(format: "%.3f", t))s")
                break
            }

            voice.updateGains()

            for i in 0..<bs { output[i] = 0 }
            voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: bs)

            var peak: Int32 = 0
            for i in 0..<bs { peak = max(peak, abs(output[i])) }

            let t = Float(block) * Float(kBlockSize) / 48000.0
            if block < 10 || (block % 75 == 0) || peak == 0 {
                // Dump carrier ops (opIdx 2=OP4, opIdx 5=OP1) with EG detail
                var info = String(format: "blk=%d t=%.3f peak=%d ", block, t, peak)
                for opIdx in [5, 2, 3, 0] {  // OP1(carrier), OP4(carrier), OP3(mod), OP6(fb)
                    voice.withOp(opIdx) { op in
                        let gain = exp2LookupQ24(op.levelIn &- Int32(14 * (1 << 24)))
                        info += String(format: "op%d[ix=%d lv=%d li=%d tgt=%d g=%d] ", opIdx, op.env.ix, op.env.level, op.levelIn, op.env.targetLevel, gain)
                    }
                }
                print(info)
                if peak == 0 && block > 50 { break }
            }
        }
    }

    @Test("E.PIANO1 voice-level diagnostic")
    func ePiano1VoiceDiagnostic() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)

        let epiano = DX7FactoryPresets.all[11]
        engine.loadDX7Preset(epiano)

        // Render to propagate snapshot
        let bs = kBlockSize
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: bs)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: bs)
        defer { bufL.deallocate(); bufR.deallocate() }
        bufL.initialize(repeating: 0, count: bs)
        bufR.initialize(repeating: 0, count: bs)
        engine.render(into: bufL, bufferR: bufR, frameCount: bs)

        // Note on with 0x7F00
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))

        // Render block-by-block, dumping each op's gain
        let output = UnsafeMutablePointer<Int32>.allocate(capacity: bs)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: bs)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: bs)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        for block in 0..<1000 {
            bufL.initialize(repeating: 0, count: bs)
            bufR.initialize(repeating: 0, count: bs)
            engine.render(into: bufL, bufferR: bufR, frameCount: bs)

            var peak: Float = 0
            for i in 0..<bs { peak = max(peak, abs(bufL[i])) }

            let t = Float(block) * Float(kBlockSize) / 48000.0
            if block < 5 || (block % 75 == 0) || peak == 0 {
                print(String(format: "block=%d t=%.3fs peak=%.6f", block, t, peak))
                if peak == 0 && block > 50 {
                    print(">>> PEAK DROPPED TO ZERO!")
                    break
                }
            }
        }

        // Now test with max velocity (0xFE00)
        print("\n--- Same with velocity 0xFE00 (MIDI 1.0 vel=127) ---")
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 123, data2: 0))
        bufL.initialize(repeating: 0, count: bs)
        bufR.initialize(repeating: 0, count: bs)
        engine.render(into: bufL, bufferR: bufR, frameCount: bs)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0xFE00)))

        for block in 0..<1500 {
            bufL.initialize(repeating: 0, count: bs)
            bufR.initialize(repeating: 0, count: bs)
            engine.render(into: bufL, bufferR: bufR, frameCount: bs)

            var peak: Float = 0
            for i in 0..<bs { peak = max(peak, abs(bufL[i])) }

            let t = Float(block) * Float(kBlockSize) / 48000.0
            if block < 5 || (block % 75 == 0) || peak == 0 {
                print(String(format: "block=%d t=%.3fs peak=%.6f", block, t, peak))
                if peak == 0 && block > 50 {
                    print(">>> PEAK DROPPED TO ZERO!")
                    break
                }
            }
        }
    }

    @Test("E.PIANO1 EG level diagnostic")
    func ePiano1EGDiagnostic() {
        // Test the EG directly with the exact outlevel the SynthEngine uses
        // E.PIANO1 OP1: OL=99, R=96/25/25/67, L=99/75/0/0, velSens=2
        // velocity16 = 0x7F00 → vel7=63 → velIdx=31 → kVelocityData[31]=205 → velValue=-34
        // scaleVelocity(0x7F00, sens=2) = ((2*-34+7)>>3)<<4 = (-61>>3)<<4 = -8*16 = -128
        // scaledOL = scaleOutputLevel(99) = 127
        // klsOffset = 0 (note=60, bp=60)
        // outlevel = max(0, (127<<5) + (-128)) = 3936

        var env = DX7Envelope()
        env.setSampleRate(48000)
        env.setRates(96, 25, 25, 67)
        env.setLevels(99, 75, 0, 0)

        // Set outlevel as SynthEngine would for vel=0x7F00, OL=99
        let velocityOffset = scaleVelocity(0x7F00, sens: 2)
        let scaledOL = scaleOutputLevel(99)
        env.outlevel = max(0, (min(127, scaledOL + 0) << 5) + velocityOffset)

        print("velocityOffset=\(velocityOffset), scaledOL=\(scaledOL), outlevel=\(env.outlevel)")

        env.noteOn()

        var lastIx = -99
        for block in 0..<2000 {
            let level = env.getsample()
            let gain = exp2LookupQ24(level &- Int32(14 * (1 << 24)))

            if env.ix != lastIx {
                let t = Float(block) * 64.0 / 48000.0
                print("STAGE CHANGE: ix=\(env.ix) at t=\(String(format: "%.3f", t))s level=\(level) gain=\(gain) target=\(env.targetLevel) inc=\(env.inc) outlevel=\(env.outlevel)")
                lastIx = env.ix
            }

            if block < 5 || (block % 75 == 0) || gain < 2000 {
                let t = Float(block) * 64.0 / 48000.0
                print("block=\(block) ix=\(env.ix) level=\(level) gain=\(gain) target=\(env.targetLevel) t=\(String(format: "%.3f", t))s")
                if gain < 1120 && block > 10 {
                    print(">>> GAIN BELOW THRESHOLD at block=\(block)!")
                    break
                }
            }
        }

        // Now compare: same EG but with full velocity outlevel (no velocity reduction)
        print("\n--- Same EG with full outlevel (4064) ---")
        var env2 = DX7Envelope()
        env2.setSampleRate(48000)
        env2.setRates(96, 25, 25, 67)
        env2.setLevels(99, 75, 0, 0)
        env2.outlevel = 4064  // No velocity reduction

        env2.noteOn()

        lastIx = -99
        for block in 0..<2000 {
            let level = env2.getsample()
            let gain = exp2LookupQ24(level &- Int32(14 * (1 << 24)))

            if env2.ix != lastIx {
                let t = Float(block) * 64.0 / 48000.0
                print("STAGE CHANGE: ix=\(env2.ix) at t=\(String(format: "%.3f", t))s level=\(level) gain=\(gain) target=\(env2.targetLevel) inc=\(env2.inc) outlevel=\(env2.outlevel)")
                lastIx = env2.ix
            }

            if block < 5 || (block % 75 == 0) || gain < 2000 {
                let t = Float(block) * 64.0 / 48000.0
                print("block=\(block) ix=\(env2.ix) level=\(level) gain=\(gain) target=\(env2.targetLevel) t=\(String(format: "%.3f", t))s")
                if gain < 1120 && block > 10 {
                    print(">>> GAIN BELOW THRESHOLD at block=\(block)!")
                    break
                }
            }
        }
    }
}
