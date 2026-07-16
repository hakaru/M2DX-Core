// VoiceAllocatorTests.swift
// Deterministic complexity regressions for the render-thread voice allocator.

import Testing
@testable import M2DXCore

@Suite("Voice allocator")
struct VoiceAllocatorTests {
    private let frameCount = 64

    private func withBuffers(_ body: (UnsafeMutablePointer<Float>, UnsafeMutablePointer<Float>) -> Void) {
        let left = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { left.deallocate(); right.deallocate() }
        body(left, right)
    }

    @Test("1024-voice burst uses one bitmap probe per allocation and full pool is O(1)")
    func bitmapAndFullPoolFastPath() {
        withBuffers { left, right in
            let engine = SynthEngine()
            engine.setSampleRate(48_000)
            engine.setLayerPartition(parts: 8, unison: 8)
            engine.setVoiceStackMultiplier(8)

            // layer base 128 × stack 8 = an exact 1024-voice pool.
            engine.render(into: left, bufferR: right, frameCount: frameCount)
            let probesBeforeFill = engine.debugVoiceAllocationProbeCount

            // Each note creates 8 slots × 8 unison × 8 stack = 512 voices.
            for note: UInt8 in [60, 61] {
                engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: 0x7F00))
            }
            engine.render(into: left, bufferR: right, frameCount: frameCount)

            #expect(engine.debugActiveVoiceCount == 1024)
            let fillProbes = engine.debugVoiceAllocationProbeCount - probesBeforeFill
            #expect(fillProbes <= 1024, "bitmap cursor should inspect at most one word per allocation; got \(fillProbes)")

            let probesAtFullPool = engine.debugVoiceAllocationProbeCount
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 62, data2: 0x7F00))
            engine.render(into: left, bufferR: right, frameCount: frameCount)

            #expect(engine.debugActiveVoiceCount == 1024)
            #expect(
                engine.debugVoiceAllocationProbeCount == probesAtFullPool,
                "full-pool stealing must bypass the bitmap entirely"
            )
        }
    }

    @Test("single-copy full-pool retrigger uses note map without a linear scan")
    func mappedRetriggerFastPath() {
        withBuffers { left, right in
            let engine = SynthEngine()
            engine.setSampleRate(48_000)
            engine.setLayerPartition(parts: 8, unison: 1)
            engine.render(into: left, bufferR: right, frameCount: frameCount)

            // 16 notes × 8 slots fills the legacy 128-voice layer pool.
            for note in UInt8(48)..<UInt8(64) {
                engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: 0x7F00))
            }
            engine.render(into: left, bufferR: right, frameCount: frameCount)
            #expect(engine.debugActiveVoiceCount == 128)

            let probesAtFullPool = engine.debugVoiceAllocationProbeCount
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 48, data2: 0x7F00))
            engine.render(into: left, bufferR: right, frameCount: frameCount)

            #expect(engine.debugActiveVoiceCount == 128)
            #expect(engine.debugVoiceAllocationProbeCount == probesAtFullPool)
        }
    }
}
