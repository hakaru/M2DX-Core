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
}
