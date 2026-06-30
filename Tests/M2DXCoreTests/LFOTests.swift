// LFOTests.swift
// M2DX-Core — LFO speed→Hz calibration against the DX7 documented range

import Testing
import Darwin
@testable import M2DXCore

@Suite("LFO")
struct LFOTests {

    @Test("LFO speed→Hz matches the DEXED lfoSource table — slow vibrato reachable (#94)")
    func lfoSpeedRange() {
        // Verbatim DEXED lfoSource[] (asb2m10/dexed lfo.cc). The headline #94 fix is the slow
        // end: speed 0 is ~0.0625 Hz, not the old pragmatic-exponential 1.47 Hz floor.
        #expect(abs(SynthEngine.lfoSpeedToHz(0) - 0.062541) < 0.001, "speed 0 → ~0.0625 Hz (slow sweep)")
        #expect(abs(SynthEngine.lfoSpeedToHz(35) - 5.617346) < 0.01, "default speed 35 → ~5.6 Hz")
        #expect(abs(SynthEngine.lfoSpeedToHz(99) - 49.261084) < 0.01, "speed 99 → ~49.3 Hz")
    }

    @Test("LFO speed→Hz is monotonically increasing")
    func lfoSpeedMonotonic() {
        var prev = SynthEngine.lfoSpeedToHz(0)
        for s: UInt8 in 1...99 {
            let f = SynthEngine.lfoSpeedToHz(s)
            #expect(f > prev, "speed \(s) must be faster than \(s - 1)")
            prev = f
        }
    }
}
