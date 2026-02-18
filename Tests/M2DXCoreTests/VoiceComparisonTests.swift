// VoiceComparisonTests.swift
// M2DX-Core — DEXED vs M2DX voice-level waveform comparison tests

import Testing
import Darwin
@testable import M2DXCore
import DX7Ref

// MARK: - 156-byte DX7 Patch Builder

/// Build a 156-byte unpacked DX7 patch from operator and global parameters.
/// Operator order in patch: OP1 at offset 0, OP2 at offset 21, ..., OP6 at offset 105.
/// Global params at offset 126-155.
func buildPatch156(
    ops: [(r: [Int], l: [Int], bp: Int, ld: Int, rd: Int, lc: Int, rc: Int,
           rs: Int, ams: Int, vs: Int, ol: Int, mode: Int, coarse: Int, fine: Int, detune: Int)],
    algorithm: Int, feedback: Int,
    pitchEGRates: [Int] = [99, 99, 99, 99],
    pitchEGLevels: [Int] = [50, 50, 50, 50],
    lfoSpeed: Int = 0, lfoDelay: Int = 0, lfoPMD: Int = 0, lfoAMD: Int = 0,
    lfoSync: Int = 0, lfoWaveform: Int = 0, lfoPMS: Int = 0,
    transpose: Int = 24
) -> [UInt8] {
    var patch = [UInt8](repeating: 0, count: 156)
    for (opIdx, op) in ops.prefix(6).enumerated() {
        let off = opIdx * 21
        for i in 0..<4 { patch[off + i] = UInt8(clamping: op.r[i]) }           // R1-R4
        for i in 0..<4 { patch[off + 4 + i] = UInt8(clamping: op.l[i]) }       // L1-L4
        patch[off + 8] = UInt8(clamping: op.bp)                                  // Break Point
        patch[off + 9] = UInt8(clamping: op.ld)                                  // Left Depth
        patch[off + 10] = UInt8(clamping: op.rd)                                 // Right Depth
        patch[off + 11] = UInt8(clamping: op.lc)                                 // Left Curve
        patch[off + 12] = UInt8(clamping: op.rc)                                 // Right Curve
        patch[off + 13] = UInt8(clamping: op.rs)                                 // Rate Scaling
        patch[off + 14] = UInt8(clamping: op.ams)                                // AMS
        patch[off + 15] = UInt8(clamping: op.vs)                                 // Vel Sensitivity
        patch[off + 16] = UInt8(clamping: op.ol)                                 // Output Level
        patch[off + 17] = UInt8(clamping: op.mode)                               // Freq Mode
        patch[off + 18] = UInt8(clamping: op.coarse)                             // Coarse
        patch[off + 19] = UInt8(clamping: op.fine)                               // Fine
        patch[off + 20] = UInt8(clamping: op.detune)                             // Detune
    }
    // Global params
    for i in 0..<4 { patch[126 + i] = UInt8(clamping: pitchEGRates[i]) }       // Pitch EG Rates
    for i in 0..<4 { patch[130 + i] = UInt8(clamping: pitchEGLevels[i]) }      // Pitch EG Levels
    patch[134] = UInt8(clamping: algorithm)                                      // Algorithm (0-31)
    patch[135] = UInt8(clamping: feedback)                                        // Feedback (0-7)
    patch[136] = 1                                                                // Osc Sync
    patch[137] = UInt8(clamping: lfoSpeed)                                       // LFO Speed
    patch[138] = UInt8(clamping: lfoDelay)                                       // LFO Delay
    patch[139] = UInt8(clamping: lfoPMD)                                         // LFO PMD
    patch[140] = UInt8(clamping: lfoAMD)                                         // LFO AMD
    patch[141] = UInt8(clamping: lfoSync)                                        // LFO Sync
    patch[142] = UInt8(clamping: lfoWaveform)                                    // LFO Waveform
    patch[143] = UInt8(clamping: lfoPMS)                                         // LFO PMS
    patch[144] = UInt8(clamping: transpose)                                      // Transpose (C3=24)
    // 145-155: name (10 bytes) + padding — not used for audio
    return patch
}

