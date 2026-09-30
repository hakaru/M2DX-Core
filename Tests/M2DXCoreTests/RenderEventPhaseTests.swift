import Testing
@testable import M2DXCore

@Suite("Host render event phase (M2DX #119)")
struct RenderEventPhaseTests {
    private func parameter(_ bank: UInt8, _ index: UInt8, _ value: Float) -> MIDIEvent {
        let fixed = UInt32(bitPattern: Int32((value * 256).rounded())) & 0x00ff_ffff
        return MIDIEvent(kind: .assignableController, data1: bank, data2: UInt32(index) << 24 | fixed)
    }

    private func render(_ engine: SynthEngine, frames: Int = 64,
                        events: (Bool) -> Void = { _ in }) -> [Float] {
        var left = [Float](repeating: 0, count: frames), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                engine.render(into: l.baseAddress!, bufferR: r.baseAddress!, frameCount: frames,
                              processEvents: events)
            }
        }
        return left
    }

    private func configured(_ mode: FMEngine) -> SynthEngine {
        let engine = SynthEngine()
        engine.loadDX7Preset(DX7FactoryPresets.initVoice)
        engine.setFMEngine(mode)
        return engine
    }

    @Test("Host automation survives unrelated snapshots and explicit replacement restores control",
          arguments: [FMEngine.modern, .markI])
    func keepAutomation(_ mode: FMEngine) {
        let host = configured(mode), reference = configured(mode)
        host.setOperatorDetune(5, cents: 37)
        reference.setOperatorDetune(5, cents: -4)
        let detune = parameter(5, 2, -4)
        let note = MIDIEvent(kind: .noteOn, data1: 60, data2: 60_000)
        let first = render(host) { changed in
            #expect(changed)
            host.processRenderParameter(detune)
            host.processRenderMIDI(note)
        }
        let firstReference = render(reference) { _ in reference.processRenderMIDI(note) }
        #expect(host.debugActiveVoiceCount == 1)
        #expect(reference.debugActiveVoiceCount == 1)
        #expect(first.contains { abs($0) > 0.000001 })
        #expect(firstReference.contains { abs($0) > 0.000001 })
        #expect(zip(first, firstReference).allSatisfy { abs($0 - $1) < 0.00001 })
        host.setAlgorithm(17); reference.setAlgorithm(17)
        let edited = render(host) { changed in
            #expect(changed)
            host.processRenderParameter(detune)
        }
        let editedReference = render(reference)
        #expect(host.debugCurrentSnapshot.slots.0.ops.5.detuneCents == -4)
        #expect(zip(edited, editedReference).allSatisfy { abs($0 - $1) < 0.00001 })
        let applied = host.debugApplyCount
        for _ in 0..<4 {
            _ = render(host) { changed in #expect(!changed) }
            _ = render(reference)
        }
        #expect(host.debugApplyCount == applied, "unchanged blocks must not repeat the heavy voice apply")
        // The host invalidates that address's override when an explicit control write follows.
        host.setOperatorDetune(5, cents: 6); reference.setOperatorDetune(5, cents: 6)
        let replaced = render(host) { changed in #expect(changed) }
        let replacedReference = render(reference)
        #expect(host.debugCurrentSnapshot.slots.0.ops.5.detuneCents == 6)
        #expect(zip(replaced, replacedReference).allSatisfy { abs($0 - $1) < 0.00001 })
    }

    @Test("Render events run after pending controller reset, in caller order")
    func sustainOrder() {
        let engine = configured(.modern)
        _ = render(engine) { _ in
            engine.processRenderMIDI(.init(kind: .noteOn, data1: 60, data2: 60_000))
            engine.processRenderMIDI(.init(kind: .controlChange, data1: 64, data2: .max))
            engine.processRenderMIDI(.init(kind: .noteOff, data1: 60, data2: 0))
        }
        let held = render(engine, frames: 8192)
        #expect(engine.debugActiveVoiceCount == 1)
        #expect(held.suffix(1024).contains { abs($0) > 0.001 })
        _ = render(engine, frames: 8192) { _ in
            engine.processRenderMIDI(.init(kind: .controlChange, data1: 64, data2: 0))
        }
        _ = render(engine, frames: 8192)
        #expect(engine.debugActiveVoiceCount == 0)
    }

    @Test("Host parameter volume and physical MIDI CC7 remain independent",
          arguments: [FMEngine.modern, .markI])
    func volumeSemantics(_ mode: FMEngine) {
        let host = configured(mode), reference = configured(mode)
        host.setMasterVolume(0.7); reference.setMasterVolume(0.5)
        let ccVolume = MIDIEvent(kind: .controlChange, data1: 7, data2: UInt32.max / 4)
        let note = MIDIEvent(kind: .noteOn, data1: 60, data2: 60_000)
        let actual = render(host) { _ in
            host.processRenderParameter(.init(kind: .controlChange, data1: 7, data2: UInt32.max / 2))
            host.processRenderMIDI(ccVolume)
            host.processRenderMIDI(note)
        }
        let expected = render(reference) { _ in
            reference.processRenderMIDI(ccVolume)
            reference.processRenderMIDI(note)
        }
        #expect(host.debugCurrentSnapshot.masterVolume == 0.5)
        #expect(host.debugActiveVoiceCount == 1)
        #expect(reference.debugActiveVoiceCount == 1)
        #expect(actual.contains { abs($0) > 0.000001 })
        #expect(expected.contains { abs($0) > 0.000001 })
        #expect(zip(actual, expected).allSatisfy { abs($0 - $1) < 0.00001 })
        host.setMasterVolume(0.8); reference.setMasterVolume(0.8)
        let replaced = render(host), replacedReference = render(reference)
        #expect(zip(replaced, replacedReference).allSatisfy { abs($0 - $1) < 0.00001 })
    }

    @Test("The first note after an engine/oversampling switch uses the new mode and stays held",
          arguments: [FMEngine.modern, .markI],
          [OversamplingMode.off, .lowCPU, .highQuality])
    func firstNoteAfterModeChange(_ mode: FMEngine, _ oversampling: OversamplingMode) {
        for queued in [false, true] {
            let engine = configured(.modern)
            _ = render(engine)
            engine.setFMEngine(mode)
            engine.setOversamplingMode(oversampling)
            engine.setSampleRate(48_000)
            let note = MIDIEvent(kind: .noteOn, data1: 60, data2: 60_000)
            if queued { engine.sendMIDI(note) }
            _ = render(engine) { _ in
                if !queued { engine.processRenderMIDI(note) }
            }
            let held = render(engine, frames: 8192)
            #expect(engine.debugActiveVoiceCount == 1,
                    "mode preparation must precede both direct and queued note-on")
            #expect(held.suffix(1024).contains { abs($0) > 0.000001 })
        }
    }

    @Test("The first layered note uses the expanded voice budget",
          arguments: [FMEngine.modern, .markI])
    func firstNoteAfterBudgetChange(_ mode: FMEngine) {
        for queued in [false, true] {
            let engine = configured(mode)
            _ = render(engine)
            engine.setLayerPartition(parts: 8, unison: 4)
            engine.setVoiceStackMultiplier(2)
            let note = MIDIEvent(kind: .noteOn, data1: 60, data2: 60_000)
            if queued { engine.sendMIDI(note) }
            let audio = render(engine) { _ in
                if !queued { engine.processRenderMIDI(note) }
            }
            #expect(engine.debugActiveVoiceCount == 64)
            #expect(audio.contains { abs($0) > 0.000001 })
        }
    }

    @Test("Render-side events do not consume the MIDI queue or apply parameters repeatedly")
    func directEventsHaveNoQueueLoad() {
        let engine = configured(.modern)
        _ = render(engine)
        let before = engine.debugApplyCount
        _ = render(engine) { changed in
            #expect(!changed)
            for i in 0..<2_000 {
                engine.processRenderParameter(parameter(0, 0, Float(i % 100)))
                engine.processRenderMIDI(.init(kind: .polyPressure, data1: 60, data2: UInt32(i)))
            }
        }
        #expect(engine.droppedMIDICount == 0)
        #expect(engine.debugCurrentSnapshot.slots.0.ops.0.dx7OutputLevel == 99)
        #expect(engine.debugApplyCount == before + 1)
        _ = render(engine) { _ in
            engine.processRenderParameter(.init(kind: .noteOn, data1: 60, data2: 60_000))
            engine.processRenderParameter(parameter(64, 5, 1)) // unsupported engine selector
        }
        #expect(engine.debugActiveVoiceCount == 0)
        #expect(engine.debugApplyCount == before + 1)
    }
}
