// MarkITablesTests.swift
import Testing
import Darwin
@testable import M2DXCore

@Suite("Mark I tables")
struct MarkITablesTests {
    @Test("sinLog table matches the public OPS formula")
    func sinLog() {
        for i in [0, 1, 511, 1023] {
            let expected = UInt16(( -1024.0 * (log2(sin(((0.5 + Double(i)) / 1024.0) * .pi / 2.0))) ).rounded())
            #expect(kSinLogLUT[i] == expected, "sinLog[\(i)]")
        }
    }
    @Test("sinExp table matches the public OPS formula")
    func sinExp() {
        for i in [0, 1, 512, 1023] {
            let expected = UInt16(((pow(2.0, Double(i) / 1024.0) - 1.0) * 4096.0).rounded())
            #expect(kSinExpLUT[i] == expected, "sinExp[\(i)]")
        }
    }
    @Test("prewarm touches both tables without trapping")
    func prewarm() { markIPrewarm(); #expect(kSinLogLUT.count == 1024 && kSinExpLUT.count == 1024) }
}
