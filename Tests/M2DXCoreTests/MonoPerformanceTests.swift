import Testing
import Darwin
@testable import M2DXCore

@Suite("Mono performance (#115)")
struct MonoPerformanceTests {
    private func render(_ engine: SynthEngine, frames: Int = 0) {
        var l = [Float](repeating: 0, count: max(1, frames))
        var r = l
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                engine.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: frames)
            }
        }
    }

    static let engines: [FMEngine] = [.modern, .markI]

    private func engine(_ fm: FMEngine = .modern, portamento: MonoPortamentoMode = .fingered) -> SynthEngine {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        engine.setFMEngine(fm)
        engine.setMonoPerformance(enabled: true, portamentoMode: portamento, glissando: false)
        render(engine)
        return engine
    }

    /// Renders one fade length. An attack over a sounding or releasing note moves that note to
    /// another slot and fades it out there (#116); the copy counts in `debugActiveVoiceCount`
    /// until the fade has been rendered, although it is no longer a playing note.
    private func settle(_ engine: SynthEngine) {
        render(engine, frames: SynthEngine.voiceFadeSamples)
    }

    private func on(_ engine: SynthEngine, _ note: UInt8, velocity: UInt32 = 50000) {
        engine.sendMIDI(.init(kind: .noteOn, data1: note, data2: velocity))
        render(engine)
    }

    private func off(_ engine: SynthEngine, _ note: UInt8) {
        engine.sendMIDI(.init(kind: .noteOff, data1: note, data2: 0))
        render(engine)
    }

    @Test("First overlap latches HIGH, non-winning keys do not interrupt, release returns", arguments: engines)
    func highPriorityTrill(fm: FMEngine) {
        let e = engine(fm)
        on(e, 60); on(e, 72); on(e, 55)
        #expect(e.monoVoiceForTesting.midiNote == 72)
        #expect(e.debugActiveVoiceCount == 1)
        off(e, 72)
        #expect(e.monoVoiceForTesting.midiNote == 60)
        on(e, 67); off(e, 67)
        #expect(e.monoVoiceForTesting.midiNote == 60)
        off(e, 60)
        #expect(e.monoVoiceForTesting.midiNote == 55)
        off(e, 55)
        #expect(e.monoVoiceForTesting.releasing)
    }

    private enum Key: CustomStringConvertible {
        case on(UInt8), off(UInt8)
        var description: String {
            switch self { case .on(let n): return "\(n) on"; case .off(let n): return "\(n) off" }
        }
    }

    /// Plays `steps` one event at a time and checks the sounding note after every event:
    /// a note number means that note sounds (voice 0, not releasing); nil means silence.
    /// Voice count (#116): right after the event there is exactly one live voice, plus at most
    /// one fading copy of the note an attack replaced; once one fade length has been rendered,
    /// the playing note is the only voice left.
    private func play(_ e: SynthEngine, _ steps: [(Key, UInt8?)]) {
        for (i, (key, expected)) in steps.enumerated() {
            switch key {
            case .on(let n): on(e, n)
            case .off(let n): off(e, n)
            }
            let v = e.monoVoiceForTesting
            if let expected {
                #expect(v.active && !v.releasing && v.midiNote == expected,
                        "step \(i) (\(key)): expected \(expected), got \(v.midiNote) releasing=\(v.releasing)")
                #expect(e.liveVoiceCountForTesting == 1, "step \(i) (\(key)): one live voice")
                #expect(e.debugActiveVoiceCount <= 2, "step \(i) (\(key)): at most one fading copy")
                settle(e)
                #expect(e.debugActiveVoiceCount == 1, "step \(i) (\(key)): the fading copy is gone")
                #expect(e.monoVoiceForTesting.midiNote == expected && !e.monoVoiceForTesting.releasing)
            } else {
                #expect(v.releasing, "step \(i) (\(key)): expected silence (release)")
                #expect(e.liveVoiceCountForTesting <= 1, "step \(i) (\(key))")
                settle(e)
                #expect(e.debugActiveVoiceCount <= 1, "step \(i) (\(key))")
            }
        }
    }

    // #115 "推奨テストケース", verbatim: C4=60 D4=62 E4=64 G4=67, E3=52 A3=57 B3=59.
    @Test("#115 HIGH latch sequence, checked after every event", arguments: engines)
    func issueHighLatchSequence(fm: FMEngine) {
        play(engine(fm), [
            (.on(60), 60), (.on(64), 64), (.on(62), 64), (.on(67), 67),
            (.off(67), 64), (.off(64), 62), (.off(62), 60), (.off(60), nil),
        ])
    }

    @Test("#115 LOW latch sequence, checked after every event", arguments: engines)
    func issueLowLatchSequence(fm: FMEngine) {
        play(engine(fm), [
            (.on(60), 60), (.on(57), 57), (.on(59), 57), (.on(52), 52),
            (.off(52), 57), (.off(57), 59), (.off(59), 60), (.off(60), nil),
        ])
    }

    @Test("#115 Reset sequence: releasing every key clears the latch in both directions", arguments: engines)
    func issueResetSequence(fm: FMEngine) {
        let e = engine(fm)
        // HIGH phrase, all keys off, then a LOW phrase. D4 probes the latch: a stale HIGH
        // latch would move to it; a fresh LOW latch stays on A3.
        play(e, [
            (.on(60), 60), (.on(64), 64),
            (.off(64), 60), (.off(60), nil),
            (.on(60), 60), (.on(57), 57), (.on(62), 57),
            (.off(62), 57), (.off(57), 60), (.off(60), nil),
        ])
        // ...and back: LOW phrase done, a HIGH phrase must latch HIGH. D4 probes again: a
        // stale LOW latch would fall to C4; a fresh HIGH latch stays on E4.
        play(e, [
            (.on(60), 60), (.on(64), 64), (.on(62), 64),
            (.off(62), 64), (.off(64), 60), (.off(60), nil),
        ])
    }

    @Test("LOW remains latched until all physical keys are released", arguments: engines)
    func lowPriorityAndReset(fm: FMEngine) {
        let e = engine(fm)
        on(e, 72); on(e, 60); on(e, 80)
        #expect(e.monoVoiceForTesting.midiNote == 60)
        off(e, 60); off(e, 72)
        #expect(e.monoVoiceForTesting.midiNote == 80)
        on(e, 70)
        #expect(e.monoVoiceForTesting.midiNote == 70)
        off(e, 70); off(e, 80)
        on(e, 60); on(e, 72)
        #expect(e.monoVoiceForTesting.midiNote == 72)
    }

    @Test("Legato preserves operator phase, feedback, amp/pitch EG and first velocity", arguments: engines)
    func noRetrigger(fm: FMEngine) {
        let e = engine(fm)
        e.setPitchEGRates(60, 50, 40, 30)
        e.setPitchEGLevels(70, 60, 50, 40)
        on(e, 60)
        render(e, frames: 256)
        let before = e.monoVoiceForTesting
        on(e, 72, velocity: 1000)
        let after = e.monoVoiceForTesting
        #expect(after.note == 72)
        #expect(after.ops.0.phase == before.ops.0.phase)
        #expect(after.ops.0.fbBuf.0 == before.ops.0.fbBuf.0)
        #expect(after.ops.0.gainOut == before.ops.0.gainOut)
        #expect(after.ops.0.env.level == before.ops.0.env.level)
        #expect(after.ops.0.env.ix == before.ops.0.env.ix)
        #expect(after.ops.0.velocityOffset == before.ops.0.velocityOffset)
        #expect(after.pitchEG.level == before.pitchEG.level)
        #expect(after.pitchEG.ix == before.pitchEG.ix)
        #expect(after.ops.0.baseFrequency > before.ops.0.baseFrequency)
        off(e, 72)
        #expect(e.monoVoiceForTesting.ops.0.env.level == before.ops.0.env.level)
        off(e, 60); on(e, 67)                  // an attack: the new note starts its EG from 0
        #expect(e.monoVoiceForTesting.ops.0.env.level == 0)
        #expect(e.liveVoiceCountForTesting == 1)   // the released 60 fades out in another slot
        settle(e)
        #expect(e.debugActiveVoiceCount == 1)
    }

    @Test("A duplicate note-on does not stack: one note-off releases the key, like Poly (#124)", arguments: engines)
    func duplicateNotes(fm: FMEngine) {
        let e = engine(fm)
        on(e, 60); on(e, 60); on(e, 72)
        #expect(e.monoVoiceForTesting.midiNote == 72)
        off(e, 60)
        #expect(e.monoVoiceForTesting.midiNote == 72)
        #expect(!e.monoVoiceForTesting.releasing)
        off(e, 72)
        // 60 was pressed twice but released once: it is no longer held, so there is no fallback.
        #expect(e.monoVoiceForTesting.midiNote == 72)
        #expect(e.monoVoiceForTesting.releasing)

        on(e, 65)
        off(e, 99); on(e, 200)   // unknown release and invalid note are harmless
        #expect(e.monoVoiceForTesting.midiNote == 65)
        #expect(!e.monoVoiceForTesting.releasing)
        on(e, 65, velocity: 0)   // velocity-0 note-on is a note-off
        #expect(e.monoVoiceForTesting.releasing)
    }

    @Test("A dropped note-off is recovered by pressing and releasing the key once more (#124)", arguments: engines)
    func droppedNoteOffRecovery(fm: FMEngine) {
        let e = engine(fm)
        on(e, 60); on(e, 72)          // HIGH latch; the note-off for 60 is "lost"
        off(e, 72)
        #expect(e.monoVoiceForTesting.midiNote == 60)   // phantom fallback to the stuck key
        on(e, 60)                     // the player presses the stuck key again...
        #expect(e.monoVoiceForTesting.midiNote == 60)
        off(e, 60)                    // ...and one release clears it
        #expect(e.monoVoiceForTesting.releasing)
        on(e, 55); on(e, 50)          // a new phrase latches fresh (LOW), no phantom above
        #expect(e.monoVoiceForTesting.midiNote == 50)
    }

    @Test("Sustain holds just one voice; a new physical phrase attacks and resets priority", arguments: engines)
    func sustain(fm: FMEngine) {
        let e = engine(fm)
        // A non-default pitch EG, so `pitchEG.down` really tracks key/pedal state
        // (with the default flat EG it is disabled and `down` is always false).
        e.setPitchEGRates(60, 50, 40, 30)
        e.setPitchEGLevels(70, 60, 50, 40)
        render(e)
        e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
        on(e, 72); on(e, 60); off(e, 60); off(e, 72)
        #expect(e.monoVoiceForTesting.pitchEG.enabled)
        #expect(e.monoVoiceForTesting.sustained)
        #expect(e.monoVoiceForTesting.pitchEG.down)     // the pedal holds the pitch EG too
        on(e, 55); on(e, 67)
        #expect(e.monoVoiceForTesting.midiNote == 67)
        #expect(!e.monoVoiceForTesting.sustained)
        #expect(e.monoVoiceForTesting.pitchEG.down)
        #expect(e.liveVoiceCountForTesting == 1)   // the pedal-held 60 fades out in another slot
        settle(e)
        #expect(e.debugActiveVoiceCount == 1)
        e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: 0))
        render(e)
        #expect(!e.monoVoiceForTesting.releasing)
        #expect(e.monoVoiceForTesting.pitchEG.down)     // keys still held
        off(e, 67); off(e, 55)
        #expect(e.monoVoiceForTesting.releasing)
        #expect(!e.monoVoiceForTesting.pitchEG.down)
    }

    @Test("Fingered only glides on overlap; reversals start at the current audible pitch")
    func fingered() {
        let e = engine()
        e.setPortamento(enabled: true, time: 1)
        on(e, 60); off(e, 60); on(e, 72)
        #expect(e.debugGlideOffsetCents(voice: 0) == 0)
        on(e, 84)
        #expect(e.debugGlideOffsetCents(voice: 0) == -1200)
        render(e, frames: 640)
        let current = e.debugGlideOffsetCents(voice: 0)
        off(e, 84)
        #expect(abs(e.debugGlideOffsetCents(voice: 0) - (current + 1200)) < 0.01)
    }

    @Test("Full-time glides across gaps; OFF suppresses glide")
    func fullTime() {
        let e = engine(portamento: .fullTime)
        e.setPortamento(enabled: true, time: 1)
        on(e, 60); off(e, 60); on(e, 72)
        #expect(e.debugGlideOffsetCents(voice: 0) == -1200)
        e.setPortamento(enabled: false, time: 1)
        on(e, 84)
        #expect(e.debugGlideOffsetCents(voice: 0) == 0)
    }

    @Test("Mode change and all-notes/sound-off clear held state and prevent resurrection", arguments: engines)
    func reset(fm: FMEngine) {
        for cc: UInt8 in [120, 123] {
            let e = engine(fm)
            on(e, 60); on(e, 72)                      // HIGH latch, 60 still held
            e.sendMIDI(.init(kind: .controlChange, data1: cc, data2: 0))
            render(e)
            if cc == 123 {
                // All Notes Off: the note releases with its natural tail.
                #expect(e.monoVoiceForTesting.active)
                #expect(e.monoVoiceForTesting.releasing)
            } else {
                // All Sound Off: silent at once.
                #expect(!e.monoVoiceForTesting.active)
                #expect(e.debugActiveVoiceCount == 0)
            }
            off(e, 72)                                // no phantom fallback to the forgotten 60
            #expect(e.monoVoiceForTesting.midiNote == 72)
            #expect(cc == 123 ? e.monoVoiceForTesting.releasing : !e.monoVoiceForTesting.active)
            on(e, 65); on(e, 62)                      // a fresh phrase latches LOW, not stale HIGH
            #expect(e.monoVoiceForTesting.midiNote == 62)
            #expect(!e.monoVoiceForTesting.releasing)
        }
        // #116: a mode switch fades the old mode's voices out instead of cutting them, so the
        // pool is empty once one fade length has been rendered (and not before).
        let e = engine(fm)
        on(e, 60); on(e, 72)
        e.setMonoPerformance(enabled: false, portamentoMode: .fingered, glissando: false)
        render(e, frames: SynthEngine.voiceFadeSamples - kBlockSize)
        #expect(e.debugActiveVoiceCount == 1)
        #expect(e.liveVoiceCountForTesting == 0)
        render(e, frames: kBlockSize)
        #expect(e.debugActiveVoiceCount == 0)
        off(e, 72); on(e, 60); on(e, 64)
        #expect(e.debugActiveVoiceCount == 2)
        e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        settle(e)
        #expect(e.debugActiveVoiceCount == 0)
    }

    @Test("Mono has one physical voice even with unison and Voice Stack enabled", arguments: engines)
    func oneVoice(fm: FMEngine) {
        let e = engine(fm)
        e.setUnison(count: 8, detuneCents: 10)
        e.setVoiceStackMultiplier(16)
        on(e, 60); on(e, 72); off(e, 60)
        #expect(e.debugActiveVoiceCount == 1)
    }

    @Test("Glissando quantizes the rendered glide, not the time accumulator")
    func glissando() {
        let e = engine()
        e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: true)
        e.setPortamento(enabled: true, time: 0.5)
        on(e, 60); on(e, 72)
        render(e, frames: 2048)
        let voice = e.monoVoiceForTesting
        let cents = 1200 * log2f(voice.ops.0.frequency / (voice.ops.0.baseFrequency * voice.ops.0.ratio * voice.ops.0.detune))
        #expect(abs(cents - (voice.glideOffsetCents / 100).rounded() * 100) < 0.01)
        #expect(abs(voice.glideOffsetCents.truncatingRemainder(dividingBy: 100)) > 0.1)
        off(e, 72)
        #expect(abs(e.debugGlideOffsetCents(voice: 0) - (1200 + cents)) < 0.01)
    }

    @Test("Fixed-frequency operators retain frequency across legato; ratio operators retune")
    func fixedFrequency() {
        let e = engine()
        e.setOperatorFixedFrequency(0, enabled: 1, coarse: 2, fine: 30)
        on(e, 60)
        let before = e.monoVoiceForTesting
        on(e, 72)
        let after = e.monoVoiceForTesting
        #expect(abs(after.ops.0.frequency - before.ops.0.frequency) < 0.001)
        #expect(after.ops.1.frequency > before.ops.1.frequency)
    }

    @Test("Mono transposed note bounds agree for attack and legato")
    func transposeBoundary() {
        let e = engine()
        e.setTranspose(24)
        on(e, 120)
        #expect(e.monoVoiceForTesting.note == 127)
        on(e, 127)
        #expect(e.monoVoiceForTesting.note == 127)
        off(e, 127); off(e, 120)
        e.setTranspose(-24)
        on(e, 0); on(e, 12)
        #expect(e.monoVoiceForTesting.note == 0)
    }

    @Test("Controller reset leaves notes and held keys alone, exactly as in Poly (#118)", arguments: engines)
    func controllerReset(fm: FMEngine) {
        let e = engine(fm)
        on(e, 72); on(e, 60)                  // LOW latch, 60 sounds
        e.resetControllers()
        render(e)
        #expect(e.monoVoiceForTesting.midiNote == 60)
        #expect(!e.monoVoiceForTesting.releasing)
        off(e, 60)                            // the still-held 72 takes over: no phrase reset
        #expect(e.monoVoiceForTesting.midiNote == 72)
        #expect(!e.monoVoiceForTesting.releasing)
        on(e, 55)                             // the LOW latch survived the reset
        #expect(e.monoVoiceForTesting.midiNote == 55)
        on(e, 67)
        #expect(e.monoVoiceForTesting.midiNote == 55)
    }

    @Test("Controller reset releases a Mono note held only by the pedal, like a pedal-up (#118)",
          arguments: [FMEngine.modern, .markI])
    func controllerResetReleasesPedalHeldNote(fm: FMEngine) {
        // The reset turns the pedal off, so it must render exactly like a CC64-off.
        func take(reset: Bool) -> (SynthEngine, [Float]) {
            let e = engine(fm)
            e.setPitchEGRates(60, 50, 40, 30)      // non-default, so `pitchEG.down` is meaningful
            e.setPitchEGLevels(70, 60, 50, 40)
            render(e)
            e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
            on(e, 60)
            render(e, frames: 256)
            off(e, 60)
            #expect(e.monoVoiceForTesting.sustained)
            #expect(!e.monoVoiceForTesting.releasing)
            if reset { e.resetControllers() }
            else { e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: 0)) }
            var out: [Float] = []
            for _ in 0..<16 {
                var l = [Float](repeating: 0, count: 256), r = l
                l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                    e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: 256)
                }}
                out += l
            }
            return (e, out)
        }
        let (e, afterReset) = take(reset: true)
        #expect(e.monoVoiceForTesting.releasing)       // not left droning at its sustain level
        #expect(!e.monoVoiceForTesting.sustained)
        #expect(!e.monoVoiceForTesting.pitchEG.down)
        let (_, afterPedalUp) = take(reset: false)
        #expect(afterPedalUp.contains { $0 != 0 })
        #expect(afterReset == afterPedalUp)
    }

    @Test("A preset load can skip the controller reset, so a pedal-held Mono note keeps ringing (#118)",
          arguments: engines)
    func presetLoadWithoutControllerReset(fm: FMEngine) throws {
        let preset = try #require(DX7FactoryPresets.all.first { $0.name == "STRINGS" })
        for reset in [false, true] {
            let e = engine(fm)
            e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
            on(e, 60); render(e, frames: 256); off(e, 60)
            #expect(e.monoVoiceForTesting.sustained)
            if reset { e.loadDX7Preset(preset) } else { e.loadDX7Preset(preset, resetControllers: false) }
            render(e, frames: 256)
            #expect(e.monoVoiceForTesting.sustained == !reset, "reset=\(reset)")
            #expect(e.monoVoiceForTesting.releasing == reset, "reset=\(reset)")
            on(e, 62); render(e, frames: 256); off(e, 62)   // the pedal is still down only without a reset
            #expect(e.monoVoiceForTesting.midiNote == 62)
            #expect(e.monoVoiceForTesting.sustained == !reset, "reset=\(reset)")
        }
    }

    @Test("requestAllNotesOff ends notes and held keys without the MIDI ring (#118)", arguments: engines)
    func requestAllNotesOff(fm: FMEngine) {
        let e = engine(fm)
        on(e, 60); on(e, 72)                  // HIGH latch, 60 still held
        e.requestAllNotesOff()
        render(e)
        #expect(e.monoVoiceForTesting.releasing)
        off(e, 72)                            // no phantom fallback to 60
        #expect(e.monoVoiceForTesting.releasing)
        on(e, 65); on(e, 62)                  // a fresh phrase latches LOW, not the stale HIGH
        #expect(e.monoVoiceForTesting.midiNote == 62)
    }

    @Test("requestAllNotesOff renders exactly like CC123 in Poly and Mono (#118)")
    func requestAllNotesOffMatchesCC123() {
        for mono in [false, true] {
            func take(_ useRequest: Bool) -> [Float] {
                let e = SynthEngine()
                e.setSampleRate(48000)
                e.setMonoPerformance(enabled: mono, portamentoMode: .fingered, glissando: false)
                render(e)
                e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
                on(e, 60); on(e, 64)
                var out: [Float] = []
                func chunk(_ n: Int) {
                    var l = [Float](repeating: 0, count: n), r = l
                    l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                        e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: n)
                    }}
                    out += l
                }
                chunk(512)
                if useRequest { e.requestAllNotesOff() }
                else { e.sendMIDI(.init(kind: .controlChange, data1: 123, data2: 0)) }
                for _ in 0..<8 { chunk(256) }
                return out
            }
            let viaCC = take(false)
            #expect(viaCC.contains { $0 != 0 })
            #expect(take(true) == viaCC)
        }
    }

    @Test("Both synthesis engines preserve operator EG levels on overlap")
    func bothEngines() {
        for mode: FMEngine in [.modern, .markI] {
            let e = engine()
            e.setFMEngine(mode)
            render(e)
            on(e, 60)
            render(e, frames: 512)
            let before = e.monoVoiceForTesting
            on(e, 72)
            let after = e.monoVoiceForTesting
            #expect(after.ops.0.env.level == before.ops.0.env.level)
            #expect(after.ops.0.markIGainOut == before.ops.0.markIGainOut)
            #expect(after.pitchEG.level == before.pitchEG.level)
            #expect(e.debugActiveVoiceCount == 1)
        }
    }

    @Test("Split coverage applies to legato too, including silent gaps and fallback", arguments: engines)
    func splitCoverage(fm: FMEngine) {
        let e = engine(fm)
        e.setTimbreMode(.split, splitPoint: 60)
        e.setPitchEGRates(60, 50, 40, 30)      // non-default, so `pitchEG.down` is meaningful
        e.setPitchEGLevels(70, 60, 50, 40)
        render(e)
        on(e, 48); on(e, 72)
        #expect(e.monoVoiceForTesting.slotId == 1)
        off(e, 72)
        #expect(e.monoVoiceForTesting.slotId == 0)
        e.setSlotEnabled(1, enabled: false)
        render(e)
        on(e, 72)
        // #116: the gap key sounds nothing, so the held note releases naturally (no cut),
        // pitch EG included.
        #expect(e.debugActiveVoiceCount == 1)
        #expect(e.monoVoiceForTesting.releasing)
        #expect(e.monoVoiceForTesting.midiNote == 48)
        #expect(e.monoVoiceForTesting.pitchEG.enabled)
        #expect(!e.monoVoiceForTesting.pitchEG.down)
        off(e, 72)                                     // back to the held 48: an attack over the tail
        #expect(e.monoVoiceForTesting.midiNote == 48)
        #expect(!e.monoVoiceForTesting.releasing)
        #expect(e.liveVoiceCountForTesting == 1)
        settle(e)
        #expect(e.debugActiveVoiceCount == 1)
    }

    @Test("An attack into a coverage gap releases a pedal-held note, pitch EG included (#116)", arguments: engines)
    func attackIntoGapReleasesPedalHeldNote(fm: FMEngine) {
        let e = engine(fm)
        e.setTimbreMode(.split, splitPoint: 60)
        e.setSlotEnabled(1, enabled: false)
        e.setPitchEGRates(60, 50, 40, 30)
        e.setPitchEGLevels(70, 60, 50, 40)
        render(e)
        e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
        on(e, 48)
        render(e, frames: 256)
        off(e, 48)
        #expect(e.monoVoiceForTesting.sustained)
        #expect(e.monoVoiceForTesting.pitchEG.enabled)
        #expect(e.monoVoiceForTesting.pitchEG.down)     // the pedal holds the pitch EG too
        on(e, 72)                                       // the disabled upper zone: sounds nothing
        #expect(e.monoVoiceForTesting.midiNote == 48)
        #expect(e.monoVoiceForTesting.releasing)
        #expect(!e.monoVoiceForTesting.pitchEG.down)
        #expect(e.debugActiveVoiceCount == 1)
    }

    @Test("Mono bypasses random unison detune on attack as well as legato")
    func randomUnisonBypass() {
        let e = engine()
        e.setUnison(count: 8, detuneCents: 40, detuneMode: 1)
        on(e, 60)
        let original = e.monoVoiceForTesting.ops.0.baseFrequency
        on(e, 72); off(e, 72)
        #expect(e.monoVoiceForTesting.ops.0.baseFrequency == original)
        #expect(original == kMIDIFreqLUT[60])
    }

    @Test("Dual with part zero disabled selects the first enabled part", arguments: engines)
    func disabledFirstPart(fm: FMEngine) {
        let e = engine(fm)
        e.setTimbreMode(.dual)
        e.setSlotEnabled(0, enabled: false)
        render(e)
        on(e, 60)
        #expect(e.debugActiveVoiceCount == 1)
        #expect(e.monoVoiceForTesting.slotId == 1)
    }

    @Test("Bypassed layer/unison/stack do not attenuate Mono audio")
    func noPhantomNormalization() {
        let normal = engine()
        let stacked = engine()
        stacked.setTimbreMode(.layer)
        stacked.setUnison(count: 8, detuneCents: 0)
        stacked.setVoiceStackMultiplier(16)
        render(stacked)
        on(normal, 60); on(stacked, 60)
        func audio(_ e: SynthEngine) -> [Float] {
            var l = [Float](repeating: 0, count: 1024)
            var r = l
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
                e.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: 1024)
            }}
            return l
        }
        let expected = audio(normal)
        #expect(expected.contains { $0 != 0 })
        #expect(audio(stacked) == expected)
    }

    @Test("Snapshot coalescing cannot hide a round-trip mode switch", arguments: engines)
    func collapsedModeSwitch(fm: FMEngine) {
        let e = engine(fm)
        on(e, 60); on(e, 72)
        e.setMonoPerformance(enabled: false, portamentoMode: .fingered, glissando: false)
        e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        settle(e)                             // #116: the switch fades the voices out
        #expect(e.debugActiveVoiceCount == 0)
        off(e, 72)
        #expect(e.debugActiveVoiceCount == 0)
        on(e, 55); on(e, 67)
        #expect(e.monoVoiceForTesting.midiNote == 67)
    }

    @Test("Full-time attack starts at the actual audible pitch, including transpose clamps")
    func fullTimeAudibleAnchor() {
        let e = engine(portamento: .fullTime)
        e.setPortamento(enabled: true, time: 1)
        e.setTranspose(24)
        on(e, 120); off(e, 120); on(e, 121)
        #expect(e.monoVoiceForTesting.note == 127)
        #expect(e.debugGlideOffsetCents(voice: 0) == 0)

        let moving = engine(portamento: .fullTime)
        moving.setPortamento(enabled: true, time: 1)
        on(moving, 60); on(moving, 72)
        render(moving, frames: 640)
        let before = moving.debugGlideOffsetCents(voice: 0)
        off(moving, 60); off(moving, 72); on(moving, 84)
        #expect(abs(moving.debugGlideOffsetCents(voice: 0) - (before - 1200)) < 0.01)
    }
}
