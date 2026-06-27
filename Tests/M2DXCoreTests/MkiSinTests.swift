// MkiSinTests.swift
import Testing
@testable import M2DXCore

@Suite("mkiSin")
struct MkiSinTests {
    @Test("quadrant 1 positive, quadrant 3 negative")
    func signByQuadrant() {
        let q1 = mkiSin(1 << 21, 0)
        let q3 = mkiSin((1 << 23) + (1 << 21), 0)
        #expect(q1 > 0); #expect(q3 < 0)
    }
    @Test("near-peak at zero attenuation, near-silent at max attenuation")
    func amplitudeByAttenuation() {
        let loud = abs(mkiSin(1 << 22, 0))
        let quiet = abs(mkiSin(1 << 22, UInt16(16384 - 1)))
        #expect(loud > quiet * 8)
    }
    @Test("does not trap at extreme phase / attenuation")
    func noTrap() {
        _ = mkiSin(Int32.min, 0); _ = mkiSin(Int32.max, UInt16(16383))
        _ = mkiSin(-1, 16000); #expect(Bool(true))
    }
}
