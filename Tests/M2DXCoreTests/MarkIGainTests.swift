// MarkIGainTests.swift
import Testing
@testable import M2DXCore

@Suite("Mark I attenuation")
struct MarkIGainTests {
    @Test("high level → low attenuation; low level → high attenuation")
    func direction() {
        let loud = markIAtten(17 << 24)
        let quiet = markIAtten(0)
        #expect(loud < quiet)
        #expect(quiet == UInt16(kMarkIEnvMax))
    }
    @Test("never returns 0 (zero maps to ENV_MAX-1)")
    func zeroGuard() {
        let a = markIAtten(Int32(kMarkIEnvMax) << 14)
        #expect(a == UInt16(kMarkIEnvMax - 1))
    }
    @Test("clamps within [0, ENV_MAX]")
    func clamp() {
        #expect(markIAtten(Int32.max) <= UInt16(kMarkIEnvMax))
        #expect(markIAtten(Int32.min) <= UInt16(kMarkIEnvMax))
    }
}
