// TableTests.swift
// M2DX-Core — Tests for SinTable, Exp2Table, FrequencyTable, ScalingTable

import Testing
import Darwin
@testable import M2DXCore

@Suite("Sin Table Tests")
struct SinTableTests {

    @Test("sinLookupQ24 at key phase points")
    func sinAtKeyPoints() {
        let q24 = Int32(1 << 24)

        // sin(0) ≈ 0
        let s0 = sinLookupQ24(0)
        #expect(abs(s0) < 512, "sin(0) should be near zero, got \(s0)")

        // sin(π/2) = phase 1/4 of full cycle ≈ 2^24
        let sQuarter = sinLookupQ24(q24 / 4)
        let expected = Int32(1 << 24)
        #expect(abs(Int(sQuarter) - Int(expected)) < 1024, "sin(π/2) should be near 2^24, got \(sQuarter)")

        // sin(π) ≈ 0
        let sHalf = sinLookupQ24(q24 / 2)
        #expect(abs(sHalf) < 1024, "sin(π) should be near zero, got \(sHalf)")

        // sin(3π/2) ≈ -2^24
        let s3Quarter = sinLookupQ24(q24 * 3 / 4)
        #expect(abs(Int(s3Quarter) + Int(expected)) < 1024, "sin(3π/2) should be near -2^24, got \(s3Quarter)")
    }

    @Test("sinLookupQ24 precision over full cycle")
    func sinPrecisionFullCycle() {
        // Check 256 uniformly spaced points
        var maxError: Double = 0
        for i in 0..<256 {
            let phase = Int32(i * (1 << 24) / 256)
            let actual = Double(sinLookupQ24(phase))
            let expected = Darwin.sin(Double(i) / 256.0 * 2.0 * .pi) * Double(1 << 24)
            let error = abs(actual - expected)
            maxError = max(maxError, error)
        }
        // Linear interpolation on 1024 entries should be within ~256 Q24 units
        #expect(maxError < 512, "Max sin error \(maxError) exceeds tolerance")
    }

    @Test("sinLookupQ24 wraps around correctly")
    func sinWraparound() {
        // Phase wraps at 2^24, so adding full cycles should give same result
        let phase: Int32 = 1234567
        let s1 = sinLookupQ24(phase)
        let s2 = sinLookupQ24(phase &+ Int32(1 << 24))
        #expect(abs(Int(s1) - Int(s2)) < 64, "Phase wrapping should preserve value")
    }
}

@Suite("Exp2 Table Tests")
struct Exp2TableTests {

    @Test("exp2LookupQ24 at identity point")
    func exp2AtIdentity() {
        // x=0 → 2^0 = 1.0 in Q24 = 2^24
        let result = exp2LookupQ24(0)
        let expected = Int32(1 << 24)
        let error = abs(Int(result) - Int(expected))
        #expect(error < 256, "exp2(0) should be 2^24, got \(result) (error \(error))")
    }

    @Test("exp2LookupQ24 doubling")
    func exp2Doubling() {
        // x = 1<<24 → 2^1 = 2.0 in Q24 = 2^25
        let result = exp2LookupQ24(Int32(1 << 24))
        let expected = Int32(1 << 25)
        let error = abs(Int(result) - Int(expected))
        #expect(error < 512, "exp2(1.0) should be 2^25, got \(result) (error \(error))")
    }

    @Test("exp2LookupQ24 halving")
    func exp2Halving() {
        // x = -(1<<24) → 2^(-1) = 0.5 in Q24 = 2^23
        let result = exp2LookupQ24(Int32(-1 * (1 << 24)))
        let expected = Int32(1 << 23)
        let error = abs(Int(result) - Int(expected))
        #expect(error < 256, "exp2(-1.0) should be 2^23, got \(result) (error \(error))")
    }

    @Test("exp2LookupQ24 large negative → near zero")
    func exp2LargeNegative() {
        // Very large negative should approach 0
        let result = exp2LookupQ24(Int32(-20 * (1 << 24)))
        #expect(result >= 0, "exp2 should never be negative")
        #expect(result < 64, "exp2(-20) should be near zero, got \(result)")
    }

    @Test("exp2LookupQ24 monotonic")
    func exp2Monotonic() {
        var prev = exp2LookupQ24(Int32(-10 * (1 << 24)))
        for i in -9...5 {
            let val = exp2LookupQ24(Int32(i * (1 << 24)))
            #expect(val >= prev, "exp2 should be monotonically increasing: i=\(i), prev=\(prev), val=\(val)")
            prev = val
        }
    }
}

@Suite("Frequency Table Tests")
struct FrequencyTableTests {

    @Test("MIDI note 69 = 440 Hz (A4)")
    func midiA4() {
        let freq = kMIDIFreqLUT[69]
        #expect(abs(freq - 440.0) < 0.01, "MIDI note 69 should be 440 Hz, got \(freq)")
    }

