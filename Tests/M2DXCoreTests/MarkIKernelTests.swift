// MarkIKernelTests.swift
import Testing
@testable import M2DXCore

@Suite("Mark I kernels")
struct MarkIKernelTests {
    @Test("computePureMkI writes a non-silent block at zero attenuation")
    func pure() {
        let out = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { out.deallocate() }
        out.initialize(repeating: 0, count: kBlockSize)
        computePureMkI(out, phase0: 0, freq: 1 << 18, atten1: 0, atten2: 0, add: false, n: kBlockSize)
        #expect((0..<kBlockSize).contains { out[$0] != 0 })
    }
    @Test("computeModMkI with silent modulator input equals computePureMkI")
    func modEqualsPureWhenInputZero() {
        let a = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let b = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let zero = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { a.deallocate(); b.deallocate(); zero.deallocate() }
        a.initialize(repeating: 0, count: kBlockSize); b.initialize(repeating: 0, count: kBlockSize)
        zero.initialize(repeating: 0, count: kBlockSize)
        computePureMkI(a, phase0: 123, freq: 1 << 18, atten1: 200, atten2: 200, add: false, n: kBlockSize)
        computeModMkI(b, UnsafePointer(zero), phase0: 123, freq: 1 << 18, atten1: 200, atten2: 200, add: false, n: kBlockSize)
        #expect((0..<kBlockSize).allSatisfy { a[$0] == b[$0] })
    }
}
