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

    @Test("stack multiplies a single note-on into N voices", arguments: [1, 2, 4, 8])
    func stackProducesNVoices(mult: Int) {
        let engine = makeEngine()
        engine.setVoiceStackMultiplier(mult)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount == mult)
    }

    @Test("note-off releases ALL stacked voices (no leak)")
    func noteOffReleasesAll() {
        let engine = makeEngine()
        engine.setVoiceStackMultiplier(4)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount == 4)
        engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: 60, data2: 0))
        for _ in 0..<2000 { engine.render(into: l, bufferR: r, frameCount: fc) }
        #expect(engine.debugActiveVoiceCount == 0)
    }

    @Test("all-notes-off clears stacked voices")
    func allNotesOffClearsStack() {
        let engine = makeEngine()
        engine.setVoiceStackMultiplier(8)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 64, data2: UInt32(0x7F00)))
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount == 8)
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 123, data2: 0)) // CC123 All Notes Off
        for _ in 0..<2000 { engine.render(into: l, bufferR: r, frameCount: fc) }
        #expect(engine.debugActiveVoiceCount == 0)
    }

    @Test("LAYER 8 slots × 2× = 16 voices for one note")
    func layerTimesStack() {
        let engine = makeEngine()
        engine.setLayerPartition(parts: 8, unison: 1, detuneCents: 0)
        engine.setVoiceStackMultiplier(2)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        // render once first so the LAYER + stack snapshot is applied before the note is drained
        engine.render(into: l, bufferR: r, frameCount: fc)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount == 16)
    }

    @Test("sustain pedal holds stacked voices through note-off, releases on pedal up")
    func sustainHoldsStack() {
        let engine = makeEngine()
        engine.setVoiceStackMultiplier(4)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 64, data2: 0x7F000000)) // sustain ON (>=0x40000000)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: l, bufferR: r, frameCount: fc)
        engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: 60, data2: 0))
        for _ in 0..<200 { engine.render(into: l, bufferR: r, frameCount: fc) }
        #expect(engine.debugActiveVoiceCount == 4)   // still held by sustain
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 64, data2: 0)) // sustain OFF
        for _ in 0..<2000 { engine.render(into: l, bufferR: r, frameCount: fc) }
        #expect(engine.debugActiveVoiceCount == 0)
    }

    @Test("multiplier clamps to 1...16 (behavioural)")
    func clampBounds() {
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }

        let low = makeEngine()
        low.setVoiceStackMultiplier(0)             // clamps to 1
        low.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        low.render(into: l, bufferR: r, frameCount: fc)
        #expect(low.debugActiveVoiceCount == 1)

        let high = makeEngine()
        high.setVoiceStackMultiplier(999)          // clamps to 16
        high.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        high.render(into: l, bufferR: r, frameCount: fc)
        #expect(high.debugActiveVoiceCount == 16)  // single base 16 × 16 = 256 budget; one note × 16 = 16
    }

    @Test("N× stack does not blow up output peak (1/N gain compensation)")
    func gainCompensated() {
        // Load INIT VOICE (DX7FactoryPresets.initVoice via loadDX7Preset — same API as
        // PresetLoadTests.initVoiceViaAtomic). Fast attack (rates 99/99/99/99) ensures
        // audible output within the first 8 render blocks.
        func loadAudiblePreset(_ e: SynthEngine) {
            e.sendMIDI(MIDIEvent(kind: .controlChange, data1: 123, data2: 0))  // allNotesOff
            e.loadDX7Preset(DX7FactoryPresets.initVoice)
        }

        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }

        let single = makeEngine()
        loadAudiblePreset(single)
        single.render(into: l, bufferR: r, frameCount: fc)   // apply preset snapshot
        single.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        var peak1: Float = 0
        for _ in 0..<8 { single.render(into: l, bufferR: r, frameCount: fc); for s in 0..<fc { peak1 = max(peak1, abs(l[s])) } }
        #expect(peak1 > 0)   // sanity: single voice is audible (if this fails, preset setup is wrong)

        let stacked = makeEngine()
        loadAudiblePreset(stacked)
        stacked.setVoiceStackMultiplier(4)
        stacked.render(into: l, bufferR: r, frameCount: fc)  // apply preset + multiplier snapshot
        stacked.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        var peak4: Float = 0
        for _ in 0..<8 { stacked.render(into: l, bufferR: r, frameCount: fc); for s in 0..<fc { peak4 = max(peak4, abs(l[s])) } }

        // Without 1/N compensation peak4 ≈ 4×peak1 (phase-locked copies sum coherently).
        // With 1/N comp, peak4 should be ≈ peak1 (within 1.5× tolerance).
        #expect(peak4 > 0)   // guard: 1/N must not silence the stack
        #expect(peak4 < peak1 * 1.5)
    }

    @Test("I-1: LAYER + unison≥2 at stack=1 keeps the legacy 128 budget (spec §2 LAYER unchanged)")
    func layerUnisonStackOneStillLegacyCap() {
        let engine = makeEngine()
        engine.setLayerPartition(parts: 4, unison: 2, detuneCents: 0) // TX816 4×2 shape, unisonCount=2, stack defaults 1
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        engine.render(into: l, bufferR: r, frameCount: fc) // apply the layer snapshot first
        // 40 notes × (4 slots × 2 unison = 8 voices) = 320 demanded; legacy cap is 128.
        for n in 36..<76 { engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: UInt8(n), data2: UInt32(0x7F00))) }
        engine.render(into: l, bufferR: r, frameCount: fc)
        #expect(engine.debugActiveVoiceCount <= 128)  // FAILS before fix (would reach ~256)
        #expect(engine.debugActiveVoiceCount > 64)     // confirms it really uses the 128 budget
    }
}
