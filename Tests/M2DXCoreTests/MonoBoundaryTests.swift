import Testing
import Darwin
@testable import M2DXCore

/// #116: Mono handovers must not click. Each case renders in 256-frame host buffers, fires the
/// event at a buffer boundary `b`, and compares the largest sample-to-sample step in the
/// `window` samples from `b` (the whole fade-out plus one block) with the largest step of the
/// same tone before it. The window matters: a shorter one sees only the start of the fade, and
/// under 2x oversampling the downsampler moves a cut a few samples past `b`.
/// A hard cut (the old behavior) measured 6–56× on these patches; Mono now measures up to
/// 1.2× and Poly's natural overlap up to 1.5× on the same sequences (48 kHz).
/// Long-release patches are used on purpose: on short releases the tail is already silent.
@Suite("Mono boundary continuity (#116)")
struct MonoBoundaryTests {
    static let limit: Float = 2.0
    static let hold = 14400, gap = 2400, after = 4800   // 300 ms, 50 ms, 100 ms at 48 kHz
    /// Host frames that cover the whole fade plus one block. The fade keeps its duration in host
    /// time at every render rate, 512 host frames up to 48 kHz, so the host rate alone sets this.
    static func fadeWindow(hostRate: Float) -> Int {
        SynthEngine.voiceFadeSamples(renderRate: hostRate) + 64
    }
    static let window = fadeWindow(hostRate: 48000)

    final class Tape {
        let e = SynthEngine()
        let hostRate: Float
        var out: [Float] = []
        init(preset: String, engine: FMEngine, mono: Bool, sampleRate: Float = 48000) throws {
            hostRate = sampleRate
            e.setSampleRate(sampleRate)
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

        /// Largest step in the `window` samples from `b`, relative to the tone's own largest step
        /// in the `preWindow` samples before `b`.
        func ratio(at b: Int, preWindow: Int = 256, minimumPre: Float = 1e-4) -> Float {
            var step: Float = 0
            for i in b..<(b + MonoBoundaryTests.fadeWindow(hostRate: hostRate)) {
                step = max(step, abs(out[i] - out[i - 1]))
            }
            var pre: Float = 0
            for i in (b - preWindow)..<b { pre = max(pre, abs(out[i] - out[i - 1])) }
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
        #expect(t.e.debugActiveVoiceCount == 1)       // the faded copy is gone after its fade
    }

    /// Full-level staccato: the note-off and the next note-on arrive in the same buffer, so the
    /// old note is still at its sustain level when the new one attacks. Low notes are the hardest
    /// case, because a 65 Hz tone's own slope is small next to any handover ramp; this case sets
    /// the fade length. The tone's slope is taken over more than one C2 period (1024 samples at
    /// 48 kHz, 2048 at 96 kHz). Oversampling and a 96 kHz host both raise the render rate, which
    /// shortened the old fixed 512-sample fade in host time, so both are checked (96 kHz for the
    /// smooth-sustain brass patches, whose own slope is small enough to show a short fade).
    /// The limit is relative to what Poly measures on the same sequence, with a floor of
    /// `staccatoFloor` (a step barely above the tone's own slope is no click); sharp-attack bass
    /// patches step as much in Poly, from the new note's own attack.
    /// Measured at C2, Mono / Poly, 48 kHz (2x oversampled): TROMBONE 1.38/1.97 (1.37/1.96) on
    /// Modern, 1.90/1.71 (1.54/1.64) on Mark I; BRASS 0.50/0.97 and 0.53–0.58/0.91–1.01; FAT BASS,
    /// SUB BASS and SYN BASS 2.9–34, within 1.1× of Poly. At 96 kHz (2x oversampled) TROMBONE
    /// measures 1.61/1.74 (1.67/1.81) on Modern and 1.49/1.40 (1.72/1.54) on Mark I. The worst
    /// case is 1.11× Poly. With the fade fixed at 512 render samples, 96 kHz 2x oversampled
    /// TROMBONE measured 2.89/1.81 on Modern and 2.30/1.54 on Mark I.
    /// A one-block fade measured up to 3.5× (8.1× oversampled) on TROMBONE, a one-block signal
    /// transfer 4.6× (9.3×), and the hard cut of 447e17a 287× on TROMBONE and 370× on SUB BASS.
    static let staccatoFloor: Float = 1.2
    static let staccatoPolyFactor: Float = 1.3

    @Test("Full-level staccato on low bass and brass notes stays close to Poly",
          arguments: engines, ["TROMBONE", "BRASS", "SUB BASS", "SYN BASS", "FAT BASS"])
    func fullLevelStaccato(engine: FMEngine, preset: String) throws {
        let rates: [Float] = ["TROMBONE", "BRASS"].contains(preset) ? [48000, 96000] : [48000]
        for rate in rates {
            for oversampling in [OversamplingMode.off, .highQuality] {
                for (first, next) in [(UInt8(36), UInt8(38)), (36, 36)] {
                    func take(mono: Bool) throws -> Float {
                        let t = try Tape(preset: preset, engine: engine, mono: mono, sampleRate: rate)
                        if oversampling != .off {
                            t.e.setOversamplingMode(oversampling)
                            t.render(4096)                             // let the transition settle
                        }
                        t.on(first); t.render(Self.hold)
                        let b = t.mark
                        t.off(first); t.on(next); t.render(Self.after) // one buffer: off, then on
                        return t.ratio(at: b, preWindow: Int(1024 * rate / 48000),
                                       minimumPre: 1e-5)               // quiet C2: ~-50 dBFS
                    }
                    let mono = try take(mono: true), poly = try take(mono: false)
                    #expect(mono <= max(Self.staccatoFloor, Self.staccatoPolyFactor * poly),
                            "\(rate) Hz \(oversampling) \(first)→\(next): mono \(mono)×, poly \(poly)×")
                }
            }
        }
    }

