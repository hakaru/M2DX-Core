// VoiceStackDetuneTests.swift
// M2DX-Core — Voice Stack detune (even + random) + decorrelation-aware gain.

import Testing
import Foundation
@testable import M2DXCore

@Suite struct VoiceStackDetuneTests {

    // MARK: voiceStackGainFactor

    @Test("gain is 1/N at detune 0 (regression: phase-locked coherent sum)")
    func gainCoherentAtZero() {
        for n in [2, 4, 8, 16] {
            #expect(voiceStackGainFactor(multiplier: n, detuneCents: 0) == 1.0 / Float(n))
        }
    }

    @Test("gain is 1/sqrt(N) at/above the decorrelation width")
    func gainIncoherentWhenWide() {
        for n in [2, 4, 8, 16] {
            let g = voiceStackGainFactor(multiplier: n, detuneCents: kVoiceStackDecorrelationCents)
            #expect(abs(g - 1.0 / sqrtf(Float(n))) < 1e-6)
            // clamps: beyond the width stays at 1/sqrt(N)
            #expect(abs(voiceStackGainFactor(multiplier: n, detuneCents: 25) - g) < 1e-6)
        }
    }

    @Test("gain rises monotonically from 1/N toward 1/sqrt(N) as detune grows")
    func gainMonotonic() {
        let g0 = voiceStackGainFactor(multiplier: 4, detuneCents: 0)
        let g3 = voiceStackGainFactor(multiplier: 4, detuneCents: 3)
        let g6 = voiceStackGainFactor(multiplier: 4, detuneCents: 6)
        #expect(g0 < g3 && g3 < g6)
    }

    @Test("single voice is never attenuated")
    func gainUnitForSingle() {
        #expect(voiceStackGainFactor(multiplier: 1, detuneCents: 25) == 1.0)
    }

    // MARK: voiceStackDetuneFactorRandom

    @Test("random factor is 1.0 when detune is 0")
    func randomZero() {
        #expect(voiceStackDetuneFactorRandom(noteOnIndex: 7, copyIndex: 2, detuneCents: 0) == 1.0)
    }

    @Test("random factor stays within the ±detune cents band")
    func randomBounded() {
        let lo: Float = exp2(-25.0 / 1200.0), hi: Float = exp2(25.0 / 1200.0)
        for copy in 0..<16 {
            let f = voiceStackDetuneFactorRandom(noteOnIndex: 0, copyIndex: copy, detuneCents: 25)
            #expect(f >= lo && f <= hi)
        }
    }

    @Test("different copies of the same note-on get different detune")
    func randomDistinctPerCopy() {
        let a = voiceStackDetuneFactorRandom(noteOnIndex: 0, copyIndex: 0, detuneCents: 25)
        let b = voiceStackDetuneFactorRandom(noteOnIndex: 0, copyIndex: 1, detuneCents: 25)
        #expect(a != b)
    }

    @Test("re-roll: the same copy gets different detune on a later note-on")
    func randomReRolls() {
        let first  = voiceStackDetuneFactorRandom(noteOnIndex: 0, copyIndex: 0, detuneCents: 25)
        let second = voiceStackDetuneFactorRandom(noteOnIndex: 1, copyIndex: 0, detuneCents: 25)
        #expect(first != second)
    }

    // MARK: voiceStackVelocityRandomized

    @Test("velocity random range 0 leaves velocity unchanged")
    func velocityRandomZero() {
        #expect(voiceStackVelocityRandomized(0x4001, range7: 0, noteOnIndex: 7, copyIndex: 2) == 0x4001)
    }

    @Test("velocity random stays within the requested 7-bit step range")
    func velocityRandomBounded() {
        let base = UInt16(64 << 9)
        let range: UInt8 = 12
        for copy in 0..<16 {
            let v = voiceStackVelocityRandomized(base, range7: range, noteOnIndex: 0, copyIndex: copy)
            #expect(abs(Int(v) - Int(base)) <= Int(range) * 512)
        }
    }

