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

    @Test("Fixed-frequency operators are detuned per unison voice")
    func fixedFreqOperatorsDetune() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        let fc = 64
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { bufL.deallocate(); bufR.deallocate() }

        // OP1 = fixed-frequency carrier (frequencyMode 1, coarse 3); OP2..6 silent.
        // In loadDX7Preset: operators[0] (OP1) maps to slot.ops.5 (opIdx 5).
        let fixedOp = DX7OperatorPreset(outputLevel: 99, frequencyCoarse: 3, frequencyFine: 0, frequencyMode: 1)
        let silent = DX7OperatorPreset(outputLevel: 0)
        let preset = DX7Preset(name: "FixedTest", algorithm: 0, feedback: 0,
                               operators: [fixedOp, silent, silent, silent, silent, silent],
                               category: .other)
        engine.loadDX7Preset(preset)
        engine.setUnison(count: 2, detuneCents: 50)
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)   // warm-up: apply preset + unison budget

        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)

        // OP1 (operators[0]) maps to opIdx 5 in the voice tuple
        let freqs = engine.activeVoiceOperatorFreqs(5).sorted()
        #expect(freqs.count == 2, "unison 2 → 2 active voices")
        if freqs.count == 2 {
            let ratio = freqs[1] / freqs[0]
            let expected = exp2(Float(100) / 1200)   // +50¢ vs -50¢ = 100¢ apart
            #expect(abs(ratio - expected) < 0.002, "fixed-freq ops detuned: ratio \(ratio) ≈ \(expected)")
        }
    }

    @Test("Unison voice budget scales to the full kMaxVoices buffer (16 notes × unison 8 = 128)")
    func unisonBudgetReaches128() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        let fc = 64
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { bufL.deallocate(); bufR.deallocate() }

        engine.setUnison(count: 8, detuneCents: 20)
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)   // warm-up applies the budget
        // 16 notes × unison 8 = 128 = the kMaxVoices buffer (Release renders this
        // at ~5% of the audio deadline, so it is RT-safe).
        let notes: [UInt8] = [52, 55, 57, 60, 62, 64, 67, 69, 71, 72, 74, 76, 79, 81, 83, 84]
        for n in notes { engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: n, data2: UInt32(0x7F00))) }
        engine.render(into: bufL, bufferR: bufR, frameCount: fc)
        #expect(engine.activeVoiceCount == 128, "16 notes × unison 8 = 128 voices (full kMaxVoices buffer)")
    }
}
