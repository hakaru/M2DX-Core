// MarkIFbChainTests.swift
import Testing
@testable import M2DXCore

@Suite("Mark I multi-op feedback")
struct MarkIFbChainTests {
    @Test("fb2 produces a non-silent fused 2-op block")
    func fb2() {
        let out = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { out.deallocate() }
        out.initialize(repeating: 0, count: kBlockSize)
        var fb: (Int32, Int32) = (0, 0)
        var p = MarkIChainParams(phase: (0, 1000, 0), freq: (1 << 18, 1 << 17, 0), levelIn: (0, 0, 0))
        computeFb2MkI(out, &p, atten01: 0, atten02: 0, fbBuf: &fb, fbShift: 3)
        #expect((0..<kBlockSize).contains { out[$0] != 0 })
    }
    @Test("fb3 advances all three phases by freq*n")
    func fb3() {
        let out = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { out.deallocate() }
        out.initialize(repeating: 0, count: kBlockSize)
        var fb: (Int32, Int32) = (0, 0)
        var p = MarkIChainParams(phase: (0, 0, 0), freq: (1 << 18, 1 << 17, 1 << 16), levelIn: (0, 0, 0))
        computeFb3MkI(out, &p, atten01: 0, atten02: 0, fbBuf: &fb, fbShift: 3)
        #expect(p.phase.1 == (1 << 17) &* Int32(kBlockSize))
        #expect(p.phase.2 == (1 << 16) &* Int32(kBlockSize))
    }
}
