// VoiceStackTests.swift
// M2DX-Core — #89 Voice Stack foundation regression + decouple tests

import Testing
@testable import M2DXCore

@Suite struct VoiceStackTests {

    private func makeEngine() -> SynthEngine {
        let e = SynthEngine()
        e.setSampleRate(48000)
        return e
    }

    @Test("default multiplier leaves a single note at one voice")
    func defaultUnchanged() {
        let engine = makeEngine()
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount == 1)
    }

    @Test("LAYER budget stays 128 after the buffer was raised to 2048 (decouple)")
    func layerBudgetStill128() {
        let engine = makeEngine()
        engine.setLayerPartition(parts: 8, unison: 1, detuneCents: 0)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.render(into: l, bufferR: r, frameCount: fc)  // apply snapshot (drainMIDI runs before applyParams; render once first)
        // 40 distinct notes × 8 enabled slots would be 320 voices if uncapped.
        for n in 36..<76 { engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: UInt8(n), data2: UInt32(0x7F00))) }
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount <= 128)   // capped at kLayerBaseVoices, not 2048
        #expect(engine.debugActiveVoiceCount > 64)      // confirms it really uses the 128 budget
    }
}