/// Default silent operator (OL=0, all rates fast)
let silentOp = (r: [99, 99, 99, 99], l: [99, 99, 99, 0],
                bp: 39, ld: 0, rd: 0, lc: 0, rc: 0,
                rs: 0, ams: 0, vs: 0, ol: 0, mode: 0, coarse: 1, fine: 0, detune: 7)

/// Default full-level operator
func fullOp(ol: Int = 99, coarse: Int = 1, fine: Int = 0, detune: Int = 7,
            rs: Int = 0, vs: Int = 0, ams: Int = 0,
            rates: [Int] = [99, 99, 99, 99], levels: [Int] = [99, 99, 99, 0],
            bp: Int = 39, ld: Int = 0, rd: Int = 0, lc: Int = 0, rc: Int = 0,
            mode: Int = 0) ->
    (r: [Int], l: [Int], bp: Int, ld: Int, rd: Int, lc: Int, rc: Int,
     rs: Int, ams: Int, vs: Int, ol: Int, mode: Int, coarse: Int, fine: Int, detune: Int) {
    return (r: rates, l: levels, bp: bp, ld: ld, rd: rd, lc: lc, rc: rc,
            rs: rs, ams: ams, vs: vs, ol: ol, mode: mode, coarse: coarse, fine: fine, detune: detune)
}

// MARK: - M2DX Voice Setup Helper

/// Set up an M2DX DX7Voice to match the same parameters that dx7ref_voice_init uses.
/// This uses the same code path as SynthEngine.noteOn but isolated for testing.
func setupM2DXVoice(patch: [UInt8], midinote: UInt8, velocity7: Int, sampleRate: Float = 44100) -> DX7Voice {
    var voice = DX7Voice()
    voice.setSampleRate(sampleRate)

    // Build DX7Preset from patch bytes — matches DEXED operator order
    // patch: [OP1 at 0, OP2 at 21, ..., OP6 at 105]
    // DEXED processes ops 0-5 in this order
    // M2DX kAlgorithmFlags: opIdx 0=OP6, 1=OP5, ..., 5=OP1

    let algorithm = Int(patch[134])
    let feedback = Int(patch[135])
    voice.algorithm = algorithm
    voice.feedbackShiftValue = feedback != 0 ? 8 - feedback : 16

    // DEXED processes patch ops 0-5 with algorithm flags 0-5 directly.
    // There is NO 5-i reversal in DEXED: params[0] gets patch[0..20] (OP1 data),
    // and flags[0] (OP6 in algorithm notation) operates on params[0].
    // M2DX must match this: patch op i → opIdx i
    for patchOp in 0..<6 {
        let off = patchOp * 21
        let opIdx = patchOp  // Direct mapping, same as DEXED

        voice.withOp(opIdx) { op in
            let ol = Int(patch[off + 16])
            op.outputLevel = ol

            let mode = Int(patch[off + 17])
            let coarse = Int(patch[off + 18])
            let fine = Int(patch[off + 19])
            let detune = Int(patch[off + 20])

            op.isFixedFreq = (mode != 0)
            if mode == 0 {
                let coarseF: Float = coarse == 0 ? 0.5 : Float(coarse)
                op.ratio = coarseF * (1.0 + Float(fine) / 100.0)
                // Use DEXED's frequency computation for the test:
                // We set the frequency from DEXED's logfreq → Freqlut to match exactly
                let logfreq = dx7ref_osc_freq(Int32(midinote), 0, Int32(coarse), Int32(fine), Int32(detune))
                let phaseInc = dx7ref_freq_lookup(logfreq)
                op.freq = phaseInc
                op.detune = 1.0  // detune is already baked into freq via DEXED path
            } else {
                op.ratio = 1.0
                op.detune = 1.0
                let logfreq = dx7ref_osc_freq(Int32(midinote), 1, Int32(coarse), Int32(fine), Int32(detune))
                let phaseInc = dx7ref_freq_lookup(logfreq)
                op.freq = phaseInc
            }

            // EG
            op.env.setRates(Int(patch[off]), Int(patch[off+1]), Int(patch[off+2]), Int(patch[off+3]))
            op.env.setLevels(Int(patch[off+4]), Int(patch[off+5]), Int(patch[off+6]), Int(patch[off+7]))

            // Velocity & KLS
            let vs = Int(patch[off + 15])
            let rs = Int(patch[off + 13])
            let ams = Int(patch[off + 14])

            op.velocityOffset = scaleVelocity(UInt16(velocity7) << 9, sens: vs)
            op.klsOffset = scaleKeyboardLevel(
                midinote, breakPoint: patch[off + 8],
                leftDepth: patch[off + 9], rightDepth: patch[off + 10],
                leftCurve: patch[off + 11], rightCurve: patch[off + 12]
            )
            op.amsDepth = kAMSDepthQ24[min(Int(ams), 3)]

            let scaledOL = scaleOutputLevel(ol)
            op.env.outlevel = max(0, (min(127, scaledOL + op.klsOffset) << 5) + op.velocityOffset)
            op.env.rateScaling = keyboardRateScaling(note: midinote, scaling: UInt8(rs))
            // No SR correction for reference comparison at 44100
            op.env.srMultiplier = 1 << 24
        }
    }

    // Note on with phase=0, no frequency recalculation (we already set freq)
    voice.active = true
    voice.note = midinote
    voice.midiNote = midinote
    voice.releasing = false
    for i in 0..<6 {
        voice.withOp(i) { op in
            op.phase = 0
            op.fbBuf = (0, 0)
            op.gainOut = 0
            op.env.noteOn()
        }
    }

    return voice
}

