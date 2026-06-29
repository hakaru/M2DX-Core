// DX7Voice.swift
// M2DX-Core — DX7 6-OP voice with flag-based algorithm dispatch

import Darwin

// MARK: - Pitch EG

/// Simple 4-stage pitch envelope generator that outputs semitones directly.
/// Operates in Float arithmetic at block rate (64 samples/block).
/// Level 50 = center (0 semitones), 0 = -48 semitones, 99 = +48 semitones.
package struct PitchEG {
    var rates:  (UInt8, UInt8, UInt8, UInt8) = (99, 99, 99, 99)
    var levels: (UInt8, UInt8, UInt8, UInt8) = (50, 50, 50, 50)
    /// -1 = idle, 0-3 = active stages
    var stage: Int = -1
    /// Current interpolated level (0-99 float)
    var currentLevel: Float = 50.0
    var targetLevel: Float = 50.0
    var increment: Float = 0.0
    var down: Bool = false
    var enabled: Bool = false

    /// Current pitch offset in semitones (-48 to +48).
    var semitones: Float {
        (currentLevel - 50.0) / 49.0 * 48.0
    }

    mutating func noteOn(
        r0: UInt8, r1: UInt8, r2: UInt8, r3: UInt8,
        l0: UInt8, l1: UInt8, l2: UInt8, l3: UInt8,
        sampleRate: Float
    ) {
        rates  = (r0, r1, r2, r3)
        levels = (l0, l1, l2, l3)
        enabled = r0 != 99 || r1 != 99 || r2 != 99 || r3 != 99 ||
                  l0 != 50 || l1 != 50 || l2 != 50 || l3 != 50
        guard enabled else { stage = -1; return }

        currentLevel = Float(l0)   // Start at L0 (pre-attack level)
        stage = 0
        down = true
        advanceStage(sampleRate: sampleRate)
    }

    mutating func noteOff(sampleRate: Float) {
        guard enabled else { return }
        down = false
        if stage >= 0 && stage < 3 {
            stage = 3
            advanceStage(sampleRate: sampleRate)
        }
    }

    private mutating func advanceStage(sampleRate: Float) {
        guard stage >= 0 && stage < 4 else {
            stage = -1
            return
        }
        // DX7 Pitch EG stages:
        //  Stage 0: L0 → L1 at R0
        //  Stage 1: L1 → L2 at R1
        //  Stage 2: L2 → L3 at R2  (sustain while key held)
        //  Stage 3: L3 → L0 at R3  (release, return to pre-attack level)
        let lvl: Float
        let rate: UInt8
        switch stage {
        case 0: lvl = Float(levels.1); rate = rates.0
        case 1: lvl = Float(levels.2); rate = rates.1
        case 2: lvl = Float(levels.3); rate = rates.2
        case 3: lvl = Float(levels.0); rate = rates.3
        default: stage = -1; return
        }
        targetLevel = lvl

        let blocksPerSecond = sampleRate / Float(kBlockSize)
        if rate >= 99 {
            // Instant: jump immediately, recurse to next stage
            currentLevel = targetLevel
            increment = 0.0
            // Hold sustain stage when key is down
            if stage == 2 && down { return }
            stage += 1
            if stage < 4 {
                advanceStage(sampleRate: sampleRate)
            } else {
                stage = -1
                currentLevel = 50.0
            }
        } else {
            // Exponential time curve: rate 0 ≈ very slow, rate 98 ≈ fast
            let timeSeconds = powf(10.0, Float(99 - Int(rate)) / 30.0) * 0.01
            let totalBlocks = max(1.0, timeSeconds * blocksPerSecond)
            increment = (targetLevel - currentLevel) / totalBlocks
        }
    }

    /// Call once per 64-sample block. Returns true while envelope is active.
    @discardableResult
    mutating func process(sampleRate: Float) -> Bool {
        guard enabled && stage >= 0 else { return false }

        // Sustain: hold at L3 while key is held
        if stage == 2 && down && increment == 0.0 { return true }

        if increment == 0.0 {
            // Already at target — advance to next stage
            if stage == 2 && down { return true }
            stage += 1
            if stage >= 4 { stage = -1; currentLevel = 50.0; return false }
            advanceStage(sampleRate: sampleRate)
            return stage >= 0
        }

        // Interpolate toward target
        currentLevel += increment
        let reached: Bool
        if increment > 0 {
            reached = currentLevel >= targetLevel
        } else {
            reached = currentLevel <= targetLevel
        }

        if reached {
            currentLevel = targetLevel
            increment = 0.0
            if stage == 2 && down { return true }
            stage += 1
            if stage >= 4 { stage = -1; currentLevel = 50.0; return false }
            advanceStage(sampleRate: sampleRate)
        }

        return stage >= 0
    }
}