    @Test("The fade keeps its duration in host time at every sample rate and oversampling mode",
          arguments: [(Float(44100), OversamplingMode.off, 512), (48000, .off, 512),
                      (48000, .highQuality, 1024), (96000, .off, 1024), (96000, .highQuality, 2048)])
    func fadeLengthFollowsRenderRate(rate: Float, oversampling: OversamplingMode, renderSamples: Int) throws {
        let factor = oversampling == .off ? 1 : 2
        #expect(SynthEngine.voiceFadeSamples(renderRate: rate * Float(factor)) == renderSamples)
        let t = try Tape(preset: "STRINGS", engine: .markI, mono: true, sampleRate: rate)
        if oversampling != .off { t.e.setOversamplingMode(oversampling); t.render(4096) }
        t.on(60); t.render(Self.hold); t.off(60); t.render(Self.gap)
        t.on(62); t.render(0)
        var fading: [Int] = []
        for i in 0..<16 where t.e.voiceForTesting(i).active && t.e.voiceForTesting(i).fadeSamplesRemaining > 0 {
            fading.append(i)
        }
        try #require(fading.count == 1, "the replaced note moved to one fading slot")
        #expect(t.e.voiceForTesting(fading[0]).fadeSamplesRemaining == renderSamples)
        let hostFrames = renderSamples / factor
        t.render(hostFrames - 1)
        #expect(t.e.debugActiveVoiceCount == 2, "still fading one host frame before the end")
        t.render(1)
        #expect(t.e.debugActiveVoiceCount == 1, "freed once the whole fade has been rendered")
        #expect(t.e.liveVoiceCountForTesting == 1)
    }

