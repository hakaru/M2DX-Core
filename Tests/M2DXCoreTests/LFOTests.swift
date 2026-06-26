// LFOTests.swift
// M2DX-Core — LFO speed→Hz calibration against the DX7 documented range

import Testing
import Darwin
@testable import M2DXCore

@Suite("LFO")
struct LFOTests {

    @Test("LFO speed maps to the DX7 frequency range (0.0625 Hz … ~47 Hz)")
    func lfoSpeedRange() {
        #expect(abs(SynthEngine.lfoSpeedToHz(0) - 0.0625) < 0.0005, "speed 0 → 0.0625 Hz")
        #expect(abs(SynthEngine.lfoSpeedToHz(99) - 47.0) < 0.5, "speed 99 → ~47 Hz")
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