    @Test("MIDI note 60 = middle C ≈ 261.63 Hz")
    func midiMiddleC() {
        let freq = kMIDIFreqLUT[60]
        #expect(abs(freq - 261.63) < 0.1, "MIDI note 60 should be ~261.63 Hz, got \(freq)")
    }

    @Test("MIDI note 0 ≈ 8.18 Hz")
    func midiNote0() {
        let freq = kMIDIFreqLUT[0]
        #expect(abs(freq - 8.176) < 0.1, "MIDI note 0 should be ~8.18 Hz, got \(freq)")
    }

    @Test("Octave relationship: note n+12 = 2× note n")
    func octaveRelationship() {
        for n in stride(from: 0, to: 116, by: 12) {
            let f1 = kMIDIFreqLUT[n]
            let f2 = kMIDIFreqLUT[n + 12]
            let ratio = f2 / f1
            #expect(abs(ratio - 2.0) < 0.001, "Octave ratio at note \(n) should be 2.0, got \(ratio)")
        }
    }

    @Test("pitchBendFactor center = 1.0")
    func pitchBendCenter() {
        let factor = pitchBendFactor(0)
        #expect(abs(factor - 1.0) < 0.001, "pitchBendFactor(0) should be 1.0, got \(factor)")
    }

    @Test("pitchBendFactorExt ±12 semitones range")
    func pitchBendExtRange() {
        let up12 = pitchBendFactorExt(12.0)
        #expect(abs(up12 - 2.0) < 0.01, "+12 semitones should be 2.0, got \(up12)")

        let down12 = pitchBendFactorExt(-12.0)
        #expect(abs(down12 - 0.5) < 0.01, "-12 semitones should be 0.5, got \(down12)")
    }

    @Test("Tuning LUT center = 1.0")
    func tuningCenter() {
        let center = kTuningLUT[100]  // 0 cents
        #expect(abs(center - 1.0) < 0.0001, "0 cents tuning should be 1.0, got \(center)")
    }
}

@Suite("Scaling Table Tests")
struct ScalingTableTests {

    @Test("scaleOutputLevel range and monotonic")
    func outputLevelMonotonic() {
        var prev = scaleOutputLevel(0)
        for ol in 1...99 {
            let val = scaleOutputLevel(ol)
            #expect(val >= prev, "scaleOutputLevel should be monotonic: OL=\(ol)")
            prev = val
        }
    }

    @Test("scaleOutputLevel boundary values")
    func outputLevelBoundaries() {
        // OL=0 → 0
        #expect(scaleOutputLevel(0) == 0, "OL=0 should be 0")
        // OL=99 → 28+99=127
        #expect(scaleOutputLevel(99) == 127, "OL=99 should be 127")
        // OL=20 → 28+20=48
        #expect(scaleOutputLevel(20) == 48, "OL=20 should be 48")
    }

    @Test("scaleVelocity: sens=0 always returns 0")
    func velocitySensZero() {
        #expect(scaleVelocity(0x7FFF, sens: 0) == 0, "sens=0 should always return 0")
        #expect(scaleVelocity(0x0100, sens: 0) == 0, "sens=0 should always return 0")
    }

    @Test("scaleVelocity: higher velocity = more positive offset")
    func velocityHigherIsLouder() {
        let lowVel = scaleVelocity(0x1000, sens: 4)
        let highVel = scaleVelocity(0x7F00, sens: 4)
        #expect(highVel > lowVel, "Higher velocity should give higher offset")
    }

    @Test("feedbackShift values")
    func feedbackShiftValues() {
        #expect(feedbackShift(0) == 16, "fb=0 → disabled (16)")
        #expect(feedbackShift(1) == 7, "fb=1 → 7")
        #expect(feedbackShift(7) == 1, "fb=7 → 1")
    }

    @Test("keyboardRateScaling zero scaling")
    func krsZeroScaling() {
        #expect(keyboardRateScaling(note: 60, scaling: 0) == 0, "scaling=0 should be 0")
    }

    @Test("keyboardRateScaling increases with note")
    func krsIncreasesWithNote() {
        let low = keyboardRateScaling(note: 36, scaling: 3)
        let high = keyboardRateScaling(note: 96, scaling: 3)
        #expect(high > low, "Higher notes should have higher rate scaling")
    }

    @Test("scaleKeyboardLevel no effect at break point")
    func klsAtBreakPoint() {
        let result = scaleKeyboardLevel(60, breakPoint: 39, leftDepth: 50, rightDepth: 50,
                                        leftCurve: 0, rightCurve: 0)
        // Note 60, bp=39 → bp adjusted to 39+21=60, so diff=0
        #expect(result == 0, "At break point, KLS should be 0")
    }

    @Test("fixedFreqHz basic values")
    func fixedFreqValues() {
        // coarse=0 → 10^0=1 Hz, fine=0 → 1.0
        let f = fixedFreqHz(coarse: 0, fine: 0)
        #expect(abs(f - 1.0) < 0.01, "coarse=0 fine=0 should be 1.0 Hz")
    }
}
