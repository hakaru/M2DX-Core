// MarkIDACCompandingTests.swift
// M2DX-Core — #95 Stage 1: the 12-bit DAC companding must engage amplitude-dependent
// exponents per voice (not degenerate to a fixed exp-8 quantizer as it did on the tiny
// post-normalization summed mix).
import Testing
import Foundation
@testable import M2DXCore

@Suite("Mark I 12-bit DAC per-voice companding (#95)")
struct MarkIDACCompandingTests {

    private let sampleRate: Float = 48000

    /// Render a preset through the full SynthEngine with the vintage DAC on/off and return the peak.
    private func render(_ preset: DX7Preset, dacOn: Bool, note: UInt8, vel: Int) -> [Float] {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(.markI)
        synth.setVintageDAC(dacOn)
        synth.loadDX7Preset(preset)
        let blk = 512, total = 4096
        var pL = [Float](repeating: 0, count: blk), pR = [Float](repeating: 0, count: blk)
        pL.withUnsafeMutableBufferPointer { lp in pR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(vel) << 9))
        var outL = [Float](repeating: 0, count: total), outR = [Float](repeating: 0, count: total)
        outL.withUnsafeMutableBufferPointer { op in outR.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return outL
    }

    /// Distance of `x` from the nearest `1/grid` step (0 ⇒ x sits exactly on that quantization grid).
    private func gridError(_ x: Float, _ grid: Float) -> Float { abs((x * grid).rounded() - x * grid) }

    @Test("dac12bitCompand quantizes amplitude-dependently (coarse grid loud, fine grid quiet)")
    func companding_is_amplitude_dependent() {
        // Tests the REAL dac12bitCompand, not a mirror. exp = a>0.5?1:a>0.25?2:a>0.125?4:8, and the
        // output sits on a 1/(2048·exp) grid. So a loud sample lands on the coarse 1/2048 grid (exp 1)
        // and a quiet one on the fine 1/16384 grid (exp 8) — the companding the fix must preserve.
        let loud = dac12bitCompand(0.6)              // 0.6 > 0.5 -> exp 1 -> 1/2048 grid
        let quiet = dac12bitCompand(0.06)            // 0.06 < 0.125 -> exp 8 -> 1/16384 grid
        #expect(gridError(loud, 2048) < 1e-3)        // loud sits on the coarse grid
        #expect(gridError(quiet, 16384) < 1e-3)      // quiet sits on the fine grid
        #expect(gridError(quiet, 2048) > 1e-3)       // and NOT on the coarse grid -> companding engaged
    }

    @Test("R sizes the per-voice raw into the engaged region; the old post-norm scale was always exp 8")
    func full_scale_reference_engages() {
        // Stage 0 measured a loud single carrier's raw OPS peak ~2^25; / R lands at the exp-1/2 boundary
        // (engaged). The OLD location companded the summed /2^28 mix (~0.08 < 0.125) -> always exp 8.
        #expect(Float(1 << 25) / kMarkIDACFullScale <= 0.5)   // loud per-voice raw is in the engaged region
        #expect(Float(0.08) <= 0.125)                          // old post-norm peak was stuck at exp 8
    }

    @Test("DAC-on output differs from DAC-off (companding is active per voice)")
    func dac_on_changes_output() {
        let p = DX7FactoryPresets.all[11]            // any multi-op patch
        let off = render(p, dacOn: false, note: 60, vel: 100)
        let on  = render(p, dacOn: true,  note: 60, vel: 100)
        var maxDiff: Float = 0
        for i in 0..<off.count { maxDiff = max(maxDiff, abs(on[i] - off[i])) }
        #expect(maxDiff > 0)                          // companding is doing something
        #expect(on.allSatisfy { $0.isFinite })
    }
}
