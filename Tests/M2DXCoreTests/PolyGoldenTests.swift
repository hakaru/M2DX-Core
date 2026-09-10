import Testing
import Darwin
@testable import M2DXCore

/// Engine-level Poly output pinned to the pre-Mono baseline (M2DX-Core 447e17a = v1.21.0 plus
/// the verbatim Mono import; Poly there is v1.21.0's). `PolyIsolationTests` compares Poly with
/// itself, so a change that hits every Poly render equally would pass it; this suite would not.
/// The golden values are per-block RMS and per-block signed mean (512 frames, left then right)
/// that 447e17a rendered: RMS pins the level, the signed mean pins polarity and phase (an
/// inverted or shifted output keeps its RMS). Both are compared with a tolerance relative to the
/// block's golden RMS instead of bit for bit: the DSP tables are built at runtime from libm,
/// whose last bit may differ between toolchains, while a real change to the Poly path (a 0.999
/// gain slip is 1e-3; an inversion moves the mean by 2–20% of the RMS) is far outside it (#116).
@Suite("Poly golden output (#116)")
struct PolyGoldenTests {
    static let blockFrames = 512
    static let totalFrames = 8192
    static let relativeTolerance = 1e-4
    static let absoluteFloor = 1e-6          // −120 dBFS: near-silent blocks compare absolutely