    @Test("A full voice pool falls back to cutting voice 0, and the allocator keeps working",
          arguments: engines, [OversamplingMode.off, .highQuality])
    func fullPoolFallback(engine: FMEngine, oversampling: OversamplingMode) throws {
        // Every slot is still fading when the Mono attack arrives: the replaced note has nowhere
        // to fade, so voice 0 is cut. The next attack must relocate again as usual.
        let t = try Tape(preset: "STRINGS", engine: engine, mono: false)
        if oversampling != .off { t.e.setOversamplingMode(oversampling); t.render(4096) }
        let pool = oversampling == .off ? 16 : 8
        // One note more than the pool, so the Poly steal pointer has moved past voice 0: an attack
        // that fell through to a Poly steal instead of the fallback would not land in voice 0.
        for k in 0...pool { t.on(UInt8(48 + k)) }
        t.render(Self.hold)
        #expect(t.e.debugActiveVoiceCount == pool, "the Poly chord fills the pool")
        t.e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        t.on(72); t.render(0)                         // the switch fades all; the attack follows
        #expect(t.e.debugActiveVoiceCount == pool, "pool - 1 fading copies plus the new note")
        #expect(t.e.liveVoiceCountForTesting == 1)
        #expect(t.e.monoVoiceForTesting.midiNote == 72)
        #expect(t.e.monoVoiceForTesting.active && !t.e.monoVoiceForTesting.releasing)
        #expect(t.e.monoVoiceForTesting.fadeSamplesRemaining == 0)
        t.render(Self.after)
        #expect(t.e.debugActiveVoiceCount == 1, "every fading copy freed its slot")
        #expect(t.e.monoVoiceForTesting.midiNote == 72)
        t.off(72); t.on(74); t.render(0)              // staccato: relocate + fade as usual
        #expect(t.e.debugActiveVoiceCount == 2)
        #expect(t.e.liveVoiceCountForTesting == 1)
        #expect(t.e.monoVoiceForTesting.midiNote == 74)
        t.render(Self.after)
        #expect(t.e.debugActiveVoiceCount == 1)
    }

    @Test("A note-off and the pedal still reach a fading copy, but cannot stop or lengthen its fade",
          arguments: engines)
    func noteOffReachesFadingCopy(engine: FMEngine) throws {
        let t = try Tape(preset: "STRINGS", engine: engine, mono: true)
        t.pedal(true); t.on(60); t.render(Self.hold); t.off(60); t.render(Self.gap)
        t.on(60); t.render(0)                         // restrike: the pedal-held 60 moves out to fade
        var fading: [Int] = []
        for i in 1..<16 where t.e.voiceForTesting(i).active && t.e.voiceForTesting(i).fadeSamplesRemaining > 0 {
            fading.append(i)
        }
        try #require(fading.count == 1)
        let j = fading[0]
        #expect(!t.e.voiceForTesting(j).sustained && t.e.voiceForTesting(j).midiNote == 60)
        t.off(60); t.render(0)                        // matches the copy by midiNote as well
        #expect(t.e.voiceForTesting(j).sustained, "the note-off reaches the copy while the pedal is down")
        #expect(t.e.voiceForTesting(j).fadeSamplesRemaining == SynthEngine.voiceFadeSamples)
        #expect(t.e.monoVoiceForTesting.sustained)
        t.pedal(false); t.render(0)
        #expect(t.e.voiceForTesting(j).releasing)
        #expect(t.e.voiceForTesting(j).fadeSamplesRemaining == SynthEngine.voiceFadeSamples)
        t.render(SynthEngine.voiceFadeSamples - 1)
        #expect(t.e.voiceForTesting(j).active && t.e.voiceForTesting(j).fadeSamplesRemaining == 1)
        t.render(1)                                   // the fade still ends on time
        #expect(!t.e.voiceForTesting(j).active && !t.e.voiceForTesting(j).sustained)
        // Only the new note can be left (released at once, its short tail may already be over).
        #expect(t.e.liveVoiceCountForTesting == t.e.debugActiveVoiceCount)
        #expect(t.e.debugActiveVoiceCount <= 1)
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
        // The fade runs at the render rate (2x here, so 1024 samples = 10.7 ms), through the DAC
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
        // The only voice is held by the pedal, not releasing. STRINGS' long tail would count as
        // active either way, so the count alone cannot tell a held note from a released one.
        #expect(t.e.debugActiveVoiceCount == 1)
        #expect(t.e.monoVoiceForTesting.sustained)
        #expect(!t.e.monoVoiceForTesting.releasing)
        t.pedal(false); t.render(256)
        #expect(t.e.debugActiveVoiceCount == 1)
        #expect(t.e.monoVoiceForTesting.releasing)  // the pedal-up releases it
        t.render(48000 * 4)
        #expect(t.e.debugActiveVoiceCount == 0)
    }
}
