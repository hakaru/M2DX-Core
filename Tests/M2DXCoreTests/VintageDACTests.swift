// VintageDACTests.swift — DX7 12-bit DAC companding (#75)
import Testing
import Foundation
@testable import M2DXCore

@Suite struct VintageDACTests {
    @Test("zero maps to zero; odd symmetry")
    func zeroAndSymmetry() {
        #expect(dac12bitCompand(0) == 0)
        #expect(dac12bitCompand(-0.7) == -dac12bitCompand(0.7))
    }

    @Test("output stays within [-1, 1] across the input range")
    func bounded() {
        for i in -100...100 {
            let s = Float(i) / 100.0
            let y = dac12bitCompand(s)
            #expect(y >= -1.0 && y <= 1.0)
        }
    }

    @Test("large signals quantize at the coarse 12-bit step (exp 1)")
    func largeSignalIs12bit() {
        // |s| > 0.5 → exp 1 → step 1/2048
        #expect(abs(dac12bitCompand(0.7) - 0.7) <= 1.0 / 2048.0)
    }

    @Test("companding preserves a sub-12-bit small signal (finer step than plain 12-bit)")
    func smallSignalCompanded() {
        // 1/4096 is below the plain 12-bit grid (round(0.5)/2048 would lose it),
        // but at exp 8 the effective step is 1/(2048*8)=1/16384, so it survives.
        let small: Float = 1.0 / 4096.0
        let y = dac12bitCompand(small)
        #expect(y != 0)                          // not collapsed to zero
        #expect(abs(y - small) <= 1.0 / 16384.0) // preserved within the fine (exp-8) step
    }
}
