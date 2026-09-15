import Testing
import Foundation
@testable import M2DXCore

@Suite("Live operator output level (M2DX #112)")
struct LiveOutputLevelTests {
    private func render(_ s: SynthEngine, blocks: Int = 1) -> [Float] {
        let n = 64 * blocks
        var l = [Float](repeating: 0, count: n), r = l
        l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
            s.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: n)
        }}
        return l
    }

    private func sustainingCarrier(_ mode: FMEngine) -> SynthEngine {
        let s = SynthEngine()
        s.setSampleRate(48000)
        s.setFMEngine(mode)
        let ops = (0..<6).map { DX7OperatorPreset(outputLevel: $0 == 5 ? 99 : 0) }
        s.loadDX7Preset(DX7Preset(name: "Live level", algorithm: 31, feedback: 0,
                                 operators: ops, category: .other))
        _ = render(s)
        s.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        _ = render(s, blocks: 100)
        return s
    }

    private func rms(_ x: [Float]) -> Double {
        sqrt(x.reduce(0) { $0 + Double($1) * Double($1) } / Double(x.count))
    }

    @Test("a held carrier follows OL99→91 (half amplitude) without retriggering", arguments: [FMEngine.modern, .markI])
    func heldLevel(mode: FMEngine) {
        let edited = sustainingCarrier(mode), control = sustainingCarrier(mode)
        edited.setOperatorDX7OutputLevel(0, level: 91)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let changed = render(edited, blocks: 64), original = render(control, blocks: 64)
        #expect(abs(rms(changed) / rms(original) - 0.5) < 0.005)
        #expect(edited.debugActiveVoiceCount == 1)
    }

    @Test("a held carrier recovers from OL0 to OL99 without exceeding a fresh OL99 voice", arguments: [FMEngine.modern, .markI])
    func silentToFull(mode: FMEngine) {
        let edited = sustainingCarrier(mode), control = sustainingCarrier(mode)
        edited.setOperatorDX7OutputLevel(0, level: 0)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let quiet = render(edited, blocks: 64), original = render(control, blocks: 64)
        #expect(rms(quiet) < rms(original) * 0.001)
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let recovered = render(edited, blocks: 64), expected = render(control, blocks: 64)
        #expect(abs(rms(recovered) / rms(expected) - 1) < 0.005)
    }

    @Test("output edits preserve attack, decay and release progress", arguments: [0, 1, 2, 3])
    func envelopeProgress(stage: Int) throws {
        var op = DX7Operator()
        op.setOutputLevel(99)
        op.env.setRates(stage == 0 ? 20 : 99, stage == 1 ? 20 : 99, stage == 2 ? 20 : 99, 20)
        op.env.setLevels(99, 80, 60, 0)
        op.noteOn(baseFreq: 261.6256)
        for _ in 0..<1000 {
            if op.env.ix == stage { break }
            _ = op.env.getsample()
        }
        if stage == 3 { op.noteOff() }
        for _ in 0..<10 { _ = op.env.getsample() }
        try #require(op.env.ix == stage)
        var control = op
        let beforePhase = op.phase, beforeDown = op.env.down
        op.setOutputLevel(91)
        #expect(op.env.ix == stage)
        #expect(op.env.down == beforeDown)
        #expect(op.phase == beforePhase)
        op.updateGain(lfoAmpMod: 0)
        control.updateGain(lfoAmpMod: 0)
        #expect(op.levelIn < control.levelIn)
        // Crossing the silence floor must not finish the running stage.
        op.setOutputLevel(0)
        op.updateGain(lfoAmpMod: 0)
        control.updateGain(lfoAmpMod: 0)
        op.setOutputLevel(99)
        op.updateGain(lfoAmpMod: 0)
        control.updateGain(lfoAmpMod: 0)
        #expect(op.env.ix == control.env.ix)
        #expect(op.levelIn == control.levelIn)
        // With no new note-on, the original release must still end naturally.
        if stage == 3 {
            op.env.setRates(99, 99, 99, 99)
            for _ in 0..<1000 { _ = op.env.getsample() }
            #expect(!op.env.isActive)
        }
    }

    @Test("raising an initially quiet sustain matches the new OL and retains its release", arguments: [0, 10, 30], [60, 99])
    func initiallyQuiet(initialOL: Int, sustain: Int) {
        var op = DX7Operator()
        op.env.setRates(99, 99, 99, 20)
        op.env.setLevels(99, 80, sustain, 0)
        op.setOutputLevel(initialOL)
        op.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { op.updateGain(lfoAmpMod: 0) }
        op.setOutputLevel(99)
        op.updateGain(lfoAmpMod: 0)
        var expected = DX7Operator()
        expected.env.setRates(99, 99, 99, 20)
        expected.env.setLevels(99, 80, sustain, 0)
        expected.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { expected.updateGain(lfoAmpMod: 0) }
        #expect(op.levelIn == expected.levelIn)
        op.noteOff(); expected.noteOff()
        for _ in 0..<20 {
            op.updateGain(lfoAmpMod: 0); expected.updateGain(lfoAmpMod: 0)
            #expect(op.env.isActive)
            #expect(op.levelIn == expected.levelIn)
        }
    }

    @Test("a snapshot changing OL and L3 uses the new sustain level")
    func simultaneousLevelAndEnvelope() {
        var voice = DX7Voice()
        var params = OperatorSnapshot()
        params.dx7EgR0 = 99; params.dx7EgR1 = 99; params.dx7EgR2 = 99
        params.dx7EgL0 = 99; params.dx7EgL1 = 99; params.dx7EgL2 = 99
        voice.applyParams(params, opIndex: 0)
        voice.ops.0.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { voice.ops.0.updateGain(lfoAmpMod: 0) }
        params.dx7OutputLevel = 91
        params.dx7EgL2 = 60
        voice.applyParams(params, opIndex: 0)
        voice.ops.0.updateGain(lfoAmpMod: 0)
        var expected = DX7Voice()
        expected.applyParams(params, opIndex: 0)
        expected.ops.0.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { expected.ops.0.updateGain(lfoAmpMod: 0) }
        #expect(voice.ops.0.levelIn == expected.ops.0.levelIn)
        voice.applyParams(params, opIndex: 0)
        voice.ops.0.updateGain(lfoAmpMod: 0)
        #expect(voice.ops.0.levelIn == expected.ops.0.levelIn)
    }

    @Test("legato KLS changes cannot accumulate live attenuation or alter EG progress")
    func legatoScaling() throws {
        var slot = SlotSnapshot()
        slot.ops.0.dx7EgR0 = 20
        slot.ops.0.klsBreakPoint = 0
        slot.ops.0.klsRightDepth = 99
        slot.ops.0.klsRightCurve = 3 // +LIN: high notes reach the OL ceiling
        var voice = DX7Voice()
        voice.applyParams(slot.ops.0, opIndex: 0)
        voice.noteOn(0, velocity16: 100 << 9)
        voice.legatoTo(0, midiNote: 0, slot: slot)
        for _ in 0..<10 { voice.ops.0.updateGain(lfoAmpMod: 0) }
        var control = voice
        for _ in 0..<32 {
            slot.ops.0.dx7OutputLevel = 0
            voice.applyParams(slot.ops.0, opIndex: 0)
            voice.legatoTo(127, midiNote: 127, slot: slot)
            slot.ops.0.dx7OutputLevel = 99
            voice.applyParams(slot.ops.0, opIndex: 0)
            voice.legatoTo(0, midiNote: 0, slot: slot)
            try #require(voice.ops.0.env.targetLevel == control.ops.0.env.targetLevel)
            voice.ops.0.updateGain(lfoAmpMod: 0)
            control.ops.0.updateGain(lfoAmpMod: 0)
            #expect(voice.ops.0.levelIn == control.ops.0.levelIn)
            #expect(voice.ops.0.env.ix == control.ops.0.env.ix)
        }
    }

    @Test("raising a release finishes at silence, and a reused operator starts at its new OL")
    func releaseAndReuse() {
        var op = DX7Operator()
        op.env.setRates(99, 99, 99, 70)
        op.env.setLevels(99, 99, 99, 0)
        op.setOutputLevel(30)
        op.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { op.updateGain(lfoAmpMod: 0) }
        op.noteOff()
        op.updateGain(lfoAmpMod: 0)
        op.setOutputLevel(99)
        var last: Int32 = 0
        for _ in 0..<1000 {
            op.updateGain(lfoAmpMod: 0)
            last = op.levelIn
            if !op.env.isActive { break }
        }
        #expect(!op.env.isActive)
        #expect(last == 16 << 16)
        op.setOutputLevel(30)
        op.noteOn(baseFreq: 261.6256)
        var expected = DX7Operator()
        expected.env.setRates(99, 99, 99, 70)
        expected.env.setLevels(99, 99, 99, 0)
        expected.setOutputLevel(30)
        expected.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 {
            op.updateGain(lfoAmpMod: 0); expected.updateGain(lfoAmpMod: 0)
            #expect(op.levelIn == expected.levelIn)
        }
    }

    @Test("raising OL after legato to a weaker KLS cannot exceed full-scale envelope gain")
    func upwardRebaseAfterLegato() {
        var op = DX7Operator()
        op.klsOffset = 100
        op.setOutputLevel(30)
        op.env.setRates(20, 99, 99, 20)
        op.env.setLevels(99, 80, 60, 0)
        op.noteOn(baseFreq: 261.6256)
        for _ in 0..<1000 { op.updateGain(lfoAmpMod: 0) }
        op.klsOffset = 0
        op.refreshKeyboardOutputLevel()
        op.setOutputLevel(99)
        var full = DX7Operator()
        full.env.setRates(99, 99, 99, 20)
        full.env.setLevels(99, 99, 99, 0)
        full.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { full.updateGain(lfoAmpMod: 0) }
        for _ in 0..<100 {
            op.updateGain(lfoAmpMod: 0)
            #expect(op.levelIn <= full.levelIn)
        }
    }

    // MARK: - Legato sustain (review P2-1)

    /// A Mono voice sustaining under one key's KLS keeps its held level after legato (DX7Voice
    /// contract). A one-step OL edit must then move the output by one step, not re-anchor the
    /// sustain to the new key's KLS.
    private func legatoSustainingCarrier(_ mode: FMEngine, klsDepth: Int) -> SynthEngine {
        let s = SynthEngine()
        s.setSampleRate(48000)
        s.setFMEngine(mode)
        s.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        let ops = (0..<6).map { i in
            i == 5 ? DX7OperatorPreset(outputLevel: 99, egRate4: 40, egLevel3: 90,
                                       klsBreakPoint: 39, klsRightDepth: klsDepth, klsRightCurve: 0)
                   : DX7OperatorPreset(outputLevel: 0)
        }
        s.loadDX7Preset(DX7Preset(name: "Legato KLS", algorithm: 31, feedback: 0,
                                 operators: ops, category: .other))
        _ = render(s)
        s.sendMIDI(MIDIEvent(kind: .noteOn, data1: 36, data2: UInt32(100) << 9))
        _ = render(s, blocks: 100)
        s.sendMIDI(MIDIEvent(kind: .noteOn, data1: 72, data2: UInt32(100) << 9))   // legato, 36 held
        _ = render(s, blocks: 20)
        return s
    }

    @Test("one OL step on a legato-held sustain moves the output by one step",
          arguments: [FMEngine.modern, .markI], [20, 60])
    func legatoSustainStep(mode: FMEngine, klsDepth: Int) {
        let edited = legatoSustainingCarrier(mode, klsDepth: klsDepth)
        let control = legatoSustainingCarrier(mode, klsDepth: klsDepth)
        edited.setOperatorDX7OutputLevel(0, level: 98)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let stepped = rms(render(edited, blocks: 32)), held = rms(render(control, blocks: 32))
        let dB = 20 * log10(stepped / held)
        #expect(abs(dB + 0.75) < 0.3, "OL 99→98 should be −0.75 dB, got \(dB) dB")
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        #expect(abs(rms(render(edited, blocks: 32)) / rms(render(control, blocks: 32)) - 1) < 0.005)
    }

    @Test("editing L4 on a legato-held sustain leaves the sustain level untouched")
    func legatoSustainReleaseLevelEdit() throws {
        var slot = SlotSnapshot()
        slot.ops.0.dx7EgR0 = 99; slot.ops.0.dx7EgR1 = 99; slot.ops.0.dx7EgR2 = 99; slot.ops.0.dx7EgR3 = 40
        slot.ops.0.dx7EgL0 = 99; slot.ops.0.dx7EgL1 = 99; slot.ops.0.dx7EgL2 = 90; slot.ops.0.dx7EgL3 = 0
        slot.ops.0.klsBreakPoint = 39
        slot.ops.0.klsRightDepth = 60
        slot.ops.0.klsRightCurve = 0   // −LIN: high notes attenuated
        var voice = DX7Voice()
        voice.applyParams(slot.ops.0, opIndex: 0)
        voice.noteOn(36, velocity16: 100 << 9)
        voice.ops.0.refreshKeyboardOutputLevel()   // note-on KLS for note 36 (klsOffset 0)
        for _ in 0..<200 { voice.ops.0.updateGain(lfoAmpMod: 0) }
        try #require(voice.ops.0.env.ix == 3)
        voice.legatoTo(96, midiNote: 96, slot: slot)
        voice.ops.0.updateGain(lfoAmpMod: 0)
        let held = voice.ops.0.levelIn
        slot.ops.0.dx7EgL3 = 1   // release level only; L3 unchanged
        voice.applyParams(slot.ops.0, opIndex: 0)
        voice.ops.0.updateGain(lfoAmpMod: 0)
        #expect(voice.ops.0.levelIn == held)
        slot.ops.0.dx7OutputLevel = 98
        voice.applyParams(slot.ops.0, opIndex: 0)
        voice.ops.0.updateGain(lfoAmpMod: 0)
        #expect(voice.ops.0.levelIn == held - (32 << 16))
    }

    @Test("raising OL one step on a level held above the new key's full scale never lowers it")
    func upwardStepAboveFullScale() {
        var op = DX7Operator()
        op.klsOffset = 100                  // previous key at the KLS ceiling
        op.setOutputLevel(30)
        op.env.setRates(99, 99, 99, 20)
        op.env.setLevels(99, 99, 99, 0)
        op.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { op.updateGain(lfoAmpMod: 0) }
        op.klsOffset = 0                    // legato to a key without the boost
        op.refreshKeyboardOutputLevel()
        op.updateGain(lfoAmpMod: 0)
        let held = op.levelIn
        op.setOutputLevel(31)
        op.updateGain(lfoAmpMod: 0)
        #expect(op.levelIn >= held)
        #expect(op.levelIn - held <= 32 << 16)
    }

    // MARK: - Note-off while muted (review P3-1)

    @Test("a note released while muted keeps its full release length", arguments: [0, 60])
    func releaseWhileMuted(mutedOL: Int) {
        var op = DX7Operator()
        op.setOutputLevel(99)
        op.env.setRates(99, 99, 99, 30)
        op.env.setLevels(99, 99, 99, 0)
        op.noteOn(baseFreq: 261.6256)
        for _ in 0..<100 { op.updateGain(lfoAmpMod: 0) }
        var control = op
        op.setOutputLevel(mutedOL)
        op.updateGain(lfoAmpMod: 0); control.updateGain(lfoAmpMod: 0)
        op.noteOff(); control.noteOff()
        var editedBlocks = 0, controlBlocks = 0, mismatchesAfterRestore = 0
        for b in 0..<20000 {
            if b == 40 { op.setOutputLevel(99) }
            op.updateGain(lfoAmpMod: 0); control.updateGain(lfoAmpMod: 0)
            if op.env.isActive { editedBlocks = b + 1 }
            if control.env.isActive { controlBlocks = b + 1 }
            if b > 40, op.levelIn != control.levelIn { mismatchesAfterRestore += 1 }
        }
        #expect(editedBlocks == controlBlocks)
        #expect(mismatchesAfterRestore == 0)
    }
}
