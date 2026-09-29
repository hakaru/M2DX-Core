import Testing
@testable import M2DXCore

@Suite("Host sample-rate publication (M2DX #119)")
struct SampleRatePublicationTests {
    private func render(_ engine: SynthEngine) -> SynthParamSnapshot {
        var left = [Float](repeating: 0, count: 64), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                engine.render(into: l.baseAddress!, bufferR: r.baseAddress!, frameCount: 64)
            }
        }
        return engine.debugCurrentSnapshot
    }

    // A sample-rate request must not mutate the editor's shadow/batch or wait
    // for endBatch: a host may render as soon as allocation has returned.
    @Test("host allocation takes effect during an editor batch and survives its later snapshot",
          arguments: [Float(44100), 48000, 96000])
    func hostRateDuringEditorBatch(rate: Float) async {
        let engine = SynthEngine()
        engine.setSampleRate(32000)
        #expect(render(engine).sampleRate == 32000)
        engine.beginBatch()
        engine.setAlgorithm(19)
        await Task.detached { engine.setSampleRate(rate) }.value
        let duringBatch = render(engine)
        #expect(duringBatch.sampleRate == rate)
        #expect(duringBatch.algorithm == 0, "The host request must not publish half an editor batch")
        engine.endBatch()
        let afterBatch = render(engine)
        #expect(afterBatch.sampleRate == rate)
        #expect(afterBatch.algorithm == 19)
        engine.setMasterVolume(0.25)
        #expect(render(engine).sampleRate == rate, "Later UI snapshots must not revert the host rate")
    }

    @Test("sample-rate validation remains finite and bounded",
          arguments: [(Float.nan, Float(44100)), (.infinity, 44100), (0, 44100),
                      (-1, 44100), (1, 8000), (384000, 192000)])
    func validation(input: Float, expected: Float) {
        let engine = SynthEngine()
        engine.setSampleRate(input)
        #expect(render(engine).sampleRate == expected)
    }

    @Test("rate-only changes update the sounding voice at every oversampling mode",
          arguments: [FMEngine.modern, .markI], [OversamplingMode.off, .highQuality, .lowCPU])
    func soundingPitch(fmEngine: FMEngine, oversampling: OversamplingMode) throws {
        let engine = SynthEngine()
        engine.setFMEngine(fmEngine)
        engine.setOversamplingMode(oversampling)
        engine.setSampleRate(48000)
        engine.setAlgorithm(31)
        for op in 0..<6 {
            engine.setOperatorDX7OutputLevel(op, level: op == 0 ? 80 : 0)
            engine.setOperatorRatio(op, ratio: 1)
            engine.setOperatorDX7EGRates(op, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(op, l1: 99, l2: 99, l3: 99, l4: 0)
        }
        _ = render(engine) // Engine/oversampling switches retire old voices before note-on.
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 69, data2: UInt32(100) << 9))
        _ = render(engine)
        for rate: Float in [44100, 96000, 48000] {
            engine.setSampleRate(rate) // No parameter publication to trigger applyParams.
            _ = render(engine)        // Settle rate/downsampler transition before measuring.
            var left = [Float](repeating: 0, count: 8192), right = left
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    for offset in stride(from: 0, to: l.count, by: 64) {
                        engine.render(into: l.baseAddress! + offset, bufferR: r.baseAddress! + offset, frameCount: 64)
                    }
                }
            }
            var crossings: [Float] = []
            for i in 1024..<left.count where left[i - 1] < 0 && left[i] >= 0 {
                crossings.append(Float(i - 1) - left[i - 1] / (left[i] - left[i - 1]))
            }
            #expect(crossings.count > 20, "A sustained carrier must remain audible")
            let first = try #require(crossings.first), last = try #require(crossings.last)
            let hz = Float(crossings.count - 1) * rate / (last - first)
            #expect(abs(hz - 440) < 1, "Rate \(rate), mode \(oversampling): sounding pitch \(hz) Hz")
        }
    }

    @Test("host, editor, and render publications can overlap")
    func concurrentPublications() async {
        let engine = SynthEngine()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<256 {
                    engine.setSampleRate(i % 2 == 0 ? 48000 : 96000)
                    await Task.yield()
                }
            }
            group.addTask {
                for i in 0..<256 {
                    engine.beginBatch()
                    engine.setAlgorithm(i % 32)
                    await Task.yield()
                    engine.setMasterVolume(0.25)
                    engine.endBatch()
                }
            }
            group.addTask {
                for _ in 0..<256 {
                    _ = render(engine)
                    await Task.yield()
                }
            }
        }
        let final = render(engine)
        #expect(final.sampleRate == 96000)
        #expect(final.algorithm == 31)
        #expect(final.masterVolume == 0.25)
    }
}
