import Testing
import Darwin
@testable import M2DXCore

/// #116: Mono handovers must not click. Each case renders in 256-frame host buffers, fires the
/// event at a buffer boundary `b`, and compares the largest sample-to-sample step in the 64
/// samples from `b` with the largest step of the same tone in the 256 samples before it. The
/// window matters: under 2x oversampling the downsampler moves a cut a few samples past `b`.
/// A hard cut (the old behavior) measured 6–56× on these patches; Mono now measures up to 1.73×
/// and Poly's natural overlap up to 1.31× on the same sequences.
/// Long-release patches are used on purpose: on short releases the tail is already silent.
@Suite("Mono boundary continuity (#116)")
struct MonoBoundaryTests {
    static let limit: Float = 2.0
    static let hold = 14400, gap = 2400, after = 4800   // 300 ms, 50 ms, 100 ms at 48 kHz

    final class Tape {
        let e = SynthEngine()
        var out: [Float] = []
        init(preset: String, engine: FMEngine, mono: Bool) throws {
            e.setSampleRate(48000)
            let p = try #require(DX7FactoryPresets.all.first { $0.name == preset })
            e.loadDX7Preset(p)
            e.setFMEngine(engine)
            if mono { e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false) }
            render(0)
        }
        func render(_ n: Int) {
            if n == 0 {
                var l: [Float] = [0], r: [Float] = [0]
                l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                    e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: 0)
                }}
                return
            }
            var left = n
            while left > 0 {
                let c = min(256, left)
                var l = [Float](repeating: 0, count: c), r = l
                l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                    e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: c)
                }}
                out += l
                left -= c
            }
        }
        var mark: Int { out.count }
        func on(_ n: UInt8) { e.sendMIDI(.init(kind: .noteOn, data1: n, data2: 0x6000)) }
        func off(_ n: UInt8) { e.sendMIDI(.init(kind: .noteOff, data1: n, data2: 0)) }
        func pedal(_ down: Bool) {
            e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: down ? .max : 0))
        }

        /// Largest step in the 64 samples from `b`, relative to the tone's own largest step in
        /// the 256 samples before `b`.
        func ratio(at b: Int, minimumPre: Float = 1e-4) -> Float {
            var step: Float = 0
            for i in b..<(b + 64) { step = max(step, abs(out[i] - out[i - 1])) }
            var pre: Float = 0
            for i in (b - 256)..<b { pre = max(pre, abs(out[i] - out[i - 1])) }
            #expect(pre > minimumPre, "the tone before the boundary must be audible for the ratio to mean anything")
            return step / pre
        }
    }

    static let engines: [FMEngine] = [.modern, .markI]
    static let presets = ["STRINGS", "PAD WARM"]

    @Test("(a) A new attack during a release tail does not cut the tail", arguments: engines, presets)
    func attackDuringReleaseTail(engine: FMEngine, preset: String) throws {
        for next: UInt8 in [62, 60] {   // new pitch, and the same key struck again
            let t = try Tape(preset: preset, engine: engine, mono: true)
            t.on(60); t.render(Self.hold); t.off(60); t.render(Self.gap)
            let b = t.mark
            t.on(next); t.render(Self.after)
            #expect(t.ratio(at: b) <= Self.limit, "next=\(next)")
            #expect(t.e.debugActiveVoiceCount == 1)
        }
    }

    @Test("(b) A new attack over a pedal-held note does not cut it", arguments: engines, presets)
    func attackOverPedalHeldNote(engine: FMEngine, preset: String) throws {
        let t = try Tape(preset: preset, engine: engine, mono: true)
        t.pedal(true); t.on(60); t.render(Self.hold); t.off(60); t.render(Self.gap)
        #expect(t.e.monoVoiceForTesting.sustained)
        let b = t.mark
        t.on(62); t.render(Self.after)
        #expect(t.ratio(at: b) <= Self.limit)
        #expect(t.e.debugActiveVoiceCount == 1)
        #expect(t.e.monoVoiceForTesting.midiNote == 62)
    }

    @Test("(c) Legato into a split gap releases the note, and returning does not click",
          arguments: engines, presets)
    func legatoIntoSplitGap(engine: FMEngine, preset: String) throws {
        let t = try Tape(preset: preset, engine: engine, mono: false)
        t.e.setTimbreMode(.split, splitPoint: 60)
        t.e.setSlotEnabled(1, enabled: false)
        t.e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        t.render(0)
        t.on(48); t.render(Self.hold)
        let into = t.mark
        t.on(72); t.render(Self.after)                 // the upper zone is disabled: a gap
        #expect(t.ratio(at: into) <= Self.limit)
        #expect(t.e.monoVoiceForTesting.releasing)
        let back = t.mark
        t.off(72); t.render(Self.after)                // fall back to the held 48
        #expect(t.ratio(at: back) <= Self.limit)
        #expect(t.e.monoVoiceForTesting.midiNote == 48)
        #expect(!t.e.monoVoiceForTesting.releasing)
        #expect(t.e.debugActiveVoiceCount == 1)
    }

    @Test("(c2) An attack into a split gap lets the old tail ring, or releases a pedal-held note",
          arguments: engines, presets)
    func attackIntoSplitGap(engine: FMEngine, preset: String) throws {
        for pedal in [false, true] {
            let t = try Tape(preset: preset, engine: engine, mono: false)
            t.e.setTimbreMode(.split, splitPoint: 60)
            t.e.setSlotEnabled(1, enabled: false)
            t.e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
            t.render(0)
            if pedal { t.pedal(true) }
            t.on(48); t.render(Self.hold); t.off(48); t.render(Self.gap)
            #expect(t.e.monoVoiceForTesting.sustained == pedal)
            let b = t.mark
            t.on(72); t.render(Self.after)                 // the upper zone is disabled: a gap
            #expect(t.ratio(at: b) <= Self.limit, "pedal=\(pedal)")
            #expect(t.e.monoVoiceForTesting.releasing, "pedal=\(pedal)")
            #expect(t.e.monoVoiceForTesting.midiNote == 48)
            #expect(t.e.debugActiveVoiceCount == 1)
        }
    }

    @Test("A new attack in the other split part fades the old part's tail", arguments: engines)
    func attackAcrossSplitParts(engine: FMEngine) throws {
        let t = try Tape(preset: "STRINGS", engine: engine, mono: false)
        t.e.setTimbreMode(.split, splitPoint: 60)
        let brass = try #require(DX7FactoryPresets.all.first { $0.name == "BRASS" })
        t.e.loadDX7Preset(brass, slotIdx: 1)
        t.e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        t.render(0)
        t.on(55); t.render(Self.hold); t.off(55); t.render(Self.gap)
        let b = t.mark
        t.on(72); t.render(Self.after)
        #expect(t.ratio(at: b) <= Self.limit)
        #expect(t.e.monoVoiceForTesting.slotId == 1)
        #expect(t.e.debugActiveVoiceCount == 1)       // the faded copy is gone after one block
    }

    /// Full-level staccato: the note-off and the next note-on arrive in the same buffer, so the
    /// old note is still at its sustain level when the new one attacks. Low notes are the hardest
    /// case for a one-block (64-sample) handover, because the ramp is steep next to a 65 Hz
    /// tone's own slope. The limit is the larger of `staccatoLimit` and 1.5× what Poly measures
    /// on the same sequence: patches with a sharp attack step that much in Poly too, from the new
    /// note's own attack. Measured at C2, Mono / Poly: TROMBONE 4.63× / 0.35× (Modern) and
    /// 3.53× / 0.57× (Mark I); SUB BASS 13.8× / 13.9× and 47.6× / 45.0×; SYN BASS 5.35× / 9.73×
    /// and 35.5× / 33.8×; BRASS 2.63× / 1.00× and 1.66× / 0.79×. The hard cut (447e17a)
    /// measured 287× / 210× on TROMBONE and 370× / 243× on SUB BASS.
    static let staccatoLimit: Float = 6.0

    @Test("Full-level staccato on low bass and brass notes stays close to Poly",
          arguments: engines, ["TROMBONE", "BRASS", "SUB BASS", "SYN BASS"])
    func fullLevelStaccato(engine: FMEngine, preset: String) throws {
        for (first, next) in [(UInt8(36), UInt8(38)), (36, 36)] {
            func take(mono: Bool) throws -> Float {
                let t = try Tape(preset: preset, engine: engine, mono: mono)
                t.on(first); t.render(Self.hold)
                let b = t.mark
                t.off(first); t.on(next); t.render(Self.after)   // one buffer: off, then on
                return t.ratio(at: b, minimumPre: 1e-5)          // quiet C2 tones: ~-50 dBFS
            }
            let mono = try take(mono: true), poly = try take(mono: false)
            #expect(mono <= max(Self.staccatoLimit, 1.5 * poly), "\(first)→\(next): mono \(mono)×, poly \(poly)×")
        }
    }

    @Test("(d) Poly→Mono with a chord and Mono→Poly with a held note fade instead of cutting",
          arguments: engines, presets)
    func modeSwitch(engine: FMEngine, preset: String) throws {
        let chord = try Tape(preset: preset, engine: engine, mono: false)
        chord.on(60); chord.on(64); chord.on(67); chord.render(Self.hold)
        let b1 = chord.mark
        chord.e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        chord.render(Self.after)
        #expect(chord.ratio(at: b1) <= Self.limit)
        #expect(chord.e.debugActiveVoiceCount == 0)

        let held = try Tape(preset: preset, engine: engine, mono: true)
        held.on(60); held.render(Self.hold)
        let b2 = held.mark
        held.e.setMonoPerformance(enabled: false, portamentoMode: .fingered, glissando: false)
        held.render(Self.after)
        #expect(held.ratio(at: b2) <= Self.limit)
        #expect(held.e.debugActiveVoiceCount == 0)
    }

    @Test("Oversampled Mark I with the vintage DAC: fades complete, free their slots and do not click")
    func oversampledMarkIVintageDAC() throws {
        // The fade runs at the render rate (2x here, so 64 samples ≈ 0.67 ms), through the DAC
        // companding branch, and relocation allocates from the halved oversampled voice budget.
        let t = try Tape(preset: "STRINGS", engine: .markI, mono: false)
        t.e.setVintageDAC(true)
        t.e.setOversamplingMode(.highQuality)
        t.render(4096)                                 // let the oversampling transition settle
        t.on(60); t.on(64); t.on(67); t.render(Self.hold)
        let chord = t.mark
        t.e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        t.render(Self.after)
        #expect(t.ratio(at: chord) <= Self.limit)
        #expect(t.e.debugActiveVoiceCount == 0)
        t.off(60); t.off(64); t.off(67)               // keys were forgotten at the switch: no-ops
        t.on(60); t.render(Self.hold); t.off(60); t.render(Self.gap)
        let attack = t.mark
        t.on(62); t.render(Self.after)                 // Mark I: relocate + fade, oversampled
        #expect(t.ratio(at: attack) <= Self.limit)
        #expect(t.e.debugActiveVoiceCount == 1)
        #expect(t.e.monoVoiceForTesting.midiNote == 62)
    }

    @Test("The sustain pedal survives a mode switch")
    func pedalSurvivesModeSwitch() throws {
        let t = try Tape(preset: "STRINGS", engine: .modern, mono: true)
        t.pedal(true); t.render(0)
        t.e.setMonoPerformance(enabled: false, portamentoMode: .fingered, glissando: false)
        t.render(256)
        t.on(60); t.render(256); t.off(60); t.render(256)
        #expect(t.e.debugActiveVoiceCount == 1)     // still sustained by the held pedal
        t.pedal(false); t.render(256)
        #expect(t.e.debugActiveVoiceCount == 1)     // now releasing (long STRINGS tail)
        t.render(48000 * 4)
        #expect(t.e.debugActiveVoiceCount == 0)
    }
}
