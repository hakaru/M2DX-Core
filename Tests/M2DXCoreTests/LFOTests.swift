// LFOTests.swift
// M2DX-Core — LFO speed→Hz calibration against the DX7 documented range

import Testing
import Darwin
@testable import M2DXCore

@Suite("LFO")
struct LFOTests {

    @Test("LFO speed maps to a usable vibrato range (~5 Hz at default 35, ~47 Hz at 99)")
    func lfoSpeedRange() {
        #expect(abs(SynthEngine.lfoSpeedToHz(35) - 5.0) < 0.5, "default speed 35 → ~5 Hz (usable vibrato)")
        #expect(abs(SynthEngine.lfoSpeedToHz(99) - 47.0) < 1.0, "speed 99 → ~47 Hz")
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
