// MarkICalibrationCharacterizationTests.swift
// M2DX-Core — INVESTIGATION harness for audit markI-ops-dac finding 1 (carrier output level).
// Renders ONE pure carrier (alg 32, op0 only — no modulation) at a sweep of output levels for
// Modern vs Mark I and prints the raw-peak gain curve + Mark I/Modern ratio. This decides whether
// finding 1 is a constant 4× offset (constant-shift fixable) or a level-dependent curve divergence.
// Not a pass/fail behavior test. Env-gated (mutates the process-global markIModScaleQ12).
// Run: `M2DX_MARKI_CHAR=1 swift test --filter renderCarrierGainCurve`

import Testing
import Foundation
@testable import M2DXCore

@Suite("Mark I carrier gain-curve characterization (investigation — prints a curve)")
struct MarkICalibrationCharacterizationTests {

    private let sampleRate: Float = 48000
    private let total = 12000          // 0.25 s at 48 kHz — enough for a steady carrier

    /// Render a single pure carrier (alg 32, op0 only) at `carrierLevel` and return the
    /// steady-state raw peak (max |sample| over the post-attack window).
    private func carrierPeak(engine: FMEngine, divisor: Double?, carrierLevel: Float) -> Float {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(engine)
        if let d = divisor { synth.setMarkIModDivisor(d) }

        synth.loadDX7Preset(DX7FactoryPresets.all[0])
        synth.setAlgorithm(32)                                   // all ops parallel carriers (no modulation)
        for op in 0..<6 { synth.setOperatorLevel(op, level: op == 0 ? carrierLevel : 0.0) }
        synth.setOperatorEGLevels(0, l1: 1, l2: 1, l3: 1, l4: 1) // flat sustain = the carrier's full level
        synth.setOperatorEGRates(0, r1: 99, r2: 99, r3: 99, r4: 99) // instant attack/decay -> steady

        let blk = 512
        var pL = [Float](repeating: 0, count: blk), pR = [Float](repeating: 0, count: blk)
        pL.withUnsafeMutableBufferPointer { lp in pR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))

        var outL = [Float](repeating: 0, count: total)
        var outR = [Float](repeating: 0, count: total)
        outL.withUnsafeMutableBufferPointer { op in outR.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        // Steady-state window: skip the first 2400 samples (50 ms) of attack settling.
        var peak: Float = 0
        for i in 2400..<total { peak = max(peak, abs(outL[i])) }
        return peak
    }

    @Test("Render Modern vs Mark I carrier gain curve")
    func renderCarrierGainCurve() {
        guard ProcessInfo.processInfo.environment["M2DX_MARKI_CHAR"] != nil else {
            print("MarkICalibrationCharacterizationTests skipped — set M2DX_MARKI_CHAR=1 to render the curve")
            return
        }
        defer { SynthEngine().setMarkIModDivisor(8.0) }          // restore process-global default

        let levels: [Float] = [0.1, 0.2, 0.35, 0.5, 0.7, 0.85, 1.0]
        print("level, modernPeak, markIDiv5Peak, ratio(markI/modern)")
        var modernPeaks: [Float] = [], markIPeaks: [Float] = []
        for lv in levels {
            let m = carrierPeak(engine: .modern, divisor: nil, carrierLevel: lv)
            let k = carrierPeak(engine: .markI, divisor: 5.0, carrierLevel: lv)
            modernPeaks.append(m); markIPeaks.append(k)
            let ratio = m > 0 ? k / m : 0
            print(String(format: "%.2f, %.5f, %.5f, %.3f", lv, m, k, ratio))
            // Sanity only — peaks are finite and within the [-1,1] sample range.
            #expect(m.isFinite && k.isFinite)
            #expect(m <= 1.0 && k <= 1.0)
        }
        // Sanity: peak is monotonic non-decreasing in carrier level for both engines.
        for i in 1..<levels.count {
            #expect(modernPeaks[i] >= modernPeaks[i - 1] - 1e-4)
            #expect(markIPeaks[i] >= markIPeaks[i - 1] - 1e-4)
        }
    }
}
