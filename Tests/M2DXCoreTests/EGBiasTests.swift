// EGBiasTests.swift
// M2DX-Core — controller→EG bias with DX7 semantics (M2DX #163, replaces the #97 OL boost).
//
// On the DX7, EG bias acts only on operators with AMS (amplitude modulation sensitivity): a
// controller's EG-bias range holds those operators down by range/99 at the controller's minimum
// and releases them to their programmed level at its maximum. Range 0 means EG bias off. The
// #97 implementation raised the output level of all six operators instead, so a fast breath
// rise brightened modulators too and gave wind sounds a sharp attack (M2DX #163).

import Foundation
import Testing
@testable import M2DXCore

@Suite("EG Bias follows the DX7 (M2DX #163)", .serialized)
struct EGBiasTests {
    /// One sounding carrier (OP1, algorithm 32) with the given AMS. Breath EG bias range `range`.
    private func make(engine fm: FMEngine, ams: UInt8, range: UInt8, aftertouchRange: UInt8 = 0) -> SynthEngine {
        let engine = SynthEngine()
        engine.setFMEngine(fm)
        engine.setMasterVolume(0.5)
        engine.setAlgorithm(31)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: i == 0 ? 99 : 0)
            engine.setOperatorRatio(i, ratio: 1)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
            engine.setOperatorAmpModSensitivity(i, value: i == 0 ? ams : 0)
        }
        engine.setBreathEGBias(range)
        engine.setAftertouchEGBias(aftertouchRange)
        _ = render(engine, blocks: 1)
        return engine
    }

    private func controller(_ engine: SynthEngine, _ cc: UInt8, _ value7: UInt32) {
        let v = value7 & 0x7F
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: cc, data2: (v << 25) | (v << 18) | (v << 11) | (v << 4) | (v >> 3)))
    }

    private func render(_ engine: SynthEngine, blocks: Int = 64) -> [Float] {
        var left = [Float](repeating: 0, count: blocks * 64), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                engine.render(into: l.baseAddress!, bufferR: r.baseAddress!, frameCount: l.count)
            }
        }
        return left
    }

    private func held(engine fm: FMEngine, ams: UInt8, range: UInt8, breath: UInt32, aftertouchRange: UInt8 = 0) -> [Float] {
        let engine = make(engine: fm, ams: ams, range: range, aftertouchRange: aftertouchRange)
        controller(engine, 2, breath)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        _ = render(engine, blocks: 16)
        return render(engine, blocks: 64)
    }

    /// RMS (dB) of the held note after the breath value settles.
    private func level(engine fm: FMEngine, ams: UInt8, range: UInt8, breath: UInt32, aftertouchRange: UInt8 = 0) -> Float {
        let x = held(engine: fm, ams: ams, range: range, breath: breath, aftertouchRange: aftertouchRange)
        let mean = x.reduce(0) { $0 + $1 * $1 } / Float(x.count)
        return 10 * log10(mean + 1e-20)
    }

    @Test("range 0 is EG bias off: output is bit-identical at any breath value", arguments: [FMEngine.modern, .markI])
    func rangeZeroIsOff(engine: FMEngine) {
        #expect(held(engine: engine, ams: 3, range: 0, breath: 0) == held(engine: engine, ams: 3, range: 0, breath: 127))
    }

    @Test("operators without AMS are not affected", arguments: [FMEngine.modern, .markI])
    func amsZeroUnaffected(engine: FMEngine) {
        #expect(held(engine: engine, ams: 0, range: 99, breath: 0) == held(engine: engine, ams: 0, range: 0, breath: 0))
    }

    @Test("full breath releases the operator to its programmed level", arguments: [FMEngine.modern, .markI])
    func fullBreathIsProgrammedLevel(engine: FMEngine) {
        #expect(held(engine: engine, ams: 3, range: 99, breath: 127) == held(engine: engine, ams: 3, range: 0, breath: 0))
    }

    @Test("no breath holds an AMS 3 operator down; the range sets how far", arguments: [FMEngine.modern, .markI])
    func rangeSetsDepth(engine: FMEngine) {
        let open = level(engine: engine, ams: 3, range: 0, breath: 0)
        let r13 = level(engine: engine, ams: 3, range: 13, breath: 0)
        let r50 = level(engine: engine, ams: 3, range: 50, breath: 0)
        let r99 = level(engine: engine, ams: 3, range: 99, breath: 0)
        #expect(open - r13 > 3 && open - r13 < 20, "range 13 is a moderate hold-down (got \(open - r13) dB)")
        #expect(r13 > r50 && r50 > r99, "a larger range holds the operator further down")
        #expect(open - r99 > 50, "range 99 with AMS 3 nearly silences the operator at rest (got \(open - r99) dB)")
    }

    @Test("breath opens the operator gradually", arguments: [FMEngine.modern, .markI])
    func breathIsMonotonic(engine: FMEngine) {
        let b0 = level(engine: engine, ams: 3, range: 99, breath: 0)
        let b64 = level(engine: engine, ams: 3, range: 99, breath: 64)
        let b127 = level(engine: engine, ams: 3, range: 99, breath: 127)
        #expect(b0 < b64 && b64 < b127)
    }

    @Test("AMS weights the depth: AMS 1 is held down less than AMS 3", arguments: [FMEngine.modern, .markI])
    func amsWeighting(engine: FMEngine) {
        let open = level(engine: engine, ams: 1, range: 0, breath: 0)
        let ams1 = level(engine: engine, ams: 1, range: 99, breath: 0)
        let ams3 = level(engine: engine, ams: 3, range: 99, breath: 0)
        #expect(open - ams1 > 1, "AMS 1 must still respond")
        #expect(ams1 > ams3, "AMS 1 is held down less than AMS 3")
    }

    @Test("EG-bias shares from several controllers add", arguments: [FMEngine.modern, .markI])
    func controllerSharesAdd(engine: FMEngine) {
        let open = level(engine: engine, ams: 3, range: 0, breath: 0)
        // Breath fully open, aftertouch at rest with range 13: aftertouch still holds its share down.
        let breathOpenATRest = level(engine: engine, ams: 3, range: 99, breath: 127, aftertouchRange: 13)
        let atOnly = level(engine: engine, ams: 3, range: 0, breath: 0, aftertouchRange: 13)
        #expect(abs(breathOpenATRest - atOnly) < 0.01, "the open breath adds nothing; aftertouch keeps its share")
        #expect(open - atOnly > 3)
        // Both at rest: a small aftertouch range cannot open a breath patch (review of M2DX #163).
        let bothRest = level(engine: engine, ams: 3, range: 99, breath: 0, aftertouchRange: 13)
        let breathRest = level(engine: engine, ams: 3, range: 99, breath: 0)
        #expect(bothRest <= breathRest + 0.01, "both at rest stay held down at least as far as breath alone")
    }

    @Test("EG bias and LFO AMD share the AMS path: the deeper one applies", arguments: [FMEngine.modern, .markI])
    func combinesWithLFOAmd(engine: FMEngine) {
        // A held-down operator (breath at rest, range 99) is not opened by an LFO AMD setting.
        let e = make(engine: engine, ams: 3, range: 99)
        e.setLFOAMD(50)
        controller(e, 2, 0)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        _ = render(e, blocks: 16)
        let x = render(e, blocks: 64)
        let withAMD = 10 * log10(x.reduce(0) { $0 + $1 * $1 } / Float(x.count) + 1e-20)
        let without = level(engine: engine, ams: 3, range: 99, breath: 0)
        #expect(withAMD <= without + 0.5, "LFO AMD must not lift an operator that EG bias holds down")
    }
}
