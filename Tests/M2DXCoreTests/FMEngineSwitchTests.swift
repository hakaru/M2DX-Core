// FMEngineSwitchTests.swift
import Testing
@testable import M2DXCore

@Suite("FM engine switch")
struct FMEngineSwitchTests {
    @Test("switching engine with an active note all-notes-off (no stuck voice)")
    func switchResets() {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: 100 << 9))
        let L = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { L.deallocate(); R.deallocate() }
        e.render(into: L, bufferR: R, frameCount: 64)
        e.setFMEngine(.markI)
        e.render(into: L, bufferR: R, frameCount: 64)
        #expect(e.debugActiveVoiceCount == 0)
    }
}
