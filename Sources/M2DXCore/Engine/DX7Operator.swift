// DX7Operator.swift
// M2DX-Core — DX7 Int32 Q24 FM operator

import Darwin

// MARK: - DX7 Operator

/// DX7 FM operator using Q24 integer pipeline.
/// Phase is Q24 (full cycle = 2^24), output is Q24 signed.
/// All processing in Int32 — no Float on the hot path.
package struct DX7Operator {
    var sampleRate: Float = 44100
    var frequency: Float = 440
    var ratio: Float = 1.0
    var detune: Float = 1.0
    var detuneCents: Float = 0   // #96: DX7 detune param − 7 (−7…+7); per-note factor computed at noteOn
    var outputLevel: Int = 99
    // Highest raw OL used by the current EG trajectory. Keep the raw value so
    // legato KLS clipping cannot accumulate an unbounded attenuation offset.
    private var envelopeReferenceOL: Int = 99
    private var heldKeyboardOffset: Int? = nil
    private var heldReferenceOL: Int = 99
    private var releaseReferenceOL: Int? = nil
    private var releaseStartLevel: Int32 = 0
    private var releaseStartL3: Int = 99
    private var releaseStartOutput: Int? = nil
    var phase: Int32 = 0          // Q24 phase accumulator
    var freq: Int32 = 0           // Q24 per-sample phase increment
    var gainOut: Int32 = 0        // Previous block's gain (for interpolation)
    var markIGainOut: UInt16 = UInt16(kMarkIEnvMax)  // Previous block's Mark I attenuation (for ramp)
    var levelIn: Int32 = 0        // EG level input to Exp2 (Q24)
    var fbBuf: (Int32, Int32) = (0, 0)  // Feedback delay line
    var fbShift: Int = 16         // Feedback shift (16=disabled, 1=max)
    var env = DX7Envelope()

    var outlevelMicrosteps: Int = 4064
    var velocityOffset: Int = 0
    var klsOffset: Int = 0
    var amsDepth: Int32 = 0       // AMS sensitivity Q24

    var isFixedFreq: Bool = false
    var baseFrequency: Float = 440

    var isActive: Bool { env.isActive }

    mutating func setSampleRate(_ sr: Float) {
        sampleRate = sr
        updateFreq()
        env.setSampleRate(sr)
    }

    mutating func noteOn(baseFreq: Float) {
        baseFrequency = baseFreq
        // #96: DEXED applies a frequency-dependent operator detune (more cents in the bass, less
        // in the treble), not a pitch-independent constant ±7c. Recompute the factor per note.
        // (Fixed-freq ops get their frequency overridden right after note-on; detune cancels.)
        detune = dexedDetuneFactor(baseFreq, detuneCents: detuneCents)
        frequency = baseFreq * ratio * detune
        updateFreq()
        envelopeReferenceOL = outputLevel
        heldKeyboardOffset = nil
        releaseReferenceOL = nil
        env.noteOn()
        phase = 0; fbBuf = (0, 0); gainOut = 0
    }

    mutating func applyPitchBend(_ factor: Float) {
        frequency = baseFrequency * ratio * detune * factor
        updateFreq()
    }

    mutating func applyPitchBendFixed(_ factor: Float) {
        if isFixedFreq { return }
        applyPitchBend(factor)
    }

    mutating func noteOff() {
        if let heldKeyboardOffset, env.ix == 3, env.down {
            envelopeReferenceOL = max(heldReferenceOL, outputLevel)
            let current = combinedOutputLevel(outputLevel, keyboardOffset: heldKeyboardOffset)
            let heldReference = env.levelFor(env.levels.2,
                output: combinedOutputLevel(envelopeReferenceOL, keyboardOffset: heldKeyboardOffset))
            let releaseReference = env.levelFor(env.levels.3,
                output: combinedOutputLevel(envelopeReferenceOL, keyboardOffset: klsOffset))
            // If the old reference adds no held headroom, discard its history.
            // A flat reference also has no duration to preserve; use the edited
            // trajectory so a non-flat release is not mistaken for immediate idle.
            if env.levelFor(env.levels.2, output: current) == heldReference || heldReference == releaseReference {
                envelopeReferenceOL = outputLevel
            }
            let reference = combinedOutputLevel(envelopeReferenceOL, keyboardOffset: heldKeyboardOffset)
            releaseReferenceOL = envelopeReferenceOL
            releaseStartL3 = env.levels.2
            releaseStartOutput = nil
            env.setReleaseReference(
                level: env.levelFor(releaseStartL3, output: reference), output: reference,
                target: combinedOutputLevel(envelopeReferenceOL, keyboardOffset: klsOffset))
            releaseStartLevel = env.level
        }
        env.noteOff()
    }

    mutating func setOutputLevel(_ level: Int) {
        outputLevel = min(99, max(0, level))
        // The reference release keeps running while OL changes its audible endpoints.
        if releaseReferenceOL != nil, env.isActive { return }
        envelopeReferenceOL = env.isActive ? max(envelopeReferenceOL, outputLevel) : outputLevel
        env.updateOutputLevel(combinedOutputLevel(outputLevel, keyboardOffset: heldKeyboardOffset ?? klsOffset))
        refreshReleaseTarget()
    }

    mutating func setEnvelopeLevels(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        if releaseReferenceOL != nil, env.isActive,
           scaleOutputLevel(env.levels.3) >> 1 != scaleOutputLevel(min(99, max(0, d))) >> 1,
           let heldKeyboardOffset {
            // L4 changes the trajectory itself. Anchor its new start at the current
            // audible level before replacing the old endpoint, so R4 continues
            // smoothly even when the old reference and edited OL clip differently.
            let audibleLevel = releaseLevel(env.level)
            let output = combinedOutputLevel(outputLevel, keyboardOffset: heldKeyboardOffset)
            releaseStartOutput = scaleOutputLevel(outputLevel) << 5
            releaseStartLevel = audibleLevel
            releaseReferenceOL = outputLevel
            env.setReleaseReference(level: audibleLevel, output: output,
                target: combinedOutputLevel(outputLevel, keyboardOffset: klsOffset))
        }
        env.setLevels(a, b, c, d)
    }

    /// Called before replacing KLS on a legato retarget. Once L3 is held, its
    /// audible level belongs to this key until note-off, even as pitch changes.
    mutating func preserveHeldKeyboardLevel() {
        if heldKeyboardOffset == nil, env.ix == 3, env.down {
            heldKeyboardOffset = klsOffset
            heldReferenceOL = envelopeReferenceOL
        }
    }

    /// Follow the legato note's KLS while retaining the running envelope trajectory.
    mutating func refreshKeyboardOutputLevel() {
        if heldKeyboardOffset != nil {
            refreshReleaseTarget()
        } else {
            env.updateKeyboardOutputLevel(combinedOutputLevel(outputLevel, keyboardOffset: klsOffset),
                reference: combinedOutputLevel(envelopeReferenceOL, keyboardOffset: klsOffset))
        }
    }

    private mutating func refreshReleaseTarget() {
        guard heldKeyboardOffset != nil else { return }
        env.releaseReferenceOutput = combinedOutputLevel(releaseReferenceOL ?? envelopeReferenceOL, keyboardOffset: klsOffset)
        env.recalcTargetLevel()
    }

    private func combinedOutputLevel(_ ol: Int, keyboardOffset: Int) -> Int {
        max(0, (min(127, scaleOutputLevel(ol) + keyboardOffset) << 5) + velocityOffset)
    }

    /// Update gain from EG. Called once per block before compute.
    @inline(__always)
    mutating func updateGain(lfoAmpMod: Int32) {
        let wasActive = env.isActive
        let egLevel = env.getsample()
        levelIn = wasActive && releaseReferenceOL != nil ? releaseLevel(egLevel) : egLevel

        // Amplitude modulation (LFO AMD, controller EG bias #163) reaches only operators with AMS.
        if amsDepth > 0 && lfoAmpMod > 0 {
            let amod = Int32((Int64(lfoAmpMod) * Int64(amsDepth)) >> 24)
            levelIn = levelIn &- amod
        }
    }

    /// Project the retained release onto the edited start/end levels. The start
    /// belongs to the held key and L3 at note-off; the end belongs to the current
    /// key and L4. A constant offset cannot represent different KLS clipping at
    /// those two ends. Restoring the reference OL makes this mapping bit-exact.
    @inline(__always)
    private func releaseLevel(_ referenceLevel: Int32) -> Int32 {
        guard let heldKeyboardOffset else { return referenceLevel }
        let nominalStart: Int32
        if let releaseStartOutput {
            // A retargeted release can have risen from a floor-clamped L3. Use
            // the raw OL difference here: either key's clipped KLS output can
            // otherwise hide a real attenuation change. Clamp only the result.
            nominalStart = releaseStartLevel
                + Int32(((scaleOutputLevel(outputLevel) << 5) - releaseStartOutput) << 16)
        } else {
            nominalStart = env.levelFor(releaseStartL3,
                output: combinedOutputLevel(outputLevel, keyboardOffset: heldKeyboardOffset))
        }
        let ceiling = env.levelFor(99, output: combinedOutputLevel(99, keyboardOffset: 127))
        let start = min(ceiling, max(16 << 16, nominalStart))
        let end = env.levelFor(env.levels.3,
            output: combinedOutputLevel(outputLevel, keyboardOffset: klsOffset))
        let referenceEnd = env.targetLevel
        if start == releaseStartLevel, end == referenceEnd { return referenceLevel }
        let span = Int64(releaseStartLevel) - Int64(referenceEnd)
        guard span != 0 else { return end }
        // Limit rounding at the endpoints rather than extrapolating extra gain.
        let distance = Int64(referenceLevel) - Int64(referenceEnd)
        let progress = span > 0 ? min(span, max(0, distance)) : max(span, min(0, distance))
        return end + Int32((Int64(start) - Int64(end)) * progress / span)
    }

    mutating func updateFreqPublic() { updateFreq() }

    private mutating func updateFreq() {
        let inc = Double(frequency) / Double(sampleRate) * Double(1 << 24)
        // Guard the Double->Int conversion: a non-finite or out-of-range `inc`
        // (e.g. sampleRate 0 or an extreme ratio) would otherwise trap here on
        // the render thread. Clamp into Int32 range and treat non-finite as 0.
        guard inc.isFinite else { freq = 0; return }
        freq = Int32(min(Double(Int32.max), max(Double(Int32.min), inc)))
    }
}
