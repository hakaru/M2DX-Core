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

    mutating func noteOff() { env.noteOff() }

    mutating func setOutputLevel(_ level: Int) {
        outputLevel = min(99, max(0, level))
        let scaledOL = scaleOutputLevel(outputLevel)
        env.outlevel = max(0, (min(127, scaledOL + klsOffset) << 5) + velocityOffset)
    }

    /// Update gain from EG. Called once per block before compute.
    @inline(__always)
    mutating func updateGain(lfoAmpMod: Int32, egBiasOL: Int32 = 0) {
        let egLevel = env.getsample()
        levelIn = egLevel

        // #97: controller→EG bias raises the operator output level in real time. Apply it as an
        // exact level offset through the real scaleOutputLevel curve (= raising OL by `egBiasOL`
        // points), so a breath/AT/wheel/foot controller assigned to EG bias brightens + swells
        // the whole voice — the DX7's main expressive dynamics path. (OL-point scale calibratable.)
        if egBiasOL > 0 {
            // Raise the operator level by egBiasOL OL points, through the SAME `min(127, …+klsOffset)`
            // ceiling the real `env.outlevel` uses — so the bias never pushes a key-scaled operator
            // past the 127 OL ceiling (it would otherwise over-brighten already-saturated notes).
            let biasedOL = min(99, outputLevel + Int(egBiasOL))
            let base = min(127, scaleOutputLevel(outputLevel) + klsOffset)
            let boosted = min(127, scaleOutputLevel(biasedOL) + klsOffset)
            levelIn = levelIn &+ (Int32((boosted - base) << 5) << 16)
        }

        if amsDepth > 0 && lfoAmpMod > 0 {
            let amod = Int32((Int64(lfoAmpMod) * Int64(amsDepth)) >> 24)
            levelIn = levelIn &- amod
        }
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