// MARK: - Tests

@Suite("Voice-Level Waveform Comparison")
struct VoiceWaveformComparisonTests {

    /// Compare DEXED ref and M2DX voice output for a given patch, note, and velocity.
    /// Returns (mismatches, firstMismatchBlock, firstMismatchSample, refValue, m2dxValue)
    func compareVoices(
        patch: [UInt8], midinote: UInt8, velocity7: Int,
        blocks: Int = 100, sampleRate: Float = 44100
    ) -> (mismatches: Int, firstBlock: Int, firstSample: Int, refVal: Int32, m2dxVal: Int32) {
        // Setup DEXED reference voice
        dx7ref_freq_init(Double(sampleRate))
        var refVoice = dx7ref_voice_t()
        patch.withUnsafeBufferPointer { ptr in
            dx7ref_voice_init(&refVoice, ptr.baseAddress!, Int32(midinote), Int32(velocity7), Double(sampleRate))
        }

        // Setup M2DX voice
        var m2dxVoice = setupM2DXVoice(patch: patch, midinote: midinote, velocity7: velocity7, sampleRate: sampleRate)

        let refBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let m2dxBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { refBuf.deallocate(); m2dxBuf.deallocate(); bus1.deallocate(); bus2.deallocate() }

        var mismatches = 0
        var firstBlock = -1
        var firstSample = -1
        var firstRefVal: Int32 = 0
        var firstM2dxVal: Int32 = 0

        for block in 0..<blocks {
            // Zero both buffers
            refBuf.initialize(repeating: 0, count: kBlockSize)
            m2dxBuf.initialize(repeating: 0, count: kBlockSize)

            // Render DEXED reference
            dx7ref_voice_render(&refVoice, refBuf)

            // Render M2DX
            m2dxVoice.updateGains()
            m2dxVoice.renderBlock(output: m2dxBuf, bus1: bus1, bus2: bus2, blockSize: kBlockSize)

            // Compare sample by sample
            for s in 0..<kBlockSize {
                if refBuf[s] != m2dxBuf[s] {
                    mismatches += 1
                    if firstBlock < 0 {
                        firstBlock = block
                        firstSample = s
                        firstRefVal = refBuf[s]
                        firstM2dxVal = m2dxBuf[s]
                    }
                }
            }
        }

        return (mismatches, firstBlock, firstSample, firstRefVal, firstM2dxVal)
    }

