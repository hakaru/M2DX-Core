// EGBiasTests.swift
// M2DX-Core — controller→EG-bias destination (#97). The fields/setters existed but the
// value was never read in synthesis, so breath/AT/wheel/foot → EG bias did nothing.

import Testing
@testable import M2DXCore

@Suite("EG Bias (#97)")
struct EGBiasTests {

    /// levelIn of an op held at sustain after one updateGain block, for a given EG-bias OL boost.
    private func sustainLevelIn(egBiasOL: Int32) -> Int32 {
        var op = DX7Operator()
        op.env.setRates(99, 99, 99, 99)
        op.env.setLevels(99, 99, 70, 0)
        op.setOutputLevel(40)          // base OL 40
        op.env.noteOn()
        for _ in 0..<10 { _ = op.env.getsample() }   // settle into the held sustain
        op.updateGain(lfoAmpMod: 0, egBiasOL: egBiasOL)
        return op.levelIn
    }

    @Test("EG bias raises the operator level by the exact scaleOutputLevel delta")
    func egBiasRaisesLevel() {
        let base = sustainLevelIn(egBiasOL: 0)
        let biased = sustainLevelIn(egBiasOL: 50)   // +50 OL → base 40 → 90
        #expect(biased > base, "EG bias must raise the operator level (was inert before #97)")
        // The boost is exactly the OL-domain difference routed through the real scaleOutputLevel.
        let expected = Int32((scaleOutputLevel(90) - scaleOutputLevel(40)) << 5) << 16
        #expect(biased - base == expected,
                "EG bias +50 OL = scaleOutputLevel(90)−(40) delta: got \(biased - base), expected \(expected)")
    }

    @Test("EG bias of 0 is a no-op")
    func egBiasZeroNoOp() {
        var a = DX7Operator(); a.env.setLevels(99, 99, 70, 0); a.setOutputLevel(50); a.env.noteOn()
        var b = DX7Operator(); b.env.setLevels(99, 99, 70, 0); b.setOutputLevel(50); b.env.noteOn()
        for _ in 0..<5 { _ = a.env.getsample(); _ = b.env.getsample() }
        a.updateGain(lfoAmpMod: 0, egBiasOL: 0)
        b.updateGain(lfoAmpMod: 0)   // default egBiasOL = 0
        #expect(a.levelIn == b.levelIn, "egBiasOL 0 must be byte-identical to no bias")
    }
}
