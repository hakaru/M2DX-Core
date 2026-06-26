// UnisonTests.swift
// M2DX-Core — unison detune spread + voice stacking

import Testing
import Darwin
@testable import M2DXCore

@Suite("Unison")
struct UnisonTests {

    @Test("unisonDetuneFactor: count 1 is always 1.0 (no detune)")
    func countOneIsUnity() {
        #expect(unisonDetuneFactor(index: 0, count: 1, detuneCents: 50) == 1.0)
    }

    @Test("unisonDetuneFactor: symmetric spread, extremes at ±detune cents")
    func symmetricSpread() {
        let n = 4, d: Float = 50
        let f0 = unisonDetuneFactor(index: 0, count: n, detuneCents: d)
        let f3 = unisonDetuneFactor(index: n - 1, count: n, detuneCents: d)
        #expect(abs(f0 - exp2(-d / 1200.0)) < 1e-6, "voice 0 at -50¢")
        #expect(abs(f3 - exp2(d / 1200.0)) < 1e-6, "voice n-1 at +50¢")
        #expect(abs(f0 * f3 - 1.0) < 1e-5, "outermost voices are symmetric about 1.0")
        let f1 = unisonDetuneFactor(index: 1, count: n, detuneCents: d)
        let f2 = unisonDetuneFactor(index: 2, count: n, detuneCents: d)
        #expect(f0 < f1 && f1 < f2 && f2 < f3, "monotonically increasing across voices")
    }

    @Test("unisonDetuneFactor: zero detune is unity for all voices")
    func zeroDetuneUnity() {
        for i in 0..<8 { #expect(unisonDetuneFactor(index: i, count: 8, detuneCents: 0) == 1.0) }
    }
}