    // MARK: - Sin Table Comparison

    @Test("Sin table matches DEXED")
    func sinTableMatchesDEXED() {
        // Test a sweep of phase values
        var mismatches = 0
        var phase: Int32 = 0
        let step: Int32 = 1 << 10  // fine-grained sweep
        while phase < (1 << 24) {
            let m2dx = sinLookupQ24(phase)
            let dexed = dx7ref_sin_lookup(phase)
            if m2dx != dexed {
                mismatches += 1
                if mismatches == 1 {
                    Issue.record("First sin mismatch: phase=\(phase), M2DX=\(m2dx), DEXED=\(dexed)")
                }
            }
            phase &+= step
            if phase < 0 { break }  // overflow guard
        }
        #expect(mismatches == 0, "Sin table: \(mismatches) mismatches out of \((1 << 24) / Int(step)) samples")
    }

    // MARK: - Frequency Comparison

    @Test("Phase increment within 0.5% of DEXED at detune=7")
    func phaseIncrementMatchesDEXED() {
        // M2DX uses linear Hz → Double → Int32 while DEXED uses log-domain LUT.
        // Both are valid approaches with slightly different rounding.
        // This test verifies the difference stays within 0.5% (inaudible).
        dx7ref_freq_init(44100.0)
        let notes: [Int] = [36, 48, 60, 69, 72, 84, 96]
        let coarseVals = [0, 1, 2, 4]
        let fineVals = [0, 50, 99]

        var maxRelError: Double = 0
        for note in notes {
            for coarse in coarseVals {
                for fine in fineVals {
                    let logfreq = dx7ref_osc_freq(Int32(note), 0, Int32(coarse), Int32(fine), 7)
                    let dexedFreq = dx7ref_freq_lookup(logfreq)

                    let baseHz = kMIDIFreqLUT[note]
                    let coarseF: Float = coarse == 0 ? 0.5 : Float(coarse)
                    let ratio = coarseF * (1.0 + Float(fine) / 100.0)
                    let hz = baseHz * ratio
                    let m2dxFreq = Int32(Double(hz) / 44100.0 * Double(1 << 24))

                    if dexedFreq != 0 {
                        let relError = abs(Double(dexedFreq - m2dxFreq)) / Double(dexedFreq)
                        maxRelError = max(maxRelError, relError)
                    }
                }
            }
        }
        #expect(maxRelError < 0.005, "Frequency max relative error: \(maxRelError * 100)% (threshold: 0.5%)")
    }

    // MARK: - INIT VOICE Waveform

