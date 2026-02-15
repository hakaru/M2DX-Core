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
    var outputLevel: Int = 99
    var phase: Int32 = 0          // Q24 phase accumulator
    var freq: Int32 = 0           // Q24 per-sample phase increment
    var gainOut: Int32 = 0        // Previous block's gain (for interpolation)
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
        frequency = baseFreq * ratio * detune
        updateFreq()
        env.noteOn()
        phase = 0; fbBuf = (0, 0)
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
    mutating func updateGain(lfoAmpMod: Int32) {
        let egLevel = env.getsample()
        levelIn = egLevel

        if amsDepth > 0 && lfoAmpMod > 0 {
            let amod = Int32((Int64(lfoAmpMod) * Int64(amsDepth)) >> 24)
            levelIn = levelIn &- amod
        }
    }

    mutating func updateFreqPublic() { updateFreq() }

    private mutating func updateFreq() {
        let inc = Double(frequency) / Double(sampleRate) * Double(1 << 24)
        freq = Int32(clamping: Int(inc))
    }
}
