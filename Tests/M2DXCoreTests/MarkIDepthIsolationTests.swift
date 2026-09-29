import Testing
@testable import M2DXCore

@Suite("Mark I depth belongs to each engine (M2DX #119)", .serialized)
struct MarkIDepthIsolationTests {
    private func make(_ divisor: Double, algorithm: Int) -> SynthEngine {
        let engine = SynthEngine()
        engine.setFMEngine(.markI)
        engine.setMarkIModDivisor(divisor)
        engine.setMasterVolume(0.2)
        engine.setAlgorithm(algorithm)
        engine.setOperatorFeedback(7)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 85)
            engine.setOperatorRatio(i, ratio: Float(i + 1))
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
        }
        _ = render(engine, blocks: 1)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        return engine
    }

    private func render(_ engine: SynthEngine, blocks: Int = 32) -> [Float] {
        var left = [Float](repeating: 0, count: blocks * 64), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                engine.render(into: l.baseAddress!, bufferR: r.baseAddress!, frameCount: l.count)
            }
        }
        return left
    }

    @Test("another instance cannot change the sounding depth, including fused kernels",
          arguments: [0, 3, 5])
    func independentEngines(algorithm: Int) {
        let expected = render(make(2, algorithm: algorithm))
        let first = make(2, algorithm: algorithm)
        let other = make(16, algorithm: algorithm)
        #expect(first.debugMarkIModScaleQ12 == 2048)
        #expect(other.debugMarkIModScaleQ12 == 256)
        let unchanged = render(first) == expected
        #expect(unchanged, "Creating/editing another AU must not change this voice")
        let different = render(other)
        #expect(zip(different, expected).contains { abs($0 - $1) > 1e-5 }, "Depth must still affect audio")
    }

    @Test("depth edits wait for their editor batch, like the other voice parameters")
    func batchPublication() {
        let control = make(2, algorithm: 0), edited = make(2, algorithm: 0)
        #expect(render(edited) == render(control))
        let expectedDuringBatch = render(control)
        edited.beginBatch()
        edited.setMarkIModDivisor(16)
        let duringBatch = render(edited) == expectedDuringBatch
        #expect(duringBatch, "An open batch must not leak a depth edit")
        edited.endBatch()
        let changed = render(edited) != render(control)
        #expect(changed, "The completed batch must reach the sounding voice")
    }
}