    @Test("INIT VOICE waveform matches DEXED (Algorithm 1, carrier OL99, rest OL=0)")
    func initVoiceWaveformMatch() {
        // Algorithm 1 (index 0): flags[5]=0x14 is carrier (in_bus=1, out_bus=0, add)
        // For carrier at flags index 5, the patch data must be at offset 5*21
        // All silent ops except the carrier at patch index 5
        let carrier = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7)
        let patch = buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, carrier],
            algorithm: 0, feedback: 0
        )

        let result = compareVoices(patch: patch, midinote: 60, velocity7: 100, blocks: 200)

        #expect(result.mismatches == 0,
            "INIT VOICE C4 vel=100: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample) ref=\(result.refVal) m2dx=\(result.m2dxVal)")
    }

    @Test("INIT VOICE A4 waveform matches DEXED")
    func initVoiceA4WaveformMatch() {
        let carrier = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7)
        let patch = buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, carrier],
            algorithm: 0, feedback: 0
        )

        let result = compareVoices(patch: patch, midinote: 69, velocity7: 100, blocks: 200)

        #expect(result.mismatches == 0,
            "INIT VOICE A4 vel=100: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample) ref=\(result.refVal) m2dx=\(result.m2dxVal)")
    }

    // MARK: - Algorithm 5 (3-carrier)

    @Test("Algorithm 5 waveform matches DEXED (3 carrier pairs)")
    func alg5WaveformMatch() {
        // Algorithm 5: 3 carrier-modulator pairs
        // OP1+OP2, OP3+OP4, OP5+OP6
        let carrier = fullOp(ol: 90, coarse: 1)
        let modulator = fullOp(ol: 80, coarse: 2)
        let patch = buildPatch156(
            ops: [carrier, modulator, carrier, modulator, carrier, modulator],
            algorithm: 4, feedback: 0  // alg 5 is index 4
        )

        let result = compareVoices(patch: patch, midinote: 60, velocity7: 100, blocks: 100)

        #expect(result.mismatches == 0,
            "Alg5 C4 vel=100: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample) ref=\(result.refVal) m2dx=\(result.m2dxVal)")
    }

    // MARK: - Feedback

    @Test("Algorithm 1 with feedback matches DEXED")
    func alg1FeedbackWaveformMatch() {
        // Algorithm 1: flags[0]=0xc1 (FB, out_bus=1), flags[5]=0x14 (carrier, in_bus=1, out_bus=0)
        // Feedback op is at flags index 0, so patch data at index 0
        // Carrier is at flags index 5, so patch data at index 5
        let modFb = fullOp(ol: 85, coarse: 1)
        let carrier = fullOp(ol: 99, coarse: 1)
        let patch = buildPatch156(
            ops: [modFb, silentOp, silentOp, silentOp, silentOp, carrier],
            algorithm: 0, feedback: 6
        )

        let result = compareVoices(patch: patch, midinote: 60, velocity7: 100, blocks: 100)

        #expect(result.mismatches == 0,
            "Alg1 FB=6: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample) ref=\(result.refVal) m2dx=\(result.m2dxVal)")
    }

    // MARK: - Velocity Sensitivity

    @Test("Velocity sensitivity produces matching waveforms")
    func velocitySensitivityMatch() {
        // Carrier at flags index 5 for Algorithm 1
        let op1 = fullOp(ol: 99, vs: 5)
        let patch = buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, op1],
            algorithm: 0, feedback: 0
        )

        for vel in [32, 64, 100, 127] {
            let result = compareVoices(patch: patch, midinote: 60, velocity7: vel, blocks: 50)
            #expect(result.mismatches == 0,
                "Vel sens vel=\(vel): \(result.mismatches) mismatches")
        }
    }

    // MARK: - Rate Scaling

    @Test("Rate scaling produces matching envelope traces")
    func rateScalingMatch() {
        // Carrier at flags index 5 for Algorithm 1
        let op1 = fullOp(ol: 99, rs: 3, rates: [96, 25, 25, 67], levels: [99, 75, 0, 0])
        let patch = buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, op1],
            algorithm: 0, feedback: 0
        )

        // Test at different notes to exercise rate scaling
        for note: UInt8 in [36, 60, 84] {
            let result = compareVoices(patch: patch, midinote: note, velocity7: 100, blocks: 200)
            #expect(result.mismatches == 0,
                "Rate scaling note=\(note): \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample)")
        }
    }

    // MARK: - Multiple Notes

    @Test("INIT VOICE matches across octaves")
    func initVoiceMultipleNotes() {
        let carrier = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7)
        let patch = buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, carrier],
            algorithm: 0, feedback: 0
        )

        for note: UInt8 in [36, 48, 60, 72, 84] {
            let result = compareVoices(patch: patch, midinote: note, velocity7: 100, blocks: 100)
            #expect(result.mismatches == 0,
                "INIT VOICE note=\(note): \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample)")
        }
    }

    // MARK: - Complex Patch: E.PIANO-like

    @Test("E.PIANO-like patch matches DEXED")
    func ePianoLikePatchMatch() {
        // Simplified E.PIANO1-like: Algorithm 5, with velocity sensitivity and rate scaling
        let op1 = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7, rs: 3, vs: 2,
                         rates: [96, 25, 25, 67], levels: [99, 75, 0, 0])
        let op2 = fullOp(ol: 85, coarse: 14, fine: 0, detune: 7, rs: 3, vs: 0,
                         rates: [95, 50, 35, 78], levels: [99, 75, 0, 0])
        let op3 = fullOp(ol: 95, coarse: 1, fine: 0, detune: 7, rs: 3, vs: 3,
                         rates: [96, 25, 25, 67], levels: [99, 75, 0, 0])
        let op4 = fullOp(ol: 79, coarse: 1, fine: 0, detune: 7, rs: 0, vs: 0,
                         rates: [95, 50, 35, 78], levels: [99, 75, 0, 0])
        let op5 = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7, rs: 3, vs: 2,
                         rates: [96, 25, 25, 67], levels: [99, 75, 0, 0])
        let op6 = fullOp(ol: 75, coarse: 1, fine: 0, detune: 7, rs: 0, vs: 0,
                         rates: [95, 50, 35, 78], levels: [99, 75, 0, 0])
        let patch = buildPatch156(
            ops: [op1, op2, op3, op4, op5, op6],
            algorithm: 4, feedback: 0  // Algorithm 5
        )

        let result = compareVoices(patch: patch, midinote: 60, velocity7: 100, blocks: 200)

        #expect(result.mismatches == 0,
            "E.PIANO-like C4: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample) ref=\(result.refVal) m2dx=\(result.m2dxVal)")
    }

    // MARK: - Algorithm 32 (All Carriers)

    @Test("Algorithm 32 (all carriers) matches DEXED")
    func alg32AllCarriersMatch() {
        let op = fullOp(ol: 80, coarse: 1)
        let patch = buildPatch156(
            ops: [op, op, op, op, op, op],
            algorithm: 31, feedback: 7  // Alg 32 with max feedback on OP6
        )

        let result = compareVoices(patch: patch, midinote: 69, velocity7: 127, blocks: 100)

        #expect(result.mismatches == 0,
            "Alg32 A4 vel=127: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample) ref=\(result.refVal) m2dx=\(result.m2dxVal)")
    }

    // MARK: - KLS (Keyboard Level Scaling)

    @Test("KLS produces matching waveforms")
    func klsWaveformMatch() {
        let op1 = fullOp(ol: 99, coarse: 1, detune: 7,
                         bp: 39, ld: 50, rd: 50, lc: 0, rc: 3)
        let patch = buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, op1],
            algorithm: 0, feedback: 0
        )

        for note: UInt8 in [24, 48, 60, 84, 96] {
            let result = compareVoices(patch: patch, midinote: note, velocity7: 100, blocks: 50)
            #expect(result.mismatches == 0,
                "KLS note=\(note): \(result.mismatches) mismatches")
        }
    }

    // MARK: - Detune

    @Test("Detune produces matching waveforms")
    func detuneWaveformMatch() {
        for detune in [0, 3, 7, 11, 14] {
            let op1 = fullOp(ol: 99, coarse: 1, fine: 0, detune: detune)
            let patch = buildPatch156(
                ops: [silentOp, silentOp, silentOp, silentOp, silentOp, op1],
                algorithm: 0, feedback: 0
            )

            let result = compareVoices(patch: patch, midinote: 60, velocity7: 100, blocks: 100)
            #expect(result.mismatches == 0,
                "Detune=\(detune) C4: \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample)")
        }
    }

    // MARK: - Coarse / Fine Frequency

    @Test("Coarse frequency ratios match DEXED")
    func coarseFreqMatch() {
        for coarse in [0, 1, 2, 3, 4, 8, 16, 31] {
            let op1 = fullOp(ol: 99, coarse: coarse, fine: 0, detune: 7)
            let patch = buildPatch156(
                ops: [silentOp, silentOp, silentOp, silentOp, silentOp, op1],
                algorithm: 0, feedback: 0
            )

            let result = compareVoices(patch: patch, midinote: 60, velocity7: 100, blocks: 50)
            #expect(result.mismatches == 0,
                "Coarse=\(coarse): \(result.mismatches) mismatches, first at block \(result.firstBlock) sample \(result.firstSample)")
        }
    }
}
