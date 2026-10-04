// _RefactorEvalDump.swift — temporary harness for refactor eval experiment.
// NOT committed. Dumps deterministic envelope output sequences to /tmp.

import Foundation
import Testing
@testable import M2DXCore

@Suite("Refactor Eval Dump")
struct RefactorEvalDump {

    /// Run a single envelope through N getsample() calls under given params.
    /// Returns the level Int32 sequence.
    static func runEnvelope(
        rates: (Int, Int, Int, Int),
        levels: (Int, Int, Int, Int),
        outlevel: Int,
        rateScaling: Int = 0,
        blocks: Int,
        noteOffAt: Int? = nil
    ) -> [Int32] {
        var env = DX7Envelope()
        env.setSampleRate(44100)
        env.setRates(rates.0, rates.1, rates.2, rates.3)
        env.setLevels(levels.0, levels.1, levels.2, levels.3)
        env.setOutputLevel(outlevel)
        env.rateScaling = rateScaling
        env.noteOn()
        var out: [Int32] = []
        out.reserveCapacity(blocks)
        for i in 0..<blocks {
            if let off = noteOffAt, i == off { env.noteOff() }
            out.append(env.getsample())
        }
        return out
    }

    /// 8 deterministic param sets covering attack-only, full ADSR,
    /// instant-attack, slow release, edge cases.
    static let cases: [(name: String, run: @Sendable () -> [Int32])] = [
        ("fast_full",        { runEnvelope(rates: (99,75,50,50),  levels: (99,80,70,0),  outlevel: 99, blocks: 200, noteOffAt: 100) }),
        ("slow_full",        { runEnvelope(rates: (30,30,30,30),  levels: (99,70,50,0),  outlevel: 99, blocks: 1500, noteOffAt: 800) }),
        ("instant_attack",   { runEnvelope(rates: (99,50,40,40),  levels: (99,80,60,0),  outlevel: 99, blocks: 300, noteOffAt: 150) }),
        ("zero_outlevel",    { runEnvelope(rates: (50,50,50,50),  levels: (99,80,70,0),  outlevel: 0,  blocks: 100, noteOffAt: 50) }),
        ("piano_long",       { runEnvelope(rates: (95,40,30,40),  levels: (99,90,80,0),  outlevel: 90, blocks: 2000, noteOffAt: 1000) }),
        ("staccato",         { runEnvelope(rates: (99,99,99,99),  levels: (99,80,60,0),  outlevel: 99, blocks: 50, noteOffAt: 5) }),
        ("scaled_rate",      { runEnvelope(rates: (50,50,50,50),  levels: (99,80,70,0),  outlevel: 80, rateScaling: 12, blocks: 500, noteOffAt: 250) }),
        ("flat_levels",      { runEnvelope(rates: (60,60,60,60),  levels: (99,99,99,0),  outlevel: 99, blocks: 800, noteOffAt: 400) }),
    ]

    @Test("Dump envelope baseline to /tmp/refactor-eval/dump.bin")
    func dump() throws {
        let dir = "/tmp/refactor-eval"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // Layout: for each case, write 4 bytes count (LE) + count*4 bytes Int32 LE
        var data = Data()
        for c in Self.cases {
            let samples = c.run()
            var count = UInt32(samples.count).littleEndian
            withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
            for s in samples {
                var v = s.littleEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }
        }
        let path = "\(dir)/dump.bin"
        try data.write(to: URL(fileURLWithPath: path))
        print("WROTE \(data.count) bytes to \(path)")
    }
}
