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

    private func engine(portamento: MonoPortamentoMode = .fingered) -> SynthEngine {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        engine.setMonoPerformance(enabled: true, portamentoMode: portamento, glissando: false)
        render(engine)
        return engine
    }

    private func on(_ engine: SynthEngine, _ note: UInt8, velocity: UInt32 = 50000) {
        engine.sendMIDI(.init(kind: .noteOn, data1: note, data2: velocity))
        render(engine)
    }

    private func off(_ engine: SynthEngine, _ note: UInt8) {
        engine.sendMIDI(.init(kind: .noteOff, data1: note, data2: 0))
        render(engine)
    }

    @Test("First overlap latches HIGH, non-winning keys do not interrupt, release returns")
    func highPriorityTrill() {
        let e = engine()
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

    @Test("LOW remains latched until all physical keys are released")
    func lowPriorityAndReset() {
        let e = engine()
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

    @Test("Legato preserves operator phase, feedback, amp/pitch EG and first velocity")
    func noRetrigger() {
        let e = engine()
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
        off(e, 60); on(e, 67)
        #expect(e.monoVoiceForTesting.ops.0.env.level == 0)
        #expect(e.debugActiveVoiceCount == 1)
    }

    @Test("A duplicate note-on does not stack: one note-off releases the key, like Poly (#124)")
    func duplicateNotes() {
        let e = engine()
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

    @Test("A dropped note-off is recovered by pressing and releasing the key once more (#124)")
    func droppedNoteOffRecovery() {
        let e = engine()
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

    @Test("Sustain holds just one voice; a new physical phrase attacks and resets priority")
    func sustain() {
        let e = engine()
        e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
        on(e, 72); on(e, 60); off(e, 60); off(e, 72)
        #expect(e.monoVoiceForTesting.sustained)
        on(e, 55); on(e, 67)
        #expect(e.monoVoiceForTesting.midiNote == 67)
        #expect(!e.monoVoiceForTesting.sustained)
        #expect(e.debugActiveVoiceCount == 1)
        e.sendMIDI(.init(kind: .controlChange, data1: 64, data2: 0))
        render(e)
        #expect(!e.monoVoiceForTesting.releasing)
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

    @Test("Mode change and all-notes/sound-off clear held state and prevent resurrection")
    func reset() {
        for cc: UInt8 in [120, 123] {
            let e = engine()
            on(e, 60); on(e, 72)
            e.sendMIDI(.init(kind: .controlChange, data1: cc, data2: 0))
            off(e, 72)
            #expect(e.monoVoiceForTesting.midiNote != 60)
            on(e, 65); on(e, 70)
            #expect(e.monoVoiceForTesting.midiNote == 70)
        }
        let e = engine()
        on(e, 60); on(e, 72)
        e.setMonoPerformance(enabled: false, portamentoMode: .fingered, glissando: false)
        render(e)
        #expect(e.debugActiveVoiceCount == 0)
        off(e, 72); on(e, 60); on(e, 64)
        #expect(e.debugActiveVoiceCount == 2)
        e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        render(e)
        #expect(e.debugActiveVoiceCount == 0)
    }

    @Test("Mono has one physical voice even with unison and Voice Stack enabled")
    func oneVoice() {
        let e = engine()
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

    @Test("Controller reset leaves notes and held keys alone, exactly as in Poly (#118)")
    func controllerReset() {
        let e = engine()
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

    @Test("requestAllNotesOff ends notes and held keys without the MIDI ring (#118)")
    func requestAllNotesOff() {
        let e = engine()
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

    @Test("Split coverage applies to legato too, including silent gaps and fallback")
    func splitCoverage() {
        let e = engine()
        e.setTimbreMode(.split, splitPoint: 60)
        render(e)
        on(e, 48); on(e, 72)
        #expect(e.monoVoiceForTesting.slotId == 1)
        off(e, 72)
        #expect(e.monoVoiceForTesting.slotId == 0)
        e.setSlotEnabled(1, enabled: false)
        render(e)
        on(e, 72)
        #expect(e.debugActiveVoiceCount == 0)
        off(e, 72)
        #expect(e.monoVoiceForTesting.midiNote == 48)
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

    @Test("Dual with part zero disabled selects the first enabled part")
    func disabledFirstPart() {
        let e = engine()
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

    @Test("Snapshot coalescing cannot hide a round-trip mode switch")
    func collapsedModeSwitch() {
        let e = engine()
        on(e, 60); on(e, 72)
        e.setMonoPerformance(enabled: false, portamentoMode: .fingered, glissando: false)
        e.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        render(e)
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
