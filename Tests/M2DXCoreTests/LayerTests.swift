// LayerTests.swift — TX816 layer mode: routing, partition, per-slot level/pan
import Testing
import Darwin
@testable import M2DXCore

@MainActor
@Suite("TX816 Layer")
struct LayerTests {

    private func makeEngine() -> SynthEngine {
        let e = SynthEngine()
        e.setSampleRate(48000)
        return e
    }
    private func render(_ e: SynthEngine, _ n: Int = 64) {
        let l = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { l.deallocate(); r.deallocate() }
        e.render(into: l, bufferR: r, frameCount: n)
    }

    @Test("layer mode routes a note to every enabled slot")
    func layerRoutesToAllEnabledSlots() {
        let e = makeEngine()
        e.setTimbreMode(.layer)
        e.setSlotEnabled(0, enabled: true)
        e.setSlotEnabled(1, enabled: true)
        e.setSlotEnabled(2, enabled: true)
        for i in 3..<8 { e.setSlotEnabled(i, enabled: false) }
        render(e) // apply snapshot
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        render(e)
        #expect(Set(e.activeVoiceSlotIds()) == [0, 1, 2], "one note → one voice in each of the 3 enabled slots")
    }
}