// MARK: - DX7 Voice

/// DX7 voice using flag-based algorithm dispatch.
/// Processes N=64 sample blocks using Int32 Q24 arithmetic.
package struct DX7Voice {
    var ops = (DX7Operator(), DX7Operator(), DX7Operator(),
               DX7Operator(), DX7Operator(), DX7Operator())
    var note: UInt8 = 0
    var midiNote: UInt8 = 0
    var active = false
    var sustained = false
    var releasing = false
    var algorithm: Int = 0
    var pitchBendFactor: Float = 1.0
    var slotId: Int = 0
    var lfoAmpMod: Int32 = 0
    var feedbackShiftValue: Int = 16
    var engineMode: FMEngine = .modern

    // MIDI 2.0 Per-Note state
    var perNotePitchBendFactor: Float = 1.0
    var perNoteVolume: Float = 1.0
    var perNoteAftertouch: Float = 0.0
    /// #76: per-voice pan [-1, 1] captured at note-on when the slot's panRandom
    /// is on. Read by the render mix only in random mode; -1 = L, +1 = R.
    var pan: Float = 0.0
    /// #79 portamento: this voice's current pitch deviation (cents) from its
    /// target note. Seeded at note-on (prev − target), decays to 0 on the render
    /// path at the portamento rate. 0 = arrived (no glide; default = no effect).
    var glideOffsetCents: Float = 0.0
    var detached: Bool = false

    // Pitch EG
    var pitchEG = PitchEG()

    /// Reset only the per-note controllers (MPE Per-Note Management "Reset"),
    /// leaving the voice's pitch EG running.
    mutating func resetPerNoteControllers() {
        perNotePitchBendFactor = 1.0
        perNoteVolume = 1.0
        perNoteAftertouch = 0.0
        detached = false
    }

    mutating func resetPerNoteState() {
        resetPerNoteControllers()
        pitchEG = PitchEG()
    }

    mutating func checkActive() {
        if active {
            if !(ops.0.isActive || ops.1.isActive || ops.2.isActive ||
                 ops.3.isActive || ops.4.isActive || ops.5.isActive) {
                active = false
                releasing = false
            }
        }
    }

    mutating func setSampleRate(_ sr: Float) {
        ops.0.setSampleRate(sr); ops.1.setSampleRate(sr); ops.2.setSampleRate(sr)
        ops.3.setSampleRate(sr); ops.4.setSampleRate(sr); ops.5.setSampleRate(sr)
    }

    mutating func noteOn(_ n: UInt8, velocity16: UInt16, midiNote originalNote: UInt8? = nil, detuneFactor: Float = 1.0) {
        note = n
        midiNote = originalNote ?? n
        active = true
        releasing = false
        sustained = false   // a stolen/reused voice must not inherit pedal-hold
        resetPerNoteState()
        let freq: Float = kMIDIFreqLUT[Int(n & 0x7F)] * detuneFactor
        ops.0.noteOn(baseFreq: freq); ops.1.noteOn(baseFreq: freq); ops.2.noteOn(baseFreq: freq)
        ops.3.noteOn(baseFreq: freq); ops.4.noteOn(baseFreq: freq); ops.5.noteOn(baseFreq: freq)
    }

    mutating func noteOff(held: Bool = false) {
        if held { sustained = true; return }
        sustained = false
        releasing = true
        ops.0.noteOff(); ops.1.noteOff(); ops.2.noteOff()
        ops.3.noteOff(); ops.4.noteOff(); ops.5.noteOff()
    }

    mutating func releaseSustain() {
        if sustained { sustained = false; noteOff() }
    }

    mutating func applyPitchBend(_ factor: Float) {
        pitchBendFactor = factor
        ops.0.applyPitchBend(factor); ops.1.applyPitchBend(factor); ops.2.applyPitchBend(factor)
        ops.3.applyPitchBend(factor); ops.4.applyPitchBend(factor); ops.5.applyPitchBend(factor)
    }

    /// Test introspection: current frequency of operator `i` (0…5).
    func operatorFrequency(_ i: Int) -> Float {
        switch i {
        case 0: return ops.0.frequency
        case 1: return ops.1.frequency
        case 2: return ops.2.frequency
        case 3: return ops.3.frequency
        case 4: return ops.4.frequency
        case 5: return ops.5.frequency
        default: return 0
        }
    }

    /// Update EG and compute gain for all 6 operators (once per block)
    @inline(__always)
    mutating func updateGains() {
        let lfaMod = lfoAmpMod
        ops.0.updateGain(lfoAmpMod: lfaMod); ops.1.updateGain(lfoAmpMod: lfaMod)
        ops.2.updateGain(lfoAmpMod: lfaMod); ops.3.updateGain(lfoAmpMod: lfaMod)
        ops.4.updateGain(lfoAmpMod: lfaMod); ops.5.updateGain(lfoAmpMod: lfaMod)
    }

    /// Render one block, dispatching to the selected FM engine.
    @inline(__always)
    mutating func renderBlock(
        output: UnsafeMutablePointer<Int32>,
        bus1: UnsafeMutablePointer<Int32>,
        bus2: UnsafeMutablePointer<Int32>,
        blockSize: Int
    ) {
        guard active else { return }
        if engineMode == .modern {
            renderBlockModern(output: output, bus1: bus1, bus2: bus2, blockSize: blockSize)
        } else {
            renderBlockMarkI(output: output, bus1: bus1, bus2: bus2, blockSize: blockSize)
        }
    }

    /// Render one block using flag-based algorithm dispatch (Modern engine).
    @inline(__always)
    mutating func renderBlockModern(
        output: UnsafeMutablePointer<Int32>,
        bus1: UnsafeMutablePointer<Int32>,
        bus2: UnsafeMutablePointer<Int32>,
        blockSize: Int
    ) {
        let alg = kAlgorithmFlags[max(0, min(algorithm, 31))]  // lower clamp = defense-in-depth
        var hasContents = (true, false, false)  // output, bus1, bus2

        for opIdx in 0..<6 {
            let flags: UInt8
            switch opIdx {
            case 0: flags = alg.0
            case 1: flags = alg.1
            case 2: flags = alg.2
            case 3: flags = alg.3
            case 4: flags = alg.4
            case 5: flags = alg.5
            default: flags = 0
            }

            let add = (flags & 0x04) != 0
            let inbus = Int((flags >> 4) & 3)
            let outbus = Int(flags & 3)
            let isFbOp = (flags & 0xC0) == 0xC0

            let outptr: UnsafeMutablePointer<Int32>
            switch outbus {
            case 1: outptr = bus1
            case 2: outptr = bus2
            default: outptr = output
            }

            let gain1: Int32
            let gain2: Int32
            switch opIdx {
            case 0:
                gain1 = ops.0.gainOut
                gain2 = exp2LookupQ24(ops.0.levelIn &- Int32(14 * (1 << 24)))
                ops.0.gainOut = gain2
            case 1:
                gain1 = ops.1.gainOut
                gain2 = exp2LookupQ24(ops.1.levelIn &- Int32(14 * (1 << 24)))
                ops.1.gainOut = gain2
            case 2:
                gain1 = ops.2.gainOut
                gain2 = exp2LookupQ24(ops.2.levelIn &- Int32(14 * (1 << 24)))
                ops.2.gainOut = gain2
            case 3:
                gain1 = ops.3.gainOut
                gain2 = exp2LookupQ24(ops.3.levelIn &- Int32(14 * (1 << 24)))
                ops.3.gainOut = gain2
            case 4:
                gain1 = ops.4.gainOut
                gain2 = exp2LookupQ24(ops.4.levelIn &- Int32(14 * (1 << 24)))
                ops.4.gainOut = gain2
            case 5:
                gain1 = ops.5.gainOut
                gain2 = exp2LookupQ24(ops.5.levelIn &- Int32(14 * (1 << 24)))
                ops.5.gainOut = gain2
            default: gain1 = 0; gain2 = 0
            }

            guard gain1 >= kGainThreshold || gain2 >= kGainThreshold else {
                if !add {
                    switch outbus {
                    case 1: hasContents.1 = false
                    case 2: hasContents.2 = false
                    default: break
                    }
                }
                switch opIdx {
                case 0: ops.0.phase = ops.0.phase &+ (ops.0.freq &* Int32(blockSize))
                case 1: ops.1.phase = ops.1.phase &+ (ops.1.freq &* Int32(blockSize))
                case 2: ops.2.phase = ops.2.phase &+ (ops.2.freq &* Int32(blockSize))
                case 3: ops.3.phase = ops.3.phase &+ (ops.3.freq &* Int32(blockSize))
                case 4: ops.4.phase = ops.4.phase &+ (ops.4.freq &* Int32(blockSize))
                case 5: ops.5.phase = ops.5.phase &+ (ops.5.freq &* Int32(blockSize))
                default: break
                }
                continue
            }

            let shouldAdd: Bool
            switch outbus {
            case 1: shouldAdd = add && hasContents.1
            case 2: shouldAdd = add && hasContents.2
            default: shouldAdd = add
            }

            let opPhase: Int32
            let opFreq: Int32
            switch opIdx {
            case 0: opPhase = ops.0.phase; opFreq = ops.0.freq
            case 1: opPhase = ops.1.phase; opFreq = ops.1.freq
            case 2: opPhase = ops.2.phase; opFreq = ops.2.freq
            case 3: opPhase = ops.3.phase; opFreq = ops.3.freq
            case 4: opPhase = ops.4.phase; opFreq = ops.4.freq
            case 5: opPhase = ops.5.phase; opFreq = ops.5.freq
            default: opPhase = 0; opFreq = 0
            }

            if inbus == 0 || (inbus == 1 && !hasContents.1) || (inbus == 2 && !hasContents.2) {
                if isFbOp && feedbackShiftValue < 16 {
                    var fbBuf: (Int32, Int32)
                    switch opIdx {
                    case 0: fbBuf = ops.0.fbBuf
                    case 1: fbBuf = ops.1.fbBuf
                    case 2: fbBuf = ops.2.fbBuf
                    case 3: fbBuf = ops.3.fbBuf
                    case 4: fbBuf = ops.4.fbBuf
                    case 5: fbBuf = ops.5.fbBuf
                    default: fbBuf = (0, 0)
                    }
                    computeFb(outptr, opPhase, opFreq, gain1, gain2,
                              &fbBuf, feedbackShiftValue, shouldAdd, blockSize)
                    switch opIdx {
                    case 0: ops.0.fbBuf = fbBuf
                    case 1: ops.1.fbBuf = fbBuf
                    case 2: ops.2.fbBuf = fbBuf
                    case 3: ops.3.fbBuf = fbBuf
                    case 4: ops.4.fbBuf = fbBuf
                    case 5: ops.5.fbBuf = fbBuf
                    default: break
                    }
                } else {
                    computePure(outptr, opPhase, opFreq, gain1, gain2, shouldAdd, blockSize)
                }
            } else {
                let inptr: UnsafePointer<Int32>
                if inbus == 1 { inptr = UnsafePointer(bus1) }
                else { inptr = UnsafePointer(bus2) }
                computeMod(outptr, inptr, opPhase, opFreq, gain1, gain2, shouldAdd, blockSize)
            }

            switch outbus {
            case 1: hasContents.1 = true
            case 2: hasContents.2 = true
            default: break
            }

            let newPhase = opPhase &+ (opFreq &* Int32(blockSize))
            switch opIdx {
            case 0: ops.0.phase = newPhase
            case 1: ops.1.phase = newPhase
            case 2: ops.2.phase = newPhase
            case 3: ops.3.phase = newPhase
            case 4: ops.4.phase = newPhase
            case 5: ops.5.phase = newPhase
            default: break
            }
        }
    }

    /// Render one block using the Mark I (OPS-chip) FM path.
    /// Adapted verbatim from `renderBlockModern`; the only substitutions are:
    ///   * gain → log-attenuation (`markIAtten`, larger = quieter)
    ///   * silence guard inverted (smaller attenuation = audible)
    ///   * kernels → `*MkI` variants
    ///   * fused Alg 4 / Alg 6 feedback chains via `computeFb2MkI` / `computeFb3MkI`
    @inline(__always)
    mutating func renderBlockMarkI(
        output: UnsafeMutablePointer<Int32>,
        bus1: UnsafeMutablePointer<Int32>,
        bus2: UnsafeMutablePointer<Int32>,
        blockSize: Int
    ) {
        let algIndex = max(0, min(algorithm, 31))
        let alg = kAlgorithmFlags[algIndex]  // lower clamp = defense-in-depth
        var hasContents = (true, false, false)  // output, bus1, bus2

        // Mark I deepens feedback by 2 shifts for the 3/6/32 algorithms.
        let fbShiftMkI = (algIndex == 3 || algIndex == 5 || algIndex == 31)
            ? min(feedbackShiftValue + 2, 16)
            : feedbackShiftValue

        var opIdx = 0
        while opIdx < 6 {
            let flags: UInt8
            switch opIdx {
            case 0: flags = alg.0
            case 1: flags = alg.1
            case 2: flags = alg.2
            case 3: flags = alg.3
            case 4: flags = alg.4
            case 5: flags = alg.5
            default: flags = 0
            }

            let add = (flags & 0x04) != 0
            let inbus = Int((flags >> 4) & 3)
            let outbus = Int(flags & 3)
            let isFbOp = (flags & 0xC0) == 0xC0

            let outptr: UnsafeMutablePointer<Int32>
            switch outbus {
            case 1: outptr = bus1
            case 2: outptr = bus2
            default: outptr = output
            }

            // Gain setup (Mark I): atten2 = this block's attenuation, atten1 = previous
            // block's (carried on the operator for the ramp). Larger = quieter.
            let atten1: UInt16
            let atten2: UInt16
            switch opIdx {
            case 0: atten2 = markIAtten(ops.0.levelIn); atten1 = ops.0.markIGainOut; ops.0.markIGainOut = atten2
            case 1: atten2 = markIAtten(ops.1.levelIn); atten1 = ops.1.markIGainOut; ops.1.markIGainOut = atten2
            case 2: atten2 = markIAtten(ops.2.levelIn); atten1 = ops.2.markIGainOut; ops.2.markIGainOut = atten2
            case 3: atten2 = markIAtten(ops.3.levelIn); atten1 = ops.3.markIGainOut; ops.3.markIGainOut = atten2
            case 4: atten2 = markIAtten(ops.4.levelIn); atten1 = ops.4.markIGainOut; ops.4.markIGainOut = atten2
            case 5: atten2 = markIAtten(ops.5.levelIn); atten1 = ops.5.markIGainOut; ops.5.markIGainOut = atten2
            default: atten1 = UInt16(kMarkIEnvMax); atten2 = UInt16(kMarkIEnvMax)
            }

            // Silence guard (inverted sense): audible when attenuation is BELOW threshold.
            guard atten1 < kMarkILevelThresh || atten2 < kMarkILevelThresh else {
                if !add {
                    switch outbus {
                    case 1: hasContents.1 = false
                    case 2: hasContents.2 = false
                    default: break
                    }
                }
                switch opIdx {
                case 0: ops.0.phase = ops.0.phase &+ (ops.0.freq &* Int32(blockSize))
                case 1: ops.1.phase = ops.1.phase &+ (ops.1.freq &* Int32(blockSize))
                case 2: ops.2.phase = ops.2.phase &+ (ops.2.freq &* Int32(blockSize))
                case 3: ops.3.phase = ops.3.phase &+ (ops.3.freq &* Int32(blockSize))
                case 4: ops.4.phase = ops.4.phase &+ (ops.4.freq &* Int32(blockSize))
                case 5: ops.5.phase = ops.5.phase &+ (ops.5.freq &* Int32(blockSize))
                default: break
                }
                opIdx += 1
                continue
            }

            let shouldAdd: Bool
            switch outbus {
            case 1: shouldAdd = add && hasContents.1
            case 2: shouldAdd = add && hasContents.2
            default: shouldAdd = add
            }

            let opPhase: Int32
            let opFreq: Int32
            switch opIdx {
            case 0: opPhase = ops.0.phase; opFreq = ops.0.freq
            case 1: opPhase = ops.1.phase; opFreq = ops.1.freq
            case 2: opPhase = ops.2.phase; opFreq = ops.2.freq
            case 3: opPhase = ops.3.phase; opFreq = ops.3.freq
            case 4: opPhase = ops.4.phase; opFreq = ops.4.freq
            case 5: opPhase = ops.5.phase; opFreq = ops.5.freq
            default: opPhase = 0; opFreq = 0
            }

            // Fused multi-op feedback chains: Alg 4 (index 3, 3-op) and Alg 6
            // (index 5, 2-op). Triggered when the feedback op (opIdx 0) is reached
            // with feedback enabled. The downstream ops are consumed (phase advanced
            // + index skipped) so they are not re-processed below.
            if isFbOp && feedbackShiftValue < 16 && opIdx == 0 && (algIndex == 3 || algIndex == 5) {
                var fbBuf = ops.0.fbBuf
                if algIndex == 5 {
                    // Alg 6: op0 (OP6, fb) → op1 (OP5). Operator order [0]=OP6, [1]=OP5.
                    var p = MarkIChainParams(
                        phase:   (ops.0.phase, ops.1.phase, 0),
                        freq:    (ops.0.freq,  ops.1.freq,  0),
                        levelIn: (ops.0.levelIn, ops.1.levelIn, 0)
                    )
                    computeFb2MkI(output, &p, atten01: atten1, atten02: atten2,
                                  fbBuf: &fbBuf, fbShift: fbShiftMkI)
                    ops.0.fbBuf = fbBuf
                    ops.0.phase = p.phase.0
                    ops.1.phase = p.phase.1
                    // #85: OP6's ramp anchor (ops.0.markIGainOut) is already its own
                    // atten2, set in the gain switch above. The follower (OP5) uses a
                    // constant atten inside computeFb2MkI and needs no anchor — same as
                    // the Alg 4 branch below. (A prior line wrote OP5's atten into OP6's
                    // anchor here, corrupting OP6's next-block ramp when OP5≠OP6 level.)
                    opIdx = 2  // consumed op0 + op1
                } else {
                    // Alg 4: op0 (OP6, fb) → op1 (OP5) → op2 (OP4).
                    var p = MarkIChainParams(
                        phase:   (ops.0.phase, ops.1.phase, ops.2.phase),
                        freq:    (ops.0.freq,  ops.1.freq,  ops.2.freq),
                        levelIn: (ops.0.levelIn, ops.1.levelIn, ops.2.levelIn)
                    )
                    computeFb3MkI(output, &p, atten01: atten1, atten02: atten2,
                                  fbBuf: &fbBuf, fbShift: fbShiftMkI)
                    ops.0.fbBuf = fbBuf
                    ops.0.phase = p.phase.0
                    ops.1.phase = p.phase.1
                    ops.2.phase = p.phase.2
                    opIdx = 3  // consumed op0 + op1 + op2
                }
                hasContents.0 = true
                continue
            }

            if inbus == 0 || (inbus == 1 && !hasContents.1) || (inbus == 2 && !hasContents.2) {
                if isFbOp && feedbackShiftValue < 16 {
                    var fbBuf: (Int32, Int32)
                    switch opIdx {
                    case 0: fbBuf = ops.0.fbBuf
                    case 1: fbBuf = ops.1.fbBuf
                    case 2: fbBuf = ops.2.fbBuf
                    case 3: fbBuf = ops.3.fbBuf
                    case 4: fbBuf = ops.4.fbBuf
                    case 5: fbBuf = ops.5.fbBuf
                    default: fbBuf = (0, 0)
                    }
                    computeFbMkI(outptr, phase0: opPhase, freq: opFreq,
                                 atten1: atten1, atten2: atten2,
                                 fbBuf: &fbBuf, fbShift: fbShiftMkI, add: shouldAdd, n: blockSize)
                    switch opIdx {
                    case 0: ops.0.fbBuf = fbBuf
                    case 1: ops.1.fbBuf = fbBuf
                    case 2: ops.2.fbBuf = fbBuf
                    case 3: ops.3.fbBuf = fbBuf
                    case 4: ops.4.fbBuf = fbBuf
                    case 5: ops.5.fbBuf = fbBuf
                    default: break
                    }
                } else {
                    computePureMkI(outptr, phase0: opPhase, freq: opFreq,
                                   atten1: atten1, atten2: atten2, add: shouldAdd, n: blockSize)
                }
            } else {
                let inptr: UnsafePointer<Int32>
                if inbus == 1 { inptr = UnsafePointer(bus1) }
                else { inptr = UnsafePointer(bus2) }
                computeModMkI(outptr, inptr, phase0: opPhase, freq: opFreq,
                              atten1: atten1, atten2: atten2, add: shouldAdd, n: blockSize)
            }

            switch outbus {
            case 1: hasContents.1 = true
            case 2: hasContents.2 = true
            default: break
            }

            let newPhase = opPhase &+ (opFreq &* Int32(blockSize))
            switch opIdx {
            case 0: ops.0.phase = newPhase
            case 1: ops.1.phase = newPhase
            case 2: ops.2.phase = newPhase
            case 3: ops.3.phase = newPhase
            case 4: ops.4.phase = newPhase
            case 5: ops.5.phase = newPhase
            default: break
            }
            opIdx += 1
        }
    }

    // MARK: - Compute Functions

    @inline(__always)
    private func computeMod(
        _ output: UnsafeMutablePointer<Int32>,
        _ input: UnsafePointer<Int32>,
        _ phase0: Int32, _ freq: Int32,
        _ gain1: Int32, _ gain2: Int32,
        _ add: Bool, _ n: Int
    ) {
        // Full block: exact shift (bit-identical to the reference). Partial final
        // block: divide by the actual length so the ramp still reaches gain2.
        let dgain = (n == kBlockSize)
            ? (gain2 &- gain1 &+ Int32(n >> 1)) >> kLgBlockSize
            : (gain2 &- gain1) / Int32(n)
        var gain = gain1
        var phase = phase0
        for i in 0..<n {
            gain = gain &+ dgain
            let y = sinLookupQ24(phase &+ input[i])
            let y1 = Int32((Int64(y) &* Int64(gain)) >> 24)
            if add { output[i] = output[i] &+ y1 } else { output[i] = y1 }
            phase = phase &+ freq
        }
    }

    @inline(__always)
    private func computePure(
        _ output: UnsafeMutablePointer<Int32>,
        _ phase0: Int32, _ freq: Int32,
        _ gain1: Int32, _ gain2: Int32,
        _ add: Bool, _ n: Int
    ) {
        // Full block: exact shift (bit-identical to the reference). Partial final
        // block: divide by the actual length so the ramp still reaches gain2.
        let dgain = (n == kBlockSize)
            ? (gain2 &- gain1 &+ Int32(n >> 1)) >> kLgBlockSize
            : (gain2 &- gain1) / Int32(n)
        var gain = gain1
        var phase = phase0
        for i in 0..<n {
            gain = gain &+ dgain
            let y = sinLookupQ24(phase)
            let y1 = Int32((Int64(y) &* Int64(gain)) >> 24)
            if add { output[i] = output[i] &+ y1 } else { output[i] = y1 }
            phase = phase &+ freq
        }
    }

    @inline(__always)
    private func computeFb(
        _ output: UnsafeMutablePointer<Int32>,
        _ phase0: Int32, _ freq: Int32,
        _ gain1: Int32, _ gain2: Int32,
        _ fbBuf: inout (Int32, Int32),
        _ fbShift: Int, _ add: Bool, _ n: Int
    ) {
        // Full block: exact shift (bit-identical to the reference). Partial final
        // block: divide by the actual length so the ramp still reaches gain2.
        let dgain = (n == kBlockSize)
            ? (gain2 &- gain1 &+ Int32(n >> 1)) >> kLgBlockSize
            : (gain2 &- gain1) / Int32(n)
        var gain = gain1
        var phase = phase0
        var y0 = fbBuf.0
        var y = fbBuf.1
        for i in 0..<n {
            gain = gain &+ dgain
            let scaledFb = (y0 &+ y) >> (fbShift + 1)
            y0 = y
            y = sinLookupQ24(phase &+ scaledFb)
            y = Int32((Int64(y) &* Int64(gain)) >> 24)
            if add { output[i] = output[i] &+ y } else { output[i] = y }
            phase = phase &+ freq
        }
        fbBuf = (y0, y)
    }

    // MARK: - Indexed Operator Access

    @inline(__always)
    mutating func withOp(_ i: Int, _ body: (inout DX7Operator) -> Void) {
        switch i {
        case 0: body(&ops.0)
        case 1: body(&ops.1)
        case 2: body(&ops.2)
        case 3: body(&ops.3)
        case 4: body(&ops.4)
        case 5: body(&ops.5)
        default: break
        }
    }

    mutating func applyParams(_ params: OperatorSnapshot, opIndex: Int) {
        let pb = pitchBendFactor
        withOp(opIndex) { op in
            op.setOutputLevel(params.dx7OutputLevel)
            op.ratio = params.ratio
            op.detune = params.detune
            op.env.setRates(params.dx7EgR0, params.dx7EgR1, params.dx7EgR2, params.dx7EgR3)
            op.env.setLevels(params.dx7EgL0, params.dx7EgL1, params.dx7EgL2, params.dx7EgL3)
            // Recompute frequency from the new ratio/detune so live edits affect a
            // held note (ratio/detune alone don't refresh `freq`; only note-on and
            // applyPitchBend do). Skip fixed-frequency operators.
            if !op.isFixedFreq { op.applyPitchBend(pb) }
        }
    }
}
