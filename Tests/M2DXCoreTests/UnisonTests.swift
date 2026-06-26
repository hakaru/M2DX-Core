// UnisonTests.swift
// M2DX-Core — unison detune spread + voice stacking

import Testing
import Darwin
@testable import M2DXCore

@Suite("Unison")
struct UnisonTests {

    @Test("unisonDetuneFactor: count 1 is always 1.0 (no detune)")
    func countOneIsUnity() {
        #expect(unisonDetuneFactor(index: 0, count: 1, detuneCents: 50) == 1.0)
    }

    @Test("unisonDetuneFactor: symmetric spread, extremes at ±detune cents")
    func symmetricSpread() {
        let n = 4, d: Float = 50
        let f0 = unisonDetuneFactor(index: 0, count: n, detuneCents: d)
        let f3 = unisonDetuneFactor(index: n - 1, count: n, detuneCents: d)
        #expect(abs(f0 - exp2(-d / 1200.0)) < 1e-6, "voice 0 at -50¢")
        #expect(abs(f3 - exp2(d / 1200.0)) < 1e-6, "voice n-1 at +50¢")
        #expect(abs(f0 * f3 - 1.0) < 1e-5, "outermost voices are symmetric about 1.0")
        let f1 = unisonDetuneFactor(index: 1, count: n, detuneCents: d)
        let f2 = unisonDetuneFactor(index: 2, count: n, detuneCents: d)
        #expect(f0 < f1 && f1 < f2 && f2 < f3, "monotonically increasing across voices")
    }

    @Test("unisonDetuneFactor: zero detune is unity for all voices")
    func zeroDetuneUnity() {
        for i in 0..<8 { #expect(unisonDetuneFactor(index: i, count: 8, detuneCents: 0) == 1.0) }
    }

    @Test("setUnison stacks N voices on a single note-on")
    func unisonStacksVoices() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        let fc = 64
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { bufL.deallocate(); bufR.deallocate() }

        engine.setUnison(count: 4, detuneCents: 50)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)
        #expect(engine.activeVoiceCount == 4, "UNISON 4 should allocate 4 voices for one note")
    }

    @Test("UNISON 1 (off) allocates a single voice — unchanged behavior")
    func unisonOffSingleVoice() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        let fc = 64
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { bufL.deallocate(); bufR.deallocate() }

        engine.setUnison(count: 1, detuneCents: 50)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)
        #expect(engine.activeVoiceCount == 1, "UNISON 1 should allocate exactly one voice")
    }

    @Test("Unison scales the voice budget (base × unison) so polyphony isn't reduced")
    func unisonScalesPolyphony() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        let fc = 64
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { bufL.deallocate(); bufR.deallocate() }

        engine.setUnison(count: 2, detuneCents: 20)
        // Warm-up render applies the unison snapshot (effectiveMaxVoices is recomputed
        // after drainMIDI, so the budget change takes effect on the next block — this
        // mirrors the app, where unison is set at startup before any notes).
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)
        // 10 distinct notes × unison 2 = 20 voices. Without budget scaling the
        // single-mode 16-voice cap would steal down to 16.
        for n: UInt8 in 60..<70 {
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: n, data2: UInt32(0x7F00)))
        }
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)
        #expect(engine.activeVoiceCount == 20, "10 notes × unison 2 = 20 voices (budget scaled past the 16 base)")
    }
}
