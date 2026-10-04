// EGBiasBoostModeTests.swift
// M2DX-Core — EGBiasMode.boost keeps the Core 1.23.0 (#97) EG-bias behaviour selectable (M2DX #168).

import Foundation
import Testing
@testable import M2DXCore

@Suite("EG Bias boost mode (M2DX #168)", .serialized)
struct EGBiasBoostModeTests {
    // MARK: Operator level — the #97 OL boost, unchanged

    private func sustainLevelIn(egBiasOL: Int32, outputLevel: Int = 40, kls: Int = 0) -> Int32 {
        var op = DX7Operator()
        op.env.setRates(99, 99, 99, 99)
        op.env.setLevels(99, 99, 70, 0)
        op.klsOffset = kls
        op.setOutputLevel(outputLevel)
        op.env.noteOn()
        for _ in 0..<10 { _ = op.env.getsample() }
        op.updateGain(lfoAmpMod: 0, egBiasOL: egBiasOL)
        return op.levelIn
    }

    @Test("boost raises an operator by the exact scaleOutputLevel delta")
    func boostRaisesLevel() {
        let expected = Int32((scaleOutputLevel(90) - scaleOutputLevel(40)) << 5) << 16
        #expect(sustainLevelIn(egBiasOL: 50) - sustainLevelIn(egBiasOL: 0) == expected)
    }

    @Test("boost respects the 127 OL ceiling")
    func boostRespectsCeiling() {
        #expect(sustainLevelIn(egBiasOL: 50, kls: 100) == sustainLevelIn(egBiasOL: 0, kls: 100))
    }

    // MARK: Engine

    /// Algorithm 32 with OP1 sounding (AMS `ams`); breath EG-bias range `range`.
    private func make(_ fm: FMEngine, mode: EGBiasMode?, ams: UInt8, range: UInt8) -> SynthEngine {
        let e = SynthEngine()
        e.setFMEngine(fm)
        e.setMasterVolume(0.5)
        e.setAlgorithm(31)
        for i in 0..<6 {
            e.setOperatorDX7OutputLevel(i, level: i == 0 ? 60 : 0)
            e.setOperatorRatio(i, ratio: 1)
            e.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            e.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
            e.setOperatorAmpModSensitivity(i, value: i == 0 ? ams : 0)
        }
        e.setBreathEGBias(range)
        if let mode { e.setEGBiasMode(mode) }
        _ = render(e, blocks: 1)
        return e
    }

    private func render(_ e: SynthEngine, blocks: Int) -> [Float] {
        var l = [Float](repeating: 0, count: blocks * 64), r = l
        l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
            e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: lp.count) } }
        return l
    }

    private func held(_ fm: FMEngine, mode: EGBiasMode?, ams: UInt8 = 0, range: UInt8, breath: UInt32) -> [Float] {
        let e = make(fm, mode: mode, ams: ams, range: range)
        let v = breath & 0x7F
        e.sendMIDI(MIDIEvent(kind: .controlChange, data1: 2, data2: (v << 25) | (v << 18) | (v << 11) | (v << 4) | (v >> 3)))
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        _ = render(e, blocks: 16)
        return render(e, blocks: 64)
    }

    private func db(_ x: [Float]) -> Float { 10 * log10(x.reduce(0) { $0 + $1 * $1 } / Float(x.count) + 1e-20) }

    @Test("DX7 is the default mode", arguments: [FMEngine.modern, .markI])
    func dx7IsDefault(fm: FMEngine) {
        #expect(held(fm, mode: nil, ams: 3, range: 99, breath: 40) == held(fm, mode: .dx7, ams: 3, range: 99, breath: 40))
    }

    @Test("boost: breath raises an operator without AMS; DX7 leaves it alone", arguments: [FMEngine.modern, .markI])
    func boostIgnoresAMS(fm: FMEngine) {
        let rest = held(fm, mode: .boost, range: 30, breath: 0)
        let full = held(fm, mode: .boost, range: 30, breath: 127)
        #expect(rest == held(fm, mode: .dx7, range: 0, breath: 0), "boost at rest adds nothing")
        #expect(db(full) - db(rest) > 3, "boost +30 OL at full breath (got \(db(full) - db(rest)) dB)")
        #expect(held(fm, mode: .dx7, range: 30, breath: 127) == rest, "DX7 mode ignores an AMS 0 operator")
    }

    @Test("boost grows with breath and range", arguments: [FMEngine.modern, .markI])
    func boostScales(fm: FMEngine) {
        let b64 = db(held(fm, mode: .boost, range: 30, breath: 64))
        let b127 = db(held(fm, mode: .boost, range: 30, breath: 127))
        let r15 = db(held(fm, mode: .boost, range: 15, breath: 127))
        #expect(b64 < b127)
        #expect(r15 < b127)
    }

    @Test("switching back to DX7 restores the DX7 result", arguments: [FMEngine.modern, .markI])
    func switchBack(fm: FMEngine) {
        let e = make(fm, mode: .boost, ams: 3, range: 99)
        e.setEGBiasMode(.dx7)
        _ = render(e, blocks: 1)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        _ = render(e, blocks: 16)
        let x = render(e, blocks: 64)
        #expect(x == held(fm, mode: .dx7, ams: 3, range: 99, breath: 0))
    }
}
