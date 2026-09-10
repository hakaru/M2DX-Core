import Testing
import Darwin
@testable import M2DXCore

/// Poly must be bit-exact regardless of what the Mono machinery did before (#116, #118).
/// Differential on purpose: a stored output hash would depend on the host libm (the tables are
/// built at runtime from sin/cos/exp2/pow), so both sides render in-process and compare `==`.
@Suite("Poly is isolated from the Mono machinery (#116, #118)")
struct PolyIsolationTests {
    final class Rig {
        let e = SynthEngine()
        var out: [Float] = []
        init(engine: FMEngine) throws {
            e.setSampleRate(48000)
            let p = try #require(DX7FactoryPresets.all.first { $0.name == "BRASS" })
            e.loadDX7Preset(p)
            e.setFMEngine(engine)
        }
        func render(_ n: Int) {
            var l = [Float](repeating: 0, count: max(1, n)), r = l
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: n)
            }}
            out += l.prefix(n)
        }
        func on(_ n: UInt8, _ v: UInt32 = 0x6000) { e.sendMIDI(.init(kind: .noteOn, data1: n, data2: v)) }
        func off(_ n: UInt8) { e.sendMIDI(.init(kind: .noteOff, data1: n, data2: 0)) }
        func cc(_ c: UInt8, _ v: UInt32) { e.sendMIDI(.init(kind: .controlChange, data1: c, data2: v)) }
    }

    /// The same render calls on both engines; only `mono` sends the Mono excursion's events.
    /// The excursion exercises transfer attacks, legato, a pedal-held handover, a mode-switch fade
    /// with a note sounding, requestAllNotesOff and a controller reset, and ends idle.
    private func excursion(_ g: Rig, mono: Bool) {
        if mono { g.e.setMonoPerformance(enabled: true, portamentoMode: .fullTime, glissando: true) }
        g.render(0)
        if mono { g.on(60) }; g.render(1024)
        if mono { g.off(60) }; g.render(512)
        if mono { g.on(62) }; g.render(512)          // attack during the tail
        if mono { g.on(67) }; g.render(512)          // legato
        if mono { g.cc(64, .max); g.off(67); g.off(62) }; g.render(256)
        if mono { g.on(65) }; g.render(256)          // attack over the pedal-held voice
        if mono { g.cc(64, 0) }; g.render(256)
        if mono { g.e.setMonoPerformance(enabled: false, portamentoMode: .fullTime, glissando: true) }
        g.render(128)                                 // the switch fades the held note out
        if mono { g.off(65); g.e.requestAllNotesOff(); g.e.resetControllers() }
        g.render(256)
    }

    private func polyScript(_ g: Rig) {
        g.on(48); g.on(55); g.on(60); g.on(64, 0x7F00); g.render(1536)
        g.cc(64, .max); g.off(48); g.off(55); g.render(512)
        g.on(55); g.render(512)                      // re-strike under the pedal
        g.cc(120, 0); g.render(256)                  // Poly All Sound Off stays a no-op
        g.cc(64, 0); g.render(1024)
        for k in 0..<3 { g.on(72, UInt32(0x3000 + k * 0x2000)); g.render(300); g.off(72); g.render(200) }
        g.e.resetControllers(); g.render(512)
        g.cc(123, 0); g.render(2048)
    }

    @Test("Poly renders identically after a Mono excursion", arguments: [FMEngine.modern, .markI])
    func polyAfterMonoExcursion(engine: FMEngine) throws {
        let plain = try Rig(engine: engine)
        let visited = try Rig(engine: engine)
        excursion(plain, mono: false)
        excursion(visited, mono: true)
        #expect(visited.e.debugActiveVoiceCount == 0)
        #expect(visited.out.contains { $0 != 0 })
        let skip = plain.out.count
        polyScript(plain)
        polyScript(visited)
        let a = Array(plain.out[skip...]), b = Array(visited.out[skip...])
        #expect(a.contains { $0 != 0 })
        #expect(a == b)
    }

    /// A Mark I Mono attack relocates the replaced voice and fades it for one block. When that
    /// copy's release ends before the fade does, the reap must still leave the slot as a finished
    /// fade would (silent Mark I ramp anchors, no fade left), or a later Poly note on that slot
    /// ramps from a stale level (#116).
    @Test("Poly is unchanged after a Mark I fade copy's tail ends mid-fade")
    func fadeCopyReapedMidFade() throws {
        func rig() throws -> SynthEngine {
            let e = SynthEngine()
            e.setSampleRate(48000)
            e.loadDX7Preset(try #require(DX7FactoryPresets.all.first { $0.name == "E.PIANO 1" }))
            e.setFMEngine(.markI)
            return e
        }
        func render(_ e: SynthEngine, _ n: Int) -> [Float] {
            var l = [Float](repeating: 0, count: max(1, n)), r = l
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: n)
            }}
            return Array(l.prefix(n))
        }
        func on(_ e: SynthEngine, _ n: UInt8) { e.sendMIDI(.init(kind: .noteOn, data1: n, data2: 0x6000)) }
        func off(_ e: SynthEngine, _ n: UInt8) { e.sendMIDI(.init(kind: .noteOff, data1: n, data2: 0)) }
        func mono(_ e: SynthEngine, _ on: Bool) {
            e.setMonoPerformance(enabled: on, portamentoMode: .fingered, glissando: false)
        }

        // One-frame renders after the note-off, so the release tail can be timed exactly: find
        // how many it takes for the tail to end, then attack a few frames before that.
        let probe = try rig()
        mono(probe, true); _ = render(probe, 0)
        on(probe, 60); for _ in 0..<16 { _ = render(probe, 256) }
        off(probe, 60)
        var tailFrames = 0
        while probe.monoVoiceForTesting.active, tailFrames < 100_000 { _ = render(probe, 1); tailFrames += 1 }
        try #require(tailFrames > 8 && tailFrames < 100_000)

        let plain = try rig(), visited = try rig()
        mono(visited, true)
        _ = render(plain, 0); _ = render(visited, 0)
        on(visited, 60)
        for _ in 0..<16 { _ = render(plain, 256); _ = render(visited, 256) }
        off(visited, 60)
        for _ in 0..<(tailFrames - 5) { _ = render(plain, 1); _ = render(visited, 1) }
        on(visited, 62)
        _ = render(plain, 0); _ = render(visited, 0)
        let copy = visited.voiceForTesting(1)
        #expect(copy.active && copy.fadeSamplesRemaining == Int(kBlockSize), "the old voice moved to slot 1 and fades")
        for _ in 0..<16 { _ = render(plain, 1); _ = render(visited, 1) }
        let reaped = visited.voiceForTesting(1)
        #expect(!reaped.active, "the copy's tail ended well before its 64-sample fade")
        #expect(reaped.fadeSamplesRemaining == 0)
        let silent = UInt16(kMarkIEnvMax)
        #expect(reaped.ops.0.markIGainOut == silent && reaped.ops.1.markIGainOut == silent
                && reaped.ops.2.markIGainOut == silent && reaped.ops.3.markIGainOut == silent
                && reaped.ops.4.markIGainOut == silent && reaped.ops.5.markIGainOut == silent)

        off(visited, 62); mono(visited, false)
        for _ in 0..<400 { _ = render(plain, 256); _ = render(visited, 256) }
        #expect(visited.debugActiveVoiceCount == 0)
        var a: [Float] = [], b: [Float] = []
        for n: UInt8 in [48, 52, 55, 60, 64] { on(plain, n); on(visited, n) }
        for _ in 0..<8 { a += render(plain, 256); b += render(visited, 256) }
        #expect(a.contains { $0 != 0 })
        #expect(a == b)
    }
}