    final class Rig {
        let e = SynthEngine()
        var left: [Float] = [], right: [Float] = []
        private var chunkIndex = 0
        private static let chunks = [256, 100, 37, 512, 1, 256, 300, 64]
        init(preset: String, engine: FMEngine) {
            e.setSampleRate(48000)
            if let p = DX7FactoryPresets.all.first(where: { $0.name == preset }) { e.loadDX7Preset(p) }
            e.setFMEngine(engine)
        }
        func settle() {
            var l: [Float] = [0], r: [Float] = [0]
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: 0)
            }}
        }
        /// Renders `n` frames in an irregular chunk pattern, so partial blocks are covered too.
        func render(_ n: Int) {
            var todo = n
            while todo > 0 {
                let c = min(todo, Self.chunks[chunkIndex % Self.chunks.count])
                chunkIndex += 1
                var l = [Float](repeating: 0, count: c), r = l
                l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                    e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: c)
                }}
                left += l; right += r
                todo -= c
            }
        }
        func finish() { render(PolyGoldenTests.totalFrames - left.count) }
        func on(_ n: UInt8, _ v: UInt32 = 0x6000) { e.sendMIDI(.init(kind: .noteOn, data1: n, data2: v)) }
        func off(_ n: UInt8) { e.sendMIDI(.init(kind: .noteOff, data1: n, data2: 0)) }
        func cc(_ c: UInt8, _ v: UInt32) { e.sendMIDI(.init(kind: .controlChange, data1: c, data2: v)) }
        func bend(_ v: UInt32) { e.sendMIDI(.init(kind: .pitchBend, data1: 0, data2: v)) }
    }

    /// Chord, pedal, re-strike under the pedal, CC120 (a Poly no-op), repeated notes with
    /// different velocities, a controller reset and CC123.
    static func pedalScript(_ g: Rig) {
        g.on(48); g.on(55); g.on(60); g.on(64, 0x7F00); g.render(1536)
        g.cc(64, .max); g.off(48); g.off(55); g.render(512)
        g.on(55); g.render(512)
        g.cc(120, 0); g.render(256)
        g.cc(64, 0); g.render(1024)
        for k in 0..<3 { g.on(72, UInt32(0x3000 + k * 0x2000)); g.render(300); g.off(72); g.render(200) }
        g.e.resetControllers(); g.render(512)
        g.cc(123, 0)
    }

    static func render(_ name: String) -> Rig {
        switch name {
        case "modern-brass", "markI-brass":
            let g = Rig(preset: "BRASS", engine: name == "markI-brass" ? .markI : .modern)
            g.settle(); pedalScript(g); g.finish(); return g
        case "markI-dac-2x":
            let g = Rig(preset: "E.PIANO 1", engine: .markI)
            g.e.setVintageDAC(true)
            g.e.setOversamplingMode(.highQuality)
            g.settle()
            g.on(52); g.on(59); g.on(64); g.on(71, 0x7F00); g.render(1024)
            g.cc(1, 0xA0000000); g.bend(0xB0000000); g.render(1024)
            g.off(52); g.off(64); g.render(1024)
            g.bend(0x80000000); g.on(76); g.render(1024)
            g.cc(123, 0); g.finish(); return g
        default:   // "modern-layer-portamento"
            let g = Rig(preset: "STRINGS", engine: .modern)
            g.e.setLayerPartition(parts: 2, unison: 2, detuneCents: 9)
            g.settle()
            if let brass = DX7FactoryPresets.all.first(where: { $0.name == "BRASS" }) {
                g.e.loadDX7Preset(brass, slotIdx: 1)
            }
            g.e.setPortamento(enabled: true, time: 0.3)
            g.settle()
            g.on(60); g.render(1024)
            g.on(67); g.render(1024)
            g.off(60); g.on(64); g.render(1024)
            g.cc(1, 0x80000000); g.bend(0x60000000); g.render(1024)
            g.off(64); g.off(67); g.render(1024)
            g.cc(123, 0); g.finish(); return g
        }
    }

    static func blockRMS(_ x: [Float]) -> [Double] {
        stride(from: 0, to: x.count, by: blockFrames).map { start in
            var sum = 0.0
            for i in start..<min(start + blockFrames, x.count) { sum += Double(x[i]) * Double(x[i]) }
            return (sum / Double(blockFrames)).squareRoot()
        }
    }

    static func blockMean(_ x: [Float]) -> [Double] {
        stride(from: 0, to: x.count, by: blockFrames).map { start in
            var sum = 0.0
            for i in start..<min(start + blockFrames, x.count) { sum += Double(x[i]) }
            return sum / Double(blockFrames)
        }
    }

    static func measure(_ name: String) -> (rms: [Double], mean: [Double]) {
        let g = render(name)
        return (blockRMS(g.left) + blockRMS(g.right), blockMean(g.left) + blockMean(g.right))
    }

    static let scenarios = ["modern-brass", "markI-brass", "markI-dac-2x", "modern-layer-portamento"]

    /// Rendered by 447e17a (see the suite comment). Regenerate only for an intended Poly change.
    static let golden: [String: [Double]] = [
        "modern-brass": [
            0.001137416891, 0.007042435406, 0.02670268703, 0.02123028922, 0.07202855064,
            0.1041366956, 0.05659301401, 0.08433845518, 0.07040170808, 0.06968909989, 0.05511329141,
            0.05760888231, 0.05607509522, 0.05113514579, 0.04500421344, 0.04780142133,
            0.001137416891, 0.007042435406, 0.02670268703, 0.02123028922, 0.07202855064,
            0.1041366956, 0.05659301401, 0.08433845518, 0.07040170808, 0.06968909989, 0.05511329141,
            0.05760888231, 0.05607509522, 0.05113514579, 0.04500421344, 0.04780142133,
        ],
        "markI-brass": [
            0.00105734744, 0.006995729588, 0.02643678709, 0.02059199056, 0.07092779961,
            0.1038303789, 0.05676921047, 0.08407771558, 0.07053915344, 0.07009573338, 0.05500207536,
            0.05726383602, 0.05647459071, 0.051290527, 0.04502366674, 0.04758251466, 0.00105734744,
            0.006995729588, 0.02643678709, 0.02059199056, 0.07092779961, 0.1038303789,
            0.05676921047, 0.08407771558, 0.07053915344, 0.07009573338, 0.05500207536,
            0.05726383602, 0.05647459071, 0.051290527, 0.04502366674, 0.04758251466,
        ],
        "markI-dac-2x": [
            0.02489897296, 0.07998991824, 0.05849378432, 0.05559964569, 0.04315433375,
            0.03914962407, 0.04378751043, 0.04471349745, 0.02456860488, 0.004847553503,
            0.0008826570767, 0.0002325839268, 7.005256539e-05, 3.349256518e-05, 1.441045346e-05, 0,
            0.02489897296, 0.07998991824, 0.05849378432, 0.05559964569, 0.04315433375,
            0.03914962407, 0.04378751043, 0.04471349745, 0.02456860488, 0.004847553503,
            0.0008826570767, 0.0002325839268, 7.005256539e-05, 3.349256518e-05, 1.441045346e-05, 0,
        ],
        "modern-layer-portamento": [
            0.003201962954, 0.005857007164, 0.009774441715, 0.01670281641, 0.02511695996,
            0.04077577768, 0.05595143854, 0.02793813356, 0.07198211251, 0.01987232977, 0.0291558286,
            0.02162889334, 0.01784972851, 0.01178681037, 0.01226185225, 0.01270853, 0.003201962954,
            0.005857007164, 0.009774441715, 0.01670281641, 0.02511695996, 0.04077577768,
            0.05595143854, 0.02793813356, 0.07198211251, 0.01987232977, 0.0291558286, 0.02162889334,
            0.01784972851, 0.01178681037, 0.01226185225, 0.01270853,
        ],
    ]

    /// Per-block signed mean (512 frames, left then right) from the same 447e17a renders. RMS is
    /// blind to polarity and phase (an inverted output has the same RMS); the signed mean is not.
    /// In most blocks it is 2–20% of the block RMS, far above the 1e-4 tolerance.
    static let goldenMean: [String: [Double]] = [
        "modern-brass": [
            0.0001860234869, -0.0002614557586, 0.001767613924, 0.000524146946, -0.006858089143,
            0.01130232648, 0.002348870199, -0.008076840482, 0.008900955466, -0.01377322653,
            0.01182343992, -0.00245801924, -0.002540086541, 0.004713213782, -0.005089740181,
            0.009388239202, 0.0001860234869, -0.0002614557586, 0.001767613924, 0.000524146946,
            -0.006858089143, 0.01130232648, 0.002348870199, -0.008076840482, 0.008900955466,
            -0.01377322653, 0.01182343992, -0.00245801924, -0.002540086541, 0.004713213782,
            -0.005089740181, 0.009388239202,
        ],
        "markI-brass": [
            -5.015466797e-07, -0.0004052208861, 0.001621296492, 0.0004005299829, -0.006841815732,
            0.01053527006, 0.001693607719, -0.009189588737, 0.008368024857, -0.01482291144,
            0.01069623758, -0.003705226247, -0.003773849515, 0.003789840114, -0.006142275071,
            0.008455795559, -5.015466797e-07, -0.0004052208861, 0.001621296492, 0.0004005299829,
            -0.006841815732, 0.01053527006, 0.001693607719, -0.009189588737, 0.008368024857,
            -0.01482291144, 0.01069623758, -0.003705226247, -0.003773849515, 0.003789840114,
            -0.006142275071, 0.008455795559,
        ],
        "markI-dac-2x": [
            0.004543989508, -0.0001213609947, -0.003100345768, 0.00193371727, -0.0008925709213,
            0.001553923383, -0.004771953257, 0.004082285311, -0.0003418594392, -4.55836656e-05,
            1.821351462e-05, -7.736387793e-05, -4.156134976e-05, -2.33146152e-05, -8.629533161e-06,
            0, 0.004543989508, -0.0001213609947, -0.003100345768, 0.00193371727, -0.0008925709213,
            0.001553923383, -0.004771953257, 0.004082285311, -0.0003418594392, -4.55836656e-05,
            1.821351462e-05, -7.736387793e-05, -4.156134976e-05, -2.33146152e-05, -8.629533161e-06,
            0,
        ],
        "modern-layer-portamento": [
            3.743003988e-05, 0.0006021381415, 0.0002602828508, -0.00146706852, -0.0007582368678,
            0.002024589669, -0.0003690479481, -0.002608780931, 0.0009106818156, 0.003472106688,
            0.000731499335, -0.003452068588, 0.002127030041, 0.0009370037301, -0.00150507218,
            0.0012162312, 3.743003988e-05, 0.0006021381415, 0.0002602828508, -0.00146706852,
            -0.0007582368678, 0.002024589669, -0.0003690479481, -0.002608780931, 0.0009106818156,
            0.003472106688, 0.000731499335, -0.003452068588, 0.002127030041, 0.0009370037301,
            -0.00150507218, 0.0012162312,
        ],
    ]

    @Test("Poly output matches the pre-Mono baseline", arguments: scenarios)
    func matchesBaseline(scenario: String) throws {
        let expected = try #require(Self.golden[scenario])
        let expectedMean = try #require(Self.goldenMean[scenario])
        let actual = Self.measure(scenario)
        #expect(expected.contains { $0 > 0.01 }, "the scenario must be audible")
        try #require(actual.rms.count == expected.count && actual.mean.count == expected.count)
        try #require(expectedMean.count == expected.count)
        for i in 0..<expected.count {
            let a = actual.rms[i], g = expected[i]
            let tolerance = Self.relativeTolerance * g + Self.absoluteFloor
            #expect(abs(a - g) <= tolerance, "\(scenario) block \(i): RMS \(a) vs golden \(g)")
            let am = actual.mean[i], gm = expectedMean[i]
            #expect(abs(am - gm) <= tolerance, "\(scenario) block \(i): mean \(am) vs golden \(gm)")
        }
    }
}