    @Test("velocity random differs by copy and re-rolls by note-on")
    func velocityRandomVaries() {
        let base = UInt16(64 << 9)
        let a = voiceStackVelocityRandomized(base, range7: 32, noteOnIndex: 0, copyIndex: 0)
        let b = voiceStackVelocityRandomized(base, range7: 32, noteOnIndex: 0, copyIndex: 1)
        let c = voiceStackVelocityRandomized(base, range7: 32, noteOnIndex: 1, copyIndex: 0)
        #expect(a != b)
        #expect(a != c)
    }

    @Test("velocity random clamps but preserves note-on")
    func velocityRandomClamps() {
        #expect(voiceStackVelocityRandomized(1, range7: 64, noteOnIndex: 0, copyIndex: 0) >= 1)
        #expect(voiceStackVelocityRandomized(0xFFFF, range7: 64, noteOnIndex: 0, copyIndex: 2) <= 0xFFFF)
    }

    // MARK: end-to-end wiring

    private func makeEngine() -> SynthEngine {
        let e = SynthEngine()
        e.setSampleRate(48000)
        return e
    }

    private func renderStack(detuneCents: Float, mode: UInt8, mult: Int) -> [Float] {
        let e = makeEngine()
        e.loadDX7Preset(DX7FactoryPresets.initVoice)
        e.setVoiceStackMultiplier(mult)
        e.setVoiceStackDetune(detuneCents: detuneCents, detuneMode: mode)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        e.render(into: l, bufferR: r, frameCount: fc)   // apply preset + stack snapshot
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        var out = [Float](repeating: 0, count: fc * 8)
        for blk in 0..<8 {
            e.render(into: l, bufferR: r, frameCount: fc)
            for s in 0..<fc { out[blk * fc + s] = l[s] }
        }
        return out
    }

    @Test("even detune changes the stacked output vs the phase-locked baseline (wiring)")
    func evenDetuneAltersOutput() {
        let flat = renderStack(detuneCents: 0, mode: 0, mult: 2)
        let det  = renderStack(detuneCents: 24, mode: 0, mult: 2)
        var diff: Float = 0
        for i in 0..<flat.count { diff += abs(flat[i] - det[i]) }
        #expect(diff > 0.001)   // detuned copies beat → audibly different from identical copies
    }

    @Test("random detune changes the stacked output (wiring)")
    func randomDetuneAltersOutput() {
        let flat = renderStack(detuneCents: 0, mode: 1, mult: 4)
        let det  = renderStack(detuneCents: 24, mode: 1, mult: 4)
        var diff: Float = 0
        for i in 0..<flat.count { diff += abs(flat[i] - det[i]) }
        #expect(diff > 0.001)
    }

    @Test("detune does not change the stacked voice count")
    func detuneKeepsVoiceCount() {
        let e = makeEngine()
        e.setVoiceStackMultiplier(4)
        e.setVoiceStackDetune(detuneCents: 20, detuneMode: 0)
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        e.render(into: l, bufferR: r, frameCount: fc)
        #expect(e.debugActiveVoiceCount == 4)
    }

    @Test("velocity random changes per-copy velocity offsets (wiring)")
    func velocityRandomAltersOffsets() {
        let e = makeEngine()
        e.setVoiceStackMultiplier(4)
        e.setVoiceStackVelocityRandom(range: 40)
        for op in 0..<6 { e.setOperatorVelocitySensitivity(op, value: 7) }
        let fc = 64
        let l = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: fc)
        defer { l.deallocate(); r.deallocate() }
        e.render(into: l, bufferR: r, frameCount: fc)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(64 << 9)))
        e.render(into: l, bufferR: r, frameCount: fc)
        let offsets = e.activeVoiceVelocityOffsets(0)
        #expect(offsets.count == 4)
        #expect(Set(offsets).count > 1)
    }
}
